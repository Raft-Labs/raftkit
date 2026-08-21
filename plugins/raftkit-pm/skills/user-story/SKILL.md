---
name: user-story
description: This skill should be used when a RaftLabs PM wants to write, generate, or draft a user story into an Asana task — e.g. "write a user story", "draft the story for password reset", "turn this scope into a RaftLabs story". It also amends a story that already exists — "amend this story", "extend this story with the onboarding changes", "update an existing story", "add these acceptance criteria to <task>", "the dev found a gap in this story, fix it" — which runs as amend mode: a diff-first additive edit that never rewrites the story, tags its followers, and re-runs the readiness gate. Reads the live Feature Template as the format authority, grounds every claim in the PM's sources, and writes only after approval. Also sizes one story on request — "how long will this take to build?", "size this story", "is this a day or a week?", "how big is this change request?" — returning one hour range with named assumptions under the founder-review watermark. This answers how big a story is, not what it costs to quote. A whole feature list or backlog belongs to raftkit-pm:estimation, which prices each feature into FE, BE and QA hours; one story is answered here.
user-invocable: true
---

# user-story

Generate a template-perfect RaftLabs user story for **any** project and place it
into a PM-named Asana task: full story body (`html_notes`) plus the `[AC]`
acceptance-criteria subtasks and the fixed `Development` / `Testing` / `Bugs`
subtasks. The story's job is to capture the WHAT and the WHY precisely enough that
a developer or an AI never has to guess — they derive the HOW from the codebase.

This generalizes the proven flowhoney method (PRD §5.2): the template approach cut
StrikeHoney staging bugs to zero. This skill makes it project-independent by
reading the format live and grounding content in each project's own sources.

## Two modes

When the ask is to put story content into a task, pick the mode
**deterministically on entry** — from the target task's state, never from how the
request was phrased:

| Mode | Entry condition | What it writes |
|---|---|---|
| **Mode A · author** | The target task has **no story body** (an empty description) | The full body, the `[AC]` subtasks, and `Development` / `Testing` / `Bugs` |
| **Mode B · amend** | The target task **already holds a story body** | A merged description, added or reworded `[AC]`s, and one comment tagging every follower of the task |

The body decides, and nothing else does. A request to extend, update, change,
correct, or add criteria to a story that exists is the **same** Mode B, however
it was worded — and a task whose description is empty is authoring, so say so and
run Mode A. When the wording leaves it unclear what the PM wants changed, ask
**inside** Mode B; never fall back to Mode A and never rewrite the story to
resolve the doubt.

Mode A is the run flow below. **Mode B runs
[`references/amend-mode.md`](references/amend-mode.md) instead** — mode selection
happens here, before that file's readiness gate runs, and Mode B refuses a story
the gate calls not ready.

Sizing is **not** a mode: it answers how long a story will take and writes
nothing. See `Sizing one story` below.

## The one rule that governs everything

**Never proceed without the PM supplying the source of truth.** Do not assume, do
not fabricate, do not fill a gap with a plausible-sounding fact, and do not work
from an absent or empty profile. When the target task or the source(s) of truth
are missing or too thin to ground a claim, **stop and ask the PM**, naming exactly
what is missing. Every sentence in a generated story must be traceable to
something the PM provided.

## Preconditions — gather before drafting anything

1. **An explicit target Asana task**, named by the PM. Never invent or guess a
   target. If none is named → stop and ask which task to write into.
2. **The feature scope** — what this story is about.
3. **The source(s) of truth** — the Project Profile and/or the project's own
   sources (spec, PRD, designs, prior stories). The profile's decided home is the
   pinned Asana resource task linking its Drive doc; the PM points at it, or at
   whatever sources exist. There is no default source. Sources arrive by any
   access path the session provides — connector, uploaded file, pasted link, or
   synced local file (`raftkit-core/house-rules`).

If any of these is missing, **ask before doing anything else** (the Empty state).

## Run flow — Mode A

1. **Resolve constants and fetch the live template.** Get the workspace GID and
   the Feature Template GID from `raftkit-core/workflow-constants`, then fetch
   the template task live via the Asana connector — every run, never from memory
   or this repo. The template (and its comments) is the format authority; its
   comments are guidance for this skill only and are never copied into a story.
   If the template cannot be read, stop with the exact `workflow-constants`
   message — no fallback to a remembered format.

2. **Confirm the preconditions above.** Missing target task or scope or source of
   truth → stop and ask, naming what is missing.

3. **Confirm the sources before drafting.** Before any drafting begins, list the
   specific sources gathered in step 2 by name (document title, link, or task
   GID — never a generic label like "various sources"). Show: "Before I draft
   this, here are the sources I'll use: [list]. Confirm these, or tell me what
   to change." Wait for explicit confirmation or a correction; silence is not
   confirmation. If the PM corrects a source, update the list and proceed with
   the corrected set — do not re-show the checkpoint again this run. No Asana
   task is created or modified before this step completes. This checkpoint runs
   once per run, not once per section drafted.

4. **Judge cohesive vs. epic.** Lean to a single cohesive story. When genuinely
   unsure whether the scope is one story or several, ask one focused question
   before structuring. See `references/epic-splitting.md`.

5. **Draft the story, grounded and conflict-resolved.** Ground every claim in the
   supplied sources. Resolve conflicting facts by the hierarchy: the Project
   Profile wins → else sources that agree → else **stop and ask, naming the exact
   conflict**. Mirror the live template's structure exactly and derive the `[AC]`
   subtasks per `references/story-structure.md`. Announce section progress in chat
   for long drafts.

6. **Draft in chat, then push only after approval.** Follow
   `raftkit-core/write-protocol`: show the full drafted story and name the exact
   target task; wait for explicit approval (silence is not approval). Only then
   write `html_notes` (applying the Asana HTML rules) and create the `[AC]` +
   `Development` / `Testing` / `Bugs` subtasks.

7. **Confirm back** with the task link and a one-line summary
   ("story + N `[AC]`s + Dev/Testing/Bugs created").

## Sizing one story

A PM may ask how long a story will take — right after this skill writes it, or
later against an existing story.

**One hour range for a whole story is this skill's job.** Return it with named
assumptions, opened by the exact watermark as its first line —
`Requires founder review — not a client commitment.` — and carry the estimation
approval chain beneath it. Hours only, never days. Sizing does **not** run the
readiness gate; an unresolved story area becomes a named assumption and widens
the range instead of blocking the answer. Mechanics and the capped output shape
are in `references/sizing.md`.

**The implementing developer is a required input** — the name of the developer who
will build the story and vet the number. Required for any output that carries
numbers: it fills the vetting link of the approval chain. There is no lookup source
and no default — the PM names them. If none is given, stop and ask before emitting
a range; never guess a name, and never emit numbers with that slot unfilled.

The boundary is the size of the ask, not the word used. One story is answered
here, however the ask is phrased. A whole feature list or a backlog is
[estimation](../estimation/SKILL.md)'s lane — hand it over and stop. A quote or
a price is neither skill's: those are founder calls.

## Guardrails

- **No invented facts.** Never write "add appropriate text" or a placeholder for
  something only the product knows — ask instead.
- **No cached template text.** The format comes from the live fetch, so a template
  change in Asana is reflected the same day with no plugin release.
- **An existing story is amended, never rewritten.** Mode B is additive and
  gated. Its rules live in `references/amend-mode.md` and are not restated here.
- **Sources are confirmed before drafting, every run** — this checkpoint precedes
  the existing draft → approve → push gate for the story body and does not
  replace or duplicate it.
- **Asana free tier only** (`raftkit-core/house-rules`): no dependencies, custom
  fields, milestones, start dates, or approval tasks. Express relationships (epic
  ↔ sub-story, depends-on) as task links in the description.
- **Escalate to founders** on budget, contracts, relationship risk, or anything
  that reads as a client commitment — never decide it inside the story.
- **Plain English out** — every line a human reads follows `raftkit-core/house-rules`' plain-language rules; a house term gets its one-line gloss on first use.

## Reference files

- **`references/story-structure.md`** — how to mirror the live template exactly
  and derive the `[AC]` + fixed subtasks from the story's content.
- **`references/epic-splitting.md`** — the cohesive-vs-epic judgment and how epics
  are structured one sub-story at a time.
- **`references/sizing.md`** — how one story is sized: the hour range, the named
  assumptions, what widens the range, the hard output cap, and the redirects for
  bulk lists, prices, and dates.
- **`references/amend-mode.md`** — Mode B: the readiness-gate entry test and its
  three outcomes, the mid-build warning, the diff-first draft, the additive `[AC]`
  rules, the comment that tags every follower of the task, and the closing
  re-audit.


## Asana rendering

All Asana output is rendered and verified through core `asana-formatting` (per-surface tag matrix, markdown→HTML conversion, mentions, read-back verification), behind the `write-protocol` draft → approve → push gate.
