#!/usr/bin/env bash
# Deterministic contract suite for the Gate 0 clarification loop
# (M3 · raftkit-dev, Asana 1216941491646670). Placement-aware: seams must
# appear in their owning section, not merely somewhere in a file.
#
# AC -> evidence matrix (behavioral eval bundle authored pre-implementation
# and structurally verified; plugin/no-plugin EXECUTION deferred to the final
# plugin-evaluation story):
#   AC-1  three Gate 0 verdicts ............ C1
#   AC-2  four-branch gap classification ... C2            + evals
#   AC-3  one-round interview discipline ... C3
#   AC-4  refusal stands ................... C4a           + evals
#   AC-5  commercial gap escalates ......... C4b           + evals
#   AC-6  answer-adds-scope rejected ....... C4c           + evals
#   AC-7  Decision Log format .............. C5
#   AC-8  coverage-closing AC + no desc-edit C6
#   AC-9  log-write hard stop .............. C7            + evals
#   AC-10 Path C stub-to-story .............. C8            + evals
#   AC-11 Gate 1 spec+scope carry clarif. ... C9
#   AC-12 scope-guard third mapping surface  C10
#   AC-13 pr permalink / readiness note / manifests  C11, C12, C13
#   AC-14 deterministic tests red-first .... this suite (red captured pre-edit)
#   AC-15 eval bundle authored ............. C15 (structural + no-leak)
#   AC-16 manifests / diff allowlist ....... C14, C16 (+ scripts/validate.sh)
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

DEV=plugins/raftkit-dev/skills
PM=plugins/raftkit-pm/skills
sec() { sed -n "/$2/,/$3/p" "$1" 2>/dev/null; }

# C14 · file allowlist. The persistent suite tests the ALGORITHM against
# synthetic changed-file lists (no branch SHAs — squash-safe). The real PR
# range audit is explicit and caller-supplied:
#   bash tests/implement-clarification.test.sh --scope-check <base> <head>
allow='^(tests/implement-clarification\.test\.sh|plugins/raftkit-dev/evals/clarification/.*|plugins/raftkit-dev/\.claude-plugin/plugin\.json|plugins/raftkit-pm/\.claude-plugin/plugin\.json|plugins/raftkit-dev/commands/help\.md|plugins/raftkit-dev/skills/implement/(SKILL\.md|references/(clarification|gates|execution)\.md)|plugins/raftkit-dev/skills/scope-guard/(SKILL\.md|references/audit-method\.md)|plugins/raftkit-dev/skills/pr/references/raise-flow\.md|plugins/raftkit-pm/skills/story-readiness/SKILL\.md)$'
if [[ "${1:-}" == "--scope-check" ]]; then
  base="${2:-}"; head="${3:-}"
  [[ -n "$base" && -n "$head" && "$base" != -* && "$head" != -* ]] || { echo "scope-check requires <base> <head> commits"; exit 2; }
  git rev-parse --verify --quiet "$base^{commit}" >/dev/null || { echo "scope-check: invalid or unreachable base '$base'"; exit 2; }
  git rev-parse --verify --quiet "$head^{commit}" >/dev/null || { echo "scope-check: invalid or unreachable head '$head'"; exit 2; }
  git merge-base --is-ancestor "$base" "$head" || { echo "scope-check: reversed or disjoint range $base..$head"; exit 2; }
  changed="$(git diff --name-only "$base" "$head" --)"
  echo "scope-check $base..$head — changed files:"; printf '%s\n' "$changed"
  viol="$(grep -Ev "$allow" <<<"$changed" || true)"
  if [[ -n "$viol" ]]; then printf 'ALLOWLIST VIOLATIONS:\n%s\nscope-check: FAIL\n' "$viol"; exit 1; fi
  echo "scope-check: PASS — every changed file is inside the approved allowlist"
  exit 0
fi

syn_ok=$'tests/implement-clarification.test.sh\nplugins/raftkit-dev/skills/implement/references/clarification.md\nplugins/raftkit-dev/evals/clarification/case/prompt.md\nplugins/raftkit-pm/skills/story-readiness/SKILL.md'
[[ -z "$(grep -Ev "$allow" <<<"$syn_ok" || true)" ]]
check "C14a allowlist admits approved paths (synthetic)" ok $?
syn_bad=$'plugins/raftkit-dev/skills/docs/SKILL.md\nplugins/raftkit-pm/skills/user-story/SKILL.md\nplugins/raftkit-dev/skills/setup-project/SKILL.md'
[[ "$(grep -Ev "$allow" <<<"$syn_bad" | wc -l | tr -d ' ')" == 3 ]]
check "C14b allowlist flags every out-of-scope path (synthetic)" ok $?

# C1 · gates.md Gate 0 section states all three verdicts.
g0=$(sec "$DEV/implement/references/gates.md" '^## Gate 0' '^## Gate 1')
grep -q 'READY (clarified)' <<<"$g0" && grep -q 'NOT READY' <<<"$g0" \
  && grep -qE '(^|[^(])READY([^ ]| .{0,3}proceed)' <<<"$g0"
check "C1 Gate 0 section names READY / READY (clarified) / NOT READY" ok $?

# C2 · new clarification.md reference exists and is named from gates.md +
# implement's own reference list, and states all four gap-classification
# branches.
[[ -f "$DEV/implement/references/clarification.md" ]]
check "C2a clarification.md exists" ok $?
clar=$(cat "$DEV/implement/references/clarification.md" 2>/dev/null)
grep -q 'references/clarification.md' "$DEV/implement/SKILL.md" 2>/dev/null
check "C2b implement SKILL.md lists the new reference" ok $?
grep -qi 'dev-answerable' <<<"$clar" && grep -qi 'founders' <<<"$clar" \
  && grep -qi 'refusal stands' <<<"$clar" && grep -qi 'scope change\|scope-change' <<<"$clar"
check "C2c clarification.md states all four gap-classification branches" ok $?

# C3 · one-round interview discipline, citing (not re-authoring) fix-bug's
# four-asks discipline.
grep -qi 'one round\|one-round' <<<"$clar" && grep -qi 'one follow-up' <<<"$clar" \
  && grep -qi 'nothing.*inferred\|never.*infer' <<<"$clar" \
  && grep -qF 'fix-bug/references/bug-intake-and-handback.md' <<<"$clar"
check "C3 one-round interview discipline cites fix-bug's four-asks precedent" ok $?

# C4 · the three non-dev-answerable classes each have distinct handling.
grep -qi 'refusal stands' <<<"$clar" && grep -qi 'no override' <<<"$clar"
check "C4a refusal-stands class documented with no override" ok $?
grep -qi 'commercial\|client.impact' <<<"$clar" && grep -qi 'escalat.*founder\|founder.*escalat' <<<"$clar"
check "C4b commercial/client-impact class escalates to founders" ok $?
grep -qi 'adds.*work no.*ac\|uncovered work\|ac-uncovered' <<<"$clar" \
  && grep -qi 'route.*pm\|back to the pm\|board' <<<"$clar"
check "C4c answer-adds-scope class routes to PM/board, not logged as a clarification" ok $?

# C5 · the Decision Log write: exactly one comment per run, exact header,
# write-protocol draft->approve->push, [AC] subtask drafting on coverage
# holes.
grep -qF 'Gate 0 clarification log — /implement' <<<"$clar"
check "C5a exact Decision Log header string present" ok $?
grep -qi 'one.*comment per.*run\|not one per gap' <<<"$clar" && grep -qi 'write-protocol' <<<"$clar"
check "C5b one comment per run, routed through write-protocol" ok $?

# C6 · coverage-closing answers draft a missing [AC] subtask; the story
# description is never touched on Path B.
grep -qi 'draft.*\[AC\]\|missing \[AC\]' <<<"$clar" && grep -qi 'description.*never touched\|never touch.*description' <<<"$clar"
check "C6 coverage-closing AC drafting + description-untouched rule" ok $?

# C7 · the log-write hard stop is the exact string, with no override.
grep -qF 'Clarifications not logged — the decision would live only in this chat. /implement stops here.' <<<"$clar"
check "C7a exact hard-stop string present" ok $?
grep -qi 'no.*proceed.*without.*log\|no proceed-without-logging' <<<"$clar"
check "C7b no proceed-without-logging override stated" ok $?

# C8 · Path C: a title-only (empty-description) stub is written to Asana before
# code, then re-audited by story-readiness.
grep -qi 'path c' <<<"$clar" && grep -qi 'title-only\|empty description' <<<"$clar" \
  && grep -qi 'before any code\|before code' <<<"$clar" && grep -qi 'story-readiness' <<<"$clar"
check "C8 Path C writes the stub to Asana before code, then re-audits" ok $?

# C8b · misclassification guard: a story with real narrative content but zero
# [AC]s is Path B (clarify + draft the missing ACs), never Path C (dev
# rewrites the whole story) — Path C requires an empty description, full stop.
g0=$(sec "$DEV/implement/references/gates.md" '^## Gate 0' '^## Gate 1')
grep -qi 'never Path C merely because it lacks' <<<"$clar" \
  && grep -qi 'not a stub' <<<"$g0" && grep -qi 'not this one' <<<"$g0"
check "C8b real-content-zero-AC story is Path B, not Path C" ok $?

# C8c · the two files' Path C tests must not diverge — clarification.md may
# not loosen gates.md's byte-empty test with a "placeholder-only" (or any
# other fuzzy) carve-out; both must state the same "full stop" test.
! grep -qi 'or placeholder-only\|placeholder-only) description' <<<"$clar"
check "C8c clarification.md carries no placeholder-only carve-out on Path C" ok $?
grep -qi 'full stop' <<<"$clar" && grep -qi 'full stop' <<<"$g0"
check "C8d both files state the same byte-empty \"full stop\" test for Path C" ok $?

# C8e · Path B's READY (clarified) verdict must be Gate 0's own reconciliation,
# never a claimed story-readiness re-audit — story-readiness reads only the
# description and subtasks, never comments, and Path B never touches the
# description, so a re-audit there would loop on NOT READY forever.
grep -qi 'does not.*re-run.*story-readiness\|does \*\*not\*\* re-run' <<<"$clar" \
  && grep -qi 'never reads comments' <<<"$clar" \
  && grep -qi 'own reconciliation' <<<"$g0"
check "C8e Path B verdict is Gate 0's own reconciliation, not a story-readiness re-audit" ok $?

# C17 · the allowlist regex is anchored — an approved path with an extra
# suffix (e.g. a stray .bak file) must NOT slip through as an approved path.
! grep -E "$allow" <<<"tests/implement-clarification.test.sh.bak" | grep -q .
check "C17 allowlist regex rejects a suffixed variant of an approved path" ok $?

# C9 · Gate 1's scope contract + the spec file's Clarifications section carry
# logged clarifications by permalink.
g1=$(sec "$DEV/implement/references/gates.md" '^## Gate 1' '^## Gate 2')
grep -qi 'clarification' <<<"$g1" && grep -qi 'permalink' <<<"$g1"
check "C9a Gate 1 scope contract cites clarifications by permalink" ok $?
sec "$DEV/implement/references/execution.md" '^## No spec, no code' '^## Pre-edit baseline' | grep -qF '## Clarifications (Gate 0)'
check "C9b spec file gains the Clarifications (Gate 0) section" ok $?

# C10 · scope-guard's third mapping surface — a permalink-cited clarification
# maps a hunk instead of landing in BEYOND.
sec "$DEV/scope-guard/SKILL.md" '^## Run flow' '^## Guardrails' | grep -qi 'permalink.cited.*clarification\|gate-0 clarification'
check "C10a scope-guard SKILL.md's mapping step names the clarification surface" ok $?
am=$(sec "$DEV/scope-guard/references/audit-method.md" '^## Mapping each changed item' '^## Documentation edits map like code')
grep -qi 'clarification' <<<"$am" && grep -qi 'permalink' <<<"$am"
check "C10b audit-method.md requires a permalink, never chat-only, to admit a clarification" ok $?

# C11 · pr's Story-link section names the Decision Log permalink.
desc=$(sec "$DEV/pr/references/raise-flow.md" 'mandatory sections' '^## Push')
grep -qi 'decision log' <<<"$desc" && grep -qi 'permalink' <<<"$desc"
check "C11 pr Story-link section carries the Decision Log permalink" ok $?

# C12 · story-readiness carries a note on the dev-side seam without changing
# its own binary, read-only verdict.
sr=$(sec "$PM/story-readiness/SKILL.md" '^## Guardrails' '^## Reference file')
grep -qi 'implement.*clarif\|dev-side.*gate 0\|gate 0.*clarif' <<<"$sr" \
  && grep -qi 'binary\|PASS.*NOT READY' <<<"$sr" && grep -qi 'read-only' <<<"$sr"
check "C12 story-readiness notes the seam; verdict stays binary and read-only" ok $?

# C13 · help.md mentions the clarification path in the core loop / implement row.
grep -qi 'clarif' plugins/raftkit-dev/commands/help.md 2>/dev/null
check "C13 help.md mentions the clarification path" ok $?

# C15 · eval bundle: authored, structural, no answer leakage.
n=$(find plugins/raftkit-dev/evals/clarification -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[[ "${n:-0}" -ge 6 ]] \
  && ! find plugins/raftkit-dev/evals/clarification -mindepth 1 -maxdepth 1 -type d '!' -exec test -f '{}/prompt.md' ';' -print | grep -q . \
  && ! find plugins/raftkit-dev/evals/clarification -mindepth 1 -maxdepth 1 -type d '!' -exec sh -c 'ls "$1"/graders/*.md >/dev/null 2>&1' _ '{}' ';' -print | grep -q .
check "C15a >=6 eval cases each with prompt.md + graders" ok $?
! grep -l 'READY (clarified)\|Clarifications not logged' plugins/raftkit-dev/evals/clarification/*/prompt.md 2>/dev/null | grep -q .
check "C15b prompts do not leak the expected verdict/hard-stop copy" ok $?

# C16 · manifests: version bumps held for this story.
node -e '
  const v = JSON.parse(require("fs").readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json","utf8")).version.split(".").map(Number);
  const min = [0, 22, 0];
  const cmp = v[0] - min[0] || v[1] - min[1] || v[2] - min[2];
  process.exit(cmp >= 0 ? 0 : 1);
'
check "C16a raftkit-dev version is at least 0.22.0" ok $?
node -e '
  const v = JSON.parse(require("fs").readFileSync("plugins/raftkit-pm/.claude-plugin/plugin.json","utf8")).version.split(".").map(Number);
  const min = [0, 13, 0];
  const cmp = v[0] - min[0] || v[1] - min[1] || v[2] - min[2];
  process.exit(cmp >= 0 ? 0 : 1);
'
check "C16b raftkit-pm version is at least 0.13.0" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
