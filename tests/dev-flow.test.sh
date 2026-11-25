#!/usr/bin/env bash
# Contracts of the raftkit-dev story and bug flow (implement, fix, scope-guard,
# docs) that another component, the platform, or a live
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
#       per-invocation model moves them. The one reviewer must be named, so
#       the check cannot pass on a file that dispatches nothing, and no other
#       toolkit agent is. The phase and fix-loop subagents dispatch at their
#       tier's model (tiers.md).
ok=0
grep -qF '`pr-review-toolkit:code-reviewer` with `model: "sonnet"`' "$IMPL/references/review.md" || { echo "  the reviewer is not dispatched at sonnet"; ok=1; }
others="$(grep -rhoE 'pr-review-toolkit:[a-z-]+' "$IMPL" "$FIX" | grep -vx 'pr-review-toolkit:code-reviewer' | sort -u)"
[[ -z "$others" ]] || { echo "  more than one reviewer: $others"; ok=1; }
while IFS= read -r hit; do
  grep -qE 'model: "(haiku|sonnet|opus)"' <<<"$hit" || { echo "  dispatch without a model: $hit"; ok=1; }
done < <(grep -rnE 'pr-review-toolkit:[a-z-]+|raftkit-dev:verifier' "$IMPL" "$FIX" --include='*.md')
grep -qF "two subagents at their tier's model" "$IMPL/SKILL.md" || { echo "  implement's pair dispatch names no tier"; ok=1; }
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

# DF11 · the review tail is one reviewer plus scripts, no wrapper agent: the
#        reviewer's brief carries the [AC]s, the Do NOT build line and the plan
#        table and returns scope-guard's block; the gate batch runs the three
#        scripts beside it; BEYOND clears only by a named human
R=$IMPL/references/review.md
ok=0
[[ -e "$DEV/agents/verifier.md" ]] && { echo "  the verifier agent still exists"; ok=1; }
grep -rqF 'raftkit-dev:verifier' "$IMPL" "$FIX" "$SG" "$DOCS" && { echo "  a dev-flow skill still names the verifier"; ok=1; }
grep -qF 'the `[AC]`s verbatim, the `Do NOT build:` line, the plan table' "$R" || { echo "  the reviewer brief lacks the [AC]s, Do NOT build or plan table"; ok=1; }
grep -qF "It returns scope-guard's output block exactly." "$R" || { echo "  the reviewer does not return scope-guard's block"; ok=1; }
for s in verify.mjs scope-check.mjs validate-docs.mjs; do
  grep -qF "**\`$s\`**" "$R" || { echo "  the gate batch does not run $s"; ok=1; }
  grep -qF "$s" "$IMPL/SKILL.md" || { echo "  implement does not invoke $s"; ok=1; }
done
grep -qF 'signed off by a named human' "$R" || { echo "  BEYOND clears without a named human"; ok=1; }
check "DF11 one reviewer and three scripts make the review tail; the verifier agent is gone" ok $ok

# DF12 · the plan record has one writer and is committed alone before the
#        first test: scope-check takes the table as first committed for the
#        plan, so a record committed later, or by a pair subagent, would hide
#        rows added mid-build. Progress lives in git, never in the table.
ok=0
grep -qF 'commit the record alone and show it without waiting' "$IMPL/SKILL.md" || { echo "  implement does not commit the record alone"; ok=1; }
grep -qF 'Commit the record alone, before the first test.' "$IMPL/references/plan.md" || { echo "  plan.md does not commit the record before the first test"; ok=1; }
grep -qF 'never edits the plan record' "$IMPL/SKILL.md" || { echo "  a pair subagent may edit the record"; ok=1; }
grep -qF 'Progress lives in git, not in the table' "$IMPL/references/plan.md" || { echo "  progress is written into the hashed table"; ok=1; }
check "DF12 implement's plan record is committed alone, first, and only the main thread writes it" ok $ok

# DF13 · a run started in plan mode writes nothing, and is told so before
#        intake's git fetch, branch, baseline build and verify cache, which all
#        write. It names git fetch: a bare "fetch" reads as the story fetch,
#        which plan mode still needs
pm_line="$(grep -n '^In plan mode: read only (no `git fetch`, branch, build or verify)' "$IMPL/SKILL.md" | head -1 | cut -d: -f1)"
intake_line="$(grep -n '^1\. \*\*Intake' "$IMPL/SKILL.md" | head -1 | cut -d: -f1)"
[[ -n "$pm_line" && -n "$intake_line" && "$pm_line" -lt "$intake_line" ]]
check "DF13 plan mode reads only, stated before implement's intake" ok $?

# DF14 · every phase prompt carries the base SHA and checks it before editing
#        (cross-group C6: setup's worktree.baseRef only helps if the phase checks)
grep -qF 'the branch SHA, which it confirms with `git merge-base --is-ancestor <sha> HEAD` before its first edit' "$IMPL/SKILL.md" \
  && grep -qF 'the branch SHA to confirm before its first edit' "$FIX/SKILL.md"
check "DF14 implement and fix phase prompts carry and check the branch SHA" ok $?

# DF15 · the plan is written inline: no planning skill and no Plan subagent;
#        superpowers is no dependency and no dev skill loads it, so the TDD
#        and debugging methods are carried inline where they are used
ok=0
grep -qF 'never through a planning skill or a `Plan` subagent' "$IMPL/SKILL.md" || { echo "  implement may plan through a skill or subagent"; ok=1; }
node -e 'process.exit(require("./'"$DEV"'/.claude-plugin/plugin.json").dependencies.some((d) => (d.name || d) === "superpowers") ? 1 : 0)' \
  || { echo "  raftkit-dev still depends on superpowers"; ok=1; }
grep -rlF 'superpowers' "$IMPL" "$FIX" "$SG" "$DOCS" "$DEV/agents" 2>/dev/null | grep -q . && { echo "  a dev-flow file still names superpowers"; ok=1; }
grep -qF 'It must fail for the reason the `[AC]` names' "$IMPL/SKILL.md" || { echo "  implement carries no red-first method"; ok=1; }
grep -qF 'Three strikes on the same error stops and reports' "$FIX/SKILL.md" || { echo "  fix carries no debugging method"; ok=1; }
check "DF15 implement plans inline, and implement and fix carry their own TDD and debugging method" ok $ok

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

# DF18 · the build is the main thread's; the FE/BE pair is the only parallel
#        path, and its subagents never share one checkout (cross-group C6):
#        each runs in its own worktree, which setup's worktree.baseRef "head"
#        branches from the run's HEAD, bootstraps its dependencies, and the
#        parent lands its commits on the branch. In one checkout, parallel
#        commits race on index.lock and carry each other's files.
ok=0
grep -m1 '^4\. \*\*Build' "$IMPL/SKILL.md" | grep -qF 'Build in the main thread, one `[AC]` at a time' || { echo "  implement does not build in the main thread by [AC]"; ok=1; }
pair="$(grep -m1 '^   \*\*Pair path\*\*' "$IMPL/SKILL.md")"
grep -qF 'only when the plan marks the FE and BE halves independent behind a frozen contract' <<<"$pair" || { echo "  the pair path is not limited to independent halves"; ok=1; }
grep -qF 'isolation: "worktree"' <<<"$pair" || { echo "  the pair is not dispatched with worktree isolation"; ok=1; }
grep -qF 'bootstraps with the repo'"'"'s detected package manager' <<<"$pair" || { echo "  a pair worktree starts without its dependencies"; ok=1; }
grep -qF 'the parent cherry-picks' <<<"$pair" || { echo "  no step lands the pair's worktree commits on the branch"; ok=1; }
grep -qF 'baseRef: "head"' "$DEV/skills/setup/scripts/merge-settings.mjs" || { echo "  setup no longer branches worktrees from HEAD"; ok=1; }
check "DF18 implement builds in the main thread; only the FE/BE pair runs in worktrees and is cherry-picked" ok $ok

# DF19 · the review range is pinned once, at intake. The reviewer and the
#        scripts start together; a range that fetches makes them race on
#        refs/remotes/origin/<target> once the target has moved, and a failed
#        fetch reads as a scope block or a failed reviewer.
ok=0
R=$IMPL/references/review.md
grep -qF 'Every check reads `git diff <base-sha> HEAD`, the base pinned at intake; nothing fetches again.' "$R" || { echo "  checks are not given the pinned range"; ok=1; }
grep -q 'git fetch' "$R" && { echo "  the review tail still fetches"; ok=1; }
check "DF19 every check in the review tail reads the range pinned at intake" ok $ok

# DF20 · fix keeps separate repro and fix commits (1.11). Steps 2 and 3 run in
#        a subagent handed only those steps verbatim, so the rule has to live in
#        step 3 itself; references/loop.md never reaches it.
grep -m1 '^3\. \*\*Smallest fix to green' "$FIX/SKILL.md" | grep -qF 'the fix is a separate `fix:` commit'
check "DF20 fix's step 3 commits the repro test alone and the fix as a separate fix: commit" ok $?

# DF21 · intake reads verify's exit 2 for a repo with no typecheck script (a
#        default Next.js app has none) as no gate, not a red baseline; V16 pins
#        the string on verify's side
grep -m1 '^1\. \*\*Intake' "$IMPL/SKILL.md" | grep -qF '(`no typecheck script` is not red)'
check "DF21 implement's intake does not stop on a repo with no typecheck script" ok $?

# DF22 · the plan record implement writes is the one scope-check.mjs parses:
#        the template's table header and hash comment are what the script
#        reads, and scope-guard runs the script on the injected base-sha
PLAN=$IMPL/references/plan.md
ok=0
grep -qxF '| # | [AC] | Test file | Source files |' "$PLAN" || { echo "  plan.md has no [AC] table header"; ok=1; }
grep -qxF '<!-- plan-table sha256: <hash> -->' "$PLAN" || { echo "  plan.md has no hash comment"; ok=1; }
grep -qF 'plan-table sha256:' "$DEV/scripts/scope-check.mjs" || { echo "  scope-check reads no hash comment"; ok=1; }
grep -qF 'node ${CLAUDE_PLUGIN_ROOT}/scripts/scope-check.mjs --base <base-sha>' "$SG/SKILL.md" || { echo "  scope-guard does not pre-filter with scope-check"; ok=1; }
grep -qF 'With an injected base-sha, the diff is `git diff <base-sha> HEAD`; never fetch.' "$SG/SKILL.md" || { echo "  scope-guard fetches despite an injected base-sha"; ok=1; }
check "DF22 implement's plan record is the table scope-check parses, and scope-guard runs it" ok $ok

# DF23 · the lines a long main-thread build must not lose sit in the first
#        lines of implement, where compaction keeps them; a story too large
#        for one context refuses with a string the telemetry registry knows;
#        each [AC]'s test is committed alone before its code
ok=0
head12="$(awk 'NR>1&&/^---$/{f=1; next} f' "$IMPL/SKILL.md" | head -12)"
for want in '**One stop**' 'Never merge; never tick `[AC]` or `Testing`.' '`Do NOT build:`' '**Red first**'; do
  grep -qF "$want" <<<"$head12" || { echo "  not in implement's first lines: $want"; ok=1; }
done
big="$(grep -m1 "^Can't build this in one run — " "$IMPL/SKILL.md")"
[[ -n "$big" ]] || { echo "  implement has no too-large refusal"; ok=1; }
node -e '
  const r = require("./plugins/raftkit-core/hooks/lib/refusals.json").refusals;
  const i = r.findIndex((x) => x.id === "story-too-large"), g = r.findIndex((x) => x.id === "generic-cant");
  process.exit(i >= 0 && i < g && new RegExp(r[i].pattern, "m").test(process.argv[1]) && r[i].source === "raftkit-dev/skills/implement/SKILL.md" ? 0 : 1);
' "$big" || { echo "  refusals.json does not register the too-large refusal ahead of generic-cant"; ok=1; }
grep -qF 'Commit it alone: `test: <the [AC]>`.' "$IMPL/SKILL.md" || { echo "  the failing test is not committed alone"; ok=1; }
check "DF23 implement's first lines hold the stop, merge and scope rules; too-large stories refuse; tests commit first" ok $ok

echo
echo "dev-flow: $failures failure(s)"
[[ "$failures" -eq 0 ]]
