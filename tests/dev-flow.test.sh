#!/usr/bin/env bash
# Contracts of the raftkit-dev story and bug flow (implement, fix, scope-guard,
# docs, the verifier agent) that another component, the platform, or a live
# template depends on. Each check pins an interface — a string another
# component reads, a path two skills must agree on, a model a dispatch passes —
# or the one clause that carries an acceptance criterion, never wording for its
# own sake. Mutation-checked when added.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

failures=0
check() { # <name> <expected: ok|fail> <actual exit code>
  local name="$1" expected="$2" actual="$3"
  if { [[ "$expected" == ok && "$actual" -eq 0 ]] || [[ "$expected" == fail && "$actual" -ne 0 ]]; }; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    failures=$((failures + 1))
  fi
}

DEV=plugins/raftkit-dev
IMPL=$DEV/skills/implement
FIX=$DEV/skills/fix
SG=$DEV/skills/scope-guard
DOCS=$DEV/skills/docs

# DF1 · every dev-flow skill loads the rules itself (cross-group sentence C4)
rules_line='Load `raftkit-core:rules` first unless it is already in this conversation.'
ok=0
for f in "$IMPL/SKILL.md" "$FIX/SKILL.md" "$SG/SKILL.md" "$DOCS/SKILL.md"; do
  grep -qF "$rules_line" "$f" || { echo "  missing the rules line: $f"; ok=1; }
  grep -qF '`raftkit-core:rules` apply' "$f" && { echo "  still says rules apply: $f"; ok=1; }
done
check "DF1 implement, fix, scope-guard and docs load raftkit-core:rules first" ok $ok

# DF2 · the squash target is settled in turn 1: implement's stop sits in intake,
#       before readiness; fix carries the same line ahead of its contract step
#       (fix never loads implement's intake); nothing points at a release-train
#       doc no repo carries, and the raise holds no second copy of the stop
stop_text="$(grep -m1 '^no documented squash target — ' "$IMPL/SKILL.md")"
stop_line="$(grep -n '^no documented squash target — ' "$IMPL/SKILL.md" | head -1 | cut -d: -f1)"
ready_line="$(grep -n '^2\. \*\*Check readiness' "$IMPL/SKILL.md" | head -1 | cut -d: -f1)"
fix_stop="$( [[ -n "$stop_text" ]] && grep -nF "$stop_text" "$FIX/SKILL.md" | head -1 | cut -d: -f1)"
contract_line="$(grep -n '^1\. \*\*Get the contract' "$FIX/SKILL.md" | head -1 | cut -d: -f1)"
[[ -n "$stop_line" && -n "$ready_line" && "$stop_line" -lt "$ready_line" ]] \
  && [[ -n "$fix_stop" && -n "$contract_line" && "$fix_stop" -lt "$contract_line" ]] \
  && ! grep -rqi 'release-train doc\|release-train convention' "$IMPL" \
  && ! grep -qF 'no documented squash target' "$IMPL/references/pr.md"
check "DF2 implement and fix stop on an undocumented squash target in turn 1, not at the raise" ok $?

# DF3 · the plan record implement writes is exempt in scope-guard (same path)
plan_path="$(grep -o 'Write the plan to `[^`]*`' "$IMPL/SKILL.md" | head -1 | sed 's/.*`\(.*\)`/\1/')"
[[ -n "$plan_path" ]] && grep -F "\`$plan_path\`" "$SG/SKILL.md" | grep -qF 'always in scope'
check "DF3 scope-guard never flags implement's plan record (${plan_path:-no path found})" ok $?

# DF4 · scope-guard reads out-of-scope where the live Feature Template puts it
grep -qF '`Do NOT build`' "$SG/SKILL.md"
check "DF4 scope-guard reads the out-of-scope list from the Do NOT build line" ok $?

# DF5 · every named agent dispatch in implement and fix passes a model. The
#       frontmatter of pr-review-toolkit's agents pins opus; only the
#       per-invocation model moves them. The five review agents must be named,
#       so the check cannot pass on a file that dispatches nothing. The phase
#       and fix-loop subagents dispatch at their tier's model (tiers.md).
ok=0
for a in code-simplifier code-reviewer type-design-analyzer silent-failure-hunter pr-test-analyzer; do
  grep -rqF "pr-review-toolkit:$a" "$IMPL" || { echo "  review agent not dispatched: $a"; ok=1; }
done
while IFS= read -r hit; do
  grep -qE 'model: "(haiku|sonnet|opus)"' <<<"$hit" || { echo "  dispatch without a model: $hit"; ok=1; }
done < <(grep -rnE 'pr-review-toolkit:[a-z-]+|raftkit-dev:verifier' "$IMPL" "$FIX" --include='*.md')
grep -qF "each a subagent at its tier's model" "$IMPL/SKILL.md" || { echo "  implement's phase dispatch names no tier"; ok=1; }
grep -qF "one subagent at the defect's tier" "$FIX/SKILL.md" || { echo "  fix's loop dispatch names no tier"; ok=1; }
check "DF5 every agent dispatch in implement and fix passes a model or its tier's" ok $ok

# DF6 · tiers.md maps each tier to an Agent model value a dispatch can pass
T=plugins/raftkit-core/skills/working-agreement/references/tiers.md
grep -qE '^\| `mechanical` \| `haiku` \|' "$T" \
  && grep -qE '^\| `standard` \| `sonnet` \|' "$T" \
  && grep -qE '^\| `hard` \| [^|]*`opus` under `opusplan`' "$T"
check "DF6 tiers.md names the model each tier dispatches with" ok $?

# DF7 · fix records a pending build, never one no build contains yet; retest
#       in raftkit-qa reads this exact string as empty (cross-group C3). The
#       pin is on the edit instruction: the go-report repeats the string
grep -qF 'the edit writing `Fixed in build: pending — first build containing PR #<n>`' "$FIX/SKILL.md" \
  && ! grep -qE 'Fixed in build <x>' "$FIX/SKILL.md"
check "DF7 fix writes Fixed in build: pending with the PR number" ok $?

# DF8 · the go-report (the last output block) of implement and fix ends by
#       telling the developer to clear the chat before the next story
last_output_line() { awk '/^```output$/{inb=1; last=""; next} inb&&/^```$/{inb=0; final=last; next} inb{last=$0} END{print final}' "$1"; }
ok=0
for f in "$IMPL/SKILL.md" "$FIX/SKILL.md"; do
  [[ "$(last_output_line "$f")" == "Next story: /clear first." ]] || { echo "  go-report does not end with the /clear line: $f"; ok=1; }
done
check "DF8 implement and fix go-reports end with Next story: /clear first." ok $ok

# DF9 · the STOP quotes the measured token line (cross-group C1). Claude Code
#       substitutes ${CLAUDE_PLUGIN_ROOT} and ${CLAUDE_SESSION_ID} in skill and
#       agent content only, so the invocation lives in SKILL.md, and no
#       reference file (read later with the Read tool) carries a placeholder.
ok=0
for f in "$IMPL/SKILL.md" "$FIX/SKILL.md"; do
  grep -qF 'node ${CLAUDE_PLUGIN_ROOT}/scripts/run-tokens.mjs ${CLAUDE_SESSION_ID}' "$f" \
    && grep -qF '`Token total: not measured`' "$f" || { echo "  no measured token line: $f"; ok=1; }
done
refs="$(grep -rlF '${CLAUDE_' "$IMPL/references" "$FIX/references" "$SG" "$DOCS/references" 2>/dev/null | grep -v '/SKILL.md$')"
[[ -z "$refs" ]] || { echo "  placeholder in a reference file: $refs"; ok=1; }
check "DF9 implement and fix quote run-tokens.mjs at the STOP" ok $ok

# DF10 · gate runs go through verify.mjs (cross-group C2): SKILL.md carries the
#        substituted invocation, and every --only names a gate it accepts
ok=0
for f in "$IMPL/SKILL.md" "$FIX/SKILL.md"; do
  grep -qF 'node ${CLAUDE_PLUGIN_ROOT}/scripts/verify.mjs' "$f" || { echo "  gates not run through verify.mjs: $f"; ok=1; }
done
bad="$(grep -rhoE 'verify\.mjs --only [a-z]+' "$IMPL" "$FIX" "$DEV/agents" 2>/dev/null | grep -vE -- '--only (test|lint|typecheck)$')"
[[ -z "$bad" ]] || { echo "  unknown gate: $bad"; ok=1; }
check "DF10 implement and fix run their gates through verify.mjs" ok $ok

# DF11 · the review tail runs in raftkit-dev:verifier, a Sonnet agent that can
#        run checks (Bash) but holds no tool that writes a file or dispatches
V=$DEV/agents/verifier.md
vfm() { awk 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} NR>1{print}' "$V"; }
ok=0
[[ -f "$V" ]] || { echo "  missing $V"; ok=1; }
if [[ -f "$V" ]]; then
  [[ "$(vfm | sed -n 's/^name: *//p')" == verifier ]] || { echo "  name is not verifier"; ok=1; }
  [[ "$(vfm | sed -n 's/^model: *//p')" == sonnet ]] || { echo "  model is not sonnet"; ok=1; }
  tools="$(vfm | sed -n 's/^tools: *//p')"
  grep -q '"Bash"' <<<"$tools" || { echo "  no Bash in tools"; ok=1; }
  grep -qE '"(Write|Edit|MultiEdit|NotebookEdit|Agent|Task)"' <<<"$tools" && { echo "  a write or dispatch tool in: $tools"; ok=1; }
fi
grep -qF '`raftkit-dev:verifier`' "$IMPL/references/review.md" || { echo "  review.md does not dispatch the verifier"; ok=1; }
check "DF11 the verifier agent is Sonnet, read-and-run only, and dispatched by review.md" ok $ok

# DF12 · the plan record has one writer. Parallel phases committing the same
#        file race on the index or conflict on merge-back, and a third file
#        breaks working-agreement rule 2, so no phase edits it; the parent
#        marks phases done (resume after /clear reads it) and commits it once,
#        with the last phase, so the review pass runs on a committed record
ok=0
grep -qF 'only the parent marks phases done in the record, and commits it with the last phase' "$IMPL/SKILL.md" \
  || { echo "  the parent is not the record's only writer"; ok=1; }
grep -qF 'marking it done in the record' "$IMPL/SKILL.md" && { echo "  a phase still marks the record"; ok=1; }
check "DF12 only the parent writes implement's plan record" ok $ok

# DF13 · a run started in plan mode writes nothing, and is told so before
#        intake's fetch, baseline build and verify cache, which all write
pm_line="$(grep -n '^In plan mode: read only (no fetch, build or verify)' "$IMPL/SKILL.md" | head -1 | cut -d: -f1)"
intake_line="$(grep -n '^1\. \*\*Intake' "$IMPL/SKILL.md" | head -1 | cut -d: -f1)"
[[ -n "$pm_line" && -n "$intake_line" && "$pm_line" -lt "$intake_line" ]]
check "DF13 plan mode reads only, stated before implement's intake" ok $?

# DF14 · every phase prompt carries the base SHA and checks it before editing
#        (cross-group C6: setup's worktree.baseRef only helps if the phase checks)
grep -qF 'the branch SHA, which it confirms with `git merge-base --is-ancestor <sha> HEAD` before its first edit' "$IMPL/SKILL.md" \
  && grep -qF 'the branch SHA to confirm before its first edit' "$FIX/SKILL.md"
check "DF14 implement and fix phase prompts carry and check the branch SHA" ok $?

# DF15 · the plan is written inline: no planning skill and no Plan subagent
grep -qF 'never through `superpowers:brainstorming`, `superpowers:writing-plans` or a `Plan` subagent' "$IMPL/SKILL.md"
check "DF15 implement never plans through brainstorming, writing-plans or a Plan subagent" ok $?

# DF16 · the PR body carries the review findings and [AC] test coverage, and
#        the STOP summary line counts findings the same way
grep -qE '^[0-9]+\. \*\*Review findings\*\*' "$IMPL/references/pr.md" \
  && grep -qF '`[AC]s with tests n/m`' "$IMPL/references/pr.md" \
  && grep -qE 'findings: [0-9]+ fixed / [0-9]+ answered\.$' "$IMPL/SKILL.md"
check "DF16 the PR body and the STOP line carry the review findings" ok $?

# DF17 · fix writes and qa's retest reads one string (cross-group C3). retest
#        treats the pending value as no build; if either side rewords it,
#        retest tests a build that does not exist yet
c3='Fixed in build: pending — first build containing PR #<n>'
BUG=plugins/raftkit-qa/skills/bug/SKILL.md
fix_c3="$(grep -oE 'the edit writing `Fixed in build: pending[^`]*`' "$FIX/SKILL.md" | head -1 | sed -E 's/^the edit writing `(.*)`$/\1/')"
bug_c3="$(grep -oE '`Fixed in build: pending[^`]*` counts as empty' "$BUG" | head -1 | sed -E 's/^`(.*)` counts as empty$/\1/')"
[[ "$fix_c3" == "$c3" && "$bug_c3" == "$c3" ]] \
  || echo "  fix writes '${fix_c3:-nothing}', retest reads '${bug_c3:-nothing}' as empty"
[[ "$fix_c3" == "$c3" && "$bug_c3" == "$c3" ]]
check "DF17 fix and qa retest carry the identical pending-build string" ok $?

# DF18 · parallel phases never share one checkout (cross-group C6): each runs in
#        its own worktree, which setup's worktree.baseRef "head" branches from
#        the run's HEAD, and the parent lands each phase's one commit on the
#        branch. In one checkout, parallel commits race on index.lock and carry
#        each other's files.
ok=0
build="$(grep -m1 '^4\. \*\*Build' "$IMPL/SKILL.md")"
grep -qF 'isolation: "worktree"' <<<"$build" || { echo "  implement's phases are not dispatched with worktree isolation"; ok=1; }
grep -qF 'the parent cherry-picks' <<<"$build" || { echo "  no step lands a phase's worktree commit on the branch"; ok=1; }
grep -qF 'baseRef: "head"' "$DEV/skills/setup/scripts/merge-settings.mjs" || { echo "  setup no longer branches worktrees from HEAD"; ok=1; }
check "DF18 implement runs each phase in a worktree and cherry-picks its commit onto the branch" ok $ok

# DF19 · the review range is pinned once, by the parent. The simplifier, four
#        reviewers and the verifier start together; a range that fetches makes
#        them race on refs/remotes/origin/<target> once the target has moved,
#        and a failed fetch reads as a scope block or a failed reviewer.
ok=0
R=$IMPL/references/review.md
range="$(awk '/^## Anchoring/{a=1} a&&/^```/{n++; next} a&&n==1' "$R")"
grep -qF 'git diff <base-sha> HEAD' <<<"$range" || { echo "  reviewers are not briefed with the pinned range"; ok=1; }
grep -q 'fetch' <<<"$range" && { echo "  the range reviewers run still fetches"; ok=1; }
grep -qF 'The parent runs `git fetch origin <squash-target>` once' "$R" || { echo "  nobody fetches the target before the range is pinned"; ok=1; }
check "DF19 the parent fetches once and every reviewer gets a range that does not fetch" ok $ok

echo
echo "dev-flow: $failures failure(s)"
[[ "$failures" -eq 0 ]]
