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
const MAX_BYTES = 5 * 1024 * 1024; // Server caps the body at 1MB; fail early, well under it.
const MIN_INTERVAL_MS = 60 * 1000; // Don't hammer on rapid session restarts.

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

function toBatch(lines, who) {
  const batch = [];
  for (const line of lines) {
    const e = parseJson(line, null);
    if (!e || !e.event) continue;
    // Back-fill the identity the synchronous path could not resolve: it knows
    // no GitHub login, so an account with no git email spooled as `anon:`.
    // Upgrading here keeps the resolution order identical to what a single
    // synchronous resolve would have produced.
    let distinctId = e.distinct_id || who.distinct_id;
    if (who.gh_login && /^anon:/.test(String(distinctId))) distinctId = `gh:${who.gh_login}`;
    batch.push({
      // Events spooled before event_id existed still flush — they just cannot
      // be deduped, so give them a stable-enough id rather than dropping them.
      event_id: e.event_id || `legacy-${sha(line)}`,
      event: e.event,
      timestamp: e.ts,
      properties: {
        distinct_id: distinctId,
        ...(e.props || {}),
        // Person properties: who this is, refreshed on every event.
        $set: { name: who.name, email: who.email, gh_login: who.gh_login, os_user: who.os_user },
      },
    });
  }
  return batch;
}

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
    return res.ok;
  } catch {
    return false;
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
    const chunk = remaining.slice(0, MAX_EVENTS);
    const rest = remaining.slice(MAX_EVENTS);
    const batch = toBatch(chunk, who);

    if (batch.length === 0) {
      remaining = rest; // nothing parseable in this chunk
      continue;
    }

    const body = JSON.stringify({ batch });
    if (body.length > MAX_BYTES) {
      // Oversized payload would 413 forever and wedge the spool. Drop this
      // chunk and keep going rather than stranding everything behind it —
      // but say so, because a silent drop reads as "nothing happened".
      await post(
        cfg.endpoint,
        JSON.stringify({
          batch: [
            {
              event_id: `trunc-${sha(`${who.distinct_id}-${Date.now()}-${batch.length}`)}`,
              event: "raftkit_spool_truncated",
              timestamp: new Date().toISOString(),
              properties: { distinct_id: who.distinct_id, dropped: batch.length, reason: "oversized_batch" },
            },
          ],
        }),
      );
      remaining = rest;
      continue;
    }

    if (!(await post(cfg.endpoint, body))) {
      sentAll = false;
      break; // leave `remaining` — this chunk included — for the next session
    }
    remaining = rest;
  }

  if (remaining.length > 0) sentAll = false;

  try {
    if (sentAll) {
      unlinkSync(claim);
      markFlushed();
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
