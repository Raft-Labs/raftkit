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
//   - a discovered hasura project root (a dir containing config.yaml)
//   - a Hasura CLI config / --project marker
// Package/Profile stack evidence is passed in by the caller when available.
//
// Usage: node detect-hasura.mjs --root <repo> [--json] [--write [--env NAME=VALUE]...]
// Exit codes: 0 detected · 1 not detected (nothing written) · 2 bad input.
import { readFileSync, existsSync, readdirSync, statSync, mkdirSync, writeFileSync } from "node:fs";
import { join, relative, resolve } from "node:path";

const args = process.argv.slice(2);
const flag = (n) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : undefined; };
const asJson = args.includes("--json");
const root = flag("--root");
if (!root) { console.error("usage: detect-hasura.mjs --root <dir> [--json]"); process.exit(2); }
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

// Look for a nested hasura project root (e.g. services/hasura) exactly as
// lib/common.sh find_hasura_root does: every */config.yaml, then every
// */*/config.yaml, names sorted, dot-directories skipped (bash globs skip them).
const subdirs = (rel) => {
  try { return readdirSync(join(root, rel)).filter((n) => !n.startsWith(".") && isDir(join(root, rel, n))).sort().map((n) => (rel ? `${rel}/${n}` : n)); }
  catch { return []; }
};
if (signals.length === 0 && isDir(root)) {
  const depth1 = subdirs("");
  const nested = [...depth1, ...depth1.flatMap(subdirs)].find((rel) => existsSync(join(root, rel, "config.yaml")));
  if (nested) {
    signals.push(`nested Hasura project root: ${nested}/`);
    conventions.hasuraRoot = join(root, nested);
  }
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
// `env`, the variables to set when running the scaffolder.
function writeCache() {
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
  const env = database ? { HASURA_MIGRATIONS_SUBDIR: `${migrations}/${database}`, HASURA_METADATA_SUBDIR: `${metadata}/databases/${database}/tables` } : {};
  const cache = { schema: 1, hasuraRoot: relative(root, hasuraDir) || ".", database, roles: [...roles].sort(), makeTargets: [...targets].sort(), env: { ...env, ...envArgs } };
  mkdirSync(join(root, ".raftkit"), { recursive: true });
  writeFileSync(join(root, ".raftkit", "hasura.json"), `${JSON.stringify(cache, null, 2)}\n`);
  if (!asJson) console.log("wrote .raftkit/hasura.json");
}
