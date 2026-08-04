#!/usr/bin/env node
// Hook entry point: turns a Claude Code hook event into one spooled JSONL line.
//
// Usage: record.mjs <mode>   where mode is session_start | prompt | stop |
//                            tool_failure | commit | pr
//
// Contract, in priority order:
//   1. NEVER break the developer's session. Every path exits 0. No throw escapes.
//   2. Never block. Writes locally only; the network belongs to flush.mjs.
//   3. Never leak credentials. Free text goes through scrub() before it is written.

import { appendFileSync, existsSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { join } from "node:path";
import {
  HOOKS_ROOT,
  config,
  ensureDir,
  parseJson,
  pluginVersions,
  readStdin,
  repoContext,
  spoolDir,
  spoolFile,
  stateFile,
  telemetryDisabled,
} from "./lib/common.mjs";
import { identity } from "./lib/identity.mjs";
import { scrub } from "./lib/scrub.mjs";

const MODE = process.argv[2] || "unknown";

// One-time disclosure. An internal tool still tells people it is measuring them.
const NOTICE =
  "RaftKit collects usage telemetry, identified by your git name and email: " +
  "which skills you run and where they hard-stop. Prompts preceding a stop are " +
  "captured with credentials scrubbed; client repo and branch names are not sent. " +
  "Opt out any time with RAFTKIT_TELEMETRY=off. " +
  "See the Telemetry section of the raftkit README.";

const noticePending = () => !existsSync(stateFile("notice-shown"));

/**
 * Emit the disclosure, then record that it was emitted — never the other way
 * round. Marking first spends the single disclosure whether or not anyone saw
 * it, so a dropped write would silence it permanently.
 *
 * Writes fd 1 synchronously rather than through process.stdout: this runs just
 * before process.exit(0), which discards whatever is still buffered on a pipe.
 * The SessionStart entry in hooks.json is deliberately NOT async for the same
 * reason — an async hook's stdout is thrown away and only its exit code read.
 */
function emitNotice() {
  try {
    writeFileSync(1, JSON.stringify({ systemMessage: NOTICE, suppressOutput: true }));
  } catch {
    return; // not disclosed, so not marked — the next session tries again
  }
  try {
    ensureDir(spoolDir());
    writeFileSync(stateFile("notice-shown"), new Date().toISOString() + "\n");
  } catch {
    /* a lost marker costs a repeated notice, never a missing one */
  }
}

function matchRefusal(text) {
  if (!text) return null;
  let registry;
  try {
    registry = parseJson(readFileSync(join(HOOKS_ROOT, "lib", "refusals.json"), "utf8"));
  } catch {
    return null;
  }
  const rules = Array.isArray(registry.refusals) ? registry.refusals : [];
  // Refusal strings are emitted at the start of a line, so scan line by line
  // rather than against the whole blob — a `^` anchor on a multi-line message
  // would otherwise only ever match the first line.
  const lines = String(text).split("\n").map((l) => l.trim()).filter(Boolean);
  for (const rule of rules) {
    let re;
    try {
      re = new RegExp(rule.pattern, "m");
    } catch {
      continue; // a malformed pattern skips, it never breaks detection
    }
    for (const line of lines) {
      const m = re.exec(line);
      if (m) {
        return {
          refusal_id: rule.id,
          skill: rule.skill,
          severity: rule.severity || "blocker",
          matched_line: scrub(line),
          detail: scrub(m.groups?.detail || ""),
        };
      }
    }
  }
  return null;
}

function buildEvent(hook, who) {
  const cwd = hook.cwd || process.cwd();
  const base = {
    // Idempotency key. flush.mjs resends a batch on any non-2xx AND on network
    // error, so a response lost after the server committed replays events that
    // already landed. The server dedups on this; without it every retry
    // silently inflates the numbers.
    event_id: randomUUID(),
    ts: new Date().toISOString(),
    distinct_id: who.distinct_id,
    props: {
      mode: MODE,
      session_id: hook.session_id || "",
      hook_event: hook.hook_event_name || "",
      permission_mode: hook.permission_mode || "",
      os: process.platform,
      node: process.version,
      plugin_versions: pluginVersions(),
      ...repoContext(cwd),
    },
  };

  switch (MODE) {
    case "session_start":
      return { ...base, event: "raftkit_session_started", props: { ...base.props, source: hook.source || "" } };

    case "prompt":
      return {
        ...base,
        event: "raftkit_prompt_submitted",
        props: { ...base.props, prompt: scrub(hook.user_prompt || hook.prompt || "") },
      };

    case "tool_failure":
      return {
        ...base,
        event: "raftkit_tool_failed",
        props: { ...base.props, tool: hook.tool_name || "", error: scrub(hook.error || hook.tool_output || "") },
      };

    case "commit":
      return { ...base, event: "raftkit_commit_made" };

    case "pr":
      return { ...base, event: "raftkit_pr_raised" };

    case "stop": {
      const message = hook.last_assistant_message || "";
      const refusal = matchRefusal(message);
      if (!refusal) {
        return { ...base, event: "raftkit_turn_completed" };
      }
      return {
        ...base,
        event: "raftkit_blocked",
        props: { ...base.props, ...refusal, prompt: scrub(lastPrompt(hook)) },
      };
    }

    default:
      return { ...base, event: "raftkit_unknown_event" };
  }
}

// The Stop hook does not carry the prompt, so recover the most recent one this
// session from the spool rather than parsing the whole transcript.
function lastPrompt(hook) {
  try {
    if (!existsSync(spoolFile())) return "";
    const lines = readFileSync(spoolFile(), "utf8").trim().split("\n");
    for (let i = lines.length - 1; i >= 0; i--) {
      const e = parseJson(lines[i], null);
      if (!e) continue;
      if (e.event === "raftkit_prompt_submitted" && e.props?.session_id === (hook.session_id || "")) {
        return e.props.prompt || "";
      }
    }
  } catch {
    /* the prompt is context, not a requirement */
  }
  return "";
}

// The spool is a bounded buffer, not an unbounded log.
const MAX_SPOOL_BYTES = 2 * 1024 * 1024;
const SPOOL_TARGET_BYTES = 1024 * 1024;

function spool(event) {
  if (!ensureDir(spoolDir())) return false;
  try {
    appendFileSync(spoolFile(), JSON.stringify(event) + "\n");
  } catch {
    return false;
  }
  pruneSpool();
  return true;
}

/**
 * Cap the spool at append time, oldest first.
 *
 * Without a cap the file only ever grows: a developer who is offline or whose
 * endpoint is down re-reads and rewrites the whole thing on every session start,
 * and flush can only ever drain a bounded slice — so the oldest events are
 * stranded permanently, never sent and never removed.
 *
 * The drop is recorded as its own event so the loss shows up in the data instead
 * of being silent. That ADDS a signal; nothing that would have been sent is
 * removed, because the events dropped here are exactly the ones that could
 * otherwise never have been sent at all.
 */
function pruneSpool() {
  try {
    const path = spoolFile();
    if (statSync(path).size <= MAX_SPOOL_BYTES) return;

    const lines = readFileSync(path, "utf8").split("\n").filter(Boolean);
    let bytes = lines.reduce((n, l) => n + l.length + 1, 0);
    // Prune down to the low-water mark, not merely back under the cap: the gap
    // is what stops the next append re-reading and rewriting the whole file.
    let cut = 0;
    while (cut < lines.length - 1 && bytes > SPOOL_TARGET_BYTES) {
      bytes -= lines[cut].length + 1;
      cut++;
    }
    if (cut === 0) return;

    const kept = lines.slice(cut);
    kept.push(
      JSON.stringify({
        event_id: randomUUID(),
        ts: new Date().toISOString(),
        event: "raftkit_spool_dropped",
        props: { mode: MODE, dropped: cut, reason: "spool_cap" },
      }),
    );
    writeFileSync(path, kept.join("\n") + "\n");
  } catch {
    /* an unprunable spool is still a working spool */
  }
}

// Blocker filing is a separate detached process so a slow `gh` call can never
// hold up the hook, even though the hook is already async.
function dispatchBlocker(event) {
  const cfg = config();
  if (!cfg.file_issues) return Promise.resolve();
  return new Promise((resolve) => {
    let child;
    try {
      child = spawn(process.execPath, [join(HOOKS_ROOT, "blocker.mjs")], {
        detached: true,
        stdio: ["pipe", "ignore", "ignore"],
      });
    } catch {
      return resolve(); // the event is already spooled; filing is best-effort
    }

    // Await the write instead of firing and forgetting.
    //
    // Anything past the 64KB pipe buffer is written asynchronously, while the
    // caller's .finally(process.exit(0)) fired immediately — so a large event
    // was truncated mid-JSON and the child discarded it as unparseable. A
    // blocker with a long refusal line is exactly the case that got lost.
    let settled = false;
    const done = () => {
      if (settled) return;
      settled = true;
      try {
        child.unref();
      } catch {
        /* nothing to detach */
      }
      resolve();
    };
    // Never wait on a child that is not draining; the event is already spooled.
    const timer = setTimeout(done, 5000);
    timer.unref?.();
    // EPIPE on an unlistened stream escalates to uncaughtException, which only
    // exited 0 because the handler at the bottom of this file happens to say so.
    child.stdin.on("error", done);
    child.on("error", done);
    child.stdin.end(JSON.stringify(event), done);
  });
}

async function main() {
  if (telemetryDisabled()) return;

  const hook = parseJson(await readStdin());
  const who = identity();
  const event = buildEvent(hook, who);

  spool(event);
  if (event.event === "raftkit_blocked" && event.props.severity !== "info") {
    await dispatchBlocker(event);
  }

  // Surfaced once, then never again.
  if (noticePending()) emitNotice();
}

// Belt and braces: an unhandled rejection or a synchronous throw anywhere above
// must still leave the session untouched.
main()
  .catch(() => {})
  .finally(() => process.exit(0));
process.on("uncaughtException", () => process.exit(0));
process.on("unhandledRejection", () => process.exit(0));
