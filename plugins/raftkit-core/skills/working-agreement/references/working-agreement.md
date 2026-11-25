## RaftLabs working agreement for AI-assisted delivery

1. **Right-size the model.** Haiku for renames, moves, fixtures, log parsing. Sonnet for components, tests, single-file refactors, ordinary debugging. The strongest model for cross-layer design and distributed-state bugs. A skill sets each dispatched agent's model, the reviewer on Sonnet by default, and reports the run's token total. The session model is the developer's choice; nobody is prompted to switch mid-run.
2. **Small phases.** A phase is one acceptance criterion's slice, built in the main thread and tested on its own. Any per-phase file limit is an open founder decision.
3. **Plan visible before code.** The plan (scope from the acceptance criteria, phases with files and tier, tests) is written to `docs/specs/<branch>.md` and shown in chat before code starts. A record, not a stop; the developer interrupts if it is wrong.
4. **Green baseline first.** Typecheck, plus build where it is a separate compile, runs before the first edit. Red means fix the baseline before touching feature code.
5. **Tests from acceptance criteria.** Each criterion becomes a failing test before its implementation.
6. **Verify after.** Inline simplify, then one spec-aware review and the scripts (lint, typecheck, suite, scope, docs) run together before a PR is drafted. Findings are fixed or answered in the PR description.
7. **No runaway loops.** Three failed fixes of the same error stop the run, whoever builds; the developer decides.
8. **One stop.** The only mandatory approval in a run is before something leaves the session: a PR opened, an Asana or Sheet write, a message sent. Merge is always human.
9. **Incidents first.** A production trace (Sentry, CloudWatch, Crashlytics) halts feature work: reproduce as a failing test, fix, verify, prepare the PR. Structural causes become a follow-up story. Ask for recent logs before calling a deployment stable. Never deploy from a session.
10. **Session hygiene.** One session per feature. Run `/context` when a session feels slow.
