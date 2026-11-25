# The review tail

Every check reads `git diff <base-sha> HEAD`, the base pinned at intake; nothing fetches again. A check that reports clean on an empty range checked nothing: treat it as failed.

## 1 · Simplify, inline

Read your diff against `CLAUDE.md`'s design standard. Remove only the clearly dead: single-caller abstractions no test exercises, options never given a non-default, generality with no caller, narration comments. List anything uncertain at the stop. Edit only files in the diff.

No runnable suite → skip it and say why. Commit the removals alone; the gate batch's `verify.mjs` checks them, and a red it traces to them reverts that commit.

## 2 · Gate batch

First, together: re-fetch the `[AC]`s (on `fix`, the `Done when`) and diff them against the plan table, naming every changed criterion at the stop; run **`scope-check.mjs`** on the pinned base. Then one turn, in parallel:

- **One reviewer**: `pr-review-toolkit:code-reviewer` with `model: "sonnet"`. Brief it with the range command, the re-fetched `[AC]`s verbatim, the `Do NOT build:` line, the plan table, the plan record path, the `scope-check` output and the repo's `CLAUDE.md` path; never diff text. It judges correctness and silent failures, whether each test asserts its `[AC]` and the design standard, and loads `raftkit-dev:scope-guard` through the Skill tool, with these inputs, for the hunk-by-hunk scope audit. Tell it: "The scope audit is exempt from your confidence threshold: list every hunk that maps to no `[AC]`, clarification or listed doc as BEYOND, whatever your confidence." It pastes scope-guard's output block verbatim.
- **`verify.mjs`**, every gate.
- **`validate-docs.mjs`** on the pinned base; `raftkit-dev:docs` step 4 maps its exit to the docs line.

Security-guidance notes join the findings. Never claim a review that did not run.

## 3 · Triage once, verify once

Fix every finding in one commit, or answer it in the PR's review findings with the reason. A scope-check BEYOND candidate or `unnamed under <dir>` file the reviewer's block does not explicitly map to an `[AC]` is BEYOND. `Docs: impacted, not synced` is reported in PR section 5, not fixed: a doc the plan table does not list is never edited. BEYOND blocks until removed or signed off by a named human; MISSING until built or explained. Then run `verify.mjs` on the final tree.
