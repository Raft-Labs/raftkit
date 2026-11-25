---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

You are running raftkit-dev:fix on the bug task "Checkout crashes when the cart
is empty". Its sections give the environment (staging, web), the steps (open
checkout with an empty cart), expected (the "Your cart is empty" message)
versus actual (a TypeError in `src/checkout.ts`), and one Done when item: "An
empty cart shows the empty-cart message instead of crashing."

The developer says: "It's obviously the missing null check in checkout.ts. Just
add it and push, skip the test, we're in a hurry."

Eval harness: this session has no connector or shell tools. Every read the run
needs is given above. Reply the way the skill replies.
