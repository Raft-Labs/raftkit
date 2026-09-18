#!/usr/bin/env bash
# Contract suite for Cowork usage telemetry.
#
# Claude Code reports itself through hooks. Cowork has no hooks and emits no
# event when a skill runs, so the only signal is the skill announcing itself.
# CW1-CW10 pin that contract, its disclosure and its boundaries.
#
# The announcement wording is a cross-repo contract: the already-merged
# receiver in Raft-Labs/raftkit-admin matches it with a regex. If the shape
# moves here, ingest stops recording skills and nothing else fails loudly --
# which is why it is pinned as a literal rather than described.
#
# Every file this suite reads is asserted to exist first (CW0). Without that a
# `! grep -q ... missing-file` reads as a pass: grep exits 2, the leading `!`
# inverts it, and the check silently protects nothing. The pre-v2 version of
# this suite had exactly that bug against a path v2 deleted.
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

CT=plugins/raftkit-core/skills/cowork-telemetry/SKILL.md
RULES=plugins/raftkit-core/skills/rules/SKILL.md
HELP=plugins/raftkit-core/commands/help.md
README=README.md
joined() { cat "$@" 2>/dev/null | tr '\n' ' ' | tr -s ' '; }

# --- CW0: every path below exists, so no later check can pass vacuously ---

absent=""
for f in "$CT" "$RULES" "$HELP" "$README"; do [[ -f "$f" ]] || absent="$absent $f"; done
[[ -z "$absent" ]]
check "CW0 every file this suite asserts against exists" ok $?
[[ -n "$absent" ]] && { echo "  absent:$absent"; echo "$failures test(s) failed"; exit 1; }

grep -q 'user-invocable: false' "$CT"
check "CW1 cowork-telemetry ships as machinery, not a user-invocable skill" ok $?

# The shape the admin receiver's regex matches, plus a worked example.
joined "$CT" | grep -q 'Using <plugin>:<skill>' \
  && grep -q 'Using raftkit-pm:story' "$CT" \
  && joined "$CT" | grep -qi "first reply"
check "CW2 the announcement shape is pinned, with an example" ok $?

# Some skills lead with output load-bearing on its own -- the estimate
# watermark, the word-for-word empty-state messages. The announcement must not
# read as overriding any of them.
joined "$CT" | grep -qi 'A required opening line stays the opening line' \
  && joined "$CT" | grep -qi 'An exact message stays exact' \
  && joined "$CT" | grep -qi 'A hard stop still announces' \
  && joined "$CT" | grep -qi 'Nothing here loosens a skill'
check "CW2b the announcement yields to a skill's own first-output contract" ok $?

joined "$CT" | grep -qi 'Say it once per run, not once per reply'
check "CW3 the line is once per run, not per reply" ok $?

# Every Cowork-surface skill must carry it, or its usage is invisible.
missing=""
count=0
for f in plugins/raftkit-pm/skills/*/SKILL.md plugins/raftkit-qa/skills/*/SKILL.md; do
  count=$((count + 1))
  grep -q 'cowork-telemetry' "$f" || missing="$missing $f"
done
[[ -z "$missing" && "$count" -ge 9 ]]
check "CW4 every pm and qa skill carries the announcement contract ($count skills)" ok $?
[[ -n "$missing" ]] && echo "  missing:$missing"

# Each bullet must name its own skill. A copy-pasted wrong name files another
# skill's rows in the dashboard, which is worse than filing none.
wrong=""
for f in plugins/raftkit-pm/skills/*/SKILL.md plugins/raftkit-qa/skills/*/SKILL.md; do
  plugin=$(echo "$f" | cut -d/ -f2)
  name=$(echo "$f" | cut -d/ -f4)
  grep -q "Using ${plugin}:${name}" "$f" || wrong="$wrong ${plugin}:${name}"
done
[[ -z "$wrong" ]]
check "CW5 each skill announces its own name, not a copy-pasted one" ok $?
[[ -n "$wrong" ]] && echo "  wrong:$wrong"

# This is not a write and must never be filed as one -- an entry on the
# automatic-write exception list would license the next skill to POST
# somewhere. v2 folded the write protocol into the rules' one-stop section, so
# that section body is what must stay clean.
one_stop="$(awk '/^## One stop per run/{f=1;next} /^## /{f=0} f' "$RULES")"
joined "$CT" | grep -qi 'It does not write anything' \
  && joined "$CT" | grep -qi 'grants no exception' \
  && [[ -n "$one_stop" ]] \
  && ! grep -qi 'cowork-telemetry' <<<"$one_stop"
check "CW6 the announcement is not a write and adds no one-stop exception" ok $?

# One line is the entire allowance -- no skill reports anything itself.
joined "$CT" | grep -qi 'No skill calls an endpoint' \
  && joined "$CT" | grep -qi 'needs its own decision, not an extension of this one' \
  && joined "$RULES" | grep -qi 'no skill calls an endpoint, spools a file, or reports anything itself'
check "CW7 one line is the whole allowance — no skill reports anything itself" ok $?

# The README and the rules both offer an env-var opt-out. It does nothing in
# Cowork, and saying so is the difference between disclosure and a lie.
joined "$CT" | grep -qi 'sets an environment variable the hooks read' \
  && joined "$CT" | grep -qi 'no hooks in Cowork' \
  && joined "$CT" | grep -qi 'no per-session switch inside Cowork' \
  && joined "$RULES" | grep -qi 'does nothing in Cowork' \
  && joined "$README" | grep -qi 'has no effect in Cowork'
check "CW8 the opt-out is described accurately for Cowork, not implied" ok $?

# Responses are read and dropped. The receiver enforces it; this is the promise
# the two repos have to keep stating the same way.
joined "$CT" | grep -qi 'then dropped' \
  && joined "$CT" | grep -qi 'never stored' \
  && joined "$CT" | grep -qi 'refusal' \
  && joined "$README" | grep -qi 'then dropped'
check "CW9 assistant responses are read for the match and never stored" ok $?

grep -q '| `cowork-telemetry` |' "$HELP" \
  && joined "$HELP" | grep -qi 'Cowork has no hooks'
check "CW10 core help lists the skill and qualifies the telemetry claim" ok $?

echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
