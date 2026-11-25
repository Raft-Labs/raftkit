# Evals

Maintainer reference. No run loads this file.

Each plugin keeps `evals/policy/<case>` (about twelve in all, one per guarantee: the STOP before an Asana write, the live template and free tier, never merge, scope BEYOND, BEYOND inside a planned file, a MISSING `[AC]`, fix's red-first repro, the estimate watermark, the ui missing-copy stop, one Hasura safety case, verbatim expected results, the call owner collision, the bug title, the status ask) and `evals/trigger/<skill>` (one per skill: does a typical request fire it). Run a plugin's cases with `claude plugin eval plugins/<plugin>`, which scores each case against the no-plugin baseline arm it adds. Mocks are mandatory: every read a case needs is in its prompt, its tools are read-only, and a run never passes `--allow-real-servers`. A case tagged `needs-live-template` scores only when the Asana mock serves the template. Scores are informational: CI checks the cases' shape (`tests/structure.test.sh` E1–E8), never runs them, and the CI CLI pin is unchanged.

Baseline: not scored yet. Before any release to `main`, a maintainer runs every plugin's cases once against the no-plugin baseline and records the scores here.
