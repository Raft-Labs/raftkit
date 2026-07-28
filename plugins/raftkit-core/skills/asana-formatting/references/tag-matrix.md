# Per-surface tag matrix

Asana accepts different tags on different surfaces. Render to the surface you
are writing to; a tag outside its column is stripped or mangled.

| Tag | Description | Comment | Project brief |
|---|---|---|---|
| `<h1>` `<h2>` (headings) | yes | **no** | yes |
| `<strong>` `<em>` `<u>` `<s>` | yes | yes | yes |
| `<code>` `<pre>` | yes | yes | yes |
| `<blockquote>` | yes | yes | yes |
| `<ol>` `<ul>` `<li>` | yes | yes | yes |
| `<a href>` / `<a data-asana-gid>` | yes | yes | yes |
| `<hr/>` | yes | **no** | yes |
| `<img src>` | yes | **no** | yes |
| `<table>` `<tr>` `<td>` | **no** | **no** | **yes (brief only)** |
| `<br/>` | never | never | never |

## Rules that follow from the matrix

- **Only two heading levels exist** — `<h1>` and `<h2>`. `<h3>`–`<h6>` do not
  exist and are silently downgraded; render a third level as
  `<strong>Label</strong>` followed by a list (see `conversion.md`).
- **Comments are the most restricted surface** — no headings, no `<hr/>`, no
  images, no tables. Express structure with `<strong>` lines and lists.
- **Tables are project-brief only.** Never emit a table into a description or a
  comment — it will not render.
- **`<br/>` is never accepted** — it is outside the allowed element list and
  rejects the write (400), not merely stripped. Get vertical spacing from
  block elements (`<hr/>` where allowed, `<ul>`, another `<strong>` line, a
  heading).
- **Named HTML entities render literally, not as the character.** Asana does
  not resolve `&rarr;`, `&mdash;`, `&nbsp;`, etc. — the reader sees the literal
  entity text. Use the literal character (→, —, a plain space) or ASCII
  instead; escaping still applies to `&`, `<`, `>` in prose per the four
  write-protocol rules.
- **`<p>` is not in the set** — juxtapose block elements instead.
- **Comments must be wrapped** in a single `<body>…</body>`; descriptions are
  wrapped too for safety.
- All tags must be closed and balanced; an unclosed tag rejects the request or
  mangles the output.
