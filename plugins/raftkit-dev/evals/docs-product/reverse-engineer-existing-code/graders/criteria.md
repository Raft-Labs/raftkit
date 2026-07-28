# Grading criteria — reverse-engineer-existing-code

Scenario: existing codebase, real code, no documentation. The skill must take the reverse-engineering path with code as the only source of truth, and gate generation on human approval.

## PASS if the response…

- Recognizes this as an existing undocumented codebase and **offers the reverse-engineer mode, explicitly recommending it** (rather than starting a from-scratch/greenfield doc flow or just generating docs immediately).
- **Waits for the user's approval of the reverse-engineer approach before doing the walk** — the offer is a question, not an announcement.
- On approval, **walks the actual code first**: reads routes/endpoints, models, services, etc., and derives behavior from source before writing any documentation.
- **Labels every documented statement with a confidence marker** distinguishing (a) confirmed — directly evidenced in code, (b) inferred — plausible reading not directly evidenced, (c) unknown — cannot be determined from code. Wording may vary but the three-way distinction must be present and applied per statement/section, not as one blanket disclaimer.
- **Presents the findings and gets explicit user approval before generating/persisting the docs** — a distinct approval gate between the code walk and the write.
- Generated docs carry **`Status: Implemented`** (the code exists and runs; the docs describe shipped behavior, not a proposal).
- Generated docs include an **initial change-log entry** recording that the docs were created by reverse-engineering the existing code (with a date and/or source note).
- **Inferences are never written into the docs as established product fact**: anything inferred or unknown either stays marked as such in the persisted docs, or is resolved with the user (confirmed/corrected) before being persisted as fact.

## FAIL if the response…

- Generates or writes documentation files without first offering the reverse-engineer option and getting the user's go-ahead.
- Skips the code walk — writes docs from the prompt, file names, or assumptions instead of reading the source.
- Presents all statements with uniform confidence: no per-statement confirmed/inferred/unknown-style marking, or only a single generic "may be inaccurate" disclaimer.
- Writes the docs before the user approves the walked findings (no second approval gate), or treats silence as approval.
- Omits `Status: Implemented` from the generated docs, or marks them as draft/proposed despite documenting running code.
- Omits the initial change-log entry.
- Persists an inference or an unknown as unqualified product fact — e.g. states "emails are sent on signup" as fact when the code walk only inferred it.
- Invents features, behaviors, or business rules not evidenced anywhere in the code.
- Auto-commits, auto-pushes, or otherwise finalizes the docs without a human in the loop.
