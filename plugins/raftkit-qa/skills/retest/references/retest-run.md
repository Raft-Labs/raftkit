# Retest run — sheet, build/environment, outcomes, and the mandated strings

This file is the single source of every fixed string this skill emits on the
close and bounce paths, plus how the retest sheet is assembled and which build it
runs against. The fail path (tag + evidence) lives in `tag-and-evidence.md`;
nothing is duplicated across the two.

## Building the retest sheet

The retest sheet is the pass list for this one bug. It is built from two sources
in the bug, and it is the **whole** definition of done — the original repro step
is one item in it, never the entire test:

- **The full "Done when" checklist** — every acceptance item the bug carries.
  These come straight from the bug, which `raftkit-qa/file-bug` required at filing
  time. Each becomes one sheet item, retested independently.
- **Adjacent-regression items** — the other roles, plans, or flows the bug names
  in its body. A fix can pass its own checklist and break a neighbour; those
  neighbours are retested too, each as its own item.

Every item records a pass/fail and, on fail, its evidence (see
`tag-and-evidence.md`). The counts drive the close comment: **N** = the number of
"Done when" items, **M** = the number of adjacent-regression checks.

## The build and environment to retest on

Retest runs on the **stated build** — the value the dev filled into
"Fixed in build ___" — in the bug's **stated environment**. The environment
defaults to the bug's original one (the environment block file-bug captured); use
that unless QA names a different one for this run.

Do not retest a different build than the one stated. Verifying build 41 when the
dev claims a fix in build 42 proves nothing about the fix.

## The three off-ramps (with their exact messages)

### Missing build — bounce to the dev unretested

A fix handed back with **"Fixed in build ___"** empty cannot be retested — there
is nothing to verify against. Do not retest; bounce to the dev with:

```
Can't retest — "Fixed in build ___" is empty. The retest contract needs a build to test against. Fill the build number and hand it back.
```

### Stated build unavailable — bounce naming build + environment

The build is stated but cannot be obtained in the environment to retest in. Do not
substitute another build; bounce, naming both:

```
Can't retest — build <build> isn't available in <environment>. Provide build <build> in <environment>, or tell me which environment to retest it in.
```

Fill `<build>` with the stated build and `<environment>` with the stated (or
QA-named) environment.

### Missing "Done when" checklist — route back through file-bug

The "Done when" checklist is the retest contract; with none, there is no pass list
to run. Do not invent one. Route back through `raftkit-qa/file-bug` discipline so
the checklist is added to the bug, then re-run retest:

```
Can't retest — this bug has no "Done when" checklist, which is the retest contract. Add it via file-bug, then re-run retest.
```

## Close — the verbatim confirmation

When **every** item on the sheet passes on the stated build, close the bug (only
QA closes) and post this confirmation comment, filled with the run's numbers and
build — emit it exactly, only after the write actually lands:

```
Closed — all N done-when items + M regression checks green on build X
```

`N` = "Done when" items, `M` = adjacent-regression checks, `X` = the stated build.
Never post it as an optimistic guess before the close and comment are written.

## Why the whole checklist, not just the repro step

The Bugs Template separates Expected Result from "Done when" precisely so retest
covers the whole definition of done, adjacent behaviour included — this rationale
is stated by the **retest story**, not read from the template body (the template is
fetched live only for its current field shape, never quoted from here).
