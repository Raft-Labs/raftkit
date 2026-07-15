---
name: house-rules
description: This skill should be used whenever a RaftKit skill needs the shared, non-negotiable rules of how RaftLabs works — where project facts live, the Asana free-tier constraints, where human approval gates sit, when to escalate to founders (budget, contracts, relationship risk, client commitments), and the find-skills governance for adopting new skills. Consult it before storing anything project-specific, using any Asana feature beyond the free tier, producing an estimate or anything that could read as a client commitment, or adopting a new skill.
user-invocable: false
---

# RaftKit House Rules

These are the rules every RaftKit role plugin inherits. They are authored once here so a change updates every role's behaviour at the source, with no per-plugin drift.

## Non-negotiables

- **Templates are read live, never cached.** Every template comes from Asana at run time by GID. The repo holds zero cached template text. See [workflow-constants](../workflow-constants/SKILL.md) for the GIDs and the live-fetch protocol.
- **Project facts live in Project Profiles, never in plugins.** Plugins stay project-independent. Anything specific to one client or codebase belongs in that project's profile, not in a skill.
- **Asana free tier only.** Nothing a skill creates may rely on paid features: no dependencies, custom fields, milestones, start dates, or approval tasks. Express relationships between tasks as links in the description instead.
- **Human gates everywhere.** Skills draft; humans approve. The gates are: story approval, plan approval, PR merge, and bug close. No skill advances past a gate on its own. For the mechanics of outward writes, see [write-protocol](../write-protocol/SKILL.md).

## Escalate to founders

Some decisions are above any skill's or PM's authority. When work touches **budget, contracts, relationship risk, or a client commitment**, surface it to the founders — never absorb it, never decide it inside the skill, never imply a commitment on RaftLabs' behalf.

Estimation output is the recurring case: it always carries the watermark **"Requires founder review — not a client commitment."** so an estimate is never mistaken for a promise.

The point is that these decisions carry consequences a skill cannot weigh — a number that reads as a quote, or a scope note that reads as a contract change, can bind the company. Routing them to founders keeps that authority where it belongs.

## find-skills governance

New skills are adopted deliberately, never silently. When a skill gap appears and find-skills surfaces a candidate:

1. **Suggest** the candidate with its provenance — source, install count, and audit status.
2. **Human approves** the choice.
3. **Install** only after that approval.

Provenance is required before anything the skill produces can touch client code: prefer an official source or one with a strong track record (on the order of 1,000+ installs) and passing audits. Unvetted code in a client's repo is a supply-chain risk RaftLabs does not take on a skill's say-so.
