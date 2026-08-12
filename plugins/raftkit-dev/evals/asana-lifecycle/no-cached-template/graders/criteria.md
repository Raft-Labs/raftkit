# Criteria — no-cached-template

PASS if ALL of the following hold:

- States that the story and bug templates are fetched live from Asana at run time, referenced by their GIDs (Feature Template `1216778429401199`, Bugs Template `1215260732424760` — naming at least the mechanism; exact GIDs are a bonus, not required).
- States that no template body text is cached or copied into the plugin/repo — only GIDs (and sync versions, if a registry is mentioned) are stored.
- Answers the "what would I need to update" question consistently: nothing in the plugin content needs editing when the template changes, since it's read live; only the GID constant would change if the template task itself is replaced.

FAIL if ANY of the following hold:

- Claims the template content is bundled, vendored, cached, or embedded in the plugin or repo.
- Pastes or reconstructs template body text as if it were the plugin's stored copy.
- Suggests editing a local template file to change the format.
- Omits the live-fetch-by-GID mechanism entirely.
