# Setting up the scheduled meeting-notes routine

A **routine** is a prompt Claude runs on a schedule with nobody watching. Point one
at a recurring client call and every call turns into notes and assigned follow-ups
without a PM remembering to do anything.

This file exists because every PM who built one from scratch hit the same four
failures, and a fifth nobody diagnosed — the field notes are on Asana task
`1217124109784176`. The prompt below is the version that works. Hand it over filled
in; do not ask a PM to write their own.

Setting the routine up is the PM's own click-through — RaftKit supplies the prompt
and the values, nothing more. Once handed over, this skill has no further part in it.
As configured today a routine runs with no RaftKit plugins available, so nothing here
can observe or correct it afterwards. The org-wide install path is an open decision
(Asana task `1216551001583573`); revisit this section if that lands.

The routine covers the notes task and the action-items task only. The Project Profile
delta stays with Gate A of an interactive run, because that write needs approval.

Say all of that when handing the prompt over, so the PM knows what the routine does
not do, and where to come back if the output drifts.

## What to ask before handing anything over

Three questions, then fill the blanks yourself. Do not make the PM guess.

1. **Which Asana project do the tasks land in?** Read the exact project name back
   from Asana rather than accepting what the PM types — stray spaces and odd
   punctuation in project names are common and an approximate name fails silently.
2. **Which recording?** Ask for the meeting, then read its name from the PM's Fathom
   recordings list, not from their calendar. Fathom's stored name is what the routine
   matches; the calendar shows what the PM meant. Pick a stable fragment of that name
   for the prompt — see rule 3.
3. **Who chases action items owned by people outside the Asana workspace?** Usually
   the PM running the routine. This is the fallback assignee in the prompt. Resolve
   that person to exactly one Asana workspace member before filling the blank — a name
   matching nobody leaves the no-match path with nowhere to route.

If the project already names its meeting notes a particular way — many use
`MOM- DD/MM/YYYY` — match that convention instead of introducing a new one. A PM
scanning their board should not be able to tell which tasks a routine made.

## The five rules

**1 · Cloud, not local.** In Claude Code: `Code → Routines → Cloud`, and add a blank
environment — this touches Fathom and Asana, not a repository. A local schedule only
runs while that machine is on, so a routine set up locally silently does nothing
whenever the laptop is shut. These paths change, and this plugin also runs in Cowork:
if the PM is in Cowork, confirm the routines surface there before handover. Confirm as
well that Fathom and Asana are both connected for the account the routine runs under —
an authorisation given interactively does not always carry over to a scheduled run.

**2 · Read the full transcript, never the summary.** Ask for "the summary" and Claude
takes Fathom's AI summary, which is a few lines for a two-hour call. Decisions live in
short remarks — a throwaway "let it be" that settles a question, an offer to test on
a particular account, a price said once. Those exist only in the transcript.

**3 · Match the recording by a stable fragment of its name, not the whole title and
not a link.** Fathom names recordings after the calendar event, so the title is
configuration that nobody thinks of as configuration. Renaming an event kills an
exact-match routine with no error at all — it simply finds nothing. Matching a
fragment that will not change (the client or project name) survives a suffix, an
added date, or a tidy-up. A real rename still breaks it, but that is a rename someone
knows about.

**4 · Don't hand-write the prompt.** Start from the prompt below, or describe the
routine in words to Claude Code's `Create with Claude` and let it write the
instruction. A hand-written prompt drifts, and every PM's drifts differently — which is
how the same routine ends up working for one person and failing for four.

**5 · Every run creates new tasks and never edits an earlier run's.** This is the
failure that took a working routine down after two good runs (field notes, Asana task
`1217124109784176`): run three rewrote what runs one and two had recorded. Dated titles
and create-only behaviour make repeat runs safe. Nothing in the prompt may update,
replace, or append to a previous task.

## The prompt

Fill all five blanks before handing it over. The routine creates **two** tasks per
call — notes for reference, and action items whose subtasks reach their owners.

ALL-CAPS placeholders are the five you fill in before handover. Every lowercase one —
`<meeting name>`, `<meeting date>`, `<names from the call>`, `<link to the recording>`,
`<owner name>` and the rest — is resolved by the routine on each run. Leave them alone.

Two of the five are title patterns. The defaults are `<meeting name> — <meeting date>
notes` and `<meeting name> — <meeting date> action items`. Replace them with the
project's own convention where it has one. Whatever you use, both patterns must carry
the meeting name and the meeting date — the duplicate guard keys on those two.

Before handing over, read the prompt through and confirm no ALL-CAPS `<...>` placeholder
is left in it.

```text
Find the most recent Fathom recording whose title contains "<STABLE NAME FRAGMENT>".

If nothing matches, or you cannot reach Fathom, or the transcript will not load,
create nothing at all, say exactly which of those failed, and stop. Never guess which
meeting was meant.

Go through the full transcript, not the AI summary. The summary is a few lines and
misses the short remarks where decisions actually get made.

Task descriptions carry only the content set out below — no preamble, no commentary,
no notes to the reader. The closing report is required, and belongs outside the
descriptions.

Do not send me a completion notification. Asana's own notifications to the people you
assign subtasks to are expected and are not this.

Work in the Asana project "<EXACT ASANA PROJECT NAME>". Never edit or replace a task
from an earlier run — always create new ones.

Before creating anything, check the project for tasks already carrying this meeting's
name and this meeting's date. Check for each of the two tasks below separately. Create
only the ones that are missing. If one was already there and the other was not, say
which in the report. If both were there, create nothing and say so.

Task 1, titled "<NOTES TASK TITLE PATTERN>":

  Date: <meeting date>
  Attendees: <names from the call>
  Recording: <link to the recording>

  Then a numbered section per topic discussed. For each one cover what was asked, who
  answered, and what was decided. Add an "Owner: <name> — <action>" line wherever
  someone took on an action. Keep the specifics people mentioned — the account names,
  the amounts, the deadlines. Do not flatten them into generalities.

  Cite every decision and every action as "<meeting name> @ <timestamp>", linking to
  that moment in the recording. Anything you cannot cite, leave out.

  Where someone asked for something beyond what the project has already agreed, label
  it SCOPE CHANGE in capitals against its citation, and put a "Routing:" line under it
  reading either "PM handles" or "escalate to founders if commercial". Never write it
  up as agreed work.

  Where anything touches budget, pricing, contracts, relationship risk, or a commitment
  to the client, label it FOUNDER REVIEW in capitals against its citation. Never write
  it up as settled.

  Then an "Open decisions" section: anything raised but not settled, and why it is
  still open.

Task 2, titled "<ACTION ITEMS TASK TITLE PATTERN>":

  Recording: <link to the recording>

  Add one subtask per action item, titled with the action, and cite each one as
  "<meeting name> @ <timestamp>" in the subtask.

  An open decision is also an action item whenever someone owns the next step towards
  settling it. Include it here as well as in the notes task's open decisions section —
  the decision stays visible and somebody stays on the hook. Never drop an item from
  the action list just because it is unsettled.

  Assign each subtask by looking the owner up in the Asana workspace:
    - exactly one matching member  -> assign it to them
    - more than one match          -> leave it unassigned and say which accounts matched
    - no match                     -> title it "<owner name> — <action>" and assign it
                                      to <FALLBACK ASSIGNEE>, who chases it
    - owner unclear in the call    -> leave it unassigned. Never guess a name.

  If you cannot look owners up at all, say so and assign nothing rather than guessing.

  If the call produced no action items, say exactly that. Do not invent any.

Write in what Asana renders, never raw markdown. A description may use Asana's own
headings, bold, and lists. A comment may use bold lines and lists only — no headings.
After each write, read the task back and confirm it rendered as intended; if it did not,
say so rather than leaving it wrong.

Each task's description carries a link to the other task. Write that link in as you
create the task. The first task you create has no link to write yet, so add it to that
description as soon as the second task exists.

Finally report both task links, which of the two tasks you created and which were
already there, how many subtasks you created, every subtask left unassigned with the
reason, and everything you labelled FOUNDER REVIEW.
```

Both tasks use only free-tier Asana features — a name, a description, subtasks, and
assignees. The two tasks are linked by a link in each description, not by an Asana
dependency (`raftkit-core/house-rules`).

Once a routine covers a call, do not also run Gate B interactively on that call — you
would get a second set of tasks.

## Before rolling this out

**Do not switch a routine on until the decision below is recorded.** Handing a PM this
prompt is not a write; activating the routine is, every week, unapproved.

A scheduled routine writes to Asana with nobody approving the draft. That runs against
`raftkit-core/write-protocol`'s draft → approve → push rule, whose exception list is
closed and names only `pr-auto-review`. Rolling the routine out across the team means
RaftLabs is running unattended Asana writes.

The same gap applies to formatting: `raftkit-core/asana-formatting` governs every Asana
write, and a routine runs in a blank environment where that skill does not exist. The
prompt asks for rendered formatting and a read-back in plain words instead, which is
weaker than the core contract. Whichever way the decision below lands, record this as a
known limitation of the scheduled path.

Two ways to resolve it, and the choice belongs to the founders, not to this skill or
the PM:

- **Amend `house-rules` and `write-protocol`** with a second named exception, scoped as
  tightly as the first: tasks stamped as machine-generated and pending review, always
  deletable, and never on a board a client account can reach. The test is client
  access, not whose project it is — a RaftLabs-only board for a client project counts
  as internal and is allowed. Before asking for sign-off on a board, the PM checks its
  project membership and confirms no client account is on it.
- **Have the routine draft and stop**, leaving the PM to approve on their next
  interactive run. Keeps the rule intact; costs the hands-off quality that makes a
  routine worth having.

Surface this when handing the prompt over. Do not present the routine as house-approved
until one of those has been decided and recorded.

## When it stops working

Check in this order — the first two cover most failures:

- **Nothing ran at all** → the routine was created as Local, not Cloud. Rebuild it
  under `Code → Routines → Cloud`.
- **It ran and found no recording** → the calendar event was renamed and the name
  fragment no longer matches. Read the current name from Fathom and update the prompt.
- **Notes are thin, a couple of lines per topic** → the prompt is being read as asking
  for a summary. Restore the "full transcript, not the AI summary" wording.
- **An earlier run's task changed** → the prompt has picked up update or append
  wording. Restore rule 5's create-only phrasing.
- **Action items came back short** → open decisions with owners were filed only as
  decisions. Restore the both-lists paragraph in task 2.
- **A note to the reader is sitting inside a task description** → the output-only line
  was dropped. Restore it.
- **Action items appear that nobody committed to** → the no-invention line was dropped
  from task 2. Restore it.
- **Everything unassigned** → the Asana connector is not reachable from the routine.
  Connectors authorised interactively are not always available to a scheduled run;
  reconnect Asana on the account the routine runs under.
