---
name: design-standard
description: This skill should be used whenever the RaftLabs Module Design Standard (MDS) — the ten-rule SOLID/design-pattern bar for React/Next.js, Node.js, and AWS Serverless code — is needed as installable core content. It is the source M3 · setup-project reads to inject the standard into a client repo's CLAUDE.md as governance-pack component 6, and the single place to confirm the exact rule text before any repo installs or updates it.
user-invocable: false
---

# RaftLabs Module Design Standard

Ten SOLID/design-pattern rules for React/Next.js, Node.js, and AWS Serverless
code, packaged once here as versioned core content and installed into every
client repo's `CLAUDE.md`. Before this pack, RaftKit had no design-quality bar
anywhere: zero mentions of SOLID, a design pattern, coupling, or cohesion in
the whole marketplace — `raftkit-dev/simplify` reliably deletes an
over-engineered abstraction and nothing catches an under-engineered one. This
skill is the fix.

## What's in the pack

| File | Installs to | Contains |
| --- | --- | --- |
| [references/standard.md](references/standard.md) | client repo `CLAUDE.md` | MDS-1 through MDS-10, each with a diff-visible trigger and fix, plus the Precedence section |

Payload verbatim — clean to inject; all meta lives here in SKILL.md.

## Why it lives in CLAUDE.md, not a separate doc

`pr-review-toolkit`'s `code-reviewer` agent is a CLAUDE.md-derivative machine:
its own scoring criteria put "an explicit CLAUDE.md violation" at the top
confidence tier (90-100) and "a minor nitpick not explicitly in CLAUDE.md" at
the bottom (26-50), and it reports only findings scored 80 or above. A rule
not physically present in a repo's `CLAUDE.md` is filtered out **by design**;
a rule that is present is enforced at the top tier, in every client repo, by
an agent RaftKit already declares as a dependency
(`raftkit-dev/capability-preflight`'s provider registry). This is the highest
enforcement-per-byte lever available — RaftKit doesn't need to build a new
reviewer, it needs to put the right ten rules where an existing one already
looks first.

## How it's consumed

`raftkit-dev/setup-project` (out of scope here) reads `references/standard.md`
and merges it into the client `CLAUDE.md` via `claude-md-management` as
governance-pack component 6, the same live-read-at-install-time discipline as
components 1-5. This skill supplies the content; it does not install it, and
it keeps no record of which repos have which version — that is the version
marker's job (`setup-project/references/components.md`).

`raftkit-dev/implement`'s post-edit chain also reads this standard indirectly:
the design-review layer it runs (`implement/references/execution.md`) dispatches
`pr-review-toolkit:code-reviewer` and `pr-review-toolkit:type-design-analyzer`
against the diff, and those agents' own CLAUDE.md-derivative scoring is what
actually applies the rules below — this skill never re-implements a reviewer.

## Single source of truth — exactly one copy

The rule text exists in **exactly one file in this entire marketplace**:
`references/standard.md`. No other skill, reference, template, or test
restates an `MDS-` rule — `setup-project` installs this file's content
byte-for-byte, and the client-scaffold `CLAUDE.md` template
(`raftkit-dev/docs`) carries only a one-line pointer back here, never a copy.
A second copy is exactly the drift this pack — and this whole pattern in
raftkit-core — exists to prevent.

## Resolving the standard's one real tension — with `simplify`

`raftkit-dev/simplify` inlines "a factory, interface, wrapper, strategy, or
indirection that serves exactly one concrete case"
(`simplify/references/candidate-catalog.md`). A naive SOLID standard would
collide with that on nearly every line, since DIP is usually taught as
"extract an interface" — precisely what `simplify` deletes. The **Precedence**
section at the end of `references/standard.md` is the load-bearing part of
this pack: every rule is drafted as a move, a deletion, or a narrowing, or is
gated behind a plural trigger strictly above `simplify`'s single-caller line,
so the two almost never meet — and when they do, `simplify` wins by default
unless a reviewer can name the specific rule and the specific trigger it met.

## Provenance — this is RaftLabs house content, not Ashit's protocol pack

Unlike `governance-protocols` (verbatim-frozen from Asana task
`1216375937893602`, amended only through Ashit), this standard is
**RaftKit-authored**, with its own amendment path: a PR to this file set,
reviewed the same way any other RaftKit skill content is reviewed. It is not
subject to `governance-protocols`' verbatim-from-source discipline, and it
does not install "whole or none" alongside the five protocols — it is its own
component, versioned and updated independently.

## Guardrails

- **Plain English out** — every line a human reads follows `raftkit-core/house-rules`' plain-language rules; a house term gets its one-line gloss on first use.
