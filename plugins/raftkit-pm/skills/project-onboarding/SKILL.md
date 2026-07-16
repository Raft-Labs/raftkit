---
name: project-onboarding
description: This skill should be used when a RaftLabs PM wants to turn everything they have about a project — PRD, SOW, master doc, email threads, meeting recordings — into one Project Profile that downstream skills treat as the source of truth. Trigger on "onboard this project", "build the project profile", "set up the source of truth for project X", "ingest my PRD and emails into one profile", or a re-run with a new source. It reads only the sources the PM names across the Cowork connectors (Google Drive, Gmail, Fathom, Asana), tags and cites every fact, surfaces conflicts without resolving them, and writes only after PM approval. For generating a per-project story skill from an approved profile, use story-skill-generator instead.
user-invocable: true
---

# project-onboarding

Turn whatever a PM has — PRD, SOW, master doc, emails, meeting notes — into **one
Project Profile** where every fact is tagged ✅ Confirmed / ⚠️ Partial / ❓ Missing
and cited to its source. Downstream skills then work from that single tagged
source of truth instead of scattered docs.

This packages the flowhoney master-doc pattern (PRD §5.2): story quality depends
on a source of truth with explicit confidence tags. The profile is the single
source of truth for delivery on the project — project facts live here, never in
plugins (`raftkit-core/house-rules`).

## The rules that govern everything

- **Never guess.** ❓ Missing means a fact is explicitly absent; the skill never
  fills a gap with a plausible-sounding value. Any untagged fact defaults to
  **⚠️ Partial, never ✅** — confidence is earned from a source, not assumed.
- **Surface conflicts, never resolve them.** When two sources disagree, present
  both with their citations and let the PM decide. The skill never silently picks
  a winner.
- **Never write without PM approval.** The skill drafts; it writes the profile —
  and every later delta — only after explicit PM approval (draft → approve → push,
  `raftkit-core/write-protocol`). Every other skill only ever READS the profile.
- **Only named sources.** Ingest exactly the sources the PM names — never reach for
  a source they did not ask for.

## Every fact carries a tag and a citation

| Tag | Meaning |
|---|---|
| ✅ Confirmed | Stated unambiguously in a source, and cited to it |
| ⚠️ Partial | Implied, incomplete, or single-source-thin — the default for anything not clearly confirmed |
| ❓ Missing | Explicitly absent — a gap to name, never a guess |

The full profile structure (fact · tag · citation · date), the profile home, and
the success-summary format are in `references/profile-format.md`.

## Inputs

1. **At least one source** the PM names — a PRD, SOW, master doc, email thread, or
   meeting recording, reachable through the Cowork connectors (Google Drive, Gmail,
   Fathom, Asana).
2. **Where the profile lives** — its home is an open decision, so the PM points at
   it; see the parameterized home in `references/profile-format.md`. Never hardcode
   a location.

**Empty state — no sources named.** Stop with this exact message, and create
nothing:

```
I need at least one source — a PRD, SOW, master doc, email thread, or meeting recording.
```

## Run flow

1. **Confirm the sources and the profile home.** No source named → the Empty state
   above. Detect whether a profile already exists at the named home: none →
   first-run build; one exists → a delta re-run (step 5).

2. **Ingest the named sources, reporting progress.** Read each source through its
   connector, announcing progress per source ("read 3 of 5 sources"). The source
   set is bounded by what fits a single run's context; when the named set will not
   fit, say so and split the ingestion into batches. See
   `references/ingestion-and-deltas.md`.

3. **Handle an unreadable source without dropping it silently.** If a source cannot
   be read (connector down, no access, missing file), name the **exact source** and
   the **access that is missing**, continue ingesting the readable sources, and list
   the skipped ones in the result. Never silently drop a source.

4. **Draft the profile — tagged, cited, conflicts surfaced.** Turn the ingested
   material into facts, each with exactly one tag (✅/⚠️/❓) and a citation (❓
   facts cite the gap — see `references/profile-format.md`); untagged facts default
   to ⚠️ Partial. Where sources disagree, surface
   the conflict with both citations for the PM to resolve — never resolve it here.

5. **On a re-run, propose a delta — not a rewrite.** When a profile already exists
   and the PM adds a source, compute the change against the current profile and
   present it as a delta (changed / new / now-confirmed facts), leaving every
   untouched fact intact. See `references/ingestion-and-deltas.md`.

6. **Draft in chat, write only after approval.** Show the drafted profile (or
   delta) and name the exact profile home it lands on; wait for explicit PM
   approval (silence is not approval), then write it — applying the Asana HTML rules
   if the home is an Asana resource (`raftkit-core/write-protocol`).

7. **Report and offer the next step.** Summarize with the exact success-count shape
   defined in `references/profile-format.md`, then **offer to run
   story-skill-generator** for the project. Offer only; generating the skill is that
   skill's job, not this one.

## Guardrails

- **Read-only on every source.** Sources are read, never modified; the only write
  is the profile, and only after approval.
- **Out of scope:** generating stories ([`user-story`](../user-story/SKILL.md)) or
  skills ([`story-skill-generator`](../story-skill-generator/SKILL.md)) — this skill
  only *offers* the hand-off; resolving conflicts on the PM's behalf; and ingesting
  any source the PM did not name.
- **Escalate to founders** (`raftkit-core/house-rules`) on budget, contracts,
  relationship risk, or anything that reads as a client commitment.

## Reference files

- **`references/profile-format.md`** — the Project Profile structure (fact · tag ·
  citation · date), the ✅/⚠️/❓ tag legend and the default-to-⚠️ rule, the
  parameterized profile home (open decision + recommended default), and the
  success-summary format.
- **`references/ingestion-and-deltas.md`** — reading sources across the connectors,
  per-source progress and the per-run context bound, the unreadable-source error
  behaviour, conflict surfacing with both citations, and the delta re-run rules
  (changed / new / now-confirmed vs. a rewrite).
