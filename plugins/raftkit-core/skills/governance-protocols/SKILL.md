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

## Parameters (single source of truth)

Two values are parameters, not hardcodes. Edit them **here and only here** — the protocol and orchestrator payloads carry these exact defaults, so this table is the one place a change is made.

| Parameter | Default | Where it appears in the payload |
| --- | --- | --- |
| `decomposition_threshold` | `2` | Protocol 2 ("more than 2 files") |
| `spec_path` | `docs/specs/active-feature.md` | orchestrator Step 0 + the ❌ ORCHESTRATION REJECTED string |

Defaults are the source-doc values. The decision to change them — per-story spec files keyed to the branch, and a pilot-tuned threshold — is Asana task `1216550892331152`, still awaiting Ashit's sign-off. Until it lands, the defaults stand; when it lands, change the values here and re-run setup-project.

## How it's consumed

setup-project (M3, out of scope here) reads these four files and installs each to its target above. The installer, the CI workflow, the pre-push hook, and the CodeRabbit gate that the protocols reference are all M3 — they are **not** in this pack. This skill only supplies the content.

## Verbatim discipline

The protocol bodies and all four exact strings — ⚠️ EFFICIENCY WARNING, ❌ ORCHESTRATION REJECTED, ⚠️ SUBAGENT LOOP WARNING, and the 📊 Session Health Check nudge — are copied verbatim from the source doc (Asana task `1216375937893602`). This is the deliverable: versioned, faithful content. It is distinct from the live-read Asana templates that [house-rules](../house-rules/SKILL.md) forbids caching — those are workflow templates fetched live; this is the governance text this story exists to freeze.

Amending protocol *substance* is out of scope: content changes go through Ashit as a PR to this file set. The pack installs whole — all five protocols or none.
