---
name: story-skill-generator
description: This skill should be used when a RaftLabs PM wants to turn an approved Project Profile into a reusable, project-specific story skill — e.g. "generate the story skill for this project", "bake my project's context into a user-story skill", "make a flowhoney-user-story-style skill for project X", "create a <project>-user-story skill". It uses skill-creator to emit a self-contained `<project>-user-story` skill with the project's glossary, roles, conflict hierarchy, and source links baked in, while the story format is always read live. Requires an APPROVED Project Profile; refuses to generate from raw, unapproved sources. For writing one individual story into a task (not a reusable skill), use the `user-story` skill instead.
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
Context (glossary, roles, conflict hierarchy, source links) is what changes per project
and is safe to bake. Format is the Feature Template, which changes in Asana and must
be read **live** every run — baking it would ship a stale story shape silently, the exact
failure RaftKit's live-fetch design exists to prevent. If there is no approved Project
Profile, do not proceed and do not improvise one from raw sources.

## Preconditions — confirm before generating anything

1. **An APPROVED Project Profile.** The profile is the sole source of the baked context.
   Its home is not fixed (an open decision) — the PM points at the approved profile; there
   is no default location. A raw spec/PRD/notes bundle is **not** a profile and must be
   refused.
2. **The target project's name** — used to name the emitted skill `<project>-user-story`.

**Empty state — no approved profile.** Stop with this exact message, and do nothing else:

```
Run project-onboarding first — I need an approved Project Profile to bake from.
```

## Run flow

1. **Read the approved profile.** Extract the four baked elements per
   `references/baked-context.md`: the project **glossary**, the **roles** (who is allowed
   / not allowed to do what), the **conflict hierarchy** (which source wins when sources
   disagree), and the **source links**. Cite sources by **live URL** wherever linkable;
   fall back to a bundled snapshot only when a source cannot be linked, and stamp it with
   its **as-of date**. Never bake the template format.

2. **Emit the skill with skill-creator.** Use **skill-creator** to author a self-contained
   `<project>-user-story` skill whose SKILL.md carries the baked context and follows the
   generated-skill anatomy in `references/baked-context.md`: it fetches the **live**
   template every run via `raftkit-core/workflow-constants`, and it inherits the generic
   `user-story` **stop-and-ask rules verbatim** (no invented facts; stop and ask on a
   missing source, a thin profile, or a source conflict). Emit it to the operator's skill
   location — never into this marketplace repo (generated skills are per-project artifacts,
   not marketplace plugins).

3. **Validate before handover.** Run one validation story against a scratch task per
   `references/validation-and-regeneration.md`, and show the PM the result before declaring
   the skill ready. If the validation story diverges from the live template, the skill is
   **not delivered** — report which section diverged, fix, and regenerate. Announce
   progress stepwise (reading profile → emitting → validating) so a long run is legible.

4. **Deliver.** On a clean validation, hand over the skill with the validation-story link
   and a reminder: *regenerate after a major change to the project's sources or profile.*

## Regeneration

When the project's sources or profile change materially, the PM re-runs this skill. Per
`references/validation-and-regeneration.md`: re-derive the baked context and build the
replacement as a **candidate under a distinct staging identity**, then **validate the candidate
itself through the pre-delivery gate before touching the live skill** — the currently delivered
skill keeps working until the replacement is proven, and a divergence blocks the swap. Then
**show the PM the baked-context diff** (what
glossary/roles/hierarchy/source-link entries changed) and the validation result, **get explicit
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
  live fetch, always (`raftkit-core/house-rules`).
- **Escalate to founders** (`raftkit-core/house-rules`) on budget, contracts, relationship
  risk, or anything that reads as a client commitment.

## Reference files

- **`references/baked-context.md`** — the four baked elements and how to extract them, the
  CONTEXT-vs-FORMAT boundary, the live-URL-over-snapshot citation rule, and the anatomy of
  the emitted `<project>-user-story` skill (live template every run; stop-and-ask verbatim).
- **`references/validation-and-regeneration.md`** — the pre-delivery validation gate (one
  story against a scratch task; divergence blocks handover and names the section) and the
  regeneration flow (baked-context diff; replace, never fork; version bump).
