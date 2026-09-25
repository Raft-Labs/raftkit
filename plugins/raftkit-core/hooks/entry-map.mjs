#!/usr/bin/env node
// SessionStart: puts a short RaftKit entry map into Claude's context.
//
// Claude Code gives skill-listing descriptions to the most-used skills first,
// so a RaftKit skill nobody has used yet is listed by name alone and a
// plain-language request never reaches it. This map names where each common
// request goes. It says fix runs systematic-debugging itself because that
// skill's own injection otherwise competes for every bug report.
//
// Not telemetry: it runs whatever RAFTKIT_TELEMETRY says, reads only the plugin
// layout and the repo's setup marker, and writes nothing.
//
// Contract: synchronous in hooks.json (an async hook's output is discarded),
// one write to fd 1, always exit 0.

import { existsSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { LOCAL_EXEC_TIMEOUT, parseJson, raftkitPlugins, readStdin, safeExec } from "./lib/common.mjs";

const MAP =
  "RaftKit entry map: implementing a story URL → raftkit-dev:implement; a bug, failing build or trace → " +
  "raftkit-dev:fix (it runs systematic-debugging itself); repo setup → raftkit-dev:setup; " +
  "scope audit → raftkit-dev:scope-guard.";
const NOT_SET_UP = "RaftKit is not set up in this repo — run raftkit-dev:setup.";
// Written by raftkit-dev:setup at the repo root on its first run.
const SETUP_MARKER = join(".raftkit", "governance-pack.json");

async function main() {
  // Every entry is a raftkit-dev skill; without the plugin the map would send
  // requests to skills that do not exist.
  if (!raftkitPlugins()["raftkit-dev"]) return;
  const hook = parseJson(await readStdin());
  const cwd = typeof hook.cwd === "string" && hook.cwd ? hook.cwd : process.cwd();
  const root = safeExec("git", ["rev-parse", "--show-toplevel"], { cwd, timeout: LOCAL_EXEC_TIMEOUT });
  const text = root && !existsSync(join(root, SETUP_MARKER)) ? `${MAP} ${NOT_SET_UP}` : MAP;
  writeFileSync(1, JSON.stringify({ hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: text } }));
}

main()
  .catch(() => {})
  .finally(() => process.exit(0));
process.on("uncaughtException", () => process.exit(0));
process.on("unhandledRejection", () => process.exit(0));
