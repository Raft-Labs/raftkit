#!/usr/bin/env node
// Scans markdown files for ```output fenced blocks — the fence convention
// raftkit-core/house-rules/references/plain-language.md defines for any
// literal text a human reads — and checks each block against that contract:
// no banned filler (word-boundary matched, so "uncertainly" doesn't trip on
// "certainly"), no sentence over 25 words, no block averaging over 15
// words/sentence, no named HTML entity, no internal-only label leaking
// through (any case), and no Gate-N reference past what the glossary
// covers. A block whose fence is opened but never closed is flagged rather
// than silently dropped.
//
// The Gate-N check is deliberately narrow: it generalizes to the one house
// term family that has a natural "future variant" (Gate 3, Gate 4, ...). It
// does not attempt open-vocabulary jargon detection — the repo already uses
// bracket placeholders like [Platform][Severity] for unrelated template
// syntax, so a generic "any unglossed term" heuristic would misfire there.
//
// Usage: node scripts/check-plain-language.mjs <file-or-dir> [...]
// Exit 0 and a summary on stdout when every block is clean; exit 1 and one
// violation per line on stderr otherwise.

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
const BANNED_PHRASE_PATTERNS = BANNED_PHRASES.map(
  (phrase) => ({ phrase, re: new RegExp(`\\b${phrase.replace(/ /g, "\\s+")}\\b`) }),
);

const FORBIDDEN_LABELS = ["WEESLD"];

const MAX_SENTENCE_WORDS = 25;
const MAX_BLOCK_AVERAGE_WORDS = 15;

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
  const st = statSync(target);
  if (st.isDirectory()) {
    for (const entry of readdirSync(target)) collectMarkdownFiles(join(target, entry), out);
  } else if (st.isFile() && target.endsWith(".md")) {
    out.push(target);
  }
}

function extractOutputBlocks(src, file, violations) {
  const lines = src.split("\n");
  const blocks = [];
  let inBlock = false;
  let start = 0;
  let openLine = 0;
  let body = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!inBlock && /^\s*```output\s*$/.test(line)) {
      inBlock = true;
      body = [];
      start = i + 2; // 1-indexed line of the block's first content line
      openLine = i + 1;
      continue;
    }
    if (inBlock && /^\s*```\s*$/.test(line)) {
      inBlock = false;
      blocks.push({ start, body: body.slice() });
      continue;
    }
    if (inBlock) body.push(line);
  }
  if (inBlock) {
    violations.push(`${file}:${openLine}: output fence opened here is never closed`);
    blocks.push({ start, body });
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
// A line is a wrap continuation of the previous one only when: the
// previous line has no sentence-ending punctuation, this line is not a
// bullet/numbered item, and this line starts lowercase (continuing a
// clause rather than opening a new statement). That keeps stacked
// independent lines — bullets, "Owner: ..." trailers, back-to-back status
// lines with no blank line between them — from being merged into one
// artificial run-on sentence.
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
    const isBullet = /^([-*•]\s|\d+[.)]\s)/.test(line);
    const startsLower = /^[a-z]/.test(line);
    const prevOpen = current !== null && !/[.!?]$/.test(current);
    if (prevOpen && !isBullet && startsLower) {
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
  const lower = text.toLowerCase();

  for (const { phrase, re } of BANNED_PHRASE_PATTERNS) {
    if (re.test(lower)) {
      violations.push(`${file}:${block.start}: banned phrase "${phrase}"`);
    }
  }

  for (const label of FORBIDDEN_LABELS) {
    if (lower.includes(label.toLowerCase())) {
      violations.push(`${file}:${block.start}: internal-only label "${label}" leaked into output`);
    }
  }

  if (/&[a-zA-Z]+;/.test(text)) {
    violations.push(`${file}:${block.start}: named HTML entity found — use the literal character`);
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
  const blocks = extractOutputBlocks(src, file, violations);
  blockCount += blocks.length;
  for (const block of blocks) checkBlock(file, block, violations, gateNumbers);
}

if (violations.length > 0) {
  console.error(violations.join("\n"));
  process.exit(1);
}

console.log(`checked ${blockCount} output block(s) across ${files.length} file(s), all clean`);
