# The plan record

`docs/specs/<branch>.md`, written after one exploration and before the first test. It is the resume point after `/clear` or compaction, and `scope-check.mjs` reads it.

```markdown
# <branch> — plan record

Story: <story URL>

## Acceptance criteria

<!-- plan-table sha256: <hash> -->
| # | [AC] | Test file | Source files |
|---|---|---|---|
| 1 | [AC] <verbatim> | `<test path>` | `<path>`, `<dir/>` |

Do NOT build: <the story's line, verbatim>

## Codebase map

<300–500 words: the modules the story touches, their entry points, the patterns to copy, the commands that test and typecheck one package.>
```

- One row per `[AC]`, its text verbatim. Every file the build will touch sits in a row; a path ending in `/` covers a directory of generated names.
- Hash the table with `scope-check.mjs --hash` and put the printed hash in the comment line. Commit the record alone, before the first test.
- Never change a row after that commit. A row added later is flagged `ADDED AFTER PLAN`: amend the story, or name the sign-off.
- Progress lives in git, not in the table: resume from the first `[AC]` with no implementation commit.
- Readiness answers and clarifications go under `## Clarifications`.
- On `fix`, the first column is `Done when`, one row per item verbatim, and the map is one paragraph.
