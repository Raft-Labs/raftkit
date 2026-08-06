#!/usr/bin/env node
// Hook entry point: turns a Claude Code hook event into one spooled JSONL line.
//
// Usage: record.mjs <mode>   where mode is session_start | prompt | stop |
//                            tool_failure | commit | pr | skill
//
// Contract, in priority order:
//   1. NEVER break the developer's session. Every path exits 0. No throw escapes.
//   2. Never block. Writes locally only; the network belongs to flush.mjs.
//   3. Never leak credentials. Free text goes through scrub() before it is written.

import { appendFileSync, existsSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { join } from "node:path";
import {
  HOOKS_ROOT,
  ensureDir,
  parseJson,
  pluginVersions,
  readStdin,
  repoContext,
  sha,
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
  "captured with credentials scrubbed, alongside the repository and branch you are in. " +
  "Opt out any time with RAFTKIT_TELEMETRY=off. " +
  "See the Telemetry section of the raftkit README.";

// The one-shot gate is keyed on a hash of the notice's own text, not merely
// on whether the marker file exists. A marker from a pre-upgrade install
// carries no version info (just an ISO timestamp) and so never contains the
// current hash — it therefore does not suppress disclosure. Any future
// wording change flows straight into a new hash and re-discloses
// automatically; the marker's filename is deliberately unchanged.
const NOTICE_VERSION = sha(NOTICE, 12);

const noticePending = () => {
  try {
    return !readFileSync(stateFile("notice-shown"), "utf8").includes(NOTICE_VERSION);
  } catch {
    return true; // no marker (or unreadable one) means undisclosed
  }
};

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
    writeFileSync(stateFile("notice-shown"), `${new Date().toISOString()} ${NOTICE_VERSION}\n`);
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

    // Which skills actually get used — the question telemetry exists to answer.
    //
    // Until this existed, `skill` was only ever populated by matchRefusal(), so
    // a skill was recorded solely when it HARD-STOPPED. Normal, successful use
    // was invisible, and the first-run disclosure's claim that we collect
    // "which skills you run" was not true.
    //
    // Two hooks are needed because there are two ways in, confirmed against a
    // live session: UserPromptExpansion carries `command_name` when a developer
    // types `/raftkit-dev:implement`, and PostToolUse(Skill) carries
    // `tool_input.skill` when the model invokes one itself.
    case "skill": {
      const name = hook.command_name || hook.tool_input?.skill || "";
      if (!name) {
        // A PostToolUse/UserPromptExpansion invocation that never resolves to
        // a name is not a skill event at all — most PostToolUse calls aren't
        // the Skill tool. Recording it as raftkit_unknown_event just fills
        // the spool with junk that, at the cap, evicts real raftkit_blocked
        // events, so it is dropped outright, leaving the spool untouched.
        const isSkillHook = hook.hook_event_name === "PostToolUse" || hook.hook_event_name === "UserPromptExpansion";
        if (isSkillHook) return null;
        // Something reached MODE=skill without even that shape (a malformed
        // or unexpected payload) — record it generically rather than either
        // staying silent or misclassifying it as a skill invocation.
        return { ...base, event: "raftkit_unknown_event" };
      }
      // Split on the FIRST colon only — a bare name can itself contain one
      // (a nested identifier), and split(":") would silently truncate it.
      const sep = name.indexOf(":");
      const ns = sep === -1 ? "" : name.slice(0, sep);
      const bare = sep === -1 ? name : name.slice(sep + 1);
      // Only RaftKit's own plugins are RaftKit usage. A skill from any other
      // installed plugin (or a client's private skill) is silently skipped —
      // the dashboard measures RaftKit adoption, not everything installed.
      if (!ns.startsWith("raftkit-")) return null;
      return {
        ...base,
        event: "raftkit_skill_invoked",
        props: {
          ...base.props,
          skill: name,
          skill_plugin: ns,
          skill_name: bare,
          invocation: hook.command_name ? "typed" : "model",
          args: scrub(hook.command_args || ""),
        },
      };
    }

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

async function main() {
  if (telemetryDisabled()) return;

  const hook = parseJson(await readStdin());
  const who = identity();
  const event = buildEvent(hook, who);

  // null means "not telemetry at all" (see the skill case above) — the spool
  // must stay byte-for-byte untouched, not gain a junk line.
  if (event) spool(event);

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
