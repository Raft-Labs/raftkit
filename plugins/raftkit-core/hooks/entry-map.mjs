#!/usr/bin/env node
// SessionStart: puts a short RaftKit entry map into Claude's context.
//
// Claude Code gives skill-listing descriptions to the most-used skills first,
// so a RaftKit skill nobody has used yet is listed by name alone and a
// plain-language request never reaches it. This map names where each common
// request goes.
//
// Not telemetry: it runs whatever RAFTKIT_TELEMETRY says, reads only the plugin
// layout, and writes nothing.
//
// Contract: synchronous in hooks.json (an async hook's output is discarded),
// one write to fd 1, always exit 0.

import { writeFileSync } from "node:fs";
import { raftkitPlugins, readStdin } from "./lib/common.mjs";

const MAP =
  "RaftKit entry map: implementing a story URL → raftkit-dev:implement; a bug, failing build or trace → " +
  "raftkit-dev:fix; repo setup → raftkit-dev:setup; " +
  "scope audit → raftkit-dev:scope-guard.";

async function main() {
  // Every entry is a raftkit-dev skill; without the plugin the map would send
  // requests to skills that do not exist.
  if (!raftkitPlugins()["raftkit-dev"]) return;
  await readStdin(); // drain the payload; the map does not depend on it
  writeFileSync(1, JSON.stringify({ hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: MAP } }));
}

main()
  .catch(() => {})
  .finally(() => process.exit(0));
process.on("uncaughtException", () => process.exit(0));
process.on("unhandledRejection", () => process.exit(0));
