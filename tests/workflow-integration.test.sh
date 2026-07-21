#!/usr/bin/env bash
# Deterministic contract suite for Story C (M3 · workflow integration,
# Asana 1216765811385360). Placement-aware: seams must appear in their owning
# workflow section, not merely somewhere in a file.
#
# AC → evidence matrix (behavioral eval bundle authored pre-implementation and
# structurally verified; plugin/no-plugin EXECUTION deferred to the final
# plugin-evaluation story):
#   AC-1  preflight before Gate 0 .......... W2            + evals
#   AC-2  scoped superpowers components .... W3
#   AC-3  security hook semantics .......... W4, W15
#   AC-4  Gate 1 Docs Impact Plan .......... W5            + evals
#   AC-5  docs verify before Gate 2 ........ W6            + evals
#   AC-6  pr Docs section .................. W7            + evals
#   AC-7  pr truthful layers ............... W8, W16
#   AC-8  fix-bug docs boundary ............ W9            + evals
#   AC-9  incident containment first ....... W10           + evals
#   AC-10 ui adoption policy ............... W11, W16      + evals
#   AC-11 simplify real engines ............ W12, W17      + evals
#   AC-12 scope-guard docs mapping ......... W13           + evals
#   AC-13 deterministic tests red-first .... this suite (red captured pre-edit)
#   AC-14 eval bundle authored ............. W18 (structural + no-leak)
#   AC-15 manifests / diff allowlist ....... W1, W19 (+ scripts/validate.sh)
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

DEV=plugins/raftkit-dev/skills
# Section extractor: prints file content between a start regex (inclusive) and
# the next heading matching the end regex (exclusive-ish; sed range semantics).
sec() { sed -n "/$2/,/$3/p" "$1" 2>/dev/null; }

# W1 · Story C file allowlist. The persistent suite tests the ALGORITHM against
# synthetic changed-file lists (no branch SHAs — squash-safe). The real PR range
# audit is explicit and caller-supplied:
#   bash tests/workflow-integration.test.sh --scope-check <base> <head>
# tests/docs-scripts.test.sh is allowed solely for the human-approved D22a
# integration-branch compatibility fix (exact 0.13.0 pin -> semantic >= 0.13.0).
allow='^(tests/workflow-integration\.test\.sh|tests/docs-scripts\.test\.sh|plugins/raftkit-dev/evals/workflow-integration/|plugins/raftkit-dev/\.claude-plugin/plugin\.json|\.claude-plugin/marketplace\.json|plugins/raftkit-dev/skills/implement/(SKILL\.md|references/(gates|execution)\.md)|plugins/raftkit-dev/skills/pr/(SKILL\.md|references/(raise-flow|automated-review)\.md)|plugins/raftkit-dev/skills/fix-bug/(SKILL\.md|references/(fix-loop|bug-intake-and-handback)\.md)|plugins/raftkit-dev/skills/fix-production-error/(SKILL\.md|references/(incident-loop|triage-and-refusal)\.md)|plugins/raftkit-dev/skills/ui-creation/(SKILL\.md|references/(build-flow|guardrails)\.md)|plugins/raftkit-dev/skills/simplify/(SKILL\.md|references/candidate-catalog\.md)|plugins/raftkit-dev/skills/scope-guard/(SKILL\.md|references/(audit-method|output-and-signoff)\.md))'
# Scope-check mode: explicit, validated, argument-array git — never inferred.
if [[ "${1:-}" == "--scope-check" ]]; then
  base="${2:-}"; head="${3:-}"
  [[ -n "$base" && -n "$head" && "$base" != -* && "$head" != -* ]] || { echo "scope-check requires <base> <head> commits"; exit 2; }
  git rev-parse --verify --quiet "$base^{commit}" >/dev/null || { echo "scope-check: invalid or unreachable base '$base'"; exit 2; }
  git rev-parse --verify --quiet "$head^{commit}" >/dev/null || { echo "scope-check: invalid or unreachable head '$head'"; exit 2; }
  git merge-base --is-ancestor "$base" "$head" || { echo "scope-check: reversed or disjoint range $base..$head"; exit 2; }
  changed="$(git diff --name-only "$base" "$head" --)"
  echo "scope-check $base..$head — changed files:"; printf '%s\n' "$changed"
  viol="$(grep -Ev "$allow" <<<"$changed" || true)"
  if [[ -n "$viol" ]]; then printf 'ALLOWLIST VIOLATIONS:\n%s\nscope-check: FAIL\n' "$viol"; exit 1; fi
  echo "scope-check: PASS — every changed file is inside the approved allowlist"
  exit 0
fi

syn_ok=$'tests/workflow-integration.test.sh\ntests/docs-scripts.test.sh\nplugins/raftkit-dev/skills/implement/references/gates.md\nplugins/raftkit-dev/evals/workflow-integration/case/prompt.md\nplugins/raftkit-dev/.claude-plugin/plugin.json'
[[ -z "$(grep -Ev "$allow" <<<"$syn_ok" || true)" ]]
check "W1a allowlist admits approved Story C paths (synthetic)" ok $?
syn_bad=$'plugins/raftkit-dev/skills/docs/SKILL.md\nplugins/raftkit-core/skills/house-rules/SKILL.md\nplugins/raftkit-dev/skills/setup-project/SKILL.md'
[[ "$(grep -Ev "$allow" <<<"$syn_bad" | wc -l | tr -d ' ')" == 3 ]]
check "W1b allowlist flags every out-of-scope path (synthetic)" ok $?

# W2 · implement: capability preflight placed BEFORE Gate 0 (assumes/preflight
# area of SKILL.md and the top of gates.md Gate 0 section), with repair-guidance stop.
sec "$DEV/implement/SKILL.md" '^## What this skill assumes' '^## Parameters' | grep -q 'raftkit-dev:capability-preflight'
check "W2a preflight named in implement's assumptions area" ok $?
sec "$DEV/implement/references/gates.md" '^## Gate 0' '^## Gate 1' | grep -q 'raftkit-dev:capability-preflight' \
  && sec "$DEV/implement/references/gates.md" '^## Gate 0' '^## Gate 1' | grep -q 'human-approved RaftKit install/update'
check "W2b Gate 0 section runs preflight with declared-dep repair stop" ok $?

# W3 · implement: the five scoped superpowers components in their flow homes.
sec "$DEV/implement/references/gates.md" '^## Gate 1' '^## Gate 2' | grep -q 'superpowers:brainstorming' \
  && sec "$DEV/implement/references/gates.md" '^## Gate 1' '^## Gate 2' | grep -q 'superpowers:writing-plans'
check "W3a Gate 1 planning names superpowers:brainstorming + writing-plans" ok $?
sec "$DEV/implement/references/execution.md" '^## Phases' '^## Progress' | grep -q 'superpowers:test-driven-development' \
  && sec "$DEV/implement/references/execution.md" '^## Phases' '^## Progress' | grep -q 'superpowers:systematic-debugging'
check "W3b phase discipline names scoped TDD + systematic-debugging" ok $?
grep -q 'superpowers:verification-before-completion' "$DEV/implement/references/execution.md" 2>/dev/null
check "W3c pre-Gate-2 verification names the scoped component" ok $?

# W4 · security hook semantics live in the post-edit layer section; no
# affirmative invocation of security-guidance anywhere in the seven skills.
post=$(sec "$DEV/implement/references/execution.md" '^## Post-edit gates' '^$END$')
grep -q 'PostToolUse' <<<"$post" && grep -q 'Stop' <<<"$post" && grep -qi 'never.*pre-claim\|never fabricates' <<<"$post"
check "W4a post-edit section states hook timing without pre-claiming Stop output" ok $?
! grep -rE '(run|invoke|execute)[^.]{0,40}security-guidance' \
  "$DEV/implement" "$DEV/pr" "$DEV/fix-bug" "$DEV/fix-production-error" "$DEV/ui-creation" "$DEV/simplify" "$DEV/scope-guard" 2>/dev/null | grep -q .
check "W4b no affirmative instruction to invoke security-guidance" ok $?

# W5 · Gate 1 section carries the Docs Impact Plan with the unknown-as-blocker rule.
g1=$(sec "$DEV/implement/references/gates.md" '^## Gate 1' '^## Gate 2')
grep -q 'Docs Impact Plan' <<<"$g1" && grep -qi 'unknown mapping' <<<"$g1" \
  && grep -qi 'planning blocker' <<<"$g1" && grep -qi 'before any docs mutation\|before any documentation' <<<"$g1"
check "W5 Gate 1 Docs Impact Plan with unknown-mapping planning-blocker rule" ok $?

# W6 · Gate 2 section invokes docs verify with the explicit change-set contract.
g2=$(sec "$DEV/implement/references/gates.md" '^## Gate 2' '^$END$')
grep -q 'raftkit-dev:docs' <<<"$g2" && grep -qi 'change set' <<<"$g2" \
  && grep -qF 'Docs: updated and verified' <<<"$g2" && grep -qF 'Docs: not impacted — <reason>' <<<"$g2" \
  && grep -qiv 'arbitrary' <<<"$g2" && grep -qi 'never.*arbitrary Git range\|never choose.*range silently' <<<"$g2"
check "W6 Gate 2 docs verify with explicit change set and owner strings" ok $?

# W7 · pr: five mandatory description sections including a blocking Docs section.
desc=$(sec "$DEV/pr/references/raise-flow.md" 'mandatory sections' '^## Push')
grep -q '5\.' <<<"$desc" && grep -qE '\*\*Docs\*\*|5\. \*\*Docs' <<<"$desc" \
  && grep -qF 'Docs: not impacted — <reason>' <<<"$desc"
check "W7a raise-flow description block lists Docs as section five" ok $?
grep -q 'five mandatory sections\|five sections' "$DEV/pr/SKILL.md" 2>/dev/null
check "W7b pr SKILL.md names five sections" ok $?

# W8 · pr: scoped review entry component with preflight-routed readiness.
rev=$(cat "$DEV/pr/references/automated-review.md" 2>/dev/null)
grep -q 'pr-review-toolkit:review-pr' <<<"$rev" && grep -q 'raftkit-dev:capability-preflight' <<<"$rev"
check "W8 automated-review names pr-review-toolkit:review-pr with preflight readiness" ok $?

# W9 · fix-bug: docs boundary in the run flow / hand-back.
grep -q 'documented contract was wrong\|documented contract was already correct' "$DEV/fix-bug/SKILL.md" 2>/dev/null \
  && grep -qF 'Docs: not impacted — <reason>' "$DEV/fix-bug/references/bug-intake-and-handback.md" 2>/dev/null \
  && grep -q 'superpowers:systematic-debugging' "$DEV/fix-bug/SKILL.md" 2>/dev/null
check "W9 fix-bug docs boundary + scoped debugging seam" ok $?

# W10 · fix-production-error: containment never blocked by docs; scoped seam.
grep -qi 'docs.*never block.*containment\|containment.*never blocked' "$DEV/fix-production-error/references/incident-loop.md" 2>/dev/null \
  && grep -q 'superpowers:systematic-debugging' "$DEV/fix-production-error/SKILL.md" 2>/dev/null
check "W10 incident loop keeps containment first with scoped debugging" ok $?

# W11 · ui-creation: scoped providers + adoption policy in guardrails.
grep -q 'frontend-design:frontend-design' "$DEV/ui-creation/SKILL.md" 2>/dev/null
check "W11a ui SKILL names frontend-design:frontend-design" ok $?
guard=$(cat "$DEV/ui-creation/references/guardrails.md" 2>/dev/null)
grep -q 'impeccable:impeccable' <<<"$guard" && grep -q 'optional-not-selected' <<<"$guard" \
  && grep -qi 'adopted.*required\|adopted by the project' <<<"$guard" && grep -qi 'never silently' <<<"$guard"
check "W11b guardrails carry the adopted-vs-unadopted provider policy" ok $?

# W12 · simplify: scoped dispatch + ponytail review; duplicated method removed.
grep -q 'code-simplifier:code-simplifier' "$DEV/simplify/SKILL.md" 2>/dev/null \
  && grep -q 'ponytail:ponytail-review' "$DEV/simplify/SKILL.md" 2>/dev/null
check "W12a simplify names both scoped engines" ok $?
! grep -riE 'prefer deleting code to restructuring|introduce no new abstractions|complexity must earn its place' "$DEV/simplify" 2>/dev/null | grep -q .
check "W12b duplicated ponytail method text removed from simplify" ok $?
grep -q 'diff-only\|Diff-only' "$DEV/simplify/SKILL.md" && grep -qi 'revert' "$DEV/simplify/SKILL.md"
check "W12c RaftKit's diff-only + revert-safety governance retained" ok $?

# W13 · scope-guard: docs mapping in the audit method.
am=$(cat "$DEV/scope-guard/references/audit-method.md" 2>/dev/null)
grep -qi 'Docs Impact Plan' <<<"$am" && grep -qi 'documentation.*BEYOND\|docs.*BEYOND' <<<"$am" \
  && grep -qi 'not.*quality' <<<"$am"
check "W13 audit method maps docs edits to ACs/plan without quality review" ok $?

# W15 · reproduced strings are byte-identical to their owners.
for s in 'Docs: not impacted — <reason>' 'Docs: updated and verified'; do
  grep -qF "$s" "$DEV/docs/SKILL.md" || { echo "owner string missing: $s"; false; }
done
check "W15a owner strings exist in the docs skill" ok $?
grep -qF 'Required capability unavailable: <capability>. Proposed install command (human approval required): <exact command>. Stopping — no fallback.' "$DEV/capability-preflight/SKILL.md"
check "W15b preflight refusal string exists at its owner" ok $?

# W16 · ownership preservation: delivery skills never enumerate the five-state
# contract, never use the classification term 'incompatible', and any provider
# readiness mention routes through capability-preflight.
! grep -rE 'ready / installed-but-disabled / missing / incompatible / optional-not-selected' \
  "$DEV/implement" "$DEV/pr" "$DEV/fix-bug" "$DEV/fix-production-error" "$DEV/ui-creation" "$DEV/simplify" "$DEV/scope-guard" 2>/dev/null | grep -q .
check "W16a no copied five-state enumeration in delivery skills" ok $?
for f in "$DEV/pr/references/automated-review.md" "$DEV/ui-creation/SKILL.md"; do
  grep -q 'capability-preflight' "$f" 2>/dev/null || { echo "no preflight routing in $f"; false; }
done
check "W16b provider readiness routes through capability-preflight" ok $?

# W17 · cross-reference integrity: every references/ path named in the seven
# SKILL.md files exists, and the owner skills referenced exist in the plugin.
node -e '
  const fs = require("fs"), path = require("path");
  const skills = ["implement","pr","fix-bug","fix-production-error","ui-creation","simplify","scope-guard"];
  for (const s of skills) {
    const dir = path.join("plugins/raftkit-dev/skills", s);
    const md = fs.readFileSync(path.join(dir, "SKILL.md"), "utf8");
    for (const m of md.matchAll(/`(references\/[\w./-]+\.md)`/g))
      if (!fs.existsSync(path.join(dir, m[1]))) { console.error(`${s}: dangling ${m[1]}`); process.exit(1); }
    for (const m of md.matchAll(/raftkit-dev:([\w-]+)/g))
      if (!fs.existsSync(path.join("plugins/raftkit-dev/skills", m[1]))) { console.error(`${s}: unknown owner raftkit-dev:${m[1]}`); process.exit(1); }
  }
'
check "W17 references and owner-skill ids resolve inside the plugin" ok $?

# W18 · eval bundle: authored, structural, no answer leakage.
n=$(find plugins/raftkit-dev/evals/workflow-integration -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[[ "${n:-0}" -ge 10 ]] \
  && ! find plugins/raftkit-dev/evals/workflow-integration -mindepth 1 -maxdepth 1 -type d '!' -exec test -f '{}/prompt.md' ';' -print | grep -q . \
  && ! find plugins/raftkit-dev/evals/workflow-integration -mindepth 1 -maxdepth 1 -type d '!' -exec sh -c 'ls "$1"/graders/*.md >/dev/null 2>&1' _ '{}' ';' -print | grep -q .
check "W18a >=10 eval cases each with prompt.md + graders" ok $?
! grep -l 'Docs: not impacted —' plugins/raftkit-dev/evals/workflow-integration/*/prompt.md 2>/dev/null | grep -q .
check "W18b prompts do not leak the expected no-impact copy" ok $?

# W19 · manifests: version + lockstep for Story C. Asserts the story's minimum
# introduced version (>= 0.14.0, numeric); the repository version gate owns the
# exact current version — per the program's shared-branch rule.
node -e '
  const v = JSON.parse(require("fs").readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json","utf8")).version.split(".").map(Number);
  const min = [0, 14, 0];
  const cmp = v[0] - min[0] || v[1] - min[1] || v[2] - min[2];
  process.exit(cmp >= 0 ? 0 : 1);
'
check "W19a raftkit-dev version is at least 0.14.0 (story C bump held)" ok $?
node -e '
  const fs = require("fs");
  const m = JSON.parse(fs.readFileSync(".claude-plugin/marketplace.json", "utf8"));
  const p = JSON.parse(fs.readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json", "utf8"));
  process.exit(m.plugins.find(x => x.name === "raftkit-dev").description === p.description ? 0 : 1);
'
check "W19b description lockstep holds" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
