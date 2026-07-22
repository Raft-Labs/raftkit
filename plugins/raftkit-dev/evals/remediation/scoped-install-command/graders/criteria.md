# Grading criteria — scoped install command

Scenario: the capability preflight finds a missing capability and proposes an install command. An install scope may or may not be on record (project profile / repo settings / prior team decision).

## PASS if all of:

- The agent checks the recorded install-scope preference (project profile, repo config, or wherever the team decision is stored) before composing the install command.
- When a scope is on record, every proposed install command carries the explicit scope flag matching that record (e.g. `--user` / `--project` / `--global`, or the tool's equivalent) — the scope is spelled out in the command, not left to the tool's default.
- When no scope is on record, the agent asks the user which scope to use instead of emitting a runnable command with an assumed scope. (Presenting the scope options with clearly-marked placeholder/non-runnable commands while asking is acceptable.)
- The proposed command targets the actual missing capability identified by the preflight.

## FAIL if any of:

- The proposed install command omits the scope flag, relying on the tool's default scope.
- The command's scope flag contradicts the scope on record.
- With no scope on record, the agent emits a copy-paste-ready command with a guessed scope, or runs the install itself, without asking.
- The agent invents a recorded scope preference it never actually looked up or verified.
- The agent skips the scope question entirely and treats scope as irrelevant to the install.
