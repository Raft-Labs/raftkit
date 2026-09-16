## RaftLabs working agreement for AI-assisted delivery

1. **Right-size the model.** Haiku for renames, moves, fixtures, log parsing. Sonnet for components, tests, single-file refactors, ordinary debugging. The strongest model for cross-layer design and distributed-state bugs. A skill sets the model for each subagent it dispatches, reviewers on Sonnet by default, and reports the run's token total. The session model is the developer's choice; nobody is prompted to switch mid-run.
2. **Small phases.** Phases compile and test in isolation, at most two files each. A subagent whose brief is larger returns a scope-reduction request; the parent re-splits.
3. **Plan visible before code.** The plan (scope from the acceptance criteria, phases with files and tier, tests) is written to `docs/specs/<branch>.md` and shown in chat before code starts. A record, not a stop; the developer interrupts if it is wrong.
4. **Green baseline first.** Build and typecheck run before the first edit. Red means fix the baseline before touching feature code.
5. **Tests from acceptance criteria.** Each criterion becomes a failing test before its implementation.
6. **Verify after.** Simplify, then lint, the full suite and one parallel review pass (design, silent failures, tests, security, scope, docs) run before a PR is drafted. Findings are fixed or answered in the PR description.
7. **No runaway loops.** A subagent that fails to fix the same error three times stops and reports; the developer decides.
8. **One stop.** The only mandatory approval in a run is before something leaves the session: a PR opened, an Asana or Sheet write, a message sent. Merge is always human.
9. **Incidents first.** A production trace (Sentry, CloudWatch, Crashlytics) halts feature work: reproduce as a failing test, fix, verify, prepare the PR. Structural causes become a follow-up story. Ask for recent logs before calling a deployment stable. Never deploy from a session.
10. **Session hygiene.** One session per feature. Run `/context` when a session feels slow.
