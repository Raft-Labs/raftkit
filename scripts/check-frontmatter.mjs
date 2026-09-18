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
// Faults covered, each of which makes the block silently fail to load:
//   1. colon-space in a plain (unquoted) scalar
//   2. a plain scalar ending in a bare colon
//   3. a tab in a line's indentation
//   4. a duplicated top-level key
//   5. a quoted scalar that is never closed
//   6. a plain scalar opening with a YAML reserved indicator (@ or `)
//   7. a mapping entry indented under a plain scalar
//   8. an unterminated frontmatter block
//
// This is a targeted scan, NOT a YAML parser, and it does not claim to
// accept only valid YAML. Every rule above was checked in both directions
// against a strict parser: each fault is one it really rejects, and the
// legal shapes that look similar are left alone — plain multi-line folding,
// a block scalar whose body contains colons, nested mappings, quotes and
// apostrophes inside a plain scalar, and a tab after the key's colon.
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
// an anchor/alias. Each may legally contain a colon-space.
const NOT_A_PLAIN_SCALAR = /^["'|>[{&*]/;

// `@` and a backtick are reserved as the first character of a plain scalar.
const RESERVED_INDICATOR = /^[@`]/;

const KEY_LINE = /^([ \t]*)([A-Za-z0-9_.-]+):([ \t]*)(.*)$/;
const LIST_ITEM = /^[ \t]*-[ \t]+(.*)$/;

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

// Walks a quoted scalar looking for its unescaped closing quote. A double
// quote escapes with a backslash, a single quote by doubling itself. Quoted
// scalars may legally span lines, so "not closed here" is not yet a fault.
function closesOnThisLine(text, quote) {
  for (let i = 1; i < text.length; i++) {
    const ch = text[i];
    if (quote === '"' && ch === "\\") {
      i++;
      continue;
    }
    if (ch !== quote) continue;
    if (quote === "'" && text[i + 1] === "'") {
      i++;
      continue;
    }
    return true;
  }
  return false;
}

// The three faults a plain (unquoted) scalar can carry on its own. Split out
// of checkBlock to keep that walk readable: it is a state machine over the
// block's lines, and inlining these made it both long and branchy.
function checkPlainScalar(file, line, name, value, violations) {
  if (RESERVED_INDICATOR.test(value)) {
    violations.push(
      `${file}:${line}: the unquoted value of \`${name}\` opens with the reserved ` +
        `indicator "${value[0]}" — a strict YAML parser rejects the whole ` +
        `frontmatter block. Quote the value.`
    );
  }

  if (value.includes(": ")) {
    violations.push(
      `${file}:${line}: colon-space in the unquoted value of \`${name}\` — ` +
        `a strict YAML parser rejects the whole frontmatter block, so the ` +
        `file loads with no metadata. Use an em dash, or quote the value.`
    );
  } else if (value.endsWith(":")) {
    violations.push(
      `${file}:${line}: the unquoted value of \`${name}\` ends in a bare ` +
        `colon — a strict YAML parser rejects the whole frontmatter block. ` +
        `Use an em dash, or quote the value.`
    );
  }
}

// A sequence item carrying a colon-space is legal YAML but almost never what
// was meant, so it is reported with its own wording — see the header.
function checkSequenceItem(file, line, value, violations) {
  if (NOT_A_PLAIN_SCALAR.test(value) || !value.includes(": ")) return;
  violations.push(
    `${file}:${line}: colon-space in an unquoted sequence item — YAML reads ` +
      `this as a mapping, so the item becomes an object instead of the ` +
      `string it reads as. Use an em dash, or quote the item.`
  );
}

// Duplicates are only tracked at the top level. Deeper down, a line scan
// cannot tell a real duplicate from the same key in two sequence items,
// which is legal — so checking there would over-fire on ordinary lists.
function checkTopLevelKey(file, line, name, seen, violations) {
  if (!seen.has(name)) {
    seen.set(name, line);
    return;
  }
  violations.push(
    `${file}:${line}: duplicate top-level key \`${name}\` (first seen on line ` +
      `${seen.get(name)}) — a strict YAML parser rejects the whole ` +
      `frontmatter block.`
  );
}

function checkBlock(file, block, violations) {
  const topLevelKeys = new Map();
  let openQuote = null; // { quote, line, key }
  let blockScalarIndent = null;
  let plainScalarParent = null; // { indent, key }

  for (const { text, line } of block) {
    // --- inside a multi-line quoted scalar: only look for the close ---
    if (openQuote) {
      if (closesOnThisLine(`${openQuote.quote}${text}`, openQuote.quote)) openQuote = null;
      continue;
    }

    // --- inside a block scalar: its body may contain anything ---
    if (blockScalarIndent !== null) {
      const indent = text.match(/^[ \t]*/)[0].length;
      if (text.trim() === "" || indent > blockScalarIndent) continue;
      blockScalarIndent = null;
    }

    if (text.trim() === "" || text.trimStart().startsWith("#")) continue;

    const lead = text.match(/^[ \t]*/)[0];
    if (lead.includes("\t")) {
      violations.push(
        `${file}:${line}: tab character in indentation — YAML forbids tabs for ` +
          `indentation and rejects the whole frontmatter block. Use spaces.`
      );
    }

    const key = text.match(KEY_LINE);
    const item = text.match(LIST_ITEM);

    if (!key) {
      if (item) {
        checkSequenceItem(file, line, item[1].trim(), violations);
        plainScalarParent = null;
      }
      // Anything else is a plain multi-line continuation, which is legal.
      continue;
    }

    const indent = key[1].length;
    const name = key[2];
    const value = key[4].trim();

    // A mapping entry cannot be indented underneath a plain scalar.
    if (plainScalarParent && indent > plainScalarParent.indent) {
      violations.push(
        `${file}:${line}: \`${name}\` is indented under the plain scalar ` +
          `\`${plainScalarParent.key}\` — a strict YAML parser rejects the whole ` +
          `frontmatter block. Quote the value above, or make it a block scalar.`
      );
    }

    if (indent === 0) checkTopLevelKey(file, line, name, topLevelKeys, violations);

    if (value === "") {
      plainScalarParent = null;
      continue;
    }

    if (value[0] === "|" || value[0] === ">") {
      blockScalarIndent = indent;
      plainScalarParent = null;
      continue;
    }

    if (value[0] === '"' || value[0] === "'") {
      if (!closesOnThisLine(value, value[0])) openQuote = { quote: value[0], line, key: name };
      plainScalarParent = null;
      continue;
    }

    if (NOT_A_PLAIN_SCALAR.test(value)) {
      plainScalarParent = null;
      continue;
    }

    // --- a plain scalar ---
    plainScalarParent = { indent, key: name };
    checkPlainScalar(file, line, name, value, violations);
  }

  if (openQuote) {
    violations.push(
      `${file}:${openQuote.line}: the quoted value of \`${openQuote.key}\` is never ` +
        `closed — a strict YAML parser rejects the whole frontmatter block.`
    );
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
