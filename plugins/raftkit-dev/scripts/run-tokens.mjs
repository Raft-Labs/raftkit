#!/usr/bin/env node
// Prints the current RaftKit run's token total, measured from the session's
// transcripts, for implement and fix to quote at the STOP:
//
//   node ${CLAUDE_PLUGIN_ROOT}/scripts/run-tokens.mjs ${CLAUDE_SESSION_ID}
//
// The run starts at the RaftKit skill invocation that opened it. --session
// counts the whole session instead, to compare against Claude Code's own cost
// ledger.
//
// Contract: exactly one line on stdout, always exit 0, writes nothing.
//   Token total: <N> tokens (main <a>, subagents <b>; <model>: <n>, ...) — measured
//   Token total: not measured
// Never an estimate. Never the <subagent_tokens> of a task notification, which
// reports an agent's final context size, not what it was billed.

import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename, dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const NOT_MEASURED = "Token total: not measured";
// fd 1, synchronously and once: process.exit() drops a buffered pipe write,
// and a failure after the line is printed must not print a second one.
let said = false;
const say = (line) => {
  if (said) return;
  said = true;
  try {
    writeFileSync(1, `${line}\n`);
  } catch {
    /* nowhere to report to */
  }
};

const configDir = () => process.env.CLAUDE_CONFIG_DIR || join(process.env.HOME || ".", ".claude");

function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return null;
  }
}

const versionKey = (v) => v.split(/[.-]/).map((x) => (/^\d+$/.test(x) ? x.padStart(8, "0") : x)).join(".");

/**
 * raftkit-core's token library, found beside this plugin: in a checkout the
 * plugins are siblings; in the plugin cache each plugin sits under
 * <marketplace>/<plugin>/<version>/, and the installed version wins.
 */
function coreTokensPath() {
  const devRoot = dirname(dirname(fileURLToPath(import.meta.url)));
  const lib = join("hooks", "lib", "tokens.mjs");
  const candidates = [join(dirname(devRoot), "raftkit-core", lib)];
  const market = dirname(dirname(devRoot));
  const coreBase = join(market, "raftkit-core");
  const installed = readJson(join(configDir(), "plugins", "installed_plugins.json"))?.plugins?.[`raftkit-core@${basename(market)}`];
  for (const entry of Array.isArray(installed) ? installed : []) {
    if (typeof entry?.installPath === "string" && entry.installPath.startsWith(coreBase)) candidates.push(join(entry.installPath, lib));
  }
  try {
    const versions = readdirSync(coreBase).sort((a, b) => (versionKey(a) < versionKey(b) ? 1 : -1));
    for (const v of versions) candidates.push(join(coreBase, v, lib));
  } catch {
    /* not a cache install */
  }
  return candidates.find((p) => existsSync(p)) || "";
}

const fmt = (n) => Math.round(n).toLocaleString("en-US");

async function main() {
  const [sessionId, ...flags] = process.argv.slice(2);
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(String(sessionId || ""))) return say(NOT_MEASURED);

  const libPath = coreTokensPath();
  if (!libPath) return say(NOT_MEASURED);
  const lib = await import(pathToFileURL(libPath).href);
  if (typeof lib.measureSession !== "function" || typeof lib.findTranscript !== "function") return say(NOT_MEASURED);

  const transcript = lib.findTranscript(sessionId);
  if (!transcript) return say(NOT_MEASURED);
  const sinceMs = flags.includes("--session") || typeof lib.runStart !== "function" ? 0 : lib.runStart(transcript);
  const t = lib.measureSession(transcript, sessionId, { sinceMs });
  if (!t || t.messages === 0 || t.total <= 0) return say(NOT_MEASURED);

  const models = Object.entries(t.by_model || {})
    .filter(([, n]) => n > 0)
    .sort((a, b) => b[1] - a[1])
    .map(([m, n]) => `${m}: ${fmt(n)}`)
    .join(", ");
  say(`Token total: ${fmt(t.total)} tokens (main ${fmt(t.main)}, subagents ${fmt(t.sidechain)}${models ? `; ${models}` : ""}) — measured`);
}

main()
  .catch(() => say(NOT_MEASURED))
  .finally(() => process.exit(0));
