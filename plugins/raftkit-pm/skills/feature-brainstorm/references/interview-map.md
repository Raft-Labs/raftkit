# Interview map — sections to questions, and what each depth covers

The compiled doc's structure comes from the **live** Feature Template, fetched
fresh every run (`raftkit-core/workflow-constants`). This file never restates
that structure. It maps **topics** to question sets: match each fetched section
to the topic it is asking about, then ask that topic's questions.

A fetched section that matches no topic below is still asked — open-ended,
from the section's own wording — and never skipped because this file does not
name it. A topic below with no matching section is dropped just as quietly.

All questions run under `raftkit-core/discovery-interview`: one at a time,
recommendation first with a reason and a "don't pick this if…" caveat, push
back on vague answers (its `push-back.md`), volunteer what people forget (its
`proactive-prompts.md`), never guess.

## The two depths

| | Quick | Exhaustive |
|---|---|---|
| Questions per topic | the headline question only | headline + every follow-up listed |
| Edge cases | the six house buckets, one question each | all 24 categories individually |
| Proactive catalog | fires on high-signal triggers only | full scan of every answer |
| Recap before compiling | no — straight to the draft | yes, confirmed section by section |

Quick is for a gut-check on an idea that may not survive the week. Exhaustive
is for an idea that is going to get built. State which one is running, and
what it covers, before the first question.

"High-signal trigger" means an answer that names money, personal data, auth,
deletion, or an external service. Those carry consequences a quick pass still
cannot afford to miss.

## Topics

### Idea and why now

**Headline:** What should this let someone do that they cannot do today?

Follow-ups: who asked for it, and what are they doing instead right now · what
breaks or gets slower if it never ships · what does success look like in a
number · is this replacing something that already exists.

### Actor and permissions

**Headline:** Who uses this, and is anyone explicitly blocked from it?

Follow-ups: which roles see it at all · which can act versus only read · what a
blocked person sees when they reach it · whether the block is enforced on the
server or only hidden in the interface · does anyone need it on someone else's
behalf.

### Surfaces

**Headline:** Where does this live — web, mobile, admin, an email, an API?

Follow-ups: which surface comes first · does it differ per surface · is there an
entry point from somewhere that already exists · anything offline.

### Scope

**Headline:** What is deliberately NOT in this, that someone might assume is?

Follow-ups: what gets cut if the deadline moves · what belongs to a later
version · which nearby feature is a separate piece of work.

### Behaviour

**Headline:** Walk me through it working, start to finish, for one real person.

Follow-ups: what they see first · what they have to fill in · what confirms it
worked · where they land afterwards · what a second run looks like once they
have used it once.

### Business rules

**Headline:** What rule must always hold here, even when it is inconvenient?

Follow-ups: limits per person, per plan, per period · what is allowed to be
changed after the fact and by whom · what is enforced automatically versus
checked by a person · any rule that comes from a contract or a regulation.

### Data

**Headline:** What gets stored, and what does it belong to?

Follow-ups: new records versus new fields on existing ones · what is personal
data · how long it is kept · what happens to it when the parent record is
deleted · what has to stay unique.

### Edge cases

**Headline:** Walk the six buckets — waiting, empty, error, success, limits,
default values — asking what should happen in each.

Exhaustive: walk all 24 categories individually
(`raftkit-core/discovery-interview` → `references/edge-cases.md`), and load
that file's pre-built set for the feature type in play. Never let a category go
silent: each one is answered or marked not applicable with a reason.

The error case is the one that matters most. Push until it names the exact
message the person sees and what they do next.

### Interface and copy

**Headline:** What does someone read on screen — the words, not the layout?

Follow-ups: the empty state before anything exists · the confirmation after it
works · the error wording · what a destructive action asks before it goes
through · any language other than English.

### Side effects

**Headline:** What else happens that the person does not see?

Follow-ups: emails or notifications, to whom, on what trigger · anything
scheduled or delayed · anything another system needs told · what should be
measurable afterwards.

### Dependencies

**Headline:** What has to exist already for this to work?

Follow-ups: other features, other teams, a third-party service, a contract or
an account someone has to set up.

### Open questions

Not interviewed — assembled. Everything flagged and unresolved during the run
lands here with who needs to decide it. If a person answers one late in the
run, move it out; do not leave it recorded as open.
