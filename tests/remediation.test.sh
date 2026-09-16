#!/usr/bin/env bash
# Deterministic contract suite for the F1-F6 remediation and SHA-bound gate
# evidence (R5), against the restored contracts.
set -uo pipefail
export NODE_DISABLE_COLORS=1 FORCE_COLOR=0 NO_COLOR=1
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

RENDER=plugins/raftkit-dev/skills/setup/scripts/render-assets.mjs
DETECT=plugins/raftkit-dev/skills/setup/scripts/detect-toolchain.mjs
VALDOCS=plugins/raftkit-dev/skills/docs/scripts/validate-docs.mjs

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

vj=$(joined "plugins/raftkit-dev/skills/docs/references/scripts.md" "$VALDOCS")
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

# ---- evals + version ------------------------------------------------------
eval_count=$(find plugins/raftkit-dev/evals/remediation -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[[ "${eval_count:-0}" -ge 5 ]] \
  && ! find plugins/raftkit-dev/evals/remediation -mindepth 1 -maxdepth 1 -type d '!' -exec test -f '{}/prompt.md' ';' -print 2>/dev/null | grep -q . \
  && ! find plugins/raftkit-dev/evals/remediation -mindepth 1 -maxdepth 1 -type d '!' -exec sh -c 'ls "$1"/graders/*.md >/dev/null 2>&1' _ '{}' ';' -print 2>/dev/null | grep -q .
check "F8 every surviving remediation eval case includes a prompt and grader" ok $?

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
