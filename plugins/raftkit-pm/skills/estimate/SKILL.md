---
name: estimate
description: Estimate a whole feature list into FE, BE and QA hour ranges for a proposal — "estimate this feature list", "hours for the proposal", "break this scope into FE/BE/QA hours". Takes the list as pasted, a document or a Sheet, widens where knowledge is thin, writes one Sheet after one stop. Hours only. One story: raftkit-pm:story size.
user-invocable: true
---

# estimate

A feature list → FE, BE and QA hour ranges per feature, totalled, in one Google Sheet. `raftkit-core:rules` apply: the watermark opens every output; the approval chain follows whenever numbers appear.

**The unit is a feature**: one line of the PM's list, one row; never a criterion or a task invented while reading. One story is `raftkit-pm:story` sizing: redirect and stop.

## Inputs, in one ask

The feature list (pasted, a document, or a read-only source Sheet whose feature column is found from the header and named back), the **implementing developer or team lead** who vets the numbers (no name, no numbers), and where the estimate Sheet lives (always a Sheet of its own). The Profile is read for ⚠️ Partial areas; none → say so and widen.

## Run

1. **Read at once**: the list, the Profile, and any Asana story a feature names (its gaps widen, never block). Blank, struck-through or out-of-scope rows are skipped and counted.
2. **Estimate every feature**: FE, BE and QA as low–high hour ranges; no work on a discipline is a stated `0`; at least one named assumption each; widen where the Profile is ⚠️ Partial or silent, absent, or the feature is one thin line. The range absorbs its drivers; nothing hangs beneath it as `+8 h`. Cross-cutting work attaches to the features that need it or becomes its own agreed line.
3. **Total** lows to lows and highs to highs, never a midpoint; deduplicate the assumptions; state the feature count. Do the arithmetic and check it before showing it.
4. **Stop once** with the draft in the shape below plus the Sheet it will write.
5. **On go**, write the Sheet per `references/sheet.md` and report the link. Sheet unreachable → the estimate stands in chat and the exact access fix is named.

```output
Requires founder review — not a client commitment.
AI estimate → vetted by <implementing developer> → approved by Nirav or Ashit → only then shared with the client.

Estimate — <project>, 3 features.
Source: <sheet>, column "feature". 1 row skipped (out of scope).

- Rate-card tagging — FE 6–10 h · BE 4–7 h · QA 3–5 h — assumes tags are additive.
- Loyalty tier rules — FE 8–12 h · BE 12–20 h · QA 5–8 h — ⚠️ widened: tier rules unwritten.
- Guest check-in — FE 10–16 h · BE 0 h · QA 4–6 h — assumes the check-in API exists.

Total: 52–84 h — FE 24–38 h · BE 16–27 h · QA 12–19 h.
Assumptions: no migration of live rate cards. No Profile, so every range is widened.
**STOP** — approve to write the Sheet, edit to change, or decline.
```

Never a single number, never days, never a feature the list did not name, never pricing or dates.
