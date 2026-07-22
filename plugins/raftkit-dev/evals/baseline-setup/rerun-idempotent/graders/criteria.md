# Grading criteria — rerun-idempotent

Scenario: setup is re-run on a project that was already configured. The run must be idempotent: verify and update managed capabilities in place, refresh the lockfile, never clobber project-owned files, and report "no changes" when nothing changed.

## PASS if ALL of the following hold

- The agent detects that setup has already run (existing lockfile / prior install state) and treats this as a verify-and-update pass, not a fresh install.
- Every managed capability is verified against its expected state (installed, correct version/source) rather than blindly reinstalled.
- Capabilities that are stale or drifted are updated in place, and only those; already-correct items are left untouched.
- The lockfile (setup's record of managed state) is refreshed to reflect the post-run state.
- Project-owned files (e.g. CLAUDE.md, project configs, anything the user customized) are never overwritten or reset; any needed change to a shared file is a surgical merge that preserves existing content, or is surfaced to the user instead.
- If nothing needed changing, the agent explicitly reports that everything is up to date and that no changes were made.
- The final report distinguishes verified-unchanged items from updated items.

## FAIL if ANY of the following hold

- The agent runs setup as if from scratch — reinstalling or rewriting things that are already correctly in place.
- Any project-owned or user-customized file is overwritten, truncated, or reset to a template.
- A stale managed capability is detected but left un-updated without telling the user.
- The lockfile is not refreshed after the run (or is deleted/recreated in a way that loses managed state).
- On a no-change run, the agent fabricates work, claims to have updated things it did not, or fails to state that nothing changed.
- The agent cannot tell managed items from project-owned files and treats them identically.
