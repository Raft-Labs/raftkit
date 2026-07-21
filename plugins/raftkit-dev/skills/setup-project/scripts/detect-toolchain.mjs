#!/usr/bin/env node
// Deterministic toolchain/ownership detector for setup-project. Pure reader:
// collects every signal (no precedence), applies the documented decision table,
// and reports hook/CI ownership with scope and origin. It never writes, never
// touches git configuration, and redacts secret-looking values in any content
// it quotes for comparison.
//
// Usage: node detect-toolchain.mjs --root <repo-root> [--json]
// Exit codes: 0 report produced · 2 bad input.
import { readFileSync, existsSync, lstatSync, readdirSync } from "node:fs";
import { execFileSync } from "node:child_process";
import path from "node:path";

const args = process.argv.slice(2);
const flag = (n) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : undefined; };
const asJson = args.includes("--json");
const root = flag("--root");
if (!root || !existsSync(root)) { console.error("missing or invalid --root"); process.exit(2); }

const rd = (p) => readFileSync(path.join(root, p), "utf8");
const has = (p) => existsSync(path.join(root, p));
const redact = (s) => s.replace(/\b((?:TOKEN|SECRET|KEY|PASSWORD|PASSWD|PASS|API[_A-Z]*)\s*=\s*)\S+/gi, "$1<redacted>");

// --- package-manager signals (collected, no precedence) ---------------------
const FAMILIES = [["pnpm", "pnpm-lock.yaml"], ["npm", "package-lock.json"], ["yarn", "yarn.lock"], ["bun", "bun.lock"], ["bun", "bun.lockb"]];
const families = [...new Set(FAMILIES.filter(([, f]) => has(f)).map(([m]) => m))];
const pkg = has("package.json") ? JSON.parse(rd("package.json")) : null;
let field = null;
if (pkg?.packageManager) {
  const m = String(pkg.packageManager).match(/^([a-z]+)@(.+)$/);
  field = m ? { name: m[1], version: m[2] } : { name: null, version: null, invalid: String(pkg.packageManager) };
}

let state, manager = null, declaredVersion = null;
if (!pkg) state = "non-node";
else if (families.length > 1) state = "conflict";
else if (families.length === 1) {
  if (field && field.name && field.name !== families[0]) state = "conflict";
  else { state = "detected"; manager = families[0]; declaredVersion = field?.version ?? null; }
} else state = field ? "ask-field-only" : "undetermined";

// --- workspace + scripts ----------------------------------------------------
const workspace = has("pnpm-workspace.yaml") || Boolean(pkg?.workspaces) || has("turbo.json") || has("nx.json");
const rootScripts = pkg?.scripts ?? {};
const QUALITY = /^(lint|typecheck|test)([:.].*)?$/;
const rootQuality = Object.keys(rootScripts).filter((k) => QUALITY.test(k));
const workspaceCandidates = [];
for (const dir of ["packages", "apps"]) {
  if (!has(dir)) continue;
  for (const sub of readdirSync(path.join(root, dir))) {
    const mf = path.join(dir, sub, "package.json");
    if (!has(mf)) continue;
    const sp = JSON.parse(rd(mf)).scripts ?? {};
    for (const k of Object.keys(sp).filter((k) => QUALITY.test(k))) workspaceCandidates.push({ script: k, location: path.posix.join(dir, sub) });
  }
}

// --- setup-mechanism report (never assumed, never invented) -----------------
const workflows = has(".github/workflows") ? readdirSync(path.join(root, ".github/workflows")) : [];
const setupReport = {
  manager, declaredVersion,
  repoSetupMechanism: field ? "corepack-packageManager" : "none",
  ciSetupConvention: workflows,
  corepackUsedOrApproved: Boolean(field),
  proposedSetupBlock: null, // a human choice from the documented options — never auto-filled
};

// --- hook ownership (read-only; scope + origin; never modified) -------------
const MARKER = "raftkit-governance-pack";
const managers = [];
if (has(".husky") || /"prepare"\s*:\s*"husky/.test(pkg ? JSON.stringify(pkg.scripts ?? {}) : "")) managers.push("husky");
if (pkg && pkg["simple-git-hooks"]) managers.push("simple-git-hooks");
if (has("lefthook.yml") || has("lefthook.yaml")) managers.push("lefthook");
if (has(".githooks")) managers.push("tracked-githooks");

let hooksPath = null, scope = null, conflict = false, proposal = null;
try {
  const out = execFileSync("git", ["-C", root, "config", "--show-scope", "--get-all", "core.hooksPath"], { encoding: "utf8" }).trim();
  if (out) {
    const lines = out.split("\n").map((l) => { const [s, ...v] = l.split(/\s+/); return { scope: s, value: v.join(" ") }; });
    if (lines.length > 1) conflict = true;
    hooksPath = lines[0].value; scope = lines[0].scope;
  }
} catch { /* not a repo or unset — hooksPath stays null */ }

const markerOwned = has(".githooks/pre-push") && rd(".githooks/pre-push").includes(MARKER);
let owner = "none";
if (markerOwned && scope !== "global" && scope !== "system") owner = "pack";
else if (managers.length || hooksPath) owner = "foreign";

if (owner === "foreign") {
  const src = has(".husky/pre-push") ? ".husky/pre-push" : has(".githooks/pre-push") ? ".githooks/pre-push" : null;
  if (src) {
    const lines = redact(rd(src)).split("\n").slice(0, 20).map((l, i) => `${src}:${i + 1}: ${l}`);
    proposal = { existing: lines, note: "foreign hook owner — side-by-side merge proposal required; only the developer's decision applies it" };
  }
}

// --- CI ownership -----------------------------------------------------------
const ciPath = path.join(root, ".github/workflows/quality-guardrail.yml");
let ci = { owner: "none", note: null };
if (existsSync(ciPath)) {
  if (lstatSync(ciPath).isSymbolicLink()) ci = { owner: "foreign", note: "workflow path is a symlink — conflict, propose, never overwrite" };
  else ci = readFileSync(ciPath, "utf8").includes(MARKER)
    ? { owner: "pack", note: "marker-owned — updates through the transaction" }
    : { owner: "foreign", note: "unmarked existing workflow — show diff, propose, human decides" };
}

const report = {
  state, manager, declaredVersion, workspace,
  rootScripts, rootQuality, workspaceCandidates,
  selectionRequired: rootQuality.length === 0 && workspaceCandidates.length > 0
    ? "quality scripts exist only in workspace packages — human selection required before any command is generated"
    : null,
  setupReport,
  hooks: { hooksPath, scope, owner, managers, conflict, proposal },
  ci,
  writesAllowed: state === "detected" || state === "non-node",
};

if (asJson) console.log(JSON.stringify(report, null, 2));
else {
  console.log(`state: ${state}${manager ? ` · manager: ${manager}${declaredVersion ? "@" + declaredVersion : ""}` : ""} · workspace: ${workspace}`);
  if (report.selectionRequired) console.log(report.selectionRequired);
  console.log(`hooks: owner=${owner} scope=${scope ?? "-"} conflict=${conflict} managers=${managers.join(",") || "-"}`);
  if (proposal) for (const l of proposal.existing) console.log(`  ${l}`);
  console.log(`ci: owner=${ci.owner}${ci.note ? ` (${ci.note})` : ""}`);
  if (!report.writesAllowed) console.log("No writes occur while detection is conflicting or undetermined — ask the developer.");
}
