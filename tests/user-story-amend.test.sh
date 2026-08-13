#!/usr/bin/env bash
# Deterministic contract suite for user-story amend mode — the PM side of the
# dev/QA -> PM story-gap loop (Asana 1217122967840819). Placement-aware: a seam
# must appear in its owning section, not merely somewhere in a file.
#
# Requirement -> evidence matrix:
#   R-1  two modes, deterministic entry ......... C1, C2
#   R-2  amend reference exists and is linked ... C3
#   R-3  entry gate: four branches .............. C4
#   R-4  NOT READY refuses, no override ......... C5
#   R-5  mid-build needs a separate go .......... C6
#   R-6  diff-first draft, never a rewrite ...... C7
#   R-7  additive [AC] rules, no deletion ....... C8
#   R-8  every follower tagged, unfiltered ...... C9
#   R-9  readiness re-run after the push ........ C10
#   R-10 write-protocol + read-back verify ...... C11
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

# C3 · the amend reference exists and is reachable from SKILL.md.
[[ -f "$AMEND" ]]
check "C3a amend-mode.md exists" ok $?
amend=$(cat "$AMEND" 2>/dev/null)
grep -qF 'references/amend-mode.md' "$STORY" 2>/dev/null
check "C3b user-story SKILL.md lists the new reference" ok $?

# C4 · the entry gate is story-readiness itself, and every one of its four
# outcomes has named handling. No second conformance test is invented.
gate=$(sec "$AMEND" '^## The entry gate' '^## [^T]')
grep -qF 'story-readiness' <<<"$gate"
check "C4a the entry gate is story-readiness, not a new test" ok $?
grep -q 'PASS' <<<"$gate" && grep -q 'NOT READY' <<<"$gate" \
  && grep -qiE 'empty description' <<<"$gate" \
  && grep -qiE 'bad link|invalid gid' <<<"$gate" && grep -qiE 'no access' <<<"$gate"
check "C4b all four entry outcomes handled (PASS / NOT READY / empty / bad link + no access)" ok $?
grep -qiE 'mode a' <<<"$gate"
check "C4c an empty description routes to Mode A, not an amend" ok $?

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
grep -qiE 'empty' <<<"$tag" && grep -qiE 'ask the PM' <<<"$tag"
check "C9d an empty follower list stops and asks, never invents names" ok $?
grep -qE 'CC:' <<<"$tag" && grep -qiE 'last line' <<<"$tag"
check "C9e followers are carried on a closing CC: line" ok $?
# The worked example must actually END on the CC: line — a rule stated in prose
# but contradicted by the sample is the version people copy.
# Both fence lines are stripped with grep: BSD sed rejects `$!{...}` without a
# separator before the brace, so the earlier one-liner errored out and reported
# FAIL on macOS no matter what the file said, while passing under GNU sed in CI.
[[ "$(sed -n '/^```output/,/^```$/p' <<<"$tag" | grep -v '^```' | tail -1)" =~ ^CC: ]]
check "C9f the example comment's final line is the CC: line" ok $?
grep -qF 'data-asana-gid' <<<"$tag" && grep -qiE 'fallback|plain text' <<<"$tag"
check "C9b mention mechanics cite the gid form and its plain-text fallback" ok $?
grep -qF 'asana-formatting/references/mentions.md' <<<"$amend"
check "C9c mention rules are cited, not re-authored" ok $?

# C10 · the loop closes: the gate is re-run on the amended story and its
# verdict reported.
grep -qiE 're-?run .*story-readiness|story-readiness.*again|re-?audit' <<<"$amend"
check "C10a story-readiness is re-run after the push" ok $?
grep -qiE 'verdict' <<<"$amend"
check "C10b the re-audit verdict is reported back" ok $?

# C11 · the push itself: gated, formatted, verified, and authorized to
# overwrite a description.
grep -qF 'write-protocol' <<<"$amend"
check "C11a the push runs through write-protocol" ok $?
grep -qF 'asana-formatting/references/verification.md' <<<"$amend"
check "C11b the render is read back and verified" ok $?
grep -qiE 'wholesale|no partial edit' <<<"$amend" && grep -qiE 'explicit' <<<"$amend"
check "C11c the description overwrite is explicitly authorized and its risk named" ok $?

# C12 · story-readiness documents its new role without changing its own
# contract.
guard=$(sec "$READY" '^## Guardrails' '^## ')
grep -qiE 'amend' <<<"$guard"
check "C12a story-readiness guardrails name the amend-mode entry gate" ok $?
grep -qiE 'read-only' <<<"$guard"
check "C12b story-readiness stays read-only" ok $?

# C13 · the help table tells a PM the mode exists.
grep -qiE 'amend|extend' "$HELP" 2>/dev/null
check "C13 help command names amending an existing story" ok $?

# C14 · content only reaches installed machines via a version bump.
ver=$(node -e 'process.stdout.write(String(require("./'"$MANIFEST"'").version ?? ""))' 2>/dev/null)
[[ -n "$ver" && "$ver" != "0.15.0" ]]
check "C14 raftkit-pm version bumped past 0.15.0 (found: ${ver:-missing})" ok $?

# C15 · amend mode is not a shortcut around the live-template rule.
grep -qiE 'live' <<<"$amend" && grep -qF 'workflow-constants' <<<"$amend"
check "C15 amend mode still fetches the template live every run" ok $?

echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all user-story amend-mode checks passed"
