# Close out — raise, link, and the write-failure fallback

The final step, reached only once Gate 2 is clean. `implement` does **not** raise
the PR or write to Asana itself — it hands both to the `pr` skill and reports the
outcome in its own success line.

## Delegate the raise to `pr`

Hand off to `raftkit-dev/pr`. That skill owns, and this skill does not duplicate:

- **Squash-target resolution** (repo docs → release-train default → refuse); never
  targets `main` directly, never hardcodes a branch.
- **The commitlint-valid title** — the changelog line for this story.
- **The four description sections** — story link · AC checklist · out-of-scope
  confirmation · test summary.
- **The pre-push hook** (surfaced verbatim on failure; never bypassed) and
  pr-review-toolkit + CodeRabbit before a human reviewer is requested.
- **The Asana close-out** — ticking the story's `Development` subtask **and**
  commenting the PR link on the story (`write-protocol`: draft → approve → push).

`implement` invokes `pr` and lets it own those; it does not re-implement any of
them. Merging stays human — neither skill merges or approves its own PR.

## Success line

On a clean raise with the close-out written, report `implement`'s own success line
(this string is `implement`'s, distinct from `scope-guard`'s clean line and `pr`'s
review line):

```
PR #n raised — link on the story, Development ticked. Suite green: X tests. Scope-guard: clean.
```

Fill `n` with the PR number and `X` with the suite's passing-test count.

## Asana write-failure fallback (error state)

If the Asana write fails — the `Development` tick or the PR-link comment cannot be
written (connector down, no access) — **the PR still completes.** A failed Asana
write never rolls back a raised PR. Instead, tell the dev exactly what to paste
manually, self-contained enough to act on without re-deriving anything:

- the **story task URL** to open,
- the **PR URL** to paste as a comment,
- and a reminder to **tick the `Development` subtask** by hand.

The run is not a failure in this state: the code shipped and the PR is open; only
the bookkeeping needs a manual hand. Report it plainly with the paste-ready text.
