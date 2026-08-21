#!/usr/bin/env bash
# Deterministic contract suite for the decided Project Profile home
# (Decision 1216550765662503): one Asana task per project, named
# `Project Profile - <project name>`, carrying one subtask per section.
# The convention lives in raftkit-core/workflow-constants so no skill asks a
# human where a profile lives; every downstream mention of an "open decision"
# for the profile home is swept.
#
# Requirement -> evidence matrix:
#   R-1  profile-format states the decided home + decision task ... C1
#   R-2  onboarding takes the project and never infers it ......... C2
#   R-3  completion output prints where the profile lives ......... C3
#   R-4  downstream skills resolve by the convention .............. C4
#   R-5  no profile-home "open decision" phrasing survives ........ C5
#   R-6  core/pm/qa versions bumped .............................. C6
#   R-7  core carries the convention and the read-all rule ........ C7
#   R-8  a delta is recorded where Asana keeps no history ......... C8
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
CONSTANTS=plugins/raftkit-core/skills/workflow-constants/SKILL.md
COREMANIFEST=plugins/raftkit-core/.claude-plugin/plugin.json
PMMANIFEST=plugins/raftkit-pm/.claude-plugin/plugin.json
QAMANIFEST=plugins/raftkit-qa/.claude-plugin/plugin.json
sec() { sed -n "/$2/,/$3/p" "$1" 2>/dev/null; }
flat() { tr '\n' ' ' <<<"$1" | tr -s ' '; }

# C1 · profile-format's home section states the decided home and cites the
# decision task, positively.
homeflat=$(flat "$(sec "$FORMAT" '^## Where the profile lives' '^## ')")
grep -q 'Project Profile - <project name>' <<<"$homeflat" && grep -qi 'subtask per section' <<<"$homeflat"
check "C1a decided home: one Asana task, one subtask per section" ok $?
grep -q '1216550765662503' <<<"$homeflat" && grep -qiE 'decided' <<<"$homeflat"
check "C1b decision task cited as the authority for the home" ok $?
grep -qiE 'no per-project override|There is no per-project override' <<<"$homeflat"
check "C1c the home is fixed — no per-project override" ok $?
grep -qiE 'Drive remains a place sources are read from' <<<"$homeflat"
check "C1d Drive stays a source, never a destination" ok $?

# C2 · onboarding takes the Asana project as an input and never infers it from
# what a source says.
inputsflat=$(flat "$(sec "$ONBOARD" '^## Inputs' '^## ')")
grep -qiE 'The Asana project' <<<"$inputsflat" && grep -q 'Project Profile - <project name>' <<<"$inputsflat"
check "C2a Inputs take the Asana project and name the task convention" ok $?
grep -qiE 'never infer it' <<<"$inputsflat"
check "C2b the project is named by the PM, never inferred from a source" ok $?
grep -qiE 'resolve it against Asana' <<<"$inputsflat"
check "C2c a roughly-typed project name is resolved, not trusted" ok $?
grep -qiE "Which Asana project is this profile for" "$ONBOARD"
check "C2d exact stop message when no project is named" ok $?

# C3 · the success summary prints where the profile lives.
reportflat=$(flat "$(sec "$FORMAT" '^## Reporting back' '^## ')")
grep -qi 'Profile lives at' <<<"$reportflat"
check "C3 completion output prints where the profile now lives" ok $?

# C4 · downstream skills resolve the profile by the convention, each in its own
# file, rather than asking a human for its location.
for f in \
  plugins/raftkit-pm/skills/estimation/SKILL.md \
  plugins/raftkit-pm/skills/meeting-decisions/SKILL.md \
  plugins/raftkit-pm/skills/story-skill-generator/SKILL.md \
  plugins/raftkit-pm/skills/user-story/SKILL.md \
  plugins/raftkit-pm/skills/brainstorm/references/sources-and-notes.md \
  plugins/raftkit-qa/skills/test-suite/SKILL.md \
  plugins/raftkit-dev/skills/recipes/SKILL.md \
  plugins/raftkit-dev/skills/ui-creation/SKILL.md
do
  fflat=$(flat "$(cat "$f")")
  grep -q 'Project Profile - <project name>' <<<"$fflat"; rc=$?
  # rc captured BEFORE the label's $(sed) runs — a substitution in an argument
  # resets $? and would make this check test sed's exit code, not grep's.
  label=$(sed -E 's|plugins/raftkit-[a-z]+/skills/||; s|/references||' <<<"$f")
  check "C4 $label resolves the profile by the convention" ok $rc
done

# C5 · the swept phrasing is gone: no file still calls the PROFILE home an open
# decision (the org-install open decision in scheduled-routine.md names a
# different task and is out of scope here).
grep -riE 'home is (\*\*)?an open decision|home is not fixed \(an open decision\)|home is still an open decision|open decision \+ recommended default|profile home is an open' plugins/ >/dev/null 2>&1
check "C5 no profile-home open-decision phrasing survives anywhere" fail $?

# C6 · versions bumped past what development already carries.
ver_at_least() { # <manifest> <major> <minor> <patch>
  python3 - "$@" <<'EOF'
import json,sys
v=[int(x) for x in json.load(open(sys.argv[1]))["version"].split(".")]
sys.exit(0 if v>=[int(sys.argv[2]),int(sys.argv[3]),int(sys.argv[4])] else 1)
EOF
}
ver_at_least "$COREMANIFEST" 0 17 0
check "C6a raftkit-core version >= 0.17.0" ok $?
ver_at_least "$PMMANIFEST" 0 25 0
check "C6b raftkit-pm version >= 0.25.0" ok $?
ver_at_least "$QAMANIFEST" 0 11 0
check "C6c raftkit-qa version >= 0.11.0" ok $?

# C7 · core owns the convention, and the lookup reads every subtask rather than
# hunting a named section (a thin profile carries fewer of them).
constflat=$(flat "$(cat "$CONSTANTS")")
grep -q 'Project Profile - <project name>' <<<"$constflat"
check "C7a workflow-constants carries the task-name convention" ok $?
grep -qiE 'Read \*\*all\*\* of its subtasks|read all of its subtasks' <<<"$constflat"
check "C7b the lookup reads all subtasks, never one by section name" ok $?
grep -qiE 'route to .raftkit-pm project-onboarding|project-onboarding' <<<"$constflat"
check "C7c a project with no profile routes to onboarding" ok $?

# C8 · a delta is recorded, because Asana keeps no history of an overwritten
# description.
deltaflat=$(flat "$(sec "$FORMAT" '^## Recording a delta' '^## ')")
grep -qiE 'one comment on the parent task' <<<"$deltaflat"
check "C8a a delta run posts one comment on the parent task" ok $?
grep -qiE 'audit trail, not a backup' <<<"$deltaflat"
check "C8b the record is stated as an audit trail, not a backup" ok $?

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
