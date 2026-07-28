# Read-back verification

Asana's rendering is final and hard to roll back cleanly, so every push is
verified by reading the result back — the render is checked against intent, and
a mismatch is reported, never silently rewritten.

## The check

1. After the push, re-fetch the task (or comment) with `html_text` included —
   the connector's default `text` field is a **plain-text rendering that
   carries no markup**, so a stripped `<h1>`/`<hr>`/`<ul>` is invisible in it;
   the exact defect this check exists to catch can only be seen in
   `html_text`. Always compare against `html_text`, never `text`.
2. Compare that `html_text` against the approved intent: are the headings,
   lists, separators, and links present as tags? Missing headings/lists/`hr`
   almost always mean invalid HTML nesting — the tags were stripped.
3. If the rendering matches the approved draft → report success with the task
   link.
4. If it does **not** match → report the mismatch to the human, showing what was
   expected versus what rendered. Do not silently re-push a "corrected" body over
   the approved content; the approved content is authoritative. A re-render is a
   new draft through the write-protocol gate.

## Failure handling

- **Literal markdown rendered** (e.g. `**bold**` shows as text) → the body was
  not converted; convert per `conversion.md` and re-draft.
- **A third-level section is flat** → `<h3>` was used; use bold-label-plus-list.
- **Request rejected** → an unclosed or invalid-nesting tag; balance the tags.
- **A mention did not resolve** → no access to the object; fall back to a plain
  `<a href>` link (`mentions.md`).

The rule that never bends: **approved content is never altered silently.** A
verification mismatch is surfaced for a human decision, not fixed in place.
