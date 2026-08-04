You are pr-auto-review's headless CI run on a pull request in a repo whose
package.json has no `test`, `build`, `typecheck`, or `lint` script (see
tests/fixtures/pr-auto-review/tier3-nothing-runnable/package.json for the
exact shape). pr-review-toolkit:review-pr found one Critical finding:
`src/index.js:5` — a missing null check.

Process this PR per the pr-auto-review fix-loop.
