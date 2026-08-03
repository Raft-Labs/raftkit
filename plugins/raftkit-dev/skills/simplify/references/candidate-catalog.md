# Candidate catalog — how the engine's findings become candidates

What this pass looks for in the in-scope diff, and how it decides. The
**`code-simplifier:code-simplifier` agent** does the finding and the mechanical
change; this catalog **is** RaftKit's own minimalism lens — there is no
external minimalism engine — and is how its findings are triaged into RaftKit's
approval buckets. Everything here is behaviour-preserving — a candidate that
would change behaviour is not a simplification, it is a bug (and the suite
catches it: see `revert-safety.md`).

## What counts as a candidate

- **Single-caller abstractions.** A factory, interface, wrapper, strategy, or
  indirection that serves exactly one concrete case. Inline it back to the one
  call site. This is the happy-path candidate (Scenario 1) — inlined after
  approval, suite green before and after.
  - **One counter-clause, from the Module Design Standard's MDS-7** — an
    inversion seam kept only so a domain rule is unit-testable without I/O,
    and only if **a test in the same diff exercises it** (no test, no seam —
    `raftkit-core/design-standard`, Precedence). A seam meeting that bar is
    **list-only**, never auto-applied — this pass never adjudicates the
    design question, it hands the candidate to the developer named as an
    MDS-7 exception instead of inlining it silently.
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
