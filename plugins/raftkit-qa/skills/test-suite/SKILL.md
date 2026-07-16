---
name: test-suite
description: This skill should be used when RaftLabs QA wants a project-level manual test-case suite generated from the Project Profile / product docs and kept in a Google Sheet they can edit — so QA tests from a living checklist without a local dev setup. Trigger on "generate the test suite", "build test cases for project X", "sync the QA Sheet", "regenerate the suite after the profile changed", or a re-run that re-imports QA's Sheet edits. The suite syncs two-way on stable case IDs — QA's manual edits win and conflicts are surfaced, never overwritten. For per-story run sheets use test-run-sheet; for building the profile itself use raftkit-pm project-onboarding.
user-invocable: true
---

# test-suite

Generate a comprehensive, project-level **manual** test-case suite from the
approved Project Profile (and any linked product docs) and keep it in a **Google
Sheet QA edits directly** — a living checklist QA works from without a local dev
environment. The suite syncs two ways: regeneration proposes new and changed cases,
while QA's own edits stay first-class and are never silently overwritten.

This packages the dev-environment-free QA workflow (PRD §5.4): QA tests from a
Sheet that stays in step with the product docs, keyed on stable case IDs.

## The core guarantee

**Conflict safety.** A regeneration never silently overwrites what QA changed.
Case IDs are stable across runs (the sync key); QA edits win by default; a
generated change to a QA-touched row becomes a conflict listed side by side for QA
to resolve — never an overwrite. This is the one property everything else serves;
the full rules are in `references/sync-and-conflicts.md`.

## The rules that govern everything

- **Case IDs are stable — the sync key.** Assigned once, never renumbered or
  reused, so a re-run can tell "same case, changed" from "new case".
- **QA edits win by default.** QA owns the content of the rows; the skill owns the
  structure (columns, IDs). A generated change to a QA-touched row is a conflict,
  not an overwrite.
- **Every generated case is traceable to a profile/doc fact**, and **coverage tags
  are mandatory** on every case.
- **The Sheet is the QA-facing surface.** One project per Sheet; QA reads and edits
  there, the skill syncs to it — it never writes without QA approval
  (`raftkit-core/write-protocol`).

## Inputs

1. **An approved Project Profile** for the project (and any product docs it links),
   read through the Cowork connectors. The profile is the source of truth; project
   facts live there, never in this skill (`raftkit-core/house-rules`). This skill
   only ever **reads** the profile.
2. **Where the Sheet lives / the profile home.** The profile home is an open
   decision, so it is a parameter QA/PM supplies — follow the parameterized
   profile-home pattern owned by `raftkit-pm project-onboarding`; never hardcode a
   path, GID, or single connector. One project → one Sheet.

**Empty state — no Project Profile.** Do not fabricate a suite from nothing. Route
to `raftkit-pm project-onboarding` to build the profile first, then re-run:

```
No Project Profile found — run raftkit-pm project-onboarding to build it, then re-run test-suite.
```

## Run flow

1. **Locate the profile and the Sheet.** No profile at the named home → the Empty
   state above. Detect whether a Sheet already exists for the project: none →
   first-run generate (step 3); one exists → a sync re-run (step 4).

2. **Read the approved profile and any linked docs.** Pull the facts the cases will
   derive from. Read-only — the profile is never modified here.

3. **First run — generate and export.** Produce cases **grouped by feature**, each
   with steps, test data, expected result, and a mandatory **coverage tag**, every
   generated case traceable to a profile/doc fact. Write them to a new Sheet with
   the fixed columns and a stable case-ID column; new cases take the default status.
   Large suites are written in **batches with progress**. The fixed columns, the
   coverage tags, the status values and their default, the case-ID scheme, and the
   soft-cap/split heuristic are all defined in `references/sheet-format.md`.

4. **Re-run — sync two-way, surface conflicts.** Re-import the Sheet first (QA's
   added and edited rows are first-class), regenerate from the current profile, and
   diff by case ID into the actionable buckets: new generated cases, deltas on
   untouched rows, and **conflicts on QA-touched rows listed side by side**
   (unchanged rows are left alone). QA edits win by default;
   nothing QA touched is overwritten. The full reconciliation and conflict rules
   are in `references/sync-and-conflicts.md`.

5. **Draft, then write only after QA approval.** Show what will be added, the
   proposed deltas, and the conflicts (both versions side by side); wait for QA to
   approve and resolve conflicts, then write to the Sheet
   (`raftkit-core/write-protocol`). Silence is not approval.

6. **Report the result.** On a completed sync, report using the exact success line
   defined in `references/sheet-format.md`.

## Error and limit states

- **Sheet unreachable / permission lost** — name the **exact access fix** (which
  account needs which permission on which Sheet/folder), do not partially write,
  and stop so QA can grant access and re-run. Details in
  `references/sync-and-conflicts.md`.
- **Suite grows past one navigable Sheet** — propose a **split by feature area**
  into another Sheet for the same project (QA decides); never split silently, never
  merge two projects into one Sheet. This is distinct from batching — see
  `references/sheet-format.md`.

## Guardrails

- **Read-only on the profile and docs; the only write is the Sheet**, and only
  after QA approval.
- **Out of scope:** automated test execution (guided manual is v1); per-story run
  sheets — `test-run-sheet` consumes this suite; and code-level
  unit tests (the dev's TDD owns those).
- **Asana free-tier constraints** apply to anything created in Asana
  (`raftkit-core/house-rules` owns that list). **Escalate to founders** on budget,
  contracts, relationship risk, or anything that reads as a client commitment.

## Reference files

- **`references/sheet-format.md`** — the canonical layout: the eight fixed columns
  (verbatim, in order), the coverage tags, the status values and their default,
  the stable case-ID scheme, traceability, the exact success line, and the
  soft-cap/split heuristic.
- **`references/sync-and-conflicts.md`** — the two-way sync: re-import-first
  reconciliation, the diff buckets, the QA-wins conflict rule (provisional pending
  PRD §10.8) with side-by-side presentation, batching, and the empty/error states.
