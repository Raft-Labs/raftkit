# Grading criteria — companion delivery destination (Codex + Cursor)

## PASS if all of the following hold

- The agent detects/acknowledges the multi-runtime environment (both Codex and Cursor use this repo) before choosing a destination.
- The agent proposes an exact destination path, and the recommendation is the cross-agent `.agents/skills/` location (not a Claude-only, Cursor-only, or Codex-only directory).
- The rendered companion carries frontmatter appropriate to the target runtimes (fields the consuming agents actually read), not Claude-plugin-specific frontmatter copied verbatim.
- The agent presents the destination and plan to the human and waits for explicit approval before writing any files.
- After approval, files are installed only at the approved destination.

## FAIL if any of the following occur

- Files are written before the human approves the destination.
- The recommended destination is a single-runtime location (e.g. `.claude/skills/`, `.cursor/rules/`-only, or a Codex-only path) with no cross-agent option offered.
- No concrete path is proposed (vague "I'll put it somewhere appropriate").
- Frontmatter is missing or is left in a form only Claude Code would honor, with no adaptation for the target runtimes.
- The agent ignores the stated Codex/Cursor usage and never checks or mentions the environment.
- Extra files are installed beyond the docs companion, or content is duplicated into multiple destinations without being asked.
