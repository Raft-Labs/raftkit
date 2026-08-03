#!/usr/bin/env node
// Drains the local event spool to the RaftLabs admin API.
//
// Runs on SessionStart, async. The spool is cleared ONLY on a 2xx — a failed
// flush leaves every event in place to retry next session, so an offline or
// rate-limited developer still reports rather than silently losing data.
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
  config,
  ensureDir,
  parseJson,
  sha,
  spoolDir,
  spoolFile,
  stateFile,
  telemetryDisabled,
} from "./lib/common.mjs";
import { identity } from "./lib/identity.mjs";

const MAX_EVENTS = 500;
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

async function main() {
  if (telemetryDisabled()) return;
  const cfg = config();
  if (!cfg.endpoint) return; // Unconfigured: spool locally, send nothing.
  if (!existsSync(spoolFile())) return;
  if (recentlyFlushed()) return;

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

  const all = raw.split("\n").filter(Boolean);
  const kept = all.slice(-MAX_EVENTS);
  const dropped = all.length - kept.length;

  const who = identity();
  const batch = [];
  for (const line of kept) {
    const e = parseJson(line, null);
    if (!e || !e.event) continue;
    batch.push({
      // Events spooled before event_id existed still flush — they just cannot
      // be deduped, so give them a stable-enough id rather than dropping them.
      event_id: e.event_id || `legacy-${sha(line)}`,
      event: e.event,
      timestamp: e.ts,
      properties: {
        distinct_id: e.distinct_id || who.distinct_id,
        ...(e.props || {}),
        // Person properties: who this is, refreshed on every event.
        $set: { name: who.name, email: who.email, gh_login: who.gh_login, os_user: who.os_user },
      },
    });
  }

  if (dropped > 0) {
    // Silent truncation would read as "nothing happened"; make it visible.
    batch.push({
      event_id: `trunc-${sha(`${who.distinct_id}-${Date.now()}-${dropped}`)}`,
      event: "raftkit_spool_truncated",
      timestamp: new Date().toISOString(),
      properties: { distinct_id: who.distinct_id, dropped },
    });
  }

  if (batch.length === 0) {
    try {
      unlinkSync(claim);
    } catch {
      /* nothing to send, nothing to keep */
    }
    return;
  }

  const body = JSON.stringify({ batch });
  if (body.length > MAX_BYTES) {
    // Oversized payload would 413 forever and wedge the spool. Drop it, loudly.
    try {
      unlinkSync(claim);
    } catch {
      /* ignore */
    }
    return;
  }

  let ok = false;
  try {
    const res = await fetch(cfg.endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
      signal: AbortSignal.timeout(15000),
    });
    ok = res.ok;
  } catch {
    ok = false;
  }

  try {
    if (ok) {
      unlinkSync(claim);
      markFlushed();
    } else {
      // Put the events back at the front of the queue for the next attempt.
      const current = existsSync(spoolFile()) ? readFileSync(spoolFile(), "utf8") : "";
      writeFileSync(spoolFile(), raw + current);
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
