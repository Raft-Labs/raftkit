#!/usr/bin/env bash
# Behavioural and contract suite for raftkit-docs. Drives the shipped
# render-companion.mjs over its shipped source (valid frontmatter is
# preserved, a bad source renders nothing), then checks what a generated repo
# inherits: the companion and the CLAUDE.md template add no human stop, sync
# and verify hand off to raftkit-dev:docs, and every file pointer in the
# plugin resolves.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

failures=0
check() {
  local name="$1" expected="$2" actual="$3"
  if { [[ "$expected" == ok && "$actual" -eq 0 ]] || [[ "$expected" == fail && "$actual" -ne 0 ]]; }; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected $expected, exit was $actual)"
    failures=$((failures + 1))
  fi
}

DOCS=plugins/raftkit-docs
RENDER=$DOCS/skills/docs-product/scripts/render-companion.mjs
SRC=$DOCS/skills/docs-product/assets/companion/SKILL.md
CLAUDE_TPL=$DOCS/skills/docs-product/assets/templates/claude-md.md
DP=$DOCS/skills/docs-product/SKILL.md

[[ -f "$RENDER" && -f "$SRC" ]]
check "C1 the renderer and its companion source both ship" ok $?

node --check "$RENDER"
check "C2 the renderer is syntactically valid" ok $?

d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
node "$RENDER" --source "$SRC" --out "$d/SKILL.md" >/dev/null 2>&1
rc=$?
if [[ $rc -eq 0 && -f "$d/SKILL.md" ]]; then
  grep -q '^name:' "$d/SKILL.md" && grep -q '^description:' "$d/SKILL.md"
  check "C3 a rendered companion keeps its name and description" ok $?
else
  check "C3 a rendered companion keeps its name and description" ok 1
fi

printf 'no frontmatter here\n' > "$d/bad.md"
node "$RENDER" --source "$d/bad.md" --out "$d/never.md" >/dev/null 2>&1
check "C4 a source without frontmatter renders nothing (fail-closed)" fail $?
[[ ! -f "$d/never.md" ]]
check "C5 nothing was written on the failed render" ok $?

# --- what a generated repo inherits: no v1 stop ---
# The v1 gates were a spec-file gate, a confirm on every edit and a
# category-graded done-claim gate. Any of their vocabulary in the payload a
# generated repo carries is a stop inside an implement run.
GATE='confirm|spec[- ]?first|spec[- ]gate|spec file|approved spec|refuse|withheld|override|blockers? stop|must go through'
! grep -qiE "$GATE" "$CLAUDE_TPL"
check "C6 the generated CLAUDE.md carries no confirm or spec-file gate" ok $?
! grep -qiE "$GATE" "$SRC"
check "C7 the companion adds no stop: no confirm, spec-first refusal or done-claim gate" ok $?
grep -qF 'raftkit-dev:docs' "$SRC"
check "C8 the companion hands docs parity to raftkit-dev:docs" ok $?

# --- sync and verify are raftkit-dev:docs, never a local copy ---
mode_bullet() { # the "- **<mode>** — ..." bullet of the Modes list, continuation lines included
  awk -v m="$1" 'index($0, "- **" m "**") == 1 {on=1; print; next} on && (/^- \*\*/ || /^$/) {exit} on {print}' "$DP"
}
for m in sync verify; do
  b="$(mode_bullet "$m")"
  [[ -n "$b" ]] && grep -qF 'raftkit-dev:docs' <<<"$b" && ! grep -qE 'references/' <<<"$b"
  check "C9 docs-product $m mode invokes raftkit-dev:docs and points at no local copy" ok $?
done

# --- every file pointer in the plugin resolves ---
# Instruction files: a references/, scripts/ or assets/ path resolves in its
# own skill, or in the skill a `plugin:skill` prefix names; a bare .md name is
# a sibling, a file in the skill, a link target in the same file, or a doc the
# generated tree creates (named in the CLAUDE.md template); a bare .mjs name
# is a shipped script; a relative link resolves. Payload files (assets/) are
# read inside the generated repo, which has no references/ directory; their
# _templates/ pointers must name a shipped template.
node - "$DOCS" "$CLAUDE_TPL" <<'NODE'
const fs = require("fs"), path = require("path");
const [root, claudeTpl] = process.argv.slice(2);
const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).flatMap((e) =>
  e.isDirectory() ? (e.name === "evals" ? [] : walk(path.join(d, e.name))) : e.name.endsWith(".md") ? [path.join(d, e.name)] : []);
const shipped = (d) => fs.readdirSync(d, { withFileTypes: true }).flatMap((e) =>
  e.isDirectory() ? shipped(path.join(d, e.name)) : /\/scripts\/[^/]+\.mjs$/.test(path.join(d, e.name)) ? [e.name] : []);
const scripts = shipped("plugins");
const generated = new Set([...fs.readFileSync(claudeTpl, "utf8").matchAll(/`([A-Za-z0-9._-]+\.md)`/g)].map((m) => m[1]).concat("CLAUDE.md"));
const skillOf = (p, s) => path.join("plugins", p, "skills", s);
const placeholder = (t) => /[<>*{}$]/.test(t);
const bad = [];
for (const f of walk(root)) {
  const text = fs.readFileSync(f, "utf8");
  const rel = path.relative(root, f).split(path.sep);
  const skillRoot = rel[0] === "skills" ? path.join(root, "skills", rel[1]) : root;
  const payload = rel.includes("assets");
  const links = [...text.matchAll(/\]\(([^)#\s]+)(?:#[^)]*)?\)/g)].map((m) => m[1]).filter((t) => !/^[a-z]+:/.test(t) && !placeholder(t));
  const linkNames = new Set(links.map((t) => path.basename(t)));
  const qualified = new Map();
  for (const m of text.matchAll(/`(raftkit-[a-z]+):([a-z-]+)`(?:'s)?\s*(?:→\s*)?`((?:references|scripts|assets)\/[^`\s]+)/g)) qualified.set(m.index + m[0].length - m[3].length, skillOf(m[1], m[2]));
  const miss = (t, why) => bad.push(`${f}: \`${t}\` ${why}`);
  if (!payload) for (const t of links) if (!fs.existsSync(path.join(path.dirname(f), t))) miss(t, "link does not resolve");
  for (const m of text.matchAll(/`([^`\n]+)`/g)) {
    const t = m[1].trim().split(/\s+/)[0];
    const at = m.index + 1;
    if (placeholder(t)) continue;
    const q = t.match(/^(raftkit-[a-z]+):([a-z-]+)\/(.+)$/);
    if (q) { if (!fs.existsSync(path.join(skillOf(q[1], q[2]), q[3]))) miss(t, "not in the named skill"); continue; }
    const tpl = t.match(/^(?:docs\/project\/)?_templates\/(.+)$/);
    if (tpl) { if (!fs.existsSync(path.join(root, "skills/docs-product/assets/templates", tpl[1]))) miss(t, "names no shipped template"); continue; }
    if (/^(references|scripts|assets)\/[^/]/.test(t)) {
      const base = qualified.get(at);
      if (base) { if (!fs.existsSync(path.join(base, t))) miss(t, "not in the named skill"); }
      else if (payload && t.startsWith("references/")) miss(t, "a generated repo has no references/ directory");
      else if (!payload && !fs.existsSync(path.join(skillRoot, t))) miss(t, "not in this skill");
      continue;
    }
    if (payload || t.includes("/")) continue;
    if (/\.md$/.test(t)) {
      const ok = [path.dirname(f), skillRoot, path.join(skillRoot, "references")].some((d) => fs.existsSync(path.join(d, t)))
        || linkNames.has(t) || generated.has(t);
      if (!ok) miss(t, "resolves nowhere");
    } else if (/\.mjs$/.test(t) && !scripts.includes(t)) miss(t, "is no shipped script");
  }
}
if (bad.length) { console.error(bad.join("\n")); process.exit(1); }
NODE
check "C10 every file pointer in raftkit-docs resolves" ok $?

echo
[[ "$failures" -eq 0 ]]
