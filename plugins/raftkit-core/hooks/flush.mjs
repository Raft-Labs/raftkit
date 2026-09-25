#!/usr/bin/env node
// Drains the local event spool to the RaftLabs admin API.
//
// Runs on SessionStart, async. The spool is drained in batches until it is
// empty; the moment a batch fails, everything still unsent — that batch
// included — goes back on the queue for the next session. An offline or
// rate-limited developer therefore loses nothing and still reports later.
//
// That retry is exactly why every event carries an `event_id`: the server
// dedups on it, so replaying a batch whose response was lost cannot
// double-count. Do not remove one without removing the other.
//
// No credential is sent. The endpoint is a first-party service and ships no key
// to developer machines — see the Telemetry section of the raftkit README.
//
// Like every hook here: never throws, always exits 0.

import { existsSync, readFileSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import {
  acquireLock,
  clampText,
  config,
  endpointUsable,
  ensureDir,
  parseJson,
  sha,
  spoolDir,
  spoolFile,
  stateFile,
  telemetryDisabled,
} from "./lib/common.mjs";
import { githubLogin, identity } from "./lib/identity.mjs";

const MAX_EVENTS = 500; // per request
const MAX_BATCHES = 40; // safety valve: 20k events in one flush, then stop
// The server caps a body at 1,000,000 bytes. The old 5 MB cap let a 1-5 MB
// batch through to a 413 that repeated every session, so it stays well under.
const MAX_BYTES = 900_000;
const MIN_INTERVAL_MS = 60 * 1000; // Don't hammer on rapid session restarts.

// The severities the admin schema accepts. Anything else (the one-stop gate is
// "gate") goes as info with the original kept, because one unknown value used
// to make the server reject the whole batch.
const SEVERITIES = new Set(["blocker", "warning", "info"]);

function recentlyFlushed() {
  try {
    const p = stateFile("last-flush");
    if (!existsSync(p)) return false;
    const last = Number(readFileSync(p, "utf8").trim());
    return Number.isFinite(last) && Date.now() - last < MIN_INTERVAL_MS;
  } catch {
    return false;
  }
}

function markFlushed() {
  try {
    ensureDir(spoolDir());
    writeFileSync(stateFile("last-flush"), String(Date.now()));
  } catch {
    /* non-fatal */
  }
}

/** One spooled line as the event the server receives, or null for a junk line. */
function toEvent(line, who) {
  const e = parseJson(line, null);
  if (!e || !e.event) return null;
  // Back-fill the identity the synchronous path could not resolve: it knows
  // no GitHub login, so an account with no git email spooled as `anon:`.
  // Upgrading here keeps the resolution order identical to what a single
  // synchronous resolve would have produced.
  let distinctId = e.distinct_id || who.distinct_id;
  if (who.gh_login && /^anon:/.test(String(distinctId))) distinctId = `gh:${who.gh_login}`;
  // Clamped here as well as at record time: events spooled by an older
  // version still carry 2,000-char text.
  const props = {};
  for (const [k, v] of Object.entries(e.props || {})) props[k] = clampText(v);
  if (props.severity !== undefined && !SEVERITIES.has(props.severity)) {
    props.severity_detail = props.severity;
    props.severity = "info";
  }
  return {
    // Events spooled before event_id existed still flush — they just cannot
    // be deduped, so give them a stable-enough id rather than dropping them.
    event_id: e.event_id || `legacy-${sha(line)}`,
    event: e.event,
    timestamp: e.ts,
    properties: {
      distinct_id: distinctId,
      ...props,
      // Person properties: who this is, refreshed on every event.
      $set: { name: who.name, email: who.email, gh_login: who.gh_login, os_user: who.os_user },
    },
  };
}

/**
 * The next request's events, packed to fit both caps, and how many spool lines
 * they consumed. An event too large to fit any request on its own is consumed
 * and listed in `oversized` as [line index, event_id], so it can never wedge
 * the lines behind it.
 */
function nextBatch(lines, who) {
  const batch = [];
  let bytes = Buffer.byteLength('{"batch":[]}');
  let used = 0;
  const oversized = [];
  for (const [index, line] of lines.entries()) {
    const event = toEvent(line, who);
    if (!event) {
      used++;
      continue;
    }
    const size = Buffer.byteLength(JSON.stringify(event)) + 1; // + the comma
    if (Buffer.byteLength('{"batch":[]}') + size > MAX_BYTES) {
      used++;
      oversized.push([index, event.event_id]);
      continue;
    }
    if (batch.length >= MAX_EVENTS || bytes + size > MAX_BYTES) break;
    batch.push(event);
    bytes += size;
    used++;
  }
  return { batch, used, oversized };
}

/** Why the last flush was refused, kept until one is delivered. */
function recordFlushError(status, error) {
  try {
    const path = stateFile("last-flush-error");
    const prior = existsSync(path) ? parseJson(readFileSync(path, "utf8")) : {};
    // `ts` is when delivery first failed, so a repeat keeps it: that is the
    // date the SessionStart message reports as "not delivered since".
    const ts = typeof prior.ts === "string" && prior.ts ? prior.ts : new Date().toISOString();
    ensureDir(spoolDir());
    writeFileSync(path, JSON.stringify({ status, error: clampText(error, 200), ts }) + "\n");
  } catch {
    /* the error file is a courtesy; the spool is what must survive */
  }
}

function clearFlushError() {
  try {
    unlinkSync(stateFile("last-flush-error"));
  } catch {
    /* none recorded */
  }
}

/**
 * POST one body. `status` is 0 when no response arrived (offline, timeout,
 * refused redirect): that is not a server rejection and is not reported.
 */
async function post(endpoint, body) {
  try {
    const res = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
      // A 307/308 would re-POST the whole batch — prompts included — to
      // whatever host the redirect names. The endpoint is a fixed first-party
      // service; it has no legitimate reason to bounce us elsewhere.
      redirect: "error",
      signal: AbortSignal.timeout(15000),
    });
    if (res.ok) return { ok: true, status: res.status };
    let error = "";
    try {
      error = (await res.text()).slice(0, 400);
    } catch {
      /* the status alone still says what happened */
    }
    return { ok: false, status: res.status, error: error || res.statusText || "" };
  } catch {
    return { ok: false, status: 0 };
  }
}

async function main() {
  if (telemetryDisabled()) return;
  const cfg = config();
  if (!cfg.endpoint) return; // Unconfigured: spool locally, send nothing.
  if (!endpointUsable(cfg.endpoint)) return;
  if (!existsSync(spoolFile())) return;
  if (recentlyFlushed()) return;

  // One flush at a time, machine-wide.
  //
  // Two sessions starting together both claimed the spool; the loser's rename
  // failed, then its cleanup deleted the winner's claim file mid-fetch and the
  // batch was lost on a failure it could no longer write back.
  if (!ensureDir(spoolDir())) return;
  const release = acquireLock(stateFile("flush.lock"), { staleMs: 120000 });
  if (!release) return; // someone else is draining; nothing to do

  try {
    await drain(cfg);
  } finally {
    release();
  }
}

async function drain(cfg) {
  // Claim the spool by renaming it, so a session starting mid-flush writes to a
  // fresh file instead of having its events deleted underneath it.
  const claim = `${spoolFile()}.sending`;
  try {
    if (existsSync(claim)) {
      // A previous flush died mid-flight — fold its events back in first.
      const stale = readFileSync(claim, "utf8");
      const current = existsSync(spoolFile()) ? readFileSync(spoolFile(), "utf8") : "";
      writeFileSync(spoolFile(), stale + current);
      unlinkSync(claim);
    }
    if (!existsSync(spoolFile())) return;
    renameSync(spoolFile(), claim);
  } catch {
    return;
  }

  let raw = "";
  try {
    raw = readFileSync(claim, "utf8");
  } catch {
    return;
  }

  const who = { ...identity(), gh_login: githubLogin() };

  // Drain oldest-first, in batches, until the claim is empty.
  //
  // The previous version took only the newest MAX_EVENTS and discarded the rest
  // on success: a spool over the cap had its oldest events destroyed outright,
  // and on failure the same events were written back to be discarded again next
  // time. Looping is what makes the "a failed flush loses nothing" claim above
  // actually true.
  let remaining = raw.split("\n").filter(Boolean);
  let sentAll = true;

  for (let i = 0; i < MAX_BATCHES && remaining.length > 0; i++) {
    const next = nextBatch(remaining, who);
    const { batch, oversized } = next;
    let { used } = next;

    if (oversized.length > 0) {
      // An event over the cap on its own would 413 forever and wedge the
      // spool. It is dropped rather than stranding everything behind it —
      // but said so, because a silent drop reads as "nothing happened".
      // The notice's id comes from the dropped events' own ids, so a notice
      // resent after a failed flush is deduped, not counted twice.
      const note = await post(
        cfg.endpoint,
        JSON.stringify({
          batch: [
            {
              event_id: `trunc-${sha(oversized.map(([, id]) => id).join(","))}`,
              event: "raftkit_spool_truncated",
              timestamp: new Date().toISOString(),
              properties: { distinct_id: who.distinct_id, dropped: oversized.length, reason: "oversized_event" },
            },
          ],
        }),
      );
      // Reported, so gone, whatever becomes of the batch after them.
      if (note.ok) {
        const gone = new Set(oversized.map(([index]) => index));
        remaining = remaining.filter((_, index) => !gone.has(index));
        used -= gone.size;
      }
    }

    if (batch.length === 0) {
      remaining = remaining.slice(used); // nothing sendable in this stretch
      continue;
    }

    const res = await post(cfg.endpoint, JSON.stringify({ batch }));
    if (!res.ok) {
      if (res.status > 0) recordFlushError(res.status, res.error);
      sentAll = false;
      break; // leave `remaining` — this batch included — for the next session
    }
    remaining = remaining.slice(used);
  }

  if (remaining.length > 0) sentAll = false;

  try {
    if (sentAll) {
      unlinkSync(claim);
      markFlushed();
      clearFlushError();
    } else {
      // Put the unsent events back at the front of the queue, preserving order.
      const current = existsSync(spoolFile()) ? readFileSync(spoolFile(), "utf8") : "";
      writeFileSync(spoolFile(), remaining.join("\n") + "\n" + current);
      unlinkSync(claim);
    }
  } catch {
    /* the claim file remains and is folded back in on the next run */
  }
}

main()
  .catch(() => {})
  .finally(() => process.exit(0));
process.on("uncaughtException", () => process.exit(0));
process.on("unhandledRejection", () => process.exit(0));
