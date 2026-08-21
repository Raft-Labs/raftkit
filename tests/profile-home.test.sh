#!/usr/bin/env bash
# Deterministic contract suite for the decided Project Profile home
# (Asana 1217123036545807, unblocked by Decision 1216550765662503):
# a Google Drive doc + a pinned Asana resource task linking it.
# project-onboarding states the destination at the point of asking and prints
# it on completion; every downstream mention of "open decision" for the
# profile home is swept to the decided home.
#
# Requirement -> evidence matrix:
#   R-1  profile-format states the decided home + decision task ... C1
#   R-2  onboarding Inputs state the home, override allowed ....... C2
#   R-3  completion output prints where the profile lives ......... C3
#   R-4  downstream skills point at the decided home .............. C4
#   R-5  no profile-home "open decision" phrasing survives ........ C5
#   R-6  pm + qa versions bumped .................................. C6
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

ONBOARD=plugins/raftkit-pm/skills/project-onboarding/SKILL.md
FORMAT=plugins/raftkit-pm/skills/project-onboarding/references/profile-format.md
PMMANIFEST=plugins/raftkit-pm/.claude-plugin/plugin.json
QAMANIFEST=plugins/raftkit-qa/.claude-plugin/plugin.json
sec() { sed -n "/$2/,/$3/p" "$1" 2>/dev/null; }
flat() { tr '\n' ' ' <<<"$1" | tr -s ' '; }

# C1 · profile-format's home section states the decided home and cites the
# decision task, positively.
homeflat=$(flat "$(sec "$FORMAT" '^## Where the profile lives' '^## ')")
grep -qi 'Google Drive doc' <<<"$homeflat" && grep -qi 'pinned Asana resource task' <<<"$homeflat"
check "C1a decided home: Drive doc + pinned Asana resource task" ok $?
grep -q '1216550765662503' <<<"$homeflat" && grep -qiE 'decided' <<<"$homeflat"
check "C1b decision task cited as the authority for the home" ok $?
grep -qiE 'already keeps its profile elsewhere|names that home|PM names' <<<"$homeflat"
check "C1c project override stays possible (access-path-agnostic)" ok $?

# C2 · onboarding's Inputs state the canonical home up front, keep the
# never-hardcode rule, and drop the open-choice framing.
inputsflat=$(flat "$(sec "$ONBOARD" '^## Inputs' '^## ')")
grep -qiE 'canonical home' <<<"$inputsflat" && grep -qi 'resource task' <<<"$inputsflat"
check "C2a Inputs state the canonical home at the point of asking" ok $?
grep -qi 'Never hardcode' <<<"$inputsflat"
check "C2b never-hardcode rule retained" ok $?

# C3 · the success summary prints where the profile lives.
reportflat=$(flat "$(sec "$FORMAT" '^## Reporting back' '^## ')")
grep -qi 'Profile lives at' <<<"$reportflat"
check "C3 completion output prints where the profile now lives" ok $?

# C4 · downstream skills point at the decided home, each in its own file.
for f in \
  plugins/raftkit-pm/skills/estimation/SKILL.md \
  plugins/raftkit-pm/skills/meeting-decisions/SKILL.md \
  plugins/raftkit-pm/skills/story-skill-generator/SKILL.md \
  plugins/raftkit-pm/skills/user-story/SKILL.md \
  plugins/raftkit-pm/skills/brainstorm/references/sources-and-notes.md \
  plugins/raftkit-qa/skills/test-suite/SKILL.md
do
  fflat=$(flat "$(cat "$f")")
  grep -qiE 'resource task|decided home' <<<"$fflat"; rc=$?
  # rc captured BEFORE the label's $(sed) runs — a substitution in an argument
  # resets $? and would make this check test sed's exit code, not grep's.
  label=$(sed -E 's|plugins/raftkit-[a-z]+/skills/||; s|/references||' <<<"$f")
  check "C4 $label points at the decided home" ok $rc
done

# C5 · the swept phrasing is gone: no file still calls the PROFILE home an
# open decision (the org-install open decision in scheduled-routine.md names a
# different task and is out of scope here).
grep -riE 'home is (\*\*)?an open decision|home is not fixed \(an open decision\)|home is still an open decision|open decision \+ recommended default|profile home is an open' plugins/ >/dev/null 2>&1
check "C5 no profile-home open-decision phrasing survives anywhere" fail $?

# C6 · versions bumped past A3's 0.23.0 (pm) and A2's 0.9.0 (qa).
python3 - "$PMMANIFEST" <<'EOF'
import json,sys
v=[int(x) for x in json.load(open(sys.argv[1]))["version"].split(".")]
sys.exit(0 if v>=[0,24,0] else 1)
EOF
check "C6a raftkit-pm version >= 0.24.0" ok $?
python3 - "$QAMANIFEST" <<'EOF'
import json,sys
v=[int(x) for x in json.load(open(sys.argv[1]))["version"].split(".")]
sys.exit(0 if v>=[0,10,0] else 1)
EOF
check "C6b raftkit-qa version >= 0.10.0" ok $?

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
