# Environment Adaptations (Claude Code CLI)

The docs workflow originated in a Cowork-style app context. This skill runs
in Claude Code (CLI). This file lists the specific adaptations that make the
workflow feel native to Claude Code — not a port.

## Interaction model

| Aspect | App context (Cowork) | Claude Code |
|---|---|---|
| Multiple-choice questions | Structured question UI | Plain-text question + numbered options inline |
| Long-running design sessions | Native (hours-long is fine) | Acceptable but devs typically prefer shorter sessions — offer to checkpoint and resume |
| File previews | Click-to-open file cards | None — just write the file; mention path in reply |
| Skill loading | One skill at a time via a skill tool | Skills load automatically via file path / matcher |
| Conversation persistence | Per-session in app | Per-shell session; resumable via `--continue` or by restarting in same repo |

## Tool model differences

App-context tools with no Claude Code equivalent — never call them here:

- Structured question widgets → use the plain-text format below
- File-preview cards → just write the file and mention the path
- Artifact/widget rendering → write HTML or Mermaid into a markdown file

Claude Code has:

- `Edit` / `MultiEdit` — use aggressively for doc edits
- `Bash` — full dev cycle: run migrations, tests, validators
- `Grep` — use heavily for code search
- `WebSearch` / `WebFetch`
- Subagents (`Task` / `Agent` tool) — Claude Code can spawn parallel
  subagents for big audits

## Plain-text question format

Replace every structured-question call with this template:

```output
**<Question text>?**

Options:
1. **<Option A>** (Recommended) — <one-sentence reasoning>
2. <Option B> — <when to pick> · don't pick if <caveat>
3. <Option C> — <when to pick> · don't pick if <caveat>
4. Other — describe what you have in mind

Reply with the number, or describe your own.
```

If the question has only 2 options (yes/no or A/B):

```output
**<Question>?**

- Yes/A — <implication>
- No/B — <implication>

Recommendation: <X> because <reason>.
```

For open-ended answers (no fixed options):

```output
**<Question>?**

I need: <specific format / examples>.

For instance: "<example answer>"
```

## Greeting

For an existing docs tree:

> Detected `docs/project/` for **<project-name>** · Archetype <X> · <N>
> modules · drift: <none / P0:n / P1:n / P2:n>.
>
> I'm running in Claude Code with full code edit + Bash — a few related
> questions at a time, recommendations with reasoning, push-back on vague
> answers, change-tracking on every edit. I own the whole loop here.
>
> What are we doing today?

For a greenfield repo (no docs):

> No `docs/project/` here yet. Let me run the full 12-phase design with you
> in the CLI. Then I'll scaffold the code and we'll implement together.
>
> Ready? First question: **what are we building?** One line is enough.

## Mermaid rendering

There is no widget renderer in Claude Code. Write Mermaid blocks into
markdown — most editors (VS Code, GitHub, Cursor) render them inline.
Always specify:

```markdown
\```mermaid
sequenceDiagram
  participant U as User
  ...
\```
```

Do NOT use ASCII art for diagrams (it ages badly). Always Mermaid.

## File creation vs file presentation

In Claude Code:

1. Write the file
2. Mention the path in the reply:
   *"Written: `docs/project/modules/orgs/module.md`"*
3. User opens it in their editor

Don't try to call a file-preview tool — none exists in Claude Code.

## Subagent use

In Claude Code, subagents are cheap and parallelizable — use them
aggressively for big audits:

- Auditing all 12 modules of a mature project → spawn 12 parallel
  subagents, one per module
- Reading 100+ files for a drift report → spawn 4-8 read-focused subagents
- Verifying spec-vs-impl parity across many features → parallel subagents

When using subagents, brief them in self-contained prompts (they don't
share your context). Be explicit about which doc to read + what to look
for + what report format to return.

## Filesystem & shell

Claude Code can run any shell command. Use this:

- `pnpm db:generate && pnpm db:migrate` after schema doc changes
- `pnpm dlx tsx scripts/validate-docs.ts` for verification
- `pnpm test --filter <pkg>` to verify tests still pass after edits
- `git status` / `git diff` to confirm what changed
- `git log --oneline -20` to understand recent history

Always show the command + the relevant output snippet in your reply.

## Session resumption

After a `--continue` or new session in the same repo:

1. Run pre-flight (`16-pre-flight.md`).
2. Read `docs/project/changes-log.md` head-50 lines to recover recent
   context.
3. Read `docs/project/_temp/pending-doc-updates.md` if it exists.
4. Read `docs/project/_temp/known-gaps.md` if it exists.
5. Pick up where you left off.

## Multi-repo / monorepo nuance

Claude Code may be opened anywhere inside a monorepo:

- `docs/project/` lives at monorepo root, not per app
- `CLAUDE.md` lives at monorepo root
- Per-app docs are inside `docs/project/modules/<m>/` not in
  `apps/<x>/docs/`

If the user opens Claude Code inside `apps/<x>/`, the skill still walks up
to find `docs/project/`.

## Environment variables / secrets

In Claude Code you might encounter:

- `.env.development` (encrypted via envx-cli — needs `make env-dev`)
- `.env.production.gpg` (don't decrypt unless asked)
- AWS credentials via profile (use the project's documented profile, e.g.
  `<your-aws-profile>`)

Don't proactively decrypt secrets. Don't print decrypted secrets to chat.
If the user shares one accidentally, never store it.

## "Done" semantics

"Docs are complete" is never the end state in Claude Code — "done" is
tiered:

- "Feature X done" → Validation gate (`19-validation-gate.md`)
- "PR ready" → All current edits change-tracked + validation passed
- "Sprint done" → All implemented features validated + drift = 0
- "Project done" → Never really (always evolving)

## Where an app-context session still helps

The CLI owns the full loop, but a conversational app session retains value
for:

- **Initial product design** where the user wants a more visual experience
  (multiple-choice UIs, file previews, side panels)
- **Non-developer stakeholders** who need to participate in design but
  don't want a terminal
- **Initial scoping** where the user prefers a slower, guided pace

After initial setup, **Claude Code owns everything**. No handoff back.
