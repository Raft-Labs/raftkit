# Story parsing contract

How to read a RaftKit story task and turn it into a scope contract. The parse
must be robust to Asana's quirks — the board and the stories are hand-authored
and their formatting is inconsistent.

## Inputs

- A task link or GID (the story) — or a board task **name** to resolve by search
  (SKILL.md Step 1: one match → confirm and proceed; zero/many → ask).
- The live task **plus all its subtasks**, fetched through the Asana connector.
- The live User Story Template (GID from `workflow-constants`) as the format
  reference — read every run, never from memory.

## Subtasks

A story's subtasks are two kinds:

- **Acceptance criteria** — every subtask whose name starts with the leading
  token `[AC] ` (bracket, `A`, `C`, space). Match on that leading token only.
  One subtask's *text* may contain a doubled `[AC] [AC]` — leading-token
  matching handles it. These are the **definition of done**; each is
  independently verifiable.
- **Fixed containers** — exactly three, matched by **exact name**, no prefix:
  `Development`, `Testing`, `Bugs`. They hold work notes, not criteria.

Subtask order is **not** meaningful — ACs and containers are interleaved as the
API returns them. Filter by prefix / exact name; never rely on position.

## Description sections

The description is the story body in the house template shape. Section headings
are plain numbered lines and **numbering intentionally skips 10** (…9 → 11 → 12).
Punctuation varies between template and story (ASCII `-` vs em-dash `—`); do not
match on punctuation. The two sections that carry scope:

- **Story header** — the `STORY:` line carries the full title; `Surface(s)`,
  `Actor / role`, `Who is allowed / not allowed`, `Priority`/`Type`, and
  `Depends on / related`.
- **Section 9, "Out of scope / non-goals"** — the **hard exclusion list**.
  Anything here must NOT appear in the diff. Treat it as a fail condition, not a
  suggestion.

WEESLD (section 6) rows — Waiting, Empty, Error (most important), Success,
Limits, Default values — each usually maps to one or more `[AC]`s to cover.

## Deriving the build target

The board section names the milestone and the skill. Enumerate sections
**dynamically** — do not hard-code names; the board has an extra empty
`Untitled section` and the real M5/M6 names are longer than their short forms.

| Section prefix | Target plugin |
|---|---|
| `M1 · …` | `raftkit-core` (or repo scaffold / CI — may be executable, not a skill) |
| `M2 · …` | `raftkit-pm` |
| `M3 · …` | `raftkit-dev` |
| `M4 · …` | `raftkit-qa` |

Skill name = the short area name in the task title (e.g. `M3 · scope-guard` →
skill `scope-guard` in `raftkit-dev`). Confirm the derived plugin + skill name
with the human at the scope-contract gate before building — never invent a
target.

## Output of the parse (restate in chat)

- STORY title + surface + actor + permission boundary.
- Target: `<plugin>/<skill>` (or "executable — CI/script/hook").
- The `[AC]` list, verbatim — this is the pass list.
- The Out-of-scope list, verbatim — this is the exclusion list.
- Any `❓`/unresolved facts or source conflicts the story flags — stop and ask,
  never guess (house-rules: no invented facts).
