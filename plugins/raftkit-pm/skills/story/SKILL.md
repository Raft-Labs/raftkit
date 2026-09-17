---
name: story
description: Write, amend, check or size a RaftLabs user story in Asana — "write a user story", "turn this idea into a story", "amend this story", "add these acceptance criteria", "the dev found a gap, fix it", "is this story ready?", "how long will this take?". Reads the live Feature Template once, grounds every line in sources, stops once before writing.
user-invocable: true
---

# story

One skill for a story's life: author, amend, check, size. `raftkit-core:rules` apply; readiness is judged by the rules' `references/readiness.md`.

**Mode** comes from the target: an empty description → **author**; a description that holds a story → **amend**; "is it ready?" → **check** (read-only, verdict only); "how long?" → **size** (`references/sizing.md`, no stop). Readiness in every mode is judged by `raftkit-core:rules` → `references/readiness.md`.

**The rule:** never proceed without a source of truth. Every sentence traces to the Profile or a source the PM named. A gap becomes a question in the draft, never a plausible fill.

## Author

1. **One ask** for what is missing: the target task, the scope, the sources. The Profile is found by convention and used; not using it is a stated decision.
2. **Read at once**: the target task, the Feature Template (once per conversation), the Profile, the named sources. Thin sources → run the batched interview in `references/interview.md` before drafting.
3. **Draft** a story that mirrors the template exactly: its header block, every numbered section in order with the template's own numbers and titles (gaps included), every placeholder replaced with a sourced value; the template's comments are guidance, never copied. Where the target task is new or unnamed, its name is a short area name; the `STORY:` header line always carries the full imperative title. Then the `[AC]` subtasks: the happy path, every edge-case row the template lists (the error row names the exact message and recovery), every business rule, every permission boundary (who is blocked, enforced server-side), plus `Development` / `Testing` / `Bugs`.
4. **Self-check readiness** against the fetched template. Each gap becomes a numbered question at the top of the draft, filled only from the PM's reply. Cohesive beats epic; genuine doubt is one more question. An epic becomes sub-stories one at a time, each a full story with its own `[AC]`s and `Development` / `Testing` / `Bugs`, linked in descriptions — never a stub.
5. **Stop once**: a `Sources used` block naming every source, the full body, every subtask, the target task, the open questions.

```output
Story draft → <task>. Sources used: Project Profile (as-of 3 Sep), PRD §4, client call 12 Aug.
Open: 2 questions above — the go is refused while either is blank.
**STOP** — approve to write, edit to change, or decline.
```

6. **On go**: write the description, create the subtasks, read back once, confirm with the link and counts.

## Amend

Additive only, never a rewrite: `references/amend.md`. One stop covers the diff, the new `[AC]`s, the follower comment and, when `Development` or `Testing` is ticked, the mid-build warning.

## Check

Fetch the story and its subtasks, judge against the template, print the verdict from `raftkit-core:rules` → `references/readiness.md`. Read-only.
