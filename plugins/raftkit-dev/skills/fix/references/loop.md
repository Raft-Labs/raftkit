# The loop, in detail

## Order is load-bearing

Intake gate → repro observed red → smallest fix → whole suite green. The fix step is unreachable until the red is observed. Each gate protects the next: no contract means no assertion to make red; no red means no proof the fix addressed this defect.

## Scope is the `Done when`, nothing else

`scope-guard` audits the diff against the `Done when` checklist exactly as it audits a feature diff against acceptance criteria. Adjacent ugly code near the defect is the classic temptation: it is out of scope unless a `Done when` item covers it. Flag it, do not fold it in.

A developer-stated `Done when` carries the same force as a QA-written one. That is why the reported path is not a way to ship an unbounded diff without a ticket.

## Environment is stated, never assumed

The repro runs in the environment that was named. On the ticketed path that is the task's environment block, not the developer's laptop as a silent substitute. On the reported path it is whatever the developer named, which may well be local, once said. The failure this guards against is silence. If the stated environment cannot be stood up, that is a cannot-reproduce hand-back, not a quiet switch.

## Commits

One branch. The repro-test commit and the fix commit are separate, the fix using the `fix:` type and reading as a changelog line. One squash PR, human merge.

## Withholding a link buys nothing

A developer with an incomplete QA ticket who omits the link would otherwise land on the reported path and escape both the bounce and the mandatory `Fixed in build`. If a task exists, its obligations apply in full.

## The hand-back carries the docs result

Both paths report the documentation outcome from `raftkit-dev:docs` with its evidence: the updated files, or `Docs: not impacted — <reason>` naming the change set examined. A bug fix never rewrites product documentation by default; it does when the documented contract was wrong or the intended behaviour changed inside the `Done when`.
