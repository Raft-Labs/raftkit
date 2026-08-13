#!/usr/bin/env bash
# Deterministic contract suite for the restored docs product (R1).
# Verifies the generalized successor to project-docs-generator/-sync inside
# raftkit-dev:docs: template parity, co-authoring workflow, generation,
# reverse engineering, restored change-tracking guarantees, companion
# artifact, and corrected PM/Dev ownership.
set -uo pipefail
cd "$(dirname "$0")/.."

failures=0
check() { # <name> <expected: ok|fail> <actual exit code>
  local name="$1" expected="$2" actual="$3"
  if { [[ "$expected" == ok && "$actual" -eq 0 ]] || [[ "$expected" == fail && "$actual" -ne 0 ]]; }; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected $expected, exit was $actual)"
    failures=$((failures + 1))
  fi
}

joined() { cat "$@" 2>/dev/null | tr '\n' ' ' | tr -s ' '; }

DOCS=plugins/raftkit-dev/skills/docs
T=$DOCS/assets/templates
R=$DOCS/references
COMPANION=$DOCS/assets/companion

# The 31 source template capabilities (enumerated from
# project-docs-generator/assets/templates on disk). 29 ship as adapted
# assets; user-story.md and bug-report.md are R2 live-template adapters and
# must NOT exist as cached files.
SHIPPED_TEMPLATES=(adr api-appsync api-graphql-hasura api-orpc api-rest
  api-webhook-incoming api-webhook-outgoing architecture-overview async-job
  changelog changes-log claude-md compliance-pii decisions design-guidelines
  feature glossary module nfr observability rbac-matrix readme schema-dbml
  schema-drizzle schema-hasura state-machine tech-stack test-plan workflow)

missing=0
for t in "${SHIPPED_TEMPLATES[@]}"; do
  [[ -f "$T/$t.md" ]] || { echo "  missing template: $t.md"; missing=1; }
done
[[ "${#SHIPPED_TEMPLATES[@]}" -eq 29 && "$missing" -eq 0 ]]
check "DP1 all 29 shipped template capabilities exist as adapted assets" ok $?

[[ ! -f "$T/user-story.md" && ! -f "$T/bug-report.md" ]] \
  && grep -rqi 'user-story.*live-template adapter\|live-template adapter.*user-story' "$R" 2>/dev/null \
  && grep -rqi 'bug-report.*live-template adapter\|live-template adapter.*bug-report' "$R" 2>/dev/null
check "DP2 the two Asana templates are R2 live-template adapters, never cached files" ok $?

! grep -rEi 'hostelsync|askshelf|weesli|wrytze|rankze|tiaime|aadhaar|Datahase' "$T" 2>/dev/null | grep -q .
check "DP3 templates carry no client-project or region-identity hardcodes" ok $?

! grep -rl '<body>' "$T" "$COMPANION" 2>/dev/null | grep -q .
check "DP4 no cached Asana HTML skeleton anywhere in docs assets" ok $?

steps_ok=1
for n in $(seq 1 20); do
  grep -qE "^${n}\." "$R/module-decomposition.md" 2>/dev/null || { steps_ok=0; break; }
done
[[ "$steps_ok" -eq 1 ]] \
  && grep -qi 'compliance.*PII.*tests\|Compliance / PII / tests' "$R/module-decomposition.md" 2>/dev/null \
  && grep -qi 'N/A — ' "$R/module-decomposition.md" 2>/dev/null \
  && grep -qi 'both.*agree\|mutual' "$R/module-decomposition.md" 2>/dev/null
check "DP5 module decomposition enumerates 20 numbered steps plus the always-on cross-cut with mutual agreement" ok $?

# DP6-DP8: the interview machinery moved to raftkit-core/discovery-interview so
# raftkit-pm can reach it too. The capability is unchanged and still required —
# these check it at its new address, plus that docs actually routes to it rather
# than having quietly dropped it.
DI=plugins/raftkit-core/skills/discovery-interview
DIR_=$DI/references

cat_count=$(grep -cE '^[0-9]+\. \*\*' "$DIR_/edge-cases.md" 2>/dev/null || echo 0)
[[ "$cat_count" -ge 24 ]] && grep -qi 'never let a category go silent\|answered or.*N/A' "$DIR_/edge-cases.md" 2>/dev/null
check "DP6 edge-case guide walks at least 24 categories, none silent" ok $?

grep -qi 'a few related questions at a time' "$DI/SKILL.md" 2>/dev/null \
  && grep -qi 'three at most' "$DI/SKILL.md" 2>/dev/null \
  && grep -q '(Recommended)' "$DI/SKILL.md" 2>/dev/null \
  && grep -qi "don't pick this if\|do not pick this if" "$DI/SKILL.md" 2>/dev/null \
  && grep -q 'raftkit-core/discovery-interview' "$R/discovery-questions.md" 2>/dev/null
check "DP7 co-authoring contract: small adaptive batches, recommend-first, don't-pick-this-if caveats" ok $?

# DP7b: the batch rule only takes effect if nothing downstream still demands the
# old one-per-turn behaviour. The docs references and the greenfield grader that
# scores them are the two places that can quietly revert it.
! grep -rqiE 'one (question|at a time)|single adaptive question|questions one at a time' \
    "$R" "$DOCS/SKILL.md" plugins/raftkit-dev/evals/docs-product 2>/dev/null
check "DP7b nothing in docs or its graders still demands one question per turn" ok $?

[[ -f "$DIR_/push-back.md" && -f "$DIR_/proactive-prompts.md" ]] \
  && grep -qi 'vague' "$DIR_/push-back.md" 2>/dev/null \
  && grep -qi 'never interrogate.*complete\|complete answers' "$DIR_/push-back.md" 2>/dev/null \
  && grep -qi 'trigger' "$DIR_/proactive-prompts.md" 2>/dev/null \
  && [[ -f "$R/stack-anti-patterns.md" ]] \
  && grep -q 'raftkit-core/discovery-interview' "$DOCS/SKILL.md" 2>/dev/null
check "DP8 push-back and proactive-prompt catalogs shipped, docs routes to them, stack half stays here" ok $?

for ph in 'Classify' 'Business' 'Stack' 'tenancy' 'Module inventory' 'deep dive' 'Cross-cut' 'Confirmation' 'Generation' 'Verification' 'Refinement' 'Scaffolding'; do
  grep -qi "$ph" "$R/orchestration.md" 2>/dev/null || { echo "  missing phase: $ph"; false; break; }
done \
  && grep -qi 'no doc file.*before.*sign-off\|never write.*before.*signed off\|nothing.*written before.*sign-off' "$R/orchestration.md" 2>/dev/null
check "DP9 orchestration names all 12 phases and blocks generation before human sign-off" ok $?

grep -qi 'cannot exit.*matrix\|matrix.*before.*exit' "$R/rbac-guide.md" 2>/dev/null \
  && grep -qi 'role.*module.*visibility' "$R/rbac-guide.md" 2>/dev/null \
  && grep -qi 'role.*field\|sensitive' "$R/rbac-guide.md" 2>/dev/null
check "DP10 RBAC guide forces the three nested matrices before the auth phase exits" ok $?

grep -qi 'greenfield' "$R/generation.md" 2>/dev/null \
  && grep -qi 'existing conventions\|discovered convention' "$R/generation.md" 2>/dev/null \
  && grep -qi 'hybrid.*approved proposal\|approved proposal.*hybrid' "$R/generation.md" 2>/dev/null \
  && grep -qi 'never.*forced\|recommend.*never force\|adaptable' "$R/generation.md" 2>/dev/null
check "DP11 generation is adaptive: greenfield default, convention preservation, hybrid via approved proposal" ok $?

grep -qi 'code-first' "$R/reverse-engineer.md" 2>/dev/null \
  && grep -qi 'Status: Implemented' "$R/reverse-engineer.md" 2>/dev/null \
  && grep -qi 'initial change.*log entry\|initial changes-log entry' "$R/reverse-engineer.md" 2>/dev/null \
  && grep -qi 'confirmed' "$R/reverse-engineer.md" 2>/dev/null \
  && grep -qi 'inferred' "$R/reverse-engineer.md" 2>/dev/null
check "DP12 reverse engineering restored end-to-end with markers, Implemented status, and initial log entry" ok $?

grep -qi 'expansion\|affected-doc' "$R/change-tracking.md" 2>/dev/null \
  && grep -qi 'per-doc history\|local changelog\|verification footer' "$R/change-tracking.md" 2>/dev/null \
  && grep -qi 'changes-log\|pointer' "$R/change-tracking.md" 2>/dev/null \
  && grep -qi 'regenerat' "$R/change-tracking.md" 2>/dev/null \
  && grep -qi 'version tables or.*footers\|repo.s own history convention' "$R/change-tracking.md" 2>/dev/null
check "DP13 change-tracking guarantees restored convention-aware (expansion, history, pointers, diagram regen)" ok $?

grep -qi 'pages' "$R/verification-checklist.md" 2>/dev/null \
  && grep -qi 'telemetry' "$R/verification-checklist.md" 2>/dev/null \
  && grep -qi 'permissions' "$R/verification-checklist.md" 2>/dev/null \
  && grep -qi 'diagrams' "$R/verification-checklist.md" 2>/dev/null \
  && grep -qiE 'P0.*P1.*P2' "$R/verification-checklist.md" 2>/dev/null \
  && grep -qi 'override.*logged\|logged.*override' "$R/verification-checklist.md" 2>/dev/null \
  && grep -qi 'stays.*Draft\|remains.*Draft' "$R/verification-checklist.md" 2>/dev/null
check "DP14 category-graded validation gate with logged override keeping status Draft" ok $?

grep -qi 'always ask' "$R/scaffolding.md" 2>/dev/null \
  && grep -qi 'db:push' "$R/scaffolding.md" 2>/dev/null \
  && grep -qi 'push to main\|push to `main`' "$R/scaffolding.md" 2>/dev/null \
  && grep -q 'capability-preflight' "$R/scaffolding.md" 2>/dev/null \
  && grep -q 'setup-project' "$R/scaffolding.md" 2>/dev/null
check "DP15 scaffolding asks before touching, keeps the never-auto-run list, routes installs through preflight/setup" ok $?

grep -qi 'project-wide' "$R/diagram-catalog.md" 2>/dev/null \
  && grep -qi 'sequence' "$R/diagram-catalog.md" 2>/dev/null \
  && grep -qi 'state' "$R/diagram-catalog.md" 2>/dev/null \
  && grep -qi 'swimlane' "$R/diagram-catalog.md" 2>/dev/null \
  && grep -qi 'N/A — ' "$R/diagram-catalog.md" 2>/dev/null \
  && grep -qi 'regenerat' "$R/diagram-catalog.md" 2>/dev/null
check "DP16 diagram catalog restored with explicit N/A reasoning and regeneration on change" ok $?

[[ -f "$COMPANION/SKILL.md" ]] \
  && grep -qi 'pre-flight' "$COMPANION/SKILL.md" 2>/dev/null \
  && grep -qi 'spec-first' "$COMPANION/SKILL.md" 2>/dev/null \
  && grep -qi 'change-tracking\|code-edit' "$COMPANION/SKILL.md" 2>/dev/null \
  && grep -qi 'validation' "$COMPANION/SKILL.md" 2>/dev/null
check "DP17 project-local companion artifact ships with the four runtime gates" ok $?

head -8 "$COMPANION/SKILL.md" 2>/dev/null | grep -q '^name:' \
  && head -8 "$COMPANION/SKILL.md" 2>/dev/null | grep -q '^description:' \
  && ! head -12 "$COMPANION/SKILL.md" 2>/dev/null | grep -qE '^(user-invocable|disable-model-invocation|allowed-tools):'
check "DP18 companion frontmatter is portable (name+description only; runtime-specific fields are R3-rendered)" ok $?

all_docs=$(joined "$DOCS/SKILL.md" "$R"/*.md)
! grep -q 'the Cowork surface plans, this skill synchronizes' <<<"$all_docs" \
  && ! grep -q "re-does the other's work" <<<"$all_docs"
check "DP19 the contradicted PM-plans/Dev-synchronizes split sentences are gone" ok $?

own=$(joined "$DOCS/SKILL.md" "$R/lifecycle-and-handoff.md")
grep -qiE 'full design.*workflow when invoked directly|design/generation workflow when invoked directly' <<<"$own" \
  && grep -qiE 'consumed.*never re-asked|never re-asks confirmed' <<<"$own"
check "DP20 the corrected ownership contract is present (Dev-direct design; approved planning never re-asked)" ok $?

grep -q 'docs mode:' "$DOCS/SKILL.md" 2>/dev/null \
  && grep -q 'Docs: updated and verified' "$DOCS/SKILL.md" "$R"/*.md 2>/dev/null | head -1 >/dev/null \
  && grep -rq 'Docs: not impacted' "$DOCS" 2>/dev/null \
  && grep -qi 'design' "$DOCS/SKILL.md" 2>/dev/null \
  && grep -qi 'scaffold' "$DOCS/SKILL.md" 2>/dev/null
check "DP21 mode contract extended (design/scaffold) while every owned success string is preserved" ok $?

M=tests/fixtures/docs/module-indexed
F=tests/fixtures/docs/flat-ownership-indexed
[[ -d "$M/docs/project/modules" && -d "$M/docs/project/index" && -d "$M/docs/project/adr" ]] \
  && [[ -f "$M/docs/project/changes-log.md" ]] \
  && grep -rqi 'Last verified:' "$F" 2>/dev/null \
  && grep -rqi 'Ownership Index\|ownership index' "$F" 2>/dev/null \
  && grep -rqE '## ADR-[0-9]+' "$F" 2>/dev/null \
  && [[ -d tests/fixtures/docs/hybrid ]]
check "DP22 fixtures faithful: askyio-shape (modules/index/adr/changes-log), tiaime-shape (footers/ownership/inline ADRs), hybrid present" ok $?

node "$DOCS/scripts/validate-docs.mjs" --root "$M" --graded >/tmp/dp23.out 2>&1
grade_exit=$?
grep -qE 'P0|P1|P2' /tmp/dp23.out && [[ "$grade_exit" -eq 0 || "$grade_exit" -eq 1 ]]
check "DP23 validate-docs --graded emits a P0/P1/P2 report with the stable exit contract" ok $?

eval_count=$(find plugins/raftkit-dev/evals/docs-product -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[[ "${eval_count:-0}" -ge 8 ]] \
  && ! find plugins/raftkit-dev/evals/docs-product -mindepth 1 -maxdepth 1 -type d '!' -exec test -f '{}/prompt.md' ';' -print 2>/dev/null | grep -q . \
  && ! find plugins/raftkit-dev/evals/docs-product -mindepth 1 -maxdepth 1 -type d '!' -exec sh -c 'ls "$1"/graders/*.md >/dev/null 2>&1' _ '{}' ';' -print 2>/dev/null | grep -q .
check "DP24 at least eight docs-product eval cases each include a prompt and grader" ok $?

node - <<'NODE'
const fs = require("fs");
const manifest = JSON.parse(fs.readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json", "utf8"));
const market = JSON.parse(fs.readFileSync(".claude-plugin/marketplace.json", "utf8"));
const v = manifest.version.split(".").map(Number);
const min = [0, 17, 0];
const cmp = v[0] - min[0] || v[1] - min[1] || v[2] - min[2];
const entry = market.plugins.find((p) => p.name === "raftkit-dev");
if (cmp < 0 || !entry || entry.description !== manifest.description) process.exit(1);
NODE
check "DP25 manifest at least 0.17.0 with marketplace description lockstep" ok $?

! grep -rEi 'hostelsync|askshelf|weesli|wrytze|rankze|aadhaar|Datahase' "$R" 2>/dev/null | grep -q .
check "DP26 references carry no client-project hardcodes (tiaime allowed only as named compatibility fixture)" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
