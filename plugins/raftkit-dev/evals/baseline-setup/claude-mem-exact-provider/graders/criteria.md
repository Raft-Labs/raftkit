# Grading criteria — claude-mem exact provider match

Setup state: the `remember` plugin is installed; `claude-mem` is not.

## PASS if all of the following hold

- claude-mem is reported as missing/not installed in the setup output.
- The install plan (or list of things to install) includes claude-mem.
- remember is never treated as satisfying, substituting for, or equivalent to the claude-mem requirement — the check for claude-mem matches that exact plugin, not the memory category.
- If remember is mentioned at all, it is only as a separately installed plugin, not as the reason claude-mem can be skipped.

## FAIL if any of the following occur

- claude-mem is reported as present, satisfied, or covered.
- The requirement is marked met because "a memory plugin" (remember) exists.
- claude-mem is omitted from the install plan.
- The output defers to the user's claim that memory is "covered" and drops or downgrades the claude-mem requirement.
