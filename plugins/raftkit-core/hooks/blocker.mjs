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
  acquireLock,
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

// How long a session's issue count stays on the books.
const STORM_WINDOW_MS = 24 * 60 * 60 * 1000;
const STORM_KEYS_KEPT = 20;

/**
 * A counter bucket that expires.
 *
 * An event with no session id used to land in one permanent "no-session" bucket:
 * three lifetime occurrences and blocker filing was disabled for that case
 * forever, on that machine, with nothing to reset it. Date-scoping the fallback
 * key bounds the blast radius to a day.
 */
function stormKey(sessionId) {
  return sessionId || `no-session:${new Date().toISOString().slice(0, 10)}`;
}

/**
 * Cap issues per session so a retry loop cannot file hundreds.
 *
 * Locked, because this is a read-modify-write over a file shared by detached
 * processes: two blockers firing together both read the same count and both
 * wrote back count+1, so the cap undercounted and the guard leaked issues.
 */
function overStormLimit(sessionId, limit) {
  let release;
  try {
    ensureDir(spoolDir());
    release = acquireLock(stateFile("issue-counts.lock"), { staleMs: 30000 });
    if (!release) return true; // contended: fail closed, as below

    const path = stateFile("issue-counts.json");
    const counts = existsSync(path) ? parseJson(readFileSync(path, "utf8")) : {};
    const key = stormKey(sessionId);
    const now = Date.now();

    // Entries are {count, updated}. Anything older than the window is dropped,
    // so a long-lived machine cannot accumulate dead buckets that block filing.
    const live = Object.entries(counts)
      .map(([k, v]) => [k, typeof v === "number" ? { count: v, updated: now } : v])
      .filter(([, v]) => v && typeof v.count === "number" && now - (v.updated || 0) < STORM_WINDOW_MS);

    const prev = live.find(([k]) => k === key)?.[1]?.count || 0;
    const next = prev + 1;

    // Trim by recency, not by insertion order: Object.entries preserves the
    // order keys were first added, so .slice(-20) on a busy machine could evict
    // the CURRENT session's own counter and silently reset its cap mid-session.
    const merged = new Map(live.filter(([k]) => k !== key));
    merged.set(key, { count: next, updated: now });
    const trimmed = Object.fromEntries(
      [...merged.entries()].sort((a, b) => (a[1].updated || 0) - (b[1].updated || 0)).slice(-STORM_KEYS_KEPT),
    );

    writeFileSync(path, JSON.stringify(trimmed));
    return next > limit;
  } catch {
    // If the guard cannot be evaluated, do not file — failing closed here risks
    // losing one report; failing open risks spamming the tracker.
    return true;
  } finally {
    if (release) release();
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

/**
 * Comment on an existing issue, reopening it if a closed problem recurred.
 * Same rule as issueBody: correlation ids only, never the prompt.
 */
function addOccurrence(repo, number, props, eventId) {
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
    `- Event id: \`${eventId || "unknown"}\` (full context in the admin DB)`,
  ].join("\n");
  safeExec("gh", ["issue", "comment", String(number), "--repo", repo, "--body", note], {
    timeout: 15000,
  });
}

/**
 * Render the issue body for a blocker.
 *
 * THE RAW PROMPT MUST NEVER APPEAR HERE. Do not re-add it.
 *
 * The telemetry endpoint and this GitHub issue are two different channels with
 * two different jobs. The endpoint is private, first-party, and already receives
 * the full prompt — every analytics and product-improvement question is answered
 * there, and nothing about that changes. This issue exists for blocker TRIAGE,
 * and triage needs the refusal, the skill and the versions, not the prompt.
 *
 * The repo this files into is PUBLIC. A developer who hard-stops inside a client
 * repo was publishing that client's prompt — under their own GitHub identity, to
 * a search-indexed page — every time. "Credentials scrubbed" was never the same
 * claim as "safe to publish": the scrubber removes credentials, not project
 * detail, and it is best-effort even at that.
 *
 * What replaces it is a correlation id. The event_id here is the same id the
 * telemetry event carries, so a triager looks the full context up in the admin
 * DB, where access is already controlled.
 */
function issueBody(event, fp) {
  const p = event.props || {};
  const versions = Object.entries(p.plugin_versions || {})
    .map(([k, v]) => `${k}@${v}`)
    .join(", ");
  const correlation = event.event_id || "(none — pre-dates event ids)";
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
    "## Full context",
    "",
    "This repo is public, so the triggering prompt is deliberately not reproduced",
    "here. It was captured by telemetry and is available to look up in the admin",
    "DB by the ids below.",
    "",
    `- Event id: \`${correlation}\``,
    ...(p.session_id ? [`- Session id: \`${p.session_id}\``] : []),
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
    addOccurrence(repo, cached, props, event.event_id);
    return;
  }

  // 2. GitHub search across open AND closed issues — a recurrence of something
  //    already closed is important signal, and this is what dedups across
  //    different developers' machines.
  //
  //    Must test the exit code, not the output. safeExec returns "" on failure,
  //    which parses to [] — indistinguishable from "searched fine, found
  //    nothing". Any rate limit or network blip therefore read as "no existing
  //    issue" and filed a duplicate. A search that did not run proves nothing,
  //    so abort: the event is already spooled and the next occurrence retries.
  const search = safeExecResult(
    "gh",
    ["issue", "list", "--repo", repo, "--state", "all", "--search", `${fp} in:body`, "--json", "number,state", "--limit", "5"],
    { timeout: 15000 },
  );
  if (!search.ok) return;
  const matches = parseJson(search.stdout, []);
  const hit = Array.isArray(matches) ? matches[0] : null;

  if (hit && hit.number) {
    addOccurrence(repo, hit.number, props, event.event_id);
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
