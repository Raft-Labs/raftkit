# Engine seam — who does what

`story-driver` orchestrates; it rebuilds nothing. Three engines plus RaftKit's
own core skills each own a slice. Reach for them by name — do not reimplement
their guidance inline.

## plugin-dev — scaffolding + QA

Owns the plugin/skill file structure and the structural QA gate.

- **`plugin-structure` skill** — directory layout, `plugin.json` manifest rules,
  `${CLAUDE_PLUGIN_ROOT}`, auto-discovery. Consult before creating any plugin dir.
- **`skill-development` skill** — how a plugin skill's SKILL.md is structured
  (frontmatter, progressive disclosure). Consult before creating a skill dir.
- **`create-plugin` command** — the full guided scaffold. Use it only when the
  target plugin is still a bare stub *and* the story calls for more than a single
  skill; for adding one skill to an existing plugin, scaffold the skill dir
  directly per `skill-development`.
- **`plugin-validator` agent** — validates manifest + structure + security.
- **`skill-reviewer` agent** — reviews SKILL.md quality + description triggering.

## skill-creator — authoring + triggering

Owns skill *content* quality and description optimization.

- Authoring guidance (use this on every build): progressive disclosure (SKILL.md
  < ~500 lines, push detail into `references/`), imperative instructions, explain
  the *why*, a `description` that is third-person and specific enough to trigger
  reliably.
- **`run_loop.py` / the eval-viewer loop are NOT part of a story build.** They are
  a periodic, human-in-the-loop co-development loop for tuning a skill's
  description and benchmarking it over many iterations — disproportionate for a
  single spec-driven build. For triggering quality during a build, rely on the
  authoring guidance and the `skill-reviewer` agent. Reach for `run_loop.py` only
  as a separate, deliberate optimization pass on a skill that already exists.
- **Do NOT use `package_skill.py`** — that produces standalone `.skill` ZIPs.
  RaftKit skills live in-place under `plugins/<plugin>/skills/<name>/`; nothing in
  this repo ships as a `.skill`.

## raftkit-core — the house rules (consult skills, `user-invocable: false`)

- **`workflow-constants`** — Asana workspace + template GIDs, the live-template
  fetch protocol, and the exact stop messages. Never guess a GID; never cache a
  template body.
- **`house-rules`** — human gates (story / plan / PR-merge / bug-close), Asana
  free-tier constraints, escalate-to-founders triggers, find-skills governance.
- **`write-protocol`** — the draft→approve→push gate for every outward write, and
  the Asana `html_notes` rules (single body root, no `<p>`, attributes only on
  `<a>`, escape `&`/`<`/`>`).

## The repo's own gate (hard, non-negotiable)

- **`scripts/validate.sh`** (`BASE_REF=main`) — runs `claude plugin validate`,
  asserts no marketplace↔manifest **description drift**, and enforces the
  **version-bump gate**: any changed `plugins/<plugin>/` dir must also bump its
  `plugin.json` version, anchored at the merge base. Touch a plugin → bump it.
- **`tests/validate.test.sh`** — the self-test of that gate.

`story-driver` itself lives in `.claude/skills/` (outside `plugins/*`), so
editing the skill never trips the version gate — but the skills it *builds* do.

## The seam in one line

`plugin-dev` makes the files exist and pass structural validation →
`skill-creator` makes the content good and triggering reliable →
`raftkit-core` keeps every Asana write and gate honest →
`validate.sh` is the wall the PR must clear.
