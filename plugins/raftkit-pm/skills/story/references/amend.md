# Amend

Read at once: the story, all its subtasks, the Feature Template, and the followers, re-read for every amend.

## The draft is a diff

1. Untouched sections, by number and title.
2. Changed sections: current text, then replacement.
3. New `[AC]`s in full, one verifiable behaviour each.
4. Reworded `[AC]`s, only where the PM named them: current, then replacement.
5. The follower comment in full, closing with one `CC:` line mentioning every follower via `<a data-asana-gid="GID"/>`: none filtered, none added. No followers → ask who should follow. A mention that cannot be formed posts nothing until it can.

Above the diff: readiness gaps as numbered questions (the go is refused while one is blank), and when `Development` or `Testing` is ticked, this line:

```output
This story is already being built; amending changes the agreed scope under the developer.
```

## Additive rules

Never delete or renumber a section, drop an `[AC]` or tick a subtask. `Development`, `Testing`, `Bugs` are never edited. Silence about an `[AC]` keeps it byte-identical. Removing agreed scope is a board proposal.

## Stop once

One stop covers the diff, the new `[AC]`s, the follower comment and any mid-build line.

## The push

In order: the merged description (re-read the task first), the `[AC]` creates and rewordings, the comment. On failure, stop, read back, report what landed, and retry only the description; match an `[AC]` by text before re-creating it. Confirm:

```output
Amended: <link>. Sections: 2 changed, 9 untouched. Criteria: 2 added, 1 reworded, 0 removed. Tagged: 3. Readiness: PASS.
```
