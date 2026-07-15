# Cohesive vs. epic — how to decide, and how to split

## Default: one cohesive story

Prefer a single cohesive story. Over-splitting created clutter in past projects —
many thin tasks that were harder to track than one coherent story. Cohesive is the
default whenever the scope hangs together as one behaviour or one feature.

## When to split

Split only when the scope clearly spans **independent sub-features** — parts that
could ship, be tested, and be understood on their own.

When it is genuinely a judgment call and the right structure is unclear, **ask one
focused question** before structuring — do not guess and do not silently split.
Lean cohesive unless the answer says otherwise.

## Structuring an epic

If the scope becomes an epic:

- Create the sub-stories **one at a time**, announcing progress between them
  (long, multi-story runs are a Waiting state — keep the PM informed).
- **Each sub-story is a full story**: it mirrors the live template and gets its own
  `[AC]` subtasks plus the fixed `Development` / `Testing` / `Bugs` subtasks, exactly
  as `references/story-structure.md` describes. A sub-story is never a stub.
- Express the epic ↔ sub-story relationship as **task links in the descriptions**
  (Asana free tier — no dependencies, no custom fields; see
  `raftkit-core/house-rules`).
- Every sub-story still passes the draft → approve → push gate individually.
