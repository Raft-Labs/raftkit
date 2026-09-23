#!/usr/bin/env node
// Read-only environment report for setup. Replaces the model reading the whole
// `claude plugin list --json` payload: it checks the engines raftkit-dev
// declares, names every enabled plugin's blocking Stop hook, lists enabled
// plugins this repo's stack does not use, and says whether security-guidance's
// duplicate push-time review can be turned off. It never writes and never runs
// a disable command; each line is something the developer decides.
//
// Usage: node check-engines.mjs --root <repo-root> [--plugins-json <file>] [--json]
//   --plugins-json  read the plugin list from a file instead of running
//                   `claude plugin list --json` in <repo-root>.
// Exit codes: 0 report produced · 1 plugin list unreadable · 2 bad input ·
// 3 raftkit-core missing or disabled (setup has nothing to install).
import { readFileSync, existsSync, readdirSync, statSync } from "node:fs";
import { execFileSync } from "node:child_process";
import path from "node:path";

const args = process.argv.slice(2);
const flag = (n) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : undefined; };
const asJson = args.includes("--json");
const root = flag("--root");
if (!root || !existsSync(root)) { console.error("missing or invalid --root"); process.exit(2); }

const readJson = (p) => { try { return JSON.parse(readFileSync(p, "utf8")); } catch { return null; } };
const nameOf = (id) => id.split("@")[0];

// --- the plugin list --------------------------------------------------------
let plugins;
try {
  const raw = flag("--plugins-json")
    ? readFileSync(flag("--plugins-json"), "utf8")
    : execFileSync("claude", ["plugin", "list", "--json"], { cwd: root, encoding: "utf8", timeout: 60000 });
  plugins = JSON.parse(raw);
  if (!Array.isArray(plugins)) throw new Error("not a JSON array");
} catch (err) {
  console.error(`reason: could not read the plugin list (${err.message.split("\n")[0]})`);
  process.exit(1);
}
const enabled = plugins.filter((p) => p.enabled === true);

// --- engines: exactly the dependencies raftkit-dev declares ------------------
const manifest = readJson(new URL("../../../.claude-plugin/plugin.json", import.meta.url));
const deps = (manifest?.dependencies ?? []).map((d) => (typeof d === "string" ? { name: d } : d));
const engines = deps.filter((d) => d.name !== "raftkit-core");

// A marketplace install wins over a claude.ai-synced copy of the same name.
const pick = (list) => list.find((p) => !p.id.endsWith("@synced")) ?? list[0];
const coreEntry = pick(enabled.filter((p) => nameOf(p.id) === "raftkit-core"));
const core = coreEntry ? { id: coreEntry.id, version: coreEntry.version, installPath: coreEntry.installPath } : null;

const engineReport = engines.map((e) => {
  const on = pick(enabled.filter((p) => nameOf(p.id) === e.name));
  if (on) return { name: e.name, state: "ok", id: on.id };
  const installed = plugins.find((p) => nameOf(p.id) === e.name);
  const id = installed?.id ?? `${e.name}@${e.marketplace ?? "raftkit"}`;
  return installed
    ? { name: e.name, state: "disabled", id, command: `claude plugin enable ${id}` }
    : { name: e.name, state: "missing", id, command: `claude plugin install ${id}` };
});

// --- blocking Stop hooks ------------------------------------------------------
// A Stop or SubagentStop hook that is neither `async` nor `asyncRewake` runs
// before the turn ends and can refuse to let it end (exit 2 or a block
// decision), whatever its type. Hook configs come from hooks/hooks.json and
// from plugin.json's `hooks` field (a path, an inline object, or an array).
function hookConfigs(p) {
  const out = [];
  const add = (cfg) => { if (cfg && typeof cfg === "object") out.push(cfg.hooks ?? cfg); };
  if (!p.installPath) return out;
  add(readJson(path.join(p.installPath, "hooks", "hooks.json")));
  const field = readJson(path.join(p.installPath, ".claude-plugin", "plugin.json"))?.hooks;
  for (const entry of Array.isArray(field) ? field : field ? [field] : []) {
    add(typeof entry === "string" ? readJson(path.join(p.installPath, entry)) : entry);
  }
  return out;
}
const blocking = [];
for (const p of enabled) {
  for (const cfg of hookConfigs(p)) {
    for (const event of ["Stop", "SubagentStop"]) {
      for (const group of Array.isArray(cfg[event]) ? cfg[event] : []) {
        for (const h of Array.isArray(group?.hooks) ? group.hooks : []) {
          if (h.async === true || h.asyncRewake === true) continue;
          const what = String(h.command ?? h.prompt ?? h.url ?? h.tool ?? "").split("\n")[0].slice(0, 80);
          blocking.push({ id: p.id, event, type: h.type ?? "command", what, command: `claude plugin disable ${p.id} --scope local` });
        }
      }
    }
  }
}

// --- plugins this repo's stack does not use -----------------------------------
// Only plugins with a known stack signal are judged; an unknown plugin is never
// called unused. Journey plugins (raftkit-*, the engines) and anything another
// enabled plugin depends on are never listed.
const manifests = [readJson(path.join(root, "package.json"))];
for (const dir of ["packages", "apps"]) {
  if (!statSync(path.join(root, dir), { throwIfNoEntry: false })?.isDirectory()) continue;
  for (const sub of readdirSync(path.join(root, dir))) manifests.push(readJson(path.join(root, dir, sub, "package.json")));
}
const depNames = new Set(manifests.filter(Boolean).flatMap((m) => Object.keys({ ...m.dependencies, ...m.devDependencies })));
const dep = (re) => [...depNames].some((n) => re.test(n));
const has = (...files) => files.some((f) => existsSync(path.join(root, f)));
const STACK = {
  expo: () => dep(/^(expo|react-native)$/) || Boolean(readJson(path.join(root, "app.json"))?.expo),
  vercel: () => has("vercel.json", ".vercel") || dep(/^(next|ai|@vercel\/.+)$/),
  neon: () => dep(/^@neondatabase\//),
  supabase: () => has("supabase") || dep(/^@supabase\//),
  "redis-development": () => dep(/^(redis|ioredis|@redis\/.+|@upstash\/redis)$/),
  "typescript-lsp": () => has("tsconfig.json") || dep(/^typescript$/),
  "pyright-lsp": () => has("pyproject.toml", "requirements.txt", "setup.py", "Pipfile"),
  playwright: () => dep(/^(@playwright\/test|playwright)$/),
  "chrome-devtools-mcp": () => dep(/^(react|next|vue|svelte|vite|@angular\/core)$/),
  "plugin-dev": () => has(".claude-plugin"),
  "skill-creator": () => has(".claude-plugin", ".claude/skills"),
};
const journey = new Set(["raftkit-core", ...engines.map((e) => e.name)]);
const dependedOn = new Set(enabled.flatMap((p) =>
  (readJson(path.join(p.installPath ?? "", ".claude-plugin", "plugin.json"))?.dependencies ?? [])
    .map((d) => (typeof d === "string" ? d : d?.name))));
const unused = enabled
  .map((p) => p.id)
  .filter((id) => {
    const n = nameOf(id);
    return !n.startsWith("raftkit-") && !journey.has(n) && !dependedOn.has(n) && STACK[n] && !STACK[n]();
  });

// --- security-guidance's duplicate push-time review ---------------------------
const sgOn = enabled.some((p) => nameOf(p.id) === "security-guidance");
const projectEnv = readJson(path.join(root, ".claude", "settings.json"))?.env ?? {};
const securityGuidance = { enabled: sgOn, pushSweepOffered: sgOn && projectEnv.SG_PUSH_SWEEP === undefined };

const report = { core, engines: engines.map((e) => e.name), engineReport, blocking, unused, securityGuidance };
if (asJson) console.log(JSON.stringify(report, null, 2));
else {
  console.log(core ? `raftkit-core ${core.version}: ${core.installPath}` : "Missing: raftkit-core. Install it with: claude plugin install raftkit-core@raftkit");
  for (const e of engineReport) {
    if (e.state === "missing") console.log(`Missing: ${e.name}. Install it with: ${e.command}`);
    if (e.state === "disabled") console.log(`Disabled: ${e.name}. Enable it with: ${e.command}`);
  }
  for (const id of [...new Set(blocking.map((b) => b.id))]) {
    const hooks = blocking.filter((b) => b.id === id);
    const events = [...new Set(hooks.map((b) => b.event))].join(", ");
    console.log(`Blocking Stop hook: ${id} (${events} ${hooks[0].type}: ${hooks[0].what}). Turn it off in this repo with: ${hooks[0].command}`);
  }
  if (unused.length) console.log(`Unused by this repo's stack: ${unused.join(", ")}`);
  if (securityGuidance.pushSweepOffered) console.log("security-guidance reviews each push again after reviewing its commits: SG_PUSH_SWEEP=0 can be offered");
}
process.exit(core ? 0 : 3);
