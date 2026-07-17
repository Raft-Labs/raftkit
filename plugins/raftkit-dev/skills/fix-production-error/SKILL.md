---
name: fix-production-error
description: This skill should be used when a RaftLabs developer pastes a production stack trace or error log — from Sentry, AWS CloudWatch, or Crashlytics — and needs it resolved with incident discipline, e.g. "fix this production error", "here's a Sentry trace", "CloudWatch is alerting", "prod is crash-looping", or a raw stack trace dropped into the session. It halts all feature work, traces the exact failing line by wrapping superpowers systematic-debugging, writes a failing regression test replicating the crash BEFORE any fix, drives the fix to green with the full suite verified, and prepares the PR — it only suggests deploy steps and never deploys. It is Protocol 5 made executable. NOT for ordinary bugs (a QA bug task, a defect with no production trace) — those go file-bug → fix-bug, and this skill refuses that misuse by name.
user-invocable: true
---

# fix-production-error

A production stack trace outranks everything. When Sentry / CloudWatch / Crashlytics
says real users are breaking, this skill hijacks the session with a disciplined
**trace → red → green** loop: the crash becomes a permanent failing regression
test *before* any fix exists, the fix is driven to green with the whole suite
verified, and the PR is prepared for a human to deploy per the release train. The
skill prepares; it never deploys.

This is governance **Protocol 5** made executable (PRD §5.3). It wraps
`superpowers/systematic-debugging` for the diagnosis and reuses the `scope-guard`
and `simplify` siblings for the loop — it rebuilds none of them.

## The one rule that governs everything

**A stack trace outranks everything, and red comes before green.** Two halves,
both non-negotiable:

1. **Incident supremacy.** A pasted production trace halts *all* feature work in
   the session immediately. Nothing else proceeds until the incident is resolved
   or explicitly handed off. Severity is assumed **S1 until triage says
   otherwise**, and only **one incident is handled per run**.
2. **Red-first, permanent.** A failing regression test that replicates the exact
   crash conditions is written and seen to fail **before any fix is written**, and
   it **stays in the suite permanently** so the crash can never regress silently.
   No red test → no fix.

The mechanical loop is in `references/incident-loop.md`.

## Preconditions — pass every gate before tracing

These are the front gates. Any failed gate stops the run with the stated ask or
refusal — the skill never guesses its way past one. Full wording and the routing
are in `references/triage-and-refusal.md`.

1. **A raw trace is present.** No trace pasted → ask for the **raw stack trace or
   log excerpt**. Never proceed on a verbal description of the crash alone.
2. **This is a production incident, not an ordinary bug.** A defect with no
   production trace — a QA bug task, a reproduction someone typed up — is **refused
   and routed to `file-bug` → `fix-bug`**, stating the exact reason. This skill is
   not a shortcut around the ordinary bug loop.
3. **The trace localizes.** A trace that does not point to a line (minified frames,
   missing context) → ask for the **specific missing artifact by name** (sourcemap,
   request ID, log window) instead of guessing at a fix.

## Run flow

Read **Protocol 5 live** from `raftkit-core/governance-protocols` at the start of
every run — never cache its text. Then:

1. **Halt feature work.** State that the session is now an incident; feature work
   is suspended until resolved or handed off (the one rule, above).
2. **Trace the exact failing line/path.** Wrap `superpowers/systematic-debugging`
   — find the precise line raising the exception or unhandled rejection. If tracing
   stalls, drop to the ambiguous-trace gate and ask for the named artifact rather
   than guessing (`references/triage-and-refusal.md`).
3. **Write the failing regression test first.** Encode the exact crash conditions
   as a test, run it, and **confirm it fails red** before touching any fix. If the
   crash cannot be replicated in a test, say **exactly what is missing** and ask —
   do not fabricate a fix (`references/incident-loop.md`).
4. **Fix to green — containment, not refactor.** Implement the smallest fix that
   turns the red test green. If the root cause is systemic, ship a **containment
   fix + the regression test** and draft a **follow-up task proposal** for the
   structural work — never refactor architecture under incident pressure
   (`references/triage-and-refusal.md`).
5. **Verify the full suite.** Run the whole suite. A fix that turns any *other*
   test red is a **hard stop** — fix that before proceeding; the incident is not
   resolved while the suite is red (`references/incident-loop.md`).
6. **Prepare — do not deploy.** Prepare the branch/PR — via the `raftkit-dev/pr`
   sibling when present, falling back to the shared PR conventions when it is
   absent — and **suggest** deploy steps only. End with the exact success line:
   `Crash replicated red → fixed green. Regression test permanent. PR #n ready — deploy per the train.`
   Deploy stays human + release-train governed.

## Guardrails

- **A trace outranks everything** — feature work halts on a pasted trace and does
  not resume until the incident is resolved or handed off; one incident per run;
  S1 until triage.
- **Red before green, permanently** — the regression test replicating the crash
  precedes the fix, is seen to fail, and stays in the suite for good.
- **No trace, no proceed** — never act on a verbal description; ask for the raw
  trace or log excerpt.
- **Ambiguous trace asks, never guesses** — request the specific artifact
  (sourcemap, request ID, log window) by name.
- **Refuse the misuse** — an ordinary bug (no production trace) is routed to
  `file-bug` → `fix-bug` with the reason stated; this skill is not a bypass.
- **Fix scope = the crash** — opportunistic changes are scope-guard violations;
  hand the diff to `raftkit-dev/scope-guard`. Behaviour-preserving cleanup is
  `raftkit-dev/simplify`, separately.
- **Containment over refactor** — a systemic root cause ships containment + a
  drafted follow-up proposal (`raftkit-core/write-protocol`, human-approved, never
  auto-filed); no incident-time architecture refactor.
- **Never deploys** — the skill prepares and suggests; deploy is a human,
  release-train-governed step.
- **Escalate to founders** per `raftkit-core/house-rules` if the incident implies
  contract, client-commitment, or relationship risk beyond the crash itself.

## Out of scope

- **Wiring the alerting** — connecting Sentry / CloudWatch / Slack is infra and
  release-train rollout, not this skill; it consumes a pasted trace, it does not
  configure the pipeline.
- **The ordinary bug flow** — a defect with no production trace goes `file-bug` →
  `fix-bug`; this skill refuses it.
- **Deploying** — preparation and suggested steps only; the release train deploys.

## Reference files

- `references/incident-loop.md` — the trace → red → green loop in detail: halting
  feature work, wrapping systematic-debugging, the red-first regression test and
  the can't-replicate stop, the full-suite verification and the hard-stop on a
  broken test, the scope-guard hand-off, and the exact success line + deploy
  hand-off.
- `references/triage-and-refusal.md` — the front gates and the exact wording: the
  empty-trace ask, the ambiguous-trace artifact-by-name ask, the ordinary-bug
  misuse refusal and its `file-bug` → `fix-bug` routing, and the systemic
  root-cause containment + follow-up-proposal path.
