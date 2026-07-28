#!/usr/bin/env node
// Deterministic readiness classifier for the capability-preflight skill.
// Pure reader: consumes captured CLI output (claude plugin list --json,
// npx skills list --json, claude plugin details text) plus the provider
// registry, and prints the readiness report. It never runs a command and
// never installs anything — installs are human-approved, elsewhere.
//
// Usage:
//   node classify.mjs --registry <providers.md> --plugins <list.json>
//        [--skills <project.json>] [--skills-global <global.json>]
//        [--details <dir of <plugin>.txt>] [--need <capability-or-provider>]...
//        [--json]
// Exit codes: 0 nothing to do · 1 action required · 2 bad input.
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const args = process.argv.slice(2);
const flag = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};
const needs = args.flatMap((a, i) => (a === "--need" ? [args[i + 1]] : []));
const asJson = args.includes("--json");

const registryPath = flag("--registry");
const pluginsPath = flag("--plugins");
if (!registryPath || !pluginsPath) {
  console.error("usage: classify.mjs --registry <providers.md> --plugins <list.json> [...]");
  process.exit(2);
}

const readJson = (p) => (p && existsSync(p) ? JSON.parse(readFileSync(p, "utf8")) : []);
const plugins = readJson(pluginsPath);
const skills = [...readJson(flag("--skills")), ...readJson(flag("--skills-global"))];
const detailsDir = flag("--details");

const pluginByName = new Map(
  plugins.map((p) => [String(p.id || "").split("@")[0], p])
);
const parentScope = pluginByName.get("raftkit-dev")?.scope;

// Registry rows: | Capability | Provider | Marketplace | Components | Policy | Ownership |
const rows = readFileSync(registryPath, "utf8")
  .split("\n")
  .filter((l) => l.startsWith("|") && !/^\|[\s|:-]+\|$/.test(l) && !/^\| *Capability/.test(l))
  .map((l) => l.split("|").slice(1, -1).map((c) => c.trim()))
  .filter((c) => c.length >= 6)
  .map(([capability, provider, marketplace, components, policy, ownership]) => ({
    capability, provider, marketplace, components, policy, ownership,
  }));
if (rows.length === 0) {
  console.error(`no registry rows parsed from ${registryPath}`);
  process.exit(2);
}

// Inventory-line check against a captured `claude plugin details` text:
// each declared component name must appear on its own type line. Distinct
// from "nothing missing": hasDetailsEvidence tells the caller whether a
// details file for THIS provider actually existed and was read, so the
// evidence string never claims "inventory verified" on a directory that
// was passed but held no file for this provider (F4 fix — a missing
// per-plugin details file must not read as a clean inventory).
const hasDetailsEvidence = (name) => !!detailsDir && existsSync(join(detailsDir, `${name}.txt`));
const missingComponents = (name, components) => {
  if (!hasDetailsEvidence(name)) return [];
  const file = join(detailsDir, `${name}.txt`);
  const text = readFileSync(file, "utf8");
  const m = components.match(/^(skills?|agent|hooks?):\s*([^(]+)/);
  if (!m) return []; // inventory-at-verification etc: discovered, not asserted
  const lineFor = { skill: "Skills (", skills: "Skills (", agent: "Agents (", hook: "Hooks (", hooks: "Hooks (" }[m[1]];
  const inventory = text.split("\n").find((l) => l.includes(lineFor)) || "";
  return m[2].split(",").map((s) => s.trim()).filter((n) => n && !inventory.includes(n))
    .map((n) => `${m[1] === "agent" ? "agent" : m[1]}: ${n}`);
};

const report = [];
const plan = [];
let ready = 0, missing = 0, disabled = 0, actionRequired = false;

for (const row of rows) {
  const needed = needs.some((n) => n === row.capability || n === row.provider);
  const declared = /required \(declared\)/.test(row.policy);
  // A baseline-required capability is always needed for an initialized project:
  // it is reported missing when absent, never optional-not-selected.
  const baseline = /baseline-required/.test(row.policy);
  // required-available (e.g. impeccable): required only when the calling
  // skill has adopted it for this run (--need); otherwise the row is a
  // normal optional-not-selected, same as any other conditional provider.
  const requiredAvailable = /required-available/.test(row.policy);
  const inherited = /inherited/.test(row.ownership);
  const line = (state, extra = "") =>
    report.push(`${row.capability} · ${row.provider} · ${state}${extra ? ` · ${extra}` : ""} · evidence: plugin list/details`);

  if (inherited) { line("core-inherited (not classified here)"); continue; }

  if (row.components.startsWith("one-of:")) {
    const names = row.components.slice(7).split(",").map((s) => s.trim());
    const hit = names.find((n) => pluginByName.get(n)?.enabled);
    if (hit) { ready++; line("ready", hit); } else line("optional-not-selected");
    continue;
  }
  if (row.components.startsWith("agent skill:")) {
    const name = row.components.split(":")[1].trim();
    if (skills.some((s) => s.name === name)) { ready++; line("ready", `agent skill ${name}`); }
    else if (needed || baseline) { missing++; actionRequired = true; line("missing", baseline ? "baseline-required" : ""); plan.push(`Discover via: npx skills find ${name} (suggestions only; human approval required to add)`); }
    else line("optional-not-selected");
    continue;
  }
  if (row.components.startsWith("cli:")) { line("cli (verified at run time)"); continue; }

  const entry = pluginByName.get(row.provider);
  if (entry && entry.enabled) {
    const gone = missingComponents(row.provider, row.components);
    if (gone.length) {
      actionRequired = true;
      report.push(`${row.capability} · ${row.provider} · incompatible — missing component ${gone.join(", ")} (not in installed inventory) · evidence: plugin details (inventory verified)`);
    } else {
      // F4: name the evidence actually consulted. Verified only when a
      // details file for THIS provider was actually found and read — not
      // merely when --details pointed at a directory (see hasDetailsEvidence).
      ready++;
      const ev = hasDetailsEvidence(row.provider) ? "plugin details (inventory verified)" : "plugin list (listed-only; inventory not consulted)";
      report.push(`${row.capability} · ${row.provider} · ready · v${entry.version} (${entry.scope}) · evidence: ${ev}`);
    }
  } else if (entry && !entry.enabled) {
    disabled++; actionRequired = true;
    // F5: the enable command carries the plugin's own installed scope.
    line("installed-but-disabled", `enable with: claude plugin enable ${row.provider} --scope ${entry.scope}`);
  } else if (declared) {
    missing++; actionRequired = true;
    report.push(`${row.capability} · ${row.provider} · unresolved declared dependency: ${row.provider} · evidence: plugin list`);
    plan.push(`Repair: resolve the declared dependency ${row.provider} through a human-approved RaftKit install/update of raftkit-dev. This preflight never adds or installs it at runtime.`);
  } else if (needed || baseline || /recommended/.test(row.policy)) {
    missing++; actionRequired = true;
    // A row with no real marketplace (e.g. "—") names a component bundled
    // inside raftkit-dev itself, not a separately installable plugin — there
    // is no `claude plugin install` command to emit for it. Report the gap
    // without fabricating an unrunnable command.
    if (!row.marketplace || row.marketplace === "—") {
      line("missing", "bundled component of raftkit-dev — not present in this checkout; no separate install applies");
    } else {
      line("missing", baseline ? "baseline-required" : requiredAvailable ? "required-available — adopted, not installed" : `available from ${row.marketplace}`);
      // F5: the proposed install command carries the correct explicit scope
      // from the raftkit-dev install scope; with no scope on record the plan
      // asks rather than emitting a runnable command with a guessed scope.
      const scopeFlag = parentScope
        ? ` --scope ${parentScope}`
        : "  # scope pending — ask the developer which install scope to use (no runnable command emitted until decided)";
      plan.push(`Proposed install command (human approval required): claude plugin install ${row.provider}@${row.marketplace}${scopeFlag}`);
    }
  } else {
    line("optional-not-selected");
  }
}

const summary = actionRequired
  ? `Capability preflight: ${ready} ready, ${missing} missing, ${disabled} installed-but-disabled — install plan awaiting approval.`
  : `Capability preflight: all required capabilities ready.`;

if (asJson) {
  console.log(JSON.stringify({ report, plan, summary }, null, 2));
} else {
  console.log(report.join("\n"));
  if (plan.length) {
    const scope = parentScope
      ? `Scope: ${parentScope} (from raftkit-dev install scope)`
      : "Scope: ask the developer (no parent scope, Project Profile rule, or org rule on record)";
    console.log(`\n${scope}`);
    console.log(plan.join("\n"));
  }
  console.log(`\n${summary}`);
}
process.exit(actionRequired ? 1 : 0);
