---
name: docs
description: This skill should be used when a RaftLabs developer wants to design a project's documentation from scratch, document an existing codebase, or keep project documentation initialized, audited, synchronized, and verified — e.g. "help me design this project", "document this codebase for me", "set up the project docs", "do the docs still match the code?", "sync the docs for this story", "are the docs done for this change?", "scaffold the project" — or when a delivery workflow needs docs parity before a PR. It runs the full co-authoring design flow (one adaptive question at a time, recommendation-first), generates docs and diagrams from adaptable templates after human sign-off, discovers and preserves the repository's OWN documentation system, consumes approved handoffs instead of re-asking, runs a confirmed seven-step change lifecycle with no silent rewrites, verifies parity with evidence, and reverse-engineers existing code marking every fact confirmed, inferred, or unknown. It never restructures without an approved proposal, never chooses a Git range silently, and never writes to Asana directly.
user-invocable: true
---

# docs

Design, generate, and keep a repository's living documentation in lockstep
with the approved story, the spec, and the code — in that repository's **own**
documentation system, never a forced one. Two real architectures (a
module-indexed tree; a flat tree with an ownership-index table) proved the
same lifecycle runs over very different structures: the lifecycle is the
contract, the architecture is discovered input.

## The one rule that governs everything

**Discover, confirm, then write — never the reverse.** Every documentation
mutation is preceded by a confirmed impact list; every structural opinion is a
proposal; existing conventions are preserved by default; no doc file is ever
generated before the human signs off on the full plan. This skill never
writes to Asana itself — story and bug drafting route through the core
write-protocol gate; hand-offs to humans happen in chat.

## Ownership — one product, two surfaces

PM (Cowork) can originate Project Profiles, decisions, stories, and approved
planning. This skill consumes those outputs when they exist, and it runs the
full design/generation workflow when invoked directly by a developer.
Confirmed facts are consumed, never re-asked; neither surface loses a
capability because the other also provides it. Asana remains the workflow
spine; project facts live in Project Profiles, never in this plugin.

## Modes

Mode may be inferred from the developer's intent, but the selection is always
stated as `docs mode: <design|init|audit|sync|verify|scaffold> · branch:
<branch>` before work begins. Preflight is always-on internal behavior, never
a seventh command.

- **design** — the full co-authoring flow (`references/orchestration.md`):
  classify the project, discover business context, select the stack, design
  auth/tenancy/RBAC, inventory modules, run the 20+1-step per-module deep
  dive, capture cross-cuts, confirm — then generate. One adaptive question at
  a time; recommendation-first; nothing written before sign-off.
- **init** — materialize a documentation foundation from **approved planning
  outputs** (story, Project Profile, spec, or a completed design session).
  With no approved planning, offer design mode; if the developer declines,
  refuse with `No approved planning output covers this — route it through the
  story/PM flow before docs init.` Never invent product decisions.
- **audit** — compare docs (or their absence) with the code. Read-only until a
  change plan is approved. On existing code without docs, reverse-engineer per
  `references/reverse-engineer.md`.
- **sync** — run the seven-step change lifecycle for the current approved
  change set (`references/change-tracking.md`).
- **verify** — prove parity across approved story/spec, code, tests, living
  docs, diagrams, and relevant operational contracts
  (`references/verification.md`), including the category-graded gate on
  done-claims (`references/verification-checklist.md`).
- **scaffold** — optional project bootstrap after design
  (`references/scaffolding.md`): archetype-matched CLI, always asks before
  touching anything outside docs, installs route through capability-preflight
  and setup-project — never improvised here.

## Preflight — three branches

Always runs first (`references/lifecycle-and-handoff.md` +
`references/discovery-and-routing.md`):

1. **greenfield** — no code/docs yet. With approved planning → init; without →
   offer the full design flow.
2. **existing code, no living docs** — real code, no documentation system →
   audit/reverse-engineer path (recommended), fresh design, or hybrid.
3. **living docs** — a documentation system exists → discovered conventions
   are the yardstick for everything that follows; missing capabilities are
   added only through an approved proposal (hybrid).

All three converge on the same sync/verify contract and the four companion
gates (`assets/companion/`).

## The handoff (read, never re-asked)

The approved Asana story (live), the Project Profile (home is a parameter —
never hardcoded), the `spec_path` implementation spec (the spec gate — this
skill never authors a competing one), discovered docs roots and conventions,
the ownership/change map, open unknowns, and the repository's own verification
commands. Questions go to the developer **only** for what repository evidence
cannot establish. Spec-first: work is classified **complete / partial /
missing** against the spec and story; partial or missing routes to the owning
approval path — or, when the developer chooses, into design mode — before any
docs mutation.

## Templates and diagrams

`assets/templates/` ships 29 adaptable doc templates (progressive disclosure:
recommended for greenfield generation, mapped onto existing conventions
otherwise — never forced). The two Asana-facing capabilities (user-story,
bug-report) are live-template adapters owned by the Asana lifecycle story —
never cached files. Diagrams follow `references/diagram-catalog.md`: generate
when applicable, record `N/A — <reason>` when not, regenerate on change.

## Discovery

`scripts/audit-docs.mjs` produces the **in-memory** discovery result — roots,
convention, indexes, ownership mapping, history convention, ADR seam,
confidence, unresolved conflicts. It is not persisted automatically. If
persisting would help, propose a **project-owned** descriptor with its exact
path and content; the human approves both before creation, and existing
conventions stay authoritative over the descriptor. Conflicting signals or a
descriptor-vs-discovery clash: report both, mutate nothing, ask the human which
convention is authoritative.

## Exact strings (owned here)

- `Docs: not impacted — <reason>` — always with the inspected change set,
  documentation roots, and ownership evidence named.
- `Docs: updated and verified — <n> file(s), history recorded`
- `No approved planning output covers this — route it through the story/PM flow before docs init.`

## Safety boundaries

Everything stays inside the resolved repository root — no out-of-root symlink
is ever followed; VCS metadata, dependency/vendor dirs, build output, caches,
auth state, and secret/env files are excluded from scans; secret values are
never printed (envx presence is metadata only — nothing decrypted, nothing
read); scripts write only to an explicit output path inside the root; temporary
files are cleaned after verification. Change sets are explicit — a selected
base/ref/diff or the user-confirmed working diff — never a silently chosen Git
range. Capability needs route through the sibling `capability-preflight`
contract; this skill never improvises an install.

## Out of scope

- Asana writes of any kind from this skill directly; ticking ACs or Testing.
  (Story/bug drafting is the Asana-lifecycle story's live-template adapter
  seam, always behind draft → approve → push.)
- Package-manager and hook-manager work, and executing installs
  (setup-project and capability-preflight own those).
- Editing read-only source projects; merging PRs; deploying.

## Reference files

- `references/orchestration.md` — the 12-phase design flow, entry branches,
  mutual-agreement and confirmation gates, refinement loop.
- `references/discovery-questions.md` — adaptive question scripts; one
  question at a time; recommend-first with caveats.
- `references/stack-and-domain-recipes.md` — archetype decision tree,
  bootstrap recipes, domain recipes, anti-recipes.
- `references/module-decomposition.md` — module inventory + the 20+1-step
  per-module loop with the always-on compliance/PII/tests cross-cut.
- `references/edge-cases.md` — the 24-category edge-case walk.
- `references/proactive-prompts.md` · `references/push-back.md` — volunteered
  suggestions and vague-answer push-back catalogs.
- `references/rbac-guide.md` — the three nested matrices; the auth phase
  cannot exit without a drafted matrix.
- `references/generation.md` — adaptive generation: greenfield default tree,
  convention preservation, hybrid via approved proposal.
- `references/diagram-catalog.md` — diagram types, N/A reasoning, regen rule.
- `references/verification-checklist.md` — graded P0/P1/P2 gap report and the
  category-graded done-claim gate.
- `references/scaffolding.md` — bootstrap CLIs, ask-before-touch,
  never-auto-run list.
- `references/environment-adaptations.md` — CLI adaptation contract.
- `references/lifecycle-and-handoff.md` — modes, branches, handoff inputs,
  spec-first classification, mode announcement.
- `references/discovery-and-routing.md` — convention discovery, descriptor
  proposal, conflict handling.
- `references/change-tracking.md` — the seven-step lifecycle: identify →
  classify → confirm → update → record → ADR only when architectural →
  re-verify; with the restored guarantees (expansion mapping, per-doc
  history, changelog and changes-log pointers, diagram regeneration,
  completion parity).
- `references/verification.md` — parity checklist, evidence-backed no-impact,
  the change-set input contract, exact output strings.
- `references/reverse-engineer.md` — the full code-first restoration flow.
- `references/story-adapter.md` · `references/bug-adapter.md` — the
  live-template Asana story and bug adapters (render through core
  asana-formatting behind draft → approve → push; never cached template text).
- `assets/companion/` — the project-local companion capability (four runtime
  gates) built here, installed by setup-project.
- `scripts/audit-docs.mjs` · `scripts/validate-docs.mjs` — deterministic pure
  readers (documented flags and exit codes in their headers; `--graded` emits
  the P0/P1/P2 report).
