---
name: story-skill-generator
description: This skill should be used when a RaftLabs PM wants to turn an approved Project Profile into a reusable, project-specific story skill — e.g. "generate the story skill for this project", "bake my project's context into a user-story skill", "make a flowhoney-user-story-style skill for project X", "create a <project>-user-story skill". It uses skill-creator to emit a self-contained `<project>-user-story` skill package with the project's glossary, roles, conflict hierarchy, and dated source snapshots bundled in `references/` — so story runs read local files, not connectors — while the story format is always read live. Requires an APPROVED Project Profile; refuses to generate from raw, unapproved sources. For writing one individual story into a task (not a reusable skill), use the `user-story` skill instead.
user-invocable: true
---

# story-skill-generator

Turn an **approved Project Profile** into a reusable `<project>-user-story` skill —
the flowhoney pattern (PRD §5.2), automated. The hand-built `flowhoney-user-story`
skill worked because it had the
project's context baked in and read the format live; this skill produces that same
artifact for any project via **skill-creator**, so a PM stops re-feeding the
same glossary, roles, and sources on every run. The generic
[`user-story`](../user-story/SKILL.md) skill is the *method*; this generator emits a
project's *specialized sibling* of it.

## The one rule that governs everything

**Bake CONTEXT, never FORMAT — and never generate without an approved profile.**
Context (glossary, roles, conflict hierarchy, bundled source snapshots) is what changes
per project and is safe to bake. Format is the Feature Template, which changes in Asana and must
be read **live** every run — baking it would ship a stale story shape silently, the exact
failure RaftKit's live-fetch design exists to prevent. If there is no approved Project
Profile, do not proceed and do not improvise one from raw sources.

## Preconditions — confirm before generating anything

1. **An APPROVED Project Profile.** The profile is the sole source of the baked context.
   Reach it through its decided home — the pinned Asana resource task linking the
   profile's Drive doc — or wherever the PM points for a project that keeps it
   elsewhere. A raw spec/PRD/notes bundle is **not** a profile and must be refused.
2. **The target project's name** — used to name the emitted skill `<project>-user-story`.

**Empty state — no approved profile.** Stop with this exact message, and do nothing else:

```output
Run project-onboarding first — I need an approved Project Profile to bake from.
```

## Run flow

1. **Read the approved profile and snapshot the sources.** Extract the four baked
   elements per `references/baked-context.md`: the project **glossary**, the **roles**
   (who is allowed / not allowed to do what), the **conflict hierarchy** (which source
   wins when sources disagree), and the **sources**. Fetch each source once — the profile
   included, by whatever access path it arrives on (connector, upload, link, or synced
   folder) — and snapshot it as markdown for the emitted skill's `references/`, headed by
   its **as-of date** and **source URL**: story runs then read these local snapshots
   instead of re-opening Drive/Gmail/Fathom every time. Never bake the template format.

2. **Emit the skill package with skill-creator.** Use **skill-creator** to author a
   self-contained `<project>-user-story` package — SKILL.md plus `references/` carrying
   the bundled snapshots — that follows the generated-skill anatomy in
   `references/baked-context.md`. Its SKILL.md:
   - carries the baked context and grounds story content in the local snapshots — the
     only live calls in a story run are the Feature Template fetch and the target task's
     Asana calls;
   - fetches the **live** template every run via `raftkit-core/workflow-constants`;
   - inherits the generic `user-story` **stop-and-ask rules verbatim** (no invented
     facts; stop and ask on a missing source, a thin profile, or a source conflict);
   - tells the PM in its own text to re-run this generator after a major change to the
     project's sources or profile.

   Emit it to the operator's skill location — the PM names it; a Drive-synced skills
   folder is a valid location and is what makes the generated skill visible to teammates —
   never into this marketplace repo (generated skills are per-project artifacts, not
   marketplace plugins).

3. **Validate before handover.** Run one validation story against a scratch task per
   `references/validation-and-regeneration.md`, and show the PM the result before declaring
   the skill ready. If the validation story diverges from the live template, the skill is
   **not delivered** — report which section diverged, fix, and regenerate. Announce
   progress stepwise (reading profile → emitting → validating) so a long run is legible.

4. **Deliver.** On a clean validation, hand over the skill with the validation-story link
   and a reminder: *regenerate after a major change to the project's sources or profile.*

## Regeneration

When the project's sources or profile change materially, the PM re-runs this skill. Per
`references/validation-and-regeneration.md`: re-derive the baked context, **re-snapshot
every source with fresh as-of dates**, and build the
replacement as a **candidate under a distinct staging identity**, then **validate the candidate
itself through the pre-delivery gate before touching the live skill** — the currently delivered
skill keeps working until the replacement is proven, and a divergence blocks the swap. Then
**show the PM the baked-context diff** (what
glossary/roles/hierarchy entries changed, and which snapshots were refreshed with their
old → new as-of dates) and the validation result, **get explicit
approval, and only then replace** the existing skill — regeneration replaces, it never forks —
and bump the generated skill's version. Silence is not approval; never overwrite a working,
already-delivered skill with an unvalidated one (`raftkit-core/write-protocol`).

## Guardrails

- **Never touch the generic `user-story` skill.** This generator emits a *separate*
  sibling; the generic skill is out of scope and stays byte-identical.
- **Manual re-run only.** No scheduled or automatic regeneration in v1 — the PM triggers
  every run.
- **Per-project artifacts, not marketplace plugins.** Generated skills are not distributed
  through the RaftKit marketplace.
- **No cached template text** anywhere — in this skill or in what it emits. Format is the
  live fetch, always (`raftkit-core/house-rules`). Bundled *source* snapshots are required;
  cached *template* text stays forbidden — the boundary is CONTEXT vs FORMAT
  (`references/baked-context.md`).
- **Escalate to founders** (`raftkit-core/house-rules`) on budget, contracts, relationship
  risk, or anything that reads as a client commitment.
- **Plain English out** — every line a human reads follows `raftkit-core/house-rules`' plain-language rules; a house term gets its one-line gloss on first use.

## Reference files

- **`references/baked-context.md`** — the four baked elements and how to extract them, the
  CONTEXT-vs-FORMAT boundary, the snapshot-by-default bundling rule (dated, source-linked
  snapshots in `references/`), and the anatomy of the emitted `<project>-user-story`
  package (live template every run; local snapshots for content; stop-and-ask verbatim).
- **`references/validation-and-regeneration.md`** — the pre-delivery validation gate (one
  story against a scratch task; package shape + connector budget checked; divergence blocks
  handover and names the section) and the regeneration flow (baked-context + snapshot diff;
  replace, never fork; version bump).
