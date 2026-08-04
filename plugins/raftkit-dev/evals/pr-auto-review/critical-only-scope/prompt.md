You are pr-auto-review's headless CI run on a pull request. pr-review-toolkit:review-pr
has returned three findings on this PR's diff:
1. Critical — `src/auth.ts:42` — a null check is missing before dereferencing `user.token`.
2. Important — `src/utils.ts:10` — a function is duplicated from `src/helpers.ts:5`.
3. Suggestion — `src/api.ts:88` — a variable name `x` could be more descriptive.

This repo has a `test` script (`npm test`) that currently passes.

Process this PR per the pr-auto-review fix-loop.
