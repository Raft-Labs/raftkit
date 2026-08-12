---
name: governance-protocols
description: This skill should be used whenever RaftLabs' AI governance & efficiency protocols (Ashit's protocols 1–5), the active-feature spec template, or the team cheat sheet are needed as installable core content. It is the source M3 · setup-project reads to inject the pack into a repo's CLAUDE.md / .claude/skills, and the single place to confirm the exact governance warning strings or the decomposition-threshold / spec-path parameter defaults.
user-invocable: false
---

# RaftKit Governance Protocols Pack

Ashit's five AI governance & efficiency protocols — model triage, task decomposition, pre-flight gates, cost monitoring, and production-alert resolution — packaged once here as versioned core content, plus the active-feature spec template and the team cheat sheet.

They are authored once in raftkit-core so a single edit updates every RaftLabs repo at the source. Unpackaged, each repo copies the protocol doc and drifts — the exact failure RaftKit exists to prevent. M3 · setup-project installs the pack per repo from the files in `references/`; this skill is the source those files come from.

## What's in the pack

| File | Installs to | Contains |
| --- | --- | --- |
| [references/protocols.md](references/protocols.md) | client repo `CLAUDE.md` | Protocols 1–5 |
| [references/orchestrator.md](references/orchestrator.md) | client repo `.claude/skills/orchestrator.md` | Protocol 2's mechanism: spec gate, decomposition table, subagent loop protection |
| [references/active-feature-template.md](references/active-feature-template.md) | client repo `docs/specs/` | the active-feature spec template the spec gate checks for |
| [references/cheat-sheet.md](references/cheat-sheet.md) | team workspace (pinned) | the 5-point Claude Code cheat sheet |

Payload verbatim — clean to inject; all meta lives here in SKILL.md.

## Parameters (canonical reference)

Two values are parameters, not incidental hardcodes. This table is their canonical reference — the one place that records what they are and their current values. Because the payload ships **verbatim**, each value is also baked into the files at the locations named below, so changing a parameter means updating it **here and at each payload location listed**, then re-running setup-project. (Keep them in lockstep — a value changed here but not in the payload is the drift this pack exists to prevent.)

| Parameter | Default | Where it appears in the payload |
| --- | --- | --- |
| `decomposition_threshold` | `2` | Protocol 2 ("more than 2 files") |
| `spec_path` | `docs/specs/active-feature.md` | orchestrator Step 0 + the ❌ ORCHESTRATION REJECTED string |

Defaults are the source-doc values. The decision to change them — per-story spec files keyed to the branch, and a pilot-tuned threshold — is Asana task `1216550892331152`, still awaiting Ashit's sign-off. Until it lands, the defaults stand; when it lands, update the value here and in each payload location above, then re-run setup-project.

## How it's consumed

setup-project (M3, out of scope here) reads these four files and installs each to its target above. The installer, the CI workflow, the pre-push hook, and the CodeRabbit gate that the protocols reference are all M3 — they are **not** in this pack. This skill only supplies the content.

## Verbatim discipline

The protocol bodies and all four exact strings — ⚠️ EFFICIENCY WARNING, ❌ ORCHESTRATION REJECTED, ⚠️ SUBAGENT LOOP WARNING, and the 📊 Session Health Check nudge — are copied verbatim from the source doc (Asana task `1216375937893602`). This is the deliverable: versioned, faithful content. It is distinct from the live-read Asana templates that [house-rules](../house-rules/SKILL.md) forbids caching — those are workflow templates fetched live; this is the governance text this story exists to freeze.

Amending protocol *substance* is out of scope: content changes go through Ashit as a PR to this file set. The pack installs whole — all five protocols or none.

## Open question for Ashit — does Protocol 1 reach dispatched subagents?

Recorded here because it affects shipped behaviour and only Ashit can settle it. This note asks a question; it does not answer one, and nothing in the payload has been edited or reinterpreted.

Protocol 1 says a model cannot be switched programmatically mid-session, so the user or parent session must be prompted when an override is needed.

**What RaftKit does today — nothing that needs this question answered.** No skill selects a model programmatically. `raftkit-dev:implement` records a recommended tier per phase in its Gate 1 table, and where a phase's tier is cheaper than the session's current model it **stops before that phase and waits** — naming the tier and the exact switch command, treating silence as no answer, and proceeding only as the developer directs. `house-rules` requires the same of any skill: work out the cheapest capable tier, then stop and ask rather than mention it in passing. That is Protocol 1's own instruction — prompt the user when an override is needed — and it stands whichever way the question below is answered.

**The question:** does Protocol 1's sentence leave room for a skill to *dispatch* a subagent on a tier a human approved in advance, or does it rule that out along with mid-session switching? An earlier version of this branch made `implement`'s Gate 1 column bind at dispatch, which needed the permissive reading. That was removed rather than shipped on an unapproved interpretation — the column is a recommendation again.

**Owner:** Ashit, by PR to this file set. Raised on Asana task `1216383018361190`. Until he rules: the payload ships exactly as written, no skill selects a model programmatically, and the binding stays out. If he confirms the permissive reading, the Gate 1 binding can land as a follow-up.

## Guardrails

- **Plain English out** — every line a human reads follows `raftkit-core/house-rules`' plain-language rules; a house term gets its one-line gloss on first use.
