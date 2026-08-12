# The three human gates

`implement` is a chain of hard stops. Each gate below either refuses, waits for an
explicit human decision, or blocks — **silence is never approval**. Templates,
`[AC]`s, and parameters are read live every run (workspace + template GIDs from
`raftkit-core/workflow-constants`); nothing here is cached.

## Gate 0 · Readiness (clarify, refuse, or proceed)

The Definition-of-Ready gate, run on the dev side before a single edit.

0. **Capability preflight first.** Before the story fetch, consult
   `raftkit-dev:capability-preflight` for the run's required capabilities. It
   owns the readiness contract; this gate only consumes its result. An
   **unresolved declared dependency** stops the run with the preflight's repair
   guidance — resolve it through a human-approved RaftKit install/update of
   raftkit-dev; never install anything from here.
1. **Fetch live.** Resolve the workspace GID from `workflow-constants` and fetch
   the story **and all its `[AC]` subtasks** through the Asana connector. If the
   story cannot be read, stop with the `workflow-constants` connector message —
   never audit a remembered story.
2. **Route on shape.** A title-only stub — an **empty description**, full stop — is
   **Path C**, not an audit target: see `references/clarification.md`. A story with
   real narrative content but zero `[AC]` subtasks is not a stub — it audits
   normally below, and a missing-ACs verdict is an ordinary NOT READY gap for Path
   B to clarify, never a reason to let the dev rewrite the story from scratch.
3. **Audit with `raftkit-pm/story-readiness`.** Reuse that skill's criteria — the
   same story must pass the same gate on both the PM and dev sides. Do **not**
   reinvent a readiness checklist here.
4. **Verdict.**
   - **PASS → READY.** Proceed to Gate 1.
   - **NOT READY → classify each gap** (`references/clarification.md`): a
     dev-answerable gap is asked back to the dev in one round and, once
     confirmed, logged to the story before proceeding. Every other gap —
     commercial/client-impacting, unanswered, or an answer that adds
     `[AC]`-uncovered scope — **refuses, with no override**, and the unresolved
     gaps are posted back on the story task (a comment, per `write-protocol`) so
     the PM can fix them.
   - **READY (clarified) — `<n>` gap(s) closed in session, `<m>` satisfied by the
     story** → every gap was either already satisfied or cleared through a logged
     clarification (naming its Decision Log permalink). On Path B this is Gate 0's
     **own reconciliation** against the confirmed log entries — it does not re-run
     `story-readiness`, which never reads comments and would see the same
     untouched description every time (`references/clarification.md`). Proceed to
     Gate 1.
   - **Empty story — empty description** → **Path C**, not a refusal by default;
     see `references/clarification.md`. (A described story with zero `[AC]`s is
     the NOT READY case above, not this one.)

Gate 0 is read-only except for the gap-list comment on a refusal, the Decision Log
comment on a clarified gap, and — Path C only — the initial story write. It never
edits or fixes a story that already has content — fixing gaps in an existing story
is the PM's job (`story-readiness` is read-only by design; `implement`'s writes
close its own loop).

## Gate 1 · Plan (plan-approval gate)

1. **Brainstorm + plan.** Run plan mode with `superpowers:brainstorming`, then
   shape the written plan with `superpowers:writing-plans`, the dev in the loop.
   Do not skip to a decomposition table before the approach is agreed.
2. **State the scope contract.** In scope = the story's `[AC]`s, verbatim, **plus
   any Gate 0 clarifications**, cited by their Decision Log permalink
   (`references/clarification.md`); everything else = out, echoing the story's
   Out-of-scope / non-goals list. This contract is exactly what `scope-guard`
   audits at Gate 2 — write it precisely.
3. **Build the decomposition table.** One row per phase, atomic units that compile
   in isolation, with these columns:

   | phase | subagent | target files | target model | dependency |
   |---|---|---|---|---|

   Decompose whenever a phase would touch more than `decomposition_threshold`
   files (read the value live from `governance-protocols`). Model per phase from
   the table — **Sonnet is the default workhorse**; reserve a stronger model for
   phases that genuinely need it and say why in the row. Drop a mechanical phase
   (a rename, a find-and-replace, generated fixtures) to Haiku. The column is the
   **recommended** tier per phase, not a switch this skill throws — the human does
   the switching (`raftkit-core/house-rules`). Say here which rows are cheaper than
   the dev's current session model, so the approved plan already shows where
   execution will stop to ask (`references/execution.md`). When a phase's tier is
   genuinely unclear, settle it here rather than picking upward.
4. **Design Approach.** State the story's structural decisions — 0 to 6 rows,
   each naming a Decision, the Alternative rejected, the Why, and the Phases it
   governs (the decomposition table's row numbers), plus a **Deliberately not
   doing** line. Zero is legitimate and must stay cheap when the story adds no
   new structure. Full field spec, the cap, and the rejectable conditions are
   in `references/design-approach.md` — do not reinvent them here.
5. **Docs Impact Plan.** The plan carries the story's documentation impact,
   built on `raftkit-dev:docs` discovery (ownership evidence, never guessed):
   - a **concrete affected-doc list**, or
   - an **evidence-backed expected no-impact**, or
   - an **unknown mapping** — flagged for human resolution. An unknown mapping
     may be approved only as a **planning blocker**: it is not approval to
     write documentation. It must be resolved into an approved concrete
     affected-doc list before any docs mutation.

   Gate 1 approval of a concrete list (or no-impact) satisfies the docs
   lifecycle's confirm step for exactly that list; if the impact expands during
   implementation, the additions regain approval before any extra doc is
   written.
6. **Approval is a hard stop.** Present the scope contract, the table, the
   Design Approach, and the Docs Impact Plan, and wait for the dev's explicit
   "go". Silence is not approval. A Design Approach that fails
   `references/design-approach.md`'s approvable test is sent back inside this
   gate — it does not reach this step until it clears.
7. **On approval, persist the plan two ways** (both required — this is the AC):
   - Post the approved plan as a **comment on the story** (`write-protocol`: draft
     → approve → push; Asana HTML rules — single `<body>` root, no `<p>`, links
     only as `<a>`, escape `&`/`<`/`>`, no named entities).
   - **Write it to the spec file** at `spec_path` (read live; default
     `docs/specs/active-feature.md`), including its own `## Design Approach`
     section (`references/design-approach.md`). This spec is the gate the
     build phase checks for — see `references/execution.md`, "No spec, no
     code".

## Gate 2 · Scope + review (block or proceed)

Run after the post-edit gates are green (`references/execution.md`), before the PR.

0. **Docs parity via `raftkit-dev:docs` verify — advisory, never a deadlock.**
   Invoke verify with the story's **explicit change set** — the branch diff
   against the fetched merge-base anchor (the same anchor scope-guard uses), or
   the dev-confirmed current diff — so the resolved commit evidence, the exact
   changed files, and the documentation roots and ownership evidence examined
   are all reported. The docs skill is never handed an arbitrary Git range to
   choose from — it never claims no impact without naming what it inspected.
   Gate 2 records one of three outcomes, never a crash:
   - `Docs: updated and verified — …` or an evidence-backed
     `Docs: not impacted — <reason>` — the two owner strings, reproduced
     verbatim.
   - **No recognized documentation convention** (`validate-docs.mjs` exits 2
     for this reason) — this is the tool's own documented, approved outcome
     for a repo with no docs system it can map, not a failure. Record it
     verbatim as the Gate 2 evidence and proceed; do not block the story on a
     repo having no docs.
   Code and approved docs land as one logical change set when docs verify does
   run against a real convention — docs are never deferred to a later cleanup
   pass in that case.
1. **`scope-guard` clean.** Run `raftkit-dev/scope-guard` against this story,
   passing it any Gate 1 clarifications by their Decision Log permalink so it can
   map the corresponding hunks (`references/clarification.md`) — and require its
   verbatim clean line — that string is scope-guard's, checked here, never
   re-derived:

   ```output
   Scope-guard: clean — 0 beyond, 0 missing
   ```

   Any **BEYOND** or **MISSING** item blocks the PR. A BEYOND item clears only by
   removal or the dev's explicit logged sign-off; a MISSING item only by being
   built or explained. Silence is not a sign-off.

Only when this is satisfied does the run proceed to the `pr` skill
(`references/close-out.md`). Automated code review (pr-review-toolkit) is not
duplicated here — it runs once, downstream, as part of `pr`'s own flow
(`pr/references/automated-review.md`). CodeRabbit is not part of the review
chain: RaftLabs decided to use pr-review-toolkit only (Asana
`1216551482947559`, closed 2026-07-14).

## Gate evidence is SHA-bound

Every gate's evidence line names the change-set SHA it inspected (e.g.
`scope-guard: clean — verified at a1b2c3d`). This is an agent responsibility,
not a separate stored artifact: before citing any earlier gate's result as
still valid, re-derive the current branch head (`git rev-parse HEAD`) and
compare it against the SHA the cited evidence names. A mismatch refuses with
`evidence stale — inspected <sha-a>, current <sha-b>`, and the gate must be
re-run at the current head — no gate reuses evidence recorded at a different
SHA than the branch's current one.
