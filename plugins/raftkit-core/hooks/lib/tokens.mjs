// Token accounting for a session, read from its transcripts.
//
// Why this exists: a skill asked to state "the run's token total" in prose is
// guessing — the model cannot see the number. The transcripts carry per-message
// `usage` from the API, so the number is there to be read rather than estimated.
//
// What the transcripts actually look like (measured, CLI 2.1.280):
//   - One assistant message is written as several consecutive lines that
//     repeat its usage. Summing lines over-counts 1.7-2.4x, so each message is
//     counted once, from the LAST line carrying its message.id.
//   - Subagents never appear in the main file. Each has its own transcript
//     under <dirname(transcript)>/<session>/subagents/, workflow agents one
//     level deeper, with its agentType in a sibling agent-*.meta.json. Their
//     early lines carry placeholder usage, which the last-line rule replaces.
//   - A fork copies its parent's records, rewritten to the fork's own
//     sessionId but keeping the parent's timestamps, then records its own
//     SessionStart:fork hook. Everything above that line is the parent's.
//   - Rarely, top-level usage is all zeros with the real numbers in
//     `usage.iterations`.
//
// The split that matters is main thread vs subagents: delegating work to a
// cheaper model shows up as main-thread tokens falling while subagent tokens
// rise. A single total would hide exactly the effect the delegation is for.
//
// Two readers share the fold: runTokens() resumes from stored byte offsets,
// because Stop fires every turn and a transcript reaches tens of megabytes;
// measureSession() reads everything once and writes nothing, for run-tokens.mjs.

import { closeSync, existsSync, openSync, readdirSync, readFileSync, readSync, statSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { claudeConfigDir, parseJson, readJsonFile, sessionFile, writeJsonFile } from "./common.mjs";

// A single catch-up read. Beyond this the tail is taken and the result marked
// partial: an approximate number that arrives is worth more than an exact one
// that times out the hook.
const MAX_CATCHUP_BYTES = 32 * 1024 * 1024;

/** Model id to the tier vocabulary the working agreement uses. */
export function tierOf(model) {
  const m = String(model || "").toLowerCase();
  if (m.includes("haiku")) return "haiku";
  if (m.includes("sonnet")) return "sonnet";
  if (m.includes("opus")) return "opus";
  if (m.includes("fable")) return "fable";
  return m ? "other" : "unknown";
}

const num = (v) => (Number.isFinite(v) ? v : 0);
const emptySums = () => ({ input: 0, output: 0, cache_read: 0, cache_creation: 0, billed: 0, side_billed: 0, messages: 0, by_model: {} });
const newPart = (side, agent = "") => ({ offset: 0, side, agent, since: 0, pending: null, sums: emptySums() });

function usageOf(usage) {
  let u = {
    i: num(usage.input_tokens),
    o: num(usage.output_tokens),
    cr: num(usage.cache_read_input_tokens),
    cc: num(usage.cache_creation_input_tokens),
  };
  if (u.i + u.o + u.cr + u.cc === 0 && Array.isArray(usage.iterations)) {
    u = { i: 0, o: 0, cr: 0, cc: 0 };
    for (const it of usage.iterations) {
      u.i += num(it?.input_tokens);
      u.o += num(it?.output_tokens);
      u.cr += num(it?.cache_read_input_tokens);
      u.cc += num(it?.cache_creation_input_tokens);
    }
  }
  return u;
}

/** Fold the message held open into the part's sums. */
function commit(part) {
  const p = part.pending;
  if (!p) return;
  add(part.sums, p);
  part.pending = null;
}

function add(sums, p) {
  const billed = p.i + p.o + p.cr + p.cc;
  sums.input += p.i;
  sums.output += p.o;
  sums.cache_read += p.cr;
  sums.cache_creation += p.cc;
  sums.billed += billed;
  if (p.side) sums.side_billed += billed;
  sums.messages += 1;
  if (billed > 0) sums.by_model[p.model] = (sums.by_model[p.model] || 0) + billed;
}

/** RaftKit entries in a skill_listing attachment, and which kept a description. */
export function listingCoverage(attachment) {
  const names = Array.isArray(attachment?.names) ? attachment.names.filter((n) => /^raftkit-/.test(String(n))) : [];
  const lines = String(attachment?.content || "").split("\n");
  const described = names.filter((n) => lines.some((l) => l.startsWith(`- ${n}: `)));
  return { raftkit: names.length, described };
}

const isForkStart = (rec) =>
  rec?.type === "attachment" &&
  rec.attachment?.hookEvent === "SessionStart" &&
  /:fork$/.test(String(rec.attachment?.hookName || ""));

/**
 * Fold one transcript line into a part. Lines that are neither usage nor an
 * attachment are skipped before parsing, which is most of any transcript.
 * Returns a skill_listing's coverage when the line is one.
 */
function foldLine(part, line, floor) {
  if (!line.includes('"usage"') && !line.includes('"attachment"')) return null;
  const rec = parseJson(line, null);
  if (!rec) return null;
  if (rec.type === "attachment") {
    if (!part.side && isForkStart(rec)) {
      // Everything above this line is the parent's history.
      part.pending = null;
      part.sums = emptySums();
      part.since = Date.parse(rec.timestamp) || 0;
      return null;
    }
    return rec.attachment?.type === "skill_listing" ? listingCoverage(rec.attachment) : null;
  }
  const usage = rec.message?.usage;
  if (!usage || typeof usage !== "object") return null;
  const since = Math.max(part.since || 0, floor || 0);
  const at = Date.parse(rec.timestamp);
  if (since && Number.isFinite(at) && at < since) return null;
  const id = String(rec.message.id || rec.uuid || "");
  const next = { id, ...usageOf(usage), model: String(rec.message.model || "unknown"), side: part.side || rec.isSidechain === true };
  if (part.pending && id && part.pending.id === id) {
    part.pending = next; // the last line of a message carries its final usage
    return null;
  }
  commit(part);
  part.pending = next;
  return null;
}

/**
 * Fold a file from the part's stored offset to EOF. A shrunken file was
 * replaced, so it is read from the start. `cap` bounds one read (0: no cap).
 */
function foldFile(part, path, { cap = 0, floor = 0 } = {}) {
  const size = statSync(path).size;
  if (size < part.offset) Object.assign(part, newPart(part.side, part.agent));
  const want = size - part.offset;
  if (want <= 0) return { listing: null, partial: false };
  const partial = cap > 0 && want > cap;
  const start = partial ? size - cap : part.offset;
  const fd = openSync(path, "r");
  let text;
  try {
    const buf = Buffer.allocUnsafe(size - start);
    readSync(fd, buf, 0, size - start, start);
    text = buf.toString("utf8");
  } finally {
    closeSync(fd);
  }
  // A file still being appended to ends mid-line; fold whole lines only and
  // stop the offset short of the remainder so the next read picks it up.
  const lines = text.split("\n");
  const tail = lines.pop() ?? "";
  let listing = null;
  for (const line of lines) {
    if (!line) continue;
    const found = foldLine(part, line, floor);
    if (found) listing = found;
  }
  part.offset = size - Buffer.byteLength(tail, "utf8");
  return { listing, partial };
}

function walk(dir) {
  let out = [];
  let entries = [];
  try {
    entries = readdirSync(dir, { withFileTypes: true });
  } catch {
    return out;
  }
  for (const e of entries) {
    const p = join(dir, e.name);
    if (e.isDirectory()) out = out.concat(walk(p));
    else if (e.name.endsWith(".jsonl")) out.push(p);
  }
  return out.sort();
}

const subagentRoot = (transcriptPath, sessionId) => join(dirname(transcriptPath), sessionId, "subagents");
const agentTypeOf = (jsonl) =>
  String(readJsonFile(jsonl.replace(/\.jsonl$/, ".meta.json")).agentType || "unknown").slice(0, 80);

/** Fold every subagent file of the session into `files` (keyed by relative path). */
function foldSubagents(files, transcriptPath, sessionId, opts) {
  const root = subagentRoot(transcriptPath, sessionId);
  let unreadable = 0;
  let partial = false;
  for (const path of walk(root)) {
    const key = relative(root, path);
    const part = files[key] || (files[key] = newPart(true, agentTypeOf(path)));
    try {
      partial = foldFile(part, path, opts).partial || partial;
    } catch {
      unreadable += 1; // skipped, and said so
    }
  }
  return { unreadable, partial };
}

/** Totals over the parts, the open message of each included. */
function report(main, files) {
  const out = {
    input: 0, output: 0, cache_read: 0, cache_creation: 0,
    main: 0, sidechain: 0, total: 0, messages: 0,
    by_model: {}, by_tier: {}, by_agent: {},
  };
  for (const part of [main, ...Object.values(files)]) {
    const s = { ...part.sums, by_model: { ...part.sums.by_model } };
    if (part.pending) add(s, part.pending);
    out.input += s.input;
    out.output += s.output;
    out.cache_read += s.cache_read;
    out.cache_creation += s.cache_creation;
    out.messages += s.messages;
    if (part.side) {
      out.sidechain += s.billed;
      out.by_agent[part.agent] = (out.by_agent[part.agent] || 0) + s.billed;
    } else {
      // A main transcript from before subagents had their own files flags them.
      out.main += s.billed - s.side_billed;
      out.sidechain += s.side_billed;
    }
    for (const [m, n] of Object.entries(s.by_model)) out.by_model[m] = (out.by_model[m] || 0) + n;
  }
  for (const [m, n] of Object.entries(out.by_model)) out.by_tier[tierOf(m)] = (out.by_tier[tierOf(m)] || 0) + n;
  out.total = out.main + out.sidechain;
  return out;
}

/**
 * Totals for this session so far, or null when they cannot be established.
 * Incremental: resumes every file from where the last call stopped.
 *
 * null, never zeros: a transcript that could not be read is an absence of
 * measurement, and recording it as 0 tokens would quietly poison every average
 * built on top of it.
 *
 * `listing` is present when this read met a skill_listing attachment. Reads
 * are incremental, so each listing is reported once, not on every turn.
 */
export function runTokens(transcriptPath, sessionId) {
  if (typeof transcriptPath !== "string" || transcriptPath === "" || !sessionId) return null;
  try {
    if (!existsSync(transcriptPath)) return null;
    const statePath = sessionFile(sessionId, "tokens");
    const state = readJsonFile(statePath, {});
    const main = state.main && typeof state.main === "object" ? state.main : newPart(false);
    const files = state.files && typeof state.files === "object" ? state.files : {};

    const read = foldFile(main, transcriptPath, { cap: MAX_CATCHUP_BYTES });
    const subs = foldSubagents(files, transcriptPath, sessionId, { cap: MAX_CATCHUP_BYTES, floor: main.since });
    const partial = Boolean(state.partial) || read.partial || subs.partial;

    const listing = read.listing;
    writeJsonFile(statePath, { main, files, partial });

    return {
      ...report(main, files),
      partial,
      ...(subs.unreadable ? { unreadable: subs.unreadable } : {}),
      ...(listing ? { listing } : {}),
    };
  } catch {
    return null;
  }
}

/**
 * Totals for the session, or for the part of it from `sinceMs` on, read in one
 * pass and written nowhere. null when the transcript cannot be read.
 */
export function measureSession(transcriptPath, sessionId, { sinceMs = 0 } = {}) {
  try {
    const main = newPart(false);
    foldFile(main, transcriptPath, { floor: sinceMs });
    const files = {};
    const subs = foldSubagents(files, transcriptPath, sessionId, { floor: Math.max(sinceMs, main.since) });
    return { ...report(main, files), ...(subs.unreadable ? { unreadable: subs.unreadable } : {}) };
  } catch {
    return null;
  }
}

// ------------------------------------------------------------------ run start

// A skill that opens a run. raftkit-core's skills are loaded by a run (the
// rules, the agreement) and the help commands are not runs at all.
const opensRun = (name) =>
  /^raftkit-[a-z0-9-]+:[a-z0-9-]+$/.test(name) && !name.startsWith("raftkit-core:") && !name.endsWith(":help");

let closers;
/**
 * Lines that end a run: the one STOP, or a skill's own refusal. The catch-all
 * "Can't …" is left out, because a plan message can say that mid-run.
 */
function runClosers() {
  if (closers) return closers;
  closers = [];
  try {
    const registry = parseJson(readFileSync(join(dirname(fileURLToPath(import.meta.url)), "refusals.json"), "utf8"));
    for (const r of registry.refusals || []) {
      if (r.id === "generic-cant") continue;
      try {
        closers.push(new RegExp(r.pattern, "m"));
      } catch {
        /* a malformed pattern closes nothing */
      }
    }
  } catch {
    /* no registry: a run then lasts to the end of the transcript */
  }
  return closers;
}

const closesRun = (text) =>
  String(text)
    .split("\n")
    .map((l) => l.trim())
    .some((l) => l && runClosers().some((re) => re.test(l)));

/**
 * When the current RaftKit run began, in ms, or 0 for "count the session".
 *
 * A run opens at a RaftKit skill invocation and closes at its STOP or refusal.
 * An invocation while a run is open (implement loading scope-guard in its
 * review) belongs to that run; a typed slash command always starts a new one.
 */
export function runStart(transcriptPath) {
  let start = 0;
  let open = false;
  let text = "";
  try {
    text = readFileSync(transcriptPath, "utf8");
  } catch {
    return 0;
  }
  for (const line of text.split("\n")) {
    if (!line.includes("raftkit-") && !line.includes('"text"') && !line.includes("SessionStart:fork")) continue;
    const rec = parseJson(line, null);
    if (!rec) continue;
    const at = Date.parse(rec.timestamp) || 0;
    if (isForkStart(rec)) {
      start = 0;
      open = false;
      continue;
    }
    const content = rec.message?.content;
    if (rec.type === "user") {
      const typed = typeof content === "string" ? content : Array.isArray(content) ? content.map((b) => b?.text || "").join("") : "";
      const m = /<command-name>\/?([^<\s]+)<\/command-name>/.exec(typed);
      if (m && opensRun(m[1])) {
        start = at;
        open = true;
      }
      continue;
    }
    if (rec.type !== "assistant" || !Array.isArray(content)) continue;
    for (const block of content) {
      if (block?.type === "tool_use" && block.name === "Skill" && opensRun(String(block.input?.skill || ""))) {
        if (!open) {
          start = at;
          open = true;
        }
      } else if (block?.type === "text" && open && closesRun(block.text || "")) {
        open = false;
      }
    }
  }
  return start;
}

/** The newest transcript for a session id under Claude Code's projects dir, or "". */
export function findTranscript(sessionId) {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(String(sessionId || ""))) return "";
  const projects = join(claudeConfigDir(), "projects");
  let best = "";
  let bestAt = -1;
  let dirs = [];
  try {
    dirs = readdirSync(projects, { withFileTypes: true }).filter((d) => d.isDirectory());
  } catch {
    return "";
  }
  for (const d of dirs) {
    const p = join(projects, d.name, `${sessionId}.jsonl`);
    try {
      const at = statSync(p).mtimeMs;
      if (at > bestAt) {
        best = p;
        bestAt = at;
      }
    } catch {
      /* not in this project */
    }
  }
  return best;
}

// -------------------------------------------------------------- the ledger

/**
 * The previous session's cost as Claude Code itself recorded it for this
 * project, read from its global config (~/.claude.json, or under
 * CLAUDE_CONFIG_DIR). Only the named cost fields are read out; nothing else in
 * that file — credentials, MCP servers, history — is touched. null when there
 * is no ledger or it records nothing.
 */
export function ledgerCost(projectDirs) {
  const path = process.env.CLAUDE_CONFIG_DIR
    ? join(process.env.CLAUDE_CONFIG_DIR, ".claude.json")
    : join(process.env.HOME || ".", ".claude.json");
  let projects;
  try {
    projects = parseJson(readFileSync(path, "utf8")).projects;
  } catch {
    return null;
  }
  if (!projects || typeof projects !== "object") return null;
  const p = (projectDirs || []).map((d) => projects[d]).find((x) => x && typeof x === "object");
  if (!p || typeof p.lastSessionId !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(p.lastSessionId)) return null;
  const byModel = {};
  if (p.lastModelUsage && typeof p.lastModelUsage === "object") {
    for (const [model, u] of Object.entries(p.lastModelUsage)) {
      if (!/^[A-Za-z0-9._:[\]-]{1,80}$/.test(model) || !u || typeof u !== "object") continue;
      byModel[model] = {
        input: num(u.inputTokens),
        output: num(u.outputTokens),
        cache_read: num(u.cacheReadInputTokens),
        cache_creation: num(u.cacheCreationInputTokens),
        cost_usd: num(u.costUSD),
      };
    }
  }
  const cost = {
    cost_session_id: p.lastSessionId,
    started_at: num(p.lastStartTime),
    cost_usd: num(p.lastCost),
    duration_ms: num(p.lastDuration),
    api_duration_ms: num(p.lastAPIDuration),
    input: num(p.lastTotalInputTokens),
    output: num(p.lastTotalOutputTokens),
    cache_read: num(p.lastTotalCacheReadInputTokens),
    cache_creation: num(p.lastTotalCacheCreationInputTokens),
    by_model: byModel,
  };
  const tokens = cost.input + cost.output + cost.cache_read + cost.cache_creation;
  return tokens > 0 || cost.cost_usd > 0 ? { ...cost, total: tokens } : null;
}
