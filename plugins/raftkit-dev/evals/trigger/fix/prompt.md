---
max_turns: 4
allowed_tools: [Read, Glob, Grep, Skill]
---

Checkout is broken on staging. Here is the trace from Sentry: TypeError: cannot read properties of undefined (reading 'code') at PaymentForm.onDecline (PaymentForm.tsx:88).
