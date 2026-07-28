#!/usr/bin/env node
// Fail-closed merge of raftkit's managed keys into a repo's .claude/settings.json.
// Exit codes: 0 applied (or no changes) · 1 unreadable input, nothing written ·
// 2 conflict against an existing value, nothing written.
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";

// House policy, mirrored from the working ~/.claude/settings.json — never invented here.
const MANAGED = {
  extraKnownMarketplaces: {
    raftkit: {
      source: { source: "github", repo: "Raft-Labs/raftkit" },
      autoUpdate: true,
    },
  },
  enabledPlugins: {
    "raftkit-core@raftkit": true,
    "raftkit-dev@raftkit": true,
    "superpowers@claude-plugins-official": true,
    "code-simplifier@claude-plugins-official": true,
    "claude-md-management@claude-plugins-official": true,
    "security-guidance@claude-plugins-official": true,
    "pr-review-toolkit@claude-plugins-official": true,
  },
  model: "opusplan",
  attribution: { commit: "", pr: "" },
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

const target = process.argv[2];
if (!target) {
  console.error("usage: merge-settings.mjs <path-to-settings.json>");
  process.exit(1);
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

// permissions.allow — array union, never a conflict on content; existing order preserved,
// gaps appended. But the container and the array itself must be shape-checked first.
const eParent = expectObject([], existing, "permissions");
if (eParent !== null) {
  const eAllow = expectArray(["permissions"], eParent, "allow");
  if (eAllow !== null) {
    const mergedAllow = [...eAllow];
    for (const rule of MANAGED.permissions.allow) {
      if (!mergedAllow.includes(rule)) mergedAllow.push(rule);
    }
    result.permissions = { ...eParent, allow: mergedAllow };
  }
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
