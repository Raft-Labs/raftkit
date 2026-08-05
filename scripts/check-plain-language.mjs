#!/usr/bin/env node
// Scans markdown files for ```output fenced blocks — the fence convention
// raftkit-core/house-rules/references/plain-language.md defines for any
// literal text a human reads — and checks each block against that contract:
// no banned filler, no sentence over 25 words, no named HTML entity, and no
// internal-only label leaking through.
//
// Usage: node scripts/check-plain-language.mjs <file-or-dir> [...]
// Exit 0 and a summary on stdout when every block is clean; exit 1 and one
// violation per line on stderr otherwise.

import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

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

function collectMarkdownFiles(target, out) {
  const st = statSync(target);
  if (st.isDirectory()) {
    for (const entry of readdirSync(target)) collectMarkdownFiles(join(target, entry), out);
  } else if (st.isFile() && target.endsWith(".md")) {
    out.push(target);
  }
}

function extractOutputBlocks(src) {
  const lines = src.split("\n");
  const blocks = [];
  let inBlock = false;
  let start = 0;
  let body = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!inBlock && /^\s*```output\s*$/.test(line)) {
      inBlock = true;
      body = [];
      start = i + 2; // 1-indexed line of the block's first content line
      continue;
    }
    if (inBlock && /^\s*```\s*$/.test(line)) {
      inBlock = false;
      blocks.push({ start, body: body.slice() });
      continue;
    }
    if (inBlock) body.push(line);
  }
  return blocks;
}

function splitSentences(line) {
  const trimmed = line.trim();
  if (!trimmed) return [];
  const parts = trimmed.split(/(?<=[.!?])\s+/).filter(Boolean);
  return parts.length ? parts : [trimmed];
}

function checkBlock(file, block, violations) {
  const text = block.body.join("\n");
  const lower = text.toLowerCase();

  for (const phrase of BANNED_PHRASES) {
    if (lower.includes(phrase)) {
      violations.push(`${file}:${block.start}: banned phrase "${phrase}"`);
    }
  }

  for (const label of FORBIDDEN_LABELS) {
    if (text.includes(label)) {
      violations.push(`${file}:${block.start}: internal-only label "${label}" leaked into output`);
    }
  }

  if (/&[a-zA-Z]+;/.test(text)) {
    violations.push(`${file}:${block.start}: named HTML entity found — use the literal character`);
  }

  for (const line of block.body) {
    for (const sentence of splitSentences(line)) {
      const words = sentence.split(/\s+/).filter(Boolean).length;
      if (words === 0) continue;
      if (words > MAX_SENTENCE_WORDS) {
        violations.push(
          `${file}:${block.start}: sentence over ${MAX_SENTENCE_WORDS} words (${words}): "${sentence.slice(0, 70)}"`,
        );
      }
    }
  }
}

const targets = process.argv.slice(2);
if (targets.length === 0) {
  console.error("usage: check-plain-language.mjs <file-or-dir> [...]");
  process.exit(2);
}

const files = [];
for (const target of targets) collectMarkdownFiles(target, files);

let blockCount = 0;
const violations = [];
for (const file of files) {
  const src = readFileSync(file, "utf8");
  const blocks = extractOutputBlocks(src);
  blockCount += blocks.length;
  for (const block of blocks) checkBlock(file, block, violations);
}

if (violations.length > 0) {
  console.error(violations.join("\n"));
  process.exit(1);
}

console.log(`checked ${blockCount} output block(s) across ${files.length} file(s), all clean`);
