#!/usr/bin/env node
// Scans markdown files for YAML frontmatter that a strict parser rejects.
//
// The defect this exists for: a plain (unquoted) YAML scalar may not contain
// ": " — a colon followed by a space. YAML reads that as a nested mapping
// entry, and because the nesting is unindented the whole block fails with
// "bad indentation of a mapping entry". The parser does not lose just that
// one value; it rejects the ENTIRE frontmatter, so `name`, `description` and
// every other key go with it and the skill loads with no metadata at all.
// It never triggers, and nothing says why. A lenient parser accepts the same
// file, so the failure appears only on the strict one and reads as a skill
// that mysteriously does not fire.
//
// The shape that keeps reappearing is a trailing cross-reference:
//   description: File a bug ... Fixing: raftkit-dev:fix.
// Write it with an em dash instead — `Fixing — raftkit-dev:fix.` — which
// keeps the scalar plain. Quoting works too, but most of these descriptions
// already contain double quotes around trigger phrases, so quoting means
// escaping and is easy to get wrong later.
//
// A value ending in a bare `:` is flagged for the same reason. Values that
// are explicitly quoted, block scalars (| >), flow collections ([ {) or
// anchors/aliases (& *) are skipped — those are not plain scalars and may
// legally contain a colon-space.
//
// A sequence item carrying a colon-space (`- Bash: the tool that runs it`)
// is a SEPARATE and milder fault, reported with its own message. That is
// legal YAML: the item silently becomes the mapping {Bash: "the tool that
// runs it"} instead of the string you meant, so the block still parses and
// only that one entry is the wrong type. Verified against a strict parser
// rather than assumed — the two cases must not claim the same consequence.
//
// Deliberately implemented with node builtins and a line scan rather than a
// YAML library: CI installs the pinned Claude CLI and nothing else, never
// `npm install`, so node_modules/ is not present when this runs.
//
// Usage: node scripts/check-frontmatter.mjs <file-or-dir> [...]
// Exit 0 and a summary on stdout when every block is clean; exit 1 and one
// violation per line on stderr when a block fails a rule; exit 2 on a
// misconfigured invocation (no target given, or a target that doesn't
// exist) — never conflated with "clean" or "violations found".

import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

// Not plain scalars: a quoted string, a block scalar, a flow collection, or
// an anchor/alias. Each may legally carry a colon-space.
const NOT_A_PLAIN_SCALAR = /^["'|>[{&*]/;

const KEY_LINE = /^(\s*)([A-Za-z0-9_.-]+):(\s*)(.*)$/;
const LIST_ITEM = /^\s*-\s+(.*)$/;

function collectMarkdownFiles(target, out) {
  let st;
  try {
    st = statSync(target);
  } catch {
    console.error(`cannot read target: ${target}`);
    process.exit(2);
  }
  if (st.isDirectory()) {
    for (const entry of readdirSync(target).sort()) {
      collectMarkdownFiles(join(target, entry), out);
    }
  } else if (target.endsWith(".md")) {
    out.push(target);
  }
}

// Returns the frontmatter's lines with their 1-based line numbers, or null
// when the file has no frontmatter at all. An opened but never closed block
// is reported and its lines are still checked rather than silently dropped.
function extractFrontmatter(file, src, violations) {
  const lines = src.split("\n");
  if (lines[0] !== "---") return null;

  for (let i = 1; i < lines.length; i++) {
    if (lines[i] === "---" || lines[i] === "...") {
      return lines.slice(1, i).map((text, j) => ({ text, line: j + 2 }));
    }
  }

  violations.push(`${file}:1: unterminated frontmatter block (opened with --- and never closed)`);
  return lines.slice(1).map((text, j) => ({ text, line: j + 2 }));
}

function valueOf(text) {
  const key = text.match(KEY_LINE);
  if (key) return { value: key[4], key: key[2] };
  const item = text.match(LIST_ITEM);
  if (item) return { value: item[1], key: null };
  return null;
}

function checkBlock(file, block, violations) {
  for (const { text, line } of block) {
    if (text.trim() === "" || text.trimStart().startsWith("#")) continue;

    const found = valueOf(text);
    if (!found) continue;

    const value = found.value.trim();
    if (value === "" || NOT_A_PLAIN_SCALAR.test(value)) continue;

    // A sequence item and a key's value fail differently, so they must not
    // be reported as if they failed the same way.
    if (found.key === null) {
      if (value.includes(": ")) {
        violations.push(
          `${file}:${line}: colon-space in an unquoted sequence item — YAML reads ` +
            `this as a mapping, so the item becomes an object instead of the ` +
            `string it reads as. Use an em dash, or quote the item.`
        );
      }
      continue;
    }

    if (value.includes(": ")) {
      violations.push(
        `${file}:${line}: colon-space in the unquoted value of \`${found.key}\` — ` +
          `a strict YAML parser rejects the whole frontmatter block, so the ` +
          `file loads with no metadata. Use an em dash, or quote the value.`
      );
    } else if (value.endsWith(":")) {
      violations.push(
        `${file}:${line}: the unquoted value of \`${found.key}\` ends in a bare ` +
          `colon — a strict YAML parser rejects the whole frontmatter block. ` +
          `Use an em dash, or quote the value.`
      );
    }
  }
}

const targets = process.argv.slice(2);
if (targets.length === 0) {
  console.error("usage: check-frontmatter.mjs <file-or-dir> [...]");
  process.exit(2);
}

const files = [];
for (const target of targets) collectMarkdownFiles(target, files);

let blockCount = 0;
const violations = [];
for (const file of files) {
  const src = readFileSync(file, "utf8");
  const block = extractFrontmatter(file, src, violations);
  if (block === null) continue;
  blockCount += 1;
  checkBlock(file, block, violations);
}

if (violations.length > 0) {
  console.error(violations.join("\n"));
  process.exit(1);
}

console.log(`checked ${blockCount} frontmatter block(s) across ${files.length} file(s), all clean`);
