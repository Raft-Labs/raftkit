# Filing — evidence, fields, checklist, placement

## Jam → template fields

The live template's section labels are authoritative; these name the intent.

- Device and OS, browser and version, URL or screen, timestamp → Environment.
- User events in order → Steps to Reproduce, from a known starting point.
- Console errors and failed requests (method, URL, status, response) → Actual Result, verbatim.

**Verbatim is non-negotiable.** Error text is pasted exactly as captured; a redaction for a secret is marked, never silently reworded. A recording with no errors is filed on steps and video, and says so.

## Evidence tiers

The template names the tiers and their order. A Jam link is ⭐, the default. Below it, mark the tier and require every field of the template's environment block from QA. Invalid link or no access → say which and the fix; never invent device or console data.

## Judgment fields, proposed in the draft

| Field | Proposal rule |
|---|---|
| Severity | how bad, on the template's scale, from the evidence |
| Priority | how urgent, on the template's scale; may diverge from severity (a typo in the hero copy is low severity, high priority) |
| Reproducibility | `Always` only when the recording shows it; otherwise `⚠️ assumed until confirmed` |
| Expected result | quoted from the story's copy or `[AC]` when it exists; otherwise `⚠️ assumed until confirmed`, which blocks the write |
| `Done when` | one checkable line per acceptance item, drawn from the story's `[AC]`s and the failing step; always `⚠️ assumed until confirmed` because it is the retest contract; the go is refused until QA confirms it |

## Title

`[Platform][Severity] short what + where`. A title missing a bracket or the where fails the checklist.

## Pre-submit checklist (every item, before a go is accepted)

Type, Severity and Priority set · Environment complete per the template's block · role and test account named · steps reproduce from a clean start · Expected and Actual both stated · at least one piece of evidence · `Done when` confirmed. An unchecked item rides in the draft as a named question; the go is refused until it is answered, so nothing incomplete is filed.

## Placement

A subtask under the target story's `Bugs` subtask, tagged with the project's priority tag for the chosen priority (resolved from the project, never hardcoded; none → ask, never create silently). One bug per ticket. A link to the failing run-sheet step goes in the body.
