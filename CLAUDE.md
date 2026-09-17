# RaftKit — Project Context

RaftKit is RaftLabs' private Claude plugin **marketplace**: one repo shipping five plugins that package the RaftLabs way of delivering software. The plugins **orchestrate** proven third-party plugins (superpowers, pr-review-toolkit, code-simplifier, claude-md-management, security-guidance, frontend-design, find-skills, asana, expo, neon) — **they rebuild nothing**. Asana is the workflow spine: work enters as a templated user story and exits as a squash-merged PR with QA-verified acceptance criteria.

Methodology, for what RaftKit produces and for RaftKit itself: **the story is the spec, its acceptance criteria become failing tests, and code exists to turn them green.** Plans are written down and shown, not gated. A run stops exactly once, before anything leaves the session.

## Sources of truth (ranked)

1. **The Asana story you are implementing** — the scope contract. Its `[AC]` subtasks are the definition of done; its "Out of scope" section is a hard exclusion list.
2. **The v2 design** — [docs/specs/2026-09-16-raftkit-v2-design.md](docs/specs/2026-09-16-raftkit-v2-design.md). The architecture, the per-skill budgets, and why each rule exists.
3. **PRD** — [claude-plugin-marketplace-prd.md](https://drive.google.com/file/d/1nJrBdvUIizJme9ysDAJPNnF0waKrra4R/view) (also in Google Drive → RaftLabs - General → Raftlabs Framework). Product intent and metrics; the v2 design supersedes its process detail.
4. **Development board** — Asana project `raftkit` (gid `1216551447756315`): https://app.asana.com/1/1194107417268910/project/1216551447756315

## Workflow constants

GIDs live in exactly one place: `plugins/raftkit-core/skills/rules/SKILL.md`. Read them there; never copy one into another file. `tests/structure.test.sh` enforces it.

## Repo layout

```
.claude-plugin/marketplace.json     # single source of what is installable
plugins/
  raftkit-core/   # rules, working-agreement, telemetry hooks
  raftkit-pm/     # profile, story, estimate, status, meeting, routine     (Cowork)
  raftkit-dev/    # setup, implement, fix, scope-guard, ui, hasura, docs   (Claude Code)
  raftkit-qa/     # suite, run-sheet, bug                                  (Cowork)
  raftkit-docs/   # docs-product, discovery-interview          (opt-in, not installed by default)
```

Each plugin: `.claude-plugin/plugin.json` + `skills/<skill-name>/SKILL.md`. Verify manifest and marketplace schema against the current Claude Code plugin docs before scaffolding — do not trust memory.

## How work happens in this repo

1. **One story at a time.** Read the story task and all its `[AC]` subtasks through the Asana connector before touching anything.
2. **Plan in the open.** State the scope contract (in scope = the acceptance criteria; everything else = out) and the phases, write it to `docs/specs/<branch>.md`, and show it. It is a record, not a gate.
3. **Test first for anything executable** — CI checks, hooks, scripts, validation tooling. Skills are markdown; their tests are the story's acceptance criteria and `tests/structure.test.sh`.
4. **Scope is a hard line.** Nothing beyond the story, nothing missing from it. Improvements go to the board as proposals, not into the diff.
5. **Keep it lean.** Every skill has a word budget in `tests/budgets.json`; raising one is a deliberate edit a reviewer sees. No speculative abstractions, no restated rules, no rationale prose in an instruction file.
6. **Commits and PRs:** small logical commits, conventional-commit titles, one story = one branch = one squash PR whose title reads as a changelog line.
7. **Close the loop in Asana:** tick the story's `Development` subtask and comment the PR link, in the same stop as the PR.

## Non-negotiables

- **One stop per run.** A skill drafts everything, then stops once before anything leaves the session: an Asana write, a PR, a Sheet write, a message. An explicit go pushes what was shown; an edit re-presents the draft; silence pushes nothing. A run that writes nothing has no stop.
- **No skill ever auto-sends, auto-merges, auto-files or auto-completes.** Merging a PR, ticking `[AC]` or `Testing`, and closing a bug stay human. Exactly one exception: the opt-in `pr-auto-review` CI workflow commits Critical-finding fixes on the PR branch it runs on and never merges, with its boundary in `raftkit-dev/skills/setup/references/pr-auto-review.md`, not extensible by analogy. Blocker telemetry is not an exception — a hard stop is reported to the admin dashboard, never filed on an issue tracker.
- **Templates are read live** from Asana by GID, once per run. This repo holds zero cached template text.
- **Project facts live in Project Profiles**, never in plugins.
- **Asana free tier only:** no dependencies, custom fields, milestones, start dates or approval tasks. Relationships are task links.
- **Rules live in one place.** `raftkit-core:rules` is inherited, never restated. A role skill that repeats the gate, the free-tier list, the live-fetch rule or the plain-language guardrail fails the structure suite.
- **Escalation to founders** on budget, contracts, relationship risk or client commitments. Estimation output always carries "Requires founder review — not a client commitment."

## Open decisions — parameterize, don't hardcode

| Decision (Asana task) | Impact here |
|---|---|
| Org-wide install path P0 (`1216551001583573`) | Distribution assumptions for pm/qa (Cowork installs) |
| Marketplace repo home (`1216551001744293`) | This repo may move orgs — avoid hardcoded repo URLs |
| Phase file limit (`1216550892331152`) | Rule 2 of the working agreement ships two files as its value |

## Pending with the founders

- **The working agreement** (`raftkit-core/skills/working-agreement/references/working-agreement.md`) replaces protocols 1–5 and needs Ashit's sign-off before the release to `main`. Its sha256 is pinned in `tests/budgets.json`, so any edit is deliberate.
- **Unattended Asana writes** by a scheduled routine (`raftkit-pm:routine`) are not switched on until the founders record that decision.
