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

## Method

Read the code the docs would describe — entry points, routes, schema,
workflows — compose evidence before proposing structure, and propose the docs
organization that matches the repo's own shape (or its existing convention if
one is discovered). Parallel readers may be used for breadth; their outputs are
evidence to compose, not text to paste.
