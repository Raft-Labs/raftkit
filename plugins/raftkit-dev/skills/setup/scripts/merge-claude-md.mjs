#!/usr/bin/env node
// Splices raftkit-core's working agreement and Module Design Standard into a
// repo's CLAUDE.md as one marker-delimited block, byte for byte. Content
// outside the block is never touched. Pure without --write: it only reports
// what it would do, so the plan can be shown at setup's stop.
//
// The block body is working-agreement.md, one blank line, then
// design-standard.md, exactly as raftkit-core ships them. The begin marker
// carries the body's sha256; after a write the file is re-read and the body
// re-hashed, and a mismatch restores the original bytes.
//
// Usage: node merge-claude-md.mjs --core <raftkit-core install path> --claude-md <path> [--write]
// Exit codes: 0 planned, applied or no changes · 1 unreadable source or bad
// invocation, nothing written · 2 conflict, nothing written · 3 verification
// failed after the write, original restored.
import { readFileSync, writeFileSync, renameSync, unlinkSync, existsSync, lstatSync } from "node:fs";
import { createHash } from "node:crypto";
import path from "node:path";

const args = process.argv.slice(2);
const flag = (n) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : undefined; };
const core = flag("--core"), target = flag("--claude-md"), write = args.includes("--write");
const die = (code, msg) => { console.error(`reason: ${msg} — nothing written`); process.exit(code); };
if (!core || !target) die(1, "usage: --core <raftkit-core install path> --claude-md <path> [--write]");

const refs = path.join(core, "skills", "working-agreement", "references");
const read = (name) => {
  try { return readFileSync(path.join(refs, name), "utf8"); }
  catch { return die(1, `${path.join(refs, name)} is missing or unreadable`); }
};
const agreement = read("working-agreement.md"), standard = read("design-standard.md");
const sha = (s) => createHash("sha256").update(s, "utf8").digest("hex");
const body = `${agreement}\n${standard}`;
const digest = sha(body);
const BEGIN = "<!-- raftkit:working-agreement begin", END = "<!-- raftkit:working-agreement end -->";
const block = `${BEGIN} sha256=${digest} -->\n${body}${body.endsWith("\n") ? "" : "\n"}${END}\n`;

// --- locate the existing block, refusing anything ambiguous -----------------
let existing = null;
if (existsSync(target) || isLink(target)) {
  if (isLink(target)) die(2, `${target} is a symlink; setup never writes through it`);
  existing = readFileSync(target, "utf8");
}
function isLink(p) { try { return lstatSync(p).isSymbolicLink(); } catch { return false; } }

const lines = existing === null ? [] : existing.split("\n");
const begins = lines.flatMap((l, i) => (l.startsWith(BEGIN) ? [i] : []));
const ends = lines.flatMap((l, i) => (l.trim() === END ? [i] : []));
if (begins.length > 1 || ends.length > 1) die(2, `${target} holds more than one RaftKit block`);
if (begins.length !== ends.length || (begins.length && ends[0] < begins[0])) die(2, `${target} has an unmatched RaftKit block marker`);

let before = existing ?? "", after = "", oldDigest = null;
if (begins.length) {
  const offsetOf = (line) => lines.slice(0, line).join("\n").length + (line ? 1 : 0);
  before = existing.slice(0, offsetOf(begins[0]));
  after = existing.slice(offsetOf(ends[0]) + lines[ends[0]].length + 1);
  oldDigest = lines[begins[0]].match(/sha256=([0-9a-f]{64})/)?.[1] ?? null;
}
// An unmarked copy outside the block would leave the agreement in CLAUDE.md twice.
for (const heading of [agreement, standard].map((s) => s.split("\n").find((l) => l.trim()))) {
  const outside = `${before}\n${after}`.split("\n").findIndex((l) => l === heading);
  if (outside >= 0) die(2, `${target} already carries an unmarked copy ("${heading}"); remove it or wrap it in the RaftKit markers`);
}

const joiner = begins.length || before === "" ? "" : before.endsWith("\n\n") ? "" : before.endsWith("\n") ? "\n" : "\n\n";
const next = `${before}${joiner}${block}${after}`;
const short = (d) => (d ? d.slice(0, 12) : "unmarked");
const action = existing === null ? "create" : !begins.length ? "append" : next === existing ? "none" : "replace";

if (action === "none") { console.log(`CLAUDE.md: no changes (block sha256 ${short(digest)})`); process.exit(0); }
if (!write) {
  const what = { create: "would create it with", append: "would append", replace: `would replace (${short(oldDigest)} → ${short(digest)})` }[action];
  console.log(`CLAUDE.md: ${what} the RaftKit block, working agreement + design standard, sha256 ${short(digest)}; nothing outside the block changes`);
  process.exit(0);
}

// --- write atomically, then verify what landed --------------------------------
const tmp = path.join(path.dirname(target), `.CLAUDE.md.raftkit-tmp-${process.pid}`);
writeFileSync(tmp, next);
renameSync(tmp, target);
const landed = readFileSync(target, "utf8");
const m = landed.match(/^<!-- raftkit:working-agreement begin sha256=([0-9a-f]{64}) -->\n([\s\S]*?)^<!-- raftkit:working-agreement end -->$/m);
if (!m || m[1] !== digest || sha(m[2]) !== digest) {
  if (existing === null) unlinkSync(target); else writeFileSync(target, existing);
  console.error(`reason: the written block does not match sha256 ${short(digest)} — CLAUDE.md restored`);
  process.exit(3);
}
console.log(`CLAUDE.md: ${action === "create" ? "created" : action === "append" ? "appended" : "replaced"} the RaftKit block — verified sha256 ${short(digest)}`);
