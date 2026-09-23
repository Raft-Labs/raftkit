#!/usr/bin/env node
// Hook entry point: turns a Claude Code hook event into one spooled JSONL line
// (two at session start, when Claude Code's ledger has a new entry to send).
//
// Usage: record.mjs <mode>   where mode is session_start | prompt | stop |
//                            tool_failure | commit | pr | skill
//
// Contract, in priority order:
//   1. NEVER break the developer's session. Every path exits 0. No throw escapes.
//   2. Never block. Writes locally only; the network belongs to flush.mjs.
//   3. Never leak credentials. Free text goes through scrub() before it is written.
//   4. Free text leaves only from a session that ran a RaftKit skill (README,
//      Telemetry). Elsewhere a prompt or tool failure is recorded without it.

import { appendFileSync, readdirSync, readFileSync, statSync, unlinkSync, writeFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { join } from "node:path";
import {
  HOOKS_ROOT,
  clampText,
  ensureDir,
  parseJson,
  pluginVersions,
  readJsonFile,
  readStdin,
  repoContext,
  sessionsDir,
  sha,
  skillSha12,
  spoolDir,
  spoolFile,
  stateFile,
  telemetryDisabled,
  writeJsonFile,
} from "./lib/common.mjs";
import { identity } from "./lib/identity.mjs";
import { scrub } from "./lib/scrub.mjs";
import { closeJourney, journeyProps, loadSession, noteSkill, notePrompt, saveSession } from "./lib/journey.mjs";
import { ledgerCost, runTokens } from "./lib/tokens.mjs";

const MODE = process.argv[2] || "unknown";

// One-time disclosure. An internal tool still tells people it is measuring them.
// It must say what record() actually keeps: free text only where RaftKit ran.
const NOTICE =
  "RaftKit collects usage telemetry, identified by your git name and email: " +
  "which skills you run, where they stop, what each run costs in tokens, and the repository and branch you are in. " +
  "In a session where a RaftKit skill runs, your prompts and failed-tool errors are captured too, shortened and with credentials scrubbed. " +
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

// While the server keeps refusing flushes, say so once a day: a wedged spool
// is otherwise invisible until someone looks at an empty dashboard.
const WARN_EVERY_MS = 24 * 60 * 60 * 1000;

/** The stuck-delivery line, or "" when delivery is healthy or it was shown today. */
function flushWarningDue() {
  try {
    const err = parseJson(readFileSync(stateFile("last-flush-error"), "utf8"));
    const since = typeof err.ts === "string" ? err.ts.slice(0, 10) : "";
    if (!/^\d{4}-\d{2}-\d{2}$/.test(since)) return "";
    let shown = 0;
    try {
      shown = Number(readFileSync(stateFile("flush-warning-shown"), "utf8").trim());
    } catch {
      /* never shown */
    }
    if (Number.isFinite(shown) && Date.now() - shown < WARN_EVERY_MS) return "";
    const status = Number.isFinite(err.status) && err.status > 0 ? ` (the server answered ${err.status})` : "";
    return `RaftKit telemetry has not delivered since ${since}${status}. Your events are kept on this machine and retried each session.`;
  } catch {
    return ""; // no error on record
  }
}

/**
 * Emit the session-start messages, then record that each was emitted — never
 * the other way round. Marking first spends the single disclosure whether or
 * not anyone saw it, so a dropped write would silence it permanently.
 *
 * Writes fd 1 synchronously rather than through process.stdout: this runs just
 * before process.exit(0), which discards whatever is still buffered on a pipe.
 * The SessionStart entry in hooks.json is deliberately NOT async for the same
 * reason — an async hook's stdout is thrown away and only its exit code read.
 */
function emitSessionMessages() {
  const notice = noticePending();
  const warning = flushWarningDue();
  const text = [notice ? NOTICE : "", warning].filter(Boolean).join("\n\n");
  if (!text) return;
  try {
    writeFileSync(1, JSON.stringify({ systemMessage: text, suppressOutput: true }));
  } catch {
    return; // not shown, so not marked — the next session tries again
  }
  try {
    ensureDir(spoolDir());
    if (notice) writeFileSync(stateFile("notice-shown"), `${new Date().toISOString()} ${NOTICE_VERSION}\n`);
    if (warning) writeFileSync(stateFile("flush-warning-shown"), String(Date.now()));
  } catch {
    /* a lost marker costs a repeated message, never a missing one */
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

// Where a failed tool's text begins. A Bash failure opens with its exit code.
const EXIT_HEADER = /^Exit code (\d+)[^\n]*\n?/;
const TOOL_ERROR_MAX = 200;

/** A failed tool's exit code, and at most 200 chars of what followed it. */
function toolError(raw) {
  const text = String(raw || "");
  const m = EXIT_HEADER.exec(text);
  // Scrubbed before it is cut: cutting first can halve a token and keep a prefix.
  const error = scrub(m ? text.slice(m[0].length) : text).slice(0, TOOL_ERROR_MAX);
  return m ? { exit_code: Number(m[1]), error } : { error };
}

// The commands the commit and PR hooks exist for. The hooks.json `if` filter
// already narrows them; this second check keeps a Claude Code that predates
// `if` from recording every Bash call as a commit.
const COMMIT_CMD = /(^|[;&|(]\s*)git\s+(?:-[Cc]\s+\S+\s+)*commit\b/;
const PR_CMD = /(^|[;&|(]\s*)gh\s+pr\s+create\b/;

function buildEvent(hook, who, session) {
  const cwd = hook.cwd || process.cwd();
  const ts = new Date().toISOString();
  const base = {
    // Idempotency key. flush.mjs resends a batch on any non-2xx AND on network
    // error, so a response lost after the server committed replays events that
    // already landed. The server dedups on this; without it every retry
    // silently inflates the numbers.
    event_id: randomUUID(),
    ts,
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

    case "prompt": {
      const raw = hook.user_prompt || hook.prompt || "";
      // A background agent's report arrives as a prompt. It is not the human
      // answering the STOP, and it carries the agent's output, so its text is
      // never kept.
      const notification = /^\s*<task-notification>/.test(raw);
      const text = notification ? "" : clampText(scrub(raw));
      const afterGate = !notification && notePrompt(session, text);
      return {
        ...base,
        event: "raftkit_prompt_submitted",
        props: {
          ...base.props,
          // Free text leaves the machine only from a session that ran RaftKit.
          ...(session.skill_seen && text ? { prompt: text } : {}),
          prompt_kind: notification ? "task_notification" : "human",
          // The first human prompt after a run's STOP, so the dashboard can
          // classify this reply as go / edit / abandon.
          after_gate: afterGate,
        },
      };
    }

    case "tool_failure": {
      const { error, ...code } = toolError(hook.error || hook.tool_output);
      return {
        ...base,
        event: "raftkit_tool_failed",
        // An error can quote file contents, so its text, like a prompt's, is
        // kept only in a session that ran RaftKit. The exit code is not text.
        props: { ...base.props, tool: hook.tool_name || "", ...code, ...(session.skill_seen && error ? { error } : {}) },
      };
    }

    // Which skills actually get used — the question telemetry exists to answer.
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
      const legacy = skillAlias(bare);
      // Only RaftKit's own plugins are RaftKit usage. A skill from any other
      // installed plugin (or a client's private skill) is silently skipped —
      // the dashboard measures RaftKit adoption, not everything installed.
      if (!ns.startsWith("raftkit-")) return null;
      let listing;
      const opened = noteSkill(session, name, {
        typed: Boolean(hook.command_name),
        // The run's token baseline, so the stop event can say what this run
        // cost rather than what the whole session has.
        start: () => {
          const { listing: seen, ...t } = runTokens(hook.transcript_path, hook.session_id) || {};
          listing = seen;
          return { skill_sha12: skillSha12(name), started_at: ts, base_total: Number.isFinite(t.total) ? t.total : null };
        },
      });
      return {
        ...base,
        event: "raftkit_skill_invoked",
        props: {
          ...base.props,
          skill: name,
          skill_plugin: ns,
          skill_name: bare,
          ...(legacy ? { legacy_name: legacy } : {}),
          invocation: hook.command_name ? "typed" : "model",
          journey_start: opened,
          // This skill's own text, which differs from the journey's when nested.
          invoked_sha12: opened ? session.journey.skill_sha12 : skillSha12(name),
          args: clampText(scrub(hook.command_args || "")),
          ...(listing ? { listing } : {}),
        },
      };
    }

    case "commit":
      if (!COMMIT_CMD.test(String(hook.tool_input?.command || ""))) return null;
      return { ...base, event: "raftkit_commit_made" };

    case "pr": {
      if (!PR_CMD.test(String(hook.tool_input?.command || ""))) return null;
      const pr = /\/pull\/(\d+)/.exec(JSON.stringify(hook.tool_response ?? ""));
      return { ...base, event: "raftkit_pr_raised", props: { ...base.props, ...(pr ? { pr_number: Number(pr[1]) } : {}) } };
    }

    case "stop": {
      const message = hook.last_assistant_message || "";
      // A STOP or refusal line is RaftKit's only when a RaftKit skill ran in
      // this session; anywhere else it is some other tool's prose.
      const refusal = session.skill_seen ? matchRefusal(message) : null;
      // Measured, not reported: the transcript's own usage, charted instead of
      // trusted. Carried on the stop event rather than spooled as one of its
      // own: the spool is a capped buffer, and a second line per turn would
      // evict real raftkit_blocked events.
      const { listing, ...measured } = runTokens(hook.transcript_path, hook.session_id) || {};
      let tokens = null;
      if (Object.keys(measured).length) {
        const baseTotal = session.journey?.base_total;
        tokens = Number.isFinite(baseTotal) ? { ...measured, run_total: measured.total - baseTotal } : measured;
      }
      const props = {
        ...base.props,
        // A turn forced by another plugin's Stop hook, not a human-paced one.
        stop_hook_active: hook.stop_hook_active === true,
        ...(tokens ? { tokens } : {}),
        ...(listing ? { listing } : {}),
      };
      if (!refusal) {
        return { ...base, event: "raftkit_turn_completed", props };
      }
      // The catch-all "Can't …" is recorded but does not end the run: a plan
      // message can say that mid-run.
      const gate = refusal.severity === "gate";
      if (gate || refusal.refusal_id !== "generic-cant") closeJourney(session, { gate, ts });
      // The one human stop per run is not a blocker: it is the moment the
      // human decides. Recorded separately so the dashboard can pair it with
      // the next prompt (go / edit / abandon) instead of counting it as a stop.
      if (gate) {
        return { ...base, event: "raftkit_gate_shown", props: { ...props, ...refusal } };
      }
      return {
        ...base,
        event: "raftkit_blocked",
        props: { ...props, ...refusal, prompt: session.last_prompt || "" },
      };
    }

    default:
      return { ...base, event: "raftkit_unknown_event" };
  }
}

// v2 skill name -> the v1 name it replaced, so dashboard series stay
// continuous across the rename. Missing file or name -> no alias, never a throw.
function skillAlias(bare) {
  try {
    const j = parseJson(readFileSync(join(HOOKS_ROOT, "lib", "skill-aliases.json"), "utf8"));
    const v = j?.aliases?.[bare];
    return typeof v === "string" && v !== bare ? v : "";
  } catch {
    return "";
  }
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

// Session state is a working set, not a history: two weeks untouched and it goes.
const SESSION_STATE_TTL_MS = 14 * 24 * 60 * 60 * 1000;

function pruneSessionState() {
  try {
    unlinkSync(stateFile("tokens.json")); // the pre-v2.1 single-file token state
  } catch {
    /* already gone */
  }
  let names = [];
  try {
    names = readdirSync(sessionsDir());
  } catch {
    return;
  }
  const cutoff = Date.now() - SESSION_STATE_TTL_MS;
  for (const name of names) {
    const path = join(sessionsDir(), name);
    try {
      if (statSync(path).mtimeMs < cutoff) unlinkSync(path);
    } catch {
      /* raced with another session's prune */
    }
  }
}

/**
 * The previous session's cost from Claude Code's own ledger, once per ledger
 * entry. The ledger is keyed by project directory, which hooks receive as
 * CLAUDE_PROJECT_DIR; cwd covers a runtime that does not set it. Never a
 * parent directory: that is another project's ledger.
 */
function ledgerEvent(hook, base) {
  const dirs = [process.env.CLAUDE_PROJECT_DIR, hook.cwd].filter((d) => typeof d === "string" && d !== "");
  const cost = ledgerCost(dirs);
  if (!cost) return null;
  const key = `${cost.cost_session_id}@${cost.started_at}`;
  const sent = readJsonFile(stateFile("ledger-sent.json"), {}).keys;
  if (Array.isArray(sent) && sent.includes(key)) return null;
  return { key, sent: Array.isArray(sent) ? sent : [], event: { ...base, event_id: randomUUID(), event: "raftkit_session_cost", props: { ...base.props, ...cost } } };
}

async function main() {
  if (telemetryDisabled()) return;

  const hook = parseJson(await readStdin());
  const who = identity();
  const session = loadSession(hook.session_id);
  const event = buildEvent(hook, who, session);
  // Every event of a run carries the run's id and the text it ran.
  if (event) event.props = { ...event.props, ...journeyProps(session) };
  // Merged into the file as it is now, not written back as loaded: this
  // session's other hooks may have saved since (see lib/journey.mjs).
  saveSession(hook.session_id, session);

  // null means "not telemetry at all" (see the skill case above) — the spool
  // must stay byte-for-byte untouched, not gain a junk line.
  if (event) spool(event);

  if (MODE === "session_start" && event) {
    pruneSessionState();
    const ledger = ledgerEvent(hook, event);
    // Marked sent only once spooled, so a failed write retries next session.
    if (ledger && spool(ledger.event)) writeJsonFile(stateFile("ledger-sent.json"), { keys: [...ledger.sent, ledger.key].slice(-50) });
  }

  // The disclosure is surfaced once, then never again; the stuck-delivery
  // line at most once a day. Both only from the SessionStart hook, the one
  // synchronous record hook: any other hook's output is discarded, and
  // marking either shown there would spend it unseen.
  if (MODE === "session_start") emitSessionMessages();
}

// Belt and braces: an unhandled rejection or a synchronous throw anywhere above
// must still leave the session untouched.
main()
  .catch(() => {})
  .finally(() => process.exit(0));
process.on("uncaughtException", () => process.exit(0));
process.on("unhandledRejection", () => process.exit(0));
