#!/usr/bin/env node
// Deterministic scope pre-filter for implement and fix: a list of candidates
// for the reviewer's hunk-level judgment, never the verdict. Reads the plan
// record's [AC] table, or fix's Done when table (implement/references/plan.md),
// and git; writes nothing.
//
// The plan is the table as first committed on this branch; every check reads it.
// Flags, one line each:
//   BEYOND candidate: <file>   changed since --base (commits, edits, untracked) and in no planned row
//   MISSING: [AC] …            a planned row's test file is not in the diff
//   ADDED AFTER PLAN: …        a row added, changed or removed since the plan, or a
//                              first-committed table that does not match its recorded hash
//   ORDER: [AC] …              its test commit does not precede its implementation
// The plan record is always in scope. A row's test commit is the first touching a
// test file only it plans, else the commit titled `test: <the [AC]>`; when neither
// exists the row prints `ORDER not checked`, which is not a flag. A source file
// several rows plan is not attributed to any one of them.
//
// Usage: node scope-check.mjs --base <sha> [--record <path>] [--root <repo>]
//        node scope-check.mjs --hash [--record <path>]
// Exit codes: 0 clean · 1 flags · 2 not checked (bad input, no record, no table).
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readFileSync, writeSync } from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
const flag = (n) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : undefined; };
const say = (text, code) => { writeSync(1, `${text}\n`); process.exit(code); };
const stop = (why) => say(`scope-check: ${why}; nothing was checked`, 2);

const git = (...a) => execFileSync("git", ["-C", root, "-c", "core.quotepath=off", ...a], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
const lines = (s) => s.split("\n").map((l) => l.trim()).filter(Boolean);

let root;
try { root = execFileSync("git", ["-C", flag("--root") ?? process.cwd(), "rev-parse", "--show-toplevel"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim(); }
catch { stop("not inside a git repository"); }

let record = flag("--record");
if (!record) {
  let branch = "";
  try { branch = git("symbolic-ref", "--short", "HEAD").trim(); } catch { /* detached */ }
  if (!branch) stop("detached HEAD, so pass --record <path>");
  record = `docs/specs/${branch}.md`;
}
record = path.relative(root, path.resolve(root, record)).split(path.sep).join("/");
if (!existsSync(path.join(root, record))) stop(`no plan record at ${record}`);

/** The [AC] (or Done when) table: its data rows, each split into the item, test files and source files. */
function parseTable(text) {
  const L = text.split("\n");
  const key = (c) => c.includes("[ac]") || c.includes("done when");
  const h = L.findIndex((l) => l.trim().startsWith("|") && key(l.toLowerCase()));
  if (h < 0) return null;
  const cells = (l) => l.trim().replace(/^\||\|$/g, "").split(/(?<!\\)\|/).map((c) => c.trim());
  const head = cells(L[h]).map((c) => c.toLowerCase());
  const col = { ac: head.findIndex(key), test: head.findIndex((c) => c.startsWith("test")), src: head.findIndex((c) => c.startsWith("source")) };
  if (col.ac < 0 || col.test < 0 || col.src < 0) return null;
  const files = (c) => (/`/.test(c || "") ? [...c.matchAll(/`([^`]+)`/g)].map((m) => m[1]) : String(c || "").split(",")).map((f) => f.trim()).filter(Boolean);
  const rows = [];
  for (let i = h + 2; i < L.length && L[i].trim().startsWith("|"); i++) {
    const c = cells(L[i]);
    rows.push({ line: L[i].trim(), ac: c[col.ac], tests: files(c[col.test]), srcs: files(c[col.src]) });
  }
  const hash = /<!--\s*plan-table sha256:\s*([0-9a-f]{64})\s*-->/.exec(text)?.[1] || "";
  return { rows, hash, digest: createHash("sha256").update(rows.map((r) => r.line).join("\n")).digest("hex") };
}

const table = parseTable(readFileSync(path.join(root, record), "utf8"));
if (!table || table.rows.length === 0) stop(`no [AC] table in ${record}`);
if (args.includes("--hash")) say(`plan-table sha256: ${table.digest}`, 0);

const base = flag("--base");
if (!base) stop("--base <sha> is required");
try { git("rev-parse", "--verify", "--quiet", `${base}^{commit}`); } catch { stop(`${base} is not a commit here`); }

const covers = (entry, file) => (entry.endsWith("/") ? file.startsWith(entry) : file === entry);
const flags = { beyond: [], missing: [], added: [], order: [] };

// The plan: the table as first committed on this branch.
const recordCommits = lines(git("rev-list", "--reverse", `${base}..HEAD`, "--", record));
const first = recordCommits.length ? parseTable(git("show", `${recordCommits[0]}:${record}`)) : table;
const plan = first?.rows ?? table.rows;

// BEYOND candidates: everything that differs from the base, committed or not.
const changed = new Set([
  ...lines(git("diff", "--name-only", "--no-renames", base)),
  ...lines(git("ls-files", "--others", "--exclude-standard")),
]);
const planned = plan.flatMap((r) => [...r.tests, ...r.srcs]);
for (const f of [...changed].sort()) {
  if (f !== record && !planned.some((p) => covers(p, f))) flags.beyond.push(`BEYOND candidate: ${f}`);
}

// ADDED AFTER PLAN: any row that is not, line for line, in the plan.
if (!first || first.hash !== first.digest) flags.added.push("ADDED AFTER PLAN: the table does not match the hash recorded when it was planned");
for (const r of table.rows) {
  if (plan.some((p) => p.line === r.line)) continue;
  flags.added.push(plan.some((p) => p.ac === r.ac) ? `ADDED AFTER PLAN: changed — ${r.ac}` : `ADDED AFTER PLAN: ${r.ac}`);
}
for (const p of plan) {
  if (!table.rows.some((r) => r.line === p.line || r.ac === p.ac)) flags.added.push(`ADDED AFTER PLAN: removed — ${p.ac}`);
}

// MISSING and ORDER, over the planned rows, from the branch's commits oldest first.
const commits = lines(git("log", "--reverse", "--topo-order", "--no-merges", "--format=%H %s", `${base}..HEAD`)).map((l) => {
  const sha = l.split(" ")[0];
  return { sha, subject: l.slice(sha.length + 1), files: lines(git("diff-tree", "--no-commit-id", "--name-only", "--no-renames", "-r", sha)) };
});
const touches = (c, entries) => c.files.some((f) => entries.some((e) => covers(e, f)));
const owners = (key, entry) => plan.filter((r) => r[key].includes(entry)).length;
const titled = (c, ac) => [`test: ${ac}`, `test: ${ac.replace(/^\[AC\]\s*/, "")}`].includes(c.subject);
const notes = [];
for (const r of plan) {
  const tested = r.tests.filter((t) => [...changed].some((f) => covers(t, f)));
  if (tested.length === 0) {
    flags.missing.push(`MISSING: ${r.ac} — no test file in the diff (${r.tests.join(", ") || "none planned"})`);
    continue;
  }
  if (r.srcs.length === 0) continue;
  const ownTests = r.tests.filter((t) => owners("tests", t) === 1);
  const t = ownTests.length ? commits.findIndex((c) => touches(c, ownTests)) : commits.findIndex((c) => titled(c, r.ac));
  if (t < 0) {
    if (!ownTests.length) notes.push(`ORDER not checked: ${r.ac} — shared test file`);
    continue;
  }
  const own = r.srcs.filter((s) => owners("srcs", s) === 1);
  if (touches(commits[t], r.srcs)) flags.order.push(`ORDER: ${r.ac} — its test and implementation share a commit`);
  else if (own.length && commits.slice(0, t).some((c) => touches(c, own))) flags.order.push(`ORDER: ${r.ac} — its implementation was committed before its test`);
  else if (!commits.slice(t + 1).some((c) => touches(c, r.srcs))) flags.order.push(`ORDER: ${r.ac} — no implementation commit after its test`);
}

const all = [...flags.beyond, ...flags.missing, ...flags.added, ...flags.order];
if (all.length === 0) say(["scope-check: clean — 0 flags", ...notes].join("\n"), 0);
say([`scope-check: ${all.length} flag(s)`, ...all, ...notes].join("\n"), 1);
