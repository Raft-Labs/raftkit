#!/usr/bin/env bash
# Contract suite for raftkit-pm:estimation after its re-scope to
# proposal-level feature-list estimation.
#
# estimation was auto-generated and never tested. It was built for the job a
# PM has when a new project lands and a proposal is due tomorrow — price the
# whole feature list — but its text described and behaved like a single-story
# tool: it refused any story that failed the readiness gate, and it broke a
# story into one line per [AC].
#
# A live run showed both halves failing at once. A PM asked it to size a small
# UI change; it first blocked demanding user-story context, then returned 85
# hours, and after pushback revised down but stayed visibly high. Nothing in
# the description told her the skill was built for a different question.
#
# This suite pins the re-scope: one job (feature list to FE/BE/QA hours in a
# Sheet), a trigger that says so, and a redirect that sends single-story asks
# to user-story — where story sizing already lives. What it deliberately does
# NOT pin: single-story sizing and any pricing, quoting or timeline output —
# those stay out of scope and are asserted as redirects, not as features.
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

SKILL=plugins/raftkit-pm/skills/estimation/SKILL.md
METHOD=plugins/raftkit-pm/skills/estimation/references/breakdown-method.md
SHEET=plugins/raftkit-pm/skills/estimation/references/sheet-output.md
STORY=plugins/raftkit-pm/skills/user-story/SKILL.md
SIZING=plugins/raftkit-pm/skills/user-story/references/sizing.md
HELP=plugins/raftkit-pm/commands/help.md
MANIFEST=plugins/raftkit-pm/.claude-plugin/plugin.json
WATERMARK='Requires founder review — not a client commitment.'
REDIRECT='One story is user-story'

# --- DISCOVERY: the trigger must carry the use case ---
#
# The live run's root cause. A PM reading the trigger could not tell this skill
# was built for a whole feature list, so she reached for it with one story.

grep -qiE '^description:.*feature list' "$SKILL"
check "E1 description names the feature list as the unit" ok $?

grep -qiE '^description:.*(proposal|new project)' "$SKILL"
check "E2 description names the proposal-time use case" ok $?

grep -qE '^description:.*FE/BE/QA' "$SKILL"
check "E3 description names the FE/BE/QA split" ok $?

grep -qiE '^description:.*(sheet|spreadsheet)' "$SKILL"
check "E4 description names the Sheet output" ok $?

grep -qiE '^description:.*user-story' "$SKILL"
check "E5 description routes single-story asks to user-story" ok $?

# The phrasings user-story claims for sizing must not be claimed back here,
# or discovery flips a coin between the two skills.
! grep -qiE '^description:.*(size this story|how long will this|day or a week)' "$SKILL"
check "E6 description does not claim user-story's sizing phrasings" ok $?

# --- THE GUARD: one story leaves this skill ---

grep -qiE '^## .*(one story|single story)' "$SKILL"
check "E7 SKILL.md carries a single-story guard section" ok $?

grep -qF "$REDIRECT" "$SKILL"
check "E8 SKILL.md states the redirect verbatim" ok $?

grep -qF "$REDIRECT" "$SHEET"
check "E9 sheet-output.md carries the redirect as an output shape" ok $?

# A new "Can't ..." string would be caught by the generic-cant refusal pattern
# and would need a refusals.json entry in the same commit. The redirect is
# routing, not a blocker, so it must not read as a refusal.
! grep -qE "^Can't " "$SKILL" "$SHEET" "$METHOD"
check "E10 the redirect adds no blocker-shaped refusal string" ok $?

# --- THE OLD SHAPE IS GONE ---
#
# Both halves of the 85-hour run: per-[AC] decomposition, and a readiness
# refusal that blocked before any number existed.

! grep -qiE '1:1|one-to-one' "$SKILL" "$METHOD"
check "E11 no 1:1 per-[AC] decomposition rule remains" ok $?

! grep -qF 'Ready-only, or refuse' "$SKILL"
check "E12 readiness is no longer a hard refusal gate" ok $?

! grep -qiE '^Cannot estimate' "$SKILL" "$METHOD" "$SHEET"
check "E13 no output refuses to estimate over story gaps" ok $?

grep -qiE 'the unit is (a|the) feature' "$METHOD"
check "E14 breakdown-method.md makes the feature the unit" ok $?

# The gate survives, demoted: where a story exists its gaps widen the range
# and get named, instead of stopping the run.
grep -qiE 'assumption' "$METHOD" && grep -qiE 'never block' "$METHOD"
check "E15 story gaps become named assumptions rather than a block" ok $?

# --- THE RULES THAT MUST SURVIVE THE RE-SCOPE ---

grep -qF "$WATERMARK" "$SKILL"
check "E16 SKILL.md states the watermark obligation verbatim" ok $?

# Every ```output block in every estimation file opens with the watermark.
# A flag, not `break` — `break` exits 0 and would swallow the failure it just found.
wm_ok=0
for f in "$SKILL" "$METHOD" "$SHEET"; do
  awk -v wm="$WATERMARK" '
    /^```output$/ { blocks++; inblock = 1; first = 1; next }
    /^```$/       { inblock = 0; next }
    inblock && first { first = 0; if ($0 != wm) bad++ }
    END { exit (bad > 0) ? 1 : 0 }
  ' "$f" || wm_ok=1
done
# A file with no output block passes above by vacuum; E18 pins that the shapes
# actually live in sheet-output.md.
check "E17 every output block opens with the watermark" ok $wm_ok

# The approval chain rides directly under the watermark on anything carrying
# numbers, so the number never travels without its route to the client.
awk '
  /^```output$/ { inblock = 1; n = 0; hours = 0; second = ""; next }
  /^```$/       { if (inblock && hours) { blocks++; if (second !~ /^AI estimate → vetted by .* → approved by Nirav or Ashit → only then shared with the client\.$/) bad++ } inblock = 0; next }
  inblock {
    n++
    if (n == 2) second = $0
    if ($0 ~ /[0-9][[:space:]]*h([^a-zA-Z]|$)/) hours = 1
  }
  END { exit (bad > 0 || blocks == 0) ? 1 : 0 }
' "$SHEET"
check "E18 every output block with hours carries the approval chain on line 2" ok $?

grep -qiE 'never a (single|point)|single number is never' "$METHOD"
check "E19 breakdown-method.md forbids a single-number answer" ok $?

grep -qiE 'at least one (named )?assumption|every range carries' "$METHOD"
check "E20 breakdown-method.md requires a named assumption per range" ok $?

grep -qF '⚠️ Partial' "$METHOD"
check "E21 breakdown-method.md widens on a partly-known profile area" ok $?

# A day figure reads as a delivery date, and dates are founder territory.
grep -qiE 'hours only|never convert hours into days' "$SKILL" "$METHOD"
check "E22 estimation keeps the answer in hours, never days" ok $?

# --- THE SHEET CONTRACT ---

test -f "$SHEET"
check "E23 references/sheet-output.md exists" ok $?

grep -qF 'references/sheet-output.md' "$SKILL"
check "E24 SKILL.md lists sheet-output.md under its reference files" ok $?

cols_ok=0
for col in 'feature' 'FE (h)' 'BE (h)' 'QA (h)' 'total' 'assumptions'; do
  grep -qF "$col" "$SHEET" || cols_ok=1
done
check "E25 sheet-output.md names every fixed column" ok $cols_ok

grep -qiE 'owns the structure' "$SHEET" && grep -qiE 'owns the content' "$SHEET"
check "E26 sheet-output.md splits structure and content ownership" ok $?

grep -qF 'write-protocol' "$SKILL" && grep -qiE 'approv' "$SHEET"
check "E27 the Sheet write sits behind the draft-then-approve gate" ok $?

# test-suite's rule, inherited: an absent connector is named with its exact
# access fix, never assumed away and never half-written.
grep -qiE 'never assume it|do not assume' "$SHEET" && grep -qiE 'access fix|which permission' "$SHEET"
check "E28 sheet-output.md names the access fix when the connector is absent" ok $?

# --- THE INPUT MAY ITSELF BE A SHEET ---
#
# A proposal's feature list usually already lives in a Sheet, so that is a first-class
# input, not a special case. The rule that matters is the direction: the source is
# read, the estimate goes somewhere else. Writing hours back into the PM's list would
# overwrite a file other people are editing and mix an unvetted number into it.

grep -qiE '^description:.*sheet.*(list|feature)' "$SKILL"
check "E29 description accepts a Sheet as the feature list" ok $?

grep -qiE 'read.only' "$SKILL" && grep -qiE 'source sheet' "$SKILL"
check "E30 SKILL.md treats a source Sheet as read-only" ok $?

# Detect first, ask second. Asking which column holds the features when the header
# plainly says so is friction, not safety — but a silent guess on an ambiguous
# Sheet prices the wrong column, so the ask has to survive for that case.
grep -qiE 'header row' "$SKILL" && grep -qiE 'says which column' "$SKILL"
check "E31 SKILL.md finds the feature column and reports which it read" ok $?

grep -qiE 'ask only when' "$SKILL"
check "E32 SKILL.md still asks when the Sheet is genuinely ambiguous" ok $?

grep -qiE 'source|never the destination' "$SHEET" && grep -qiE 'never written into|not the estimate sheet' "$SHEET"
check "E33 sheet-output.md separates the source Sheet from the estimate Sheet" ok $?

# --- OUT OF SCOPE: pricing, quoting, dates, capacity ---

grep -qiE 'never (price|prices|quote)|no pricing' "$SKILL"
check "E34 estimation prices nothing and quotes nothing" ok $?

grep -qiE 'capacity' "$SKILL" && grep -qiE 'founder' "$SKILL"
check "E35 delivery dates and capacity stay with founders" ok $?

# --- CROSS-SKILL CONSISTENCY: the pair must agree on the boundary ---
#
# user-story used to send a task-level breakdown of one story to estimation.
# estimation now sends one story back. Left as-is the two skills bounce a PM
# between them, which is the loop the guard exists to end.

! grep -qF 'for one story as much as for a whole list' "$STORY" &&
  ! grep -qF 'it names one story' "$STORY"
check "E36 user-story no longer routes one-story breakdowns to estimation" ok $?

! grep -qF 'for a single story as much as for a list' "$SIZING" &&
  ! grep -qF "estimation's even when it names one story" "$SIZING"
check "E37 sizing.md no longer claims estimation covers a single story" ok $?

# The boundary has to point somewhere, or the removal above just leaves a hole.
grep -qiE '^description:.*(feature list|backlog).{0,60}estimation' "$STORY"
check "E38 user-story description sends a feature list to estimation" ok $?

grep -qiE '\| `estimation` \|.*feature list' "$HELP"
check "E39 the help table row describes the feature-list job" ok $?

# --- HOUSE PLUMBING ---

node scripts/check-plain-language.mjs "$SKILL" "$METHOD" "$SHEET" >/dev/null 2>&1
check "E40 estimation output blocks pass the plain-language checker" ok $?

grep -qF 'Plain English out' "$SKILL"
check "E41 SKILL.md carries the propagated plain-language guardrail" ok $?

# A floor, not a pin: the re-scope ships in raftkit-pm 0.18.0, so the manifest
# must sit at or above it. The merge-base-anchored bump gate is
# scripts/validate.sh's job — restating it here would turn this suite red on
# the next legitimate release.
node -e '
  const fs = require("fs");
  const v = JSON.parse(fs.readFileSync("'"$MANIFEST"'", "utf8")).version.split(".").map(Number);
  const min = [0, 18, 0];
  process.exit((v[0]-min[0] || v[1]-min[1] || v[2]-min[2]) >= 0 ? 0 : 1);
'
check "E42 raftkit-pm version is at least 0.18.0" ok $?

echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed."
  exit 1
fi
echo "All checks passed."
