# Git + PR + Asana close-out

One story = one branch = one squash-PR. This file is the mechanical end of the
run. Everything here is an **outward write** — it happens only after the in-chat
approval gate, and never at all in dry-run mode.

## Branch

Create the branch **before** building, off an up-to-date `main`:

```
feat/<milestone>-<skill-name>
```

e.g. `feat/m3-scope-guard`. Milestone prefix is the lowercased section tag
(`m1`…`m6`). Verify the working tree is clean first; if it is not, stop and ask.

If the branch already exists (a prior attempt, or it is checked out in another
worktree), do not clobber it: report it, and either continue on it if it is this
same story's work, or ask before choosing a suffixed name (`feat/m3-scope-guard-2`).
A silent fallback that buries the collision is worse than pausing to confirm.

## Commits

Small logical commits, conventional-commit titles (`feat:` / `fix:` / `docs:` /
`chore:`). The commit that adds the skill reads as a changelog line, e.g.
`feat: raftkit-dev scope-guard skill — hard scope-line enforcement`.

Every commit message ends with the trailer:

```
Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

## PR

- **Title** — the changelog line for this story (conventional-commit form).
- **Body** — links the Asana story, lists the `[AC]`s this PR satisfies, and
  ends with:

  ```
  🤖 Generated with [Claude Code](https://claude.com/claude-code)
  ```

Draft title + body in chat and show a diff summary. **Wait for explicit
approval.** Then push and open the PR (GitHub MCP `create_pull_request`, or
`gh pr create`). Report the PR URL.

## Asana close-out (write-protocol applies)

After the PR is open, per `write-protocol` (draft → approve → push):

1. Tick the story's **`Development`** subtask complete.
2. Add a comment on the story with the PR link and a one-line summary of what
   shipped.

Apply the Asana HTML rules on the comment: single `<body>` root, no `<p>`
(line breaks instead), attributes only on `<a href>`, escape `&`/`<`/`>`. When in
doubt, plain text with line breaks.

**Do not** tick `[AC]` subtasks, tick `Testing`, close the story, or merge the
PR — those are downstream human/QA gates (house-rules: PR merge and bug close are
human gates).

## Dry-run mode

When invoked dry-run (the default for benchmark/practice runs), do everything up
to but not including any push/PR/Asana write. Instead, emit:

- the exact `git` commands (branch, commits) — or run the local commits, but
  never `git push`;
- the drafted PR title + body;
- the drafted Asana `Development` tick + comment.

Nothing leaves the local machine and nothing is written to Asana or GitHub.
