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
- **Human gates everywhere.** Skills draft; humans approve. The gates are: story approval, plan approval, PR merge, and bug close. No skill advances past a gate on its own. For the mechanics of outward writes, see [write-protocol](../write-protocol/SKILL.md).

## Escalate to founders

Some decisions are above any skill's or PM's authority. When work touches **budget, contracts, relationship risk, or a client commitment**, surface it to the founders — never absorb it, never decide it inside the skill, never imply a commitment on RaftLabs' behalf.

Estimation output is the recurring case: it always carries the watermark **"Requires founder review — not a client commitment."** so an estimate is never mistaken for a promise.

The point is that these decisions carry consequences a skill cannot weigh — a number that reads as a quote, or a scope note that reads as a contract change, can bind the company. Routing them to founders keeps that authority where it belongs.

## Telemetry and blocker capture

RaftKit measures its own use, so the team can see who has adopted it and where people get stuck. This runs in Claude Code as plugin hooks under `raftkit-core/hooks/`, never as skill behaviour — no skill needs to do anything to participate.

Events go to RaftLabs' own admin API — never a third-party analytics processor.

**What is collected:** the developer's git name and email, GitHub login and OS user; which skills run; when a skill hard-stops, and which refusal it emitted; plugin and platform versions; **every prompt the developer submits**, captured in full; and **every failed tool call** — the tool's name and its error output. The prompt attached to a blocker report is not a separate capture: it is that session's most recent prompt, already collected under the every-prompt rule. Repository identity is a **hash** of the origin remote and only the branch **prefix** is kept, so client repo and branch names never leave the machine. All free text — prompts and tool errors alike — passes through a credential scrubber first; the scrubber removes credentials, not project detail, so captured text can still carry client context.

**Opt out** with `RAFTKIT_TELEMETRY=off` (or `DO_NOT_TRACK=1`) in the environment. A one-time notice discloses collection on first run.

**The auto-file carve-out.** [write-protocol](../write-protocol/SKILL.md) states that no skill ever auto-files. Blocker capture is the one deliberate exception, and it is narrow:

- It applies **only** to RaftKit's own failure reports landing on RaftLabs' own tooling repo.
- It never touches a client-facing surface. Asana, client docs, PRs, and every other outward write remain fully gated by draft → approve → push.
- It is a mechanical report of a stop RaftKit itself produced — not work performed on a client's behalf, which is the thing the gate exists to protect.
- It makes exactly **three** automatic writes to that repo, all through the `gh` CLI: it **creates** a deduplicated issue for a blocker never seen before, **comments** a "+1 occurrence" note on the matching existing issue, and **reopens** that issue when the blocker recurs after someone closed it. The reopen is the one to know about — a closed issue is a human triage decision, and a recurrence overrides it with no one in the loop.
- The limits are the ones the code actually enforces: at most **3 issues per session** (`max_issues_per_session`), `info`-severity stops are **never** filed, repeat occurrences of a known problem collapse onto the one issue by fingerprint, and nothing is written at all when telemetry is opted out, when `file_issues` is off, or when `gh` is absent or unauthenticated.

The rule's purpose is that an automated write which turns out wrong is visible to a client before anyone can catch it. A deduplicated issue on an internal repo carries none of that risk, and gating it would defeat the point — a developer mid-task declines, and the blocker is lost. That trade is the reason for the exception, and it does not generalise to anything else.

## find-skills governance

New skills are adopted deliberately, never silently. When a skill gap appears and find-skills surfaces a candidate:

1. **Suggest** the candidate with its provenance — source, install count, and audit status.
2. **Human approves** the choice.
3. **Install** only after that approval.

Provenance is required before anything the skill produces can touch client code: prefer an official source or one with a strong track record (on the order of 1,000+ installs) and passing audits. Unvetted code in a client's repo is a supply-chain risk RaftLabs does not take on a skill's say-so.
