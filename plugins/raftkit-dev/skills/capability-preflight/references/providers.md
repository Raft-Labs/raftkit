# Provider registry — verified capability seams

The single source of which engine serves each raftkit-dev capability, with the
exact component each provider actually ships. Component semantics below were
**verified by isolated-config installation on 2026-07-21** (see
`tests/capability-preflight-network.test.sh`); a claim in this table is either
verified evidence or marked as discovered-at-verification — never memory.

Registry contract: one row per capability. `Policy` values: `required (declared)`
(a plugin.json dependency, resolved only by a human-approved RaftKit
install/update), `required (core-inherited)` (owned by raftkit-core, not
classified here), `recommended`, `conditional: <when>`, `optional`. The
classifier (`scripts/classify.mjs`) parses this table verbatim.

| Capability | Provider | Marketplace | Components | Policy | Ownership |
|---|---|---|---|---|---|
| brainstorm-plan-tdd-debug-verify | superpowers | claude-plugins-official | skills: brainstorming, writing-plans, test-driven-development, systematic-debugging, verification-before-completion | required (declared) | raftkit-dev |
| claude-md-merge | claude-md-management | claude-plugins-official | skills: revise-claude-md, claude-md-improver | required (declared) | raftkit-dev |
| simplification-engine | code-simplifier | claude-plugins-official | agent: code-simplifier (dispatch by scoped type code-simplifier:code-simplifier — the bare agent name is ambiguous while pr-review-toolkit is enabled, which ships its own code-simplifier agent; runtime-verified 2026-07-21) | required (declared) | raftkit-dev |
| security-feedback | security-guidance | claude-plugins-official | hooks: SessionStart, UserPromptSubmit, PostToolUse, Stop (hook-only; no invocable component — the seam is "hooks active, Stop-review runs") | required (declared) | raftkit-dev |
| pr-review | pr-review-toolkit | claude-plugins-official | inventory-at-verification (observed 2026-07-21: skill review-pr; agents code-reviewer, silent-failure-hunter, code-simplifier, comment-analyzer, pr-test-analyzer, type-design-analyzer — its code-simplifier agent collides by bare name with the code-simplifier plugin's; all agent dispatch uses scoped plugin-name:agent-name types, so downstream skills must name the scoped type, never the bare name) | required (declared) | raftkit-dev |
| asana-connectivity | claude.ai Asana connector or an approved asana plugin | — | connector-or-plugin (authentication is a human/setup gate) | required (core-inherited) | raftkit-core (inherited) |
| sheets-connectivity | claude.ai Google Sheets connector or an approved sheets plugin | — | connector-or-plugin (authentication is a human/setup gate) | conditional (core-inherited): raftkit-qa suite Sheet sync | raftkit-core (inherited) |
| pr-annotations | coderabbit | claude-plugins-official | skills: coderabbit-review, autofix | optional (not in use — RaftLabs decided pr-review-toolkit only, Asana 1216551482947559, closed 2026-07-14) | raftkit-dev |
| ui-implementation | frontend-design | claude-plugins-official | skill: frontend-design | baseline-required | raftkit-dev |
| ui-polish | impeccable | impeccable | skill: impeccable | required-available (UI work; never replaces frontend-design) | raftkit-dev |
| browser-validation | playwright | claude-plugins-official | browser tools | conditional: browser-visible ACs | raftkit-dev |
| mobile-stack | expo | claude-plugins-official | stack pack | conditional: mobile scope | raftkit-dev |
| neon-db | neon | claude-plugins-official | database skills/tools | conditional: Neon usage detected or profiled | raftkit-dev |
| hasura-migrations | raftkit-dev:hasura | — | skill: hasura (migration/metadata/permission workflow) | conditional: Hasura project detected (config.yaml / metadata / migrations dir) | raftkit-dev |
| encrypted-env | envx | — | agent skill: envx | baseline-required | raftkit-dev |
| memory | claude-mem | — | agent skill: claude-mem | baseline-required (exact provider; remember is never a substitute) | raftkit-dev |
| memory-alt | remember | — | agent skill: remember | optional (standalone; never a substitute for claude-mem) | raftkit-dev |
| skill-discovery | find-skills | — | agent skill: find-skills | baseline-required (the skill plus its Skills CLI seam: npx skills find / add / check / update; suggestions only, never auto-installs) | raftkit-dev |
| continuous-observation | task-observer | — | agent skill: task-observer | baseline-required (CC BY 4.0 — copy with attribution; activation instruction merged into the project instruction file) | raftkit-dev |

## Connector rows

Two rows name a **connector**, not a plugin: `asana-connectivity` and
`sheets-connectivity`. A connector cannot be checked the way a plugin can —
`claude plugin list` does not see it, and its authentication is a human setup
step. Both are therefore marked core-inherited, and the classifier reports them
as not classified here rather than inventing an install command for them. They
are listed so the seam is written down and a run can name what it needs, not so
a script can prove it.

`sheets-connectivity` is the seam `raftkit-qa`'s `test-suite` needs for its Sheet
sync. It was **not** part of the 2026-07-21 installation sweep below and carries
no verification evidence: whether QA's Cowork setup exposes a Sheets connector at
all is still the open PRD question §10.8. Until that is answered, `test-suite`'s
own rule stands — if the connector is absent from the run's environment, stop and
name it, never assume it.

## Verification evidence (2026-07-21, isolated CLAUDE_CONFIG_DIR)

All five `required (declared)` candidates passed marketplace resolution,
installation, enablement, and component-inventory verification. The upstream
marketplace publishes **zero** `{name}--v{version}` release tags, so the
declared dependencies are **unversioned** — a semver range may be added only
when observed tags make it meaningful.

A verification failure for a candidate is recorded here with its evidence and
the candidate stays undeclared. A **transient** failure (network, auth,
marketplace unreachable, CLI missing) is never recorded as a provider fact —
re-run `RUN_NETWORK_TESTS=1 bash tests/capability-preflight-network.test.sh`
in a healthy environment instead.
