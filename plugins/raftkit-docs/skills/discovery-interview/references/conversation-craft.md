# Conversation craft — how the questions land

The catalogs decide *what* gets asked. This file is *how*. Every rule here came
out of an interview that went wrong in a specific way.

## Explain before you critique

The single most reliable way to lose a non-specialist: open with what is broken
about a thing they do not yet understand.

Explaining what something is, and flagging what is wrong with it, are two
separate messages. The explanation goes first, on its own, and it does not
mention risks, blockers, contradictions, missing documents, or cost. Those
come after the person has their footing.

End the explanation with a plain check — "does that make sense?" — not a menu
of next steps. The menu comes later.

```output
Too fast: "Phase 1 scopes the review engine only, on synthetic data,
server-side, with a conflict between reviewer edits and the grade lock."

Right pace: "Imagine a parent with no idea whether their kid is a realistic
candidate for a college. Normally they'd pay a consultant to guess.
This tries to replace that guess by looking at last year's admitted students.
Does that much make sense before I go further?"
```

## Translate the domain, every time

Assume no specialist vocabulary. Translate each term — including the other
side's own names for their features and modules — before using it. If a term
has to be used, define it in the same breath.

```output
Instead of: "Should this operation be synchronous or asynchronous?"

Ask: "Should the person see this finish immediately, or can it take a moment
in the background? Sending money should feel instant. A big report can take
a few minutes. Which one is this?"
```

## Build the example, don't describe the rule

An unclear requirement gets clearer faster as a worked scenario with real
numbers than as an abstract description. The scenario is also the thing you can
forward to whoever has to decide.

```output
Anna has 500 points. She sends 200 to John.
Anna has 300 left. John receives 200.

Those 200 points expired on 30 September before the transfer. Now what?
A. They still expire on 30 September.
B. They get a fresh expiry date.
```

## Compare to something familiar

One line naming a product the person already uses does more than a paragraph
of description. The point is not to copy it — it is to make an option legible.

> "Think about how a post shows a like count, and tapping it shows who liked
> it. Same pattern here?"

Always say what the referenced behaviour actually is. A comparison the person
has to look up is worse than no comparison.

## Pressure-test before formalising

An idea offered mid-interview is a thought, not a requirement. Question it once
before writing it down — especially the person's own ideas, which get the least
scrutiny precisely because they came from them.

> "We could. First though — is approval actually needed? Every transfer waiting
> on an admin is work for your team and a delay for the user. Approval earns
> its cost if there's money or fraud risk. Is there?"

Then split what survives:

- **Now** — what the thing needs to work at all.
- **Later** — what would improve it but does not need to exist yet.

Not every idea raised becomes a requirement. Saying so is part of the job.

## The shape of a good turn

Observation → explanation → example → question. In that order, small enough to
answer in one sitting.

```output
The notes say people can transfer points, but not how they pick who gets them.
If two people are both called Sarah, searching by name sends points to
the wrong one. I'd use email or phone number instead.

Do people already have a verified email or phone in the product?
```

## Recap before continuing

After a run of decisions, stop and show the state. It catches a
misunderstanding while it is still cheap, and it shows the person the interview
is going somewhere.

```output
Settled so far: transfers happen instantly, existing users only,
the original expiry date carries over, both people get told.

Still open: transfer limits, and whether an admin can reverse one.
```

## Say when there is enough

Name the moment the interview has what it needs, and list only what genuinely
still blocks progress. An interview with no stated end runs until the person
gives up on it.

```output
Enough to define the core behaviour. Two things still need a decision:
can an admin reverse a transfer, and is there a maximum amount?
Everything else the team can settle on its own.
```

## Never

- Merge the plain explanation of a thing with the list of what is wrong with it.
- Ask twenty questions at once, or one question twenty times.
- Re-ask for something already supplied, already found, or already settled.
- Turn every idea raised into a requirement.
- Agree with every idea automatically.
- Repeat a failed explanation in slightly different specialist words. Change the
  approach instead — a smaller example, a comparison, a concrete scenario.
