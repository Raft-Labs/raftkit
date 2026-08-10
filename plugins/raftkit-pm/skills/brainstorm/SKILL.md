---
name: brainstorm
description: This skill should be used when anyone at RaftLabs has a feature idea — even just a name — and wants it thought through and interviewed into a detailed spec document before any story gets written. Trigger on "brainstorm this feature", "help me think through <feature>", "what am I missing", "what should we ask the client", "turn this idea into a spec", "flesh out this feature idea", or a bare project name with nothing attached. It finds whatever already exists for that project, asks a few related questions at a time covering business, user, product, admin, edge cases and standard practice, explains everything in plain language, splits the leftover questions into ones the client must answer and ones the team can decide, and compiles the result into the live Asana Feature Template shape after approval. For writing the resulting story into an Asana task, use user-story instead.
user-invocable: true
---

# brainstorm

Think a feature idea through with someone, then compile it into a spec
document deep enough to write precise, gap-free stories from. A one-line idea
is a complete starting point — the depth comes out of the conversation, not out
of what the person walked in with.

This exists because story quality tracks source-material quality. On the one
project that had a detailed client-written feature doc, stories came out tight
and fast; everywhere else they start thin and the gaps surface later as bugs.

The job is not to fill in a form. By the end of a session the person should
understand the feature better than when they started, and know exactly what
still needs someone else's decision.

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

When what turns up is a whole project's worth of material rather than one
feature's, that is
[`project-onboarding`](../project-onboarding/SKILL.md)'s job — offer it and
carry on with the feature.

## What it needs (and what it does not)

Needed: **a feature idea, or just a project name.** Plus a destination and a
depth, both asked explicitly — see below.

Not needed: notes, a doc, a spec, prior context of any kind. Starting from
nothing is a fully supported path, not a degraded one. Never gate the run on
the person having material to hand.

## Run flow

1. **Look before asking** — `references/sources-and-notes.md`. Check the
   session notes for this project first, then Asana, then the project's
   document store. Report what turned up, one line per source, before going
   further. Never re-ask for something already found, already supplied, or
   already settled in earlier notes.

2. **Fetch the live Feature Template.** Resolve the workspace and Feature
   Template GIDs from `raftkit-core/workflow-constants`, then fetch that task
   live through the Asana connector — every run, never from memory and never
   from this repo. Its section structure is the shape of the compiled doc. If
   it cannot be read, stop with that skill's exact message; there is no
   remembered-format fallback.

3. **Explain it back, before anything else.** Say what the feature is in plain
   language, on its own, with no risks or gaps attached — those are a separate
   message that comes after the person has their footing
   (`raftkit-core/discovery-interview` → `references/conversation-craft.md`).
   Skip this only when the person already showed they understand it.

4. **Ask the destination.** Where the compiled doc lands: an Asana task, a
   document store, or a file in a synced folder. Ask it — there is no default
   and no silent pick. An Asana destination needs the exact task named; never
   invent or guess one.

5. **Ask the depth.** Quick or exhaustive, per `references/interview-map.md`.
   Ask it — again no default, no silent pick. State what the chosen depth will
   cover before starting, so the person can switch before the interview, not
   halfway through it.

6. **Interview.** Run `raftkit-core/discovery-interview`: a few related
   questions at a time — three at most — each set shaped by the last answers.
   Recommendation first with a reason and a "don't pick this if…" caveat. Push
   back on vague answers and on unnecessary ones. Never interrogate a complete
   answer. Walk the lenses in `references/interview-map.md`, announcing which
   one is in flight and what is left, and recap the state periodically.

7. **Research only against a named gap** — `references/research-protocol.md`.
   House knowledge first. Say so before running a search, and label what comes
   back where it is used. Research is never automatic and never blended in as
   unstated fact.

8. **Flag, never guess.** A contradiction between two answers is named — both
   answers, and that they conflict — and re-asked. A missing answer is
   re-asked once in plainer words, then recorded as an open question if it is
   still not there. Neither is ever resolved by the skill on the person's
   behalf.

9. **Triage what is left.** Every unresolved question is sorted by who has to
   answer it — must-ask, good-to-clarify, or the team can decide
   (`references/interview-map.md`). Sending a client a question the team could
   have settled itself costs goodwill and a week.

10. **Compile.** Fill the live template's sections from the answers, tagging
    each fact ✅ Confirmed / ⚠️ Partial / ❓ Missing the same way
    `project-onboarding` does. Everything unresolved goes to the
    open-questions section with its triage label. An untouched section is
    marked not applicable with the reason, never left blank and never padded.

11. **Draft, approve, push.** Follow `raftkit-core/write-protocol`: show the
    full compiled doc in chat, name the exact destination, wait for explicit
    approval. Silence is not approval. Only then write — through
    `asana-formatting` when the destination is Asana, as-is on any other
    destination.

12. **Offer to save the session notes**, then report and stop. Give the link,
    the count of open questions by triage label, and the offer to run
    `user-story` next. Notes are never saved silently
    (`references/sources-and-notes.md`).

## Depth

Both tiers cover every lens. They differ in how far each is pushed — the
difference is in `references/interview-map.md` and it is countable, not a
matter of tone.

- **Quick** — one headline question per lens, edge cases walked as the six
  house buckets, proactive suggestions raised only on high-signal triggers.
  For a gut-check on an idea that may not survive the week.
- **Exhaustive** — every quick question plus its follow-ups, the full
  24-category edge-case walk, the full proactive scan, and a recap the person
  confirms before anything is compiled. For an idea that is going to get built.

## Guardrails

- **No cached template text.** The section structure comes from the live fetch
  every run, so an edit to the template in Asana shows up the same day with no
  plugin release.
- **No project facts in this skill.** Workspace and template GIDs come from
  `workflow-constants`; the document-store root and the session-notes home are
  parameters the person supplies or the Project Profile holds. Never hardcode
  a folder, a project, or a client (`raftkit-core/house-rules`).
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

- **`references/interview-map.md`** — the lenses, each mapped to its question
  set, what quick and exhaustive each cover, and the question triage.
- **`references/sources-and-notes.md`** — finding what already exists before
  asking, and carrying state across sessions.
- **`references/research-protocol.md`** — when research is allowed, how it is
  announced, how a researched line is labelled, and the one thing a person
  cannot overrule.

## Asana rendering

All Asana output is rendered and verified through core `asana-formatting`
(per-surface tag matrix, markdown→HTML conversion, mentions, read-back
verification), behind the `write-protocol` draft → approve → push gate.
