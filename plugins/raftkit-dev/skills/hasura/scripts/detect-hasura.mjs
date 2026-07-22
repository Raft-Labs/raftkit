#!/usr/bin/env node
// Deterministic Hasura-project detector. Pure reader: it looks for Hasura
// signals under a root and reports whether the capability should activate and
// which conventions were discovered. A non-Hasura repository yields nothing and
// a non-zero exit — the capability never activates or installs assets there.
//
// Signals (any is sufficient; more raise confidence):
//   - a Hasura config.yaml (version:/metadata_directory:/endpoint:)
//   - a metadata/ directory alongside it
//   - a migrations/ directory alongside it
//   - a discovered hasura project root (a dir containing config.yaml)
//   - a Hasura CLI config / --project marker
// Package/Profile stack evidence is passed in by the caller when available.
//
// Usage: node detect-hasura.mjs --root <dir> [--json]
// Exit codes: 0 detected · 1 not detected · 2 bad input.
import { readFileSync, existsSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const args = process.argv.slice(2);
const flag = (n) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : undefined; };
const asJson = args.includes("--json");
const root = flag("--root");
if (!root) { console.error("usage: detect-hasura.mjs --root <dir> [--json]"); process.exit(2); }
if (!existsSync(root)) { console.error(`root not found: ${root}`); process.exit(2); }

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

// Look one level down for a nested hasura project root (e.g. services/hasura).
if (signals.length === 0 && isDir(root)) {
  for (const name of readdirSync(root)) {
    const sub = join(root, name);
    if (isDir(sub) && existsSync(join(sub, "config.yaml"))) {
      signals.push(`nested Hasura project root: ${name}/`);
      conventions.hasuraRoot = sub;
      break;
    }
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
process.exit(detected ? 0 : 1);
