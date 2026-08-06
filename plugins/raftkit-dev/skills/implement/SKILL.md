---
name: implement
description: This skill should be used when a RaftLabs developer wants to take one Asana story from URL to a review-ready PR the house way — e.g. "run /implement <story-url>", "implement this story", "build this task end to end", or when a dev hands over a ready raftkit story to code. It fetches the story and its live [AC] subtasks, refuses any story that fails the Gate 0 readiness audit (no override), runs plan mode with superpowers:brainstorming, writes the approved plan as the spec file (no spec, no code), then drives test-first phases through scoped subagents and the post-edit review layers (simplify, design review against the Module Design Standard, security, lint + suite), clears Gate 2 (scope-guard), and delegates the raise + Asana close-out to the pr skill. It orchestrates existing engines and rebuilds none of them; it never merges and never ticks [AC]/Testing or closes the story.
user-invocable: true
---

# implement

Turn one approved Asana story into one review-ready PR, the RaftLabs way:
**Spec-Driven + Test-Driven, human-in-the-loop at every gate.** The story is the
spec; its `[AC]` subtasks are the definition of done; nothing outside them enters
the diff. This is the core of RaftKit (PRD §5.3): AI-assisted dev drifts without
hard gates — scope creep, missing edge cases, compounding errors — so this
orchestrator chains the guardrails into one disciplined flow.

`implement` is the conductor; the siblings are the orchestra. It **rebuilds
nothing** — Gate 0 is `raftkit-pm/story-readiness`, planning is
`superpowers:brainstorming` + `superpowers:writing-plans`, the post-edit layers
are `simplify` + the design review (`pr-review-toolkit:code-reviewer` +
`type-design-analyzer`, scored against `raftkit-core/design-standard`) + the
security-guidance hook evidence + the suite, Gate 2 is
`raftkit-dev:docs` verify + `scope-guard`, and the raise +
close-out are the `pr` skill. It owns
only the **gate sequencing**, the **spec-file lifecycle**, the **pre-edit
baseline hard stop**, the **decomposition + scoped-subagent discipline**, the
**progress streaming**, and its own **success line** and **write-failure
fallback**.

Run one story at a time. Work the gates in order; each is a hard stop that waits
for an explicit human "go" — **silence is not approval**.

## The one rule that governs everything

**No spec, no code.** Coding cannot begin until the plan approved at Gate 1 is
written to the spec file, and the story stays the single source of truth behind
it. If the spec file is absent at any point after Gate 1, stop with the
governance pack's `❌ ORCHESTRATION REJECTED` string (see `references/execution.md`)
— never edit code against a missing spec.

## What this skill assumes

- The governance pack is installed (`raftkit-dev/setup-project`) — this skill
  reads its protocols, parameters, and verbatim strings; it does not install them.
- `raftkit-core` is installed — `workflow-constants` (GIDs, live-template fetch),
  `house-rules` (gates, escalation), `write-protocol` (draft→approve, Asana HTML).
- The sibling skills exist: `story-readiness` (pm), `scope-guard`, `simplify`,
  `pr`, `docs`, and — when a phase needs them — `recipes` and `ui-creation`.
- Provider readiness is `raftkit-dev:capability-preflight`'s call, run before
  Gate 0: it reports the required capabilities with evidence. An unresolved
  declared dependency stops the run with the preflight's repair guidance (a
  human-approved RaftKit install/update) — this skill never improvises an
  install and never degrades silently.

If a constant or core piece is missing, stop and say which — use the exact
`workflow-constants` stop messages; never guess a GID.

## Parameters (read live, never hardcoded)

Read both from `raftkit-core/governance-protocols`' parameter table every run —
they are parameters pending Asana decision `1216550892331152`, not facts to bake in:

- `spec_path` — where the spec file is written (default `docs/specs/active-feature.md`).
- `decomposition_threshold` — the file count above which work must be decomposed
  into phases (default `2`).

## Run flow

Work the three gates in order; the mechanics live in the references.

### Gate 0 · Readiness  → CLARIFY-REFUSE-OR-PROCEED
Fetch the story and **all** its `[AC]` subtasks live (workspace GID from
`workflow-constants`). Run `raftkit-pm/story-readiness` and reuse its criteria —
do not reinvent them. A dev-answerable gap is asked back to the dev and, once
confirmed, logged to the story before any code — a NOT READY with no dev-answerable
gaps, or a gap the dev cannot or will not answer, **still refuses with no override**,
and the gap list is posted back on the story for the PM. A title-only stub with no
`[AC]`s is a dev-shaped path, not an automatic refusal. See `references/gates.md` and
`references/clarification.md`.

### Gate 1 · Plan  → PLAN-APPROVAL GATE
Run plan mode with `superpowers:brainstorming`, dev in the loop. The plan states
the **scope contract** (in scope = the ACs; everything else = out), the
**decomposition table** (phase · subagent · target files · target model ·
dependency) of atomic units that compile in isolation, the **Design Approach**
(0–6 structural decisions, each with its rejected alternative, why, and
governing phases — zero is a legitimate, cheap answer), and the **Docs Impact
Plan** (a concrete affected-doc list, an evidence-backed no-impact, or an
unknown mapping — a planning blocker, not docs-write approval). On dev
approval, post the plan as a comment on the story **and** write it to
`spec_path`. See `references/gates.md`.

### Build · baseline → phases → post-edit gates
Confirm a **green pre-edit baseline** (failing build/typecheck is a hard stop —
fix the baseline first, touch no code), branch per conventions, then execute each
phase with a **scoped subagent** (narrow context, model per the table, test-first
red→green). Then the post-edit layers: the `simplify` pass, the **design
review** (MDS + Design Approach conformance, on the post-simplify diff), the
security-guidance hook evidence (hook-only — nothing to invoke), and lint +
full suite. See `references/execution.md`.

### Gate 2 · Scope + review  → BLOCK-OR-PROCEED
Run `raftkit-dev:docs` verify against the story's explicit change set (docs
parity is required), then `scope-guard` with its verbatim clean line (or a
logged sign-off). See `references/gates.md`.

### Close out · raise + link
Hand the raise to the `pr` skill (it owns the squash target, commitlint title,
the five description sections including the Docs result, and the Asana close-out). Report the success line;
on an Asana write failure, give the dev the exact manual-link text. See
`references/close-out.md`.

## Guardrails

- **No spec, no code** — the spec derives from the approved story + plan; a
  missing spec after Gate 1 stops the run with `❌ ORCHESTRATION REJECTED`.
- **Gate 0 has no override** — a gap that is not dev-answerable (commercial impact,
  or the dev cannot or will not answer it) is refused, full stop. A dev-answerable
  gap may be cleared, but only once its answer is logged to the story — an unlogged
  answer never clears anything (`references/clarification.md`).
- **Silence is not approval** — Gate 1 and Gate 2 each wait for an explicit human
  decision; Gate 0 proceeds only on a readiness pass.
- **Scope is a hard line** — the Gate 1 scope contract is exactly what Gate 2's
  `scope-guard` audits; improvements go to the board as proposals, never the diff.
- **Story read live, not cached** — the story and its `[AC]`s come from Asana
  every run; templates and parameters are read live, never from this repo.
- **Reference the verbatim strings** — `❌ ORCHESTRATION REJECTED` and
  `⚠️ SUBAGENT LOOP WARNING` are the governance pack's; the clean line is
  `scope-guard`'s; reproduce them from their owners, never re-author them.
- **Never merge, never over-tick** — `implement` raises and hands to a human; it
  does not merge, does not tick `[AC]`/`Testing`, and does not close the story.
- **Escalate to founders** per `house-rules` on budget, contracts, or client risk.
- **Plain English out** — every line a human reads follows `raftkit-core/house-rules`' plain-language rules; a house term gets its one-line gloss on first use.

## Out of scope

- **Installing the governance pack** — `raftkit-dev/setup-project` owns it.
- **PR review-layer configuration** — the `pr` story owns the config; `implement`
  only runs the layers.
- **Bug fixing and production incidents** — `fix-bug` and `fix-production-error`.
- **Auto-merge** — merging, promoting, and tagging stay human.

## Reference files

- `references/gates.md` — the three human gates: Gate 0 readiness seam + refusal
  and gap-post, Gate 1 plan → approval → spec-write + story comment, Gate 2
  scope-guard clean line.
- `references/design-approach.md` — the Design Approach artifact: five fields,
  the 0–6 cap, the approvable zero-answer, rejectable conditions, and the
  mid-build amendment path.
- `references/clarification.md` — Gate 0's three entry paths, gap classification
  (dev-answerable vs. escalate vs. refuse vs. scope-change), the one-round
  interview, the Decision Log write and its hard stop, and how clarifications
  propagate to Gate 1, `scope-guard`, and `pr`.
- `references/execution.md` — spec lifecycle and `❌ ORCHESTRATION REJECTED`, the
  pre-edit baseline hard stop, the decomposition table, scoped-subagent discipline
  (narrow context, model-per-phase, the 3-attempt `⚠️ SUBAGENT LOOP WARNING`),
  per-phase TDD, small commits, progress streaming, and the post-edit gates.
- `references/close-out.md` — delegating the raise + Asana close-out to `pr`, the
  success line, and the Asana-write-failure manual-link fallback.
