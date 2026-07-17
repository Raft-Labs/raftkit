# The three human gates

`implement` is a chain of hard stops. Each gate below either refuses, waits for an
explicit human decision, or blocks — **silence is never approval**. Templates,
`[AC]`s, and parameters are read live every run (workspace + template GIDs from
`raftkit-core/workflow-constants`); nothing here is cached.

## Gate 0 · Readiness (refuse or proceed)

The Definition-of-Ready gate, run on the dev side before a single edit.

1. **Fetch live.** Resolve the workspace GID from `workflow-constants` and fetch
   the story **and all its `[AC]` subtasks** through the Asana connector. If the
   story cannot be read, stop with the `workflow-constants` connector message —
   never audit a remembered story.
2. **Audit with `raftkit-pm/story-readiness`.** Reuse that skill's criteria — the
   same story must pass the same gate on both the PM and dev sides. Do **not**
   reinvent a readiness checklist here.
3. **Verdict.**
   - **PASS** → proceed to Gate 1.
   - **NOT READY → refuse. There is no override.** Post the gap list back on the
     story task (a comment, per `write-protocol`) so the PM can fix it, and stop.
   - **Empty story — no `[AC]` subtasks** → this is a NOT READY refusal whose gap
     list **names exactly that**: the story has no acceptance criteria. Refuse and
     post it; do not attempt to plan an AC-less story.

Gate 0 is read-only except for the single gap-list comment on a refusal. It never
edits or fixes the story — fixing gaps is the PM's job (`story-readiness` is
read-only by design; the comment is `implement`'s close of the loop).

## Gate 1 · Plan (plan-approval gate)

1. **Brainstorm + plan.** Run plan mode with `superpowers` brainstorming, the dev
   in the loop. Do not skip to a decomposition table before the approach is agreed.
2. **State the scope contract.** In scope = the story's `[AC]`s, verbatim;
   everything else = out, echoing the story's Out-of-scope / non-goals list. This
   contract is exactly what `scope-guard` audits at Gate 2 — write it precisely.
3. **Build the decomposition table.** One row per phase, atomic units that compile
   in isolation, with these columns:

   | phase | subagent | target files | target model | dependency |
   |---|---|---|---|---|

   Decompose whenever a phase would touch more than `decomposition_threshold`
   files (read the value live from `governance-protocols`). Model per phase from
   the table — **Sonnet is the default workhorse**; reserve a stronger model for
   phases that genuinely need it and say why in the row.
4. **Approval is a hard stop.** Present the scope contract + table and wait for the
   dev's explicit "go". Silence is not approval.
5. **On approval, persist the plan two ways** (both required — this is the AC):
   - Post the approved plan as a **comment on the story** (`write-protocol`: draft
     → approve → push; Asana HTML rules — single `<body>` root, no `<p>`, links
     only as `<a>`, escape `&`/`<`/`>`, no named entities).
   - **Write it to the spec file** at `spec_path` (read live; default
     `docs/specs/active-feature.md`). This spec is the gate the build phase checks
     for — see `references/execution.md`, "No spec, no code".

## Gate 2 · Scope + review (block or proceed)

Run after the post-edit gates are green (`references/execution.md`), before the PR.

1. **`scope-guard` clean.** Run `raftkit-dev/scope-guard` against this story and
   require its verbatim clean line — that string is scope-guard's, checked here,
   never re-derived:

   ```
   Scope-guard: clean — 0 beyond, 0 missing
   ```

   Any **BEYOND** or **MISSING** item blocks the PR. A BEYOND item clears only by
   removal or the dev's explicit logged sign-off; a MISSING item only by being
   built or explained. Silence is not a sign-off.
2. **CodeRabbit local pass.** Run the CodeRabbit CLI review locally and address or
   explicitly answer every finding before proceeding to the raise.

Only when both are satisfied does the run proceed to the `pr` skill
(`references/close-out.md`).
