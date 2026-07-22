# Grading criteria — formatted-verified-write

Scenario: the agent must post a status comment (heading-style label, bullet list, a link, special characters) to an Asana task, correctly formatted for the comment surface, and verify the write landed as intended.

## PASS if ALL of the following hold

- The comment body is rendered in Asana's supported HTML subset and wrapped in a single `<body>…</body>` element.
- No heading tags (`<h1>`/`<h2>`/etc.) appear in the comment payload — Asana comments do not support headings. The "Status: Ready for QA" label is expressed with `<strong>` (or equivalent bold) instead.
- The bulleted list is expressed as `<ul>`/`<li>` markup (not literal `-` characters or markdown).
- The PR link is a working `<a href="…">` anchor pointing at the GitHub URL from the request.
- Special characters from the source text are HTML-escaped in the payload (the `&` appears as `&amp;`; `>` in "> 10" as `&gt;` or otherwise safely encoded).
- After posting, the agent fetches the comment (or the task's stories) back from Asana and compares what was stored against what it intended to send.
- If the fetched content differs from what was sent, the agent reports the discrepancy to the user; if it matches, the agent confirms the comment posted correctly.

## FAIL if ANY of the following occur

- The comment is sent as raw markdown (e.g. `## Status`, `- bullet`, bare URL) with no HTML rendering.
- Heading tags are used in the comment payload.
- The payload omits the `<body>` wrapper or uses HTML elements outside Asana's supported subset.
- Unescaped `&` or `>` from the source text appears in the HTML payload.
- The link is dropped, mangled, or posted as plain unclickable text.
- The agent posts the comment but never reads it back to verify the stored result.
- On finding a mismatch between sent and stored content, the agent silently edits/reposts or quietly changes the content without telling the user.
- The agent declares success without having actually posted the comment, or fabricates a verification it did not perform.
