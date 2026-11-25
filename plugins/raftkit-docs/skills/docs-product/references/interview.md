# Interview

How every question in this skill is asked.

## Rules

- Ask at most three related questions per turn. A question that depends on another's answer waits. Skip moot questions.
- Recommend first. Mark one option `(Recommended)` with a one-sentence reason; give each alternative a "don't pick this if…" caveat.
- Explain what something is, then what is wrong with it, in separate messages.
- Use the developer's words. Gloss every term; prefer a concrete example.
- Push back on a vague answer with one targeted follow-up. Question an answer that describes something nobody needs, once.
- Accept a specific answer and move on. Never grind through a catalog.
- Raise anything forgotten (below) as a question.
- Never guess a fact. Ask it, or record it as an open question.
- Name a contradiction with an earlier answer and ask which holds.
- Recap at each phase end. Say when there is enough.
- Ask up front whether this is a short or an exhaustive pass.

## Vague answer → follow-up

| They say | Ask |
|---|---|
| "Multi-tenant" | By what axis: org, team, workspace or user? What crosses tenants: billing, audit, support? |
| "Has auth" | Provider, methods, session lifetime, refresh, admin separation, impersonation, MFA, reset path? |
| "Standard CRUD" | Bulk actions, import and export, soft or hard delete, history, audit, concurrent edits, restore? |
| "Real-time" | Pushed or polled, latency tolerance, who sees what, reconnect, ordering? |
| "Notifications" | Channels, per-user preferences, quiet hours, throttling, templates per language? |
| "Payments" | Gateway, model, currency, tax, refunds, failed-payment retries, trial? |

## Volunteer when missing

An audit log for privileged actions · notification preferences · API keys and outgoing webhooks when integrators exist · data export and account deletion · rate limits · backup and restore · an admin app with impersonation · locale formats when there is more than one market.

## Edge cases: one catalog, two passes

The short pass walks six buckets: waiting, empty, error, success, limits, default values. The exhaustive pass walks 24 categories:

1 empty states · 2 boundaries and limits · 3 permissions · 4 concurrency · 5 network · 6 data integrity · 7 time-based · 8 deletion · 9 external dependencies · 10 state transitions · 11 rate limiting · 12 idempotency · 13 retries · 14 deduplication · 15 read-after-write · 16 queue back-pressure · 17 cold starts · 18 secrets rotation · 19 partial failure · 20 audit gaps · 21 impersonation traces · 22 multi-region · 23 time skew · 24 mobile and PWA.

Answer each or mark it `N/A — <reason>`. Never fabricate one.
