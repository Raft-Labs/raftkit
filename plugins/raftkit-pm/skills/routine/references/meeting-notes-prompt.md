# Meeting-notes routine prompt

Fill the five `<ALL-CAPS>` blanks. Title-pattern defaults: `<meeting name> — <meeting date> notes` and `<meeting name> — <meeting date> action items`; use the project's own convention where it has one. Both patterns must carry the meeting name and date, which the duplicate guard keys on.

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
headings, bold, and lists.
After each write, read the task back and confirm it rendered as intended; if it did not,
say so rather than leaving it wrong.

Each task's description carries a link to the other task. Write that link in as you
create the task. The first task you create has no link to write yet, so add it to that
description as soon as the second task exists.

Finally report both task links, which of the two tasks you created and which were
already there, how many subtasks you created, every subtask left unassigned with the
reason, and everything you labelled FOUNDER REVIEW.
```
