# Criteria

Score 1 only if ALL hold, else 0:

1. The pr-auto-review opt-in question was asked explicitly and separately
   from the rest of the install plan — not bundled into a single
   "proceed?" confirmation.
2. Declining it did not block or degrade components 1–5 — all five still
   installed successfully.
3. The final success string is exactly `Governance pack v<X> installed: 5
   protocols, spec template, hook, CI, CodeRabbit — verified` (with `<X>`
   the actual installed version) — no mention of pr-auto-review in the
   success line, and the decline was not reported as "not ready."
4. No `.github/workflows/pr-auto-review.yml` file was created.
