---
name: cowork-telemetry
description: How RaftKit records skill usage in Cowork, where no hook runs — the one line a skill says to name itself, once per run, and why RAFTKIT_TELEMETRY=off does nothing there. Read before adding or reshaping a pm or qa skill's first reply, or when asked why a skill announces itself.
user-invocable: false
---

# Cowork Telemetry

RaftKit measures its own use so the team can see who has adopted it and where
people get stuck. In Claude Code that is automatic — the hooks under
`raftkit-core/hooks/` do all of it, and no skill takes part
([rules](../rules/SKILL.md)).

Cowork cannot work that way, and this skill is the whole of the difference.

## Why a skill has to do anything at all

A Cowork session runs in a sandbox with no host filesystem and no hooks, so
`record.mjs` and `flush.mjs` never run. Cowork has its own OpenTelemetry export
instead, which an admin turns on once and which reports prompts, tool failures
and errors without help from any skill.

It does not report skills. Cowork emits no event when a skill runs, because a
skill is expanded internally as a prompt —
[a known gap](https://github.com/anthropics/claude-code/issues/41845), closed as
not planned, so it is the shape of the world rather than a bug to wait out.

The only trace a skill leaves in Cowork is what it says. So that is the signal.

## The contract

**A skill names itself in its first reply.**

```output
Using raftkit-pm:story to turn this into a user story.
```

What matters is the shape `Using <plugin>:<skill>` somewhere in the skill's
first reply after it takes over. The prose around it is ordinary and can say
whatever the skill needs. Say it once per run, not once per reply.

## When something else has to come first

Some skills open with output that is load-bearing on its own. `estimate` leads
with the founder-review watermark, and several skills answer an empty state
with a message reproduced word for word. Those win.

- **A required opening line stays the opening line.** The announcement follows
  it, in the same reply.
- **An exact message stays exact.** "This exact message" constrains the
  message, not the whole reply. The announcement may come before or after it,
  and is never edited into it.
- **A hard stop still announces.** A skill that refuses is a skill that ran,
  and a refusal nobody can attribute is the most useful row the dashboard can
  be missing.

The rule is that the announcement appears, not that it wins a fight over
position. Nothing here loosens a skill's own output contract.

## What this does and does not change

- **It does not write anything.** The line is conversation text — no task, PR
  or Sheet changes because a skill said it. Outward writes stay where
  `raftkit-core:rules` puts them, and this grants no exception.
- **It does not send anything.** The skill says a line. Cowork's exporter, set
  up once by an admin and off until then, is what leaves the machine.
- **It is Cowork's answer only.** Claude Code still reports through hooks and
  ignores the announcement. Never add a second reporting path to a skill.
- **It is the only skill behaviour telemetry may ask for.** No skill calls an
  endpoint, spools a file, or reports anything itself. Needing more than one
  line needs its own decision, not an extension of this one.

## Disclosure and opting out

`RAFTKIT_TELEMETRY=off` sets an environment variable the hooks read, and there
are no hooks in Cowork, so it does nothing there. Say that plainly rather than
implying an opt-out that silently fails.

- **The admin switch is the real one.** Cowork telemetry exists only while an
  admin has an OTLP endpoint configured. Unset it and nothing is exported, for
  anyone.
- **Content capture is a separate switch.** With it off, prompts and responses
  arrive redacted, which also means no skill usage is recorded — the
  announcement lives inside a response.
- **Someone who wants no record of one session** can run it in Claude Code with
  `RAFTKIT_TELEMETRY=off`, or ask an admin. There is no per-session switch
  inside Cowork, and pretending otherwise would be worse than saying so.

What reaches the dashboard from Cowork — the signed-in email, session and
prompt identifiers, prompt text, tool failures, which skill ran, and which
refusal a hard stop emitted. **Assistant responses are read for the
announcement and for refusals, then dropped.** They are never stored. The store
holds client-identifying content and is handled as such, exactly as the Claude
Code path already is.

## Guardrails

- **Never fake the line.** Announcing a skill that did not run puts a false row
  in the dashboard. A skill that declines to handle something says so instead.
- **Never let the line replace the work.** One line, then the actual first
  question or action.
