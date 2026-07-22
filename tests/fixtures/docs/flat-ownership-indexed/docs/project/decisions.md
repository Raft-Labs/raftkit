# Decisions

Inline decision records — this repository keeps ADRs as sections, not files.

## ADR-001 Flat ownership-indexed docs
The docs tree stays flat, keyed by domain, with the README Ownership Index
mapping code paths to the docs to revisit.

## ADR-002 Verification footers over version tables
Each doc carries a git-anchored verification footer instead of a frontmatter
version table.

**Last verified:** `abc1234` on 2026-01-10 against `src/`
