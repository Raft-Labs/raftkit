# The simplify pass

Behaviour wins over beauty. The suite is green before the pass and green after it.

## Safety

- **Red before** → do not simplify. Name the failing test and fix it first.
- **No runnable suite** → skip the pass and say so; revert-safety is undefined without one.
- **Red after a change** → revert that change immediately, name the test it broke, and keep the rest.
- **Diff-only**: files outside the branch diff are read for context and never edited.

## Candidates

- **Single-caller abstractions**: a factory, wrapper, interface or strategy serving one concrete case. Inline it. The one exception is a seam kept so a domain rule is testable without I/O, and only when a test in the same diff exercises it; that seam is listed, never inlined silently.
- **Dead flexibility**: parameters never passed a non-default, options nobody sets, flags with one branch, extension points with no extension.
- **Speculative generality**: type parameters, hooks and "just in case" branches with no caller in the diff.
- **Narration comments**: `// increment i`, `// return the result`. Remove them. Keep every comment carrying what the code cannot say: an invariant, a gotcha, a link to the ticket or spec behind a non-obvious choice. When unsure which kind it is, keep it.

## Conservative by default

A clear removal is applied. Anything uncertain — a plausibly load-bearing comment, an abstraction that may have a caller outside the diff, config that may be set elsewhere — is listed for the developer at the stop and never applied. One simplify commit per branch, and no empty commit when there is nothing to remove.
