---
name: simplify
description: This skill should be used when a RaftLabs developer wants a post-implementation minimalism pass on a completed story — e.g. "simplify this", "run the simplify pass", "strip the over-engineering", "remove speculative abstractions", "clean up before the PR", or when /implement finishes its phases and hands off for a minimalism pass. It is a behaviour-preserving cleanup that removes speculative abstractions, dead flexibility, unused config, and narration comments from the files the story changed — dispatching the code-simplifier:code-simplifier agent, whose findings are triaged through RaftKit's own minimalism catalog (`references/candidate-catalog.md`). Revert-safety is the core guarantee — it refuses to start on a red suite, and auto-reverts any change that turns a test red, naming the failing test. Runs only on the story branch's in-scope diff. Not a linter (style is the linter's job), not a refactor tool, and never a performance pass.
user-invocable: true
---

# simplify

The best code is the code never written. AI implementations look clean but
over-build: interfaces with one implementation, config nobody sets, comments that
narrate the obvious. This pass strips what the story didn't need, so the codebase
stays **exactly as complex as the product requires — no more** (PRD §5.3).

It orchestrates one scoped engine and rebuilds none of it: the
**`code-simplifier:code-simplifier` agent** — dispatched by that scoped type,
never the bare name, which is ambiguous while pr-review-toolkit is enabled —
*finds* the simplifications, which RaftKit's own `references/candidate-catalog.md`
triages into apply / list-only buckets (RaftKit's own minimalism lens — there is
no external minimalism engine). This skill *applies* candidates only after the
developer approves — it is the disciplined driver that adds revert-safety, the
diff-only boundary, the approval gate, and the reporting contract around them.

## The one rule that governs everything

**Behaviour wins over beauty.** The test suite must be green **before** the pass
and green **after** it — a red suite anywhere stops or reverts the work:

- **Red before** → the pass **refuses to start**. Fix the failing test first.
- **Red after any candidate** → that change is **auto-reverted** and reported,
  **naming the failing test**. The pass never ships a change that turned the suite
  red.

This is the guarantee the whole skill exists to provide. The full ordering,
commit mechanics, and exact output strings are in `references/revert-safety.md`.

It rests on two standing house rules this skill inherits, both non-negotiable:

1. **Diff-only.** Only files in the **story branch's diff** are ever touched.
   Files outside the diff are off-limits — reading them for context is fine,
   editing them is not.
2. **Draft → approve → apply.** Removals are shown to the developer as
   before/after and applied only on approval — per `raftkit-core/write-protocol`.
   The skill proposes; the developer approves; only then is anything changed.

And never guess: an uncertain candidate is **listed, not applied** — conservative
by default.

## Preconditions — check before proposing anything

1. **A story branch with a diff.** The pass operates on the files the story
   changed. Determine the in-scope set from the branch's diff against its base. No
   diff / not on a story branch → **stop and say so**; there is nothing to
   simplify.
2. **A runnable test suite, green.** Run it first (pre-flight). If it is **red**,
   **refuse to start** — name the failing test and stop; the fix comes first
   (`references/revert-safety.md`). If there is no suite to run at all, stop and
   ask — revert-safety cannot be guaranteed without one.
3. **One pass per story branch** by default. If a simplify commit already exists on
   this branch, say so and stop rather than stacking a second pass.

## Run flow

1. **Pre-flight the suite.** Run the full suite once. **Green** → continue.
   **Red** → refuse: report the failing test and stop; nothing is touched
   (`references/revert-safety.md`).
2. **Scope to the diff.** Compute the in-scope file set from the story branch's
   diff. Every candidate and every edit stays inside this set; out-of-diff files
   are never modified.
3. **Find candidates.** Dispatch the `code-simplifier:code-simplifier` agent
   across the in-scope files — see `references/candidate-catalog.md` for how
   its findings are triaged, through RaftKit's own minimalism lens, into
   candidates: single-caller abstractions, dead flexibility / unused config,
   and narration comments (removed) vs WHY-comments (preserved). The pass
   introduces no new abstractions of its own.
4. **Triage — conservative by default.** Sort candidates into **apply** (clear
   removals) and **list-only** (uncertain — reported for the developer to judge,
   never auto-applied). When in doubt, list it.
5. **Show before/after and get approval.** Present the apply batch as before/after
   pairs; the developer approves the batch (`raftkit-core/write-protocol`).
   Nothing changes before approval.
6. **Apply, then verify — revert on red.** Apply the approved removals, then
   **re-run the full suite**. If any test goes red, **auto-revert** the offending
   change and report it **naming the failing test**; behaviour wins. Re-run until the applied set is green. Details and batching in
   `references/revert-safety.md`.
7. **Commit or report empty.**
   - Removals were made → make **one dedicated simplify commit** and report:
     `Simplify: N removals, suite green (X tests), one commit`.
   - Nothing to simplify → say **exactly that** and make **no commit** — no empty
     commit. Exact strings in `references/revert-safety.md`.
8. **Hand back** the list-only candidates (if any) so the developer can decide on
   them separately — they are surfaced, never silently dropped.

## Guardrails

- **Green before and after** — refuse on a red pre-flight suite; auto-revert any
  candidate that turns a test red, naming it. The core guarantee
  (`references/revert-safety.md`).
- **Diff-only** — only files in the story branch's diff are touched; out-of-diff
  refactors are out of scope, full stop.
- **Minimalism via RaftKit's own catalog** (`references/candidate-catalog.md`) —
  there is no external minimalism engine; the pass introduces no new
  abstractions of its own.
- **Conservative default** — uncertain candidates are listed, not applied. Beauty
  is never worth a guessed behaviour change.
- **One dedicated commit per pass**, and no empty commit when there is nothing to
  simplify.
- **Orchestrate, don't rebuild** — code-simplifier finds the simplifications; this
  skill applies them only after developer approval, and governs safety, scope, and
  reporting. It reimplements no simplification logic.
- **Escalate to founders** per `raftkit-core/house-rules` if a proposed removal
  touches budget, contract, or client-commitment surface area rather than pure
  internal cleanup.

## Out of scope

- **Refactors beyond the story's diff** — the pass never reaches into files the
  story did not change.
- **Style-guide / formatting enforcement** — linters and formatters own that; this
  pass is about removing what isn't needed, not restyling what is.
- **Performance optimization** — behaviour-preserving minimalism only; speed work
  is a separate, measured effort.

## Reference files

- `references/candidate-catalog.md` — what counts as a simplification candidate
  (single-caller abstractions, dead flexibility / unused config, the narration-vs-
  WHY-comment taxonomy), the one scoped engine seam, and the conservative-default rule.
- `references/revert-safety.md` — the pre-flight refuse-on-red, batch-then-verify,
  auto-revert-on-red naming the failing test, the one dedicated simplify commit,
  and the exact success and empty-state output strings.
