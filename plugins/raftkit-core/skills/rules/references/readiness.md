# Story readiness — derive from the live template, judge, report

The checklist is derived from the freshly fetched Feature Template every run, never from this page. Read the template's sections, its edge-case rows and its required header fields off the live task, then judge the story against that structure. If the template changes in Asana, the judgment follows the same day.

## Definition of Ready

A story is ready only when every item holds. Anything you cannot confirm is a gap. Any gap ⇒ **NOT READY**. There is no partial pass.

1. **Every edge-case row the template lists has a real answer.** `N/A` counts; a blank or a leftover `{…}` placeholder does not. Where the template marks a row as most important, that row states the exact message the user sees and the recovery action.
2. **Exact user-facing copy is present.** Every string the user reads is given verbatim. "Add appropriate text" is a gap.
3. **The permission boundary is stated both ways.** Who may act and who is blocked.
4. **At least one concrete out-of-scope item.**
5. **`[AC]` coverage is complete.** The `[AC]` subtasks cover the happy path, every edge-case row present, every business rule and every permission boundary.

## The five gap types

| # | Gap | Shows up as |
|---|---|---|
| 1 | Missing edge-case row | a row blank or placeholder, not even `N/A` |
| 2 | No exact copy | a message or label named without its verbatim string |
| 3 | No permission rule | the allowed/blocked boundary missing or one-sided |
| 4 | No out-of-scope item | the non-goals section empty |
| 5 | `[AC]` coverage hole | a scenario, rule, row or boundary with no matching `[AC]` |

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

Each gap line names the section as the live template names it and the concrete missing thing. Good: `Section 6 "Edge cases" — the Error row is blank; give the exact message and recovery action.` Bad: `edge cases incomplete.`

## Parsing

Match `[AC]` subtasks by the leading token `[AC] ` only; order is not meaningful. `Development`, `Testing`, `Bugs` are containers, not criteria. Match sections by number and meaning, not punctuation (`-` and `—` are the same). Take numbering from the live template; an intentional gap in numbering is not a missing section. Anything unreadable is a gap, and the gap line says it could not be assessed.
