# Run-sheet format — the fixed layout

The run sheet **is** the deliverable: this file is the single source of every
fixed rule the skill emits — the step columns, the determinism rule, the mandatory
WEESLD and permission step groups, the default step status, the exact-strings rule,
and the success line. Nothing here is paraphrased in `SKILL.md`; it points back
here so the rules never drift.

## The step table (fixed columns, in order)

A run sheet is a numbered list of steps grouped by what they cover. Each step has,
in order:

| Field | Holds |
|---|---|
| step # | the sequential number — the sheet is numbered end to end |
| group | what the step covers: a Gherkin scenario, an `[AC]`, a WEESLD state, or a permission boundary |
| start state | the test account / data state the step begins from (deterministic — a named account and data, not "some data") |
| action | the single action QA performs |
| test data | the exact data the action uses |
| expected | the expected result — **quoted verbatim from the story** (see below) |
| status | the execution mark; every step defaults to `not run` |

The skill owns this structure; QA owns the execution marks. When the sheet is
appended to a run-sheet tab or Sheet (never the suite Sheet's case rows — see
SKILL.md's guardrail), these are its columns; in chat, the same fields render as
a numbered table.

## Determinism (no "verify it works" steps)

Every step is deterministic: a concrete **start state**, a single **action**, and
one **expected** result. A step that says "verify it works", "check the page", or
"confirm behaviour" is not a step — it names no start state, no action, and no
checkable expected result. Replace it with the concrete state/action/expected the
story implies, or, if the story does not give one, flag it as a coverage gap
(`routing-and-edges.md`) rather than emitting a vague step.

## Expected results quote the story's exact strings

The `expected` field is filled with the story's **own wording, verbatim** — its
success and error copy (the UI-copy and WEESLD sections), its `[AC]` text, its Gherkin
`THEN` clauses. Never paraphrase: a paraphrase asserts something the story did not
say. The story is the single source of these strings; if the story gives no exact
string for an outcome, quote the closest `[AC]` or `THEN` clause and note that the
copy is unspecified — do not invent copy.

## Mandatory step groups — every WEESLD state and every permission boundary

Two coverage guarantees, each an **explicit** step group (never folded into the
happy path):

- **WEESLD** — one step group per state the story's edge-cases section specifies:
  Waiting, Empty, Error, Success, Limits, Default values. A state the story marks `N/A` is
  recorded as `N/A` (so the sheet shows it was considered), not silently dropped.
- **Permission boundary** — the story header's `Who is allowed / not allowed`
  becomes explicit step groups: one exercising the allowed actor, one asserting the
  disallowed actor is blocked. (For this story's own domain, for example: anyone on
  the project can generate, but pass/fail execution marks belong to QA.)

Coverage tags align with `test-suite/references/sheet-format.md` — `happy`,
`WEESLD`, `permission` — so a run sheet and the project suite describe coverage the
same way.

## Default step status

Every generated step starts at **`not run`**. The status vocabulary is the same as
the project suite's — `not run` · `pass` · `fail` · `blocked` — owned by
`test-suite/references/sheet-format.md`; this skill reuses it rather than defining a
second vocabulary. QA changes a step's status as they execute; the skill never sets
anything but the `not run` default.

## Success line (verbatim)

On a generated sheet, report exactly:

```
Run sheet: N steps covering M [AC]s — gaps: none / listed
```

`N` = the number of steps, `M` = the number of `[AC]`s covered by at least one
step. End the line with `gaps: none` when every `[AC]` and every WEESLD state is
covered, or `gaps: listed` when the coverage-gap list (`routing-and-edges.md`) is
non-empty — and then actually list them. Emit the line only for a sheet that was
produced, never as an optimistic guess.
