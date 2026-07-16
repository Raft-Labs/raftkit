# Extraction and citations

How to turn one Fathom transcript into three cited lists, how every item is cited,
how out-of-scope requests are flagged, and how a long transcript is processed without
truncation.

## The three categories

Extract exactly these three, and nothing else (a recap is out of scope — Fathom
already produces one):

- **Decisions** — a choice the call actually settled ("we're going with weekly
  billing", "the launch moves to August"). Not a discussion, not an option still open.
- **Scope changes** — anything the client asked for that sits beyond the current
  SOW/profile scope. These are decisions' dangerous cousins: flag every one (see
  "The SCOPE CHANGE flag" below). Never fold a scope change into the plan as if it
  were agreed work.
- **Action items** — a concrete next step someone owns ("Ravi sends the API keys",
  "we draft the migration plan"). These become the proposed task batch in
  `gates-and-writes.md`.

An item that is none of these (small talk, a rehash, an aside) is not extracted.

## The citation form — one form, used everywhere

Every extracted item — in all three categories, and every profile-delta fact derived
from the call — carries a citation in this single form:

```
<meeting> @ <timestamp>
```

- `<meeting>` — the recording's title (or its share link).
- `<timestamp>` — a **timestamped deep link** into the transcript at the moment the
  item was said. Fathom returns these when the recording URL is passed to the
  transcript call, so always pass the URL when reading the transcript.

**No citation, no claim.** An item that cannot be tied to a specific transcript
moment is not asserted as fact — either drop it, or raise it to the PM as a question
("did we actually decide X? I can't find it in the transcript"). Never manufacture a
timestamp and never state an uncited item as though it were agreed.

## The SCOPE CHANGE flag

The flag wording is **fixed and always caps-visible**: the literal token
`SCOPE CHANGE`, uppercase, is what makes an out-of-scope request impossible to miss.
Present each flagged item in this shape:

```
SCOPE CHANGE — <what the client asked for>  [<meeting> @ <timestamp>]
  Routing: <PM handles / escalate to founders if commercial>
```

Routing rule:

- The item is **labelled and routed, never silently absorbed** into the plan or the
  task batch as ordinary work.
- If the scope change carries a **commercial** dimension — budget, contract,
  relationship risk, or a client commitment (e.g. a timeline promise) — it
  **escalates to founders**
  (`raftkit-core/house-rules`); the PM does not commit on RaftLabs' behalf.
- A non-commercial scope adjustment the PM can own stays with the PM, still flagged
  and still cited.

A scope change may also become an action item ("PM to quote the extra module") — that
is fine, as long as it stays flagged and is never counted as in-scope delivery.

## Long transcripts — chunk, report, never truncate

A transcript that will not fit a single pass is processed in **chunks**, with a
**progress note per chunk** ("scanning 2 of 4 …") so a slow run stays legible. Extract
from each chunk, then merge the three lists across chunks, de-duplicating items that
span a chunk boundary. Never silently truncate a transcript: a half-read call yields
false-empty or half-cited results, which is worse than saying the run is still going.
