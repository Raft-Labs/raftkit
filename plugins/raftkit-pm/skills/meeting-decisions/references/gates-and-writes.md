# The two gates and their writes

The call's extraction feeds two outputs, each behind its **own** approval gate. They
are independent: approving the profile delta never authorizes the task batch, and
confirming the batch never authorizes a profile write. Draft each, wait for its
explicit approval, then write — `raftkit-core/write-protocol`.

## Gate A — Project Profile delta

The profile is the project's single tagged source of truth. This skill only ever
**updates an existing** profile with what the call confirmed or changed; it never
builds one (no profile → route to `project-onboarding`, per SKILL.md).

Compute a **delta, not a rewrite** — aligned with `project-onboarding`'s
`references/profile-format.md` (a fact = statement + tag + citation + date):

- **Changed** — an existing fact whose value or tag the call updates.
- **New** — a fact the call establishes that the profile did not hold.
- **Now-confirmed** — a ⚠️ Partial or ❓ Missing fact the call lifts to ✅ Confirmed.

For every delta fact:

- The **citation** is the call, in the `<meeting> @ <timestamp>` form from
  `extraction-and-citations.md` — this is the "call + timestamp" citation the profile
  format expects for a meeting source.
- The **date** (as-of) is the meeting date.
- The **default-to-⚠️ rule still holds**: a fact the call only implies is ⚠️ Partial,
  not ✅. Only an unambiguous on-call decision earns ✅.
- A call value that **conflicts** with an existing profile fact is surfaced as a
  conflict (both values, both citations) for the PM to resolve — never silently
  overwritten (`project-onboarding` owns the conflict rule).

Leave every untouched fact exactly as it is. Show the delta and name the exact profile
home it lands on; write **only after PM approval**, applying the Asana HTML rules from
`write-protocol` if the home is an Asana resource.

## Gate B — Asana task batch

Turn the **action items** (never scope changes as if in-scope, never decisions) into a
proposed task batch:

- **Propose first.** List each task with a title, the source citation, and a
  **suggested assignee**. Tasks are **created only after the PM confirms the batch** —
  auto-creating tasks without confirmation is out of scope.
- **Assignee resolution ladder:** suggest the owner the transcript names → if the
  owner is unclear, ask **one focused question** → if still unresolved, create the
  task **unassigned**. Never guess an owner to fill the slot.

### Asana free-tier task shape

Everything created respects the free tier — **no dependencies, custom fields,
milestones, start dates, or approval tasks**. Express relationships as links inside
the task description, not as structured Asana relations:

- Link the **source meeting** (the recording URL) in the description.
- Link the **related story or profile** by task link / URL where relevant.
- A due date is a plain due date only if the call set one and the PM confirms it —
  never inferred.

Read any board/template GID needed live from `raftkit-core/workflow-constants`; never
hardcode a GID and never reuse a remembered template body.

### Reporting the batch

After creation, report **each created task with its link**, and name any task left
unassigned (with the question still open) so the PM can close the loop. If the PM
declines the batch, create nothing and say so plainly.
