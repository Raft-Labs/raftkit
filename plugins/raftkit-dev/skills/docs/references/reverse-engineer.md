# Reverse engineering — evidence over invention

For a repository with real code and no living docs (or docs with unexplained
gaps), reverse-engineer what the docs should say — without ever laundering a
guess into a product fact.

## The three marks

Every reverse-engineered statement carries exactly one:

- **confirmed** — directly evidenced by code the reader can be pointed at
  (name the file/behavior that proves it).
- **inferred** — a reasonable reading of the evidence that could be wrong;
  stated as inference with its basis.
- **unknown** — the code cannot answer it (intent, policy, product tone,
  compliance posture). Unknowns stay visibly unknown until a human answers.

Inference is never persisted as product fact: promotion from inferred to
confirmed happens only when a human confirms it or code evidence closes the
gap.

## The read-only rule

Reverse engineering is analysis. Until the developer approves a change plan
(which docs to create/update, in which discovered or proposed convention),
nothing is written. The output of the analysis is the proposal.

## Interview scope

Ask the developer only what repository evidence cannot establish — intent,
policy, product decisions. Never re-ask what the handoff already answers
(story, Profile, spec) and never ask questions a file read would answer.

## Method — the full code-first flow

1. **Static audit** — infer the stack/archetype and modifiers from repository
   signals; flag instruction-file drift.
2. **Foundation reads** — entry points, routes, schema, workflows, configs.
3. **Module grouping proposal** — group what the code actually contains
   (URL prefixes, package layout); the developer confirms the grouping.
4. **Per-module walk, run code-first** — the same 20+1-step decomposition as
   design mode, but inferred from code first; the interview covers only the
   gaps code cannot answer (intent, role policy, edge-case policy, telemetry
   wishes). Every statement carries its mark. Parallel readers may be used
   for breadth; their outputs are evidence to compose, not text to paste.
5. **Cross-cuts inferred** — async, webhooks, observability, compliance
   posture, from the code that implements them.
6. **Reconciliation report** — code-but-no-doc and doc-but-no-code lists,
   presented before anything is generated.
7. **Approval, then generation** — the approved docs are generated in the
   discovered (or approved-proposed) convention with frontmatter
   `Status: Implemented`, inferred-vs-confirmed markers intact.
8. **Initial history entry** — an initial changes-log entry (or the
   convention's equivalent) records the code-state snapshot, the generation
   date, and the stated limitations.
9. **Handoff** — normal change tracking owns every subsequent edit.

Never document dead code, never over-document, never fabricate edge cases.
