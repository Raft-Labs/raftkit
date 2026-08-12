# Amend mode — extend an existing story without rewriting it

Mode B. The PM asks to extend, update, or change a story that already exists in
Asana. The output is a **diff** the PM approves, then an in-place edit: the
description merged, acceptance criteria added or reworded, everyone following the
task tagged on it, and the readiness gate re-run.

This mode exists because a downstream gap had nowhere to go. A developer or QA
finds that a story is missing a requirement; the developer cannot answer it,
because it is the PM's to answer; the gap list comes back to the PM — and until
now no skill could act on it. The gap then got settled verbally and the story
stayed wrong, which defeats the story being the contract for QA and scope-guard.

Mode A (the run flow in SKILL.md) authors a story into a task that has none.
This mode never authors and never rewrites. **Never a full rewrite** — additive
edits only, per the rules below.

## The entry gate — story-readiness decides

Run `raftkit-pm/story-readiness` on the target story and branch on its verdict.
One call is enough: that gate derives its checklist from the **live** Feature
Template (`raftkit-core/workflow-constants`) and matches sections by number and
meaning, so a body that is not the template shape already fails it. Do not
invent a second conformance test.

- **PASS** → amend. This is the common case even for a story that is silent
  about the new scope, because the gate audits a story against its own content.
- **NOT READY** → **refuse the amend.** Print the gate's gap list exactly as it
  came back, then the line below. **No override**, and no partial amend of the
  sections that happen to be complete:

  ```output
  Amend refused - this story is not ready yet.
  Fix these gaps in Asana, re-run the readiness gate, then ask me to amend.
  ```

  The gaps are the PM's to fix by hand. A story that is both incomplete and in
  need of extending gets no shortcut here — a half-ready story amended into a
  bigger half-ready story is worse than a refusal.
- **Empty description** → this is authoring, not amending. Say so and route to
  **Mode A**; never treat a stub as a story to extend.
- **Bad link or invalid GID**, and **no access** → surface `story-readiness`'s
  own two messages unchanged. The fix differs for each, which is why that gate
  keeps them separate.

## Mid-build — the contract is moving under a developer

Read the fixed subtasks. If **`Development`** or **`Testing`** is already
ticked, stop and say so before drafting anything:

```output
Heads up - this story is already being built.
  Development: done
  Testing: not started
Amending changes the agreed scope under the developer.
Confirm you want to amend anyway, or hold this for a follow-up story.
```

Wait for a **separate** explicit go. It is **distinct from the push approval**
below, and neither implies the other: one accepts the disruption, the other
accepts the wording. A silent mid-build amend is the exact failure this mode
exists to prevent.

## Ground the extension before drafting

The one rule in SKILL.md holds unchanged — nothing is invented. Confirm the
sources for the new scope by name before drafting, the same checkpoint Mode A
runs. A requirement that arrived verbally on a call is not a source until the
PM states it in the session or points at a written record. Resolve conflicts
between the story's existing content and the new sources by the same hierarchy;
an unresolved conflict stops the run and names itself.

## Draft the diff, not the story

Show all five parts in one draft, so the PM sees what moves and what does not:

1. **Untouched sections** — listed by number and title. Nothing else about them.
2. **Changed sections** — the current text, then the replacement, per section.
3. **New `[AC]`s** — in full, each one independently verifiable.
4. **Reworded `[AC]`s** — current wording, then the replacement. Only for an
   acceptance criterion the PM's instruction actually named.
5. **The tag comment** — its full text, including the closing `CC:` line with the
   exact followers it will mention, so a stale name is corrected before the push
   and not after.

## Additive rules

- **Never delete** a section, **never renumber** one, and **never drop** an
  `[AC]` subtask. Removing agreed scope is a decision, not an edit: it goes to
  the board as a proposal.
- Reword an existing `[AC]` **only where the PM's instruction names it**.
  Silence about an acceptance criterion means it stays **byte-identical**.
- **Never tick** and **never complete** any subtask. Ticking `Development` is
  the developer's, `Testing` is QA's.
- `Development`, `Testing`, and `Bugs` are matched by exact name, and are never
  audited for coverage or edited here.
- New acceptance criteria follow `story-structure.md` exactly — the same `[AC] `
  prefix, one verifiable behaviour each, mapping to a test.

## The push

One approval round through `raftkit-core/write-protocol`, then push in order:
the merged description, the `[AC]` creates and rewordings, then the tag comment.

Asana replaces a description **wholesale** — there is **no partial edit** — so
the approved diff is the only thing that makes this write safe. The PM's amend
instruction is the **explicit** description-overwrite authorization that
`raftkit-core/asana-formatting` requires; an inferred instruction is not enough.
Read the task first, and after the push read the result back and verify the
render per `asana-formatting/references/verification.md`.

## Tag everyone following the task

One comment on the amended task, carrying the amend summary, and closing with a
single **`CC:` line as its last line** that @-mentions **every follower of that
task** — the whole list as Asana holds it, in that order, separated by spaces.
Do not filter it, do not sort people into roles, and never add anyone who is not
on it: whoever followed the story is who the amend concerns. Read the follower
list fresh in the same run, never from an earlier one.

The `CC:` line is the last line of the comment, always. Mentions never appear
inside the summary above it — the summary states what changed, the `CC:` line
states who is being told. One line, one prefix, no per-name role labels.

Mechanics come from `asana-formatting/references/mentions.md` and are not
re-authored here: send the `<a data-asana-gid="GID"/>` form when the object is
accessible, and fall back to plain text names when it may not be, because a
rejected mention fails the whole write.

Two states to handle rather than guess at:

- **The list is empty** — say so and ask the PM who should be following the
  story. Never pick names to fill the gap, and never push a bare `CC:` prefix
  with nothing after it.
- **A name on the list looks wrong** to the PM — they correct it from the draft
  in step 5 above, before the push. That is why the draft shows the list.

```output
Story amended - 12 Aug 2026
Added: 2 acceptance criteria for the onboarding-flow change.
Changed: section 6 edge cases, section 7 copy.
Source: client call notes, 3 Aug 2026.
Check the new criteria before you build or test against this story.
CC: Person1 Person2 Person3
```

The comment is the notification channel. Nothing about the amend is left in
chat only.

## Close the loop

Re-run `story-readiness` on the amended story and report its **verdict** — PASS,
or the new gap list. A description edit is exactly what that gate can see, so
the re-audit is meaningful here and worth doing every time.

Then confirm back in one block: the task link, what changed, who was tagged, and
the verdict.

```output
Amended: <task link>
Description: 2 sections changed, 9 untouched.
Criteria: 2 added, 1 reworded, none removed.
Tagged: 3 people on the task.
Re-audit: ready to hand off.
```
