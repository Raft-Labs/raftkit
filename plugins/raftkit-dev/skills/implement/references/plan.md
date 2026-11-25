# The plan record

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

<300–500 words: the modules touched, their entry points, the patterns to copy, the commands that test and typecheck one package.>
```

- One row per `[AC]`, verbatim. Every file the build touches sits in a row; a path ending in `/` covers a directory.
- Put the `scope-check.mjs --hash` output in the comment line. Commit the record alone, before the first test.
- Never change a row after that commit: the first-committed table is the plan, and any change is flagged `ADDED AFTER PLAN`. Amend the story, or name the sign-off.
- Progress lives in git, not in the table.
- Readiness answers and clarifications go under `## Clarifications`.
- On `fix`, the first column is `Done when`, and the map is one paragraph.
