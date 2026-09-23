#!/usr/bin/env node
// One verify pass per tree. Runs the repo's test, lint and typecheck scripts
// (resolved by setup's detect-toolchain.mjs, never guessed) and keeps gate
// output out of the conversation: one line when everything is green, and on
// red only the failing gates with at most their last 20 lines each.
//
// A green result is cached under <git common dir>/raftkit/verify.json, keyed
// by the tree hash of HEAD and the exact command. It is reused only while the
// working tree is clean; a dirty tree always runs, and a red result is never
// cached. The pre-push hook does not use this script and keeps its full gates.
//
// Usage: node verify.mjs [--only test|lint|typecheck] [--root <repo>]
// Exit codes: 0 green or nothing to run · 1 a gate failed · 2 bad input or an
// undetermined package manager (nothing run).
import { spawn, execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdirSync, renameSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROLES = ["test", "lint", "typecheck"];
const TAIL = 20, KEEP_TREES = 20;
const DETECT = fileURLToPath(new URL("../skills/setup/scripts/detect-toolchain.mjs", import.meta.url));

const args = process.argv.slice(2);
const flag = (n) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : undefined; };
const say = (line, code) => { console.log(line); process.exit(code); };
const only = flag("--only");
if (args.includes("--only") && !ROLES.includes(only)) say(`verify: --only takes ${ROLES.join(", ")}; nothing was run`, 2);

const git = (cwd, ...a) => execFileSync("git", ["-C", cwd, ...a], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
let root;
try { root = git(flag("--root") ?? process.cwd(), "rev-parse", "--show-toplevel"); }
catch { say("verify: not inside a git repository; nothing was run", 2); }

// --- the gate commands, from setup's own detector ---------------------------
let detected;
try { detected = JSON.parse(execFileSync(process.execPath, [DETECT, "--root", root, "--json"], { encoding: "utf8" })); }
catch { say("verify: the toolchain could not be detected; nothing was run", 2); }
if (detected.state === "non-node") say("verify: nothing to run — no Node manifest at the repo root", 0);
if (detected.state !== "detected") say(`verify: package manager ${detected.state} — resolve it with raftkit-dev:setup; nothing was run`, 2);
const roles = only ? [only] : ROLES;
const present = roles.filter((r) => Object.hasOwn(detected.rootScripts ?? {}, r));
const absent = roles.filter((r) => !present.includes(r));
if (!present.length) say(`verify: nothing to run — no ${roles.join(", ")} script at the repo root`, 0);
const commandOf = (role) => `${detected.manager} run ${role}`;

// --- tree state and cache ------------------------------------------------------
const treeState = () => {
  let tree = null;
  try { tree = git(root, "rev-parse", "HEAD^{tree}"); } catch { /* no commit yet: nothing is cacheable */ }
  const dirty = git(root, "status", "--porcelain", "--untracked-files=normal") !== "";
  return { tree, dirty };
};
const before = treeState();
let commonDir;
try { commonDir = git(root, "rev-parse", "--path-format=absolute", "--git-common-dir"); }
catch { commonDir = path.resolve(root, git(root, "rev-parse", "--git-common-dir")); }
const cacheFile = path.join(commonDir, "raftkit", "verify.json");
let cache = [];
try { cache = JSON.parse(readFileSync(cacheFile, "utf8")); if (!Array.isArray(cache)) cache = []; } catch { cache = []; }
const reusable = before.tree && !before.dirty ? cache.find((e) => e?.tree === before.tree) : null;

// --- run ---------------------------------------------------------------------
// Package-manager framing lines carry nothing the summary does not already say.
const NOISE = [/^> /, /^npm (ERR!|error|warn)\b/, /ELIFECYCLE/, /^error Command failed with exit code/, /^info Visit https:\/\/yarnpkg\.com/, /^\$ /];
function run(role) {
  return new Promise((resolve) => {
    const chunks = [];
    const child = spawn(detected.manager, ["run", role], {
      cwd: root, stdio: ["ignore", "pipe", "pipe"], shell: process.platform === "win32",
      env: { ...process.env, FORCE_COLOR: "0", NO_COLOR: "1" },
    });
    child.stdout.on("data", (d) => chunks.push(d));
    child.stderr.on("data", (d) => chunks.push(d));
    child.on("error", (err) => resolve({ code: 127, lines: [err.message] }));
    child.on("close", (code) => {
      const lines = Buffer.concat(chunks).toString("utf8").replace(/\x1b\[[0-9;]*[A-Za-z]/g, "")
        .split(/\r?\n/).filter((l) => l.trim() && !NOISE.some((re) => re.test(l)));
      resolve({ code: code ?? 1, lines: lines.slice(-TAIL) });
    });
  });
}
const results = [];
for (const role of present) {
  if (reusable?.results?.[role]?.command === commandOf(role)) results.push({ role, cached: true, code: 0 });
  else results.push({ role, cached: false, ...(await run(role)) });
}

// --- cache greens, only for a tree that was and still is clean ---------------
const after = treeState();
if (before.tree && !before.dirty && after.tree === before.tree && !after.dirty) {
  const entry = cache.find((e) => e?.tree === before.tree) ?? { tree: before.tree, results: {} };
  for (const r of results) {
    if (r.code === 0) entry.results[r.role] = { command: commandOf(r.role), at: new Date().toISOString() };
    else delete entry.results[r.role];
  }
  cache = [...cache.filter((e) => e?.tree !== before.tree), entry].slice(-KEEP_TREES);
  try {
    mkdirSync(path.dirname(cacheFile), { recursive: true });
    const tmp = `${cacheFile}.${process.pid}.tmp`;
    writeFileSync(tmp, JSON.stringify(cache, null, 2) + "\n");
    renameSync(tmp, cacheFile);
  } catch { /* a cache that cannot be written only costs a re-run */ }
}

// --- report --------------------------------------------------------------------
const where = before.dirty ? `tree ${before.tree?.slice(0, 12) ?? "(no commit)"} + uncommitted changes` : `tree ${before.tree?.slice(0, 12) ?? "(no commit)"}`;
const missing = absent.map((r) => ` · no ${r} script`).join("");
const red = results.filter((r) => r.code !== 0);
const green = results.filter((r) => r.code === 0).map((r) => `${r.role}${r.cached ? " (cached)" : ""}`);
if (!red.length) say(`verify: green — ${green.join(", ")}${missing} · ${where}`, 0);
console.log(`verify: red — ${red.map((r) => `${r.role} (exit ${r.code})`).join(", ")} failed${green.length ? `; green: ${green.join(", ")}` : ""}${missing} · ${where}`);
for (const r of red) {
  console.log(`--- ${r.role}: ${commandOf(r.role)}, last ${r.lines.length} line(s) ---`);
  for (const l of r.lines.length ? r.lines : ["(no output)"]) console.log(l);
}
process.exit(1);
