#!/usr/bin/env node
// Fail-closed merge of raftkit's managed keys into a repo's .claude/settings.json.
// Usage: merge-settings.mjs <path-to-settings.json> [--node] [opt-ins]
//   --node  the repo has a Node manifest: worktrees also share node_modules.
// Opt-ins, each written only when the developer accepted its line at the stop:
//   --allow-local [--pm <pm> --manifest <package.json> --scripts "<names>"]
//       allow local git fetch/switch/add/commit, plus `<pm> run <script>` for
//       each approved script present in the manifest that is a test, lint or
//       typecheck gate (quality.mjs); any other name is refused. Never push or a PR.
//   --sg-push-sweep-off   env.SG_PUSH_SWEEP "0": security-guidance stops its
//       push-time review; the commit-time review stays.
//   --disable-plugins <id,...>   turn plugins off for this repo (project scope).
// Exit codes: 0 applied (or no changes) · 1 unreadable input, nothing written ·
// 2 conflict against an existing value, nothing written.
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { QUALITY } from "./quality.mjs";

// The plugins a RaftKit repo enables: raftkit-dev and exactly what its manifest
// declares, so this list cannot drift from plugin.json.
const manifest = JSON.parse(readFileSync(new URL("../../../.claude-plugin/plugin.json", import.meta.url), "utf8"));
const pluginIds = ["raftkit-dev@raftkit", ...manifest.dependencies.map((d) =>
  typeof d === "string" ? `${d}@raftkit` : `${d.name}@${d.marketplace ?? "raftkit"}`)];

// House policy, mirrored from the working ~/.claude/settings.json — never invented here.
const MANAGED = {
  extraKnownMarketplaces: {
    raftkit: {
      source: { source: "github", repo: "Raft-Labs/raftkit" },
      autoUpdate: true,
    },
  },
  enabledPlugins: Object.fromEntries(pluginIds.map((id) => [id, true])),
  model: "opusplan",
  attribution: { commit: "", pr: "" },
  // Worktrees branch from local HEAD, so a phase sees the run's own commits;
  // node_modules is shared rather than reinstalled per worktree (Node repos only).
  worktree: { baseRef: "head", symlinkDirectories: ["node_modules"] },
  permissions: {
    allow: [
      "Bash(git status:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(claude plugin list:*)",
      "Bash(gh pr view:*)",
    ],
  },
};

const USAGE = 'usage: merge-settings.mjs <settings.json> [--node] [--allow-local [--pm <pm> --manifest <package.json> --scripts "<names>"]] [--sg-push-sweep-off] [--disable-plugins <id,...>]';
const [target, ...rest] = process.argv.slice(2);
const opts = {};
const VALUED = new Set(["--pm", "--manifest", "--scripts", "--disable-plugins"]);
for (let i = 0; i < rest.length; i++) {
  const f = rest[i];
  if (VALUED.has(f) && i + 1 < rest.length) opts[f] = rest[++i];
  else if (["--node", "--allow-local", "--sg-push-sweep-off"].includes(f)) opts[f] = true;
  else opts.bad = f;
}
const refuse = (msg) => { console.error(`reason: ${msg} — nothing written`); process.exit(1); };
if (!target || target.startsWith("--") || opts.bad !== undefined) { console.error(USAGE); process.exit(1); }
const nodeRepo = opts["--node"] === true;

// Opt-in allow rules: local git steps, plus the approved gate scripts only.
const LOCAL_GIT = ["Bash(git fetch *)", "Bash(git switch *)", "Bash(git add *)", "Bash(git commit *)"];
const gateFlags = ["--pm", "--manifest", "--scripts"].filter((f) => f in opts);
const optInAllow = [];
if (gateFlags.length && (!opts["--allow-local"] || gateFlags.length !== 3)) refuse("--pm, --manifest and --scripts go together, with --allow-local");
if (opts["--allow-local"]) {
  optInAllow.push(...LOCAL_GIT);
  if (gateFlags.length === 3) {
    const pm = opts["--pm"];
    if (!["npm", "pnpm", "yarn", "bun"].includes(pm)) refuse(`package manager '${pm}' is not npm, pnpm, yarn or bun`);
    let scripts;
    try { scripts = JSON.parse(readFileSync(opts["--manifest"], "utf8")).scripts ?? {}; }
    catch (err) { refuse(`cannot read ${opts["--manifest"]} (${err.message})`); }
    for (const name of opts["--scripts"].split(/[\s,]+/).filter(Boolean)) {
      if (!/^[A-Za-z0-9][A-Za-z0-9:_.-]*$/.test(name) || !Object.hasOwn(scripts, name)) refuse(`'${name}' is not a script in ${opts["--manifest"]}`);
      if (!QUALITY.test(name)) refuse(`'${name}' is not a test, lint or typecheck gate`);
      optInAllow.push(`Bash(${pm} run ${name} *)`);
    }
  }
}

// Opt-in project-scope disables: never a RaftKit plugin or an engine it needs.
const managedNames = new Set(Object.keys(MANAGED.enabledPlugins).map((id) => id.split("@")[0]));
const toDisable = (opts["--disable-plugins"] ?? "").split(",").filter(Boolean);
for (const id of toDisable) {
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]*@[A-Za-z0-9][A-Za-z0-9._-]*$/.test(id)) refuse(`'${id}' is not a plugin id`);
  if (id.startsWith("raftkit-") || managedNames.has(id.split("@")[0])) refuse(`${id} is one RaftKit runs on and is never disabled here`);
}

function isPlainObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

let existing = {};
let rawExisting = null;
if (existsSync(target)) {
  rawExisting = readFileSync(target, "utf8");
  try {
    existing = JSON.parse(rawExisting);
  } catch (err) {
    console.error(`reason: ${target} is not valid JSON (${err.message}) — nothing written`);
    process.exit(1);
  }
  // Syntactically valid JSON whose root isn't an object ([], "x", 42, null) must not be
  // spread into { ...existing } below — that silently discards the original root and
  // replaces it with a fresh settings object. Same fail-closed bucket as invalid JSON.
  if (!isPlainObject(existing)) {
    const shape = existing === null ? "null" : Array.isArray(existing) ? "array" : typeof existing;
    console.error(`reason: ${target}'s root is a ${shape}, not a JSON object — nothing written`);
    process.exit(1);
  }
}

const conflicts = [];

function mergeScalar(path, existingObj, key, managedValue) {
  if (!(key in existingObj)) {
    existingObj[key] = managedValue;
    return;
  }
  if (JSON.stringify(existingObj[key]) !== JSON.stringify(managedValue)) {
    conflicts.push({ path: [...path, key].join("."), existing: existingObj[key], proposed: managedValue });
  }
}

// Every managed container is merged by spreading the existing value — a wrong-shaped
// existing value (a string where an object or array is expected) must never be spread
// silently (that coerces "sonnet" into {0:"s",1:"o",...} or its characters into an
// array). Wrong shape is a conflict like any other: reported, nothing written.
function expectObject(path, existingParent, key) {
  const value = existingParent[key];
  if (value === undefined) return {};
  if (!isPlainObject(value)) {
    conflicts.push({ path: [...path, key].join("."), existing: value, proposed: "<object>" });
    return null;
  }
  return { ...value };
}

function expectArray(path, existingParent, key) {
  const value = existingParent[key];
  if (value === undefined) return [];
  if (!Array.isArray(value)) {
    conflicts.push({ path: [...path, key].join("."), existing: value, proposed: "<array>" });
    return null;
  }
  return [...value];
}

const result = { ...existing };

// extraKnownMarketplaces.raftkit — object merge, conflict on a differing existing entry.
const eKM = expectObject([], existing, "extraKnownMarketplaces");
if (eKM !== null) {
  result.extraKnownMarketplaces = eKM;
  mergeScalar(["extraKnownMarketplaces"], result.extraKnownMarketplaces, "raftkit", MANAGED.extraKnownMarketplaces.raftkit);
}

// enabledPlugins — additive; an existing key that differs (e.g. explicitly disabled) conflicts.
const eEP = expectObject([], existing, "enabledPlugins");
if (eEP !== null) {
  result.enabledPlugins = eEP;
  for (const [plugin, enabled] of Object.entries(MANAGED.enabledPlugins)) {
    mergeScalar(["enabledPlugins"], result.enabledPlugins, plugin, enabled);
  }
  for (const id of toDisable) mergeScalar(["enabledPlugins"], result.enabledPlugins, id, false);
}

// env.SG_PUSH_SWEEP — opt-in only; any existing differing value conflicts.
if (opts["--sg-push-sweep-off"]) {
  const eEnv = expectObject([], existing, "env");
  if (eEnv !== null) {
    result.env = eEnv;
    mergeScalar(["env"], result.env, "SG_PUSH_SWEEP", "0");
  }
}

// model — plain scalar; any existing differing value conflicts.
mergeScalar([], result, "model", MANAGED.model);

// attribution — object merge, same shape guard as above.
const eAttr = expectObject([], existing, "attribution");
if (eAttr !== null) {
  result.attribution = eAttr;
  mergeScalar(["attribution"], result.attribution, "commit", MANAGED.attribution.commit);
  mergeScalar(["attribution"], result.attribution, "pr", MANAGED.attribution.pr);
}

// Array union, never a conflict on content; existing order preserved, gaps appended.
function union(existingArr, managed) {
  const merged = [...existingArr];
  for (const item of managed) if (!merged.includes(item)) merged.push(item);
  return merged;
}

// worktree — baseRef is a scalar; symlinkDirectories a union, written only for Node repos.
const eWt = expectObject([], existing, "worktree");
if (eWt !== null) {
  result.worktree = eWt;
  mergeScalar(["worktree"], result.worktree, "baseRef", MANAGED.worktree.baseRef);
  if (nodeRepo) {
    const eLinks = expectArray(["worktree"], eWt, "symlinkDirectories");
    if (eLinks !== null) result.worktree.symlinkDirectories = union(eLinks, MANAGED.worktree.symlinkDirectories);
  }
}

// permissions.allow — the container and the array itself are shape-checked first.
const eParent = expectObject([], existing, "permissions");
if (eParent !== null) {
  const eAllow = expectArray(["permissions"], eParent, "allow");
  if (eAllow !== null) result.permissions = { ...eParent, allow: union(eAllow, [...MANAGED.permissions.allow, ...optInAllow]) };
}

if (conflicts.length > 0) {
  console.error(`${conflicts.length} conflict(s) — nothing written:`);
  for (const c of conflicts) {
    console.error(`  ${c.path}: existing=${JSON.stringify(c.existing)} proposed=${JSON.stringify(c.proposed)}`);
  }
  process.exit(2);
}

const newContent = JSON.stringify(result, null, 2) + "\n";
if (rawExisting !== null && rawExisting === newContent) {
  console.log("no changes");
  process.exit(0);
}

mkdirSync(dirname(target), { recursive: true });
writeFileSync(target, newContent);
console.log(rawExisting === null ? "created" : "updated");
