---
name: discovery-interview
description: This skill should be used whenever a RaftKit skill has to interview a human to build something out — a feature spec, a project design, a module breakdown, any artifact whose quality depends on the questions asked. It defines the house interview contract (a few related questions at a time, recommendation first, push back on vague answers, never guess) and carries the three shared catalogs every such interview draws on — vague-answer push-backs, proactive suggestions to volunteer, and the edge-case walk. Consult it before asking a human a series of questions, even when the consuming skill has its own question script.
user-invocable: false
---

# RaftKit Discovery Interview

The house contract for interviewing a human to build something out. It is
authored once here so a PM speccing a feature and a developer designing a
repo's docs get the same interview, and a fix to one is a fix to both.

This skill owns **how the questions are asked** and the **cross-domain
catalogs** they draw on. It never owns the question list itself — the
consuming skill brings its own script, ordered by whatever artifact it is
building (`raftkit-pm:brainstorm` walks the live Feature Template;
`raftkit-dev:docs` walks its 12-phase design flow).

## The rules that govern every interview

- **A few related questions at a time — three at most.** One question per turn
  makes a long interview exhausting; twenty at once turns it into a form. Ask
  two or three questions that genuinely belong together, then let the answers
  shape the next set. "Related" is the load-bearing word: questions that need
  each other's answers go in separate turns, not the same one. Skip questions
  earlier answers made irrelevant, silently.
- **Recommend, don't just list.** Put your recommended option first and mark it
  `(Recommended)`. Give a one-sentence reason for it.
  Every alternative carries a "don't pick this if…" caveat.
  A bare menu pushes the thinking back onto the human, which is the work the
  interview exists to do.
- **Explain before you critique.** What something is, and what is wrong with
  it, are two separate messages. Sending them together is the most reliable way
  to lose a non-specialist — see `references/conversation-craft.md`.
- **Talk in the human's vocabulary, not the domain's.** Translate every term
  before using it, and reach for a concrete example or a familiar product over
  an abstract description.
- **Push back on vague answers** — `references/push-back.md`. A vague answer
  does not advance the interview; it earns a targeted follow-up.
- **Push back on unnecessary answers too.** A complete answer describing
  something nobody needs is still worth questioning once. The cheapest thing
  to build is the thing you talked them out of building.
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
- **Recap, then say when there is enough.** Summarise the state periodically,
  and name the moment the interview has what it needs. An interview with no
  stated end runs until the human gives up.

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

- **`references/conversation-craft.md`** — how the questions are delivered:
  explain before critiquing, translate the domain, build a worked example,
  compare to something familiar, pressure-test complexity, recap, and signal
  when there is enough.
- **`references/push-back.md`** — the vague-answer catalog: pattern → the
  follow-up it earns, plus the rule against interrogating complete answers.
- **`references/proactive-prompts.md`** — the product-level trigger catalog:
  what the human said → what to volunteer before moving on.
- **`references/edge-cases.md`** — the 24-category edge-case walk, the six-bucket
  short pass mapped onto it, and pre-built sets per feature type.
