#!/usr/bin/env node
// Scans markdown files for ```output fenced blocks — the fence convention
// raftkit-core/house-rules/references/plain-language.md defines for any
// literal text a human reads — and checks each block against that contract:
// no banned filler (word-boundary matched, case-insensitive, so
// "uncertainly" doesn't trip on "certainly"), no sentence over 25 words
// (measured after rejoining hard-wrapped lines), no block averaging over 15
// words/sentence, no named or numeric HTML entity, no internal-only label
// leaking through (WEESLD, any case), and no Gate-N reference past what the
// glossary covers. A block whose fence is opened but never closed is
// flagged, and its accumulated content is still checked by every rule
// above rather than silently dropped.
//
// The Gate-N check is deliberately narrow: it generalizes to the one house
// term family that has a natural "future variant" (Gate 3, Gate 4, ...). It
// does not attempt open-vocabulary jargon detection — the repo already uses
// bracket placeholders like [Platform][Severity] for unrelated template
// syntax, so a generic "any unglossed term" heuristic would misfire there.
//
// Usage: node scripts/check-plain-language.mjs <file-or-dir> [...]
// Exit 0 and a summary on stdout when every block is clean; exit 1 and one
// violation per line on stderr when a block fails a rule; exit 2 on a
// misconfigured invocation (no target given, or a target that doesn't
// exist) — never conflated with "clean" or "violations found".

import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const BANNED_PHRASES = [
  "utilize",
  "leverage",
  "furthermore",
  "in order to",
  "at this point in time",
  "please be advised",
  "kindly",
  "as an ai",
  "great question",
  "certainly",
  "it should be noted",
  "facilitate",
  "going forward",
];

const FORBIDDEN_LABELS = ["WEESLD"];

const MAX_SENTENCE_WORDS = 25;
const MAX_BLOCK_AVERAGE_WORDS = 15;

// Word-boundary, case-insensitive matchers — a raw substring match would flag
// "deleverage" for "leverage" or "uncertainly" for "certainly", and miss
// "Leverage" at a sentence start.
function wordBoundaryPattern(phrase) {
  const escaped = phrase.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp(`\\b${escaped}\\b`, "i");
}
const BANNED_PHRASE_PATTERNS = BANNED_PHRASES.map((phrase) => [phrase, wordBoundaryPattern(phrase)]);
const FORBIDDEN_LABEL_PATTERNS = FORBIDDEN_LABELS.map((label) => [label, wordBoundaryPattern(label)]);

// The glossary table is the single source of which Gate numbers are
// covered — parsed live so the checker and plain-language.md can't drift.
const GLOSSARY_REF = join(
  dirname(fileURLToPath(import.meta.url)),
  "..",
  "plugins/raftkit-core/skills/house-rules/references/plain-language.md",
);

function knownGateNumbers() {
  const src = readFileSync(GLOSSARY_REF, "utf8");
  const numbers = new Set();
  for (const line of src.split("\n")) {
    const m = /^\|\s*Gate\s+(\d+)\s*\|/i.exec(line);
    if (m) numbers.add(m[1]);
  }
  return numbers;
}

function collectMarkdownFiles(target, out) {
  let st;
  try {
    st = statSync(target);
  } catch (err) {
    // A bad target must never look like "violations found" (exit 1) — that
    // would let a typo'd or renamed path pass every downstream check that
    // only looks at the exit code.
    console.error(`cannot read target "${target}": ${err.code || err.message}`);
    process.exit(2);
  }
  if (st.isDirectory()) {
    for (const entry of readdirSync(target)) collectMarkdownFiles(join(target, entry), out);
  } else if (st.isFile() && target.endsWith(".md")) {
    out.push(target);
  }
}

// Nested fences are tracked as a depth counter, not a boolean — a bare ```
// closer only ends the outer `output` block once every inner fence opened
// inside it (each one a ```<info-string> line) has already been closed.
// A boolean flag collapses two levels of nesting into one, mistaking the
// close of an inner fence for the close of the outer block.
function extractOutputBlocks(file, src, violations) {
  const lines = src.split("\n");
  const blocks = [];
  let inBlock = false;
  let nestDepth = 0;
  let start = 0;
  let body = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!inBlock && /^\s*```output\s*$/.test(line)) {
      inBlock = true;
      nestDepth = 0;
      body = [];
      start = i + 2; // 1-indexed line of the block's first content line
      continue;
    }
    if (inBlock && /^\s*```/.test(line)) {
      if (/^\s*```\S/.test(line)) {
        // A fence opener with an info string is a quoted code sample, not
        // the block's own closer — it opens one more level of nesting.
        nestDepth++;
      } else if (nestDepth > 0) {
        // A bare closer while nested closes the innermost open fence, not
        // the outer output block.
        nestDepth--;
      } else {
        inBlock = false;
        blocks.push({ start, body: body.slice() });
        continue;
      }
    }
    if (inBlock) body.push(line);
  }
  // An output fence left open to EOF (outer or inner) must never be a
  // silent, unchecked pass — its accumulated content is still pushed so
  // every other rule below still runs against it.
  if (inBlock) {
    violations.push(`${file}:${start}: unterminated \`\`\`output fence opened here — content still checked`);
    blocks.push({ start, body: body.slice() });
  }
  return blocks;
}

function splitSentences(text) {
  const trimmed = text.trim();
  if (!trimmed) return [];
  const parts = trimmed.split(/(?<=[.!?])\s+/).filter(Boolean);
  return parts.length ? parts : [trimmed];
}

// Joins a hard-wrapped sentence's continuation lines back into one line
// before sentence-splitting, so word count doesn't depend on where the
// file happened to wrap — the shape every file in this repo is written in.
// A line is a wrap continuation of the previous one whenever: the previous
// line has no sentence-ending punctuation, and this line does not open a
// new bullet/numbered item or heading. The next line's case is NOT part of
// the test — a sentence that wraps right before a capitalized word or
// acronym (e.g. "...continues into the next line about the API before the
// period.") is still a continuation, not a new statement, and must not
// escape the cap just because of where it happened to wrap.
function joinWrappedLines(bodyLines) {
  const units = [];
  let current = null;
  for (const raw of bodyLines) {
    const line = raw.trim();
    if (line === "") {
      if (current !== null) units.push(current);
      current = null;
      continue;
    }
    const startsNewUnit = /^([-*•]\s|\d+[.)]\s|#{1,6}\s)/.test(line);
    const prevOpen = current !== null && !/[.!?]$/.test(current);
    if (prevOpen && !startsNewUnit) {
      current = `${current} ${line}`;
    } else {
      if (current !== null) units.push(current);
      current = line;
    }
  }
  if (current !== null) units.push(current);
  return units;
}

function checkSentenceLength(file, block, violations) {
  const wordCounts = [];
  for (const unit of joinWrappedLines(block.body)) {
    for (const sentence of splitSentences(unit)) {
      const words = sentence.split(/\s+/).filter(Boolean).length;
      if (words === 0) continue;
      wordCounts.push(words);
      if (words > MAX_SENTENCE_WORDS) {
        violations.push(
          `${file}:${block.start}: sentence over ${MAX_SENTENCE_WORDS} words (${words}): "${sentence.slice(0, 70)}"`,
        );
      }
    }
  }
  // The average only means something as a signal distinct from the max
  // once a block has 2+ sentences — on a single-sentence block it just
  // restates the same cap at a stricter threshold.
  if (wordCounts.length > 1) {
    const avg = wordCounts.reduce((a, b) => a + b, 0) / wordCounts.length;
    if (avg > MAX_BLOCK_AVERAGE_WORDS) {
      violations.push(
        `${file}:${block.start}: block averages ${avg.toFixed(1)} words/sentence, over ${MAX_BLOCK_AVERAGE_WORDS}`,
      );
    }
  }
}

function checkGateCoverage(file, block, text, violations, gateNumbers) {
  for (const m of text.matchAll(/\bGate\s+(\d+)\b/gi)) {
    if (!gateNumbers.has(m[1])) {
      violations.push(
        `${file}:${block.start}: house term "Gate ${m[1]}" used in an output block but has no glossary entry`,
      );
    }
  }
}

function checkBlock(file, block, violations, gateNumbers) {
  const text = block.body.join("\n");

  for (const [phrase, pattern] of BANNED_PHRASE_PATTERNS) {
    if (pattern.test(text)) {
      violations.push(`${file}:${block.start}: banned phrase "${phrase}"`);
    }
  }

  for (const [label, pattern] of FORBIDDEN_LABEL_PATTERNS) {
    if (pattern.test(text)) {
      violations.push(`${file}:${block.start}: internal-only label "${label}" leaked into output`);
    }
  }

  if (/&(?:[a-zA-Z]+|#\d+|#x[0-9a-fA-F]+);/.test(text)) {
    violations.push(`${file}:${block.start}: HTML entity found — use the literal character`);
  }

  checkSentenceLength(file, block, violations);
  checkGateCoverage(file, block, text, violations, gateNumbers);
}

const targets = process.argv.slice(2);
if (targets.length === 0) {
  console.error("usage: check-plain-language.mjs <file-or-dir> [...]");
  process.exit(2);
}

const files = [];
for (const target of targets) collectMarkdownFiles(target, files);

const gateNumbers = knownGateNumbers();
let blockCount = 0;
const violations = [];
for (const file of files) {
  const src = readFileSync(file, "utf8");
  const blocks = extractOutputBlocks(file, src, violations);
  blockCount += blocks.length;
  for (const block of blocks) checkBlock(file, block, violations, gateNumbers);
}

if (violations.length > 0) {
  console.error(violations.join("\n"));
  process.exit(1);
}

console.log(`checked ${blockCount} output block(s) across ${files.length} file(s), all clean`);
