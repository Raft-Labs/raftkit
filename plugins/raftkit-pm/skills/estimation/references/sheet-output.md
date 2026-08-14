# Sheet output — the canonical layout and the chat shapes

The Sheet is what the proposal is built from, so its layout is fixed and its strings
live here. This file is the single source of the columns, the write rules, and every
shape the PM sees in chat. Nothing here is paraphrased elsewhere.

## Fixed columns (exact order, verbatim)

One estimate, one Sheet, one header row, these six columns in this order:

| Column | Holds |
|---|---|
| feature | the feature as the PM's list names it — never reworded |
| FE (h) | the front-end hour range, low–high (a stated `0` where none is needed) |
| BE (h) | the back-end hour range, low–high |
| QA (h) | the QA hour range, low–high |
| total | that feature's three ranges summed, low–high |
| assumptions | the named assumptions for that feature, including any widening driver |

The last row is the list total: the four ranges summed across every feature, with the
list-level assumptions in the final column.

The skill **owns the structure** — the column set and their order.
The PM **owns the content** — the features, the numbers once vetted, and the wording
of the assumptions.
A re-run may propose new rows and changed numbers, but it never reorders, renames, or
drops these columns, and it never overwrites a number the PM or the developer has
edited. A changed number on an edited row is shown for the PM to resolve.

## A source Sheet is not the estimate Sheet

The feature list may itself arrive as a Google Sheet. That Sheet is a **source, read
only** — never the destination. Read the features from it, and write the estimate to
a Sheet of its own.

Writing hours back into the PM's list would overwrite a document other people are
editing for the proposal, and would mix a number that has not been vetted into a
file that already circulates. Keep them apart, and name the source Sheet in the
estimate so the two stay traceable to each other.

## The write happens after approval, never before

The estimate is drafted in chat first and written to the Sheet only once the PM
approves it (`raftkit-core/write-protocol`). Silence is not approval. Report the Sheet
link only after the write lands — never as an optimistic guess.

Where the Sheet lives is a parameter the PM supplies. Never hardcode a path, a file
ID, or a single connector.

## When the Sheet cannot be reached

Google Sheets is a connector, and whether a PM's session exposes one is a setup
question, not something this skill can settle. If it is absent or the write is
refused, **do not assume it** and do not half-write: keep the estimate in chat, name
the exact access fix — which account needs which permission on which Sheet or
folder — and stop so the PM can grant it and re-run.

## Chat shapes

The watermark is always the first line, and the approval chain is the second line
whenever the shape carries hours. Use literal `—`, `·` and `⚠️` so it reads cleanly in
chat.

### Estimate

```output
Requires founder review — not a client commitment.
AI estimate → vetted by <implementing developer> → approved by Nirav or Ashit → only then shared with the client.

Estimate — <project>, <N> features

- Rate-card tagging — FE 6–10 h · BE 4–7 h · QA 3–5 h — assumes tags are additive.
- Loyalty tier rules — FE 8–12 h · BE 12–20 h · QA 5–8 h — assumes one tier model. ⚠️ widened: tier rules unwritten.
- Guest check-in — FE 10–16 h · BE 0 h · QA 4–6 h — assumes the check-in API exists.

Total: 45–74 h — FE 24–38 h · BE 16–27 h · QA 12–19 h

Assumptions:
- No migration of the rate cards already live.
- No Project Profile was supplied, so every range is widened.

Sheet: <link>
```

### Redirect — the ask names one story

```output
Requires founder review — not a client commitment.

One story is user-story's job — run raftkit-pm user-story and ask it to size the story. This skill estimates a whole feature list.
```

### Empty — no list to estimate

```output
Requires founder review — not a client commitment.

No feature list to estimate. Paste the list, or point at the scope document that holds it.
```

### Sheet unreachable — the estimate still stands

```output
Requires founder review — not a client commitment.
AI estimate → vetted by <implementing developer> → approved by Nirav or Ashit → only then shared with the client.

The estimate above is ready. The Sheet was not written, because Google Sheets is not reachable from this session.

Fix: grant <account> edit access to <folder>, then re-run and approve the write.
```
