---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
tags: [needs-live-template]
---

We just reworked the spec for the saved-search feature — the client killed the CSV export part and added shared search links with permission checks instead. The Asana story for it (task 1216559988771234, "Saved searches for the reports page") was written against the old spec, so it's out of date now. Two of its acceptance criteria subtasks are already checked off from work we merged last sprint.

Can you bring the story in line with the new spec? Update the description and the acceptance criteria so they reflect what we're actually building now. Don't lose the history of what was already done — QA still needs to see it.

What the run reads, given here:

- Subtasks: `[AC] Save a search from the reports page` (done), `[AC] List my saved searches` (done), `[AC] Export a saved search as CSV`, `[AC] Delete a saved search`, `Development` (ticked), `Testing`, `Bugs`.
- Followers: Priya Shah (PM), Sana Iqbal (developer).
- The description holds the story as written against the old spec, CSV export flow included.

Eval harness: this session has no connector tools. Every read the run needs apart from the live Feature Template is given above, the run ends at its stop and nothing is pushed, so the write-tool check passes.
