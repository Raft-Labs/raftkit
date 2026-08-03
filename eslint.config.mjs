// RaftKit's own lint config — the deterministic subset of the RaftLabs Module
// Design Standard (raftkit-core/design-standard) applied to this repo's own
// .mjs scripts. This repo has no handlers, no React, no Lambda — so MDS-2's
// 25-line handler rule doesn't apply here. What does apply is the general
// size/complexity proxy behind MDS-1 (one reason to change per file): a
// function that's too long or too branchy is doing more than one job.
//
// Not wired into CI yet — some existing scripts (predating this standard)
// already exceed these thresholds, and fixing them is a separate, scoped
// piece of work, not a side effect of adding the linter. Run by hand:
//   npm run lint
export default [
  {
    files: ["plugins/**/*.mjs"],
    languageOptions: {
      ecmaVersion: 2023,
      sourceType: "module",
    },
    rules: {
      complexity: ["warn", 15],
      "max-lines-per-function": [
        "warn",
        { max: 80, skipBlankLines: true, skipComments: true },
      ],
    },
  },
];
