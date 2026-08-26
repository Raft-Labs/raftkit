#!/usr/bin/env bash
# Contract suite for Cowork usage telemetry.
#
# Claude Code reports itself through hooks. Cowork has no hooks and emits no
# event when a skill runs, so the only signal is the skill announcing itself.
# CW1-CW9 pin that contract, its disclosure, and its boundaries.
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
HR=plugins/raftkit-core/skills/house-rules/SKILL.md
joined() { cat "$@" 2>/dev/null | tr '\n' ' ' | tr -s ' '; }

[[ -f "$CT" ]] && grep -q 'user-invocable: false' "$CT" 2>/dev/null
check "CW1 cowork-telemetry ships as machinery, not a user-invocable skill" ok $?

# The announcement shape is what the admin app's regex matches. If this wording
# moves, ingest stops recording skills and nothing else fails loudly.
joined "$CT" | grep -q 'Using <plugin>:<skill>' \
  && grep -q 'Using raftkit-pm:brainstorm' "$CT" 2>/dev/null \
  && joined "$CT" | grep -qi 'first line of the first reply'
check "CW2 the announcement shape is pinned, with an example" ok $?

joined "$CT" | grep -qi 'Say it once per run, not once per reply'
check "CW3 the line is once per run, not per reply" ok $?

# Every Cowork-surface skill must carry it, or its usage is invisible.
missing=""
for f in plugins/raftkit-pm/skills/*/SKILL.md plugins/raftkit-qa/skills/*/SKILL.md; do
  grep -q 'cowork-telemetry' "$f" || missing="$missing $f"
done
[[ -z "$missing" ]]
check "CW4 every pm and qa skill carries the announcement contract" ok $?
[[ -n "$missing" ]] && echo "  missing:$missing"

# Each bullet must name its own skill — a copy-pasted wrong name puts another
# skill's rows in the dashboard, which is worse than no rows.
wrong=""
for f in plugins/raftkit-pm/skills/*/SKILL.md plugins/raftkit-qa/skills/*/SKILL.md; do
  plugin=$(echo "$f" | cut -d/ -f2)
  name=$(echo "$f" | cut -d/ -f4)
  grep -q "Using ${plugin}:${name}" "$f" || wrong="$wrong ${plugin}:${name}"
done
[[ -z "$wrong" ]]
check "CW5 each skill announces its own name, not a copy-pasted one" ok $?
[[ -n "$wrong" ]] && echo "  wrong:$wrong"

# This is not a write, and must never be filed as one. An entry in the
# automatic-write list would license the next skill to POST somewhere.
joined "$CT" | grep -qi 'It does not write anything' \
  && joined "$CT" | grep -qi 'this is not an exception to it' \
  && ! grep -q 'cowork-telemetry' plugins/raftkit-core/skills/write-protocol/SKILL.md
check "CW6 the announcement is not a write and adds no write-protocol exception" ok $?

# No skill may report anything itself — one line is the entire allowance.
joined "$CT" | grep -qi 'No skill calls an endpoint' \
  && joined "$CT" | grep -qi 'needs its own decision, not an extension of this one' \
  && joined "$HR" | grep -qi 'No skill calls an endpoint, spools a file, or reports anything itself'
check "CW7 one line is the whole allowance — no skill reports anything itself" ok $?

# The README and house-rules both promise an env-var opt-out. It does nothing
# in Cowork, and saying so is the difference between disclosure and a lie.
joined "$CT" | grep -qi 'is a Claude Code mechanism' \
  && joined "$CT" | grep -qi 'there are no hooks in Cowork' \
  && joined "$CT" | grep -qi 'no per-session switch inside Cowork' \
  && joined "$HR" | grep -qi 'does nothing in Cowork\|there is no per-session equivalent'
check "CW8 the opt-out is described accurately for Cowork, not implied" ok $?

# Responses are read and dropped. The admin app enforces it; this is the
# promise the two repos have to keep saying the same way.
joined "$CT" | grep -qi 'then dropped' \
  && joined "$CT" | grep -qi 'never stored'
check "CW9 assistant responses are read for the match and never stored" ok $?

grep -q '| `cowork-telemetry` |' plugins/raftkit-core/commands/help.md 2>/dev/null
check "CW10 cowork-telemetry appears in the core help table" ok $?

# Not Cowork-specific, but this suite is where it surfaced: an unquoted YAML
# scalar containing ": " parses on a lenient CLI and fails on the pinned CI one,
# and the skill then loads with EMPTY metadata — no name, no description, so it
# never triggers. b1d4816 shipped one that sat on development undetected.
hazards=$(python3 - <<'PY_EOF'
import glob, re
bad = []
for f in sorted(glob.glob("plugins/*/skills/**/SKILL.md", recursive=True)):
    s = open(f).read()
    if not s.startswith("---"):
        continue
    for line in s.split("---")[1].strip().split("\n"):
        m = re.match(r'^(name|description|user-invocable):\s*(.*)$', line)
        if not m or m.group(2)[:1] in ('"', "'"):
            continue
        if re.search(r':(\s|$)', m.group(2)):
            bad.append(f)
for f in bad:
    print(f)
PY_EOF
)
[[ -z "$hazards" ]]
check "CW11 no skill frontmatter hides a colon-space in an unquoted scalar" ok $?
[[ -n "$hazards" ]] && echo "  hazards: $hazards"


echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
