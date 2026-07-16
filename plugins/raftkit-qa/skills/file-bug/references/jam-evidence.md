# Jam evidence extraction

Jam is the ⭐ tier because one recording auto-captures the console, the network,
the exact steps, and the device context — the four things a manual bug report
usually gets wrong. When a Jam link is present it is the default source; the
skill reads it and pre-fills the mechanical fields so QA only supplies judgment.

## What to pull, and where it lands

Map the Jam data onto the live template's own section labels (the names below
describe intent — the authoritative labels come from the live template, never
from here):

- **Device / OS, browser + version, URL or screen, observed-at timestamp** →
  Environment.
- **User events** (clicks, navigations, inputs, in order) → Steps to Reproduce,
  written deterministically from a known starting point.
- **Console errors + failed network requests** (method, URL, status, response)
  → Actual Result, **quoted verbatim**.

## The verbatim rule (non-negotiable)

Console and network error text is pasted exactly as Jam captured it — never
summarized into prose, never reworded. The exact string is what a developer
greps for and what lets them line the failure up against server logs. If a value
must be redacted for secrets, mark the redaction explicitly; never silently
reword.

## Streaming what was found

While extracting, report progress so QA sees the evidence forming — e.g.
"3 console errors, 2 failed requests captured." If the Jam captured no errors,
proceed with steps and video only and say so plainly; do not manufacture an
error that was not recorded.

## Evidence tiers

Higher tier = faster fix. The live template defines the tiers and their exact
names; apply them in its order of preference. A **Jam link is the top (⭐) tier**
and the default whenever a link is present. When there is no Jam, drop to the
next tier the template offers — typically a screen video with console/network
captures, or at minimum screenshots with pasted console errors and failed-request
details (method, URL, status, response).

**No-Jam fallback:** accept the lower tier, **mark which tier** it is in the
Evidence section, and require QA to fill the manual environment block the template
demands (device, browser + version, URL/screen, build/version, observed-at, and
any other fields it lists) — the block Jam would otherwise have filled. The bug
is still fileable; it is just marked as lower evidence so the gap is visible, not
hidden.

## Reproducibility default

Set Reproducibility to "Always" **only if the Jam actually shows it**; otherwise
ask QA rather than assuming.

## Errors and splits

- **Invalid Jam link / no access** → name which of the two it is and the fix; do
  not fabricate device or console data to fill the gap.
- **Two unrelated defects in one recording** → split them (see
  `filing-rules.md`): two drafts, two tickets. One bug per ticket, enforced.
