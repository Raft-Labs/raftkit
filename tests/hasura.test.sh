#!/usr/bin/env bash
# Deterministic contract suite for the generalized Hasura capability (R4):
# complete bundle port, deterministic detection/non-detection, every TiAiMe
# assumption parameterized, all safety rules preserved, integrations wired.
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

H=plugins/raftkit-dev/skills/hasura
S=$H/SKILL.md
DETECT=$H/scripts/detect-hasura.mjs
PROV=plugins/raftkit-dev/skills/capability-preflight/references/providers.md

# HR1 · complete bundle: SKILL + 3 refs + 3 top scripts + 5 libs + tests + 18 templates
[[ -f "$S" ]] \
  && [[ -f "$H/references/enum-tables.md" && -f "$H/references/permissions-patterns.md" && -f "$H/references/relationship-naming.md" ]] \
  && [[ -f "$H/scripts/new-migration.sh" && -f "$H/scripts/hasura-query.sh" && -f "$H/scripts/check-schema.sh" ]] \
  && [[ -f "$H/scripts/lib/common.sh" && -f "$H/scripts/lib/dbml_grep.sh" && -f "$H/scripts/lib/fk_parse.sh" && -f "$H/scripts/lib/perms.sh" && -f "$H/scripts/lib/render.sh" ]]
check "HR1 core bundle present (SKILL, 3 references, 3 scripts, 5 libs)" ok $?

# The source bundle has 19 .tmpl files (machine-verified from disk; the Phase-0
# audit's "18" undercounted permission-only, which ships up.sql only).
tmpl_count=$(find "$H/templates" -name '*.tmpl' 2>/dev/null | wc -l | tr -d ' ')
[[ "$tmpl_count" -eq 19 ]]
check "HR2 all 19 migration templates ported" ok $?

test_count=$(find "$H/scripts/tests" -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
[[ "$test_count" -ge 8 ]]
check "HR3 ported test suite present (8+ files)" ok $?

# HR4 · deterministic hardcode gate: no TiAiMe identity anywhere in the shipped
# skill (doc mentions of Hasura are fine; project identity is not).
! grep -rliE 'tiaime|ti-origin' "$H" 2>/dev/null | grep -q .
check "HR4 zero TiAiMe project-identity strings in the shipped skill" ok $?

# HR5 · fixed project paths and stages parameterized (not hardcoded literals).
sk=$(joined "$S")
grep -qiE 'discover|detect|configured|Project Profile|convention' <<<"$sk" \
  && ! grep -qE 'services/hasura/migrations/default[^`]*is the migrations dir' <<<"$sk"
check "HR5 paths/stages are discovered or configured, not fixed project literals" ok $?

# HR6 · tenancy scope is convention-driven, not hardcoded to family.
pm=$(joined "$H/scripts/lib/perms.sh")
grep -qE 'TENANCY|SCOPE_|\$\{[A-Z_]*(REL|COLUMN|MEMBER|ACTIVE)' <<<"$pm" \
  && grep -qiE 'deny-by-default|00000000-0000' <<<"$pm"
check "HR6 permission scope is parameterized (tenancy discovered) with deny-by-default fallback" ok $?

# HR7 · all safety rules preserved (verbatim intent) in SKILL.md.
grep -qiE 'never edit.*applied migration|do not edit.*applied' <<<"$sk" \
  && grep -qiE 'up\.sql.*down\.sql|reversible|down reverses' <<<"$sk" \
  && grep -qiE 'confirm.*destructive|destructive.*confirm' <<<"$sk" \
  && grep -qiE 'atomic commit|one .*commit per schema' <<<"$sk" \
  && grep -qiE 'never declare.*admin|admin.*never.*declared|forbidden in YAML' <<<"$sk" \
  && grep -qiE 'admin secret never|never echo|redact' <<<"$sk" \
  && grep -qiE 'local[- ]first|stage=local|only.*local' <<<"$sk"
check "HR7 all safety rules preserved (applied-migration immutability, reversibility, destructive confirm, atomic commit, admin-never-declared, secret redaction, local-first)" ok $?

# HR8 · deterministic detection module: activates on Hasura signals; a
# non-Hasura repo yields nothing.
[[ -f "$DETECT" ]]
check "HR8 detect-hasura.mjs exists" ok $?

if [[ -f "$DETECT" ]]; then
  dt=$(mktemp -d)
  mkdir -p "$dt/hasura/metadata" "$dt/hasura/migrations"
  printf 'version: 3\nendpoint: http://localhost:8080\nmetadata_directory: metadata\n' > "$dt/hasura/config.yaml"
  out=$(node "$DETECT" --root "$dt/hasura" 2>/dev/null); dec=$?
  echo "$out" | grep -qiE 'hasura|detected' && [[ "$dec" -eq 0 ]]
  d1=$?
  nd=$(mktemp -d); printf '{"name":"x"}' > "$nd/package.json"
  out2=$(node "$DETECT" --root "$nd" 2>/dev/null); dec2=$?
  # Non-detection is signalled by exit code and the "no Hasura signals" line;
  # the message intentionally says "does not activate", so match the negative
  # signal precisely rather than the word "activate".
  echo "$out2" | grep -qi 'no Hasura signals' && [[ "$dec2" -ne 0 ]]
  d2=$?
  [[ "$d1" -eq 0 && "$d2" -eq 0 ]]
  check "HR9 detection activates on Hasura signals and stays silent on non-Hasura repos" ok $?
  rm -rf "$dt" "$nd"
else
  check "HR9 detection activates on Hasura signals and stays silent on non-Hasura repos" ok 1
fi

# HR10 · the ported test suite runs green in isolation (the source's own
# safety/behaviour oracle). HASURA_SKILL_AUTOCONFIRM guards interactivity.
if [[ -x "$H/scripts/tests/run.sh" || -f "$H/scripts/tests/run.sh" ]]; then
  ( cd "$H/scripts/tests" && HASURA_SKILL_AUTOCONFIRM=1 bash run.sh ) >/tmp/hr10.out 2>&1
  check "HR10 ported Hasura unit+integration tests pass in isolation" ok $?
else
  check "HR10 ported Hasura unit+integration tests pass in isolation" ok 1
fi

# HR11 · the source's silently-skipped smoke test is fixed (its REAL_DBML path
# no longer resolves one directory short).
grep -q 'REAL_DBML' "$H/scripts/tests/test_dbml_grep.sh" 2>/dev/null \
  && ! grep -qE 'REAL_DBML=.*\.\./\.\./\.\./\.\./docs/schema.dbml' "$H/scripts/tests/test_dbml_grep.sh" 2>/dev/null
check "HR11 the source's off-by-one REAL_DBML smoke-test path is corrected" ok $?

# HR12 · registered in the provider registry as conditional on Hasura detection.
grep -qiE '\| .*hasura.* \|.*conditional' "$PROV" 2>/dev/null
check "HR12 Hasura capability registered conditional on detection in providers.md" ok $?

# HR13 · integrations named: envx, docs sync, capability-preflight, setup.
grep -qiE 'envx' <<<"$sk" \
  && grep -qiE 'docs.*(sync|schema|architecture)|schema.*doc' <<<"$sk" \
  && grep -qiE 'capability-preflight|setup-project|preflight' <<<"$sk"
check "HR13 integrations wired (envx, docs schema sync, preflight/setup)" ok $?

eval_count=$(find plugins/raftkit-dev/evals/hasura -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[[ "${eval_count:-0}" -ge 8 ]] \
  && ! find plugins/raftkit-dev/evals/hasura -mindepth 1 -maxdepth 1 -type d '!' -exec test -f '{}/prompt.md' ';' -print 2>/dev/null | grep -q . \
  && ! find plugins/raftkit-dev/evals/hasura -mindepth 1 -maxdepth 1 -type d '!' -exec sh -c 'ls "$1"/graders/*.md >/dev/null 2>&1' _ '{}' ';' -print 2>/dev/null | grep -q .
check "HR14 at least eight hasura eval cases each include a prompt and grader" ok $?

node - <<'NODE'
const fs = require("fs");
const dev = JSON.parse(fs.readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json", "utf8"));
const market = JSON.parse(fs.readFileSync(".claude-plugin/marketplace.json", "utf8"));
const a = dev.version.split(".").map(Number), min = [0,20,0];
if ((a[0]-min[0] || a[1]-min[1] || a[2]-min[2]) < 0) process.exit(1);
if (market.plugins.find((p) => p.name === "raftkit-dev").description !== dev.description) process.exit(1);
NODE
check "HR15 manifest at least 0.20.0 with marketplace description lockstep" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
