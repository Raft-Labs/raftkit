# Gate 0 clarification — the dev answers, Asana keeps the decision

Gate 0 was a hard refuse-or-proceed with no middle path: a gap the developer could
answer in ten seconds bounced to the PM exactly like one nobody could answer. This
reference adds the middle path — **ask the dev when the gap is theirs to answer, and
write the confirmed answer to the story before any code is touched.** The chat is
never the record; Asana is.

## Three entry paths, decided on entry

The branch is deterministic, the same way `fix-bug`'s Path A/B split is
(`fix-bug/references/bug-intake-and-handback.md`):

- **Path A · ready.** `story-readiness` returns PASS. Unchanged — proceed straight to
  Gate 1.
- **Path B · gaps.** `story-readiness` returns NOT READY on a story that has a real
  body — a description with actual content, per `story-readiness`'s own "empty
  description" test (`readiness-checklist.md` step 2). This is Path B **even when
  the gap is "no `[AC]` subtasks at all"** — a PM-authored story missing its ACs is
  still a PM-authored story; the dev-answered-and-drafted `[AC]` mechanism below
  handles it exactly like any other coverage hole. Never mistake "no ACs yet" for
  "no story" — the test below is the only thing that makes it Path C, nothing looser.
- **Path C · dev-shaped.** The story is a **title-only stub — an empty description,
  full stop**, the same byte-empty test `story-readiness` itself uses
  (`readiness-checklist.md` step 2: "the task has no story body") — not "thin,"
  not "mostly placeholders," not any other judgment call on how filled-in it looks.
  A duplicated-template story whose fields are still `{...}` is **not** empty and
  is **not** Path C either — it has bytes, so it audits normally below and comes
  back NOT READY with a gap for every unfilled section, which Path B's one-round
  interview then works through like any other gap set. A story with real narrative
  content is never Path C merely because it lacks ACs — that is Path B, above;
  rewriting a described story's contract from a dev's say-so would be the exact
  description-overwrite `write-protocol` forbids without explicit instruction.
  For a genuine stub: do not run a readiness audit against nothing; instead the dev
  states the contract in session, it is written to Asana as a real description plus
  `[AC]` subtasks (draft → approve → push, per `write-protocol`), and **only then**
  is the now-real story re-audited by `story-readiness` before planning proceeds. A
  stub that gets waved through on the conversation alone, with
  no re-audit, is exactly the failure this path exists to prevent.

## Gap classification — ask, escalate, refuse, or reject as scope

Before asking anything, classify each gap in the NOT READY list. Four outcomes,
never blended:

1. **Dev-answerable** — a specification detail the dev can state authoritatively: a
   WEESLD row, an exact copy string, a permission boundary, an out-of-scope item, or
   the intended meaning of an ambiguous `[AC]`. Ask it in the round below.
2. **Commercial or client-impacting** — pricing, contractual behaviour, anything that
   reads as a client commitment. Never asked to the dev as a clarification —
   **escalate to founders** per `house-rules` and hold the story there.
3. **Refusal stands** — the dev cannot or will not answer ("you decide", "whatever's
   standard", silence). This is not a lighter bar than Gate 0's existing refusal —
   it *is* that refusal. **No override.** The gap list is posted for the PM exactly
   as it is today.
4. **Scope change, not a clarification** — the dev's answer adds AC-uncovered work
   (no existing `[AC]` describes it). An answer is not free-form license to add
   scope; it closes a gap or it is not a clarification at all. Reject it as a
   clarification and route it back to the PM, or to the board as a proposal — the
   original gap stays open until answered on its own terms.

## The one-round interview

Ask every dev-answerable gap **together, in one round** — not gap by gap. Never infer
or default an answer: a guessed WEESLD row is a fabricated contract, no different in
kind from a fabricated repro step. One follow-up is allowed per vague answer; if it is
still not pinned down after that, it is an unanswered gap and Refusal-stands applies.
This mirrors `fix-bug`'s four-asks discipline exactly
(`fix-bug/references/bug-intake-and-handback.md`) — cite it, do not re-author it.
Confirm the full answer set back to the dev before drafting anything.

## The Decision Log — one comment per run, not one per gap

Once the answer set is confirmed, draft **exactly one** comment for the story,
through `write-protocol` (draft → approve → push) and `asana-formatting`. Answers go
in verbatim, never paraphrased:

```
Gate 0 clarification log — /implement
Cleared by: <dev> · <date>
Gap: <section/field> — <what was missing>
  Q: <the question asked>
  A: <the dev's answer, verbatim>
Gap: …
Readiness: READY (clarified) — <n> closed here, <m> satisfied by the story.
```

Where an answer closes an `[AC]` coverage hole, additionally draft the missing `[AC]`
subtask(s) for approval in the same round — so the live contract
`scope-guard` reads at Gate 2 actually contains them. The story's **description is
never touched** on Path B; only Path C writes a description, and only because the
story had none.

## The log is a precondition, not a courtesy

If the comment cannot be pushed — a connector failure, or the dev declines the
write — the run stops. There is **no proceed-without-logging override**:

```
Clarifications not logged — the decision would live only in this chat. /implement stops here.
```

A connector outage may be retried; declining the write is not a lighter path to
"proceed anyway" — it is this stop. This deliberately differs from `fix-bug` Path B,
where declining the *optional* bug record is fine because the fix is already green
and the PR is the record. Here nothing has been built yet — the log is the only
record that would exist.

## Gate 0's verdict

Three verdicts, replacing the old two:

- **READY** — the story passed `story-readiness` on its own (Path A).
- **READY (clarified) — `<n>` gap(s) closed in session, `<m>` satisfied by the
  story** — the Decision Log's permalink is named alongside it (Path B or C, once
  the log is pushed and the story re-audited).
- **NOT READY** — refused, gap list posted for the PM. Unchanged.

## Propagation — without this, clarifying is decorative

A clarification that Gate 1 and Gate 2 don't recognize gets flagged BEYOND at Gate 2
for no reason. See `references/gates.md` for exactly where this lands:

- **Gate 1** — the scope contract is `[AC]`s **plus the logged clarifications**,
  cited by the Decision Log's permalink; the spec file gains its own
  `## Clarifications (Gate 0)` section carrying the same entries.
- **Gate 2 / `scope-guard`** — a third mapping surface, alongside an `[AC]` and the
  Docs Impact Plan: a hunk that maps to a **permalink-cited** Gate-0 clarification is
  not BEYOND. `scope-guard` never accepts "the dev said so" without the permalink.
- **`pr`** — the Story-link section also names the Decision Log permalink when Gate 0
  was clarified or ran Path C.
