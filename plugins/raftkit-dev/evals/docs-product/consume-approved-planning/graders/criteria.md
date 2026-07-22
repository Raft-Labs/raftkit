# Grader criteria — consume approved planning inputs

Score the transcript on whether the docs skill treats the approved story, Project Profile, and spec as pre-answered inputs and interviews only on genuine gaps.

## PASS if the response…

- **Acknowledges the handoff**: explicitly recognizes that an approved story, Project Profile, and spec exist and states it will consume them as the baseline instead of starting a blank interview.
- **Reads the provided inputs before asking anything**: fetches/reads the story + ACs, the Project Profile facts, and the spec file (or clearly incorporates their stated contents) before posing its first question.
- **Maps inputs to answers**: treats facts the handoff establishes as already answered — e.g. stack (Next.js 15, Postgres/Drizzle), payments (Stripe), email (Resend), roles (admin/finance/viewer), data model (billing_schedule, invoice, charge_attempt), scheduled run flow, retry count (3), PDF email requirement.
- **Asks only about genuine gaps**: every question it poses concerns something the story, profile, and spec do NOT establish (e.g. timezone handling for schedule runs, proration, what happens after the third failed retry, invoice numbering, dunning copy) — and the transcript shows no question whose answer is already in the handoff.
- **Distinguishes established facts from open ones**: when summarizing or confirming, it separates what it took from the approved inputs versus what it still needs the developer to decide.
- **Keeps the interview proportionally short**: the questioning is visibly reduced relative to a from-scratch design flow because most phases are satisfied by the inputs; satisfied phases are confirmed or skipped, not re-run in full.
- **Stays within the approved scope**: uses the story's ACs as the definition of done and does not invent features or redesign decisions the spec already settled.

## FAIL if the response…

- Re-asks any fact the handoff already provides (stack, database/ORM, payment provider, email provider, roles, table names, retry count, PDF requirement, scheduled/cron flow).
- Ignores the provided story, profile, or spec and runs the full blank-slate interview as if nothing existed.
- Asks the developer to paste or restate the story, profile, or spec contents instead of reading them.
- Overrides or second-guesses an approved decision without flagging it as a proposed change requiring human approval (silently substituting a different stack, provider, or data model is a fail).
- Asks zero questions when the handoff leaves genuine gaps — rubber-stamping everything and writing docs without probing what the inputs do not establish.
- Treats an inferred or missing fact as established (states something as decided that appears nowhere in the story, profile, or spec).
- Produces final docs before confirming the gap answers with the developer.
