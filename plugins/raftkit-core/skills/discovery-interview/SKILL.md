---
name: discovery-interview
description: This skill should be used whenever a RaftKit skill has to interview a human to build something out — a feature spec, a project design, a module breakdown, any artifact whose quality depends on the questions asked. It defines the house interview contract (one question at a time, recommendation first, push back on vague answers, never guess) and carries the three shared catalogs every such interview draws on — vague-answer push-backs, proactive suggestions to volunteer, and the edge-case walk. Consult it before asking a human a series of questions, even when the consuming skill has its own question script.
user-invocable: false
---

# RaftKit Discovery Interview

The house contract for interviewing a human to build something out. It is
authored once here so a PM speccing a feature and a developer designing a
repo's docs get the same interview, and a fix to one is a fix to both.

This skill owns **how the questions are asked** and the **cross-domain
catalogs** they draw on. It never owns the question list itself — the
consuming skill brings its own script, ordered by whatever artifact it is
building (`raftkit-pm:feature-brainstorm` walks the live Feature Template;
`raftkit-dev:docs` walks its 12-phase design flow).

## The rules that govern every interview

- **One question at a time.** Never batch. The next question depends on the
  last answer, so a batch is a worse question set than the one you would have
  asked. Skip questions earlier answers made irrelevant, silently.
- **Recommend, don't just list.** Put your recommended option first and mark it
  `(Recommended)`. Give a one-sentence reason for it.
  Every alternative carries a "don't pick this if…" caveat.
  A bare menu pushes the thinking back onto the human, which is the work the
  interview exists to do.
- **Push back on vague answers** — `references/push-back.md`. A vague answer
  does not advance the interview; it earns a targeted follow-up.
- **Never interrogate a complete answer.** The catalogs exist to make the
  human better at speccing, not to grind through every row. A specific answer
  is accepted and the interview moves on.
- **Volunteer what people forget** — scan every answer against
  `references/proactive-prompts.md` and raise a matching suggestion as a
  question before moving on.
- **Never guess a fact.** An unknown is asked, or recorded as an open question.
  It is never filled with a plausible-sounding value.
- **Flag contradictions, don't resolve them.** When a new answer conflicts with
  an earlier one, name both, say they conflict, and ask which holds. Silently
  picking one is the failure this rule exists to prevent.
- **Announce progress.** On a long interview, say which section is in flight
  and what is left, so the human can see the end of it.

## Depth is a choice the human makes

An interview that can run short or long asks which up front and never picks
silently. The consuming skill names its own tiers and binds each to a question
set — a tier that does not change the questions asked is not a tier. The
edge-case catalog is built for exactly this: `references/edge-cases.md` maps
six house buckets onto the same 24 categories, so a short pass and an
exhaustive pass share one catalog instead of forking into two.

## Where this sits

This skill asks; it never writes. Anything the interview produces goes out
through `write-protocol` (draft → approve → push), and anything project-specific
it learns belongs in a Project Profile, never in a plugin
([house-rules](../house-rules/SKILL.md)).

## Guardrails

- **Plain English out** — every line a human reads follows `raftkit-core/house-rules`' plain-language rules; a house term gets its one-line gloss on first use.
- **No writes from here.** This skill defines question behaviour only.
- **Escalate to founders** on budget, contracts, relationship risk, or anything
  that reads as a client commitment — an interview never settles one of those.

## Reference files

- **`references/push-back.md`** — the vague-answer catalog: pattern → the
  follow-up it earns, plus the rule against interrogating complete answers.
- **`references/proactive-prompts.md`** — the product-level trigger catalog:
  what the human said → what to volunteer before moving on.
- **`references/edge-cases.md`** — the 24-category edge-case walk, the six-bucket
  short pass mapped onto it, and pre-built sets per feature type.
