# The fail path — evidence, the Retest Failed tag, and the reopen loop

This is the fail side of a retest: any "Done when" item (or adjacent-regression
check) failing. The close and bounce paths, the sheet, and the mandated close
string live in `retest-run.md`; this file owns the fail path only.

## Evidence before tag — the core guarantee

The **Retest Failed** tag is never applied without fresh evidence attached. The
order is fixed, and it is not negotiable:

1. **Gather fresh evidence.** New proof from *this* retest run — a new Jam link
   (the ⭐ tier) or the errors quoted **verbatim** (console text, failed network
   requests: method, URL, status, response). Never the bug's original evidence
   reused; never paraphrased. If a value must be redacted for secrets, mark the
   redaction — never silently reword.
2. **Itemize the failures.** Which sheet items failed, each named, each tied to its
   evidence. A bare "still broken" is not a failure record.
3. **Only then apply the tag** and comment.

A tag with no evidence behind it is exactly the failure this skill exists to
prevent: a reopen no one can act on and no one can trust. Evidence first, always.

## The fail comment and returning the bug

On a failed retest, after evidence is gathered and failures itemized:

- Post a comment carrying the **fresh evidence + the itemized failures** (which
  items failed, on which build, with the proof).
- Apply the **Retest Failed** tag (resolution below).
- **Return the bug to the dev** — reopened, so the dev's `fix-bug` loop (M3) picks
  it up again. Retest does not fix and does not decide the refix's priority (that
  is PM/dev triage); it verifies and hands back.

All of this goes through draft → approve → push (`raftkit-core/write-protocol`);
QA approves the comment and the tag before either reaches Asana.

## The Retest Failed tag is project-specific

The tag's name belongs to the project, not to this skill — resolve it at run time
from the bug's project, following the **priority-tag pattern owned by
`raftkit-qa/file-bug`**: never hardcode a tag name (project facts live in Project
Profiles, never in this plugin).

Where retest **deliberately diverges** from file-bug: file-bug asks QA before
creating a missing priority tag. Retest's own rule — mandated by the retest
story — is **create-or-ask, never silent failure**: if the project has no Retest
Failed tag, either create it or ask QA which tag to use, but never let the tag step
fail silently. A reopen that isn't tagged isn't tracked. This divergence is
mandated by the retest story, not inherited from file-bug.

## Why the tag matters — the reopen-rate metric

The Retest Failed tag is how reopened bugs are counted: its total feeds the bug
reopen-rate metric (PRD §8). That is the measurement reason a failed retest is
tagged rather than just re-commented — an untagged reopen is invisible to the
metric, so "still broken after the fix" gets relitigated instead of measured.
