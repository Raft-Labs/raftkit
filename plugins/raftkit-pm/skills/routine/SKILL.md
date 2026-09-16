---
name: routine
description: Hand a PM a filled-in prompt for a scheduled cloud routine — "set up the meeting notes routine", "automate the MOM for this project", "set up the deprecation sweep". Asks the setup questions in one message, fills every blank from live names, hands over the prompt and setup steps. Never creates, schedules or runs a routine.
user-invocable: true
---

# routine

Two routines, one handover shape. `raftkit-core:rules` apply. This skill writes nothing and has no stop: its output is a prompt the PM pastes into Routines.

| Routine | What it does each run | Prompt |
|---|---|---|
| meeting notes | finds the latest recording of a recurring call and creates a notes task and an action-items task with assigned subtasks | `references/meeting-notes-prompt.md` |
| deprecation sweep | reads Asana, Slack and email for third-party deprecation, end-of-life, price and security notices and reports them; creates nothing | `references/deprecation-sweep-prompt.md` |

## Run

1. **Ask everything at once.** Meeting notes: which Asana project, which recording, who chases items owned by people outside the workspace, and any existing title convention (many boards use `MOM- DD/MM/YYYY`). Deprecation sweep: which Asana projects and Slack channels, which projects RaftLabs no longer maintains, and the two run times with timezone.
2. **Fill the blanks from live names, never typed ones**: the exact project name read back from Asana, the recording name from Fathom (pick a stable fragment: the client or project name, not the whole title, never a link), channel names from Slack, the fallback assignee resolved to exactly one workspace member.
3. **Read the prompt through** and confirm no `<ALL-CAPS>` placeholder remains. Lowercase placeholders are the routine's to fill each run.
4. **Hand over** the prompt with the setup steps and the rules below.

## Setup steps and rules

- **Cloud, not local**: `Code → Routines → Cloud`, blank environment; a local schedule stops when the laptop closes. In Cowork, confirm the routines surface exists.
- **Connectors** must be connected for the account the routine runs under; interactive authorisation does not always carry over.
- **Do not hand-write the prompt**; hand-written ones drift.
- **Every run stands alone**: new tasks, never an edit to an earlier run's.
- A routine runs with no RaftKit plugins loaded; nothing here can watch it afterwards.

**The meeting-notes routine must not be switched on until the founders record the unattended-write decision.** It writes Asana tasks with nobody approving the draft, which the rules do not allow today. The two ways to settle it are the founders' call: a narrow named exception for machine-generated, review-pending tasks on boards no client account can reach, or a routine that drafts and stops. Say this at handover. The deprecation sweep reads only, so it needs no decision. Once a routine covers a call, do not also run `raftkit-pm:meeting` on it.

## When it stops working

Nothing ran → created as Local. No recording found → the event was renamed; re-read the name from Fathom. Thin notes → restore the full-transcript line. An earlier task changed → restore the create-only line. Everything unassigned or a surface unreachable → reconnect that connector. Flags without citations, or tasks being created → restore the citation and read-only lines.
