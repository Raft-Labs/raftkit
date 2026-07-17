# Candidate catalog — what counts, under the ponytail lens

What this pass looks for in the in-scope diff, and how it decides. The
**code-simplifier** plugin does the finding and the mechanical change; this
catalog is how its findings are read and triaged. Everything here is
behaviour-preserving — a candidate that would change behaviour is not a
simplification, it is a bug (and the suite catches it: see `revert-safety.md`).

## The ponytail lens

- **Prefer deleting code to restructuring it.** The cheapest simplification is
  removal. Reach for a rewrite only when deletion is impossible.
- **Introduce no new abstractions.** The pass never adds an interface, a helper, a
  layer, or a config to "clean up" — that trades one form of over-building for
  another. It only removes.
- **Complexity must earn its place.** Anything present for a future that the story
  did not ask for is a candidate for removal.

## What counts as a candidate

- **Single-caller abstractions.** A factory, interface, wrapper, strategy, or
  indirection that serves exactly one concrete case. Inline it back to the one
  call site. This is the happy-path candidate (Scenario 1) — inlined after
  approval, suite green before and after.
- **Dead flexibility / unused config.** Parameters never passed a non-default,
  options nobody sets, feature flags with one branch, extension points with no
  extension. Remove the unused path and the knob that fed it.
- **Speculative generality.** Type parameters, hooks, or "just in case" branches
  with no current caller in the diff.
- **Over-commenting.** See the comment taxonomy below.

## Comment taxonomy — remove narration, keep the WHY

Two kinds of comment; the pass treats them oppositely (Scenario 2):

- **Narration — REMOVE.** Comments that restate what the code already says, line
  by line. `// increment i`, `// return the result`, `// loop over users`. They
  add reading cost and no information.
- **WHY-comments — PRESERVE.** Comments that carry information the code cannot:
  - **Invariants** — "must stay sorted; binary search below depends on it."
  - **Gotchas** — "the API returns cents, not dollars"; "off-by-one is
    deliberate — the header row."
  - **Links** — a ticket, spec, RFC, or workaround reference that explains a
    non-obvious choice.

  When unsure whether a comment is narration or a WHY, keep it — see the
  conservative default.

## The conservative default

Every candidate is sorted into one of two buckets:

- **Apply** — a clear, unambiguous removal with no behaviour question. Goes into
  the before/after batch for approval.
- **List-only** — anything uncertain: a plausibly-load-bearing comment, an
  abstraction that *might* have an out-of-diff caller, a config that *might* be set
  externally. These are **reported for the developer to judge, never
  auto-applied.**

When in doubt, list it, don't apply it. Beauty is never worth a guessed behaviour
change — the suite is the safety net, but the conservative default keeps guessed
changes out of the batch in the first place.
