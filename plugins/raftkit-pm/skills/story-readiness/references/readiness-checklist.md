# Readiness checklist — derive from the live template, audit, report

The checklist is **derived from the live Feature Template every run**, never
reproduced from memory. Read the template's structure off the freshly fetched task
(see `raftkit-core/workflow-constants`) and audit the story against *that*. If the
template gains, loses, renames, or renumbers a section, the gate follows
automatically — that is the whole point of deriving it live.

What follows is the *method* for turning the live template into a verdict. The
section names, numbers, and row lists below are **illustrative of the template at
the time of writing** — always take the authoritative structure from the live
fetch, never from this page. Where a concrete name/number appears, read it as "the
section the live template uses for this", not as a fixed constant.

## Definition of Ready

A story is **Ready** only when every one of these holds. Any that you cannot
confirm is a gap, and any gap ⇒ **NOT READY** (fail closed).

1. **Every edge-case row answered** (the template's WEESLD section — at time of
   writing section 6, rows Waiting / Empty / Error / Success / Limits / Default
   values). Each row the live template presents has a real answer. `"N/A"` is a
   valid answer; **blank or a leftover `{...}` placeholder is not.** Where the live
   template flags a row as most important (it currently labels the **Error** row
   "Error (most important)"), that row must state the exact message the user sees
   and the recovery action.
2. **Exact user-facing copy present** (the template's UI/UX copy section — at time
   of writing section 7). Every string the user reads — labels, buttons,
   empty/error/success messages, email subject/body — is given verbatim in the
   source language. "Add appropriate text" or a `{...}` placeholder is a gap, not
   copy.
3. **Permission boundary stated** (the header's "who is allowed / not allowed"
   field). Who may perform the action *and* who is explicitly blocked. "Who is
   blocked" being absent is a gap.
4. **At least one out-of-scope item** (the template's out-of-scope / non-goals
   section — at time of writing section 9). The non-goals list has ≥ 1 concrete
   item. An empty section is a gap.
5. **`[AC]` coverage is complete.** The `[AC]` subtasks together cover: the happy
   path, every edge-case row present in the story, every business rule, and every
   permission boundary. A scenario, rule, edge-case row, or boundary with no
   corresponding `[AC]` is a coverage hole.

No content is filled in, nothing is placeholder, and every `{...}` from the template
has been replaced with a real, specified value.

## The five gap types to catch

The audit must catch each of these (they are the seeded-gap acceptance criterion).
For every gap, emit one line — see the format below.

| # | Gap type | How it shows up |
|---|---|---|
| 1 | **Missing edge-case (WEESLD) row** | A row in the edge-cases section is blank / placeholder (not even `N/A`). |
| 2 | **No exact copy** | The copy section refers to a message/label without giving the verbatim string. |
| 3 | **No permission rule** | The header's allowed/blocked boundary is missing or one-sided. |
| 4 | **No out-of-scope item** | The non-goals section is empty. |
| 5 | **`[AC]` coverage hole** | A scenario / business rule / edge-case row / permission boundary has no matching `[AC]` subtask. |

## Output formats

This section is the single source for the exact verdict strings — SKILL.md points
here rather than restating them.

### PASS

```output
PASS — ready to hand off.
Coverage: <n> scenarios, <m> acceptance criteria ([AC]s), every edge case covered.
```

Only emit PASS when **every** Definition-of-Ready item holds. There is no partial
pass.

### NOT READY

```output
NOT READY — <k> gap(s):
- Section <N> "<title>" — <exactly what is missing>
- [AC] coverage — <the uncovered scenario / rule / edge-case row / boundary>
- ...
Owner: PM (fix the story, then re-run the gate).
```

Each gap line must be **actionable without re-reading the template**: name the
section (its number + title as they appear in the live template) and state the
concrete missing thing, not a category label. Good: `Section 6 "Edge cases —
WEESLD" — the Error row is blank; give the exact message and recovery action.`
Bad: `WEESLD incomplete.`

For the empty-description state, the single line is the verdict:

```output
NOT READY — the task description is empty — generate the story first.
```

## Parsing robustness

Asana stories are hand-authored and their formatting is inconsistent. Parse
defensively:

- **`[AC]` subtasks** — match by the **leading token** `[AC] ` (bracket, `A`, `C`,
  space) only. A subtask whose *body* repeats `[AC]` does not fool leading-token
  matching. Subtask order is not meaningful.
- **Fixed containers** — `Development`, `Testing`, `Bugs`, matched by exact name, no
  prefix. They are not acceptance criteria and are not audited for coverage.
- **Sections** — match by number and meaning, **not punctuation**: the template may
  use ASCII `-` where a story uses an em-dash `—`; treat them the same. The
  template's numbering may be non-contiguous (at time of writing it skips 10:
  …9 → 11 → 12) — take the numbering from the live template and do not treat an
  intentional gap as a missing section.
- **Unreadable / ambiguous** — if a section or field cannot be assessed, treat it as
  a gap (fail closed), and say in the gap line that it could not be assessed.
