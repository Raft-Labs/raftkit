#!/usr/bin/env bash
# Contract suite for story-level sizing inside raftkit-pm:user-story.
#
# Two effort questions existed and only one had a home. "Break down every
# feature for a fixed-scope quote" belongs to estimation and stays there.
# "If I hand this one story to a developer, is it a day or a week?" had
# nowhere to go, so it was answered freehand — and the house rules that keep
# an effort number safe (range not point, named assumptions, the
# founder-review watermark) live inside estimation and did not travel.
#
# A live run confirmed it: user-story wrote a story, was asked "how long
# will this take to build?", and returned a figure with no watermark on the
# first line and an hours-to-days conversion that reads as a delivery date.
#
# This suite pins the sizing path into user-story and pins the four rules
# that must travel with it. What it deliberately does NOT pin: bulk
# feature-list estimation and any pricing, quoting or timeline output —
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

SKILL=plugins/raftkit-pm/skills/user-story/SKILL.md
SIZING=plugins/raftkit-pm/skills/user-story/references/sizing.md
MANIFEST=plugins/raftkit-pm/.claude-plugin/plugin.json
WATERMARK='Requires founder review — not a client commitment.'

# --- DISCOVERY: a PM must be able to find the path from the skill itself ---

grep -qiE '^description:.*\bsiz(e|ing)\b' "$SKILL"
check "S1 frontmatter description names sizing" ok $?

grep -qiE '^## .*\bsizing\b' "$SKILL"
check "S2 SKILL.md carries a sizing section" ok $?

test -f "$SIZING"
check "S3 references/sizing.md exists" ok $?

grep -qF 'references/sizing.md' "$SKILL"
check "S4 SKILL.md lists sizing.md under its reference files" ok $?

# --- THE WATERMARK: exact string, first line, every output ---

grep -qF "$WATERMARK" "$SIZING"
check "S5 sizing.md carries the watermark verbatim" ok $?

# Every ```output block in sizing.md must open with the watermark. This is
# the rule the live run broke — it paraphrased the warning and put it last.
awk -v wm="$WATERMARK" '
  /^```output$/ { blocks++; inblock = 1; first = 1; next }
  /^```$/       { inblock = 0; next }
  inblock && first {
    first = 0
    if ($0 != wm) { bad++ }
  }
  END { exit (bad > 0 || blocks == 0) ? 1 : 0 }
' "$SIZING"
check "S6 every output block opens with the watermark" ok $?

grep -qF "$WATERMARK" "$SKILL"
check "S7 SKILL.md states the watermark obligation verbatim" ok $?

# --- THE NUMBER: hour range, never a point, never converted to days ---

grep -qiE 'range' "$SIZING"
check "S8 sizing.md requires a range" ok $?

grep -qiE 'never a (single|point)|not a single number|single number' "$SIZING"
check "S9 sizing.md forbids a single-number answer" ok $?

# The live run said "roughly 4.5-6 days at 8 hours a day". A day figure
# reads as a schedule, and schedules are founder territory.
grep -qiE 'never convert hours into days' "$SIZING"
check "S10 sizing.md forbids converting hours into days" ok $?

grep -qiE 'assumption' "$SIZING"
check "S11 sizing.md requires named assumptions" ok $?

# --- UNCERTAINTY: thin sources widen, gaps get named ---

grep -qF '⚠️ Partial' "$SIZING"
check "S12 sizing.md widens on a partly-known profile area" ok $?

grep -qiE 'unresolved|gap|thin|missing' "$SIZING"
check "S13 sizing.md names story gaps as assumptions rather than gating" ok $?

# Decision: sizing does NOT run the readiness gate — that reintroduces the
# two-hop bounce this path exists to remove.
grep -qiE '(does not|never|no).{0,30}(readiness|gate)' "$SIZING"
check "S14 sizing.md states it does not gate on readiness" ok $?

# --- THE HARD CAP: the live run answered "day or week" in 500 words ---

grep -qiE 'cap|no more than|nothing more|at most' "$SIZING"
check "S15 sizing.md caps the output length" ok $?

# --- OUT OF SCOPE: bulk, pricing, timelines ---

grep -qF 'estimation' "$SIZING"
check "S16 sizing.md routes bulk feature-list work to estimation" ok $?

grep -qiE 'pric|quot|timeline|founder' "$SIZING"
check "S17 sizing.md keeps pricing and timelines with founders" ok $?

# A new "Can't ..." string would be caught by the generic-cant refusal
# pattern and would need a refusals.json entry in the same commit. The
# redirect is routing, not a blocker, so it must not read as a refusal.
! grep -qE "^Can't " "$SIZING"
check "S18 sizing.md adds no new blocker-shaped refusal string" ok $?

# --- DISCOVERY: user-story claims the sizing phrasing ---
#
# A live run showed the phrase decides the skill: the PM typed "how long will
# this take to build?" and discovery chose another skill, so the sizing path
# was never reached. user-story has to claim the phrasing it answers.

grep -qiE '^description:.*how long will this' "$SKILL"
check "S19 user-story description claims the 'how long' phrasing" ok $?

grep -qiE '^description:.*size this story' "$SKILL"
check "S20 user-story description claims the 'size this story' phrasing" ok $?

grep -qiE '^description:.*(day or a week|change request)' "$SKILL"
check "S21 user-story description claims the plain-English phrasings" ok $?

# A live run showed the opposite failure: "estimate this story" — a phrase
# estimation claims verbatim — returned a sizing range instead. The cause was
# a blanket claim in this description, "anything about one story belongs here",
# which overrode estimation on its own phrasing. The boundary is the KIND of
# answer, not the story count.

! grep -qiE '^description:.*anything about one story' "$SKILL"
check "S22 user-story description makes no blanket claim over one story" ok $?

grep -qiE '^description:.*breakdown' "$SKILL"
check "S23 user-story description sends breakdowns to estimation" ok $?

grep -qiE '(estimate|breakdown|quote).{0,60}estimation' "$SIZING"
check "S24 sizing.md sends an estimate or breakdown ask to estimation" ok $?

# --- HOUSE PLUMBING: the output blocks and the manifest ---

# --- THE HEADLINE CARRIES THE RISK ---
#
# A live run returned "30-35 h" with "+8-16 h", "+8 h" and "+6-8 h" listed
# underneath, so the honest ceiling was near 67 h. The watermark stops the
# number reading as a commitment; it does not stop a PM forwarding the
# headline and leaving the risk in the bullets.

grep -qiE 'absorb' "$SIZING"
check "S25 sizing.md requires the range to absorb every named driver" ok $?

# No output block may quote a bolt-on hour delta after the headline range.
awk '
  /^```output$/ { inblock = 1; next }
  /^```$/       { inblock = 0; next }
  inblock && /(adds|plus|extra|\+)[[:space:]]*[0-9]+([–-][0-9]+)?[[:space:]]*h/ { bad++ }
  END { exit (bad > 0) ? 1 : 0 }
' "$SIZING"
check "S26 no output block hangs an hour add-on under the range" ok $?

# --- NOTHING WRAPS THE BLOCK ---
#
# A live run reached sizing through estimation's redirect and prepended two
# framing lines above the watermark, then appended a paragraph below the
# closing line. A reader who copies the top of that message takes the
# number and leaves the founder-review warning behind.

grep -qiE '(nothing|no).{0,60}(precede|before the watermark|above the watermark)' "$SIZING"
check "S27 sizing.md forbids any line above the watermark" ok $?

grep -qiE '(nothing|no).{0,60}(follow|after the closing|below the closing)' "$SIZING"
check "S28 sizing.md forbids any line below the closing founder line" ok $?

node scripts/check-plain-language.mjs "$SIZING" >/dev/null 2>&1
check "S29 sizing.md output blocks pass the plain-language checker" ok $?

# A floor, not a pin: this path shipped in raftkit-pm 0.16.0, so the manifest must
# sit at or above it. The merge-base-anchored bump gate is scripts/validate.sh's
# job — restating it here would turn this suite red on the next legitimate release.
node -e '
  const fs = require("fs");
  const v = JSON.parse(fs.readFileSync("'"$MANIFEST"'", "utf8")).version.split(".").map(Number);
  const min = [0, 16, 0];
  process.exit((v[0]-min[0] || v[1]-min[1] || v[2]-min[2]) >= 0 ? 0 : 1);
'
check "S30 raftkit-pm version is at least 0.16.0" ok $?

# --- THE APPROVAL CHAIN AND THE ASSUMPTION CEILING ---
#
# raftkit-core/house-rules routes any AI effort number through the approval
# chain, and estimation carries it on every output that has numbers. Sizing
# emits an hour range outside the estimation skill, so the chain travels too.

grep -qF 'approved by Nirav or Ashit' "$SIZING"
check "S31 sizing output carries the estimation approval chain" ok $?

# The hard cap allows two to four assumption bullets. An example that breaks its
# own cap teaches the cap is soft — the first draft of this file shipped five.
awk '
  /^```output$/ { inblock = 1; n = 0; next }
  /^```$/       { if (inblock && n > 4) bad++; inblock = 0; next }
  inblock && /^- / { n++ }
  END { exit (bad > 0) ? 1 : 0 }
' "$SIZING"
check "S32 no output block exceeds four assumption bullets" ok $?

echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed."
  exit 1
fi
echo "All checks passed."
