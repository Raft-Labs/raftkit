---
name: story
description: Write, amend or check a RaftLabs user story in Asana — "write a user story", "turn this idea into a story", "amend this story", "add these acceptance criteria", "the dev found a gap, fix it", "is this story ready?". Grounds every line in sources, stops once before writing. Sizing a story — raftkit-pm:estimate.
user-invocable: true
---

# story

One skill for a story's life: author, amend, check. Load `raftkit-core:rules` first unless it is already in this conversation.

**Mode**: the request decides first. An amend request → **amend**; "is it ready?" → **check**. Otherwise the target decides: an empty description or an untouched template copy → **author**, in place; a description that holds a story → **amend**.

**The rule:** never proceed without a source of truth. Every sentence traces to the Profile or a source the PM named. A gap becomes a question in the draft, never a plausible fill.

## Author

1. **One ask** for what is missing: the target task, the scope, the sources.
2. **Read at once**: the target task, the Feature Template, the Profile, the named sources. Thin sources → interview first: batches of up to eight questions, recommendation first, marked `proposed — confirm`, covering goal, user flow, permissions, rules, data, side effects, each template edge-case row, dependencies and what is out. Answers land cited "you said, <date>".
3. **Draft** a story that mirrors the template exactly: every numbered section in order with its number and title, every placeholder replaced with a sourced value, template comments never copied. The `STORY:` line carries the full imperative title. Then the `[AC]` subtasks: the happy path, every edge-case row, every business rule, every permission boundary (who is blocked, enforced server-side), plus `Development` / `Testing` / `Bugs`.
4. **Self-check readiness** against the fetched template. Each gap is a numbered question at the top of the draft, filled only from the PM's reply. An epic becomes full sub-stories, one at a time, linked in descriptions.
5. **Stop once**: a `Sources used` block, the full body, every subtask (a template copy's placeholder `[AC]`s each rewritten or listed for deletion), the target task, the open questions.

```output
Story draft → <task>. Sources used: Project Profile (as-of 3 Sep), PRD §4, client call 12 Aug.
Open: 2 questions above — the go is refused while either is blank.
**STOP** — approve to write, edit to change, or decline.
```

6. **On go**: write the description; rename rewritten placeholder `[AC]`s in place and delete the listed ones; create the other subtasks; confirm with the link and counts.

## Amend

Additive only, never a rewrite: `references/amend.md`.

## Check

Fetch the story and its subtasks, judge against the template, print the readiness verdict. Read-only.

- **Announce it** — `Using raftkit-pm:story` in the first reply, once (`raftkit-core:rules`).
