---
type: llm
weight: 1
---

# Criteria

Score 1 only if ALL hold, else 0:

1. The missing engine is named plainly, with the exact command to install it.
2. The reply says setup carries on with what the repo can have — it does not
   stop the whole run over one missing optional engine, and it does not claim
   to have installed anything.
3. It says which skills will be affected, without listing every installed
   engine back at the reader.
4. No sentence exceeds ~25 words, and none of the banned filler phrases appear
   (utilize, leverage, furthermore, in order to, at this point in time, please
   be advised, kindly, as an AI, great question, certainly, it should be noted,
   facilitate, going forward). No opening throat-clearing.
5. A reader with no RaftKit background knows exactly what to run next.
6. The lines a human reads are wrapped in the output fence (` ```output `).
