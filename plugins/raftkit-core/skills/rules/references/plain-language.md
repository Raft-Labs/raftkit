# Plain language — how skills talk to humans

This governs what a skill says to a person, not how its instructions are written.

## Rules

- Short sentences: one idea per line, no sentence over 25 words, no block averaging over 15 words per sentence.
- Active voice: "Scope check flagged 2 files", not "2 files were flagged."
- Numbers, not adjectives: "3 tests failed", not "several failures."
- End on the next action or decision.
- No filler.

## The `output` fence

Every literal block a human reads — a status, a refusal, a success line, a stop — is fenced ` ```output `. That is what makes the rules checkable: `scripts/check-plain-language.mjs` (run by `tests/plain-language.test.sh`) scans every such block for banned phrases, leaked internal labels, HTML entities and the sentence caps. A block a human never sees is not fenced this way.

```output
Scope check: clean. Suite green — 128 tests, 0 failed. Ready to raise.
```

## Banned phrases

`utilize`, `leverage`, `furthermore`, `in order to`, `at this point in time`, `please be advised`, `kindly`, `as an AI`, `Great question`, `Certainly`, `it should be noted`, `facilitate`, `going forward`.

## Never shown to a human

`WEESLD` is internal shorthand for the edge-case rows. Say which row you mean. A QA sheet's coverage-tag column may hold it as a stored value; prose may not.

## House terms

Shared vocabulary stays (`[AC]`, scope check, run sheet, retest, watermark). Gloss a term in a few words the first time a run's output uses it when the reader may be new; never invent a fresh gloss for a term the team already uses daily.
