# Grading criteria — comment-surface-restrictions

Scenario: the agent must post a richly structured update (headings, a table, a horizontal rule in the source draft) as an Asana task comment. Comments are Asana's most restricted rich-text surface: no headings, no horizontal rules, no tables. The agent must re-express the structure within what comments support — bold labels and lists — without dropping information.

## PASS if ALL of the following hold

- The comment payload contains no heading tags (`<h1>`/`<h2>`/`<h3>`/etc.). Section titles from the draft ("Sprint Checkpoint", "Progress by area", "Blockers", "Next up") are expressed as bold labels (`<strong>` or equivalent) instead.
- The comment payload contains no `<table>`, `<tr>`, `<td>`, or any table markup, and no markdown pipe-table text. The per-area status breakdown is restructured as a list (e.g. one `<li>` per area with bold area name, status, and owner) or equivalent non-table form.
- The comment payload contains no `<hr>` and no literal `---` divider text; the divider is simply dropped or replaced by paragraph/label separation.
- All information from the draft survives the restructuring: every area/status/owner triple, every blocker, and every next-step item appears in the posted comment.
- Bullet content is expressed as real list markup (`<ul>`/`<li>`), not literal `-` characters.
- The payload uses only elements the comment surface supports (bold/italic, links, lists, paragraphs/line breaks within a single `<body>` wrapper, or the equivalent if posting via a connector that handles wrapping).

## FAIL if ANY of the following occur

- A table (HTML table tags or a markdown pipe table) appears in the comment payload.
- Heading tags appear in the comment payload.
- An `<hr>` tag or raw `---` divider appears in the comment payload.
- The draft is pasted into the comment as raw markdown (`##`, `|` pipes, `---`) with no adaptation to the surface.
- Information is silently dropped during restructuring — e.g. the owner column disappears, a blocker or next-step item is missing.
- The agent posts the structured content to a different surface (e.g. overwrites the task description) instead of a comment, without the user asking for that.
- The agent refuses or claims the content cannot be posted rather than restructuring it for the comment surface.
- The agent claims success without actually posting the comment.
