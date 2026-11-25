# The review tail

After every `[AC]` is green: one inline simplify commit, one gate batch, one triage commit, one final verify. Every check reads `git diff <base-sha> HEAD`, the base pinned at intake; nothing fetches again. A check that reports clean on an empty range checked nothing: treat it as failed.

## 1 · Simplify, inline

Read your own diff against the design standard in the repo's `CLAUDE.md`. Remove only what is clearly dead:

- single-caller abstractions — a seam that a test in the diff exercises stays, and is listed;
- parameters, options and flags never given a non-default;
- speculative generality with no caller in the diff;
- narration comments. Keep every comment that says what the code cannot.

Anything uncertain is listed at the stop, never applied. Never edit a file outside the diff. Commit the removals alone, so the pass reverts cleanly; no empty commit. Red before the pass → skip it and name the failing test. A test that goes red reverts the change that broke it.

## 2 · Gate batch, one turn, all in parallel

- **Re-fetch the `[AC]`s** (on `fix`, the bug's `Done when`) and diff them against the plan table. Name every changed, added or removed criterion at the stop.
- **One reviewer**: `pr-review-toolkit:code-reviewer` with `model: "sonnet"`. Brief it with the range command, the `[AC]`s verbatim, the `Do NOT build:` line, the plan table and the path of the repo's `CLAUDE.md`; never diff text, never the Feature Template. It judges:
  - correctness and silent failures (swallowed errors, empty catches, fallbacks that hide a failure);
  - whether each test asserts its `[AC]`, not merely runs the code;
  - the design standard in `CLAUDE.md`;
  - scope, hunk by hunk, by `raftkit-dev:scope-guard`'s audit, with the `scope-check` flags as candidates. It returns scope-guard's output block exactly.
- **`verify.mjs`** in full: lint, typecheck, suite.
- **`scope-check.mjs`** on the pinned base.
- **`validate-docs.mjs`** on the pinned base; `raftkit-dev:docs` step 4 maps its exit to the docs line.
- The security-guidance notes already emitted. Nothing to invoke; never claim a review that did not run.

## 3 · Triage once

Fix every finding in one commit, or answer it in the PR's review-findings section with the reason. Silence resolves nothing. A BEYOND item blocks until it is removed or signed off by a named human; a MISSING item until it is built or explained. Deferred security-guidance notes land here.

## 4 · Final verify

Run `verify.mjs` once more on the final tree. It is a cache hit when triage committed nothing.
