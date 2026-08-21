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
#
# One check is not a string match: scripts/check-estimate-totals.mjs adds up
# every estimate example the skill ships. Mutation testing found the rest of
# the gaps this suite now covers — a Sheet layout that carried neither the
# watermark nor the approval chain, and a dozen checks whose patterns stayed
# green with the rule they name deleted.
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
CHAIN='AI estimate → vetted by <implementing developer> → approved by Nirav or Ashit → only then shared with the client.'
PROSE_CHAIN='vetted by the developer who will build it'
REDIRECT='One story is user-story'
FULL_REDIRECT="One story is user-story's job — run raftkit-pm user-story and ask it to size the story. This skill estimates a whole feature list."

# Every file here is hard-wrapped, so any pinned sentence longer than one line
# is matched against the file with its whitespace squeezed to single spaces.
flat() { tr -s '[:space:]' ' ' < "$1"; }
skill_flat="$(flat "$SKILL")"
method_flat="$(flat "$METHOD")"
sheet_flat="$(flat "$SHEET")"
sizing_flat="$(flat "$SIZING")"

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

# sheet-output.md owns every emitted string and says so ("Nothing here is
# paraphrased elsewhere"). SKILL.md shipped a second verbatim copy of the
# redirect, so the two could drift apart word by word with both files green.
# The pointer stays; the copy must not come back.
printf '%s' "$skill_flat" | grep -qF 'shape in `references/sheet-output.md`' &&
  printf '%s' "$skill_flat" | grep -qF 'That file holds the wording; it is not restated here.' &&
  ! printf '%s' "$skill_flat" | grep -qF "$FULL_REDIRECT"
check "E8 SKILL.md points at the redirect's single source instead of restating it" ok $?

# Inside an output block, and in exactly one — a file-wide grep stayed green
# with the redirect demoted to prose the skill cannot emit.
awk -v redirect="$REDIRECT" '
  /^```output$/ { inblock = 1; hit = 0; next }
  /^```$/       { if (inblock && hit) found++; inblock = 0; next }
  inblock && index($0, redirect) { hit = 1 }
  END { exit (found == 1) ? 0 : 1 }
' "$SHEET"
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
# and get named, instead of stopping the run. Pinned to the rule's own words —
# the bare word "assumption" also matches the example's `Assumptions:` label,
# which kept this green with the rule deleted.
grep -qF 'Story gaps widen, they never block.' "$METHOD" &&
  printf '%s' "$method_flat" | grep -qF 'become a named assumption on that feature'
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
# The loop above passes by vacuum on a file with no output block, so the file
# that owns the shapes has to be shown to hold some.
awk '/^```output$/ { blocks++ } END { exit (blocks > 0) ? 0 : 1 }' "$SHEET" || wm_ok=1
check "E17 every output block opens with the watermark" ok $wm_ok

# The approval chain rides directly under the watermark on anything carrying
# numbers, so the number never travels without its route to the client. Matched
# exactly, not by pattern: the old regex accepted any `vetted by ...` text
# between the arrows, including the prose form that names nobody. Looped over
# all three files — a shape added to SKILL.md or the method escaped the pin.
chain_ok=0
for f in "$SKILL" "$METHOD" "$SHEET"; do
  awk -v chain="$CHAIN" '
    /^```output$/ { inblock = 1; n = 0; hours = 0; second = ""; next }
    /^```$/       { if (inblock && hours && second != chain) bad++; inblock = 0; next }
    inblock {
      n++
      if (n == 2) second = $0
      if ($0 ~ /[0-9][[:space:]]*h([^a-zA-Z]|$)/) hours = 1
    }
    END { exit (bad > 0) ? 1 : 0 }
  ' "$f" || chain_ok=1
done
# Same vacuum guard: sheet-output.md must actually carry hours-bearing blocks.
awk '
  /^```output$/ { inblock = 1; hours = 0; next }
  /^```$/       { if (inblock && hours) blocks++; inblock = 0; next }
  inblock && /[0-9][[:space:]]*h([^a-zA-Z]|$)/ { hours = 1 }
  END { exit (blocks > 0) ? 0 : 1 }
' "$SHEET" || chain_ok=1
check "E18 every output block with hours carries the exact approval chain on line 2" ok $chain_ok

# --- THE SHEET CARRIES ITS OWN WATERMARK AND CHAIN ---
#
# The Sheet is the artefact that gets exported and forwarded, and the first
# version of this layout carried neither line: the watermark and the chain
# existed only in chat, so an exported tab arrived at a client naked. Both are
# rows of the layout now, pinned in order.

layout="$(awk '/^## Fixed layout/ { inside = 1; next } inside && /^## / { exit } inside { print }' "$SHEET")"

grep -qE '^\| 1 \|.*Requires founder review — not a client commitment\.' <<<"$layout"
check "E43 the Sheet layout carries the watermark as row 1" ok $?

grep -qF "| 2 |" <<<"$layout" && grep -qF "$CHAIN" <<<"$layout"
check "E44 the Sheet layout carries the approval chain as row 2" ok $?

# The chain has two forms and only one belongs in emitted output or in a Sheet.
# house-rules states the policy in prose — "the developer who will build it" —
# which identifies nobody as the vetter. The emitted form carries a slot the PM
# fills.
grep -qF "$CHAIN" "$SHEET" && ! grep -qF "$PROSE_CHAIN" "$SKILL" "$METHOD" "$SHEET"
check "E45 the chain carries a fillable vetter slot, never the prose form" ok $?

# The slot is only fillable if the skill demands the name before any number is
# emitted. Whitespace-normalised because the obligation wraps, and anchored on
# the full sentence: "stop and ask" appears elsewhere in the file for other
# missing inputs and stayed green with this rule deleted.
printf '%s' "$skill_flat" | grep -qF 'The implementing developer or team lead** — who vets the number.' &&
  printf '%s' "$skill_flat" | grep -qF 'stop and ask before emitting hours; never guess a name, and never emit numbers with that slot unfilled.'
check "E46 SKILL.md requires the named implementing developer before hours" ok $?

grep -qiE 'never a (single|point)|single number is never' "$METHOD"
check "E19 breakdown-method.md forbids a single-number answer" ok $?

grep -qiE 'at least one (named )?assumption|every range carries' "$METHOD"
check "E20 breakdown-method.md requires a named assumption per range" ok $?

grep -qF '⚠️ Partial' "$METHOD"
check "E21 breakdown-method.md widens on a partly-known profile area" ok $?

# A day figure reads as a delivery date, and dates are founder territory. Both
# files carry the rule in their own words, and the old pattern was satisfied by
# either file alone — so the method could lose it silently.
grep -qF 'Hours only, never days.' "$SKILL" && grep -qF 'Hours, never days.' "$METHOD"
check "E22 estimation keeps the answer in hours, never days" ok $?

# The totalling rule is what the arithmetic check below enforces, so the words
# have to be there to enforce.
grep -qE '^## Totalling the list$' "$METHOD" &&
  printf '%s' "$method_flat" | grep -qF 'Sum the lows together and the highs together — never average, and never quote a midpoint'
check "E47 breakdown-method.md sums the lows and the highs, never averages" ok $?

# The example is the specification a run copies. The first version of it printed
# 45–74 h over components summing to 52–84 h, and every string check passed.
node scripts/check-estimate-totals.mjs "$SKILL" "$METHOD" "$SHEET" >/dev/null 2>&1
check "E48 every estimate example's totals are the sum of its parts" ok $?

# Both halves of the demoted readiness gate, in the skill's own words.
grep -qF 'There is no readiness gate to pass' "$SKILL" && grep -qF 'never block the run' "$SKILL"
check "E49 SKILL.md keeps readiness out of the way of an estimate" ok $?

# --- THE SHEET CONTRACT ---

test -f "$SHEET"
check "E23 references/sheet-output.md exists" ok $?

grep -qF 'references/sheet-output.md' "$SKILL"
check "E24 SKILL.md lists sheet-output.md under its reference files" ok $?

# Read out of the table in file order, not grepped one by one: six greps pass
# on a table whose columns have been reordered or renamed around them, and the
# proposal is built from that order.
cols="$(awk -F'|' '
  /^\| Column \| Holds \|/ { intable = 1; next }
  intable && /^\|/ {
    if ($2 ~ /^ *-+ *$/) next
    gsub(/^ +| +$/, "", $2)
    out = out (out == "" ? "" : ";") $2
    next
  }
  intable { exit }
  END { print out }
' "$SHEET")"
[[ "$cols" == 'feature;FE (h);BE (h);QA (h);total;assumptions' ]]
check "E25 sheet-output.md names the six fixed columns in order" ok $?

grep -qiE 'owns the structure' "$SHEET" && grep -qiE 'owns the content' "$SHEET"
check "E26 sheet-output.md splits structure and content ownership" ok $?

# `approv` matched the word "approval" anywhere in the file, including the chain
# line — so the whole gate section could go with this check still green.
grep -qF 'write-protocol' "$SKILL" &&
  grep -qE '^## The write happens after approval, never before$' "$SHEET" &&
  grep -qF 'Silence is not approval' "$SHEET"
check "E27 the Sheet write sits behind the draft-then-approve gate" ok $?

# Where the Sheet lives is a parameter, so no example may ship a real one.
! grep -qEi 'docs\.google\.com|drive\.google\.com|spreadsheets/d/|/d/[A-Za-z0-9_-]{20,}' "$SKILL" "$METHOD" "$SHEET" &&
  printf '%s' "$sheet_flat" | grep -qF 'Never hardcode a path, a file ID, or a single connector.'
check "E53 no Sheet URL or file ID is hardcoded anywhere" ok $?

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

# A skipped row that is never counted out loud is a dropped feature, which is
# the failure the disclosure exists to prevent.
printf '%s' "$skill_flat" | grep -qF 'skipped, and say how many were skipped so a dropped row is never silent.'
check "E52 SKILL.md discloses how many rows it skipped" ok $?

# The old first alternative was the bare word "source", which matches this file
# a dozen times over — the direction rule could be deleted and stay green.
grep -qF 'never the destination' "$SHEET" && grep -qF 'not the estimate Sheet' "$SHEET"
check "E33 sheet-output.md separates the source Sheet from the estimate Sheet" ok $?

# --- OUT OF SCOPE: pricing, quoting, dates, capacity ---

grep -qiE 'never (price|prices|quote)|no pricing' "$SKILL"
check "E34 estimation prices nothing and quotes nothing" ok $?

# The old pair — the word "capacity" and the word "founder" — was satisfied by
# the watermark and a stray mention, so the rule this check names could go
# missing. Pinned to the guardrail itself, whitespace-normalised.
printf '%s' "$skill_flat" | grep -qF 'No pricing, margins, or quotes; no delivery-date promises; no capacity planning.' &&
  printf '%s' "$skill_flat" | grep -qF 'escalates to founders'
check "E35 delivery dates and capacity stay with founders" ok $?

# The list is the scope contract: nothing added, nothing dropped in silence.
printf '%s' "$skill_flat" | grep -qF 'Never add a feature the list does not name, and never silently drop one.'
check "E54 estimation estimates the list and only the list" ok $?

# Per-criterion hours are the mechanism that turned a small UI change into 85
# hours. Both files have to keep saying so, or one of them re-offers it.
printf '%s' "$method_flat" | grep -qF 'Not a story, not an acceptance criterion, not a task invented while reading.'
check "E55 breakdown-method.md rules out the acceptance criterion as a unit" ok $?

printf '%s' "$skill_flat" | grep -qF 'Breaking one story into per-criterion hours is not offered by either skill'
check "E56 SKILL.md says per-criterion hours belong to neither skill" ok $?

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

# E36/E37 are negative checks: they pass on a file that says nothing at all.
# These two pin what sizing.md must say instead — the shared boundary rule, and
# the out-of-scope bullet that hands a list over with the job named.
printf '%s' "$sizing_flat" | grep -qF 'The boundary is the **size of the ask**, not the word used.'
check "E50 sizing.md states the size-of-ask boundary" ok $?

BULK_BULLET=$'**A whole feature list or backlog** — that estimate is `estimation`\'s job, which prices each feature into FE, BE and QA hours.'
printf '%s' "$sizing_flat" | grep -qF -- "$BULK_BULLET"
check "E51 sizing.md hands a whole feature list to estimation by name" ok $?

grep -qiE '\| `estimation` \|.*feature list' "$HELP"
check "E39 the help table row describes the feature-list job" ok $?

# --- HOUSE PLUMBING ---

node scripts/check-plain-language.mjs "$SKILL" "$METHOD" "$SHEET" >/dev/null 2>&1
check "E40 estimation output blocks pass the plain-language checker" ok $?

grep -qF 'Plain English out' "$SKILL"
check "E41 SKILL.md carries the propagated plain-language guardrail" ok $?

# A floor, not a pin: the re-scope ships in raftkit-pm 0.21.0, so the manifest
# must sit at or above it. The merge-base-anchored bump gate is
# scripts/validate.sh's job — restating it here would turn this suite red on
# the next legitimate release.
node -e '
  const fs = require("fs");
  const v = JSON.parse(fs.readFileSync("'"$MANIFEST"'", "utf8")).version.split(".").map(Number);
  const min = [0, 21, 0];
  process.exit((v[0]-min[0] || v[1]-min[1] || v[2]-min[2]) >= 0 ? 0 : 1);
'
check "E42 raftkit-pm version is at least 0.21.0" ok $?

echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed."
  exit 1
fi
echo "All checks passed."
