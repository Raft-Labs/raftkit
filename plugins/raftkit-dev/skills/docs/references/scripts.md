# The two readers

Both are pure readers: they mutate nothing, persist nothing, stay inside the resolved repository root, follow no out-of-root symlink, and never read the contents of a secret or env file.

## audit-docs.mjs — discovery

```
node audit-docs.mjs --root <repo-root> [--json] [--out <path-inside-root>]
```

Emits the in-memory discovery result: preflight branch, convention, roots, ownership evidence, history convention, decision-record seam, confidence, unresolved conflicts. Exit 0 when a report is produced (conflicts are reported, not fatal); exit 2 on bad input.

## validate-docs.mjs — parity

```
node validate-docs.mjs --root <repo-root> [--changed <file|->] [--base <ref> [--head <ref>]]
                       [--convention <descriptor.json>] [--graded] [--json] [--out <path-inside-root>]
```

Checks links and, given an explicit change set, staleness and no-impact with named evidence. Exit 0 clean, including an evidence-backed no-impact; exit 1 findings; exit 2 bad input, an unrecognized convention, or a convention conflict. An invalid or ambiguous revision is bad input, never an empty change set. Renames count on both paths. `--graded` adds P0 (blocks a done claim) / P1 / P2 grading.

Machine output goes to stdout or an explicit `--out` path inside the repository root. No unsolicited report files.

## Persisting discovery

If persisting the discovery result would help, propose a project-owned descriptor with its exact path and content at the stop. Existing conventions stay authoritative over any descriptor; a descriptor that contradicts discovery is reported, and the human decides which holds.

The descriptor schema is minimal and closed: the only documented fields are `convention` and `note`, and any unknown field is rejected rather than ignored, so a descriptor asserts only what it names. It must resolve inside the repository root, symlinks followed, or it is bad input.
