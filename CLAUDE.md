# RaftKit — Project Context

RaftKit is RaftLabs' private Claude plugin **marketplace**: one repo shipping four plugins that package the RaftLabs way of delivering software. The plugins **orchestrate** proven third-party plugins (superpowers, code-simplifier, pr-review-toolkit, security-guidance, find-skills, asana, claude-md-management, remember, frontend-design, playwright/chrome-devtools, expo, neon) — **they rebuild nothing**. Asana is the workflow spine: work enters as a templated user story and exits as a squash-merged PR with QA-verified acceptance criteria.

Methodology of everything RaftKit produces (and of building RaftKit itself): **Spec-Driven + Test-Driven Development, combined.** The spec derives from the approved story; ACs become failing tests; code exists only to turn them green. No spec → no code. No failing test → no implementation. Human-in-the-loop at every gate: story approval, plan approval, PR merge, bug close.

## Sources of truth (ranked)

1. **The Asana story you are implementing** — the scope contract. Its `[AC]` subtasks are the definition of done; its "Out of scope" section is a hard exclusion list.
2. **PRD** — [claude-plugin-marketplace-prd.md](https://drive.google.com/file/d/1nJrBdvUIizJme9ysDAJPNnF0waKrra4R/view) (also in Google Drive → RaftLabs - General → Raftlabs Framework). Architecture, skill specs, guardrails, metrics.
3. **Development board** — Asana project `raftkit` (gid `1216551447756315`): https://app.asana.com/1/1194107417268910/project/1216551447756315 — sections: Problem Statements, Decisions & gates, M1 · Core & marketplace, M2 · raftkit-pm, M3 · raftkit-dev, M4 · raftkit-qa, M5 · Pilot — TicketStop, M6 · Rollout & backlog.
4. **Ashit's AI governance & efficiency protocol** — Asana task `1216375937893602` (protocols 1–5, packaged by the M1 governance-pack story).

## Workflow constants (never cache the content — read live by GID)

- Asana workspace: `1194107417268910`
- Feature Template (format authority): task `1216778429401199`
- Bugs Template (format authority): task `1215260732424760`
- raftkit board: project `1216551447756315`
- Release train / git model: task `1216207700369490`
- Subtask conventions: `[AC] …` acceptance criteria + `Development` / `Testing` / `Bugs`

## Target repo layout

```
.claude-plugin/marketplace.json     # single source of what is installable
plugins/
  raftkit-core/   # house rules, workflow constants, governance protocols pack,
                  # discovery-interview (the shared interview contract)
  raftkit-pm/     # onboarding, brainstorm, user-story, story-skill-generator,
                  # story-readiness, status-update, meeting-decisions,
                  # estimation                                          (Cowork)
  raftkit-dev/    # init, ultrathink, implement, scope-guard, simplify, pr,
                  # fix-bug, ui-creation, setup-project, fix-production-error,
                  # recipes, capability-preflight, docs, hasura   (Claude Code)
  raftkit-qa/     # test-suite, test-run-sheet, file-bug, retest        (Cowork)
```

Each plugin: `.claude-plugin/plugin.json` + `skills/<skill-name>/SKILL.md`. Verify manifest/marketplace schema against the current Claude Code plugin docs before scaffolding — do not trust memory.

## How work happens in this repo

1. **One story at a time.** Pick it from the board (M1 → M2 → M3 → M4 order). Read the story task + all `[AC]` subtasks via the Asana connector before touching anything.
2. **Plan before code.** Restate the scope contract (in scope = the ACs; everything else = out), propose the approach, get approval.
3. **TDD for anything executable** — CI checks, hooks, scripts, validation tooling: failing test first, then green. Skills are mostly markdown; their "tests" are the story's ACs — walk them one by one before calling a story done.
4. **Scope is a hard line.** Nothing beyond the story, nothing missing from it. Improvements you spot go to the board as proposals, not into the diff.
5. **Keep it lean** (the minimalism lens — see `raftkit-dev/simplify`): the best code is the code never written. No speculative abstractions, no over-commenting, skills as short as correctness allows.
6. **Commits/PRs:** small logical commits; conventional-commit titles (`feat:`, `fix:`, `docs:`, `chore:`); one story = one branch = one squash-PR whose title reads as a changelog line.
7. **Close the loop in Asana:** on completion tick the story's `Development` subtask and comment what shipped (PR link). Draft → approve → push applies to every Asana write.

## Non-negotiables

- **Templates are read LIVE** from Asana at run time by every skill — GIDs in constants, never copied content. This repo must contain zero cached template text.
- **Project facts live in Project Profiles**, never in plugins. Plugins stay project-independent.
- **Asana free tier only:** no dependencies, custom fields, milestones, start dates, or approval tasks in anything a skill creates. Express relationships as task links in descriptions.
- **Human gates everywhere:** skills draft, humans approve — story approval, plan approval, PR merge, bug close. No skill ever auto-sends, auto-merges, or auto-files. Exactly one exception, enumerated in `raftkit-core/house-rules` and `write-protocol`: the opt-in `pr-auto-review` CI workflow auto-commits Critical-finding fixes to the PR branch it runs on, never merging. Blocker telemetry is **not** an exception — blockers surface in the admin dashboard, never on an issue tracker.
- **Escalation to founders** on budget, contracts, relationship risk, or client commitments (estimation output is always watermarked "Requires founder review — not a client commitment.").
- **find-skills governance:** suggest → human approves → install; provenance required before anything touches client code.

## Open decisions — parameterize, don't hardcode

| Decision (Asana task) | Impact here |
|---|---|
| Org-wide install path P0 (`1216551001583573`) | Distribution assumptions for pm/qa (Cowork installs) |
| Marketplace repo home (`1216551001744293`) | This repo may move orgs — avoid hardcoded repo URLs |
| Project Profile home (`1216550765662503`) | Where onboarding writes / skills read profiles |
| Spec path + decomposition threshold (`1216550892331152`) | Governance pack ships these as parameters with defaults |

## Build order

M1 (scaffold → core constants → governance pack) → M2 (pm) → M3 (dev) → M4 (qa) → M5 pilot on **TicketStop** (StrikeHoney is the reference implementation, not the pilot) → M6 rollout.
