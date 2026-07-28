#!/usr/bin/env bash
# Deterministic contract suite for the F1-F6 remediation and SHA-bound gate
# evidence (R5), against the restored contracts.
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

RENDER=plugins/raftkit-dev/skills/setup-project/scripts/render-assets.mjs
DETECT=plugins/raftkit-dev/skills/setup-project/scripts/detect-toolchain.mjs
VALDOCS=plugins/raftkit-dev/skills/docs/scripts/validate-docs.mjs
CLS=plugins/raftkit-dev/skills/capability-preflight/scripts/classify.mjs
FPE=plugins/raftkit-dev/skills/fix-production-error
PR=plugins/raftkit-dev/skills/pr
SG=plugins/raftkit-dev/skills/scope-guard
DOCS=plugins/raftkit-dev/skills/docs

# ---- F1 · shell/YAML-safe rendering ---------------------------------------
rj=$(joined "$RENDER")
grep -qiE 'shell-?quote|single-quote|charset-proven|charset|quote' <<<"$rj" \
  && grep -qiE 'yaml-encode|yaml.*encode|encode.*yaml|json.*yaml|quote.*yaml' <<<"$rj"
check "F1a rendering documents shell-quoting/charset and YAML encoding of substituted values" ok $?

# Adversarial: an injection-shaped script name must render nothing (fail-closed).
adv=$(mktemp -d)
cat > "$adv/manifest.json" <<'JSON'
{ "pm": "pnpm", "scripts": ["lint", "test; rm -rf /"] }
JSON
node "$RENDER" --manifest "$adv/manifest.json" --out "$adv/out" >/dev/null 2>&1
rc=$?
[[ "$rc" -ne 0 && ! -e "$adv/out" ]]
check "F1b an injection-shaped value renders nothing (fail-closed)" ok $?
rm -rf "$adv"

# ---- F2 · docs confinement + truthful descriptor schema -------------------
# An out-of-root --convention descriptor is rejected with the bad-input exit.
c2=$(mktemp -d); mkdir -p "$c2/repo"; echo "outside" > "$c2/evil.json"
( cd "$c2/repo" && git init -q . && node "$OLDPWD/$VALDOCS" --root . --convention "../evil.json" ) >/dev/null 2>&1
[[ $? -eq 2 ]]
check "F2a an out-of-root --convention descriptor is rejected (bad input)" ok $?
rm -rf "$c2"

vj=$(joined "$DOCS/references/discovery-and-routing.md" "$VALDOCS")
grep -qiE 'descriptor schema|minimal.*schema|schema.*field' <<<"$vj" \
  && grep -qiE 'unknown field.*reject|reject.*unknown|only.*documented field' <<<"$vj"
check "F2b the descriptor schema is minimal, documented, and rejects unknown fields" ok $?

# ---- F3 · symlinked hooks foreign; origin + multi-value evidence -----------
grep -qE 'show-origin' "$DETECT" 2>/dev/null \
  && grep -qE 'get-all' "$DETECT" 2>/dev/null \
  && grep -qiE 'symlink.*foreign|foreign.*symlink|isSymbolicLink' "$DETECT" 2>/dev/null
check "F3a detector reads --show-origin --get-all and treats symlinked hooks as foreign" ok $?

dj=$(joined "$DETECT")
grep -qiE 'multi-?value|multiple.*value|more than one.*value' <<<"$dj" \
  && grep -qiE 'conflict|stop.*ask|ask' <<<"$dj"
check "F3b multiple core.hooksPath values are a conflict that stops and asks with full evidence" ok $?

# ---- F4 · evidence-backed readiness ---------------------------------------
grep -qiE 'evidence' "$CLS" 2>/dev/null \
  && grep -qiE 'inventory.*verified|verified.*inventory|listed-only|listed only|not consulted' "$CLS" 2>/dev/null
check "F4 readiness rows name the evidence actually consulted (verified-inventory vs listed-only)" ok $?

# ---- F5 · correctly scoped commands ---------------------------------------
grep -qiE 'scope' "$CLS" 2>/dev/null \
  && grep -qiE '[-][-]scope|scope flag|explicit scope|enable.*scope|install.*scope|scope pending' "$CLS" 2>/dev/null
check "F5 proposed enable/install commands carry the correct explicit scope or ask" ok $?

# ---- F6 · Incident PR Handoff (8 elements) --------------------------------
ho=$(joined "$FPE/SKILL.md" "$FPE/references/incident-loop.md")
grep -qiE 'Incident PR Handoff' <<<"$ho" \
  && grep -qiE 'incident source|source/evidence|trace' <<<"$ho" \
  && grep -qiE 'containment scope' <<<"$ho" \
  && grep -qiE 'inspected change set' <<<"$ho" \
  && grep -qiE 'regression-test evidence|permanent regression' <<<"$ho" \
  && grep -qiE 'full-suite result|full suite' <<<"$ho" \
  && grep -qiE 'scope-audit result|incident scope-audit' <<<"$ho" \
  && grep -qiE 'operational-doc|no-impact|follow-up' <<<"$ho" \
  && grep -qiE 'human-controlled deployment|deployment.*human' <<<"$ho"
check "F6a fix-production-error produces the eight-element Incident PR Handoff" ok $?

grep -qiE 'missing.*element.*hard stop|hard stop.*missing|named hard stop|any missing' <<<"$ho"
check "F6b an incomplete handoff is a named hard stop" ok $?

prj=$(joined "$PR/SKILL.md" "$PR/references/raise-flow.md")
grep -qiE 'incident mode' <<<"$prj" \
  && grep -qiE 'only.*handoff|structured.*handoff.*activat|activated.*handoff' <<<"$prj" \
  && grep -qiE 'no silent downgrade|never.*silently.*incident|never silently downgrade' <<<"$prj" \
  && grep -qiE 'missing.*story.*hard fail|hard fail.*no story|normal.*hard' <<<"$prj"
check "F6c pr incident mode activates only via the handoff; normal missing-story hard-fail preserved; no silent downgrade" ok $?

sgj=$(joined "$SG/SKILL.md" "$SG/references/audit-method.md")
grep -qiE 'incident' <<<"$sgj" \
  && grep -qiE 'containment' <<<"$sgj" \
  && grep -qiE 'story-mode.*unchanged|activated.*only.*handoff|only.*by.*handoff' <<<"$sgj"
check "F6d scope-guard has a bounded incident branch activated only by the handoff; story-mode unchanged" ok $?

grep -qiE 'incident' <<<"$(joined "$DOCS/references/verification.md")"
check "F6e docs verification has an incident-evidence branch for the containment change set" ok $?

# ---- SHA-bound gate evidence ----------------------------------------------
shj=$(joined "$PR/references/raise-flow.md" "$SG/references/audit-method.md" "$DOCS/references/verification.md" plugins/raftkit-dev/skills/implement/references/gates.md)
grep -qiE 'SHA|change-set.*sha|inspected.*sha' <<<"$shj" \
  && grep -qiE 'stale.*evidence|evidence.*stale|evidence stale' <<<"$shj" \
  && grep -qiE 'regenerat|refresh.*evidence' <<<"$shj"
check "F7 gate evidence is bound to the inspected change-set SHA; stale evidence is refused and must be regenerated" ok $?

# ---- evals + version ------------------------------------------------------
eval_count=$(find plugins/raftkit-dev/evals/remediation -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[[ "${eval_count:-0}" -ge 8 ]] \
  && ! find plugins/raftkit-dev/evals/remediation -mindepth 1 -maxdepth 1 -type d '!' -exec test -f '{}/prompt.md' ';' -print 2>/dev/null | grep -q . \
  && ! find plugins/raftkit-dev/evals/remediation -mindepth 1 -maxdepth 1 -type d '!' -exec sh -c 'ls "$1"/graders/*.md >/dev/null 2>&1' _ '{}' ';' -print 2>/dev/null | grep -q .
check "F8 at least eight remediation eval cases each include a prompt and grader" ok $?

node - <<'NODE'
const fs = require("fs");
const dev = JSON.parse(fs.readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json", "utf8"));
const market = JSON.parse(fs.readFileSync(".claude-plugin/marketplace.json", "utf8"));
const a = dev.version.split(".").map(Number), min = [0,21,0];
if ((a[0]-min[0] || a[1]-min[1] || a[2]-min[2]) < 0) process.exit(1);
if (market.plugins.find((p) => p.name === "raftkit-dev").description !== dev.description) process.exit(1);
NODE
check "F9 manifest at least 0.21.0 with marketplace description lockstep" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
