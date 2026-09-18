# fix/frontmatter-colon-scalar — a colon-space in unquoted frontmatter loads a skill with no metadata

## Why

A plain (unquoted) YAML scalar may not contain `": "`. YAML reads it as a nested mapping entry, and because the nesting is unindented the block fails with `bad indentation of a mapping entry`. The parser does not lose only that value — it rejects the **entire frontmatter block**, so `name`, `description` and `user-invocable` go with it and the file loads with no metadata at all. The skill never triggers, and nothing reports why.

Six shipped `SKILL.md` files carried the shape, every one of them on a trailing cross-reference added during the v2 refactor:

| File | Breaks on |
|---|---|
| `raftkit-core/skills/working-agreement` | `(ten rules: model tiers, …` |
| `raftkit-pm/skills/meeting` | `Scheduling: raftkit-pm:routine.` |
| `raftkit-pm/skills/estimate` | `One story: raftkit-pm:story size.` |
| `raftkit-qa/skills/run-sheet` | `Project-wide suite: suite. Filing a failure: bug.` |
| `raftkit-qa/skills/bug` | `Fixing: raftkit-dev:fix.` |
| `raftkit-docs/skills/docs-product` | `Opt-in: install raftkit-docs.` |

**Nothing in the repo caught it.** `scripts/validate.sh` exited 0 with all six present, `claude plugin validate` passed them, and `tests/structure.test.sh` checks that `name` matches the directory and counts description words without ever strict-parsing the block. The defect was found while planning the port of PR #62, whose commit `50ae5f1` had fixed one instance of it on a pre-v2 tree; the shape recurred five more times after that branch was abandoned.

Origin of the idea: `50ae5f1` on `feat/cowork-telemetry` (Rahul Retnan). This branch carries it forward against v2 and widens it from one file to a repo-wide guard.

## Scope

In: the six descriptions; a repo-wide checker and its contract suite; four patch version bumps; one stale doc reference.

Out: the Cowork telemetry feature the same source branch carries (that is PR #62, rebuilt separately — folding it in here would make this a four-plugin feature PR and cost the changelog line its meaning); any rewording of a description beyond what the word cap forces; `raftkit-dev`, which carries no instance.

## Decisions

- **Em dash, not quotes.** Five of the six descriptions already contain double quotes around trigger phrases, so `"…"` wrapping needs escaping and `'…'` needs every apostrophe doubled (`story's`, `project's`). An em dash keeps the scalar plain, matches v2 punctuation, and introduces no new hazard class for the next editor to trip on.
- **The swap is word-neutral where it had to be.** S3 caps a description at 60 words. `raftkit-qa/bug` sat at 60 and `run-sheet` at 59, and `wc -w` counts a spaced em dash as a word, so the naive swap pushed both over. Each paid for itself in the same description: `bug` dropped `per chat` from "Reads the live Bugs Template once per chat"; `run-sheet` shortened "expected results quote the story verbatim" to "quote it verbatim" and "Filing a failure — bug" to "Failures — bug".
- **A sequence item is a different fault, reported differently.** `- Bash: the tool` is *legal* YAML — the item silently becomes the mapping `{Bash: "the tool"}` instead of the string it reads as. Verified against a strict parser rather than assumed. The block still loads, so the checker says so rather than claiming metadata loss; `tests/frontmatter.test.sh` FM2c pins that the two messages do not make the same claim.
- **No YAML library.** CI installs the pinned Claude CLI and never runs `npm install`, so `node_modules/` is absent when the checker runs. `js-yaml` exists locally only as a transitive eslint dependency. The checker is a line scan over node builtins, and FM1e fails the build if a library import appears.
- **The checker also flags a value ending in a bare colon**, which fails the same way, and an unterminated frontmatter block, whose content is still checked rather than dropped.

## Phases

| # | Tier | Files | Tests |
|---|---|---|---|
| 1 | mechanical | the six `SKILL.md` descriptions | `tests/frontmatter.test.sh` FM5 |
| 2 | standard | `scripts/check-frontmatter.mjs`, `tests/fixtures/frontmatter/` | `tests/frontmatter.test.sh` FM1–FM4, FM6 |
| 3 | mechanical | four `plugin.json` versions, `docs/specs/2026-09-16-raftkit-v2-design.md` | `scripts/validate.sh` |

## Verification

`tests/frontmatter.test.sh` — 30 checks. Negative controls assert the exact exit code and violation text, not merely "nonzero": a bad target exits 2 and must never read as "violations found". Positive controls prove the rule does not over-fire on quoted scalars, block scalars, flow collections, URLs, or a file with no frontmatter.

FM6 is the check that makes a green run mean something: it injects the exact defect back into a copy of a real shipped skill and requires the checker to catch it there. A suite that only ever sees hand-made fixtures can pass while missing the shape that actually occurs in the tree.

Measured after the fix: 192 frontmatter blocks across 254 files, all strict-parseable; the six formerly-broken files parse with all three keys intact.

## Follow-up

`raftkit-pm:*` skills have been reported as erroring when invoked in a dev session, and `meeting` and `estimate` are two of the six. That symptom should be re-tested now the block parses — if it clears, the two are the same bug; if not, it is a separate one.
