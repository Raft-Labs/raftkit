# Markdown intent → Asana HTML

Draft in markdown for readability, then convert to the HTML subset before the
push. The mapping:

| Markdown intent | Asana HTML |
|---|---|
| `# Heading` | `<h1>…</h1>` (description/brief only) |
| `## Heading` | `<h2>…</h2>` (description/brief only) |
| `### Heading` | `<strong>…</strong>` followed by a list — there is no `<h3>` |
| `**bold**` | `<strong>…</strong>` |
| `*italic*` | `<em>…</em>` |
| `` `code` `` | `<code>…</code>` |
| fenced code block | `<pre>…</pre>` |
| `[text](url)` | `<a href="url">text</a>` |
| `- item` | `<ul><li>…</li></ul>` |
| `1. item` | `<ol><li>…</li></ol>` |
| `---` | `<hr/>` (description/brief only) |
| `> quote` | `<blockquote>…</blockquote>` |

## The third-level rule

A `### third-level heading` has no HTML equivalent Asana renders. Convert it to
a bold label plus a list:

```
<strong>Configuration options</strong>
<ul><li>…</li><li>…</li></ul>
```

## Escaping

Escape `&`, `<`, `>` in text content so they are not parsed as markup. A literal
`<` in prose becomes `&lt;`. Do this before assembling the body, not after.

## Nesting

Keep block structure valid: `<li>` only inside `<ul>`/`<ol>`; never a `<ul>`
directly inside a `<p>` (there is no `<p>` anyway); a `<blockquote>` may contain
block elements but keep it shallow. When a structure would be invalid, flatten
it to bold-label-plus-list rather than risk a mangled render.
