---
name: deprecation-sweep
description: This skill should be used when a RaftLabs PM wants a scheduled sweep that catches third-party service notices before they cost money — e.g. "set up the deprecation sweep", "watch for service deprecation alerts", "sweep my inbox and Slack for AWS notices", "how do we stop missing end-of-support emails". It interviews the PM, fills in a ready-to-paste routine prompt that reads Asana, Slack, and email twice daily and reports anything needing attention — deprecations, end-of-support dates, forced migrations, price changes, expiries. The routine is read-only; it creates nothing anywhere.
user-invocable: true
---

# Deprecation sweep — a scheduled watch on service notices

A **routine** is a prompt Claude runs on a schedule with nobody watching. This one
exists because notices arrive with long lead times and still get missed: an AWS
notice forwarded by a client one day before its deadline, and a Postgres
end-of-support that cost $150/month in extended-support fees before anyone
noticed (field notes: Asana task `1217123743893926`). While a project is being
actively developed, upgrades happen naturally; once development stops, nobody is
looking. The sweep is the looking.

This packages **step 3 of Ashit's process** — the scheduled sweep. Steps 1–2
(one shared Gmail per project for all third-party signups, imported into the
PM's inbox) are a process change above PM authority and an **open founder
question on Asana task `1217123743893926`**. Until that lands, the sweep sees
only the inboxes and channels the PM's own account can read — say so at
handover. Step 4 (forwarding to a client with a quote offer) stays a human act
on a flag, never the routine's.

## Read-only by design

The routine reads and reports. It **creates nothing, edits nothing, files
nothing** — no Asana tasks, no Slack messages, no emails, no docs. Its entire
output is its own run report, which the PM reads like an inbox. That is what
keeps it inside `raftkit-core/write-protocol`'s draft → approve → push rule
with **no new exception needed**: a routine that never writes needs no write
approval. Do not "improve" it into filing tasks — that turns it into an
unattended writer and puts it in front of the founders' unattended-write
decision (see `meeting-decisions/references/scheduled-routine.md`).

## What to ask before handing anything over

Three questions, then fill the blanks yourself.

1. **Which surfaces?** The Asana projects and Slack channels the sweep should
   read. Read exact project and channel names back from Asana and Slack rather
   than accepting what the PM types. Email needs no blank: the routine reads
   whatever inbox its own account can reach — say so, so the PM knows which
   account to schedule it under.
2. **Which projects are no longer maintained by RaftLabs?** Flags on those get
   the forward-to-client suggestion; flags on active projects get the
   fix-it-here suggestion.
3. **When?** Twice daily per the process — morning and post-lunch. Ask for the
   two times rather than assuming a timezone.

## The routine rules

The same delivery rules as the meeting-notes routine apply, adapted:

- **Cloud, not local** — `Code → Routines → Cloud`, blank environment. A local
  schedule only runs while that machine is on. Confirm Asana, Slack, and Gmail
  are connected for the account the routine runs under; interactive
  authorisation does not always carry over to a scheduled run.
- **Don't hand-write the prompt** — start from the prompt below, or describe it
  to `Create with Claude`. Hand-written prompts drift.
- **Every run stands alone** — the report says what it found this run; it never
  edits or appends to anything from an earlier run.

## The prompt

Fill the four ALL-CAPS blanks before handover, and read the prompt through to
confirm no `<...>` placeholder is left in it.

```text
Read, do not write. Create nothing, edit nothing, send nothing, file nothing —
in Asana, Slack, email, or anywhere else. Your only output is this run's report.

Sweep these three surfaces for anything needing attention:
  - Asana: the projects <ASANA PROJECT NAMES>
  - Slack: the channels <SLACK CHANNEL NAMES>
  - Email: the inbox this account can read

You are looking for third-party service notices: deprecations and end-of-support
or end-of-life dates, forced or recommended migrations, API-version sunsets,
price and plan changes, expiring certificates, domains, or credentials, and
security notices marked action-required. A vendor email that reads as routine
marketing is not a flag; a date with a consequence is.

For each flag report:
  - what the notice says, in one line
  - the deadline it names, and how far away that is
  - the source, cited exactly: email subject and date, Slack message link, or
    Asana task link — never a paraphrase without the source
  - which project it belongs to, if that is identifiable
  - the suggested next step:
      <ACTIVELY MAINTAINED PROJECTS>    -> "schedule the upgrade in this project"
      <NOT-MAINTAINED PROJECT NAMES>    -> "forward to the client — 'you may have
                                           missed this' — and offer a quote if
                                           they want it done"
  - anything touching budget, pricing, contracts, or a commitment to a client:
    label it FOUNDER REVIEW in capitals. Never present it as decided.

If a surface is unreachable, say which one and continue with the others. If a
sweep finds nothing, say exactly that — an empty report is a good report, and
you never invent a flag to have something to show.
```

## Guardrails

- **Read-only is the contract.** The moment a report suggests the routine
  should act on a flag itself, the answer is no — acting is the PM's, and
  anything commercial is the founders' (`raftkit-core/house-rules`).
- **Never guess a deadline or a project.** A flag without a source citation is
  left out; a notice whose project is unclear is reported as unassigned.
- **Plain English out** — every line a human reads follows
  `raftkit-core/house-rules`' plain-language rules; a house term gets its
  one-line gloss on first use.

## When it stops working

- **Nothing ran** → the routine was created as Local, not Cloud. Rebuild under
  `Code → Routines → Cloud`.
- **A surface always comes back unreachable** → that connector is not
  authorised for scheduled runs; reconnect it on the account the routine runs
  under.
- **Flags appear with no citation, or flags you can't verify** → the citation
  rule was dropped from the prompt. Restore it.
- **The report starts creating tasks "to be helpful"** → the read-only opening
  line was dropped. Restore it before the next run.
