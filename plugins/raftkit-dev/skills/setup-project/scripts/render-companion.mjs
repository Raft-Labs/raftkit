#!/usr/bin/env node
// Render the project-local docs companion for a specific agent runtime.
//
// Shared behavioral content has one source (the Claude-form companion
// SKILL.md); runtime-specific frontmatter is RENDERED per destination, never
// blind-copied. Claude-only frontmatter fields (user-invocable,
// disable-model-invocation, allowed-tools) must never leak into a Codex or
// Cursor artifact — those runtimes reject unknown keys. This script strips them
// and keeps only the fields each runtime documents, then validates the result.
//
// Usage:
//   node render-companion.mjs --source <SKILL.md> --runtime <claude|codex|cursor> --out <path>
// Exit codes: 0 rendered · 2 bad input · 3 validation failed (nothing written).
import { readFileSync, writeFileSync } from "node:fs";

const args = process.argv.slice(2);
const flag = (n) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : undefined; };
const source = flag("--source"), runtime = flag("--runtime"), out = flag("--out");
const bad = (m) => { console.error(m); process.exit(2); };
if (!source || !runtime || !out) bad("usage: render-companion.mjs --source <SKILL.md> --runtime <claude|codex|cursor> --out <path>");

// Fields each runtime documents in SKILL.md frontmatter (verified 2026-07-22).
// Claude: full set. Codex: name + description only (unknown keys rejected by
// the generic validator). Cursor: name, description, paths,
// disable-model-invocation, metadata.
const ALLOWED = {
  claude: null, // keep all
  codex: new Set(["name", "description"]),
  cursor: new Set(["name", "description", "paths", "disable-model-invocation", "metadata"]),
};
// Claude-only fields that must never appear in codex/cursor output.
const CLAUDE_ONLY = new Set(["user-invocable", "allowed-tools", "disallowed-tools", "effort", "context", "agent", "hooks"]);

if (!(runtime in ALLOWED)) bad(`unknown runtime: ${runtime} (claude|codex|cursor)`);

const text = readFileSync(source, "utf8");
const m = text.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
if (!m) bad("source has no YAML frontmatter block");
const [, fm, body] = m;

const lines = fm.split("\n");
const kept = [];
for (const ln of lines) {
  const key = ln.match(/^([A-Za-z0-9_-]+):/)?.[1];
  if (!key) { kept.push(ln); continue; } // continuation line
  const allow = ALLOWED[runtime];
  if (allow === null || allow.has(key)) kept.push(ln);
  // dropped otherwise
}

const renderedFm = kept.join("\n").trim();

// Validation (fail-closed, write nothing on failure):
const keys = renderedFm.split("\n").map((l) => l.match(/^([A-Za-z0-9_-]+):/)?.[1]).filter(Boolean);
const problems = [];
if (!keys.includes("name")) problems.push("missing required field: name");
if (!keys.includes("description")) problems.push("missing required field: description");
if (runtime !== "claude") {
  for (const k of keys) if (CLAUDE_ONLY.has(k)) problems.push(`Claude-only field leaked into ${runtime} artifact: ${k}`);
  const allow = ALLOWED[runtime];
  for (const k of keys) if (!allow.has(k)) problems.push(`field not accepted by ${runtime}: ${k}`);
}
if (problems.length) { console.error(`validation failed for ${runtime}:\n  ${problems.join("\n  ")}\nNothing written.`); process.exit(3); }

writeFileSync(out, `---\n${renderedFm}\n---\n${body.startsWith("\n") ? body : "\n" + body}`);
console.log(`rendered ${runtime} companion -> ${out} (fields: ${keys.join(", ")})`);
