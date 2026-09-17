# Asana HTML — render, mention, verify

Draft in markdown, convert to this HTML subset at push time, render to the surface you are writing to.

## Tag matrix

| Tag | Description | Comment | Project brief |
|---|---|---|---|
| `<h1>` `<h2>` | yes | **no** | yes |
| `<strong>` `<em>` `<u>` `<s>` | yes | yes | yes |
| `<code>` `<pre>` | yes | yes | yes |
| `<blockquote>` | yes | yes | yes |
| `<ol>` `<ul>` `<li>` | yes | yes | yes |
| `<a href>` / `<a data-asana-gid>` | yes | yes | yes |
| `<hr/>` | yes | **no** | yes |
| `<img src>` | yes | **no** | yes |
| `<table>` `<tr>` `<td>` | **no** | **no** | yes |
| `<br/>` `<p>` `<h3>`+ | never | never | never |

Only two heading levels exist; render a third level as `<strong>Label</strong>` plus a list. Comments take no headings, rules, images or tables: use `<strong>` lines and lists. `<br/>` rejects the write (400). Named entities (`&rarr;`, `&mdash;`, `&nbsp;`) render literally: use the character (→, —, a space) or ASCII. Escape `&` `<` `>` in prose before assembling the body. Wrap the whole body in one `<body>…</body>`. Close and balance every tag.

## Markdown → HTML

| Markdown | Asana HTML |
|---|---|
| `# H` / `## H` | `<h1>` / `<h2>` (description and brief only) |
| `### H` | `<strong>H</strong>` followed by a list |
| `**b**` / `*i*` / `` `c` `` | `<strong>` / `<em>` / `<code>` |
| fenced code | `<pre>…</pre>` |
| `[t](url)` | `<a href="url">t</a>` |
| `- item` / `1. item` | `<ul><li>` / `<ol><li>` |
| `---` | `<hr/>` (description and brief only) |
| `> q` | `<blockquote>` |

`<li>` only inside `<ul>`/`<ol>`; keep blockquotes shallow; when a structure would be invalid, flatten to bold-label-plus-list.

## Mentions

`<a data-asana-gid="GID"/>` expands to the object's display name; add `data-asana-dynamic="false"` to keep your own anchor text. A mention to an object you cannot access rejects the whole write, so when in doubt send a plain `<a href="…">text</a>`: it always renders.

## After the push

Re-fetch once with `html_text` (the default `text` field carries no markup) and compare against the approved draft: headings, lists, rules and links present as tags. Match → success line with the task link. Mismatch → show expected versus rendered and stop; never re-push a "corrected" body over approved content. Literal `**bold**` means the body was not converted; a flat third-level section means `<h3>` was used; a rejected request means an unclosed tag; an unresolved mention means no access, so use a plain link.

## Multi-write batches

When a run pushes several writes (description + subtasks, tick + comment, N bugs), report exactly what landed and what did not, retry only idempotent writes (a comment, a subtask create keyed by name), and never emit the success line until every approved write is confirmed. On an Asana timeout, look the target up by name before any retry so nothing is created twice.
