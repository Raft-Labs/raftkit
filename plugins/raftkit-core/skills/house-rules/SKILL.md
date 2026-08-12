---
name: house-rules
description: This skill should be used whenever a RaftKit skill needs the shared, non-negotiable rules of how RaftLabs works — where project facts live, the Asana free-tier constraints, where human approval gates sit, when to escalate to founders (budget, contracts, relationship risk, client commitments), the find-skills governance for adopting new skills, and how to handle a source or destination on any access path (connector, uploaded file, synced local folder, pasted link). Consult it before storing anything project-specific, using any Asana feature beyond the free tier, producing an estimate or anything that could read as a client commitment, adopting a new skill, or deciding how to read an upload, a synced file, or a pasted link.
user-invocable: false
---

# RaftKit House Rules

These are the rules every RaftKit role plugin inherits. They are authored once here so a change updates every role's behaviour at the source, with no per-plugin drift.

## Non-negotiables

- **Templates are read live, never cached.** Every template comes from Asana at run time by GID. The repo holds zero cached template text. See [workflow-constants](../workflow-constants/SKILL.md) for the GIDs and the live-fetch protocol.
- **Project facts live in Project Profiles, never in plugins.** Plugins stay project-independent. Anything specific to one client or codebase belongs in that project's profile, not in a skill.
- **Sources and destinations are access-path-agnostic.** A named source or output home may arrive via a connector (Google Drive, Gmail, Fathom, Asana), a file uploaded into the conversation, a file in a synced local folder (e.g. Google Drive for Desktop, where a Drive doc is a local file), or a pasted link. Accept whichever path the session provides — never insist on one. Every gate, citation rule, and approval applies identically on every path. Cite an upload as "uploaded file, as-of \<date\>" — it carries no live URL.
- **Asana free tier only.** Nothing a skill creates may rely on paid features: no dependencies, custom fields, milestones, start dates, or approval tasks. Express relationships between tasks as links in the description instead.
- **Human gates everywhere.** Skills draft; humans approve. The gates are: story approval, plan approval, PR merge, and bug close. No skill advances past a gate on its own, and only the one exception enumerated below writes anything automatically. For the mechanics of outward writes, see [write-protocol](../write-protocol/SKILL.md).
- **Work is matched to the cheapest model that can do it, and the human does the switching.** Protocol 1 asks that model capacity be matched to task difficulty; this is how a skill acts on that. Read the tiers live from [governance-protocols](../governance-protocols/references/protocols.md), never from a copy here, and work out the lowest tier that can do the work. Then **stop and ask, rather than mentioning it in passing**: when the session is running a more expensive model than the work needs, name the cheaper tier and the exact command to switch, per Protocol 1's efficiency warning, and **wait for an answer — silence is not one, and the work does not start without it.** The human either switches and says to continue, or says to proceed on the current model; either way it is their call on the record. When the right tier is genuinely unclear, ask that instead — name the choice you are between. Never quietly run expensive work you could have flagged as cheap, and never treat having mentioned it as having asked.

  **What a skill does not do:** select a model programmatically. No RaftKit skill picks a model on its own, for itself or for a subagent it dispatches — it recommends, and the human switches. Whether Protocol 1's mid-session sentence leaves room for a skill to dispatch a subagent on a tier a human approved in advance is an **open question for Ashit**, recorded under [governance-protocols](../governance-protocols/SKILL.md). Until he rules, recommend-and-prompt is the whole of this rule; nothing in RaftKit relies on the other reading.

## How skills talk to humans

Every line a human reads — a status, a refusal, a success report, a question —
is short, plain, and ends on the next action or decision. House terms
(`Gate 0`, `scope contract`, `[AC]`, and the rest) stay — they are shared
vocabulary — but each gets a one-line gloss the first time a run's output uses
it. The full rules, the banned-phrase list, the house glossary, and the
`output`-fence convention that makes this checkable are in
[references/plain-language.md](references/plain-language.md).

## The one automatic-write exception

The four gates above — story approval, plan approval, PR merge, bug close —
are unchanged and still human-only. Exactly one RaftKit mechanism writes
without a per-write human approval, and it does not advance a gate. It is
enumerated here and mirrored in
[write-protocol](../write-protocol/SKILL.md):

1. **`pr-auto-review` Critical-fix commits (CI layer).** `raftkit-dev`'s
   `pr-auto-review` skill adds Critical-fix commits on a PR branch as
   intermediate, non-gate-advancing writes: a Critical-fix commit does not
   complete the PR-merge gate, does not close a bug, and does not advance any
   of the four named gates on its own — it only prepares evidence (the commit
   itself, plus the PR comment) for the human who still owns the PR-merge
   gate. See `write-protocol`'s entry for this skill for the exact
   commit-level boundary (Critical-only, one commit per fix, auto-reverted on
   a red check, never a merge).

Blocker telemetry used to be a second exception, filing issues on this repo's
tracker. It no longer writes anywhere outward: blockers are reported to the
admin dashboard as ordinary telemetry and triaged there. The exception was
removed rather than narrowed — see Telemetry and blocker capture below.

A future skill tempted to read the entry above as license to add its own
auto-write may not — a second exception needs its own named amendment to this
list, not an inference from this one.

## Escalate to founders

Some decisions are above any skill's or PM's authority. When work touches **budget, contracts, relationship risk, or a client commitment**, surface it to the founders — never absorb it, never decide it inside the skill, never imply a commitment on RaftLabs' behalf.

### The estimation approval chain

No skill sends an estimate to a client. An estimate reaches one only along this chain, and every review link on it is a person:

**AI estimate → vetted by the developer who will build it → approved by Nirav or Ashit → only then shared with the client.**

Each link exists for a reason. The developer who will build the thing is the person best placed to say whether the number is real, and no amount of PM seniority substitutes for that vetting. A senior PM may catch a bad number by instinct; a junior PM has no reason to doubt it, and a wrong number in front of a client can cost the deal. Founder approval is the last gate before the client, because sharing a number *is* a client commitment, and that authority sits with founders per the rule above.

Estimation output is the recurring case: it always carries the watermark **"Requires founder review — not a client commitment."** so an estimate is never mistaken for a promise. The watermark says the number is not a commitment; the chain says who is allowed to make it one.

The point is that these decisions carry consequences a skill cannot weigh — a number that reads as a quote, or a scope note that reads as a contract change, can bind the company. Routing them to founders keeps that authority where it belongs.

## Telemetry and blocker capture

RaftKit measures its own use, so the team can see who has adopted it and where people get stuck. This runs in Claude Code as plugin hooks under `raftkit-core/hooks/`, never as skill behaviour — no skill needs to do anything to participate.

Events go to RaftLabs' own admin API — never a third-party analytics processor.

**What is collected:** the developer's git name and email, GitHub login and OS user; which skills run; when a skill hard-stops, and which refusal it emitted; plugin and platform versions; **every prompt the developer submits**, captured in full; and **every failed tool call** — the tool's name and its error output. The prompt attached to a blocker report is not a separate capture: it is that session's most recent prompt, already collected under the every-prompt rule. Repository identity is sent as **`owner/repo`** together with the full branch name, so a blocker can be traced to the project it happened in. (It was previously hashed; that was reversed deliberately — without it the dashboard cannot tell one project's failures from another's.) The remote is normalized to `owner/repo` rather than sent raw, which drops any credential embedded in an HTTPS remote by construction.

**What the scrubber does and does not do.** All free text — prompts and tool errors alike — passes through a credential scrubber before it is spooled. Be precise about its scope, because the difference matters to how the resulting data must be handled:

- It removes **credentials**: API keys and provider tokens, `Authorization` headers, private key blocks, JWTs, connection-string passwords, and secret-looking `key=value` assignments. Best-effort over known shapes, not a guarantee.
- It removes **no PII whatsoever**, by design. Client and company names, customer emails and phone numbers, addresses, pasted database rows, ticket contents and file paths all reach the endpoint verbatim. That project detail is the signal the telemetry exists to collect, so filtering it would defeat the purpose.

The consequence is the operative rule: **the telemetry store holds client-identifying content and must be treated as such** — access-controlled, never re-exported, and never copied into a public surface. That last point is why nothing derived from a captured prompt is ever published to a public surface at all, full stop: the tooling repo is public, and "credentials scrubbed" was never the same claim as "safe to publish".

**Opt out** with `RAFTKIT_TELEMETRY=off` (or `DO_NOT_TRACK=1`) in the environment. A one-time notice discloses collection on first run.

**Blockers go to the dashboard, not to a tracker.** When a skill hard-stops,
the refusal is reported as a `raftkit_blocked` telemetry event and appears in
the admin dashboard with a triage status. Nothing is filed, commented, or
reopened on any Git host, so `write-protocol`'s "no skill ever auto-files"
holds without an exception for this.

That is deliberate, and the reason is exposure. `scrub()` removes credentials
only — it is explicitly not a PII filter, so a captured refusal line or prompt
can carry client project detail. An issue tracker is the wrong place for that:
it notifies, it is searchable, it is reachable by every integration wired into
the repo, and `Raft-Labs/raftkit` is a public repository. The dashboard is
behind authentication and is the only surface that sees this data.

## find-skills governance

New skills are adopted deliberately, never silently. When a skill gap appears and find-skills surfaces a candidate:

1. **Suggest** the candidate with its provenance — source, install count, and audit status.
2. **Human approves** the choice.
3. **Install** only after that approval.

Provenance is required before anything the skill produces can touch client code: prefer an official source or one with a strong track record (on the order of 1,000+ installs) and passing audits. Unvetted code in a client's repo is a supply-chain risk RaftLabs does not take on a skill's say-so.
