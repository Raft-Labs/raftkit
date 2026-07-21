#!/usr/bin/env node
// Deterministic docs validator for the docs skill. Pure reader/reporter:
// discovers the repo's OWN documentation convention, checks links, and — given
// an EXPLICIT change set — checks stale/no-impact with named evidence. It never
// mutates docs, never picks a Git range silently, never leaves the repository
// root, and never reads secret/env file contents.
//
// Usage:
//   node validate-docs.mjs --root <repo-root> [--changed <file|->]
//        [--base <ref> [--head <ref>]] [--convention <descriptor.json>]
//        [--json] [--out <path-inside-root>]
// Exit codes: 0 clean (incl. evidence-backed no-impact) · 1 findings ·
//             2 bad input, unrecognized convention, or convention conflict.
import { readFileSync, writeFileSync, existsSync, lstatSync, readdirSync, realpathSync } from "node:fs";
import { execFileSync } from "node:child_process";
import path from "node:path";
import { pathToFileURL } from "node:url";

const EXCLUDED_DIRS = new Set([".git", ".hg", ".svn", "node_modules", "vendor", "build", "dist", "out", ".next", "coverage", ".cache", ".turbo", ".claude", ".agents", "tmp"]);
const SECRET_FILE = /^\.env(\.|$)|\.gpg$|\.pem$|\.key$|keystore|service-account.*\.json$|^\.envrc$/;

export const bad = (msg) => { console.error(msg); process.exit(2); };

export function parseArgs(argv) {
  const opts = { json: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--json") opts.json = true;
    else if (a === "--root") opts.root = argv[++i];
    else if (a === "--changed") opts.changed = argv[++i];
    else if (a === "--base") opts.base = argv[++i];
    else if (a === "--head") opts.head = argv[++i];
    else if (a === "--convention") opts.convention = argv[++i];
    else if (a === "--out") opts.out = argv[++i];
    else bad(`unknown argument: ${a}`);
  }
  return opts;
}

export function resolveRoot(rootArg) {
  if (!rootArg) bad("missing --root <repo-root>");
  if (!existsSync(rootArg)) bad(`root not found: ${rootArg}`);
  return realpathSync(path.resolve(rootArg));
}

export const within = (root, p) => {
  const rp = path.resolve(root, p);
  return rp === root || rp.startsWith(root + path.sep);
};

// Like within(), but resolves symlinks in the candidate's parent first, so a
// path spelled through a platform symlink (e.g. /var -> /private/var) compares
// against the realpath'd root correctly.
export const withinReal = (root, p) => {
  const abs = path.resolve(root, p);
  let dirReal;
  try { dirReal = realpathSync(path.dirname(abs)); } catch { dirReal = path.dirname(abs); }
  return within(root, path.join(dirReal, path.basename(abs)));
};

// Root-confined walk: excluded dirs skipped entirely, secret files listed by
// name only (never read), out-of-root symlinks refused and reported.
export function walk(root, dir, acc) {
  for (const name of readdirSync(dir)) {
    const full = path.join(dir, name);
    const st = lstatSync(full);
    if (st.isSymbolicLink()) {
      let target;
      try { target = realpathSync(full); } catch { acc.findings.push(`out-of-root symlink refused: ${path.relative(root, full)} (broken target)`); continue; }
      if (!within(root, target)) { acc.findings.push(`out-of-root symlink refused: ${path.relative(root, full)} — not followed`); continue; }
    }
    if (st.isDirectory() || (st.isSymbolicLink() && lstatSync(realpathSync(full)).isDirectory())) {
      if (EXCLUDED_DIRS.has(name)) { acc.excludedDirs++; continue; }
      walk(root, realpathSync(full), acc);
    } else {
      if (SECRET_FILE.test(name)) { acc.excludedFiles.push(path.relative(root, full)); continue; }
      acc.files.push(path.relative(root, full));
    }
  }
  return acc;
}

export function discover(root) {
  const acc = walk(root, root, { files: [], findings: [], excludedFiles: [], excludedDirs: 0 });
  const mds = acc.files.filter((f) => f.endsWith(".md"));
  const docsRoot = ["docs/project", "docs", "documentation"].find((c) =>
    mds.some((f) => f.startsWith(c + "/") && !f.startsWith(path.join(c, "specs") + "/")));
  const inRoot = docsRoot ? mds.filter((f) => f.startsWith(docsRoot + "/")) : [];

  const read = (f) => readFileSync(path.join(root, f), "utf8");
  const hasModules = inRoot.some((f) => f.startsWith(path.join(docsRoot || "", "modules") + "/"));
  const tableSources = inRoot.filter((f) => /\|\s*Code path\s*\|/.test(read(f)));
  const footerSources = inRoot.filter((f) => read(f).includes("Update when you change:"));

  const unresolvedConflicts = [];
  let convention = "none";
  if (docsRoot) {
    if (hasModules && tableSources.length) {
      convention = "ambiguous";
      unresolvedConflicts.push(`both a modules/ tree and an ownership table (${tableSources[0]}) are present — module-indexed vs flat-ownership-indexed is undecidable from evidence`);
    } else if (hasModules) convention = "module-indexed";
    else if (tableSources.length) convention = "flat-ownership-indexed";
    else if (footerSources.length) convention = "module-indexed";
    else { convention = "none"; }
  }

  const ownership = [];
  for (const src of tableSources) {
    for (const line of read(src).split("\n")) {
      const m = line.match(/^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|$/);
      if (!m || /Code path|^[-\s|:]+$/.test(m[1])) continue;
      for (const glob of m[1].split(",").map((s) => s.trim()))
        ownership.push({ glob, docs: m[2].split(",").map((s) => path.posix.join(docsRoot, s.trim())), source: src });
    }
  }
  for (const f of footerSources) {
    const m = read(f).match(/Update when you change:\*{0,2}\s*(.+)/);
    if (m) for (const glob of m[1].replace(/`/g, "").split(",").map((s) => s.trim()).filter(Boolean))
      ownership.push({ glob, docs: [f], source: f });
  }

  const specFilled = acc.files.some((f) => f.startsWith("docs/specs/") && f.endsWith(".md") && read(f).trim().length > 40);
  const hasCode = acc.files.some((f) => /\.(js|ts|jsx|tsx|py|go|rb|java|swift|kt)$/.test(f));
  const branch = docsRoot ? "living-docs" : specFilled && !hasCode ? "greenfield-handoff" : hasCode ? "existing-code-no-docs" : "greenfield-handoff";

  const adrSeam = Boolean(docsRoot && (inRoot.some((f) => f.startsWith(path.join(docsRoot, "adr") + "/")) || inRoot.includes(path.posix.join(docsRoot, "decisions.md"))));
  const historyConvention = inRoot.some((f) => /Last verified:|Update when you change:/.test(read(f))) ? "per-doc footer"
    : inRoot.some((f) => f.endsWith("changes-log.md")) ? "changes-log" : null;

  return { branch, convention, docsRoot: docsRoot || null, docsFiles: inRoot, ownership,
    ownershipSources: [...new Set(ownership.map((o) => o.source))], adrSeam, historyConvention,
    confidence: convention === "ambiguous" ? "low" : "high", unresolvedConflicts,
    excludedFiles: acc.excludedFiles, walkFindings: acc.findings };
}

export const globMatch = (glob, file) => {
  const esc = glob.replace(/[.+^${}()|[\]\\]/g, "\\$&");
  const rx = new RegExp("^" + esc.replace(/\*\*/g, "\u0001").replace(/\*/g, "[^/]*").replace(/\u0001/g, ".*") + "$");
  return rx.test(file) || (glob.endsWith("/**") && file === glob.slice(0, -3));
};

function resolveChangeSet(root, opts) {
  if (opts.changed) {
    const raw = opts.changed === "-" ? readFileSync(0, "utf8") : (existsSync(opts.changed) ? readFileSync(opts.changed, "utf8") : bad(`changed list not found: ${opts.changed}`));
    const files = raw.split("\n").map((s) => s.trim()).filter(Boolean);
    for (const f of files) if (path.isAbsolute(f) || !within(root, f)) bad(`changed path resolves outside the repository root: ${f}`);
    return { source: "explicit list (--changed)", files, renames: [] };
  }
  if (opts.base) {
    const refOk = (r) => typeof r === "string" && r.length > 0 && !r.startsWith("-") && /^[\w./~^@{}-]+$/.test(r);
    if (!refOk(opts.base) || (opts.head && !refOk(opts.head))) bad(`invalid revision: ${opts.base}${opts.head ? " / " + opts.head : ""}`);
    const rev = (r) => { try { return execFileSync("git", ["-C", root, "rev-parse", "--verify", "--quiet", r + "^{commit}"], { encoding: "utf8" }).trim(); } catch { bad(`unknown or ambiguous revision: ${r}`); } };
    const baseSha = rev(opts.base), headSha = rev(opts.head || "HEAD");
    const diff = execFileSync("git", ["-C", root, "diff", "--name-status", "-M", `${baseSha}..${headSha}`], { encoding: "utf8" });
    const files = [], renames = [];
    for (const line of diff.split("\n").filter(Boolean)) {
      const parts = line.split("\t");
      if (parts[0].startsWith("R")) { renames.push({ from: parts[1], to: parts[2] }); files.push(parts[1], parts[2]); }
      else files.push(parts[1]);
    }
    return { source: `git diff ${baseSha.slice(0, 12)}..${headSha.slice(0, 12)}`, baseSha, headSha, files, renames };
  }
  return null;
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  const root = resolveRoot(opts.root);
  if (opts.out && !withinReal(root, opts.out))
    bad(`--out must stay inside the repository root: ${opts.out}`);
  const d = discover(root);
  const findings = [...d.walkFindings];

  if (opts.convention) {
    if (!within(root, path.resolve(root, opts.convention)) && !existsSync(opts.convention)) bad(`--convention not found: ${opts.convention}`);
    const desc = JSON.parse(readFileSync(opts.convention, "utf8"));
    if (desc.convention && d.convention !== "none" && desc.convention !== d.convention) {
      console.error(`convention conflict:\n  discovered from the repository: ${d.convention}\n  approved descriptor (${opts.convention}): ${desc.convention}\nNo documentation was touched. Decide which convention should be authoritative — ask the human and update the descriptor or the docs, then re-run.`);
      process.exit(2);
    }
    if (d.convention === "none" && desc.convention) d.convention = desc.convention;
  }
  if (d.convention === "none") bad("no recognized documentation convention (and no approved descriptor supplied)");
  if (d.convention === "ambiguous") {
    console.error(`convention conflict:\n  ${d.unresolvedConflicts.join("\n  ")}\nDecide which convention should be authoritative — ask the human.`);
    process.exit(2);
  }

  for (const f of d.docsFiles) {
    const body = readFileSync(path.join(root, f), "utf8");
    for (const m of body.matchAll(/\]\(([^)]+)\)/g)) {
      const target = m[1].split("#")[0].trim();
      if (!target || /^(https?:|mailto:|#)/.test(target)) continue;
      const resolved = path.resolve(root, path.dirname(f), target);
      if (!within(root, resolved)) { findings.push(`link escapes the repository root in ${f} -> ${target}`); continue; }
      if (!existsSync(resolved)) findings.push(`broken link in ${f} -> ${target}`);
    }
  }

  const changeSet = resolveChangeSet(root, opts);
  let verdict = "checked";
  const evidence = [];
  if (!changeSet) {
    verdict = "stale/no-impact not evaluated — no change set provided (pass --changed or --base)";
  } else {
    const changed = new Set(changeSet.files);
    const impacted = new Map();
    for (const file of changed) for (const o of d.ownership) if (globMatch(o.glob, file))
      for (const doc of o.docs) impacted.set(doc, { via: file, source: o.source });
    for (const [doc, hit] of impacted) if (!changed.has(doc))
      findings.push(`stale candidate: ${doc} — ownership (${hit.source}) maps changed ${hit.via} but the doc is not in the change set`);
    if (impacted.size === 0) {
      verdict = "Docs: not impacted — no changed path matches any documentation ownership mapping";
      evidence.push(`Inspected change set: ${changeSet.files.join(", ")} (${changeSet.source})`,
        `Documentation roots: ${d.docsRoot}`,
        `Ownership evidence: ${d.ownershipSources.join(", ") || "none found"}`);
    } else if (findings.length === d.walkFindings.length) {
      verdict = "docs updated alongside code — impacted docs are in the change set";
    }
  }

  const result = { convention: d.convention, branch: d.branch, docsRoot: d.docsRoot, adrSeam: d.adrSeam,
    unresolvedConflicts: d.unresolvedConflicts, excludedFiles: d.excludedFiles.length,
    changeSet: changeSet || null, findings, verdict, evidence };
  const text = [
    `convention: ${d.convention} · branch: ${d.branch} · docs root: ${d.docsRoot}`,
    changeSet ? `inspected change set (${changeSet.source}): ${changeSet.files.join(", ")}` : null,
    changeSet?.renames?.length ? `renames: ${changeSet.renames.map((r) => `${r.from} -> ${r.to}`).join(", ")}` : null,
    ...findings.map((f) => `finding: ${f}`), verdict, ...evidence,
  ].filter(Boolean).join("\n");
  const output = opts.json ? JSON.stringify(result, null, 2) : text;
  if (opts.out) writeFileSync(path.resolve(root, opts.out), output + "\n"); else console.log(output);
  process.exit(findings.length ? 1 : 0);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) main();
