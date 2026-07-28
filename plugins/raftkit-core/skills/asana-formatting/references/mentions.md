# Object references and @-mentions

Asana turns an `<a>` with a `data-asana-gid` into a live reference to the object
(task, project, user), rendered with the object's display name.

## The mechanics

- **Auto-expanding reference:** `<a data-asana-gid="GID"/>` — Asana expands it to
  a correctly formatted reference showing the object's display name. Provide the
  GID only; if you have access to the object, Asana generates the `href` and the
  rest.
- **Custom anchor text:** add `data-asana-dynamic="false"` to keep your own text:
  `<a data-asana-gid="GID" data-asana-dynamic="false">read the story</a>`.

## The no-access fallback

If you do **not** have access to the referenced object, Asana rejects a mention
that has no `href`. So:

- When you have access → send the `data-asana-gid` form and let Asana expand it.
- When you may lack access, or the object is outside the workspace → fall back to
  a plain `<a href="…">` link with explicit text. A plain link always renders;
  a broken mention rejects the whole write.

When unsure which case applies, prefer the plain `<a href>` link — it never
fails, and the reader still gets a working link.
