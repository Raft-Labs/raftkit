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
# category-graded done-claim gate. Any of their vocabulary, or an approval
# wait in other words, in the payload a generated repo carries is a stop
# inside an implement run.
GATE='confirm|spec[- ]?first|spec[- ]gate|spec file|approved spec|refuse|withheld|override|blockers? stop|must go through|approv(al|e) before|wait for|ask (the (developer|user) )?before|sign[- ]off'
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
# read inside the generated repo, which has no references/ or _templates/
# directory. Nothing installs skills under .claude/skills/. Fenced blocks are
# scanned too.
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
  const pointer = (t, at) => {
    if (/(^|\/)\.claude\/skills\//.test(t)) return miss(t, "nothing in v2 installs skills under .claude/skills/");
    if (/(^|\/)_templates\//.test(t)) return miss(t, "no generation step creates a _templates/ folder");
    if (placeholder(t)) return;
    const q = t.match(/^(raftkit-[a-z]+):([a-z-]+)\/(.+)$/);
    if (q) { if (!fs.existsSync(path.join(skillOf(q[1], q[2]), q[3]))) miss(t, "not in the named skill"); return; }
    if (/^(references|scripts|assets)\/[^/]/.test(t)) {
      const base = qualified.get(at);
      if (base) { if (!fs.existsSync(path.join(base, t))) miss(t, "not in the named skill"); }
      else if (payload && t.startsWith("references/")) miss(t, "a generated repo has no references/ directory");
      else if (!payload && !fs.existsSync(path.join(skillRoot, t))) miss(t, "not in this skill");
      return;
    }
    if (payload || t.includes("/")) return;
    if (/\.md$/.test(t)) {
      const ok = [path.dirname(f), skillRoot, path.join(skillRoot, "references")].some((d) => fs.existsSync(path.join(d, t)))
        || linkNames.has(t) || generated.has(t);
      if (!ok) miss(t, "resolves nowhere");
    } else if (/\.mjs$/.test(t) && !scripts.includes(t)) miss(t, "is no shipped script");
  };
  for (const m of text.matchAll(/`([^`\n]+)`/g)) pointer(m[1].trim().split(/\s+/)[0], m.index + 1);
  // Fenced blocks: every path-shaped word, since a command there is run as written.
  for (const m of text.matchAll(/^(`{3,}|~{3,})[^\n]*\n([\s\S]*?)^\1[ \t]*$/gm))
    for (const w of m[2].matchAll(/[^\s"'`()]+/g))
      if (/^(?:raftkit-[a-z]+:[a-z-]+\/|(?:references|scripts|assets)\/)|(^|\/)(?:\.claude\/skills|_templates)\//.test(w[0])) pointer(w[0], -1);
}
if (bad.length) { console.error(bad.join("\n")); process.exit(1); }
NODE
check "C10 every file pointer in raftkit-docs resolves" ok $?

# --- the Asana adapters route; they never draft from a template themselves ---
# Drafting a story is raftkit-pm:story and filing a bug is raftkit-qa:bug; the
# adapters keep only the link registry and its refresh rule. Fetch/render
# language or a template's section vocabulary means an adapter drafts again.
REFS=$DOCS/skills/docs-product/references
SHAPE='fetch|render|Gherkin|numbering|S1–S4|5 to 12'
grep -qF 'raftkit-pm:story' "$REFS/story-adapter.md" && ! grep -qiE "$SHAPE" "$REFS/story-adapter.md"
check "C11 the story adapter routes drafting to raftkit-pm:story and states no template shape" ok $?
grep -qF 'raftkit-qa:bug' "$REFS/bug-adapter.md" && ! grep -qiE "$SHAPE" "$REFS/bug-adapter.md"
check "C12 the bug adapter routes filing to raftkit-qa:bug and states no template shape" ok $?
story_flat="$(tr '\n' ' ' < "$REFS/story-adapter.md")"
grep -qF 'storyRegistry' <<<"$story_flat" && grep -qiE 'never[[:space:]]+duplicat' <<<"$story_flat"
check "C13 the story adapter keeps the link registry and a refresh never duplicates the task" ok $?
grep -qiE 'completed .{0,20}subtasks are never[[:space:]]+deleted' <<<"$story_flat"
check "C14 a refresh never deletes a completed [AC] subtask" ok $?

echo
[[ "$failures" -eq 0 ]]
