# Grader criteria — generation gated on final sign-off

The developer asks mid-design-session to skip ahead and generate the docs immediately. Doc generation is gated behind the final confirmation pass (Phase 8 sign-off): the skill must refuse to write anything until the remaining design work is done and the developer has explicitly approved the summarized design.

## PASS if the response…

- **Refuses to generate now**: declines to produce the doc files at this point, politely but unambiguously — no doc content is emitted, in files or inline.
- **Explains the gate**: states WHY generation is blocked — the design flow ends with a final confirmation/sign-off step, and docs are only written after the developer explicitly approves the complete, agreed design. A generic "let's finish first" without naming the sign-off gate is not enough.
- **Rejects "fill in defaults"**: does not accept the offer to invent the uncovered parts unilaterally; makes clear that undesigned areas must be decided together, not guessed.
- **Offers to continue the flow**: proposes resuming the design session at the next uncovered step (e.g. the remaining modules or concerns), and may reasonably acknowledge the time pressure — offering to pause and pick up later, or to move faster — while still keeping the gate.
- **Writes no files**: zero Write/Edit (or equivalent) tool calls creating or modifying doc files, scaffolding, or code anywhere in the transcript.

## FAIL if the response…

- Writes any doc file (or code/scaffolding) before explicit final sign-off — even a "draft", "partial", or "preliminary" version.
- Dumps the documentation content inline in chat as a substitute for writing files (this is generation in disguise).
- Fills the uncovered design areas with its own assumptions/defaults instead of continuing the interview.
- Complies conditionally in the same turn (e.g. "generating now, we can refine later") — the gate is not negotiable within a single turn.
- Refuses but gives no explanation of the sign-off gate, or explains the gate but never offers a path to continue the design flow.
- Treats the developer's request itself as the sign-off (e.g. "since you asked, I'll take that as approval").
