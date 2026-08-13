#!/usr/bin/env bash
# Deterministic contract suite for user-story amend mode — the PM side of the
# dev/QA -> PM story-gap loop (Asana 1217122967840819). Placement-aware: a seam
# must appear in its owning section, not merely somewhere in a file.
#
# Requirement -> evidence matrix:
#   R-1  two modes, state-based entry ........... C1, C2
#   R-2  amend reference exists and is linked ... C3
#   R-3  empty body routes pre-gate; 3 branches . C4
#   R-4  NOT READY refuses, no override ......... C5
#   R-5  mid-build needs a separate go .......... C6
#   R-6  diff-first draft, never a rewrite ...... C7
#   R-7  additive [AC] rules, no deletion ....... C8
#   R-8  every follower tagged, unfiltered ...... C9
#   R-9  readiness re-run after the push ........ C10
#   R-10 write-protocol + read-back verify ...... C11
#   R-10b a partial push is reported, not hidden  C11d, C11e
#   R-11 story-readiness documents its new role . C12
#   R-12 help table names amending .............. C13
#   R-13 plugin version bumped .................. C14
#   R-14 template still read live in amend mode . C15
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

PM=plugins/raftkit-pm/skills
STORY="$PM/user-story/SKILL.md"
AMEND="$PM/user-story/references/amend-mode.md"
READY="$PM/story-readiness/SKILL.md"
HELP=plugins/raftkit-pm/commands/help.md
MANIFEST=plugins/raftkit-pm/.claude-plugin/plugin.json
sec() { sed -n "/$2/,/$3/p" "$1" 2>/dev/null; }
# These files are hard-wrapped at ~80 columns, so a normative phrase routinely
# spans a line break and a plain grep for it silently never matches. Any check
# whose pattern is longer than one word runs against the flattened section.
flat() { tr '\n' ' ' <<<"$1" | tr -s ' '; }

# C1 · the frontmatter description is the only trigger surface (raftkit-pm has
# no per-skill command file), so the amend triggers must live there.
desc=$(sed -n '/^description:/,/^user-invocable:/p' "$STORY" 2>/dev/null)
grep -qi 'amend' <<<"$desc" && grep -qiE 'extend|update an existing' <<<"$desc"
check "C1 frontmatter description carries the amend triggers" ok $?

# C2 · both modes named in their own section, with a deterministic entry branch.
modes=$(sec "$STORY" '^## Two modes' '^## ')
grep -qiE 'mode a' <<<"$modes" && grep -qiE 'mode b' <<<"$modes"
check "C2a Two modes section names Mode A and Mode B" ok $?
grep -qiE 'deterministic' <<<"$modes" && grep -qiE 'no story body|empty description' <<<"$modes"
check "C2b mode selection is deterministic on entry, keyed on the body" ok $?
# The state, not the wording. An existing task asked about in words neither mode
# names must still land in Mode B, and a doubt is resolved inside Mode B.
modesf=$(flat "$modes")
grep -qiE 'never from how the request was phrased' <<<"$modesf" \
  && grep -qiE 'body decides' <<<"$modesf" \
  && grep -qiE 'ask [^.]{0,20}inside[^.]{0,20}mode b' <<<"$modesf"
check "C2c the body decides the mode; ambiguity is resolved inside Mode B" ok $?

# C3 · the amend reference exists and is reachable from SKILL.md.
[[ -f "$AMEND" ]]
check "C3a amend-mode.md exists" ok $?
amend=$(cat "$AMEND" 2>/dev/null)
grep -qF 'references/amend-mode.md' "$STORY" 2>/dev/null
check "C3b user-story SKILL.md lists the new reference" ok $?

# C4 · the entry gate is story-readiness itself, and each of its three outcomes
# has named handling. No second conformance test is invented.
gate=$(sec "$AMEND" '^## The entry gate' '^## [^T]')
grep -qF 'story-readiness' <<<"$gate"
check "C4a the entry gate is story-readiness, not a new test" ok $?
grep -q 'PASS' <<<"$gate" && grep -q 'NOT READY' <<<"$gate" \
  && grep -qiE 'bad link|invalid gid' <<<"$gate" && grep -qiE 'no access' <<<"$gate"
check "C4b all three gate outcomes handled (PASS / NOT READY / bad link + no access)" ok $?

# C4c · empty-body routing is MODE SELECTION, and it must happen BEFORE the gate.
# story-readiness scores an empty description NOT READY, and the NOT READY branch
# refuses every amend — so an empty task gated first gets refused instead of
# authored. The routing therefore cannot live among the gate's own branches.
pre=$(sec "$AMEND" '^## Before the gate' '^## The entry gate')
grep -qiE 'mode a' <<<"$pre" && grep -qiE 'empty description' <<<"$pre"
check "C4c an empty description routes to Mode A" ok $?
grep -qiE 'ahead of|before' <<<"$pre" && grep -qF 'NOT READY' <<<"$pre"
check "C4d the routing is stated as pre-gate, naming the NOT READY collision" ok $?
! grep -qiE 'empty description' <<<"$gate"
check "C4e empty description is not one of the gate's own branches" ok $?

# C5 · NOT READY refuses with the gate's own gap list, and cannot be overridden.
grep -qiE 'refuse|refused' <<<"$gate" && grep -qiE 'gap list' <<<"$gate"
check "C5a NOT READY refuses and prints the gap list" ok $?
grep -qiE 'no override' <<<"$amend"
check "C5b the refusal has no override" ok $?

# C6 · mid-build: the contract is changing under a developer, and the
# confirmation is separate from the push approval.
mid=$(sec "$AMEND" '^## Mid-build' '^## ')
grep -qF 'Development' <<<"$mid" && grep -qF 'Testing' <<<"$mid"
check "C6a mid-build is detected from the Development / Testing subtasks" ok $?
grep -qiE 'separate' <<<"$mid" && grep -qiE 'does not imply|not the push approval|distinct from' <<<"$mid"
check "C6b the mid-build go is separate from the push approval" ok $?

# C7 · the draft is a diff, not a story. All five parts shown before any push.
diff=$(sec "$AMEND" '^## Draft the diff' '^## ')
grep -qiE 'untouched' <<<"$diff" && grep -qiE 'changed' <<<"$diff" \
  && grep -qiE 'new .?\[AC\]' <<<"$diff" && grep -qiE 'reworded' <<<"$diff"
check "C7a the diff shows untouched, changed, new and reworded parts" ok $?
grep -qiE 'never a (full |whole-body )?rewrite|not a rewrite' <<<"$amend"
check "C7b a wholesale rewrite is ruled out explicitly" ok $?

# C8 · additive rules. Nothing is deleted, renumbered, or silently reworded,
# and no subtask is ever ticked by this mode.
add=$(sec "$AMEND" '^## Additive rules' '^## ')
grep -qiE 'never delete' <<<"$add" && grep -qiE 'never renumber' <<<"$add" \
  && grep -qiE 'never drop' <<<"$add"
check "C8a no section deleted, no renumbering, no [AC] dropped" ok $?
grep -qiE 'only where the PM|only when the PM' <<<"$add" && grep -qiE 'byte-identical' <<<"$add"
check "C8b an existing [AC] is reworded only on a naming instruction" ok $?
grep -qiE 'never tick|never complete' <<<"$add"
check "C8c amend mode never ticks or completes a subtask" ok $?

# C9 · every follower of the task is tagged on it, by the documented mention
# mechanics, with the name list visible in the draft. No role filtering — a
# follower list sorted into "dev" and "QA" would be a guess.
tag=$(sec "$AMEND" '^## Tag ' '^## [^T]')
grep -qiE 'every follower|all followers' <<<"$tag" && grep -qiE 'do not filter|never filter' <<<"$tag"
check "C9a the tag comment mentions every follower, unfiltered" ok $?
# Anchored to the empty-list bullet: "ask the PM" now appears twice in this
# section (the unformable-mention bullet asks too), so a section-wide grep
# stayed green with the empty-list rule deleted outright.
emptyf=$(flat "$(sed -n '/^- \*\*The list is empty\*\*/,/^- \*\*A mention/p' "$AMEND")")
grep -qiE 'ask the PM who should be following' <<<"$emptyf" \
  && grep -qiE 'never push a bare' <<<"$emptyf"
check "C9d an empty follower list stops and asks, never invents names" ok $?
grep -qE 'CC:' <<<"$tag" && grep -qiE 'last line' <<<"$tag"
check "C9e followers are carried on a closing CC: line" ok $?
# The worked example must actually END on the CC: line — a rule stated in prose
# but contradicted by the sample is the version people copy.
# Both fence lines are stripped with grep: BSD sed rejects `$!{...}` without a
# separator before the brace, which made the earlier one-liner error out and
# report FAIL on macOS no matter what the file said.
[[ "$(sed -n '/^```output/,/^```$/p' <<<"$tag" | grep -v '^```' | tail -1)" =~ ^CC: ]]
check "C9f the example comment's final line is the CC: line" ok $?
# A plain-text name is not a mention and notifies nobody, so there is no
# plain-text fallback here: an unformable mention stops the write instead of
# producing a CC: line that only looks tagged.
tagf=$(flat "$tag")
grep -qF 'data-asana-gid' <<<"$tagf" && grep -qiE 'not a[* ]+mention' <<<"$tagf" \
  && grep -qiE 'stop before the[* ]+write' <<<"$tagf"
check "C9b an unformable mention stops the write, never degrades to plain text" ok $?
# Cited by the skill's public entry, not by a path into its references/ — a
# role plugin depends on raftkit-core's SKILL.md, never on its internals.
grep -qF '`raftkit-core/asana-formatting`' <<<"$tagf" \
  && grep -qiE 'not re-authored' <<<"$tagf"
check "C9c mention rules are cited via raftkit-core/asana-formatting, not re-authored" ok $?

# C10 · the loop closes: the gate is re-run on the amended story and its
# verdict reported. Both anchored to the closing section — 'verdict' also appears
# in the entry gate ("branch on its verdict") and 're-audit' matches the sample
# output line, so file-wide greps stayed green with the whole section deleted.
closef=$(flat "$(sed -n '/^## Close the loop/,$p' "$AMEND")")
grep -qiE 're-?run [^.]{0,20}story-readiness' <<<"$closef"
check "C10a story-readiness is re-run after the push" ok $?
grep -qiE 'report its \*\*verdict\*\*' <<<"$closef"
check "C10b the re-audit verdict is reported back" ok $?

# C11 · the push itself: gated, formatted, verified, and authorized to
# overwrite a description. Anchored to the push section: 'explicit' also matches
# the mid-build "separate explicit go", which kept a file-wide grep green with
# the authorization sentence gone.
pushf=$(flat "$(sec "$AMEND" '^## The push' '^## ')")
grep -qF 'write-protocol' <<<"$pushf"
check "C11a the push runs through write-protocol" ok $?
grep -qiE 'read the result back' <<<"$pushf" \
  && grep -qF '`raftkit-core/asana-formatting`' <<<"$pushf"
check "C11b the render is read back and verified" ok $?
# Core overwrites a description only on an instruction that names it, and
# write-protocol forbids extending that entry by analogy — so the authorization
# has to be the approved diff, not the word "amend". Anchored to the push
# section: 'explicit' also matches the mid-build "separate explicit go".
grep -qiE 'wholesale|no partial edit' <<<"$pushf" \
  && grep -qiE 'an amend request is not one' <<<"$pushf" \
  && grep -qiE 'no changed sections [^.]{0,40}no description[* ]+write' <<<"$pushf"
check "C11c the description overwrite is authorized by the approved diff, not the amend request" ok $?

# C11d/C11e · the three writes are not atomic. A failure after the description
# lands leaves a half-amended task, and the confirmation block would still claim
# success. Honest reporting is the contract; a blind [AC] retry duplicates it.
grep -qiE 'not one[* ]+transaction' <<<"$pushf" \
  && grep -qiE 'report what landed' <<<"$pushf"
check "C11d a partial push reports what landed instead of confirming success" ok $?
grep -qiE 'blind retry duplicates' <<<"$pushf"
check "C11e an [AC] create is never blind-retried" ok $?

# C12 · story-readiness documents its new role without changing its own
# contract.
guard=$(sec "$READY" '^## Guardrails' '^## ')
grep -qiE 'amend' <<<"$guard"
check "C12a story-readiness guardrails name the amend-mode entry gate" ok $?
# Anchored to the amend bullet itself. "binary, read-only" already sat in this
# section before this PR, so a section-wide grep passed with the new bullet's
# own read-only promise stripped out.
amendbullet=$(flat "$(sed -n '/^- \*\*This gate is also `user-story` amend mode/,/^- \*\*Plain English/p' "$READY")")
grep -qiE 'the gate stays[* ]+read-only' <<<"$amendbullet"
check "C12b the amend bullet keeps story-readiness read-only" ok $?
# The empty-description carve-out must be named here too, or this file and
# amend-mode.md state incompatible versions of the same NOT READY contract.
grep -qiE 'non-empty' <<<"$amendbullet" && grep -qiE 'never reaches it' <<<"$amendbullet"
check "C12c the amend bullet names the pre-gate empty-description routing" ok $?

# C13 · the help table tells a PM the mode exists. Anchored to the "Use it when"
# cell of the user-story row — [^|]* stops at the next column. A file-wide grep
# matched the core-loop diagram above, and a whole-row grep matched the "extend
# <task-url>" example in the Say cell, so both stayed green with the row's own
# description of amending removed.
grep -qiE '^\| `user-story` \| [^|]*amend' "$HELP" 2>/dev/null
check "C13 the help Skills table row says user-story amends an existing story" ok $?

# C14 · content only reaches installed machines via a version bump. A floor, not
# a pin: amend mode ships in raftkit-pm 0.17.0, so the manifest must sit at or
# above it. The merge-base-anchored bump gate is scripts/validate.sh's job —
# restating it here would turn this suite red on the next legitimate release.
node -e '
  const fs = require("fs");
  const v = JSON.parse(fs.readFileSync("'"$MANIFEST"'", "utf8")).version.split(".").map(Number);
  const min = [0, 17, 0];
  process.exit((v[0]-min[0] || v[1]-min[1] || v[2]-min[2]) >= 0 ? 0 : 1);
'
check "C14 raftkit-pm version is at least 0.17.0" ok $?

# C15 · amend mode is not a shortcut around the live-template rule. It does not
# fetch the template itself — it inherits the gate's live audit — so the check is
# anchored to the gate section and to the exact phrase. A bare 'live' also
# matches "delivered" and "lives", which kept the old check green regardless.
gatef=$(flat "$gate")
grep -qiE '\*\*live\*\* Feature Template' <<<"$gatef" \
  && grep -qF 'workflow-constants' <<<"$gatef"
check "C15 the format authority is the gate's live template fetch, never a cached copy" ok $?

echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all user-story amend-mode checks passed"
