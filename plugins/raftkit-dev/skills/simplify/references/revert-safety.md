# Revert-safety — the behaviour guarantee

Behaviour wins over beauty. This file is the exact ordering and mechanics that
make the pass safe: a red suite before it refuses; a red suite after any change
reverts that change. Nothing here is optional — it is the core guarantee the skill
exists to provide.

## Pre-flight: refuse on a red suite

Before touching a single file, run the **full test suite once**.

- **Green** → proceed to find candidates.
- **Red** → **refuse to start.** Do not simplify anything. Report the failing
  test by name and stop with the fix-first message:

  ```
  Suite is red before the pass — fix the failing test first, then re-run simplify.
  Failing: <test name>
  ```

  A red suite means behaviour is already unknown; simplifying on top of it would
  make it impossible to tell whether the pass changed behaviour. The fix comes
  first, always. This is the pre-flight fix-first rule.

If there is no runnable suite at all, stop and ask — revert-safety is undefined
without one, and the pass must not run blind.

## Apply, then verify — auto-revert on red

After the developer approves the before/after batch:

1. Apply the approved removals in small batches, ideally one candidate at a time —
   so the offending change is identifiable when a test goes red.
2. **Re-run the full suite.**
3. If any test is now **red**, the change turned behaviour red:
   - **Auto-revert** the offending change (restore the pre-change state).
   - Report it, **naming the failing test**:

     ```
     Reverted <change> — it turned <test name> red. Behaviour wins over beauty.
     ```
4. Re-run until the applied set is green.

The invariant is that **every change that survives the pass leaves the suite
green** — no change that turned a test red is ever committed.

## Commit — one dedicated commit, or none

- **Removals survived** → make **one dedicated simplify commit** (conventional
  form, e.g. `chore: simplify <area> — remove speculative abstractions`) and
  report the success line **exactly**:

  ```
  Simplify: N removals, suite green (X tests), one commit
  ```

  where `N` is the number of removals that survived and `X` is the passing test
  count.

- **Nothing to simplify** → say **exactly** that and make
  **no commit** — never an empty commit:

  ```
  Nothing to simplify — the diff is already minimal. No commit made.
  ```

One pass produces at most one commit. List-only candidates are reported alongside
the outcome, never committed.

## Scope boundary

Every candidate, every applied change, and the single commit stay within the
**story branch's diff** — the files the story changed, computed against the
branch's base. Files outside that set are never modified; reading them for context
is fine, editing them is not. An out-of-diff change is a scope violation, not a
simplification.
