# Triage and refusal — the front gates

Before the incident loop (`references/incident-loop.md`) runs, three gates decide
whether there is a real, localizable production incident to work. Each failed gate
stops with a stated ask or refusal — the skill never guesses its way past one. A
fourth path handles a systemic root cause discovered mid-loop.

## Empty — no trace pasted

A production incident starts from a **raw artifact**, never from a description.

- **Trigger:** the developer describes a crash ("checkout is throwing", "users
  are hitting a 500") **and claims it is a live production / live-users incident**,
  but pastes no stack trace or log.
- **Action:** ask for the **raw stack trace or the log excerpt** — from Sentry,
  CloudWatch, or Crashlytics — and stop until it arrives.
- **Never:** proceed on the verbal description alone. A described crash is a
  hypothesis, not a trace; acting on it fabricates the failing line.
- **Tiebreaker (Empty vs Misuse):** this gate and the Misuse gate below both look
  like "a crash described, no trace pasted." The discriminator is the **production
  claim**, and the branch is deterministic on it: if the description asserts a
  production / live-users incident, take **this** path — ask for the raw artifact.
  If there is **no production claim at all** (a QA bug task, a typed-up repro, "can
  you also fix…"), take the **Misuse** path instead.

## Ambiguous — the trace does not localize

A trace that cannot be traced to a line is not yet workable.

- **Trigger:** minified or symbol-less frames, a stack with no source context, a
  trace missing the request/session that reproduces it — tracing in the loop
  stalls (`references/incident-loop.md` step 2).
- **Action:** ask for the **specific missing artifact by name** — the
  **sourcemap** for minified frames, the **request ID** to pull the full context,
  the **log window** around the event — whichever the gap calls for.
- **Never:** guess at a fix to a crash you cannot localize. Name the artifact and
  wait for it.

## Misuse — an ordinary bug, not a production incident

This skill is the production feedback loop, not a shortcut around the ordinary bug
flow. It refuses that misuse by name.

- **Trigger:** a defect with **no production claim and no production trace** — a
  QA bug task, a manually written reproduction, a "can you also fix…" with no
  Sentry/CloudWatch/Crashlytics artifact behind it. (If a production incident *is*
  claimed but the trace is merely missing, that is the **Empty** gate above, not
  this one — see its tiebreaker.)
- **Action:** **refuse and route**, stating the reason: an ordinary bug goes
  through **`fix-bug`** — which takes it with a filed bug task or straight from the
  dev's own report, so this routing never leaves them stuck — not through the
  incident loop. The incident
  loop's red-first, feature-halting discipline is for real production breakage;
  applying it to an ordinary bug both misprioritizes the bug and cheapens the
  incident path.
- **Never:** run the incident loop to jump an ordinary bug ahead of the queue.

## Systemic root cause — containment, not incident-time refactor

Discovered inside the loop (`references/incident-loop.md` step 4), not a front
gate, but it lives here because it is a discipline decision, not a mechanical one.

- **Trigger:** the diagnosis concludes the true fix is structural — the crash is a
  symptom of an architecture problem, not a single wrong line.
- **Action:** ship the **containment fix + the regression test** that stops the
  user-facing breakage now, and **draft a follow-up task proposal** for the
  structural work: a board proposal (a new task or a comment on the story) drafted
  for **human approval per `raftkit-core/write-protocol`** — draft → approve →
  file. It is never auto-filed.
- **Never:** refactor architecture under incident pressure. Incident time is for
  containment; the structural fix is deliberate, reviewed work that follows. The
  same discipline covers documentation: a runbook/known-failure update ships in
  the incident only when its scope requires it — everything broader goes into
  the drafted follow-up proposal.
