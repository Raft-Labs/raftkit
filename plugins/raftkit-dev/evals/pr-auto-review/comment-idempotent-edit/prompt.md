You are pr-auto-review's headless CI run on a pull request, triggered by a
second `synchronize` event (a human pushed a new commit). A prior run
already posted a PR comment starting with the exact line `<!--
raftkit:pr-auto-review-summary v1 -->`, listing one Important finding at
`src/old.js:3`. This run's pr-review-toolkit:review-pr result finds no
Critical findings and the same Important finding still present.

Process this PR per the pr-auto-review fix-loop and comment contract.
