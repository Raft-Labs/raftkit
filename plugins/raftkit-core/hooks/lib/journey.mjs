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

import { randomUUID } from "node:crypto";
import { readJsonFile, sessionFile, writeJsonFile } from "./common.mjs";

const fresh = () => ({ skill_seen: false, journey: null, gate_pending: null, last_prompt: "" });

export function loadSession(sessionId) {
  const saved = readJsonFile(sessionFile(sessionId, "journey"), {});
  return { ...fresh(), ...(saved && typeof saved === "object" ? saved : {}) };
}

export function saveSession(sessionId, state) {
  return writeJsonFile(sessionFile(sessionId, "journey"), state);
}

export const opensRun = (name) =>
  /^raftkit-[a-z0-9-]+:[a-z0-9-]+$/.test(name) && !name.startsWith("raftkit-core:") && !name.endsWith(":help");

/**
 * Record a RaftKit skill invocation. Returns true when it opened a new journey.
 * `start` supplies the new journey's extra fields (sha12, token baseline) and is
 * called only when one opens.
 */
export function noteSkill(state, name, { typed, start }) {
  state.skill_seen = true;
  if (!opensRun(name)) return false;
  if (!typed && state.journey?.open) return false;
  state.journey = { id: randomUUID(), skill: name, open: true, ...start() };
  state.gate_pending = null;
  return true;
}

/** The run's STOP was shown, or a skill refused: the run is over. */
export function closeJourney(state, { gate, ts }) {
  if (state.journey) state.journey.open = false;
  if (gate) state.gate_pending = { ts, journey_id: state.journey?.id || "" };
}

/** Props every event of the session carries while a journey is on record. */
export const journeyProps = (state) =>
  state.journey
    ? { journey_id: state.journey.id, journey_skill: state.journey.skill, skill_sha12: state.journey.skill_sha12 || "" }
    : {};
