---
name: ultrathink
description: This skill should be used when a developer asks to ultrathink, think this through before acting, make a plan, compare approaches, scope ambiguous work, prepare a technical decision, or plan before implementation. It turns the RaftKit reasoning playbook into a proportionate, evidence-backed thinking and planning flow, orchestrates the verified brainstorming and written-plan providers, labels uncertainty, preserves decision ownership, and returns a verification-aware plan without executing it.
user-invocable: true
---

# ultrathink

This is a RaftKit internal skill for disciplined thinking and planning. Produce
the observable work product of good reasoning — scope, evidence, alternatives,
decisions, risks, and verification — without exposing or requesting private
chain-of-thought or hidden reasoning. Share only decision-relevant rationale and
the evidence the developer needs to review the result.

## The governing rule

**Understand and verify before committing.** Preserve the developer's actual
outcome, distinguish facts from assumptions, compare real alternatives only
where the decision warrants it, and design verification before execution. This
skill itself plans; it does not execute the plan, write to Asana, install
providers, publish, deploy, or spend. It orchestrates the brainstorming and
written-plan engines unmodified (never copying or suppressing a provider's own
method) — both of those engines write a file as part of their documented
process (the brainstorming engine also commits its design doc). Say so
plainly when either runs (see steps 5 and 8 below for the exact seams and
their write behavior); this skill never claims a no-write guarantee it cannot
keep on the providers' behalf.

## Runtime effort

The skill name is also a documented Claude Code keyword: `ultrathink` in
prompt or skill content requests deeper reasoning through an in-context
instruction, while the effort level sent to the API is unchanged. That effect
is intentional here — running this skill deliberately increases reasoning
tokens, latency, and runtime on the turns where it runs. It never initiates
purchases or external spending; the cost is model effort only.

## Choose the mode and depth

State the mode before starting:

- **think** — frame a problem or decision, gather evidence, compare approaches,
  and return a decision record. Stop before a detailed execution plan unless the
  developer asks for one.
- **plan** — turn an already-framed outcome or approved approach into an ordered,
  verification-aware plan.
- **ultrathink** — frame, brainstorm, decide, and plan in one human-gated flow;
  use this when the request does not select a mode.

Use a **proportionate** depth:

- A **small task** has low blast radius, is easily reversible, has few
  interacting parts, and has no blocking uncertainty. Collapse the workflow to
  a goal, one to three steps, and a completion check.
- A **substantial task** is high on any of those four risk factors, crosses a
  public interface, or needs a multi-file/multi-section deliverable. Use the
  complete written contract, evidence labels, alternatives where consequential,
  verification per step, and rollback/recovery.

Re-score depth when evidence changes the scope or invalidates an assumption.

## Run flow

Work in this order. Do not skip ahead from the request to a preferred solution.

1. **Verify provider readiness.** Run
   `raftkit-dev:capability-preflight` for the brainstorm/plan capability. It owns
   readiness, provenance, installation proposals, and the hard stop. Continue
   only when the exact scoped components are ready; never copy their methods as
   a fallback.
2. **Parse the request.** Restate the requested outcome and deliverable; enumerate
   every explicit requirement, reasonable implicit requirement, constraint, and
   exclusion. Resolve blocking ambiguity with one precise question. Label a
   non-blocking interpretation as an assumption and continue.
3. **Classify and calibrate.** Identify the primary/secondary problem category,
   evidence bar, risk factors, irreversible or outward-facing actions, and the
   decision owner. Owner-shaped choices stay with the developer.
4. **Gather and label evidence.** Read supplied material and the relevant current
   artifacts before proposing solutions. Give every load-bearing item one of the
   playbook's six statuses:

   | Status | Use |
   |---|---|
   | **Confirmed** | Directly observed during this task |
   | **Strongly supported** | Independent evidence agrees; not directly verified |
   | **Inferred** | A stated conclusion from confirmed facts |
   | **Assumed** | Adopted without evidence to make reversible progress |
   | **Unknown** | A recognized gap, classified blocking or non-blocking |
   | **Contradicted** | Evidence conflicts; resolve or present both sides |

5. **Open the solution space.** Invoke `superpowers:brainstorming` with the
   confirmed scope, evidence, constraints, unknowns, and success conditions.
   Use its questions and alternatives to challenge the initial framing. It is an
   engine invocation, not text to imitate. Do not let brainstorming silently
   widen the scope contract.
6. **Compare consequential approaches.** For a hard-to-reverse, public-interface,
   data-model, or critical-path choice, compare at least two structurally real
   approaches against criteria fixed before scoring: correctness, user value,
   scope, complexity, risk, reversibility, cost, evidence strength, and
   verification difficulty. Eliminate any option that violates a hard
   constraint. For a cheap reversible choice, take the first sufficient option.
7. **Record the decision.** Recommend the simplest sufficient approach, explain
   why it wins, name the strongest rejected alternative, state the abandonment
   signal, and route preference/authority decisions to their owner. In `think`
   mode, present this decision record and stop at its human gate when no plan was
   requested.
8. **Shape the plan.** In `plan` and `ultrathink` modes, invoke
   `superpowers:writing-plans` with the approved or recommended approach plus the
   scope/evidence record. Then enforce the playbook fields below; Superpowers
   supplies the planning engine while this skill supplies RaftKit's evidence,
   ownership, risk, and verification contract.
9. **Run the pre-delivery check.** Walk every requirement, challenge the plan's
   weakest assumption, confirm each step has evidence and a completion check,
   and run the playbook's Correctness, Scope, Simplicity, Adversarial,
   User-experience, Honesty, and Presentation passes as proportionate to risk.
10. **Plan-approval gate.** Present the plan and wait for explicit approval.
    Silence is not approval. Hand the approved plan back to the calling workflow;
    never execute it from this skill.

## Output contract

For a written plan, preserve every universal field. Keep entries concise, but do
not omit a field silently:

```text
Mode:
Goal:
Current known state:      Confirmed facts and their evidence
Unknowns:                 Blocking vs non-blocking
Assumptions:              Consequence if each is wrong
Scope:                    In / out / constraints
Decision record:          Options, criteria, recommendation, owner decisions
Steps:                    Ordered, verb-first, independently actionable
Dependencies:             Between steps and on external inputs
Risks:                    Mitigation and early-warning signal
Verification:             Per step and end-to-end
Completion criteria:      Requirement-to-evidence definition of done
Rollback/recovery:        For every irreversible or high-blast-radius step
Approval needed:          Exact decision or action awaiting the human
```

Each step should name its dependency, expected effect, verification evidence,
and gate/rollback when applicable. A requirement traceability table is mandatory
for substantial tasks and has only three valid states: `Verified`,
`Unverified — reported`, or `Blocked — reported`.

## Progressive use of the playbook

The bundled source is `references/reasoning-playbook.md` (source snapshot
SHA-256 `1e163383124f526c865b478d9c353ae996cc81eb98120b9f1eb7d8c5f62cb1f6`).
Resolve that path relative to this SKILL.md. Consult it; do not recite it. Find
headings before loading a relevant section, for example:

```bash
rg -n '^## |^### ' references/reasoning-playbook.md
```

- Always use **Section 17** as the before/during/after checklist.
- Use **Section 16** as the spine for a substantial task.
- Load Sections 1–3 for interpretation, classification, and risk.
- Load Section 4 for evidence collection and epistemic labels.
- Load Sections 5–6 for decomposition and plan construction.
- Load Sections 7–8 for hypotheses, alternatives, and decisions.
- Load Sections 9–11 to design execution and verification boundaries.
- Load Sections 12–14 for communication, progress, and recovery.
- Load the matching recipe in Section 15 for domain-specific work.

Do not load the full reference when the compact checklist and one relevant
section are sufficient.

## Boundaries

- Do not expose hidden reasoning. Provide the scope contract, evidence labels,
  compared options, decision record, and verification plan instead.
- Do not use brainstorming as permission for scope creep.
- Do not invent evidence or promote an Assumed/Inferred item to Confirmed.
- Do not decide budget, product direction, external commitments, destructive
  actions, or other owner-shaped choices for the developer.
- Do not treat a plausible plan as a verified plan: falsify it against the
  requirements and current artifact first.
- Do not execute, install, write to Asana, send, merge, deploy, or spend from
  this skill — but do not claim brainstorming/writing-plans wrote nothing when
  they did; disclose their file writes (and brainstorming's commit) as they
  happen.

## Guardrails

- **Plain English out** — every line a human reads follows `raftkit-core/house-rules`' plain-language rules; a house term gets its one-line gloss on first use.
