#!/usr/bin/env node
// Fail-closed renderer for setup-project's pack assets. Operates on the SHIPPED
// templates with the exact substitution rules documented in components.md:
// validate every input, substitute each token, verify nothing unresolved
// remains, and render NOTHING when any validation fails. Deterministic: the
// same approved inputs always produce byte-identical output.
//
// Rendering safety (F1): every substituted value reaches the pre-push hook
// shell-safe and the CI workflow YAML-safe.
//   - Shell (pre-push): script/role names are charset-proven by NAME_RE
//     (no whitespace, quotes, $, backticks, newlines, or leading dash), and the
//     package-manager identity is an enum plus a control/injection reject — so
//     values are charset-proven safe in the hook's `$PM run <name>` lines. The
//     hook additionally quotes each value at use ("$gate"), so even a
//     charset-proven value is never word-split.
//   - CI (quality-guardrail.yml): the same charset-proven values are emitted as
//     single-quoted YAML scalars in every `run:` line, so no value can inject
//     YAML structure. A value that fails validation renders nothing (exit 3).
//
// Usage: node render-assets.mjs --templates <dir> --out-dir <dir>
//   --pm <pnpm|npm|yarn|bun|none> [--pm-version <x.y.z>]
//   --setup <none|corepack|setup-node-cache-any|setup-bun>
//   --scripts "<space-separated approved script names>"
//   --absent-roles "<space-separated roles|none>"
//   --manifest <package.json> --spec-path <p> --spec-sentinel <s>
// Exit codes: 0 rendered · 2 bad invocation · 3 validation failed, nothing written.
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
const flag = (n) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : undefined; };
const die = (code, msg) => { console.error(msg); process.exit(code); };

const templates = flag("--templates"), outDir = flag("--out-dir");
if (!templates || !outDir) die(2, "usage: --templates <dir> --out-dir <dir> ...");

const pm = flag("--pm") ?? "";
const pmVersion = flag("--pm-version") ?? "";
const setup = flag("--setup") ?? "none";
const scripts = (flag("--scripts") ?? "").split(/\s+/).filter(Boolean);
const roles = (flag("--absent-roles") ?? "none").split(/\s+/).filter(Boolean);
const manifestPath = flag("--manifest");
const specPath = flag("--spec-path") ?? "docs/specs/active-feature.md";
const specSentinel = flag("--spec-sentinel") ?? "";

// --- validation (reject; never sanitize-and-continue) -----------------------
const PM_ENUM = ["pnpm", "npm", "yarn", "bun", "none"];
const NAME_RE = /^[A-Za-z0-9][A-Za-z0-9:_.-]*$/;
const VER_RE = /^\d+\.\d+\.\d+([-+.][A-Za-z0-9.-]+)?$/;
const fail = (msg) => die(3, `validation failed — rendering nothing: ${msg}`);

if (!PM_ENUM.includes(pm)) fail(`package manager '${pm}' is not in the supported set (${PM_ENUM.join("|")})`);
if (pmVersion) {
  if (pmVersion === "latest" || !VER_RE.test(pmVersion)) fail(`declared version '${pmVersion}' is not an explicit x.y.z version (latest is never selected)`);
}
for (const s of [...scripts, ...roles]) {
  if (!NAME_RE.test(s)) fail(`name '${s}' contains injection-shaped or unsupported characters`);
}
if (pm !== "none" && scripts.length) {
  if (!manifestPath || !existsSync(manifestPath)) fail("manifest required to verify script keys");
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  for (const s of scripts) if (!manifest.scripts || !(s in manifest.scripts)) fail(`script '${s}' does not exist in the manifest`);
}
if (/[\n\r]|[$`]|^-/.test(pm + pmVersion)) fail("control or injection characters in manager identity");

// --- documented setup-block options (chosen by a human, emitted verbatim) ---
const cacheFor = { npm: "npm", yarn: "yarn", pnpm: "pnpm" };
const SETUP_BLOCKS = {
  none: pm === "none"
    ? "      # non-Node repository — quality steps skipped (reason: no Node manifest)"
    : "      # no toolchain setup selected — quality steps run on the runner's default environment",
  corepack: [
    "      - uses: actions/setup-node@v4",
    "        with:",
    "          node-version: lts/*",
    "      - run: corepack enable",
  ].join("\n"),
  "setup-node-cache-any": [
    "      - uses: actions/setup-node@v4",
    "        with:",
    "          node-version: lts/*",
    ...(cacheFor[pm] ? [`          cache: ${cacheFor[pm]}`] : []),
  ].join("\n"),
  "setup-bun": "      - uses: oven-sh/setup-bun@v2",
};
if (!(setup in SETUP_BLOCKS)) fail(`setup option '${setup}' is not one of the documented options (${Object.keys(SETUP_BLOCKS).join("|")})`);

// CI run lines are emitted as single-quoted YAML scalars so a (charset-proven)
// value can never inject YAML structure — YAML-encoding, defence in depth.
const qualitySteps = pm === "none"
  ? '      - run: echo "non-Node repository — quality steps skipped (no Node manifest)"'
  : scripts.map((s) => `      - run: '${pm} run ${s}'`).join("\n") || '      - run: echo "no quality scripts approved for this repository"';

// --- substitution over the shipped templates --------------------------------
const subs = {
  __SPEC_PATH__: specPath,
  __SPEC_TEMPLATE_SENTINEL__: specSentinel,
  __PM__: pm,
  __QUALITY_SCRIPTS__: scripts.join(" "),
  __ABSENT_ROLES__: roles.join(" ") || "none",
  __SETUP_BLOCK__: SETUP_BLOCKS[setup],
  __QUALITY_STEPS__: qualitySteps,
};
const render = (file) => {
  let text = readFileSync(path.join(templates, file), "utf8");
  for (const [token, value] of Object.entries(subs)) text = text.split(token).join(value);
  const left = text.match(/__[A-Z_]+__/);
  if (left) fail(`unresolved placeholder ${left[0]} in ${file}`);
  return text;
};

// Build both outputs fully BEFORE writing anything (all-or-nothing).
const hook = render("pre-push");
const ci = render("quality-guardrail.yml");
mkdirSync(outDir, { recursive: true });
writeFileSync(path.join(outDir, "pre-push"), hook);
writeFileSync(path.join(outDir, "quality-guardrail.yml"), ci);
console.log(`rendered: pre-push, quality-guardrail.yml (pm=${pm}${pmVersion ? "@" + pmVersion : ""}, setup=${setup}, scripts=${scripts.join(",") || "-"})`);
