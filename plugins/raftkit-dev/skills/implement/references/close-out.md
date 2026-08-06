# Close out — raise, link, and the write-failure fallback

The final step, reached only once Gate 2 is clean. `implement` does **not** raise
the PR or write to Asana itself — it hands both to the `pr` skill and reports the
outcome in its own success line.

## Delegate the raise to `pr`

Hand off to `raftkit-dev/pr` and let it own its full contract — squash-target
resolution, the commitlint title, the four description sections, the pre-push
hook, pr-review-toolkit, and the Asana close-out (the `Development`
tick and the PR-link comment). That contract is defined in `raftkit-dev/pr`; do
**not** restate or re-implement it here — a copy drifts from the source.
`implement` invokes `pr`, it does not duplicate it. Merging stays human — neither
skill merges or approves its own PR.

Two seams matter to `implement`:

- **Code review runs once, in `pr`.** Gate 2 checks docs parity and scope
  only; automated code review (pr-review-toolkit) happens downstream as part
  of `pr`'s own flow (`pr/references/automated-review.md`) — `implement` does
  not run it a second time.
- **The close-out is `pr`'s; confirming it is `implement`'s** — see the fallback
  below.

## Success line

On a clean raise with the close-out written, report `implement`'s own success line
(this string is `implement`'s, distinct from `scope-guard`'s clean line and `pr`'s
review line):

```output
PR #n raised — link on the story, Development ticked. Suite green: X tests. Scope-guard: clean.
```

Fill `n` with the PR number and `X` with the suite's passing-test count.

## Asana write-failure fallback (error state)

`implement` confirms the close-out after the hand-off: `pr` surfaces its
close-out result — the `Development` tick and the PR-link comment. **If either
write failed, or its status comes back unknown, `implement` emits the manual-link
fallback.** That is the AC's deterministic trigger — confirmation after the
hand-off, not an implicit hope that `pr` succeeded. A failed Asana write never
rolls back the raised PR; **the PR still completes.**

The fallback tells the dev exactly what to paste manually, self-contained enough
to act on without re-deriving anything:

- the **story task URL** to open,
- the **PR URL** to paste as a comment,
- and a reminder to **tick the `Development` subtask** by hand.

The run is not a failure in this state: the code shipped and the PR is open; only
the bookkeeping needs a manual hand. Report it plainly with the paste-ready text.


## Asana rendering

All Asana output is rendered and verified through core `asana-formatting` (per-surface tag matrix, markdown→HTML conversion, mentions, read-back verification), behind the `write-protocol` draft → approve → push gate.
