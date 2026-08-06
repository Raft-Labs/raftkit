#!/usr/bin/env bash
# Contract suite for the plain-language guardrail (raftkit board — plain
# English output across all skills).
#
# The checker (scripts/check-plain-language.mjs) scans every ```output
# fenced block repo-wide for banned filler (word-boundary matched,
# case-insensitive), over-length sentences (measured after rejoining
# hard-wrapped lines, regardless of how the next line is cased),
# block-average sentence length, uncovered Gate-N references, named or
# numeric HTML entities, correctly nested inner code fences, an
# unterminated fence (whose content is still checked, not dropped), and a
# leaked internal-only label (WEESLD, any case, word-boundary matched).
# This suite pins: the contract exists in house-rules, every skill except
# house-rules itself carries the propagated guardrail bullet, the real repo
# content is clean, and — so a green run here is trustworthy, not a rubber
# stamp — each negative-control fixture deliberately fails exactly the rule
# it names (with the exact exit code and violation text asserted, not just
# "nonzero"), and each positive-control fixture deliberately passes.
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
check_exit() { # <name> <expected exit code> <actual exit code>
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected exit $expected, got $actual)"
    failures=$((failures + 1))
  fi
}
check_contains() { # <name> <haystack> <needle>
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected output to contain: $needle)"
    failures=$((failures + 1))
  fi
}

HOUSE_RULES=plugins/raftkit-core/skills/house-rules/SKILL.md
REF=plugins/raftkit-core/skills/house-rules/references/plain-language.md

# --- CONTRACT: house-rules names it, plain-language.md carries it ---

grep -qF '## How skills talk to humans' "$HOUSE_RULES"
check "PL1 house-rules names the plain-language contract" ok $?

grep -qF 'plain-language.md' "$HOUSE_RULES"
check "PL2 house-rules links to the reference file" ok $?

[[ -f "$REF" ]]
check "PL3a plain-language.md exists" ok $?

grep -qF '## Banned phrases' "$REF" && grep -qF '## The house glossary' "$REF" \
  && grep -qF '## Never shown to a human' "$REF" && grep -qF '```output' "$REF"
check "PL3b plain-language.md carries the banned list, glossary, WEESLD carve-out, and output-fence convention" ok $?

grep -qF '## Before / after' "$REF"
check "PL3c plain-language.md carries a before/after example" ok $?

grep -qF '## The one exception: verbatim strings' "$REF"
check "PL3d plain-language.md carries the governance-pack verbatim-string carve-out" ok $?

# --- PROPAGATION: every skill except house-rules carries the bullet ---
#
# Uses find, not a plugins/*/skills/*/SKILL.md glob, so a nested skill (one
# level deeper than the top-level skills/<name>/SKILL.md shape -- e.g.
# raftkit-dev/docs's project-local docs-companion) is not silently invisible
# to this check. docs-companion ships standalone into a client repo with no
# raftkit-core installed, so it carries its own worded version of the bullet
# rather than a `raftkit-core/house-rules` cross-reference -- but it still
# must contain the phrase, same as every other skill here.

missing=""
skill_count=0
while IFS= read -r f; do
  skill_count=$((skill_count + 1))
  [[ "$f" == "$HOUSE_RULES" ]] && continue
  grep -qF 'Plain English out' "$f" || missing="$missing $f"
done < <(find plugins -type f -name 'SKILL.md' | sort)
[[ -z "$missing" ]]
check "PL4 every skill but house-rules carries the guardrail bullet" ok $?
[[ -n "$missing" ]] && echo "  missing: $missing"

[[ "$skill_count" -ge 32 ]]
check "PL5 at least 32 skills found (no silent scope shrink)" ok $?

# --- CHECKER: exists, is itself valid JS, and its usage/target errors are
# distinguishable from "clean" and from "violations found" ---

CHECKER=scripts/check-plain-language.mjs
[[ -f "$CHECKER" ]]
check "PL6a checker script exists" ok $?

node --check "$CHECKER" >/dev/null 2>&1
check "PL6b checker script is syntactically valid" ok $?

node "$CHECKER" >/dev/null 2>&1
check_exit "PL6c no target given exits 2 (a usage error, never 'clean')" 2 $?

out="$(node "$CHECKER" "tests/fixtures/plain-language/does-not-exist.md" 2>&1)"; code=$?
check_exit "PL6d a nonexistent target exits 2 (never mistaken for 'violations found')" 2 "$code"
check_contains "PL6d reports which target it couldn't read" "$out" "cannot read target"

FIX=tests/fixtures/plain-language

# PL6e/PL6f replace a vacuous assertion from an earlier revision of this
# suite, which grepped the checker's source for the literal string
# "house-rules/references/plain-language.md" -- that string appears in the
# checker's header COMMENT regardless of whether the glossary is ever
# actually parsed, so the old assertion passed even against a checker that
# never read the file. Assert on real behavior instead: an unglossed house
# term fails by name, and the same term glossed in plain-language.md passes.
out="$(node "$CHECKER" "$FIX/bad-unglossed-term.md" 2>&1)"; code=$?
check_exit "PL6e an unglossed Gate reference exits 1" 1 "$code"
check_contains "PL6e names the unglossed term" "$out" 'house term "Gate 3"'

node "$CHECKER" "$FIX/good-known-gate.md" >/dev/null 2>&1
check_exit "PL6f a Gate reference the glossary already covers exits 0 (no over-firing)" 0 $?

# --- NEGATIVE CONTROLS: prove the checker actually catches problems ---
#
# Each assertion pins the exact exit code (1, not merely "nonzero" — a bad
# target also exits nonzero, at 2, and that must not read as a pass here)
# and the specific violation text, not just that *something* failed.

out="$(node "$CHECKER" "$FIX/bad-banned-phrase.md" 2>&1)"; code=$?
check_exit "PL7a rejects a banned filler phrase (exit 1)" 1 "$code"
check_contains "PL7a names the phrase" "$out" 'banned phrase "leverage"'

out="$(node "$CHECKER" "$FIX/bad-long-sentence.md" 2>&1)"; code=$?
check_exit "PL7b rejects a sentence over 25 words (exit 1)" 1 "$code"
check_contains "PL7b reports the word count" "$out" "sentence over 25 words (34)"

out="$(node "$CHECKER" "$FIX/bad-weesld-leak.md" 2>&1)"; code=$?
check_exit "PL7c rejects a leaked WEESLD label (exit 1)" 1 "$code"
check_contains "PL7c names the leaked label" "$out" 'internal-only label "WEESLD"'

out="$(node "$CHECKER" "$FIX/bad-html-entity.md" 2>&1)"; code=$?
check_exit "PL7d rejects a named HTML entity (exit 1)" 1 "$code"
check_contains "PL7d names the entity violation" "$out" "HTML entity found"

out="$(node "$CHECKER" "$FIX/bad-numeric-entity.md" 2>&1)"; code=$?
check_exit "PL7h rejects a numeric HTML entity (exit 1)" 1 "$code"
check_contains "PL7h names the entity violation" "$out" "HTML entity found"

node "$CHECKER" "$FIX/good.md" >/dev/null 2>&1
check_exit "PL7e accepts a compliant output block, no over-firing (exit 0)" 0 $?

out="$(node "$CHECKER" "$FIX/bad-unterminated-fence.md" 2>&1)"; code=$?
check_exit "PL7f rejects an unterminated \`\`\`output fence (exit 1)" 1 "$code"
check_contains "PL7f names it as unterminated" "$out" "unterminated"
check_contains "PL7m an unterminated fence's content is still checked, not dropped" "$out" 'internal-only label "WEESLD"'

out="$(node "$CHECKER" "$FIX/bad-nested-fence.md" 2>&1)"; code=$?
check_exit "PL7g rejects a violation hidden behind two levels of nested code fence (exit 1)" 1 "$code"
check_contains "PL7g still finds the violation past both inner fences" "$out" 'banned phrase "leverage"'

out="$(node "$CHECKER" "$FIX/bad-block-average.md" 2>&1)"; code=$?
check_exit "PL7i rejects a block averaging over 15 words/sentence (exit 1)" 1 "$code"
check_contains "PL7i reports the block average, not the per-sentence cap" "$out" "block averages"

out="$(node "$CHECKER" "$FIX/bad-lowercase-weesld.md" 2>&1)"; code=$?
check_exit "PL7j rejects a lowercase weesld leak (exit 1)" 1 "$code"
check_contains "PL7j names the leaked label regardless of case" "$out" 'internal-only label "WEESLD"'

node "$CHECKER" "$FIX/good-boundaries.md" >/dev/null 2>&1
check_exit "PL7k accepts near-miss words that only contain a banned phrase as a substring (exit 0)" 0 $?

out="$(node "$CHECKER" "$FIX/bad-wrapped-long-sentence.md" 2>&1)"; code=$?
check_exit "PL7l rejects a >25-word sentence hard-wrapped across lines, next line lowercase (exit 1)" 1 "$code"
check_contains "PL7l reports the word count" "$out" "sentence over 25 words (39)"

# PL7n covers a real bug in an earlier join heuristic: a wrap was only
# treated as a continuation when the next line started lowercase, so a
# sentence wrapped right before a capitalized word or acronym escaped the
# cap entirely. The join condition no longer looks at the next line's case.
out="$(node "$CHECKER" "$FIX/bad-wrapped-uppercase-sentence.md" 2>&1)"; code=$?
check_exit "PL7n rejects a >25-word sentence wrapped before a capitalized continuation (exit 1)" 1 "$code"
check_contains "PL7n reports the word count" "$out" "sentence over 25 words (32)"

# --- REAL CONTENT: every existing output block in the repo passes ---

real_out="$(node "$CHECKER" plugins 2>&1)"
real_exit=$?
[[ "$real_exit" -eq 0 ]]
check "PL8 every existing output-fenced block in plugins/ passes the checker" ok $?
[[ "$real_exit" -ne 0 ]] && echo "$real_out"

grep -qE '^checked [0-9]+ output block' <<<"$real_out"
check "PL9 the checker actually scanned blocks, not a silent zero-match pass" ok $?

# The floor is the real measured count at merge time (59, via both the
# checker's own tally and `grep -rEc '^[[:space:]]*```output[[:space:]]*$'
# plugins/`), minus a small safety margin -- not a stale number carried
# over from either branch this suite was built from.
block_count="$(grep -oE '^checked [0-9]+' <<<"$real_out" | grep -oE '[0-9]+')"
[[ "${block_count:-0}" -ge 55 ]]
check "PL10 at least 55 output blocks found repo-wide (no silent scope shrink)" ok $?

# --- EVAL BUNDLE: behavioral cases in the official layout (prompt.md + graders/*.md) ---

EVALS=plugins/raftkit-core/evals/plain-language
n=$(find "$EVALS" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[[ "${n:-0}" -ge 6 ]] && ! find "$EVALS" -mindepth 1 -maxdepth 1 -type d \
  '!' -exec test -f '{}/prompt.md' ';' -print | grep -q . \
  && ! find "$EVALS" -mindepth 1 -maxdepth 1 -type d \
  '!' -exec sh -c 'ls "$1"/graders/*.md >/dev/null 2>&1' _ '{}' ';' -print | grep -q .
check "PL11 >=6 eval cases each with prompt.md + graders" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
