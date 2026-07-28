# Bug adapter — docs → Asana bug reports, live template

Files a bug in the organization's **live** Bug Report Template, fetched by GID
at run time — no template body is cached in this plugin. All writes route
through core `asana-formatting` and the `write-protocol` gate.

## What the skill fills, what the human supplies

The skill pre-fills from the specs and generated docs:

- module, affected role/test data, steps to reproduce (from the workflow docs),
  and the **expected result quoted verbatim from the spec** — the spec IS the
  expected behavior;
- acceptance criteria, including adjacent behavior that must keep working.

The human supplies only what the spec cannot:

- the **actual** result, environment/build, evidence, reproducibility, a
  regression check, priority, and any workaround.

Severity (S1–S4) is recommended, not decided; severity and priority are
independent axes.

## Retest, never duplicate

A retest that fails re-tags the **existing** bug task and adds a comment — it
never files a duplicate. The registry (`asana.json` bugs config) holds the bug
task GIDs and the retest tag GID, GIDs only.

## Boundaries

Live template only (no cached body); one bug per defect; every write behind
draft → approve → push; offline behavior matches the story adapter — an artifact
is produced only from a current-run template fetch, with provenance recorded,
or the capability is reported blocked.
