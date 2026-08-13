# Interview map — the lenses, the depths, and who answers what

The compiled doc's structure comes from the **live** Feature Template, fetched
fresh every run (`raftkit-core/workflow-constants`). This file never restates
that structure. It maps **lenses** to question sets: run the feature through
each lens, then place the answers into whichever fetched section they belong to.

A fetched section that matches no lens below is still filled — ask about it
open-ended, from the section's own wording, and never skip it because this file
does not name it. A lens with nowhere to land is still worth asking; its answer
goes in the nearest section or the open questions.

All questions run under `raftkit-core/discovery-interview`: a few related
questions at a time (three at most), recommendation first with a reason and a
"don't pick this if…" caveat, push back on vague answers (its `push-back.md`)
and on unnecessary ones, volunteer what people forget (its
`proactive-prompts.md`), never guess. How the questions are delivered — explain
before critiquing, translate the domain, build the example — is its
`conversation-craft.md`.

## The two depths

| | Quick | Exhaustive |
|---|---|---|
| Questions per lens | the headline question only | headline + every follow-up listed |
| Edge cases | the six house buckets, one question each | all 24 categories individually |
| Proactive catalog | fires on high-signal triggers only | full scan of every answer |
| Recap before compiling | no — straight to the draft | yes, confirmed lens by lens |

Quick is for a gut-check on an idea that may not survive the week. Exhaustive
is for an idea that is going to get built. State which one is running, and
what it covers, before the first question.

"High-signal trigger" means an answer that names money, personal data, auth,
deletion, or an external service. Those carry consequences a quick pass still
cannot afford to miss.

## The lenses

### 💼 Business — why this exists

**Headline:** What should this let someone do that they cannot do today, and
who benefits when they can?

Follow-ups: who asked for it, and what are they doing instead right now · what
breaks or gets slower if it never ships · what behaviour is this trying to
encourage · what does success look like in a number · could someone misuse it,
and what would that cost · does it change anything about how the business
makes money · could it create extra support work.

### 👤 User — who does it, and how it feels

**Headline:** Walk me through it working, start to finish, for one real person.

Follow-ups: what they see first · what they have to fill in · what confirms it
worked · where they land afterwards · what a second run looks like once they
have used it once · can they undo it · do they get told anything · what
happens on their very first visit, before any data exists.

### 📱 Product — where it lives and what it looks like

**Headline:** Where does this live — web, mobile, admin, an email, an API?

Follow-ups: which surface comes first · the screens involved and how someone
gets to them · the buttons and actions on each · what differs per surface ·
search, filters, sorting, history · what the empty, loading, error, and success
states say · anything offline.

### 🔐 Permissions — who is allowed, and who is explicitly not

**Headline:** Who uses this, and is anyone explicitly blocked from it?

Follow-ups: which roles see it at all · which can act versus only read · what a
blocked person sees when they reach it · whether the block is enforced on the
server or only hidden in the interface · does anyone need it on someone else's
behalf · what counts as personal or private here, and who may see it.

### 🛠️ Admin — what the team can do about it

**Headline:** Can an admin see, change, or reverse this after the fact?

Follow-ups: does it show up in a history · who did it, and when · does anything
here need approval before it takes effect · different access per role · does
the team need a report on it · what does someone do when a person calls
support about it.

### 📋 Rules — what must always hold

**Headline:** What rule must always hold here, even when it is inconvenient?

Follow-ups: limits per person, per plan, per period · what can be changed after
the fact, and by whom · what is enforced automatically versus checked by a
person · anything that comes from a contract or a regulation — those are
constraints, not preferences (`research-protocol.md`).

### 🗄️ Data — what gets kept

**Headline:** What gets stored, and what does it belong to?

Follow-ups: new records versus new fields on existing ones · what is personal
data · how long it is kept · what happens to it when the parent record is
deleted · what has to stay unique · what is worth tracking so the team can tell
later whether this worked, and why that number is useful.

### 🔔 Side effects — what happens that nobody sees

**Headline:** What else happens that the person does not see?

Follow-ups: emails, push, in-app or text messages — who gets them and when ·
can someone turn them off · anything scheduled or delayed · anything another
system needs told.

### ⚠️ Edge cases — what happens when it goes wrong

**Headline:** Walk the six buckets — waiting, empty, error, success, limits,
default values — asking what should happen in each.

Exhaustive: walk all 24 categories individually
(`raftkit-core/discovery-interview` → `references/edge-cases.md`), and load
that file's pre-built set for the feature type in play. Never let a category go
silent: each one is answered or marked not applicable with a reason.

Only raise an edge case that could materially change the product. Skip the ones
that exist for completeness alone.

The error case matters most. Push until it names the exact message the person
sees and what they do next.

### 🔗 Dependencies — what has to exist first

**Headline:** What has to exist already for this to work?

Follow-ups: other features, other teams, an outside service, a payment
provider, an app store, a contract or an account someone has to set up · what
happens to this feature when that dependency is unavailable.

### ✂️ Scope — what this deliberately is not

**Headline:** What is deliberately NOT in this, that someone might assume is?

Follow-ups: what gets cut if the deadline moves · what belongs to a later
version · which nearby feature is a separate piece of work · which of the ideas
raised in this session are "now", and which are "later".

## Triage the leftovers — not every question goes to the client

Every unresolved question gets one label before it reaches the doc. Sending a
client a question the team could have settled itself costs goodwill and a week.

| Label | Meaning |
|---|---|
| 🔴 Must ask | The feature cannot be defined or estimated without this answer. |
| 🟡 Good to clarify | Worth confirming, but a sensible recommendation exists without it. |
| 🟢 Team decides | Product, design, or engineering can choose this. It never goes out. |

Where a 🟡 has a sensible answer, write the recommendation next to it, so the
question travels with its proposed answer rather than as an open-ended ask.

A minor interface choice is almost always 🟢. Anything touching money, a
contract, a regulation, or a promise already made to a customer is 🔴.

```output
Still open after this session:

Must ask — can an admin reverse a transfer? Is there a maximum amount?
Good to clarify — should both people get told? I'd say yes, both.
Team decides — how the recipient is searched for. I'd use email, not name.
```

## Facts carry a tag

Every fact in the compiled doc is tagged the same way `project-onboarding`
tags a Project Profile, so the two read alike:

| Tag | Meaning |
|---|---|
| ✅ Confirmed | Stated plainly by the person or a supplied source, and cited to it |
| ⚠️ Partial | Implied, incomplete, or thin — the default for anything not clearly confirmed |
| ❓ Missing | Explicitly absent — a gap named, never a guess |

An untagged fact defaults to ⚠️ Partial. Confidence is earned from a source,
never assumed.
