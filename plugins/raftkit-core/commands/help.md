---
description: How to use raftkit-core — the shared rules every RaftKit plugin runs on, and where to find the role plugins
argument-hint: [skill name or question]
---

# raftkit-core help

The user ran `/raftkit-core:help $ARGUMENTS`. You are the guide to **raftkit-core** — the shared foundation every RaftKit role plugin depends on.

**If `$ARGUMENTS` names a skill or asks a question:** answer that specifically. Read `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/SKILL.md` (and its `references/`) as the authority — never answer about a skill from memory alone.

**Otherwise, present the overview below.** First list the directories in `${CLAUDE_PLUGIN_ROOT}/skills/` and reconcile: if a skill exists that isn't in this table (or one listed here is gone), say so and describe it from its SKILL.md — the installed skills are the source of truth, not this page.

## What this plugin is

raftkit-core carries no day-to-day workflow of its own — it is the rulebook the other plugins consult. It installs automatically with any role plugin. You'd invoke its content directly when you need to check a rule, fetch a workflow constant, or quote a governance string exactly.

## Skills

| Skill | What it holds | A human uses it when |
| --- | --- | --- |
| `house-rules` | Where project facts live (Project Profiles, never plugins), Asana free-tier constraints, human approval gates, founder-escalation triggers, find-skills governance | "What's the rule on estimates?" / "Can I use Asana dependencies?" |
| `workflow-constants` | The Asana workspace GID, Feature + Bugs Template GIDs, subtask naming conventions — the single source; templates are always fetched LIVE | "What's the story template GID?" / "How do I fetch the live template?" |
| `write-protocol` | The draft → approve → push gate for every outward write (Asana, Drive docs, files, client-facing), plus Asana's rich-text HTML rules | "Why won't my html_notes push?" / before any skill writes anywhere |
| `governance-protocols` | Ashit's protocols 1–5 (model triage, decomposition, pre-flight gates, cost hygiene, production alerts), the spec template, the team cheat sheet — the pack `raftkit-dev:setup-project` installs per repo | "What's the exact efficiency warning string?" / "What's the decomposition threshold default?" |
| `asana-formatting` | How RaftKit renders content for Asana — per-surface tag matrix, markdown-to-Asana-HTML rules, object-reference syntax, read-before-write and read-back verification | Not user-invocable — consulted automatically by write-protocol and every skill that writes to Asana |

## The three rules everyone hits eventually

1. **Draft → approve → push.** No skill makes an outward write — Asana, a Drive doc, a file, anything client-facing — without explicit human approval of the exact content.
2. **Live templates, never cached.** Story and bug formats come from the live Asana template tasks at run time; editing the template updates every project instantly.
3. **Free-tier Asana only.** No dependencies, custom fields, milestones, or start dates — relationships are task links in descriptions.

## Your role plugin

Day-to-day work lives in the role plugins: `/raftkit-pm:help` (stories, profiles, updates, estimates) · `/raftkit-dev:help` (implement → PR, bugs, setup) · `/raftkit-qa:help` (suites, run sheets, bugs, retest).

Close by pointing them at their role plugin's help unless their question was about a core rule.
