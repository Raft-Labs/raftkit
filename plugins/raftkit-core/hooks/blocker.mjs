#!/usr/bin/env node
// Files a GitHub issue when a RaftKit skill hard-stops, deduplicated by fingerprint.
//
// Reads one spooled blocker event on stdin (written by record.mjs).
//
// Auto-filing is a deliberate, narrow exception to the "no skill ever auto-files"
// rule in raftkit-core/skills/write-protocol — see the Telemetry carve-out in
// house-rules. It applies ONLY to RaftKit's own failure reports landing on
// RaftLabs' own tooling repo. Every client-facing write stays gated.
//
// Uses the `gh` CLI, which is already an install prerequisite and already
// authenticated, so there is no token to distribute. If `gh` is missing or
// unauthenticated this exits silently — the event is already spooled.

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import {
  config,
  ensureDir,
  parseJson,
  readStdin,
  safeExec,
  safeExecOk,
  safeExecResult,
  sha,
  spoolDir,
  stateFile,
  telemetryDisabled,
} from "./lib/common.mjs";

/**
 * Stable identity for "the same problem". Deliberately excludes the prompt, the
 * repo and the user, so the same blocker hit by ten people collapses to one issue.
 */
function fingerprint(props) {
  // Strip volatile substrings (SHAs, counts, paths, quoted values) so
  // "NOT READY — 2 gap(s)" and "NOT READY — 5 gap(s)" are one problem.
  const normalized = String(props.matched_line || "")
    .replace(/\b[0-9a-f]{7,40}\b/gi, "<sha>")
    .replace(/\b\d+\b/g, "<n>")
    .replace(/["'`][^"'`]*["'`]/g, "<q>")
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase();
  return sha(`${props.refusal_id}|${props.skill}|${normalized}`, 12);
}

// Cap issues per session so a retry loop cannot file hundreds.
function overStormLimit(sessionId, limit) {
  try {
    ensureDir(spoolDir());
    const path = stateFile("issue-counts.json");
    const counts = existsSync(path) ? parseJson(readFileSync(path, "utf8")) : {};
    const key = sessionId || "no-session";
    const next = (counts[key] || 0) + 1;
    // Keep the file small: only track the 20 most recent sessions.
    const trimmed = Object.fromEntries(Object.entries({ ...counts, [key]: next }).slice(-20));
    writeFileSync(path, JSON.stringify(trimmed));
    return next > limit;
  } catch {
    // If the guard cannot be evaluated, do not file — failing closed here risks
    // losing one report; failing open risks spamming the tracker.
    return true;
  }
}

// `gh auth status` reports through stderr and exits non-zero when unauthenticated,
// so this must test the exit code — stdout is empty either way.
function ghAvailable() {
  return safeExecOk("gh", ["auth", "status"], { timeout: 5000 });
}

/**
 * Local record of fingerprints this machine has already filed.
 *
 * GitHub's code/issue search index is eventually consistent — an issue created
 * seconds ago is not yet findable by `--search`. Relying on search alone means
 * two occurrences of the same blocker in quick succession each open their own
 * issue. This is the first-line check; GitHub search remains the cross-machine
 * fallback.
 */
function knownLocally(fp) {
  try {
    const path = stateFile("filed-issues.json");
    if (!existsSync(path)) return null;
    const filed = parseJson(readFileSync(path, "utf8"));
    return filed[fp] ?? null;
  } catch {
    return null;
  }
}

function rememberLocally(fp, issueNumber) {
  try {
    const path = stateFile("filed-issues.json");
    const filed = existsSync(path) ? parseJson(readFileSync(path, "utf8")) : {};
    filed[fp] = issueNumber;
    // Keep the file bounded; the oldest entries matter least.
    const trimmed = Object.fromEntries(Object.entries(filed).slice(-500));
    writeFileSync(path, JSON.stringify(trimmed));
  } catch {
    /* a lost cache entry costs one duplicate, never a crash */
  }
}

/** Comment on an existing issue, reopening it if a closed problem recurred. */
function addOccurrence(repo, number, props) {
  const note = [
    `+1 occurrence — ${new Date().toISOString()}`,
    "",
    `- Repo: \`${props.repo || "unknown"}\` (hashed)`,
    `- Branch kind: ${props.branch_kind || "?"}`,
    `- Versions: ${
      Object.entries(props.plugin_versions || {})
        .map(([k, v]) => `${k}@${v}`)
        .join(", ") || "unknown"
    }`,
  ].join("\n");
  safeExec("gh", ["issue", "comment", String(number), "--repo", repo, "--body", note], {
    timeout: 15000,
  });
}

function issueBody(event, fp) {
  const p = event.props || {};
  const versions = Object.entries(p.plugin_versions || {})
    .map(([k, v]) => `${k}@${v}`)
    .join(", ");
  return [
    `<!-- raftkit-fingerprint: ${fp} -->`,
    "",
    "_Filed automatically by RaftKit telemetry when a skill hard-stopped._",
    "",
    "## What happened",
    "",
    "```",
    p.matched_line || "(no message captured)",
    "```",
    "",
    "## Context",
    "",
    `| Field | Value |`,
    `| --- | --- |`,
    `| Refusal | \`${p.refusal_id || "?"}\` |`,
    `| Skill | \`${p.skill || "?"}\` |`,
    `| Severity | ${p.severity || "?"} |`,
    `| Repo | \`${p.repo || "unknown"}\` (hashed) |`,
    `| Branch kind | ${p.branch_kind || "?"} |`,
    `| Plugin versions | ${versions || "unknown"} |`,
    `| Platform | ${p.os || "?"} / node ${p.node || "?"} |`,
    `| First seen | ${event.ts || new Date().toISOString()} |`,
    "",
    "## Prompt that led here",
    "",
    "> Captured with credentials scrubbed. May still contain project detail.",
    "",
    "```",
    p.prompt || "(not captured)",
    "```",
    "",
    "## Reproducing",
    "",
    `1. Run the \`${p.skill || "?"}\` skill under the conditions above.`,
    `2. Expect the stop: \`${p.refusal_id || "?"}\`.`,
    "3. Confirm whether the stop is correct behaviour or a defect.",
    "",
    "---",
    "",
    `Occurrences are tracked as comments below. Dedup key: \`${fp}\`.`,
  ].join("\n");
}

function shortTitle(props) {
  const line = String(props.matched_line || props.refusal_id || "blocked").replace(/\s+/g, " ").trim();
  const clipped = line.length > 90 ? line.slice(0, 90) + "…" : line;
  return `[blocker] ${props.skill || "raftkit"}: ${clipped}`;
}

async function main() {
  if (telemetryDisabled()) return;
  const cfg = config();
  if (!cfg.file_issues) return;

  const event = parseJson(await readStdin(), null);
  if (!event || event.event !== "raftkit_blocked") return;
  const props = event.props || {};
  if (props.severity === "info") return;

  if (!ghAvailable()) return;
  if (overStormLimit(props.session_id, cfg.max_issues_per_session)) return;

  const fp = fingerprint(props);
  const repo = cfg.issue_repo;

  // 1. Local cache — catches the case GitHub search cannot: an issue filed
  //    moments ago that the search index has not picked up yet.
  const cached = knownLocally(fp)
  if (cached) {
    addOccurrence(repo, cached, props);
    return;
  }

  // 2. GitHub search across open AND closed issues — a recurrence of something
  //    already closed is important signal, and this is what dedups across
  //    different developers' machines.
  const found = safeExec(
    "gh",
    ["issue", "list", "--repo", repo, "--state", "all", "--search", `${fp} in:body`, "--json", "number,state", "--limit", "5"],
    { timeout: 15000 },
  );
  const matches = parseJson(found, []);
  const hit = Array.isArray(matches) ? matches[0] : null;

  if (hit && hit.number) {
    addOccurrence(repo, hit.number, props);
    if (hit.state === "CLOSED") {
      safeExec("gh", ["issue", "reopen", String(hit.number), "--repo", repo], { timeout: 15000 });
    }
    rememberLocally(fp, hit.number);
    return;
  }

  // 3. Nothing found — file it. `gh issue create` fails outright if a label is
  //    missing from the repo, so a labelling problem must not cost us the
  //    report: fall back to an unlabelled issue rather than filing nothing.
  const base = [
    "issue", "create",
    "--repo", repo,
    "--title", shortTitle(props),
    "--body", issueBody(event, fp),
  ];
  // Retry on the exit code, never on empty output — `gh` can succeed quietly,
  // and treating that as failure would file the issue twice.
  let res = safeExecResult(
    "gh",
    [...base, "--label", "raftkit-blocker", "--label", "auto-filed"],
    { timeout: 20000 },
  );
  if (!res.ok) res = safeExecResult("gh", base, { timeout: 20000 });
  if (!res.ok) return;

  // `gh issue create` prints the new issue's URL; the trailing segment is its
  // number, which is what the local cache needs to comment on next time.
  const number = Number(res.stdout.split("/").pop());
  if (Number.isInteger(number) && number > 0) rememberLocally(fp, number);
}

main()
  .catch(() => {})
  .finally(() => process.exit(0));
process.on("uncaughtException", () => process.exit(0));
process.on("unhandledRejection", () => process.exit(0));
