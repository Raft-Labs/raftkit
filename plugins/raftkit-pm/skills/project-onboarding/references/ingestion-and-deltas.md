# Ingestion, conflicts, and deltas

How onboarding reads the PM's named sources, what it does when one cannot be read,
how it surfaces disagreements, and how a re-run stays a delta instead of a rewrite.

## Reading the named sources

Read only the sources the PM named — never reach for one they did not ask for —
each through whatever access path it arrives on:

- **Google Drive** — PRD, SOW, master doc, and other project documents.
- **Gmail** — email threads.
- **Fathom** — meeting recordings and their transcripts.
- **Asana** — tasks and prior stories.
- **Uploaded files** — a PRD, SOW, or transcript dropped into the conversation;
  cite as "uploaded file, as-of \<date\>".
- **Synced local folder** — Drive mounted via Google Drive for Desktop: reading the
  doc is a local file read; the citation still names the doc.
- **Pasted links** — resolve via the Drive connector, or via the synced folder when
  mounted.

**Progress (Waiting).** Long ingests report progress per source as they go, e.g.
"read 3 of 5 sources", so a slow run stays legible.

**Per-run context bound (Limits).** The source set is bounded by what fits a single
run's context — there is no fixed number.
When the named sources will not fit a single run's context window, say so and split
the ingestion into batches rather than truncating a source silently — a half-read
source produces false ⚠️/❓ tags.

## Unreadable source — name it, never drop it

If a source cannot be read — connector down, no access, missing or moved file, or a
link or upload that cannot be resolved — do
**not** fail the whole run and do **not** silently skip it:

1. Name the **exact source** that failed and the **access that is missing** (for
   example: "can't read the Fathom call from 12 May — the Fathom connector isn't
   connected").
2. Continue ingesting every source that *can* be read (partial ingest).
3. List the skipped sources in the result so the PM knows precisely what did not
   make it into this draft and can re-run once access is fixed.

Silently dropping a source is the failure this rule exists to prevent: it would
produce a confident-looking profile that is quietly incomplete.

## Conflicts — surface both, resolve neither

When two sources state different values for the same fact (the PRD says one limit,
a client email says another), record it as a **conflict**, not a fact:

- Present the conflicting values side by side, each with its own citation.
- Mark it for the PM to resolve; the PM decides which holds.
- Never silently pick a winner, and never average or merge the two.

## Re-runs propose a delta, not a rewrite

When the project already has its `Project Profile - <project name>` task and the PM
adds a new source, compute the change against the current profile and present it as
a **delta** — never regenerate the whole profile from scratch:

- **Changed** — an existing fact whose value or tag the new source updates.
- **New** — a fact not previously in the profile.
- **Now-confirmed** — a ⚠️ Partial or ❓ Missing fact the new source lifts to
  ✅ Confirmed.

Leave every untouched fact exactly as it was, and show the delta for approval
before writing (`raftkit-core/write-protocol`). A rewrite would discard the PM's
prior resolutions and the profile's history; a delta preserves them.

A delta touches **only the subtasks whose sections changed** — an untouched section
is not rewritten, and a section the sources newly support is added as a new subtask.
Record the run afterwards as one comment on the parent task (`profile-format.md`),
since an overwritten description leaves no trace in Asana.
Writing a subtask replaces its description, which `raftkit-core/asana-formatting`
permits only on an explicit human instruction, so name the subtasks about to be
overwritten when asking for approval.
