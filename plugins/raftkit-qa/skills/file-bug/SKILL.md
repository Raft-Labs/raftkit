---
name: file-bug
description: This skill should be used when a RaftLabs QA engineer wants to file, draft, log, or report a bug into Asana — e.g. "file a bug", "log this Jam recording as a bug", "raise a defect for this failing step", "create a bug report". Reads the live Bugs Template from Asana as the format authority, pre-fills environment, steps, and actual result from a Jam recording (console and network errors quoted verbatim), asks QA for the judgment fields, and creates the bug as a subtask under the target story's Bugs subtask only after QA approves the draft.
user-invocable: true
---

# file-bug

File a bug report that fills itself from a Jam recording into the house Bugs
Template, so developers get a reproduce-first-time report and QA stops typing
environment blocks by hand. The bug lands as a subtask under the target story's
`Bugs` subtask, tagged with the project's priority tag — traceability is
automatic. One bug per ticket.

Jam is the ⭐ evidence tier because it auto-captures console, network, and the
exact steps; this skill wires that tier in as the default (PRD §5.4).

## The one rule that governs everything

Two halves, both non-negotiable:

1. **The live Bugs Template is the only format authority.** Read it live every
   run (see run flow step 1); never work from a remembered or repo-cached shape.
2. **Draft → approve → push.** No bug is ever filed without QA's explicit
   approval of the draft — per `raftkit-core/write-protocol`. The skill drafts;
   QA approves; only then does anything reach Asana.

And never fabricate: Jam evidence is quoted **verbatim**, never paraphrased. When
a required input is missing, stop and ask — naming exactly what is missing.

## Preconditions — gather before drafting anything

1. **A target story.** A bug always attaches to a story (the definition-of-done
   trace). If no target story is given → **stop and ask**; never file a
   free-floating bug (Empty state).
2. **Evidence.** A Jam recording link is the default (⭐ tier). If there is no
   Jam, a lower tier is accepted — marked as such, with the manual environment
   block required (see `references/jam-evidence.md`).

## Run flow

1. **Resolve constants and fetch the live template.** Get the workspace GID and
   the Bugs Template GID from `raftkit-core/workflow-constants`, then fetch that
   template task live via the Asana connector — every run, never from memory or
   this repo. It is the format authority for this run: its section structure,
   field labels, severity/priority scales, and evidence-tier names all come from
   this fetch. If it cannot be read, stop with the exact `workflow-constants`
   message; do not fall back to a remembered format.
2. **Confirm the target story.** No target story given → stop and ask; a bug is
   never filed free-floating.
3. **Extract evidence.**
   - **Jam present:** pull device/browser → Environment; user events → Steps;
     console + failed network requests → Actual Result, quoted verbatim. Draft
     the summary, type, and feature/module from the same context as pre-fill
     proposals for QA to confirm. Stream
     what was found ("n console errors, m failed requests"). If the Jam captured
     no errors, proceed with steps/video only and say so. Invalid link / no
     access → name which and the fix; do not invent device or console data. See
     `references/jam-evidence.md`.
   - **No Jam:** accept the lower evidence tier, **mark the tier** in the
     Evidence section, and require QA to fill the manual environment block the
     template demands.
4. **Split multi-defect recordings.** One recording covering unrelated issues
   becomes separate drafts and separate tickets — one bug per ticket (see
   `references/filing-rules.md`).
5. **Ask the judgment fields, axis by axis.** Severity and Priority are different
   axes and are asked separately; odd-but-legal combinations are confirmed with
   QA, not blocked. Expected Result and the "Done when" acceptance criteria come
   from QA. See `references/filing-rules.md`.
6. **Assemble and self-check.** Build the draft to the live template's shape,
   apply the title format, and run the pre-submit checklist — every item must
   pass before a push is offered (see `references/filing-rules.md`).
7. **Draft → approve → push.** Show the full draft and name the exact target (a
   new subtask under the story's `Bugs` subtask). On approval, create the bug
   subtask and apply the project's priority tag, resolved at run time (see
   Guardrails). Apply the Asana HTML rules from `raftkit-core/write-protocol`; if
   the push is rejected, fix the HTML per those rules, **retry once**, then
   surface the API error.
8. **Confirm back:** the bug link plus a one-line summary — "filed under [story] ·
   Bugs, tier ⭐, checklist complete."

## Guardrails

- **Evidence verbatim.** Console and network error text is pasted exactly as
  captured; paraphrasing loses the string a developer greps for.
- **Template read live, not cached.** The template's section structure, field
  labels, and scales come from the live fetch every run — never from this repo —
  so a change in Asana takes effect the same day with no plugin release. The
  enforcement rules this skill applies (the title pattern and the pre-submit
  checklist) are the story's acceptance criteria, not a copy of the template body.
- **Project-independent.** Resolve the priority tag at run time from the target
  story's project (or ask QA); never hardcode a project-specific tag name. If the
  project has no matching priority tag, **ask QA — do not create one silently**
  (project facts live in Project Profiles, never in this plugin).
- **Asana free tier** per `raftkit-core/house-rules`: no dependencies, custom
  fields, milestones, start dates, or approval tasks; the priority tag is
  free-tier and story-mandated. Express relationships as task links.
- **Escalate to founders** per `raftkit-core/house-rules` if a bug implies a
  scope, contract, or client-relationship risk beyond the defect itself.

## Out of scope

- **Fixing** the bug — that is `raftkit-dev`'s `fix-bug` (M3).
- **Retesting** a fix — that is the `retest` skill (M4).
- **Editing the Bugs Template itself** — it is read-only format authority here.

## Reference files

- `references/jam-evidence.md` — Jam → template field mapping, the verbatim rule,
  evidence tiers, and the no-Jam fallback.
- `references/filing-rules.md` — title format, the severity-vs-priority axes, the
  pre-submit checklist, one-bug-per-ticket, and Asana placement.
