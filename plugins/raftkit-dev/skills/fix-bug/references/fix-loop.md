# The fix loop — red before fix

The mechanics behind the one rule: the defect becomes a **failing test first**, the
fix turns it green, and the fix never expands past the bug's "Done when" nor reddens
the rest of the suite. This loop orchestrates existing engines — it rebuilds none of
them.

## The enforced order

SKILL.md's Run flow is the canonical sequence; this section only adds the gating
mechanics for the three steps where the order is load-bearing. Each step gates the
next, and the fix step is **unreachable** until the repro test is observed red.

- **Intake gate** — §6/§8/§13 must be present or the bug bounces before any fix
  work begins (`bug-intake-and-handback.md`).
- **Reproduce → red test gate** — wrap superpowers `systematic-debugging` to
  replicate the defect from §8's steps in §6's environment, and encode it as a test.
  The test must be **observed failing for the reason the bug describes** — a test
  that passes, or fails for an unrelated reason, is not a repro; do not proceed.
  Cannot reproduce → hand back to QA (`bug-intake-and-handback.md`); never fix blind.
- **Fix → green gate** — only once the repro is red, implement the **smallest**
  change that turns it green. Nothing speculative, nothing adjacent. The whole suite
  must then be green (the hard stop below).

## The repro test is permanent

The repro test is committed on the branch and **stays in the suite forever** as a
regression guard. It is never deleted once the fix is green — a deleted repro test
is exactly how a fixed bug silently returns. It is part of the permanent diff, on
equal footing with the fix.

## Fix breaks another test = hard stop, fix-first

After the fix, the **whole** suite must be green, not just the repro test. If the
fix turns any other test red:

- **Stop.** Do not open the PR, do not hand back.
- **Fix-first** — the regression the fix introduced is now the problem to solve;
  resolve it before proceeding. A fix that trades one red test for another is not a
  fix.
- Never ship a fix that reddens the suite, and never disable or delete the newly
  red test to get green.

This mirrors `simplify`'s behaviour-wins-over-beauty guarantee: behaviour is the
line, and the suite is how behaviour is proven.

## Scope = the bug's "Done when" only

Scope is §13's "Done when" checklist and nothing else. The `scope-guard` sibling
owns the audit — do not reinvent it. Reuse its semantics directly:

- Any changed hunk that maps to no "Done when" item lands in **BEYOND** — removed,
  or kept only with an explicit logged sign-off (silence is not approval).
- Adjacent ugly code near the defect is a classic BEYOND temptation: it is out of
  scope unless a "Done when" item covers it. Flag it, don't fold it in.

## Git conventions (same loop as feature work)

Bugs ship through the shared `raftkit-core` release-train conventions — identical to
feature implementation:

- **One branch** for the bug fix.
- **Small, conventional commits** — the repro-test commit and the fix commit are
  separate logical commits; the fix commit uses the `fix:` type and reads as a
  changelog line.
- **One squash PR**, base per the repo's release model.
- **Human merge** — the skill opens the PR and stops; a human merges. It never
  auto-merges.

## The seam in one line

`systematic-debugging` reproduces and diagnoses → the repro test makes the defect
red → the fix turns it green → `scope-guard` proves the diff didn't exceed the bug →
`simplify` proves it isn't over-built → the squash PR carries it to a human merge.
