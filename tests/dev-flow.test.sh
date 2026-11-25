#!/usr/bin/env bash
# Contracts of the raftkit-dev story and bug flow (implement, fix, scope-guard,
# docs) that another component, the platform, a script or a live template
# depends on: a string another component reads, a path two skills must agree
# on, a model a dispatch passes, an invocation a script answers. Never the
# wording of an instruction.
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

# DF1 · every dev-flow skill names the rules it loads
ok=0
for f in "$IMPL/SKILL.md" "$FIX/SKILL.md" "$SG/SKILL.md" "$DOCS/SKILL.md"; do
  grep -qF '`raftkit-core:rules`' "$f" || { echo "  does not name raftkit-core:rules: $f"; ok=1; }
done
check "DF1 implement, fix, scope-guard and docs name raftkit-core:rules" ok $ok

# DF2 · implement and fix stop on an undocumented squash target with one
#       identical line; the raise holds no second copy
stop_text="$(grep -m1 '^no documented squash target — ' "$IMPL/SKILL.md")"
[[ -n "$stop_text" ]] && grep -qF "$stop_text" "$FIX/SKILL.md" \
  && ! grep -qF 'no documented squash target' "$IMPL/references/pr.md"
check "DF2 implement and fix carry one identical undocumented-squash-target stop" ok $?

# DF3 · the plan record implement writes is the path scope-guard exempts
grep -qF '`docs/specs/<branch>.md`' "$IMPL/SKILL.md" && grep -qF '`docs/specs/<branch>.md`' "$SG/SKILL.md"
check "DF3 implement and scope-guard agree on the plan record path" ok $?

# DF4 · scope-guard reads out-of-scope where the live Feature Template puts it
grep -qF '`Do NOT build`' "$SG/SKILL.md"
check "DF4 scope-guard reads the out-of-scope list from the Do NOT build line" ok $?

# DF5 · every named agent dispatch in implement and fix passes a model. The
#       frontmatter of pr-review-toolkit's agents pins opus; only the
#       per-invocation model moves them. The one reviewer is named at sonnet.
ok=0
grep -qF '`pr-review-toolkit:code-reviewer` with `model: "sonnet"`' "$IMPL/references/review.md" || { echo "  the reviewer is not dispatched at sonnet"; ok=1; }
others="$(grep -rhoE 'pr-review-toolkit:[a-z-]+' "$IMPL" "$FIX" | grep -vx 'pr-review-toolkit:code-reviewer' | sort -u)"
[[ -z "$others" ]] || { echo "  more than one reviewer: $others"; ok=1; }
while IFS= read -r hit; do
  grep -qE 'model: "(haiku|sonnet|opus)"' <<<"$hit" || { echo "  dispatch without a model: $hit"; ok=1; }
done < <(grep -rnE 'pr-review-toolkit:[a-z-]+|raftkit-dev:verifier' "$IMPL" "$FIX" --include='*.md')
check "DF5 every agent dispatch in implement and fix passes a model" ok $ok

# DF6 · tiers.md maps each tier to an Agent model value a dispatch can pass
T=plugins/raftkit-core/skills/working-agreement/references/tiers.md
grep -qE '^\| `mechanical` \| `haiku` \|' "$T" \
  && grep -qE '^\| `standard` \| `sonnet` \|' "$T" \
  && grep -qE '^\| `hard` \| [^|]*`opus` under `opusplan`' "$T"
check "DF6 tiers.md names the model each tier dispatches with" ok $?

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

# DF11 · the review tail is one reviewer plus three scripts; the verifier agent
#        is gone and nothing names it
R=$IMPL/references/review.md
ok=0
[[ -e "$DEV/agents/verifier.md" ]] && { echo "  the verifier agent still exists"; ok=1; }
grep -rqF 'raftkit-dev:verifier' "$IMPL" "$FIX" "$SG" "$DOCS" && { echo "  a dev-flow skill still names the verifier"; ok=1; }
for s in verify.mjs scope-check.mjs validate-docs.mjs; do
  grep -qF "$s" "$R" || { echo "  the gate batch does not run $s"; ok=1; }
  grep -qF "$s" "$IMPL/SKILL.md" || { echo "  implement does not invoke $s"; ok=1; }
done
check "DF11 one reviewer and three scripts make the review tail; the verifier agent is gone" ok $ok

# DF15 · superpowers is no dependency and no dev-flow file names it
ok=0
node -e 'process.exit(require("./'"$DEV"'/.claude-plugin/plugin.json").dependencies.some((d) => (d.name || d) === "superpowers") ? 1 : 0)' \
  || { echo "  raftkit-dev still depends on superpowers"; ok=1; }
grep -rlF 'superpowers' "$IMPL" "$FIX" "$SG" "$DOCS" "$DEV/agents" 2>/dev/null | grep -q . && { echo "  a dev-flow file still names superpowers"; ok=1; }
check "DF15 raftkit-dev neither depends on nor names superpowers" ok $ok

# DF16 · the STOP summary line counts review findings
grep -qE 'findings: [0-9]+ fixed / [0-9]+ answered\.$' "$IMPL/SKILL.md"
check "DF16 the STOP line carries the review findings" ok $?

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

# DF18 · the FE/BE pair's subagents never share one checkout (cross-group C6):
#        each is dispatched with worktree isolation, which setup's
#        worktree.baseRef "head" branches from the run's HEAD
ok=0
grep -qF 'isolation: "worktree"' "$IMPL/references/pair.md" || { echo "  the pair is not dispatched with worktree isolation"; ok=1; }
grep -qF 'baseRef: "head"' "$DEV/skills/setup/scripts/merge-settings.mjs" || { echo "  setup no longer branches worktrees from HEAD"; ok=1; }
check "DF18 the pair runs in worktrees branched from HEAD" ok $ok

# DF19 · the review tail never fetches: it reads the range pinned at intake
! grep -q 'git fetch' "$IMPL/references/review.md"
check "DF19 the review tail does not fetch" ok $?

# DF21 · intake reads verify's `no typecheck script` (V16) as no gate, not red
grep -m1 '^1\. \*\*Intake' "$IMPL/SKILL.md" | grep -qF '`no typecheck script`'
check "DF21 implement's intake names verify's no-typecheck-script exit" ok $?

# DF22 · the plan record implement writes is the one scope-check.mjs parses:
#        the template's table header and hash comment are what the script
#        reads, and scope-guard runs the script on the injected base-sha
PLAN=$IMPL/references/plan.md
ok=0
grep -qxF '| # | [AC] | Test file | Source files |' "$PLAN" || { echo "  plan.md has no [AC] table header"; ok=1; }
grep -qF '`Done when`' "$PLAN" || { echo "  plan.md has no Done when table for fix"; ok=1; }
grep -qxF '<!-- plan-table sha256: <hash> -->' "$PLAN" || { echo "  plan.md has no hash comment"; ok=1; }
grep -qF 'plan-table sha256:' "$DEV/scripts/scope-check.mjs" || { echo "  scope-check reads no hash comment"; ok=1; }
grep -qF 'node ${CLAUDE_PLUGIN_ROOT}/scripts/scope-check.mjs --base <base-sha>' "$SG/SKILL.md" || { echo "  scope-guard does not pre-filter with scope-check"; ok=1; }
check "DF22 implement's plan record is the table scope-check parses, and scope-guard runs it" ok $ok

# DF23 · a story too large for one context refuses with a string the telemetry
#        registry knows; scope-check's ORDER reads `test:` and `fix:` commit
#        subjects, so implement and fix commit by them
ok=0
big="$(grep -m1 "^Can't build this in one run — " "$IMPL/SKILL.md")"
[[ -n "$big" ]] || { echo "  implement has no too-large refusal"; ok=1; }
node -e '
  const r = require("./plugins/raftkit-core/hooks/lib/refusals.json").refusals;
  const i = r.findIndex((x) => x.id === "story-too-large"), g = r.findIndex((x) => x.id === "generic-cant");
  process.exit(i >= 0 && i < g && new RegExp(r[i].pattern, "m").test(process.argv[1]) && r[i].source === "raftkit-dev/skills/implement/SKILL.md" ? 0 : 1);
' "$big" || { echo "  refusals.json does not register the too-large refusal ahead of generic-cant"; ok=1; }
grep -qF '`test: <the [AC]>`' "$IMPL/SKILL.md" || { echo "  implement does not commit tests as test: <the [AC]>"; ok=1; }
grep -qF '`fix:`' "$FIX/SKILL.md" || { echo "  fix does not commit the fix as fix:"; ok=1; }
check "DF23 too-large stories refuse; test and fix commits carry the subjects scope-check reads" ok $ok

# DF24 · fix builds in its own thread and runs implement's review tail
ok=0
grep -qiE 'subagent|isolation:' "$FIX/SKILL.md" && { echo "  fix still dispatches a subagent"; ok=1; }
for s in verify.mjs scope-check.mjs validate-docs.mjs; do
  grep -qF "$s" "$FIX/SKILL.md" || { echo "  fix does not run $s"; ok=1; }
done
grep -qF 'implement/references/review.md' "$FIX/SKILL.md" || { echo "  fix does not run implement's review tail"; ok=1; }
[[ -e "$FIX/references/loop.md" ]] && { echo "  fix still carries loop.md"; ok=1; }
check "DF24 fix dispatches nothing and runs implement's review tail" ok $ok

echo
echo "dev-flow: $failures failure(s)"
[[ "$failures" -eq 0 ]]
