// raftkit-governance-pack
//
// The deterministic subset of the RaftLabs Module Design Standard
// (raftkit-core/design-standard) — the rules an LLM reviewer catches ~70% of
// the time and a linter catches 100%: MDS-1 (size/complexity), MDS-2
// (handler thinness), and MDS-8 (import cycles). The other seven rules
// (MDS-3..7, 9, 10) stay with /implement's design-review layer — they turn on
// judgment a linter can't make.
//
// This file installs unrendered, byte-verbatim (no tokens) — same as
// coderabbit.yaml. It does NOT self-install into your eslint.config.js: this
// repo's own config is yours, and safely merging into an arbitrary existing
// one is out of scope for an installer. Wire it in with one line:
//
//   import mds from "./.raftkit/mds-eslint.config.mjs";
//   export default [...yourExistingConfig, ...mds];
//
// MDS-8 (import/no-cycle) requires eslint-plugin-import — not assumed
// installed; add it yourself (`npm i -D eslint-plugin-import`) and uncomment
// the block below once it's present. Never invented or silently required.

export default [
  {
    files: ["**/*.{js,jsx,ts,tsx,mjs}"],
    rules: {
      // MDS-1 — one reason to change per file (size/complexity proxy).
      complexity: ["warn", 15],
      "max-lines-per-function": [
        "warn",
        { max: 60, skipBlankLines: true, skipComments: true },
      ],
    },
  },
  {
    // MDS-2 — handlers are thin adapters. Adjust these globs to match your
    // repo's actual handler locations (Lambda functions, Next.js Route
    // Handlers / API routes, Server Actions) — this list is a starting point,
    // not a detected fact about your repo.
    files: [
      "**/api/**/*.{js,ts}",
      "**/app/**/route.{js,ts}",
      "**/functions/**/*.{js,ts}",
      "**/pages/api/**/*.{js,ts}",
    ],
    rules: {
      "max-lines-per-function": [
        "warn",
        { max: 25, skipBlankLines: true, skipComments: true },
      ],
    },
  },
  // MDS-8 — import cycles. Uncomment once eslint-plugin-import is installed:
  //
  // {
  //   plugins: { import: (await import("eslint-plugin-import")).default },
  //   rules: { "import/no-cycle": "error" },
  // },
];
