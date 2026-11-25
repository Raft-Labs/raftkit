# Story readiness

Judge against the Feature Template fetched this run: its sections, edge-case rows and header fields. Anything unconfirmed is a gap. Any gap ⇒ **NOT READY**; no partial pass.

## The six gap types

| # | Gap | Ready means |
|---|---|---|
| 1 | Missing edge-case row | every template row answered (`N/A` counts; blank or `{…}` does not); a row marked most important gives the exact message and recovery action |
| 2 | No exact copy | every string the user reads is given verbatim |
| 3 | No permission rule | who may act and who is blocked, both stated |
| 4 | No out-of-scope item | at least one concrete out-of-scope item |
| 5 | `[AC]` coverage hole | `[AC]`s cover the happy path, every edge-case row, rule and permission boundary |
| 6 | Open question | open questions read `none` or are all answered; `[Unresolved]` is a gap |

## Verdict strings

```output
PASS — ready to hand off.
Coverage: <n> scenarios, <m> acceptance criteria, every edge case covered.
```

```output
NOT READY — <k> gap(s):
- Section <N> "<title>" — <exactly what is missing>
- acceptance criteria coverage — <the uncovered scenario, rule, row or boundary>
Owner: PM.
```

An empty description is one line: `NOT READY — the task description is empty — write the story first.`

Name the section as the live template does, plus the concrete missing thing: `Section 7 "Edge cases" — the Error row is blank; give the exact message and recovery action.`, never `edge cases incomplete.`

## Parsing

- An `[AC]` is a subtask named `[AC] …`, in any order; one still holding `{…}` is a gap.
- `Development`, `Testing`, `Bugs` are containers, not criteria.
- Match sections by number and meaning, not punctuation; take numbering from the live template — an intentional gap is not a missing section.
- Anything unreadable is a gap: say it could not be assessed.
