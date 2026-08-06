#!/usr/bin/env bash
# Contract suite for the plain-language guardrail (raftkit board — plain
# English output across all skills).
#
# The checker (scripts/check-plain-language.mjs) scans every ```output
# fenced block repo-wide for banned filler, over-length sentences (measured
# after rejoining hard-wrapped lines), block-average sentence length,
# uncovered Gate-N references, named HTML entities, an unclosed fence, and
# leaked internal-only labels (WEESLD, any case). This suite pins: the
# contract exists in house-rules, every skill except house-rules itself
# carries the propagated guardrail bullet, the real repo content is clean,
# and — so a green run here is trustworthy, not a rubber stamp — one
# fixture per rule deliberately fails it, plus two fixtures that
# deliberately pass everything (a clean block, and near-miss words that
# only contain a banned phrase as a substring).
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

missing=""
skill_count=0
for f in plugins/*/skills/*/SKILL.md; do
  skill_count=$((skill_count + 1))
  [[ "$f" == "$HOUSE_RULES" ]] && continue
  grep -qF 'Plain English out' "$f" || missing="$missing $f"
done
[[ -z "$missing" ]]
check "PL4 every skill but house-rules carries the guardrail bullet" ok $?
[[ -n "$missing" ]] && echo "  missing: $missing"

[[ "$skill_count" -ge 32 ]]
check "PL5 at least 32 skills found (no silent scope shrink)" ok $?

# --- CHECKER: exists, and is itself valid JS ---

CHECKER=scripts/check-plain-language.mjs
[[ -f "$CHECKER" ]]
check "PL6a checker script exists" ok $?

node --check "$CHECKER" >/dev/null 2>&1
check "PL6b checker script is syntactically valid" ok $?

grep -qF 'house-rules/references/plain-language.md' "$CHECKER"
check "PL6c checker parses the glossary from plain-language.md rather than hardcoding it" ok $?

# --- NEGATIVE CONTROLS: prove the checker actually catches problems ---

FIX=tests/fixtures/plain-language

node "$CHECKER" "$FIX/bad-banned-phrase.md" >/dev/null 2>&1
check "PL7a rejects a banned filler phrase" fail $?

node "$CHECKER" "$FIX/bad-long-sentence.md" >/dev/null 2>&1
check "PL7b rejects a sentence over 25 words" fail $?

node "$CHECKER" "$FIX/bad-weesld-leak.md" >/dev/null 2>&1
check "PL7c rejects a leaked WEESLD label" fail $?

node "$CHECKER" "$FIX/bad-html-entity.md" >/dev/null 2>&1
check "PL7d rejects a named HTML entity" fail $?

node "$CHECKER" "$FIX/good.md" >/dev/null 2>&1
check "PL7e accepts a compliant output block (no over-firing)" ok $?

node "$CHECKER" "$FIX/bad-wrapped-long-sentence.md" >/dev/null 2>&1
check "PL7f rejects a >25-word sentence hard-wrapped across lines" fail $?

node "$CHECKER" "$FIX/bad-unclosed-fence.md" >/dev/null 2>&1
check "PL7g rejects an output fence that's opened but never closed" fail $?

node "$CHECKER" "$FIX/bad-unglossed-term.md" >/dev/null 2>&1
check "PL7h rejects a Gate number the glossary doesn't cover" fail $?

node "$CHECKER" "$FIX/bad-block-average.md" >/dev/null 2>&1
check "PL7i rejects a block averaging over 15 words/sentence" fail $?

node "$CHECKER" "$FIX/bad-lowercase-weesld.md" >/dev/null 2>&1
check "PL7j rejects a lowercase weesld leak" fail $?

node "$CHECKER" "$FIX/good-boundaries.md" >/dev/null 2>&1
check "PL7k accepts near-miss words that only contain a banned phrase as a substring" ok $?

# --- REAL CONTENT: every existing output block in the repo passes ---

real_out="$(node "$CHECKER" plugins 2>&1)"
real_exit=$?
[[ "$real_exit" -eq 0 ]]
check "PL8 every existing output-fenced block in plugins/ passes the checker" ok $?
[[ "$real_exit" -ne 0 ]] && echo "$real_out"

grep -qE '^checked [0-9]+ output block' <<<"$real_out"
check "PL9 the checker actually scanned blocks, not a silent zero-match pass" ok $?

block_count="$(grep -oE '^checked [0-9]+' <<<"$real_out" | grep -oE '[0-9]+')"
[[ "${block_count:-0}" -ge 40 ]]
check "PL10 at least 40 output blocks found repo-wide (no silent scope shrink)" ok $?

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
