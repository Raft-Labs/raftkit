# Suite slice reuse — pull matching cases by case ID

Where a project already has a test suite (built by `test-suite` and kept in a
Google Sheet), a story's run sheet should **reuse** the suite's relevant cases
rather than re-derive them — so the same case is described once, in one place, and
QA is not testing two subtly different versions of it.

## The rule

- **Pull matching cases by case ID — no duplication.** The suite's cases carry
  **stable case IDs** (the sync key). When a suite Sheet exists for the story's
  project, identify the cases that cover this story and pull them into the run sheet
  **by case ID**, carrying the ID through so the run sheet row and the suite row are
  the same case. Do **not** re-generate a case the suite already has under a new
  number — that is the duplication this rule forbids.
- **Add story-specific steps for the rest.** Whatever the suite does not already
  cover — story-specific scenarios, WEESLD states, permission boundaries — is
  generated fresh as new steps in the run sheet.

## The case-ID scheme is owned elsewhere

The case-ID scheme — the stable-key guarantee, the per-project origin prefixes
(recorded per project, never hardcoded), never-renumbered / never-reused — is
defined once in **`test-suite/references/sheet-format.md`**. This skill **reads and
reuses** those IDs by that scheme; it does not define, assign, or renumber case IDs
(assigning IDs is `test-suite`'s job on the suite Sheet). Match the suite's scheme;
do not invent a parallel one.

## Suite unreachable — generate standalone

The suite is an optimisation, never a precondition. If no suite Sheet exists for
the project, or the Sheet cannot be read (connector absent, no access), **generate
the run sheet standalone from the story alone and say the slice link is missing** —
name that suite cases could not be pulled and why, so QA knows the sheet is not
deduplicated against a suite. Never block generation on the suite, and never
partially stitch in cases from a Sheet you could not fully read.
