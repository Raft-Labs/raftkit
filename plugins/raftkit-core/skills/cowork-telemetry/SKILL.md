---
name: cowork-telemetry
description: This skill should be used by any RaftKit skill that can run in Cowork, and whenever someone asks how RaftKit measures usage outside Claude Code, why a skill announces itself, or how to opt out of Cowork telemetry. It defines the one line every skill says when it starts, which is the only signal Cowork gives that a skill ran at all. Consult it before adding a skill to raftkit-pm or raftkit-qa, and before changing how any skill opens its first reply.
user-invocable: false
---

# Cowork Telemetry

RaftKit measures its own use so the team can see who has adopted it and where
people get stuck. In Claude Code that is entirely automatic — plugin hooks
under `raftkit-core/hooks/` do it, and no skill does anything to take part
([house-rules](../house-rules/SKILL.md)).

Cowork cannot work that way, and this skill is the whole of the difference.

## Why a skill has to do anything at all

Cowork sessions run in a sandbox with no host filesystem and no hooks, so
`record.mjs` and `flush.mjs` never execute. What Cowork does have is a
first-party OpenTelemetry export an admin turns on once, which reports prompts,
tool failures and errors with no help from any skill.

It does not report skills. Cowork emits no event when a skill runs — no tool
result, no prompt — because a skill is expanded internally as a prompt. That is
[a known gap](https://github.com/anthropics/claude-code/issues/41845), closed as
not planned, so it is the shape of the world rather than a bug to wait out.

The only trace a skill leaves in Cowork is what it says. So that is the signal.

## The contract

**A skill's first line names the skill it is.**

```output
Using raftkit-pm:brainstorm to turn this idea into a spec doc.
```

The shape that matters is `Using <plugin>:<skill>` — plugin, colon, skill name
— somewhere in the skill's **first reply** after it takes over. Everything
around it is ordinary prose and can say whatever the skill needs.

Say it once per run, not once per reply.

## When something else has to come first

Some skills lead with output that is load-bearing on its own: `estimation`
opens with the founder-review watermark, and several skills answer an empty
state with a message that has to be reproduced word for word. Those win.

- **A required opening line stays the opening line.** The announcement goes
  immediately after it, in the same reply.
- **An exact message stays exact.** "This exact message" constrains the message,
  not the whole reply — the announcement may precede or follow it, and must not
  be edited into it.
- **A hard stop still announces.** A skill that refuses is a skill that ran, and
  a refusal nobody can attribute is the single most useful row the dashboard
  can be missing.

The rule is that the announcement appears, not that it wins a fight over
position. Nothing here loosens a skill's own output contract.

## Why this is a good line regardless

It is not a tax paid for measurement. A person who asked a question and got a
different-shaped answer than usual deserves to know which skill picked it up,
and RaftKit skills change the shape of a reply a lot. The line earns its place
on its own; telemetry is the second reason for it, not the first.

That is also why it is plain text a human reads rather than a marker hidden in
a comment. A tool that measures people should not measure them invisibly.

## What this does and does not change

- **It does not write anything.** The line is a reply in a conversation, not an
  outward write. Nothing here goes near the draft → approve → push gate in
  [write-protocol](../write-protocol/SKILL.md), and this is not an exception to
  it.
- **It does not send anything.** The skill says a line. Cowork's exporter — set
  up once by an admin, off until then — is what leaves the machine.
- **It is Cowork's answer only.** Claude Code still reports through hooks, and
  the announcement is ignored there. Never add a second reporting path to a
  skill.
- **It is the only skill behaviour telemetry may ask for.** No skill calls an
  endpoint, writes a spool file, or reports anything itself. A future need for
  more than one line needs its own decision, not an extension of this one.

## Disclosure and opting out

`RAFTKIT_TELEMETRY=off` is a Claude Code mechanism — it sets an environment
variable the hooks read, and there are no hooks in Cowork. Be accurate about
that rather than implying an opt-out that does nothing:

- **The admin switch is the real one.** Cowork telemetry exists only while an
  admin has an OTLP endpoint configured. Unset it and nothing is exported from
  any session, for anyone.
- **Content capture is a separate switch.** With it off, prompts and responses
  arrive redacted — which also means no skill usage is recorded, since the
  announcement is inside a response.
- **A person who wants no record of a specific session** can run it in Claude
  Code with `RAFTKIT_TELEMETRY=off`, or ask an admin. There is no per-session
  switch inside Cowork, and pretending otherwise would be worse than saying so.

What reaches the dashboard from Cowork: the signed-in email, session and prompt
identifiers, prompt text, tool failures, which skill ran, and which refusal a
hard-stop emitted. **Assistant responses are read for the announcement and for
refusals, then dropped** — they are never stored. The same handling rule applies
as to every other RaftKit telemetry: the store holds client-identifying content
and is treated as such.

## Guardrails

- **Plain English out** — every line a human reads follows `raftkit-core/house-rules`' plain-language rules; a house term gets its one-line gloss on first use.
- **Never fake the line.** Announcing a skill that did not run puts a false row
  in the dashboard. If a skill declines to handle something, it says so instead.
- **Never let the line replace the work.** It is one line, then the actual
  first question or action.
