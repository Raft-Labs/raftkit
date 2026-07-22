#!/usr/bin/env bash
# Deterministic contract suite for baseline capabilities + transactional setup
# and companion delivery across runtimes (R3).
set -uo pipefail
cd "$(dirname "$0")/.."

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
joined() { cat "$@" 2>/dev/null | tr '\n' ' ' | tr -s ' '; }

PRE=plugins/raftkit-dev/skills/capability-preflight
PROV=$PRE/references/providers.md
CLS=$PRE/scripts/classify.mjs
SETUP=plugins/raftkit-dev/skills/setup-project
IF=$SETUP/references/install-flow.md
RENDER=$SETUP/scripts/render-companion.mjs
DOCS_COMPANION=plugins/raftkit-dev/skills/docs/assets/companion/SKILL.md

pv=$(joined "$PROV")
grep -qiE '\| claude-mem \|.*baseline-required' "$PROV"
check "BS1 claude-mem is baseline-required (exact provider)" ok $?

grep -qiE '\| remember \|.*optional' "$PROV" \
  && grep -qi 'never a substitute' "$PROV"
check "BS2 remember is standalone optional, never a substitute for claude-mem" ok $?

grep -qiE '\| task-observer \|.*baseline-required' "$PROV"
check "BS3 task-observer row added as baseline-required" ok $?

grep -qiE '\| (find-skills|skill-discovery) \|.*baseline-required' "$PROV" \
  && grep -qi 'npx skills' "$PROV"
check "BS4 find-skills is baseline-required (skill plus Skills CLI seam)" ok $?

grep -qiE '\| frontend-design \|.*baseline-required' "$PROV"
check "BS5 frontend-design is baseline-required" ok $?

grep -qiE '\| envx \|.*baseline-required' "$PROV"
check "BS6 envx is baseline-required" ok $?

grep -qiE '\| impeccable \|.*required-available' "$PROV" \
  && grep -qi 'never replac' "$PROV"
check "BS7 impeccable required-available for UI work, never replacing frontend-design" ok $?

grep -q 'baseline-required' "$CLS" 2>/dev/null
check "BS8 classifier parses the baseline-required policy" ok $?

# Behavioral: a baseline capability that is absent from the inventory must be
# reported "missing", never "optional-not-selected".
tmp=$(mktemp -d)
cat > "$tmp/plugins.json" <<'JSON'
[{"id":"superpowers@claude-plugins-official","enabled":true,"version":"1.0.0","scope":"user"},
 {"id":"raftkit-dev@raftkit","enabled":true,"version":"0.19.0","scope":"user"}]
JSON
echo '[]' > "$tmp/skills.json"
out=$(node "$CLS" --registry "$PROV" --plugins "$tmp/plugins.json" --skills "$tmp/skills.json" 2>/dev/null || true)
echo "$out" | grep -Ei 'frontend-design.*missing' >/dev/null \
  && ! echo "$out" | grep -Ei 'frontend-design.*optional-not-selected' >/dev/null
check "BS9 an absent baseline capability classifies as missing, never optional-not-selected" ok $?
rm -rf "$tmp"

ifj=$(joined "$IF")
grep -qiE 'consolidated|one .*plan|single .*plan' <<<"$ifj" \
  && grep -qiE 'one .*approval|single .*approval|one explicit approval' <<<"$ifj" \
  && grep -qi 'source' <<<"$ifj" && grep -qi 'version' <<<"$ifj" \
  && grep -qi 'provenance' <<<"$ifj" && grep -qi 'license' <<<"$ifj"
check "BS10 install-flow describes one consolidated setup plan gated on one approval" ok $?

grep -qiE 'transaction|all-or-nothing|atomic' <<<"$ifj" \
  && grep -qiE 'rollback|roll back|rolls back' <<<"$ifj" \
  && grep -qi 'verif' <<<"$ifj" \
  && grep -qiE 'journal|inverse|staging' <<<"$ifj"
check "BS11 transactional install with verification, rollback, and journaled/staged boundary" ok $?

grep -qiE 'decline|declined' <<<"$ifj" \
  && grep -qiE 'not ready|project.*not ready' <<<"$ifj" \
  && grep -qi 'never.*optional-not-selected\|baseline.*never optional' <<<"$ifj"
check "BS12 declining a required capability stops setup; baseline never optional-not-selected" ok $?

grep -qiE 'idempotent|re-run' <<<"$ifj" \
  && grep -qi 'project-owned' <<<"$ifj" \
  && grep -qi 'clobber\|overwrit' <<<"$ifj"
check "BS13 idempotent re-runs never clobber project-owned files" ok $?

grep -qiE 'skills-lock|lockfile' <<<"$ifj" \
  && grep -qi 'hash' <<<"$ifj" && grep -qi 'source' <<<"$ifj"
check "BS14 lockfile records hashes and sources for copied/installed skills" ok $?

grep -qi 'task-observer' <<<"$ifj" \
  && grep -qiE 'activation instruction|merge' <<<"$ifj" \
  && grep -qiE 'CC BY 4.0|attribution' <<<"$ifj" \
  && grep -qiE 'provider channel|npx skills add|envx skill add|impeccable' <<<"$ifj"
check "BS15 activation-merge safety, attribution preserved, unlicensed caps via provider channels" ok $?

grep -q '.claude/skills' <<<"$ifj" && grep -q '.agents/skills' <<<"$ifj" && grep -q '.cursor/skills' <<<"$ifj" \
  && grep -qiE 'detect|environment' <<<"$ifj" \
  && grep -qiE 'exact.*destination|proposed destination' <<<"$ifj" \
  && grep -qiE 'approval before install|human approval' <<<"$ifj"
check "BS16 companion delivery names verified destinations with detection and approval" ok $?

grep -qiE 'never.*instruction file.*installed skill|instruction file is never.*installed skill' <<<"$ifj" \
  && grep -qiE 'no.*unsupported.*guess|never.*guess' <<<"$ifj" \
  && grep -qi 'render' <<<"$ifj"
check "BS17 truthful fallback: instruction file never called an installed skill; no format guessing" ok $?

# Executable per-runtime rendering with a leak guard: Claude-only frontmatter
# fields must never appear in a Codex/Cursor artifact.
[[ -f "$RENDER" ]] || false
check "BS18 render-companion.mjs exists" ok $?

if [[ -f "$RENDER" ]]; then
  rtmp=$(mktemp -d)
  node "$RENDER" --source "$DOCS_COMPANION" --runtime cursor --out "$rtmp/cursor.md" >/dev/null 2>&1
  node "$RENDER" --source "$DOCS_COMPANION" --runtime codex --out "$rtmp/codex.md" >/dev/null 2>&1
  node "$RENDER" --source "$DOCS_COMPANION" --runtime claude --out "$rtmp/claude.md" >/dev/null 2>&1
  leak=0
  for f in "$rtmp/cursor.md" "$rtmp/codex.md"; do
    head -12 "$f" 2>/dev/null | grep -qE '^(user-invocable|disable-model-invocation|allowed-tools):' && leak=1
  done
  head -12 "$rtmp/cursor.md" 2>/dev/null | grep -q '^name:' && head -12 "$rtmp/cursor.md" 2>/dev/null | grep -q '^description:'
  ncok=$?
  [[ "$leak" -eq 0 && "$ncok" -eq 0 ]]
  check "BS19 rendered Codex/Cursor artifacts carry no Claude-only frontmatter and keep name+description" ok $?
  rm -rf "$rtmp"
else
  check "BS19 rendered Codex/Cursor artifacts carry no Claude-only frontmatter and keep name+description" ok 1
fi

tb=$(joined "$IF" "$SETUP/references/components.md")
grep -qiE 'transaction boundary|journaled|inverse' <<<"$tb" \
  && grep -qiE 'injected failure|failure.*roll ?back|zero.*residue|no.*residue' <<<"$tb"
check "BS20 transaction-boundary redesign: journaled inverses, zero residue on failure" ok $?

eval_count=$(find plugins/raftkit-dev/evals/baseline-setup -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[[ "${eval_count:-0}" -ge 8 ]] \
  && ! find plugins/raftkit-dev/evals/baseline-setup -mindepth 1 -maxdepth 1 -type d '!' -exec test -f '{}/prompt.md' ';' -print 2>/dev/null | grep -q . \
  && ! find plugins/raftkit-dev/evals/baseline-setup -mindepth 1 -maxdepth 1 -type d '!' -exec sh -c 'ls "$1"/graders/*.md >/dev/null 2>&1' _ '{}' ';' -print 2>/dev/null | grep -q .
check "BS21 at least eight baseline-setup eval cases each include a prompt and grader" ok $?

node - <<'NODE'
const fs = require("fs");
const dev = JSON.parse(fs.readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json", "utf8"));
const market = JSON.parse(fs.readFileSync(".claude-plugin/marketplace.json", "utf8"));
const a = dev.version.split(".").map(Number), min = [0,19,0];
if ((a[0]-min[0] || a[1]-min[1] || a[2]-min[2]) < 0) process.exit(1);
if (market.plugins.find((p) => p.name === "raftkit-dev").description !== dev.description) process.exit(1);
NODE
check "BS22 manifest at least 0.19.0 with marketplace description lockstep" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
