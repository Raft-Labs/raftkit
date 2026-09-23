// Per-session journey state: which RaftKit run is in progress, whether its
// STOP is waiting for the human's reply, and whether any RaftKit skill has run
// in this session at all.
//
// A journey is one run. It opens at a RaftKit skill invocation and closes at
// that run's STOP or a skill's own refusal. A skill loaded while it is open —
// implement loading the rules, or scope-guard in its review — belongs to it. A
// typed slash command always opens a new one. raftkit-core's skills and the
// help commands are loaded by runs and never open one themselves.
//
// It lives in a file rather than being read back from the spool, because a
// flush from any other session drains the spool mid-run.
//
// Hooks of one session run at the same time: a typed slash command fires its
// expansion and prompt hooks together. So a hook never writes back the state it
// loaded. Each change is recorded as an operation, and saveSession re-reads the
// file under a short lock and applies only this hook's operations to it.

import { randomUUID } from "node:crypto";
import { dirname } from "node:path";
import { acquireLock, ensureDir, readJsonFile, sessionFile, writeJsonFile } from "./common.mjs";

const fresh = () => ({ skill_seen: false, journey: null, gate_pending: null, last_prompt: "" });
const OPS = Symbol("ops"); // a symbol key, so JSON never writes it

function readState(path) {
  const saved = readJsonFile(path, {});
  return { ...fresh(), ...(saved && typeof saved === "object" ? saved : {}) };
}

const sameGate = (a, b) => Boolean(a && b) && a.ts === b.ts && a.journey_id === b.journey_id;

// Each operation, applied to whatever state is on disk when the hook saves.
const APPLY = {
  seen: (s) => {
    s.skill_seen = true;
  },
  // Replaces the journey this hook saw, or an older one another hook opened meanwhile.
  open: (s, { journey, over }) => {
    if (!s.journey || s.journey.id === over || String(s.journey.started_at || "") <= String(journey.started_at || "")) {
      s.journey = journey;
    }
  },
  close: (s, { id, gate }) => {
    if (s.journey && s.journey.id === id) s.journey.open = false;
    if (gate) s.gate_pending = gate;
  },
  // Only the STOP this prompt answered; one shown since stays waiting.
  reply: (s, { gate }) => {
    if (sameGate(s.gate_pending, gate)) s.gate_pending = null;
  },
  prompt: (s, { text }) => {
    s.last_prompt = text;
  },
};

function change(state, op, args = {}) {
  APPLY[op](state, args);
  state[OPS].push([op, args]);
}

export function loadSession(sessionId) {
  const state = readState(sessionFile(sessionId, "journey"));
  state[OPS] = [];
  return state;
}

// A synchronous pause: the lock is held for one small read and one rename.
const pause = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);

function lockFor(path) {
  for (let i = 0; i < 100; i++) {
    const release = acquireLock(`${path}.lock`, { staleMs: 5000 });
    if (release) return release;
    pause(5);
  }
  return null; // still merged, just without the lock
}

/** Apply this hook's changes to the state on disk. Writes nothing when it changed nothing. */
export function saveSession(sessionId, state) {
  const ops = state[OPS] || [];
  const path = sessionFile(sessionId, "journey");
  if (!path || ops.length === 0) return false;
  ensureDir(dirname(path));
  const release = lockFor(path);
  try {
    const current = readState(path);
    for (const [op, args] of ops) APPLY[op](current, args);
    return writeJsonFile(path, current);
  } finally {
    release?.();
  }
}

export const opensRun = (name) =>
  /^raftkit-[a-z0-9-]+:[a-z0-9-]+$/.test(name) && !name.startsWith("raftkit-core:") && !name.endsWith(":help");

/**
 * Record a RaftKit skill invocation. Returns true when it opened a new journey.
 * `start` supplies the new journey's extra fields (sha12, token baseline) and is
 * called only when one opens.
 */
export function noteSkill(state, name, { typed, start }) {
  if (!state.skill_seen) change(state, "seen");
  if (!opensRun(name)) return false;
  if (!typed && state.journey?.open) return false;
  change(state, "open", { journey: { id: randomUUID(), skill: name, open: true, ...start() }, over: state.journey?.id || "" });
  return true;
}

/** The run's STOP was shown, or a skill refused: the run is over. */
export function closeJourney(state, { gate, ts }) {
  const id = state.journey?.id || "";
  change(state, "close", { id, gate: gate ? { ts, journey_id: id } : null });
}

/** A human prompt. Returns true when it is the reply to a waiting STOP. */
export function notePrompt(state, text) {
  const gate = state.gate_pending;
  change(state, "prompt", { text });
  if (!gate) return false;
  change(state, "reply", { gate });
  return true;
}

/** Props every event of the session carries while a journey is on record. */
export const journeyProps = (state) =>
  state.journey
    ? { journey_id: state.journey.id, journey_skill: state.journey.skill, skill_sha12: state.journey.skill_sha12 || "" }
    : {};
