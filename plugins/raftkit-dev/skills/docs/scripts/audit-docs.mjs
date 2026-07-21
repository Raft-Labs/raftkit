#!/usr/bin/env node
// Deterministic discovery reporter for the docs skill. Emits the in-memory
// discovery result — preflight branch, convention, roots, ownership evidence,
// history convention, ADR seam, confidence, unresolved conflicts — and nothing
// else. Pure reader: mutates nothing, persists nothing, follows the same
// root-confinement and secret-safety rules as validate-docs.mjs (shared code).
//
// Usage: node audit-docs.mjs --root <repo-root> [--json] [--out <path-inside-root>]
// Exit codes: 0 report produced (conflicts are reported, not fatal) · 2 bad input.
import { writeFileSync } from "node:fs";
import path from "node:path";
import { parseArgs, resolveRoot, withinReal, discover, bad } from "./validate-docs.mjs";

const opts = parseArgs(process.argv.slice(2));
const root = resolveRoot(opts.root);
if (opts.out && !withinReal(root, opts.out)) bad(`--out must stay inside the repository root: ${opts.out}`);

const d = discover(root);
const result = {
  branch: d.branch,
  convention: d.convention,
  docsRoot: d.docsRoot,
  ownershipSources: d.ownershipSources,
  ownershipEntries: d.ownership.length,
  historyConvention: d.historyConvention,
  adrSeam: d.adrSeam,
  confidence: d.confidence,
  unresolvedConflicts: d.unresolvedConflicts,
  excludedFiles: d.excludedFiles.length,
  walkFindings: d.walkFindings,
};
const text = [
  `branch: ${d.branch}`,
  `convention: ${d.convention} (confidence: ${d.confidence})`,
  `docs root: ${d.docsRoot ?? "none"}`,
  `ownership: ${d.ownership.length} mapping(s) from ${d.ownershipSources.join(", ") || "none"}`,
  `history convention: ${d.historyConvention ?? "none detected"}`,
  `ADR seam: ${d.adrSeam}`,
  d.unresolvedConflicts.length ? `unresolved conflicts:\n  ${d.unresolvedConflicts.join("\n  ")}` : null,
  ...d.walkFindings.map((f) => `finding: ${f}`),
].filter(Boolean).join("\n");

const output = opts.json ? JSON.stringify(result, null, 2) : text;
if (opts.out) writeFileSync(path.resolve(root, opts.out), output + "\n"); else console.log(output);
