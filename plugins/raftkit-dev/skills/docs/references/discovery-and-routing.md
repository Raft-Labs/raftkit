# Discovery and routing

Convention discovery answers: where do docs live, how is ownership expressed,
how is history recorded, where do decisions go — for THIS repository.

## The in-memory discovery result

`scripts/audit-docs.mjs --root <repo> --json` produces it deterministically:
documentation roots, convention (`module-indexed` · `flat-ownership-indexed` ·
`ambiguous` · `none`), index files, ownership mapping (table rows and per-doc
"Update when you change:" footers), history convention (per-doc footer chains
or a changes-log), ADR seam (an `adr/` directory or decisions index),
confidence, and unresolved conflicts.

**It is not persisted automatically.** It exists for this run.

## Persisting a descriptor (approval-gated)

When repeated runs would benefit from a recorded convention (typically after
reverse-engineering a convention-less repo), propose a **project-owned**
descriptor: show the exact path (inside the project, e.g. under its docs root
or config — never inside the plugin) and the exact content. The human approves
**both** before the file is created. Existing conventions remain authoritative
over a descriptor: a descriptor never overrides what the repo itself expresses.

## Conflicts never resolve silently

Two cases, same rule:

- **Ambiguous discovery** — the repo carries signals of more than one
  convention. Report each signal with its evidence.
- **Descriptor vs discovery** — an approved descriptor contradicts what the
  repo now expresses. Report both sources and the exact conflict.

In both cases: make no documentation mutation, return the documented
conflict/bad-input result (the scripts exit 2), and ask the human which
convention should become authoritative. Update the loser (descriptor or docs)
only through the normal confirmed lifecycle.

## Branch routing

- No docs root + approved planning outputs + no code → **greenfield handoff** → init.
- No docs root + real code → **existing code, no living docs** → audit /
  reverse-engineer; docs proposals come from evidence.
- Docs root present → **living docs** → discovered conventions are the
  yardstick; validation and sync run against them.

## Scan safety

All discovery walks are root-confined (out-of-root symlinks refused and
reported, never followed) and exclusion-aware (VCS metadata, dependency/vendor
directories, build output, caches, auth state, and secret/env files are skipped
— secret files are counted as metadata, their contents never read).

## The descriptor schema (minimal and truthful)

A project-owned convention descriptor (proposed, never auto-created) has a
minimal, documented schema — it asserts only what it names:

| Field | Type | Meaning |
|---|---|---|
| `convention` | string | the authoritative documentation convention this repository uses |
| `note` | string (optional) | human context for the choice |

`scripts/validate-docs.mjs --convention <path>` enforces this: the descriptor
must resolve **inside** the repository root (symlink-aware — an out-of-root path
is rejected even if it exists), and **any unknown field is rejected**. The
descriptor never overrides a discovered repository convention silently; a
descriptor-vs-discovery clash stops with the conflict reported (exit 2).
