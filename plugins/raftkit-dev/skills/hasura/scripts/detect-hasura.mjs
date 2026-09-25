#!/usr/bin/env node
// Deterministic Hasura-project detector. It looks for Hasura signals under a
// root and reports whether the capability should activate and which
// conventions were discovered. A non-Hasura repository yields nothing and a
// non-zero exit — the capability never activates or installs assets there.
// It reads only, unless --write records the conventions in
// <root>/.raftkit/hasura.json (schema: references/conventions.md).
//
// Signals (any is sufficient; more raise confidence):
//   - a Hasura config.yaml (version:/metadata_directory:/endpoint:)
//   - a metadata/ directory alongside it
//   - a migrations/ directory alongside it
//   - a nested hasura project root (a dir containing config.yaml); when there
//     are several, each is reported and --write needs --env HASURA_ROOT
//   - a Hasura CLI config / --project marker
// Package/Profile stack evidence is passed in by the caller when available.
//
// Usage: node detect-hasura.mjs --root <repo> [--json] [--write [--env NAME=VALUE]...]
// Exit codes: 0 detected · 1 not detected or nothing to record (nothing written)
// · 2 bad input.
import { readFileSync, existsSync, readdirSync, statSync, mkdirSync, writeFileSync } from "node:fs";
import { join, relative, resolve } from "node:path";

const args = process.argv.slice(2);
const flag = (n) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : undefined; };
const asJson = args.includes("--json");
const root = flag("--root");
if (!root) { console.error("usage: detect-hasura.mjs --root <repo> [--json] [--write [--env NAME=VALUE]...]"); process.exit(2); }
if (!existsSync(root)) { console.error(`root not found: ${root}`); process.exit(2); }

// --env records a value the scripts read as an environment variable.
const ENV_NAMES = ["HASURA_ROOT", "HASURA_MIGRATIONS_SUBDIR", "HASURA_METADATA_SUBDIR", "TENANCY_COLUMN", "TENANCY_REL",
  "TENANCY_MEMBER_REL", "TENANCY_MEMBER_COLUMN", "TENANCY_STATUS_FIELD", "TENANCY_STATUS_VALUE"];
const write = args.includes("--write");
const envArgs = {};
args.forEach((a, i) => {
  if (a !== "--env") return;
  const [name, ...value] = (args[i + 1] ?? "").split("=");
  if (!ENV_NAMES.includes(name) || value.length === 0) {
    console.error(`--env takes NAME=VALUE with NAME one of: ${ENV_NAMES.join(", ")}`);
    process.exit(2);
  }
  envArgs[name] = value.join("=");
});

const isDir = (p) => { try { return statSync(p).isDirectory(); } catch { return false; } };
const has = (p) => existsSync(join(root, p));

const signals = [];
const conventions = {};

// A Hasura config.yaml is the strongest single signal.
const cfgPath = join(root, "config.yaml");
if (has("config.yaml")) {
  try {
    const cfg = readFileSync(cfgPath, "utf8");
    if (/^\s*version\s*:/m.test(cfg) || /metadata_directory\s*:/.test(cfg) || /endpoint\s*:/.test(cfg)) {
      signals.push("config.yaml (Hasura CLI project config)");
      conventions.hasuraRoot = root;
      const md = cfg.match(/metadata_directory\s*:\s*(\S+)/);
      if (md) conventions.metadataDir = md[1];
      const mg = cfg.match(/migrations_directory\s*:\s*(\S+)/);
      if (mg) conventions.migrationsDir = mg[1];
    }
  } catch { /* unreadable config is not a signal */ }
}
if (isDir(join(root, "metadata"))) { signals.push("metadata/ directory"); conventions.metadataDir ??= "metadata"; }
if (isDir(join(root, "migrations"))) { signals.push("migrations/ directory"); conventions.migrationsDir ??= "migrations"; }

// With no Hasura config.yaml at the root, look for a nested project root (e.g.
// services/hasura) in lib/common.sh find_hasura_root's order: every
// */config.yaml, then every */*/config.yaml, dot-directories skipped (bash
// globs skip them). Name order can differ from bash's locale collation, so
// several candidates are all reported and --write then needs the chosen one.
const subdirs = (rel) => {
  try { return readdirSync(join(root, rel)).filter((n) => !n.startsWith(".") && isDir(join(root, rel, n))).sort().map((n) => (rel ? `${rel}/${n}` : n)); }
  catch { return []; }
};
let candidates = [];
if (!conventions.hasuraRoot && isDir(root)) {
  const depth1 = subdirs("");
  candidates = [...depth1, ...depth1.flatMap(subdirs)].filter((rel) => existsSync(join(root, rel, "config.yaml")));
  if (candidates.length === 1) signals.push(`nested Hasura project root: ${candidates[0]}/`);
  for (const c of candidates.length > 1 ? candidates : []) signals.push(`Hasura project root candidate: ${c}/`);
  if (candidates.length) conventions.hasuraRoot = join(root, candidates[0]);
}

const detected = signals.length > 0;
const result = { detected, signals, conventions };

if (asJson) {
  console.log(JSON.stringify(result, null, 2));
} else if (detected) {
  console.log(`Hasura detected — signals: ${signals.join("; ")}`);
  console.log(`discovered conventions: ${JSON.stringify(conventions)}`);
} else {
  console.log("no Hasura signals — capability does not activate; no Hasura assets installed");
}
if (detected && write) writeCache();
process.exit(detected ? 0 : 1);

// The cache holds what later runs would otherwise re-derive: the Hasura root,
// the database, the declared roles, the root Makefile's hasura/dbml targets, and
// `env`, the variables to set when running the scaffolder. env.HASURA_ROOT is
// always the recorded root, so the scaffolder never re-discovers another one.
function writeCache() {
  if (!envArgs.HASURA_ROOT && candidates.length > 1) {
    console.error(`several Hasura project roots (${candidates.join(", ")}) — pass --env HASURA_ROOT=<dir>; nothing written`);
    process.exit(1);
  }
  const hasuraDir = envArgs.HASURA_ROOT ? resolve(root, envArgs.HASURA_ROOT) : conventions.hasuraRoot;
  if (!hasuraDir || !existsSync(join(hasuraDir, "config.yaml"))) {
    console.error("no Hasura config.yaml to record — pass --env HASURA_ROOT=<dir>; nothing written");
    process.exit(1);
  }
  const cfg = readFileSync(join(hasuraDir, "config.yaml"), "utf8");
  const metadata = cfg.match(/^\s*metadata_directory\s*:\s*(\S+)/m)?.[1] ?? "metadata";
  const migrations = cfg.match(/^\s*migrations_directory\s*:\s*(\S+)/m)?.[1] ?? "migrations";
  const list = (dir, keep) => { try { return readdirSync(dir).filter((n) => !n.startsWith(".") && keep(join(dir, n))).sort(); } catch { return []; } };
  const dbs = list(join(hasuraDir, metadata, "databases"), isDir);
  const database = dbs.length === 1 ? dbs[0] : dbs.includes("default") ? "default" : null;
  const tables = database ? join(hasuraDir, metadata, "databases", database, "tables") : null;
  const roles = new Set();
  for (const f of tables ? list(tables, (p) => /\.ya?ml$/.test(p)) : []) {
    for (const m of readFileSync(join(tables, f), "utf8").matchAll(/^\s*-?\s*role\s*:\s*["']?([\w-]+)/gm)) if (m[1] !== "admin") roles.add(m[1]);
  }
  const makefile = join(root, "Makefile");
  const targets = new Set();
  if (existsSync(makefile)) {
    for (const m of readFileSync(makefile, "utf8").matchAll(/^([A-Za-z0-9][\w.-]*)[ \t]*:(?![=:])/gm)) if (/hasura|dbml/i.test(m[1])) targets.add(m[1]);
  }
  const hasuraRoot = relative(root, hasuraDir) || ".";
  const env = database ? { HASURA_MIGRATIONS_SUBDIR: `${migrations}/${database}`, HASURA_METADATA_SUBDIR: `${metadata}/databases/${database}/tables` } : {};
  const { HASURA_ROOT: _given, ...given } = envArgs;
  const cache = { schema: 1, hasuraRoot, database, roles: [...roles].sort(), makeTargets: [...targets].sort(), env: { HASURA_ROOT: hasuraRoot, ...env, ...given } };
  mkdirSync(join(root, ".raftkit"), { recursive: true });
  writeFileSync(join(root, ".raftkit", "hasura.json"), `${JSON.stringify(cache, null, 2)}\n`);
  if (!asJson) console.log("wrote .raftkit/hasura.json");
}
