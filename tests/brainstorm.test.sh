#!/usr/bin/env bash
# Contract suite for raftkit-pm:brainstorm and the shared interview
# machinery it runs on (raftkit-core:discovery-interview).
#
# Asana story 1216976430591539. FB1-FB6 map 1:1 onto the story's [AC] subtasks;
# DI1-DI4 cover the core skill the refactor extracted out of raftkit-dev:docs.
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

FB=plugins/raftkit-pm/skills/brainstorm
DI=plugins/raftkit-core/skills/discovery-interview
MAP=$FB/references/interview-map.md
RESEARCH=$FB/references/research-protocol.md
NOTES=$FB/references/sources-and-notes.md
CRAFT=$DI/references/conversation-craft.md

joined() { cat "$@" 2>/dev/null | tr '\n' ' ' | tr -s ' '; }

# --- The core skill the pm skill (and docs) run on ---

[[ -f "$DI/SKILL.md" ]] \
  && [[ -f "$DI/references/push-back.md" ]] \
  && [[ -f "$DI/references/proactive-prompts.md" ]] \
  && [[ -f "$DI/references/edge-cases.md" ]]
check "DI1 discovery-interview ships with its three shared catalogs" ok $?

grep -q 'user-invocable: false' "$DI/SKILL.md" 2>/dev/null
check "DI2 discovery-interview is machinery, not a user-invocable skill" ok $?

# It defines question behaviour only — an interview that could write on its own
# would sit outside the write-protocol gate.
grep -qi 'never writes\|no writes from here' "$DI/SKILL.md" 2>/dev/null \
  && grep -q 'write-protocol' "$DI/SKILL.md" 2>/dev/null
check "DI3 discovery-interview writes nothing itself and routes output through the gate" ok $?

# The six-bucket short pass and the 24-category walk must be one catalog, not
# two lists that can drift apart.
grep -qi 'WEESLD' "$DI/references/edge-cases.md" 2>/dev/null \
  && grep -qi 'Waiting' "$DI/references/edge-cases.md" 2>/dev/null \
  && grep -qi 'queue back-pressure' "$DI/references/edge-cases.md" 2>/dev/null
check "DI4 the short pass maps onto the same 24 categories, not a second list" ok $?

# --- FB1 [AC] happy path: idea + destination + depth -> a doc at that destination ---

# A bare 'live' grep passes on any incidental use of the word, so pin the two
# halves of the rule instead: the template is fetched live, and there is no
# remembered-format fallback when that fetch fails.
grep -q 'workflow-constants' "$FB/SKILL.md" 2>/dev/null \
  && joined "$FB/SKILL.md" | grep -qi 'live through the Asana connector' \
  && joined "$FB/SKILL.md" | grep -qi 'no remembered-format fallback' \
  && grep -q 'write-protocol' "$FB/SKILL.md" 2>/dev/null \
  && grep -q 'asana-formatting' "$FB/SKILL.md" 2>/dev/null
check "FB1 happy path fetches the live template and pushes only through the gate" ok $?

# --- FB2 [AC] empty state: zero notes still produces a full build-out ---

joined "$FB/SKILL.md" | grep -qi 'a complete starting point' \
  && joined "$FB/SKILL.md" | grep -qi 'Starting from nothing is a fully supported path' \
  && joined "$FB/SKILL.md" | grep -qi 'Never gate the run on'
check "FB2 zero notes is a supported start, never a gate" ok $?

# A bare project name is also a valid start — look for material before asking
# for it, and never re-ask for something already found.
joined "$NOTES" | grep -qi 'A project name with nothing attached is a complete starting point' \
  && joined "$NOTES" | grep -qi 'Do not ask for documents before looking for them' \
  && joined "$FB/SKILL.md" | grep -qi 'Never re-ask for something already found'
check "FB2b a bare project name starts a run — sources are found, not demanded" ok $?

# --- FB3 [AC] depth scaling: the choice must change the question set ---

grep -qi 'quick' "$MAP" 2>/dev/null \
  && grep -qi 'exhaustive' "$MAP" 2>/dev/null \
  && grep -qi 'headline question only' "$MAP" 2>/dev/null \
  && grep -qi 'all 24 categories' "$MAP" 2>/dev/null \
  && joined "$FB/SKILL.md" | grep -qi 'countable'
check "FB3 quick and exhaustive are bound to different, countable question sets" ok $?

# Both depths are asked, neither is defaulted — the story resolved this
# explicitly ("destination and depth are both asked explicitly each run").
joined "$FB/SKILL.md" | grep -qi 'there is no default and no silent pick' \
  && joined "$FB/SKILL.md" | grep -qi 'again no default, no silent pick'
check "FB3b destination and depth are both asked, neither silently defaulted" ok $?

# --- FB4 [AC] research attribution ---

grep -qi 'never automatic' "$RESEARCH" 2>/dev/null \
  && joined "$RESEARCH" | grep -qi 'Announce before running' \
  && joined "$RESEARCH" | grep -qi 'carries its source at the point it is used' \
  && joined "$RESEARCH" | grep -qi 'tellable apart'
check "FB4 research is announced, labelled inline, and never blended in as fact" ok $?

# A law, platform rule or contract term is a constraint, not an option the
# person can decline — that path escalates instead of recording a preference.
joined "$RESEARCH" | grep -qi 'A requirement is not a preference' \
  && joined "$RESEARCH" | grep -qi 'do not record it as a decision they made against it' \
  && grep -q 'raftkit-core/house-rules' "$RESEARCH" 2>/dev/null \
  && joined "$RESEARCH" | grep -qi 'escalate'
check "FB4b an authoritative requirement is escalated, never overridden by preference" ok $?

# --- FB5 [AC] error handling: contradictions flagged and re-asked, never guessed ---

joined "$FB/SKILL.md" | grep -qi 'Flag, never guess' \
  && joined "$FB/SKILL.md" | grep -qi 'both answers, and that they conflict' \
  && joined "$FB/SKILL.md" | grep -qi 're-asked' \
  && joined "$FB/SKILL.md" | grep -qi 'plausible-sounding value'
check "FB5 contradictions and gaps are flagged and re-asked, never guessed" ok $?

# --- FB6 [AC] i18n N/A: no UI surface, so no localized strings shipped ---
# Asserted as the absence of a UI: the skill's only output is a document, and
# its own prompts are conversation, not a shipped string table.

! find "$FB" -type f ! -name '*.md' 2>/dev/null | grep -q .
check "FB6 no UI surface — the skill ships markdown only, no string tables" ok $?

# --- Boundaries the story drew explicitly ---

# "Do NOT build: automatic user-story generation or auto-handoff into that skill"
joined "$FB/SKILL.md" | grep -qi 'never chains into it' \
  && joined "$FB/SKILL.md" | grep -qi 'No auto-handoff into'
check "FB7 terminal by design — offers user-story, never chains into it" ok $?

# Zero cached template text: the structure is fetched, and the map keys on
# topics rather than restating the template's own sections.
grep -qi 'never from memory and never' "$FB/SKILL.md" 2>/dev/null \
  && joined "$MAP" | grep -qi 'This file never restates that structure' \
  && joined "$MAP" | grep -qi 'maps \*\*lenses\*\* to question sets'
check "FB8 no cached template text — structure comes from the live fetch" ok $?

# No project facts in the plugin: the document-store root and the notes home
# are parameters, never a folder or client named in a skill file.
! grep -rqE '[0-9]{15,}|1[A-Za-z0-9_-]{25,}' "$FB" 2>/dev/null \
  && joined "$NOTES" | grep -qi 'never a folder, project, or client named in this file' \
  && grep -q 'raftkit-core/house-rules' "$NOTES" 2>/dev/null \
  && joined "$FB/SKILL.md" | grep -qi 'Never hardcode a folder, a project, or a client'
check "FB8b no hardcoded gids, folders or clients — sources and notes homes are parameters" ok $?

# The pm skill must actually run the shared contract, not a private copy of it.
grep -q 'raftkit-core/discovery-interview' "$FB/SKILL.md" 2>/dev/null \
  && grep -q 'raftkit-core/discovery-interview' "$MAP" 2>/dev/null \
  && ! [[ -f "$FB/references/push-back.md" ]] \
  && ! [[ -f "$FB/references/edge-cases.md" ]]
check "FB9 runs the shared interview contract, keeps no second copy of the catalogs" ok $?

# Discoverability: help table row + manifest lockstep (validate.sh enforces the
# table both ways; this pins the versions the refactor shipped under).
grep -q '| `brainstorm` |' plugins/raftkit-pm/commands/help.md 2>/dev/null \
  && grep -q '| `discovery-interview` |' plugins/raftkit-core/commands/help.md 2>/dev/null
check "FB10 both new skills appear in their plugin's help table" ok $?

# --- Question triage: not every open question goes to the client ---

grep -qi 'Must ask' "$MAP" 2>/dev/null \
  && grep -qi 'Good to clarify' "$MAP" 2>/dev/null \
  && grep -qi 'Team decides' "$MAP" 2>/dev/null \
  && joined "$MAP" | grep -qi 'costs goodwill and a week' \
  && joined "$FB/SKILL.md" | grep -qi 'Triage what is left'
check "FB11 leftover questions are triaged by who has to answer them" ok $?

# The whole point of the 🟢 label is that those questions stay internal. A doc
# that carries them outward makes the triage decorative.
joined "$MAP" | grep -qi 'It never goes out' \
  && joined "$FB/SKILL.md" | grep -qi 'Team decides never leaves the building' \
  && joined "$FB/SKILL.md" | grep -qi 'stripped from anything built to go to a client'
check "FB11b team-decides questions are marked internal and never sent outward" ok $?

# Every compiled fact carries a citation, not just a confidence tag — a session
# answer needs one as much as a researched line does.
joined "$FB/SKILL.md" | grep -qi 'a citation naming where it came from' \
  && joined "$FB/SKILL.md" | grep -qi 'required for a session answer too'
check "FB11c every compiled fact carries a citation, session answers included" ok $?

# Facts carry the same tags project-onboarding uses, not a second scheme.
grep -qi 'Confirmed' "$MAP" 2>/dev/null \
  && grep -qi 'Partial' "$MAP" 2>/dev/null \
  && grep -qi 'Missing' "$MAP" 2>/dev/null \
  && joined "$MAP" | grep -qi 'defaults to .. Partial'
check "FB12 facts carry the house confidence tags, defaulting to Partial" ok $?

# --- Notes across sessions: offered, never silent, and parameterized ---

joined "$NOTES" | grep -qi 'Offer, never save silently' \
  && grep -q 'write-protocol' "$NOTES" 2>/dev/null \
  && joined "$NOTES" | grep -qi 'read the notes before re-scanning' \
  && joined "$FB/SKILL.md" | grep -qi 'Notes are never saved silently'
check "FB13 session notes are read first, and saved only through the gate" ok $?

# A note is not automatically true later. Only Confirmed carries forward.
joined "$NOTES" | grep -qi 'Confirmed entries carry forward as settled' \
  && joined "$NOTES" | grep -qi 'are leads, not answers' \
  && joined "$NOTES" | grep -qi 'never carry a stale note forward as fact'
check "FB13b only confirmed notes suppress re-asking; the rest are re-checked" ok $?

# --- Batching: the shipped contract must not still say one-at-a-time ---

joined "$DI/SKILL.md" | grep -qi 'A few related questions at a time — three at most' \
  && ! grep -rqi 'one question at a time\|one adaptive question' "$DI" "$FB" 2>/dev/null \
  && joined "$FB/SKILL.md" | grep -qi 'three at most'
check "FB14 questions come in small related batches, capped, never one-at-a-time" ok $?

# --- Conversation craft: the delivery rules that make an interview land ---

[[ -f "$CRAFT" ]] \
  && joined "$CRAFT" | grep -qi 'Explain before you critique' \
  && joined "$CRAFT" | grep -qi 'Translate the domain' \
  && joined "$CRAFT" | grep -qi 'Pressure-test before formalising' \
  && joined "$CRAFT" | grep -qi 'Say when there is enough' \
  && joined "$FB/SKILL.md" | grep -qi 'Explain it back, before anything else'
check "FB15 explain-first, translate, pressure-test and stop-signal are contracted" ok $?

# Every lens the brainstorm partner ran is covered, including admin — the one
# genuinely missing from the first cut.
lens_missing=0
for lens in 'Business' 'User' 'Product' 'Permissions' 'Admin' 'Rules' 'Data' 'Side effects' 'Edge cases' 'Dependencies' 'Scope'; do
  grep -qi "^### .*$lens" "$MAP" 2>/dev/null || { echo "  missing lens: $lens"; lens_missing=1; }
done
[[ "$lens_missing" -eq 0 ]]
check "FB16 all eleven lenses are walked, admin included" ok $?

echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
