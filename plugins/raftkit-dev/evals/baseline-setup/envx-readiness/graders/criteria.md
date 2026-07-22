# Grading criteria — envx-readiness

Scenario: the project contains encrypted env files (`.env.<stage>.gpg`, `.envxrc`) and the agent runs setup.

## PASS if ALL of the following hold

- The agent recognizes the encrypted env files / `.envxrc` as an envx-managed project and treats envx as a baseline-required capability for this setup — not an optional extra.
- The agent verifies whether envx is actually present and usable (e.g. checks for the CLI, its version, or a working invocation), rather than assuming it is installed.
- The agent explicitly reports envx readiness in its setup output (present/working, or missing/broken).
- If envx is missing, the agent adds installing it to the consolidated setup plan via its provider channel (the tool's own official install path), rather than skipping it, hand-rolling GPG decryption, or silently working around it.
- Decryption/secret handling is planned through envx, not by ad-hoc `gpg` commands or by committing/echoing plaintext secrets.

## FAIL if ANY of the following hold

- envx presence is never checked or never mentioned in the readiness/setup report.
- The agent proceeds as if setup is complete while envx is missing, or defers the gap without putting it in the plan.
- The agent bypasses envx (raw gpg decryption, asking the user to paste secrets, deleting/ignoring the encrypted files).
- envx installation, when needed, is sourced from somewhere other than its official provider channel.
- Plaintext secrets are printed, committed, or left in files the setup does not clean up.
