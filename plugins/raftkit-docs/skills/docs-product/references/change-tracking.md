# Change tracking — the seven-step lifecycle

Every documentation change for an approved change set runs the same confirmed
protocol. No step is skippable; the confirm step is the human gate.

1. **Identify** the affected docs — from the discovered ownership mapping and
   the explicit change set (never a silently chosen Git range).
2. **Classify** the change: `additive | breaking | rename | removal |
   architectural`.
3. **Confirm** — present the exact affected-doc list with the classification
   and wait for the developer's approval. A Gate-approved docs impact plan from
   the calling workflow satisfies this step; anything beyond it does not.
4. **Update** the approved docs (and only those), matching each doc's existing
   style and depth.
5. **Record** the change in the repository's own history convention — per-doc
   frontmatter versions with a local changelog table, git-anchored
   verification footer chains, a central changes-log — whichever the repo
   already uses. A new convention is introduced only via an approved proposal.
6. **ADR only when architectural** — a decision record is created or updated
   only for changes that cross an architectural seam, in the repo's discovered
   ADR seam. Routine edits create no ceremony. No ADR seam + an architectural
   change → propose one (approval-gated), don't invent silently.
7. **Re-verify** the affected surface (`scripts/validate-docs.mjs` scoped to
   the change set) and report the result.

## Impact-list expansion

If step 4 reveals more affected docs than step 3 approved, **stop**: the
approved docs may finish, but the additions are presented for approval before
any extra doc is written. A widened list is a new confirmation, never an
implied one.

## Restored guarantees (convention-aware)

The lifecycle carries the original product guarantees, expressed in whatever
convention the repository uses — version tables or verification footers, a
module-indexed tree or a flat ownership-indexed one:

- **Affected-doc expansion mapping** — step 1 uses the discovered
  change-type → touched-docs mapping (an ownership-index table, module
  folders, or naming conventions) so a schema change expands to its schema
  doc, affected screens/features, API docs, and depicted diagrams — never
  just the file the developer named.
- **Per-doc history** — every rewritten doc records its own history in the
  repo's convention (version bump + local changelog row, or a refreshed
  verification footer).
- **Project changelog and pointer log** — where the convention keeps a
  release changelog and/or an append-only changes-log, both receive their
  entries; the pointer entry names the files rewritten and downstream
  actions.
- **Diagrams regenerated** — any diagram depicting a changed element is
  regenerated in the same pass, never left stale.
- **ADR when architectural** — step 6, in the repo's discovered ADR seam
  (folder of records or inline decision sections alike).
- **Completion parity** — docs catch up before the next unrelated task; a
  deferral is recorded explicitly and blocks the done claim until cleared.
  Linked Asana story refresh is the Asana-lifecycle story's adapter seam,
  reached only through draft → approve → push.

## Scope discipline

Docs churn that maps to no `[AC]` and no proven contract inconsistency is
surfaced as an observation for the developer to defer or schedule — it never
rides along in the approved change set. Diagrams are regenerated when the
change alters what they depict; none are created by quota.
