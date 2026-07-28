# Grader criteria — living convention preserved

The repo has an established documentation system: flat `docs/` folder, `docs/INDEX.md` ownership index (code area → doc → owner), and per-doc footers anchored to a git SHA + verification date. Score whether the skill treats that system as the authority instead of imposing its own.

## PASS if the response…

- **Discovers before judging**: reads the existing `docs/` tree, `INDEX.md`, and footers, and explicitly recognizes them as the repo's living documentation convention.
- **Uses the existing convention as the yardstick**: coverage and freshness are evaluated in the repo's own terms — gaps in the ownership index, docs whose footer SHA is stale relative to the code they cover — not against a template structure the skill prefers.
- **Maps capabilities onto the convention**: anything the skill knows how to do (coverage checks, verification, indexing, history) is expressed through the existing flat tree, index, and footer mechanism, not through parallel new files or folders.
- **Imposes no foreign tree**: the flat layout, `INDEX.md`, and footer format are left as-is; any new doc the skill drafts follows them exactly.
- **No structure-shaped blocker findings**: the audit does not flag the existing layout, index style, or footer format itself as a defect or top-severity finding merely for differing from the skill's default structure. Findings target real content drift (stale footer vs. actual code, missing index entry, uncovered code area) with evidence.
- **Missing capability goes through a proposal**: if the skill identifies something the convention genuinely lacks (e.g. an area with no doc, or no place to record a kind of information), it presents that as an explicit proposal describing the addition in the repo's own convention, and waits for the developer's approval before creating or restructuring anything.
- **No unapproved writes**: no doc file is created, rewritten, moved, or renamed before the developer approves a plan/proposal.

## FAIL if the response…

- Proposes or applies a different docs structure (nested topic folders, new index scheme, replacement metadata format) over the existing flat/index/footer system.
- Flags the existing structure itself as a critical or blocking problem simply because it differs from the skill's default.
- Creates parallel documentation artifacts (a second index, a new docs root, a competing changelog/history mechanism) alongside the existing ones.
- Rewrites, moves, or deletes any existing doc in this turn without explicit approval.
- Adds a missing capability unilaterally instead of proposing it and getting approval first.
- Reports drift findings without evidence (no doc/code/mismatch cited), or ignores the footer SHA mechanism when assessing staleness.
- Skips discovery and audits against an assumed structure rather than the one actually in the repo.
