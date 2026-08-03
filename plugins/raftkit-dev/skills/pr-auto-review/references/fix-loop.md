# The fix-application loop

Modeled on `simplify/references/revert-safety.md`'s apply → reverify →
auto-revert-on-red shape, adapted for a headless, per-PR, Critical-only
context. This is the core novel mechanic pr-auto-review adds.

## Step by step

1. **Invoke `pr-review-toolkit:review-pr`** against the PR diff (anchored
   per `workflow-mechanics.md`). This is the **only** classifier of
   Critical/Important/Suggestion — the fix loop never re-buckets or
   second-guesses its severity calls, mirroring how `pr` and `scope-guard`
   treat pr-review-toolkit as an owned, un-reimplemented engine.

2. **Resolve a verify tier** before touching any file. On Tier 2, "available"
   means checked directly against this repo's manifest (e.g. a `build`,
   `typecheck`, or `lint` entry in `package.json`'s `scripts`) — the same
   signal `setup-project`'s toolchain detection (`scripts/detect-toolchain.mjs`)
   looks for, checked here directly rather than by invoking that script,
   since the headless fix-loop prompt is self-contained and has no access to
   it at CI runtime:
   - **Tier 1 (test script exists)** → run it as the reverify gate after
     each fix. Full auto-revert-on-red.
   - **Tier 2 (no test script, but build/typecheck/lint exists)** → run the
     strongest available in that preference order (build > typecheck >
     lint) as the reverify gate, and disclose it explicitly in the PR
     comment: `Verified via: <command> (no test script found in this
     repo)`. Weaker than a real test run — always labeled as such.
   - **Tier 3 (nothing runnable at all)** → Critical fixes still apply and
     commit — refusing entirely would make this skill useless in exactly
     the repos with the weakest existing safety nets — but there is no
     verify signal, so nothing can be auto-reverted. The comment carries a
     **mandatory, permanent disclosure line**: `Could not verify — no test,
     build, typecheck, or lint script found in this repo. Auto-fixed
     commits below are unverified; review carefully before merge.`

3. **Process Critical findings one at a time, sequentially — never
   batched**, so a red result is attributable to exactly one fix. Each
   fix is verified against the tree as it stands after every prior fix in
   this run, so a fix that depends on an earlier one in the same run
   resolves naturally — there is no separate cross-finding dependency
   mechanism to reason about.

   **Verify happens on the uncommitted change, before any commit exists for
   this finding** — this is what makes the revert in (e) a plain discard,
   never a history rewrite of something already pushed:
   - a. Take the next unaddressed Critical finding (file:line + description
     from `pr-review-toolkit`'s output).
   - b. Apply the smallest fix that resolves it, uncommitted — no
     speculative or adjacent changes, same "smallest fix" discipline as
     `fix-bug`'s fix-to-green step.
   - c. Verify the uncommitted working tree per the resolved tier, before
     committing anything for this finding.
   - d. **Green (Tier 1/2) or unverifiable (Tier 3)** → commit the
     already-verified change:

     ```
     fix: <specific description of the one fix>

     Auto-fixed by pr-auto-review from a Critical finding in
     pr-review-toolkit's review.
     Finding: <file>:<line> — <short finding text>

     pr-auto-review-commit: true
     ```

     Push right away — pushing per-fix, not batching at the end, is what
     makes the self-trigger loop guard (`workflow-mechanics.md`)
     load-bearing.
   - e. **Red (only possible in Tier 1/2)** → nothing was committed for
     this finding, so there is nothing to revert via history and nothing
     to push. Discard the uncommitted working-tree change (`git checkout --
     .` / `git reset --hard HEAD`, resetting to the current `HEAD` — never
     `HEAD~1`, which would instead destroy the *previous* finding's already
     -verified, already-pushed commit) and report in the PR comment:

     ```
     Could not auto-fix safely: <finding file:line> — attempted fix broke
     <failing check name>. Reverted; left for manual review.
     ```
   - f. Move to the next Critical finding; repeat until the list is
     exhausted.

4. **Never batch Critical fixes into one commit** — explicitly the
   opposite of `simplify`'s "one dedicated commit for the whole pass." This
   contrast is deliberate: a future maintainer should not "align" the two
   skills' commit granularity.

## Hard boundaries (stated verbatim in the fix-loop prompt)

- Never touch files outside fixing the one named Critical finding.
- Never merge.
- Never force-push.
- Never modify `.github/workflows/**`, including its own workflow file — a
  supply-chain-adjacent guardrail so the bot can never edit its own trigger
  or permissions.
- Never re-bucket a finding's severity — `pr-review-toolkit`'s call is
  final.

## What "headless Claude Code reviews, decides Critical, fixes, commits, verifies" means mechanically

The single `anthropics/claude-code-action@v1` invocation in the workflow is
handed a `prompt` (the static asset `assets/fix-loop-prompt.md`) that states
this entire loop verbatim — the exact invocation, the per-finding loop
above (steps 3a–3f) including the tiered verify resolution and its exact
disclosure strings, the commit message shape (byte-exact, since the
loop-guard's defense-in-depth check may grep for the trailer), the comment
contract (see `comment-contract.md`), and the hard boundaries above. This
prompt is the actual "skill logic" running at CI time — the GitHub Actions
job and the official action are a thin, static harness; all the judgment
lives in the prompt asset.
