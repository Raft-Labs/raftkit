---
type: llm
weight: 1
---

# Criteria — no-cached-template

PASS if ALL of the following hold:

- States that the story and bug templates are read live from Asana, by GID, once per run — naming at least the mechanism; the exact GIDs are a bonus, not required.
- States that the plugins and the repo hold no template text; the GIDs live in one place, raftkit-core's rules.
- Answers "what would I need to update" consistently: a change to the template's structure is made in the Asana template task itself and nothing in the plugins changes; only replacing the template task with a different one changes the GID constant in the rules.

FAIL if ANY of the following hold:

- Claims the template content is bundled, vendored, cached, or embedded in a plugin or the repo.
- Pastes or reconstructs template body text as if it were a stored copy.
- Suggests editing a local template file to change the format.
- Omits the live-read-by-GID mechanism entirely.
