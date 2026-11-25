# Asana HTML

Draft in markdown; convert to this subset at push time for the surface you write to.

## Tags

| Tag | Description | Comment | Project brief |
|---|---|---|---|
| `<h1>` `<h2>` | yes | **no** | yes |
| `<strong>` `<em>` `<u>` `<s>` `<code>` `<pre>` `<blockquote>` | yes | yes | yes |
| `<ol>` `<ul>` `<li>` `<a href>` `<a data-asana-gid>` | yes | yes | yes |
| `<hr/>` `<img src>` | yes | **no** | yes |
| `<table>` `<tr>` `<td>` | **no** | **no** | yes |
| `<br/>` `<p>` `<h3>`+ | never | never | never |

- Wrap the body in one `<body>…</body>`; close and balance every tag; `<li>` only inside a list.
- A third heading level, or anything a comment cannot hold, becomes `<strong>Label</strong>` plus a list.
- `<br/>` rejects the write. Named entities render literally: use the character. Escape `&` `<` `>` in prose.
- Markdown maps directly: `#`/`##` → `<h1>`/`<h2>`, `**b**` → `<strong>`, fenced code → `<pre>`, `[t](url)` → `<a href>`, `---` → `<hr/>`, `>` → `<blockquote>`.

## Mentions

`<a data-asana-gid="GID"/>` expands to the object's name; `data-asana-dynamic="false"` keeps your own text. A mention you cannot access rejects the whole write; when in doubt, use a plain `<a href="…">text</a>`.

## Read-back

A description is read back once with `html_notes`; a comment's read-back is the `html_text` its create call returned. Compare against the approved draft. Match → success line with the task link. Mismatch → show expected versus rendered and stop; never re-push over approved content.

## Batches

Emit the success line only when every approved write is confirmed. After a timeout, look the target up by name before any retry, so nothing is created twice.
