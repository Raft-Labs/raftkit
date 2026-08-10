---
name: feature-brainstorm
description: This skill should be used when anyone at RaftLabs has a feature idea — even just a name — and wants it interviewed into a detailed spec document before any story gets written. Trigger on "brainstorm this feature", "help me think through <feature>", "turn this idea into a spec", "I want to build X, ask me the questions", "flesh out this feature idea", or a request to spec something from scratch or from rough notes. It asks where the output goes and how deep to go, interviews one question at a time covering business cases, edge cases and standard practice, labels anything it researched, and compiles the answers into the live Asana Feature Template shape after approval. For writing the resulting story into an Asana task, use user-story instead.
user-invocable: true
---

# feature-brainstorm

Interview a feature idea into a spec document deep enough to write precise,
gap-free stories from. A one-line idea is a complete starting point — the
depth comes out of the interview, not out of what the person walked in with.

This exists because story quality tracks source-material quality. On the one
project that had a detailed client-written feature doc, stories came out tight
and fast; everywhere else they start thin and the gaps surface later as bugs.
This skill produces that document on demand instead of hoping a client wrote
one.

## The one rule that governs everything

**Every line in the compiled doc traces to something real** — an answer the
person gave, a source they supplied, or a citation labelled as research.
Nothing is invented, nothing is inferred into a fact, and no gap is filled
with a plausible-sounding value. A gap is either asked about or recorded as an
open question.

## Where it sits

Upstream of [`user-story`](../user-story/SKILL.md), and **terminal** — this
skill's job ends at the compiled doc. It offers the story step as a next
action the human runs; it never chains into it. Nothing about any existing
skill changes because this one exists.

## What it needs (and what it does not)

Needed:

1. **The feature idea.** One line is enough. A name is enough.
2. **A destination**, asked explicitly every run — see below.
3. **A depth**, asked explicitly every run — see below.

Not needed: notes, a doc, a spec, prior context of any kind. Starting from
nothing is a fully supported path, not a degraded one. Never gate the run on
the person having material to hand.

Supplied material, when it exists, arrives by whatever path the session
offers — connector, upload, pasted link, or synced local file
(`raftkit-core/house-rules`). Ground the questions in it and name the gaps it
leaves rather than re-asking what it already answers.

## Run flow

1. **Fetch the live Feature Template.** Resolve the workspace and Feature
   Template GIDs from `raftkit-core/workflow-constants`, then fetch that task
   live through the Asana connector — every run, never from memory and never
   from this repo. Its section structure is the shape of the compiled doc. If
   it cannot be read, stop with that skill's exact message; there is no
   remembered-format fallback.

2. **Take the idea.** Whatever the person has, including only a name. If they
   supplied sources, list them back by name (title, link, or task GID) and
   confirm the set before interviewing.

3. **Ask the destination.** Where the compiled doc lands: an Asana task, a
   Google Drive doc, or a file in a synced folder. Ask it — there is no
   default and no silent pick. An Asana destination needs the exact task
   named; never invent or guess one.

4. **Ask the depth.** Quick or exhaustive, per `references/interview-map.md`.
   Ask it — again no default, no silent pick. State what the chosen depth will
   cover before starting, so the person can switch before the interview, not
   halfway through it.

5. **Interview.** Run `raftkit-core/discovery-interview`: one question at a
   time, recommendation first with a reason and a "don't pick this if…" caveat,
   push back on vague answers, volunteer what people forget, never interrogate
   a complete answer. Walk the live template's sections in order, using the
   question sets in `references/interview-map.md`. Announce which section is in
   flight and what is left.

6. **Research only against a named gap** — `references/research-protocol.md`.
   House knowledge first. Say so before running a search, and label what comes
   back where it is used. Research is never automatic and never blended in as
   unstated fact.

7. **Flag, never guess.** A contradiction between two answers is named — both
   answers, and that they conflict — and re-asked. A missing answer is
   re-asked once in plainer words, then recorded as an open question if it is
   still not there. Neither is ever resolved by the skill on the person's
   behalf.

8. **Compile.** Fill the live template's sections from the answers. Everything
   still unresolved goes to the template's open-questions section with who
   needs to decide it. An untouched section is marked not applicable with the
   reason, never left blank and never padded.

9. **Draft, approve, push.** Follow `raftkit-core/write-protocol`: show the
   full compiled doc in chat, name the exact destination, wait for explicit
   approval. Silence is not approval. Only then write — through
   `asana-formatting` when the destination is Asana, as-is on any other
   destination.

10. **Report and stop.** Give the link, the count of open questions, and the
    offer to run `user-story` next. Then stop.

## Depth

Both tiers ask about every section of the template. They differ in how far
each section is pushed — the difference is in `references/interview-map.md`
and it is countable, not a matter of tone.

- **Quick** — one headline question per section, edge cases walked as the six
  house buckets, proactive suggestions raised only on high-signal triggers.
  For a gut-check on an idea that may not survive the week.
- **Exhaustive** — every quick question plus its follow-ups, the full
  24-category edge-case walk, the full proactive scan, and a recap the person
  confirms before anything is compiled. For an idea that is going to get built.

## Guardrails

- **No cached template text.** The section structure comes from the live fetch
  every run, so an edit to the template in Asana shows up the same day with no
  plugin release.
- **Open questions are surfaced, never settled.** This skill has no authority
  to decide a product question. It records who does.
- **Terminal by design.** No auto-handoff into `user-story`, no story drafted
  here, no `[AC]` subtasks created.
- **Asana free tier only** (`raftkit-core/house-rules`): no dependencies,
  custom fields, milestones, start dates, or approval tasks. Relationships are
  task links in the description.
- **Escalate to founders** on budget, contracts, relationship risk, or anything
  that reads as a client commitment — never settle one inside a spec doc.
- **Plain English out** — every line a human reads follows `raftkit-core/house-rules`' plain-language rules; a house term gets its one-line gloss on first use.

## Reference files

- **`references/interview-map.md`** — each live-template section mapped to its
  question set, and exactly what quick and exhaustive each cover.
- **`references/research-protocol.md`** — when research is allowed, how it is
  announced, and how a researched line is labelled in the doc.

## Asana rendering

All Asana output is rendered and verified through core `asana-formatting`
(per-surface tag matrix, markdown→HTML conversion, mentions, read-back
verification), behind the `write-protocol` draft → approve → push gate.
