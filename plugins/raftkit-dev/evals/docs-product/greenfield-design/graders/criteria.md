# Grader criteria — greenfield co-authoring design flow

Score the transcript against the docs skill's co-authoring design contract.

## PASS if the response…

- **States the mode up front**: explicitly announces it is entering greenfield / co-authoring design mode (empty repo, nothing to reverse-engineer) before asking anything.
- **Asks exactly ONE question at a time**: every assistant turn in the interview poses a single adaptive question, then waits. Never a numbered list of questions in one turn.
- **Is recommendation-first**: each question comes with the skill's recommended answer AND a "don't pick this if…" caveat explaining when the recommendation is wrong.
- **Pushes back on vagueness**: when the developer gives a vague or hand-wavy answer (e.g. "whatever you think", "just make it work"), the skill does not silently accept it — it narrows the question, offers concrete options, or challenges the answer until it gets a decidable one.
- **Walks the phases in order**: classification of the product → business/domain questions → stack selection → auth & RBAC → module inventory → per-module deep-dive loop → cross-cutting concerns → final confirmation.
- **Produces an RBAC matrix**: the auth/RBAC phase yields an explicit role × permission matrix (table), not prose.
- **Builds a module inventory** before diving into any single module, and gets the developer to agree to the list.
- **Runs the per-module loop with mutual agreement**: each module is worked through the skill's full per-module step sequence (the 20-step design walk plus its final agreement step), and the skill obtains explicit developer sign-off on a module before moving to the next one.
- **Covers cross-cutting concerns** after modules (e.g. error handling, logging, notifications, background jobs — whatever the skill's cross-cut list specifies).
- **Ends with a confirmation gate**: summarizes the agreed design and asks for explicit approval before writing anything.
- **Writes NOTHING before sign-off**: no files created, no Write/Edit tool calls producing docs or code, until the human has explicitly confirmed the final design.

## FAIL if the response…

- Writes any file (docs, scaffolding, code, README) before the human's explicit final sign-off.
- Asks multiple questions in a single turn during the interview, or dumps a questionnaire.
- Gives questions without a recommendation, or recommendations without a "don't pick this if" caveat.
- Accepts a vague answer ("you decide", "whatever's standard") without pushback at least once when one occurs.
- Skips or reorders required phases (e.g. jumps to stack before classifying the product, or starts a module deep-dive with no agreed module inventory).
- Handles auth/RBAC in prose only, with no explicit role-permission matrix.
- Moves to the next module without explicit agreement on the current one, or truncates the per-module step sequence.
- Omits cross-cutting concerns entirely.
- Skips the final confirmation and proceeds straight to writing output.
- Designs the whole system unilaterally in one long answer instead of interviewing the developer.
