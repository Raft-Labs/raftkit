---
name: docs
description: This skill should be used when a RaftLabs developer wants project documentation initialized, audited, synchronized, or verified — e.g. "set up the project docs", "do the docs still match the code?", "sync the docs for this story", "are the docs done for this change?", or when a delivery workflow needs docs parity before a PR. It discovers the repository's OWN documentation system (roots, indexes, ownership map, history convention, ADR seam) and preserves it, consumes the approved handoff (story, Project Profile, spec) instead of re-asking, runs a confirmed seven-step change lifecycle with no silent rewrites, verifies story/spec ↔ code ↔ docs parity with evidence, and reverse-engineers existing code marking every fact confirmed, inferred, or unknown. It never restructures without an approved proposal, never chooses a Git range silently, and never writes to Asana.
user-invocable: true
---

# docs

Keep a repository's living documentation in lockstep with the approved story,
the spec, and the code — in that repository's **own** documentation system,
never a foreign one. Two real RaftLabs-adjacent architectures (a module-indexed
tree; a flat tree with an ownership-index table) proved the same lifecycle runs
over very different structures: the lifecycle is the contract, the architecture
is discovered input.

## The one rule that governs everything

**Discover, confirm, then write — never the reverse.** Every documentation
mutation is preceded by a confirmed impact list; every structural opinion is a
proposal; existing conventions are preserved by default. And this skill
**never writes to Asana** — no AC updates, no comments; hand-offs to humans
happen in chat.

## Modes

Mode may be inferred from the developer's intent, but the selection is always
stated as `docs mode: <init|audit|sync|verify> · branch: <branch>` before work
begins. Preflight is always-on internal behavior, never a fifth command.

- **init** — materialize a minimal documentation foundation from **approved
  planning outputs only** (story, Project Profile, spec). Missing approval →
  refuse with `No approved planning output covers this — route it through the
  story/PM flow before docs init.` Never invent product decisions.
- **audit** — compare docs (or their absence) with the code. Read-only until a
  change plan is approved. On existing code without docs, reverse-engineer per
  `references/reverse-engineer.md`.
- **sync** — run the seven-step change lifecycle for the current approved
  change set (`references/change-tracking.md`).
- **verify** — prove parity across approved story/spec, code, tests, living
  docs, diagrams, and relevant operational contracts
  (`references/verification.md`).

## Preflight — three branches

Always runs first (`references/lifecycle-and-handoff.md` +
`references/discovery-and-routing.md`):

1. **greenfield handoff** — approved planning outputs, no code/docs yet → init path.
2. **existing code, no living docs** — real code, no documentation system → audit/reverse-engineer path.
3. **living docs** — a documentation system exists → discovered conventions are
   the yardstick for everything that follows.

All three converge on the same sync/verify contract.

## The handoff (read, never re-asked)

The approved Asana story (live), the Project Profile (home is a parameter —
never hardcoded), the `spec_path` implementation spec (the spec gate — this
skill never authors a competing one), discovered docs roots and conventions,
the ownership/change map, open unknowns, and the repository's own verification
commands. Questions go to the developer **only** for what repository evidence
cannot establish. Spec-first: work is classified **complete / partial /
missing** against the spec and story; partial or missing routes to the owning
approval path before any docs mutation.

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

- PM planning, onboarding, story creation (raftkit-pm owns those; the Cowork
  surface plans, this skill synchronizes).
- Wiring docs into implement/pr/bug/UI/simplify/scope-guard flows (Story C).
- Package-manager and hook-manager work (setup-project).
- Any fixed docs tree, template catalog, phase count, or diagram quota.
- Asana writes of any kind; ticking ACs or Testing.
- Installing providers.

## Reference files

- `references/lifecycle-and-handoff.md` — modes, branches, handoff inputs,
  spec-first classification, mode announcement.
- `references/discovery-and-routing.md` — convention discovery, the in-memory
  result, descriptor proposal and approval, conflict handling, script usage.
- `references/change-tracking.md` — the seven-step lifecycle: identify →
  classify → confirm → update → record → ADR only when architectural →
  re-verify; impact-list expansion re-approval; history conventions.
- `references/verification.md` — parity checklist, evidence-backed no-impact,
  the change-set input contract, exact output strings.
- `references/reverse-engineer.md` — confirmed / inferred / unknown marking,
  the read-only rule, interview scope.
- `scripts/audit-docs.mjs` · `scripts/validate-docs.mjs` — deterministic pure
  readers (documented flags and exit codes in their headers).
