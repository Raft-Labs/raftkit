#!/usr/bin/env bash
# Deterministic contract suite for the story-gap loop rule in house-rules —
# the documented half of the dev/QA -> PM story-gap loop (Asana 1217122967840819).
# The mechanics shipped in user-story amend mode (see user-story-amend.test.sh);
# this suite pins the RULE: authored in raftkit-core:house-rules and
# cross-referenced from both pm skills that implement it.
#
# Requirement -> evidence matrix:
#   R-1  named section exists, placed in house-rules ........ C1, C2
#   R-2  the four-link chain, each link present ............. C3
#   R-3  PM owns the update — authority never moves down .... C4
#   R-4  channel is amend mode, never out-of-band ........... C5
#   R-5  Gate 0 boundary — dev-answerable gaps excluded ..... C6
#   R-6  house-rules description names the loop ............. C7
#   R-7  amend-mode names the governing rule ................ C8
#   R-8  story-readiness points at the rule ................. C9
#   R-9  core help's house-rules row names the loop ......... C10
#   R-10 core + pm versions bumped .......................... C11
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

RULES=plugins/raftkit-core/skills/house-rules/SKILL.md
AMEND=plugins/raftkit-pm/skills/user-story/references/amend-mode.md
READY=plugins/raftkit-pm/skills/story-readiness/SKILL.md
COREHELP=plugins/raftkit-core/commands/help.md
COREMANIFEST=plugins/raftkit-core/.claude-plugin/plugin.json
PMMANIFEST=plugins/raftkit-pm/.claude-plugin/plugin.json
sec() { sed -n "/$2/,/$3/p" "$1" 2>/dev/null; }
# These files are hard-wrapped, so multi-word normative phrases span line
# breaks; longer-than-one-word patterns run against the flattened section.
flat() { tr '\n' ' ' <<<"$1" | tr -s ' '; }

# C1 · the section exists as a top-level heading of its own.
grep -q '^## The story-gap loop' "$RULES"
check "C1 house-rules has a top-level '## The story-gap loop' section" ok $?

# C2 · placement: after the founder-escalation section, before telemetry —
# the loop is a process rule, not a telemetry or adoption rule.
awk '/^## Escalate to founders/{e=NR} /^## The story-gap loop/{g=NR} /^## Telemetry and blocker capture/{t=NR} END{exit !(e && g && t && e<g && g<t)}' "$RULES"
check "C2 section sits between founder escalation and telemetry" ok $?

gap=$(sec "$RULES" '^## The story-gap loop' '^## ')
gapflat=$(flat "$gap")

# C3 · the chain, all four links, in order, in one bold chain line.
grep -qE 'Gap found downstream.*→.*amend mode.*→.*story-readiness.*→.*follower' <<<"$gapflat"
check "C3a chain line carries all four links in order" ok $?
grep -qiE 'CC line' <<<"$gapflat"
check "C3b notification link names the CC line mechanism" ok $?
# The guarantee must stay honest: reach = the follower list, and an empty list
# stops-and-asks — never an unconditional "dev and QA are notified" claim.
grep -qiE "loop's reach.*follower list" <<<"$gapflat" && grep -qiE 'stops and asks' <<<"$gapflat"
check "C3c notification reach tied to the follower list, empty list stops-and-asks" ok $?

# C4 · ownership: the PM updates the story; requirements authority stays put.
grep -qiE 'PM (owns|updates)' <<<"$gapflat" && grep -qiE 'requirements authority never moves downstream' <<<"$gapflat"
check "C4 PM ownership stated with the authority rationale" ok $?

# C5 · channel: amend mode — a gap settled out-of-band leaves the story wrong.
grep -qiE 'never (a )?verbal' <<<"$gapflat" && grep -qiE 'scope-guard' <<<"$gapflat"
check "C5 out-of-band fixes banned; story named as what QA/scope-guard measure" ok $?

# C6 · boundary: dev-answerable gaps are Gate 0's lane, not this loop's.
grep -qiE 'dev-answerable' <<<"$gapflat" && grep -qiE 'Gate 0' <<<"$gapflat"
check "C6 Gate 0 boundary drawn for dev-answerable gaps" ok $?

# C7 · the frontmatter description is house-rules' trigger surface.
desc=$(sed -n '/^description:/,/^user-invocable:/p' "$RULES" 2>/dev/null)
grep -qi 'story-gap' <<<"$desc"
check "C7 house-rules description names the story-gap loop" ok $?

# C8 · amend-mode's motivation block names the governing rule by home and name.
amendhead=$(flat "$(head -30 "$AMEND")")
grep -qE 'house-rules' <<<"$amendhead" && grep -qiE 'story-gap loop' <<<"$amendhead"
check "C8 amend-mode names house-rules' story-gap loop as the rule it implements" ok $?

# C9 · story-readiness' guardrail points at the rule, not just the mechanism.
readyflat=$(flat "$(sec "$READY" 'amend mode' '^## ')")
grep -qiE 'story-gap loop' <<<"$readyflat" && grep -qE 'house-rules' <<<"$readyflat"
check "C9 story-readiness points at house-rules' story-gap loop" ok $?

# C10 · discoverability: core help's house-rules row names the loop.
helprow=$(grep '`house-rules`' "$COREHELP")
grep -qiE 'story-gap loop' <<<"$helprow"
check "C10 core help's house-rules row names the story-gap loop" ok $?

# C11 · versions: core minor-bumped past 0.15.0, pm bumped past 0.21.0.
python3 - "$COREMANIFEST" 0 16 <<'EOF'
import json,sys
v=[int(x) for x in json.load(open(sys.argv[1]))["version"].split(".")]
sys.exit(0 if (v[0],v[1])>=(int(sys.argv[2]),int(sys.argv[3])) else 1)
EOF
check "C11a raftkit-core version >= 0.16.0" ok $?
python3 - "$PMMANIFEST" <<'EOF'
import json,sys
v=[int(x) for x in json.load(open(sys.argv[1]))["version"].split(".")]
sys.exit(0 if v>=[0,21,1] else 1)
EOF
check "C11b raftkit-pm version >= 0.21.1" ok $?

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
