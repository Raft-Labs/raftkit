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

   **Hard abort if the review does not come back structured.** `review-pr`
   is a slash command, so the run's `--allowedTools` must include
   `SlashCommand` plus everything that command's own frontmatter declares —
   `Bash`, `Glob`, `Grep`, `Read` and above all `Task`, since its entire
   method is dispatching review subagents. If that allowlist is ever
   narrowed, the invocation is denied and the plausible failure mode is not
   a clean error: the agent improvises its own review and commits fixes for
   severity buckets it invented, silently destroying this skill's one
   guarantee. So the prompt makes it explicit — if the invocation errors, or
   returns anything other than a structured Critical/Important/Suggestion
   finding list, the run stops, changes nothing, and says so in the PR
   comment. A self-performed review is never a substitute.

2. **Resolve a verify tier** before touching any file. First read
   `$DEPS_STATUS`, the outcome of the workflow's dependency-install step
   (`workflow-mechanics.md`): anything other than `ok` or `none` means the
   toolchain itself is broken, which is an abort, not a tier. Otherwise
   "available" means checked directly against this repo's manifest (e.g. a
   `build`, `typecheck`, or `lint` entry in `package.json`'s `scripts`) — the
   same signal `setup-project`'s toolchain detection
   (`scripts/detect-toolchain.mjs`) looks for, checked here directly rather
   than by invoking that script, since the headless fix-loop prompt is
   self-contained and has no access to it at CI runtime:
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

3. **Run the verify command ONCE as a baseline, before the first fix.**
   Without this, every non-zero exit gets attributed to whichever fix
   preceded it — so a PR whose checks were *already* failing (the normal
   case for a PR under review) has every correct fix discarded, plus a PR
   comment falsely stating the fix broke the build. npm's scaffold
   `"test": "echo \"Error: no test specified\" && exit 1"` is the worst
   version of this: it satisfies Tier 1 detection and is always red.

   The baseline sorts the run into one of three states, and this is the
   decision — stated here and in the prompt so the two cannot drift:

   | Baseline | Meaning | Response |
   |---|---|---|
   | Exit 0 | Branch is green | Normal loop. A red after a fix is that fix's fault. |
   | Non-zero, harness ran | Branch was already failing | **Drop to Tier 3** for the whole run: commit fixes, never revert on red, carry the baseline-red disclosure. |
   | Harness could not run | Infrastructure failure | **Abort.** Change nothing, commit nothing, disclose. |

   **Why baseline-red drops to Tier 3 rather than aborting.** Aborting would
   refuse to help on exactly the PRs that most need it, and the risk is
   bounded: the branch is already red, the fixes are Critical-only and
   one-per-commit, every one is linked in the comment, and the comment
   carries a permanent "unverified; review carefully before merge" line. The
   disclosure names the baseline explicitly so nobody mistakes it for the
   no-script Tier 3 case:

   ```
   Could not verify — this repo's verify command (<command>) was already
   failing on the unmodified branch before any auto-fix ran, so no fix below
   can be verified against it. Auto-fixed commits below are unverified;
   review carefully before merge.
   ```

   **Why an infrastructure failure aborts instead.** A harness that cannot
   start — command not found, missing module, missing binary, a crash before
   any check executed — tells you nothing about the code. A red from it must
   never be read as "this fix is bad", and a green cannot be read as "this
   fix is good", so there is no safe way to continue. The run makes no code
   change at all and discloses:

   ```
   Could not verify — the verification toolchain could not be prepared in CI
   (<one-line reason>), so no fix could be told apart from a broken harness.
   No code was changed by this run; every Critical finding below is left for
   manual review.
   ```

   This same classification applies mid-loop: if a post-fix verify fails the
   way a broken harness fails rather than the way a test fails, discard the
   working-tree change, stop the loop, and finish with the infrastructure
   disclosure — never with "this fix is red".

4. **Post the summary comment before the first fix**, then update it after
   every pushed commit. Commits go out one at a time while the summary is
   written last, so a run that dies to `--max-turns` or `timeout-minutes`
   after a push would otherwise leave bot commits on the branch with no fix
   list and no disclosure — skipping the one mandatory safety artifact. The
   workflow additionally carries an `if: always()` backstop step
   (`workflow-mechanics.md`) for the case the run dies before even that.

5. **Process Critical findings one at a time, sequentially — never
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

     The trailer is byte-exact: the loop guard greps for it
     (`workflow-mechanics.md`), so it is a checked contract, not decoration.

     Push right away — pushing per-fix, not batching at the end, keeps the
     branch and the summary comment at most one commit apart. The push is a
     literal, exact command, and its exit status is checked:

     ```bash
     git push origin HEAD:"$HEAD_REF"
     ```

     **On rejection (non-fast-forward), the loop stops.** A human pushed
     while the run was working. The two improvisations a model reaches for
     here are both destructive and both explicitly forbidden: `git pull
     --rebase` rewrites a human's history, and `git push --force` /
     `--force-with-lease` destroys their commit — restating the hard
     boundary at the point of use, **never force-push**. Leave the local
     commit unpushed, report the stop in the comment, end the run. The
     human's push will trigger a fresh one.

     **Capture the commit SHA only after the push has exited 0.** A SHA
     captured before a confirmed push can end up linked in the summary
     comment while never reaching the remote — a 404 in the one artifact
     reviewers rely on.
   - e. **Red (only possible in Tier 1/2, and only when the baseline was
     green)** → nothing was committed for this finding, so there is nothing
     to revert via history and nothing to push. Discard the uncommitted
     working-tree change (`git checkout -- .` / `git reset --hard HEAD`,
     resetting to the current `HEAD` — never `HEAD~1`, which would instead
     destroy the *previous* finding's already-verified, already-pushed
     commit) and report in the PR comment:

     ```
     Could not auto-fix safely: <finding file:line> — attempted fix broke
     <failing check name>. Reverted; left for manual review.
     ```
   - f. Move to the next Critical finding; repeat until the list is
     exhausted.

6. **Never batch Critical fixes into one commit** — explicitly the
   opposite of `simplify`'s "one dedicated commit for the whole pass." This
   contrast is deliberate: a future maintainer should not "align" the two
   skills' commit granularity.

## Hard boundaries (stated verbatim in the fix-loop prompt)

- Never touch files outside fixing the one named Critical finding.
- Never merge.
- Never force-push, and never rewrite history already on the remote — no
  `rebase`, no `pull --rebase`, no amend-and-force.
- Never modify `.github/workflows/**`, including its own workflow file — a
  supply-chain-adjacent guardrail so the bot can never edit its own trigger
  or permissions.
- Never re-bucket a finding's severity — `pr-review-toolkit`'s call is
  final, and a review the agent performed itself is not a review.

## What "headless Claude Code reviews, decides Critical, fixes, commits, verifies" means mechanically

The single `anthropics/claude-code-action@v1` invocation in the workflow is
handed a `prompt` (the static asset `assets/fix-loop-prompt.md`) that states
this entire loop verbatim — the exact invocation, the baseline run and its
three outcomes, the per-finding loop above including the tiered verify
resolution and its exact disclosure strings, the commit message shape
(byte-exact, since the loop guard greps for the trailer), the exact push
command and its rejection path, the comment contract (see
`comment-contract.md`), and the hard boundaries above. This prompt is the
actual "skill logic" running at CI time — the GitHub Actions job and the
official action are a thin, static harness; all the judgment lives in the
prompt asset.
