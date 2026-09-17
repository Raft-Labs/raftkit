# Amend — extend a story without rewriting it

Read at once: the story and all its subtasks, the Feature Template (once per conversation), and the followers — the follower list is re-read for every amend, never reused from an earlier fetch.

## The draft is a diff, in five parts

1. Untouched sections, listed by number and title.
2. Changed sections: current text, then replacement.
3. New `[AC]`s in full, one verifiable behaviour each.
4. Reworded `[AC]`s (only where the PM's instruction named them): current, then replacement.
5. The follower comment, full text, closing with one `CC:` line that mentions every follower of the task as Asana lists them, via `<a data-asana-gid="GID"/>`; never plain-text names, never filtered, never anyone added.

Above the diff: readiness gaps as numbered questions filled only from the PM's reply (the go is refused while one is blank), and when `Development` or `Testing` is ticked, this line. The go covers it.

```output
This story is already being built; amending changes the agreed scope under the developer.
```

An empty follower list → a question in the draft: who should follow? A mention that cannot be formed → say so in the draft; nothing is posted until it can.

## Additive rules

Never delete or renumber a section; never drop an `[AC]`; never tick a subtask; `Development`, `Testing`, `Bugs` are matched by exact name and never edited. Silence about an `[AC]` keeps it byte-identical. Removing agreed scope is a board proposal, not an edit.

## The push

In order: the merged description (only when part 2 has approved changes; re-read the task immediately before this write, since Asana replaces descriptions wholesale), the `[AC]` creates and rewordings, then the comment. Not one transaction: on any failure stop, read the task back, report what landed by name, and retry only the description (idempotent); an `[AC]` create is matched by text before any retry. Never confirm a half-landed amend.

Re-check readiness whenever the description or the `[AC]` set changed; when neither did, drop the readiness line from the confirmation. Confirm:

```output
Amended: <link>. Sections: 2 changed, 9 untouched. Criteria: 2 added, 1 reworded, 0 removed. Tagged: 3. Readiness: PASS.
```
