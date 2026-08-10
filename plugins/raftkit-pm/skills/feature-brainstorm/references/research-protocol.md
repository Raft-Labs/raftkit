# Research protocol — when to look something up, and how to label it

Research is never automatic. Most of what this interview needs is either in
the person's head or in the sources they supplied; reaching for the web by
default wastes their time and dilutes the doc with unsourced generality.

## The order

1. **What the person said.** Always first, always wins.
2. **What their sources say.** The supplied material, cited by name.
3. **House knowledge.** How RaftLabs normally does this — the shared catalogs
   in `raftkit-core/discovery-interview`, the house rules, prior patterns.
   Offer it as a recommendation the person can reject, never as a settled fact.
4. **The web.** Only when 1-3 leave a real gap, and only on the terms below.

## When the web is allowed

One condition: a specific gap that the first three cannot fill, that the
answer actually depends on. In practice that is a fact that changes over time
and that neither of you should be recalling from memory — a regulation's
current requirement, a provider's current limits, what is now standard
practice in a domain neither of you works in.

It is not allowed for padding a thin section, for confirming something the
person already told you, or for producing "best practice" filler nobody asked
for.

## Announce before running it

Say what the gap is and that you are about to look it up. Then look it up.
Never let a search happen invisibly inside a run the person thinks is a
conversation.

```output
I don't have a current answer for retention limits under that rule.
Looking it up now — one search, then back to the questions.
```

## Label it where it lands

Anything researched carries its source at the point it is used, inline, in the
compiled doc. Not a footnote, not a sources section at the bottom, not blended
into a sentence that reads as the person's own decision.

A line that came from research and a line that came from the person must be
tellable apart by reading the doc alone, by someone who was not in the
session.

## Research does not decide anything — with one boundary

A researched fact is input to a question, not a substitute for asking it.
Present what it says, then ask what the person wants to do about it. If they
disagree with it, their answer is what goes in the doc — with the research
noted alongside as the thing they decided against.

That holds for product choices. It does not hold for an authoritative
requirement.

## A requirement is not a preference

A law, a regulation, a platform rule, or a term in a signed contract is a
constraint the feature has to live inside. It is not a recommendation someone
can decline.

When research surfaces one of those and it conflicts with what the person
wants the feature to do, do not record it as a decision they made against it.
Record it as a conflict, stop treating that part of the spec as settled, and
escalate — contracts and regulatory exposure are founder-level calls, never a
spec doc's (`raftkit-core/house-rules`).

```output
This conflicts with a rule the feature has to follow, not a preference.
Flagged as blocked and routed to the founders — the rest of the spec continues.
```

Two judgement calls this needs, both of which stay with a person:

- **Does the requirement actually apply here?** Often unclear. If it is
  unclear, that uncertainty is the open question — not the behaviour.
- **Is it really authoritative?** A vendor's recommendation, an industry
  convention, and a statute are three different things. Only the last one
  binds. Say which you found.

## When a search comes back thin

Say so plainly and record it as an open question. A weak or contradictory
result is not rounded up into a confident line.

```output
Searched — the sources disagree on this one.
Recording it as an open question rather than picking a side.
```
