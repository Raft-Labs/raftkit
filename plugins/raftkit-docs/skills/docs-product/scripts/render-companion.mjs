#!/usr/bin/env node
// Deliver the project-local docs companion to the Claude Code destination.
//
// RaftKit is Claude Code and Claude apps only (CLAUDE.md) — there is no
// cross-runtime rendering here. This validates the companion's frontmatter
// (name + description present) and writes it through unchanged; a validation
// failure writes nothing.
//
// Usage:
//   node render-companion.mjs --source <SKILL.md> --out <path>
// Exit codes: 0 written · 2 bad input · 3 validation failed (nothing written).
import { readFileSync, writeFileSync } from "node:fs";

const args = process.argv.slice(2);
const flag = (n) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : undefined; };
const source = flag("--source"), out = flag("--out");
const bad = (m) => { console.error(m); process.exit(2); };
if (!source || !out) bad("usage: render-companion.mjs --source <SKILL.md> --out <path>");

const text = readFileSync(source, "utf8");
const m = text.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
if (!m) bad("source has no YAML frontmatter block");
const [, fm] = m;

const keys = fm.split("\n").map((l) => l.match(/^([A-Za-z0-9_-]+):/)?.[1]).filter(Boolean);
const problems = [];
if (!keys.includes("name")) problems.push("missing required field: name");
if (!keys.includes("description")) problems.push("missing required field: description");
if (problems.length) { console.error(`validation failed:\n  ${problems.join("\n  ")}\nNothing written.`); process.exit(3); }

writeFileSync(out, text);
console.log(`delivered companion -> ${out} (fields: ${keys.join(", ")})`);
