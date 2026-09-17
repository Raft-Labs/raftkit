// Token accounting for a run, read from the session transcript.
//
// Why this exists: the implement skill asks the model to report "the run's
// token total" in prose at the stop. Prose is not a measurement — it cannot be
// charted, compared against last week, or used to check whether a change
// (the bulk-read shunt, a model tier) actually saved anything. The transcript
// already carries per-message `usage` from the API, so the number is there to
// be read rather than estimated.
//
// The split that matters is main thread vs sidechain: a subagent's messages
// are flagged `isSidechain`, so delegating work to a cheap model shows up as
// main-thread tokens falling while sidechain tokens rise. A single total would
// hide exactly the effect the delegation is for.
//
// Read incrementally. Stop fires on every turn, and re-parsing a transcript
// that grows to tens of megabytes would cost more than the thing it measures,
// so each read resumes from the byte offset the last one finished at.

import { closeSync, openSync, readSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { ensureDir, dataDir, parseJson, stateFile } from "./common.mjs";

// A single catch-up read. Beyond this the tail is taken and the result marked
// partial: an approximate number that arrives is worth more than an exact one
// that times out the hook.
const MAX_CATCHUP_BYTES = 32 * 1024 * 1024;

// Sessions kept in the state file. Enough for a few concurrent windows;
// without a cap the file grows for the life of the machine.
const MAX_SESSIONS = 8;

const EMPTY = () => ({
  input: 0,
  output: 0,
  cache_read: 0,
  cache_creation: 0,
  main: 0,
  sidechain: 0,
  by_tier: {},
  messages: 0,
});

/** Model id to the tier vocabulary the working agreement uses. */
export function tierOf(model) {
  const m = String(model || "").toLowerCase();
  if (m.includes("haiku")) return "haiku";
  if (m.includes("sonnet")) return "sonnet";
  if (m.includes("opus")) return "opus";
  if (m.includes("fable")) return "fable";
  return m ? "other" : "unknown";
}

/**
 * Fold one transcript line into the running totals.
 *
 * Silently ignores any line without usage — user turns, tool results, summary
 * records and the partial line at the end of a file being written to.
 */
function fold(totals, line) {
  const rec = parseJson(line, null);
  const usage = rec?.message?.usage;
  if (!usage) return;

  const input = num(usage.input_tokens);
  const output = num(usage.output_tokens);
  const cacheRead = num(usage.cache_read_input_tokens);
  const cacheCreation = num(usage.cache_creation_input_tokens);
  const billed = input + output + cacheRead + cacheCreation;

  totals.input += input;
  totals.output += output;
  totals.cache_read += cacheRead;
  totals.cache_creation += cacheCreation;
  totals.messages += 1;
  if (rec.isSidechain === true) totals.sidechain += billed;
  else totals.main += billed;

  const tier = tierOf(rec.message?.model);
  totals.by_tier[tier] = (totals.by_tier[tier] || 0) + billed;
}

const num = (v) => (Number.isFinite(v) ? v : 0);

/** Bytes from `offset` to EOF, and the offset actually consumed. */
function readFrom(path, offset) {
  const size = statSync(path).size;
  // A transcript that shrank was rotated or replaced; the stored offset points
  // into a different file and resuming from it would fold garbage.
  const from = size < offset ? 0 : offset;
  const want = size - from;
  if (want <= 0) return { text: "", end: size, reset: from === 0 && offset !== 0, partial: false };

  const partial = want > MAX_CATCHUP_BYTES;
  const start = partial ? size - MAX_CATCHUP_BYTES : from;
  const length = size - start;
  const fd = openSync(path, "r");
  try {
    const buf = Buffer.allocUnsafe(length);
    readSync(fd, buf, 0, length, start);
    return { text: buf.toString("utf8"), end: size, reset: from === 0 && offset !== 0, partial };
  } finally {
    closeSync(fd);
  }
}

function loadState() {
  try {
    return parseJson(readFileSync(stateFile("tokens.json"), "utf8"));
  } catch {
    return {};
  }
}

function saveState(state) {
  try {
    const entries = Object.entries(state)
      .sort((a, b) => (b[1]?.seen || 0) - (a[1]?.seen || 0))
      .slice(0, MAX_SESSIONS);
    ensureDir(dataDir());
    writeFileSync(stateFile("tokens.json"), JSON.stringify(Object.fromEntries(entries)) + "\n");
  } catch {
    /* an uncached offset costs a re-read, never a wrong number */
  }
}

/**
 * Totals for this session so far, or null when they cannot be established.
 *
 * null, never zeros: a transcript that could not be read is an absence of
 * measurement, and recording it as 0 tokens would quietly poison every average
 * built on top of it.
 */
export function runTokens(transcriptPath, sessionId) {
  if (typeof transcriptPath !== "string" || transcriptPath === "" || !sessionId) return null;
  try {
    const state = loadState();
    const prior = state[sessionId];
    const totals = prior?.totals ? { ...EMPTY(), ...prior.totals, by_tier: { ...prior.totals.by_tier } } : EMPTY();

    const { text, end, reset, partial } = readFrom(transcriptPath, prior?.offset || 0);
    const fresh = reset ? EMPTY() : totals;
    // A file still being appended to ends mid-line; fold whole lines only and
    // stop the offset short of the remainder so the next read picks it up.
    const lines = text.split("\n");
    const tail = lines.pop() ?? "";
    for (const line of lines) if (line) fold(fresh, line);
    const consumed = end - Buffer.byteLength(tail, "utf8");

    const everPartial = partial || Boolean(prior?.partial);
    state[sessionId] = { offset: consumed, totals: fresh, seen: Date.now(), partial: everPartial };
    saveState(state);

    return {
      ...fresh,
      total: fresh.main + fresh.sidechain,
      partial: everPartial,
    };
  } catch {
    return null;
  }
}
