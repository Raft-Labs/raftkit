# Plain language — how skills talk to humans

This is the contract for anything a human reads: a status line, a refusal, a
success report, an error, a question. It is not about how a skill *thinks* —
its instructions stay as dense as correctness needs. It is about what the
skill *says*.

## The rules

- **Short sentences.** One idea per line.
- **Active voice.** "Scope-guard flagged 2 files", not "2 files were flagged."
- **Numbers, not adjectives.** "3 tests failed", not "several failures."
- **End on the next action or decision.** A human reading the last line should
  know what happens next, or what they need to decide.
- **No filler.** Cut words that add no information.

## The `output` fence

Any literal block a human reads — a status line, a refusal, a success report —
is fenced ` ```output `. This is what makes the rule testable: a checker can
find every block a human sees by looking for the fence, and check it against
the rules below. A block a human never sees (an internal instruction to the
model) is never fenced this way.

```output
Scope-guard (checks the diff against the agreed scope): clean.
Suite green — 128 tests, 0 failed. Ready to raise.
```

## What CI checks, and what a human reviewer checks

Not every rule above is machine-checkable. `scripts/check-plain-language.mjs`
(run by `tests/plain-language.test.sh`) mechanically enforces, on every
`output` block:

- no banned phrase (word-boundary match, case-insensitive)
- no leaked internal-only label (`WEESLD`, any case)
- no named or numeric HTML entity
- no sentence over 25 words, counted after wrapped lines are rejoined (see
  "Sentence length") — and no block averaging over 15 words/sentence
- no `Gate N` reference outside the numbers the house glossary below lists,
  parsed live from this same file so the two can't drift
- a fence opened with ` ```output ` and never closed — flagged as a
  violation, with its content still checked against every rule above rather
  than skipped

It does not check active voice, numbers-over-adjectives, ending on the next
action or decision, or that a house term other than `Gate N` gets glossed on
first use — those need judgment a regex can't apply. They're graded by the
eval bundle (`raftkit-core/evals/plain-language/`) and by human review, not
CI. A green `check-plain-language.mjs` run means "no banned filler, no
oversized sentence, nothing leaked, every Gate number glossed" — not "this
output is plain English." That's still a human read.

## Banned phrases

None of these appear inside an `output` block:

`utilize`, `leverage`, `furthermore`, `in order to`, `at this point in time`,
`please be advised`, `kindly`, `as an AI`, `Great question`, `Certainly`,
`it should be noted`, `facilitate`, `going forward`.

## Sentence length

Inside an `output` block: no sentence over 25 words, counted after
hard-wrapped continuation lines are rejoined into the sentence they're part
of — word count depends on the sentence, not on where the file wraps it. A
new bullet, numbered item, or heading always starts a fresh unit, even when
the line above it has no sentence-ending punctuation.

A block with more than one sentence also has a ceiling on the average: no
more than 15 words/sentence across the whole block. Clearing the 25-word cap
on every sentence but still reading dense fails the average — break the
block up instead of trimming words to fit.

## The house glossary

RaftKit runs on shared vocabulary — that vocabulary is not the problem, an
unglossed *first use* of it is. A house term appearing inside an `output`
block gets a short gloss the first time that block uses it. After that, the
bare term is fine — the human has already been told what it means this run.

| Term | Gloss |
|---|---|
| `[AC]` | acceptance criterion — one checkable outcome |
| Gate 0 | the story-readiness check, before any plan or code |
| Gate 1 | the plan-approval check |
| Gate 2 | the scope + review check, before a PR is raised |
| scope contract | the exact list of what's in and out, agreed at Gate 1 |
| spec file | the approved plan, written to disk before code starts |
| story-readiness | the check that a story has enough detail to build from |
| scope-guard | the check that the diff matches the scope contract |
| run sheet | the QA tracking sheet for one test pass |
| retest | re-running QA on a fix, to confirm it holds |
| capability preflight | the check that a required tool or plugin is installed |
| decomposition | splitting a build into small, independently-testable steps |
| MDS / design standard | RaftLabs' Module Design Standard — the code-shape rules |
| watermark | the "not a client commitment" line on every estimate |
| provider seam | the point where a skill hands off to a third-party plugin |
| the train / release train | the scheduled deploy pipeline — a PR is ready for it, never deployed by a skill |
| governance pack | the installed set of house rules and CI checks a repo runs against |

Add a term here when a skill needs it in output more than once — do not
invent a fresh gloss inline.

## Never shown to a human

Some labels are internal shorthand for the model and must never appear inside
an `output` block:

- `WEESLD` (Waiting / Empty / Error / Success / Limits / Default values —
  spell out whichever of these actually applies, in plain words, instead)

**Carve-out:** a QA sheet's `coverage tag` column may hold `WEESLD` as a
literal, persisted value — a stored tag, not prose a human narrates. Prose
that describes or explains something *using* the acronym still must not use
it.

## The one exception: verbatim strings

Four strings are copied word-for-word from RaftLabs' AI governance protocol
(Asana task `1216375937893602`): `⚠️ EFFICIENCY WARNING`,
`❌ ORCHESTRATION REJECTED`, `⚠️ SUBAGENT LOOP WARNING`, and the
`📊 Session Health Check` nudge. These are never reworded, shortened, or
re-glossed in place — they are a deliverable in their own right (see
`governance-protocols`). A skill that shows one of these strings may add a
plain one-line gloss immediately after it, but the string itself stays exactly
as authored.

## Before / after

**Before** (illustrative only — never actually shipped, so this is a plain
` ``` ` fence, not ` ```output `; a checker scanning `output` blocks should never
find the non-compliant half of this pair):

```text
Required capability unavailable: <capability>. Proposed install command
(human approval required): <exact command>. Stopping — no fallback.
```

**After:**

```output
Missing: <capability>. Install it with: <exact command>
Needs your approval first — nothing installs until you say go.
```

Same information. Half the words. Ends on what happens next.
