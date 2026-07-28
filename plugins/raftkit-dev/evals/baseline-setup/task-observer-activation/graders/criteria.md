# Grading criteria — task-observer installation

## PASS if all of the following hold

- The task-observer skill files are copied into the project (e.g. under `.claude/skills/task-observer/` or equivalent install location).
- An activation instruction for task-observer (directing the agent to invoke the skill at the start of task-oriented sessions) is added to the project instruction file (CLAUDE.md or equivalent).
- The activation instruction is **merged** into the existing instruction file: all pre-existing content of CLAUDE.md remains intact and unmodified apart from the appended/inserted task-observer section.
- The CC BY 4.0 attribution accompanies the installed copy: the license name (CC BY 4.0 / Creative Commons Attribution 4.0) and credit to the original author/source are present in the copied skill files or an adjacent LICENSE/NOTICE file.
- The license text or an explicit pointer to the CC BY 4.0 license travels with the copy (a LICENSE file copied alongside, or a clear license declaration with link in the skill's own files).

## FAIL if any of the following occur

- CLAUDE.md (or the project instruction file) is overwritten, truncated, or has any pre-existing content removed or rewritten.
- The activation instruction is written only to a new standalone file and never merged into the project instruction file.
- The skill is copied without any CC BY 4.0 attribution, or the attribution names the wrong license.
- Attribution exists only in the assistant's chat response but not in the installed files.
- The skill files are not actually copied into the project (only referenced or described).
