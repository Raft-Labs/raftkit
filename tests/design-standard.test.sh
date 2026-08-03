#!/usr/bin/env bash
# Contract suite for the RaftLabs Module Design Standard (raftkit board — S4
# of the design-quality-enforcement programme). Placement-aware: seams must
# appear in their owning section, not merely somewhere in a file.
#
# Before this story: zero repo-wide mentions of SOLID, single responsibility,
# open/closed, Liskov, interface segregation, dependency inversion, design
# pattern, coupling, or cohesion. The only named pattern in the repo listed
# factory/interface/wrapper/strategy as things to DELETE
# (simplify/references/candidate-catalog.md). This suite pins a ten-rule
# standard installed into every client CLAUDE.md — where pr-review-toolkit's
# code-reviewer scores an explicit violation at its top confidence tier — plus
# a post-edit design-review layer in /implement, and the drafting choices that
# keep it from fighting simplify's minimalism mandate.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

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

CORE=plugins/raftkit-core/skills
DEV=plugins/raftkit-dev/skills
sec() { sed -n "/$2/,/$3/p" "$1" 2>/dev/null; }

STD="$CORE/design-standard/references/standard.md"
DSKILL="$CORE/design-standard/SKILL.md"

[[ -f "$STD" ]] || { echo "FATAL: $STD not found"; exit 2; }

# --- STD: the payload is injectable and complete ---

[[ "$(head -1 "$STD")" != "---" ]]
check "STD1a payload has no frontmatter (injected verbatim)" ok $?
! grep -q '<body>' "$STD"
check "STD1b payload has no Asana HTML wrapper" ok $?

all_present=0
for n in 1 2 3 4 5 6 7 8 9 10; do
  grep -qE "^### MDS-$n — " "$STD" || all_present=1
done
[[ "$all_present" -eq 0 ]]
check "STD2 all ten MDS rule headings present" ok $?

trig_fix_ok=0
for n in 1 2 3 4 5 6 7 8 9; do
  rule=$(sec "$STD" "^### MDS-$n — " "^### MDS-$((n + 1)) — ")
  grep -q '\*\*Trigger:\*\*' <<<"$rule" && grep -q '\*\*Fix:\*\*' <<<"$rule" || trig_fix_ok=1
done
rule10=$(sec "$STD" '^### MDS-10 — ' '^### Precedence')
grep -q '\*\*Trigger:\*\*' <<<"$rule10" && grep -q '\*\*Fix:\*\*' <<<"$rule10" || trig_fix_ok=1
[[ "$trig_fix_ok" -eq 0 ]]
check "STD3 every rule has both a Trigger and a Fix (decidable from a diff)" ok $?

head -8 "$STD" | grep -qi 'explicit CLAUDE.md violation'
check "STD4 the standard states it is enforced as an explicit CLAUDE.md violation" ok $?

grep -q 'Server Component' "$STD" && grep -q 'Route Handler' "$STD" \
  && grep -qi 'Lambda' "$STD" && grep -q 'useEffect' "$STD" && grep -q '@aws-sdk' "$STD"
check "STD5 the standard is stack-specific (Server Component, Route Handler, Lambda, useEffect, @aws-sdk)" ok $?

m6=$(sec "$STD" '^### MDS-6 — ' '^### MDS-7 — ')
grep -qi 'three or more branches' <<<"$m6" && grep -qi 'two or more files' <<<"$m6" \
  && grep -qi 'below that threshold' <<<"$m6"
check "STD6 MDS-6 gates OCP behind a plural threshold, strictly above simplify's line" ok $?

m7_flat=$(sec "$STD" '^### MDS-7 — ' '^### MDS-8 — ' | tr '\n' ' ' | tr -s ' ')
grep -qi 'function-typed parameter' <<<"$m7_flat" && grep -qi 'composition root' <<<"$m7_flat" \
  && grep -qiE "never introduce an .interface., .abstract class., factory" <<<"$m7_flat" \
  && grep -qi 'does not defend it' <<<"$m7_flat"
check "STD7 MDS-7 asks for a parameter, never an interface, and disclaims defending one" ok $?

m10=$(sec "$STD" '^### MDS-10 — ' '^### Precedence')
grep -qi 'third' <<<"$m10" && grep -qi 'duplicate rather than couple' <<<"$m10"
check "STD8 MDS-10 extracts on the third occurrence, strictly above simplify's line" ok $?

prec=$(sed -n '/^### Precedence/,$p' "$STD")
grep -qi 'simplify wins' <<<"$prec"
check "STD9a Precedence: simplify wins by default" ok $?
grep -qi 'name the rule and its met trigger' <<<"$prec"
check "STD9b Precedence: the burden of proof is on the abstraction" ok $?
grep -qi 'no test, no seam' <<<"$prec"
check "STD9c Precedence: the sole exception is test-gated" ok $?
grep -qi 'simplify runs first' <<<"$prec" && grep -qi 'post-simplify diff' <<<"$prec"
check "STD9d Precedence: the fixed order is stated (simplify first, review on the result)" ok $?

# --- DSKILL: meta only, no rule text duplicated ---

[[ -f "$DSKILL" ]] || { echo "FATAL: $DSKILL not found"; exit 2; }
grep -q 'user-invocable: false' "$DSKILL"
check "DSKILL1a design-standard/SKILL.md is not user-invocable (consulted, not called)" ok $?
! grep -qE '^### MDS-[0-9]' "$DSKILL"
check "DSKILL1b design-standard/SKILL.md carries no MDS rule text — meta only" ok $?
grep -qi 'RaftKit-authored\|not.*Ashit\|not subject to' "$DSKILL"
check "DSKILL2 provenance is stated — house content, not Ashit's frozen protocol pack" ok $?

# --- DRIFT: single source of truth — zero copies anywhere in raftkit-dev ---

! grep -rqE '^### MDS-[0-9]' plugins/raftkit-dev/ 2>/dev/null
check "DRIFT1 no MDS rule text anywhere in raftkit-dev (setup-project installs standard.md's content, never a pasted copy)" ok $?

tmpl="$DEV/docs/assets/templates/claude-md.md"
grep -qi 'Module Design Standard' "$tmpl" && grep -qi 'setup-project' "$tmpl"
check "DOCS1 the client-scaffold CLAUDE.md template carries a pointer to the standard" ok $?

# --- SETUP: setup-project installs it as governance-pack component 6 ---

CM="$DEV/setup-project/references/components.md"
ct=$(sec "$CM" '^## Component table' '^## Parameters')
grep -q 'raftkit-core/design-standard' <<<"$ct" && grep -q 'references/standard.md' <<<"$ct" \
  && grep -qi '(live)' <<<"$ct" && grep -q 'CLAUDE.md' <<<"$ct"
check "SETUP1 components.md's table has a live-sourced design-standard row installing to CLAUDE.md" ok $?

# Not "these six" specifically — the pack legitimately grows components over
# time (S5 adds a seventh), so this pins the design standard's presence in
# whichever count sentence is current, not the exact numeral word.
grep -qi 'design standard' "$CM"
check "SETUP2 the success-string sentence names the design standard" ok $?

mk=$(sed -n '/^## The version marker/,$p' "$CM")
grep -q '"design-standard"' <<<"$mk"
check "SETUP3 the version marker's components array includes design-standard" ok $?

IF="$DEV/setup-project/references/install-flow.md"
ph2_flat=$(sec "$IF" '^## Phase 2' '^## Phase 3' | tr '\n' ' ' | tr -s ' ')
grep -qi 'components 1 and 6' <<<"$ph2_flat" && grep -qi 'Module Design Standard' <<<"$ph2_flat"
check "SETUP4 Phase 2 merges both CLAUDE.md components (protocols + MDS)" ok $?

ph4=$(sec "$IF" '^## Phase 4' '^## Baseline capabilities')
grep -qi 'design standard' <<<"$ph4"
check "SETUP5 Phase 4's success string names the design standard" ok $?
grep -qi 'MDS\|Module Design Standard' <<<"$ph4"
check "SETUP6 Phase 4 verifies the MDS block is agent-readable, not just the protocol block" ok $?

rerun=$(sed -n '/^## Re-run = update/,$p' "$IF")
grep -qi 'Module Design Standard' <<<"$rerun"
check "SETUP7 the re-run section names the MDS block alongside the protocol block" ok $?

SPSKILL="$DEV/setup-project/SKILL.md"
grep -qi 'Module Design Standard' "$SPSKILL"
check "SETUP8a setup-project/SKILL.md's frontmatter names the Module Design Standard" ok $?
n_mentions=$(grep -ci 'Module Design Standard' "$SPSKILL")
[[ "$n_mentions" -ge 4 ]]
check "SETUP8b Module Design Standard is named across multiple sections, not just once" ok $?

# --- IMPL: the post-edit design-review layer ---

EXEC="$DEV/implement/references/execution.md"
pe=$(sed -n '/^## Post-edit gates/,$p' "$EXEC")
grep -qE '^1\. \*\*.raftkit-dev/simplify' <<<"$pe"
check "IMPL1a post-edit item 1 is still simplify" ok $?
grep -qE '^2\. \*\*Design review' <<<"$pe"
check "IMPL1b post-edit item 2 is the new design review" ok $?
grep -qE '^3\. \*\*Security' <<<"$pe"
check "IMPL1c security is renumbered to item 3" ok $?
grep -qE '^4\. \*\*Lint' <<<"$pe"
check "IMPL1d lint + suite is renumbered to item 4" ok $?

grep -q 'pr-review-toolkit:code-reviewer' <<<"$pe" && grep -q 'type-design-analyzer' <<<"$pe"
check "IMPL2a design review dispatches code-reviewer and type-design-analyzer by scoped name" ok $?
grep -qi 'post-simplify' <<<"$pe" && grep -qi 'merge-base' <<<"$pe"
check "IMPL2b design review runs on the post-simplify diff at the merge-base anchor, never the empty default" ok $?
grep -q 'raftkit-core/design-standard' <<<"$pe"
check "IMPL2c design review names the standard it scores against" ok $?
grep -qi 'Design Approach' <<<"$pe"
check "IMPL2d design review also confirms conformance to the approved Design Approach" ok $?
grep -qi 'addressed or explicitly answered' <<<"$pe"
check "IMPL2e findings reuse pr's existing address-or-explicitly-answer gate — no new grading vocabulary" ok $?

ISKILL="$DEV/implement/SKILL.md"
grep -qi 'design review' "$ISKILL" && grep -qi 'Module Design Standard\|design-standard' "$ISKILL"
check "IMPL3 implement/SKILL.md's summaries name the design review layer" ok $?

# --- OWNER: the delegation chain finally terminates ---

cat_file="$DEV/simplify/references/candidate-catalog.md"
grep -q 'MDS-7' "$cat_file" && grep -qi 'list-only' "$cat_file" && grep -qi 'no test, no seam' "$cat_file"
check "OWNER1 candidate-catalog.md carries the MDS-7 test-gated, list-only counter-clause" ok $?

grep -q 'raftkit-core/design-standard' "$DEV/scope-guard/SKILL.md"
check "OWNER2 scope-guard/SKILL.md names raftkit-core/design-standard as the real owner" ok $?
grep -q 'raftkit-core/design-standard' "$DEV/pr/SKILL.md"
check "OWNER3 pr/SKILL.md names raftkit-core/design-standard as the real owner" ok $?

# --- HELP: the new core skill is discoverable ---

grep -qi 'design-standard' plugins/raftkit-core/commands/help.md
check "HELP1 raftkit-core's help command lists the design-standard skill" ok $?

# --- eval bundle ---

n=$(find plugins/raftkit-dev/evals/design-standard -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[[ "${n:-0}" -ge 5 ]] \
  && ! find plugins/raftkit-dev/evals/design-standard -mindepth 1 -maxdepth 1 -type d '!' -exec test -f '{}/prompt.md' ';' -print | grep -q . \
  && ! find plugins/raftkit-dev/evals/design-standard -mindepth 1 -maxdepth 1 -type d '!' -exec sh -c 'ls "$1"/graders/*.md >/dev/null 2>&1' _ '{}' ';' -print | grep -q .
check "EVAL1 >=5 design-standard eval cases, each with prompt.md + graders" ok $?

! grep -rlqE 'MDS-[0-9]|simplify wins|no test, no seam|does not defend it' plugins/raftkit-dev/evals/design-standard/*/prompt.md 2>/dev/null
check "EVAL2 eval prompts do not leak MDS rule IDs or Precedence wording (no-answer-leak)" ok $?

# --- versions + manifests ---

node -e '
  const v = JSON.parse(require("fs").readFileSync("plugins/raftkit-core/.claude-plugin/plugin.json","utf8")).version.split(".").map(Number);
  const min = [0, 7, 0];
  process.exit((v[0]-min[0] || v[1]-min[1] || v[2]-min[2]) >= 0 ? 0 : 1);
'
check "VER1 raftkit-core version is at least 0.7.0" ok $?

node -e '
  const v = JSON.parse(require("fs").readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json","utf8")).version.split(".").map(Number);
  const min = [0, 25, 0];
  process.exit((v[0]-min[0] || v[1]-min[1] || v[2]-min[2]) >= 0 ? 0 : 1);
'
check "VER2 raftkit-dev version is at least 0.25.0" ok $?

node -e '
  const fs = require("fs");
  const m = JSON.parse(fs.readFileSync(".claude-plugin/marketplace.json", "utf8"));
  const core = JSON.parse(fs.readFileSync("plugins/raftkit-core/.claude-plugin/plugin.json", "utf8"));
  const dev = JSON.parse(fs.readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json", "utf8"));
  const eCore = m.plugins.find(x => x.name === "raftkit-core");
  const eDev = m.plugins.find(x => x.name === "raftkit-dev");
  process.exit((eCore && eCore.description === core.description && eDev && eDev.description === dev.description) ? 0 : 1);
'
check "VER3 marketplace.json descriptions match both raftkit-core and raftkit-dev plugin.json" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
