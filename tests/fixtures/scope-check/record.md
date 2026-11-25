# feat/42-badge — plan record

Story: https://app.asana.com/0/0/42 (fixture)

## Acceptance criteria

<!-- plan-table sha256: {{HASH}} -->
| # | [AC] | Test file | Source files |
|---|---|---|---|
| 1 | [AC] A member sees their tier badge | `src/badge.test.ts` | `src/badge.ts` |
| 2 | [AC] A guest sees no badge | `src/guest.test.ts` | `src/guest.ts`, `src/shared/` |

Do NOT build: tier upgrades, badge animations.

## Codebase map

Badges render from `src/badge.ts`; guest handling lives in `src/guest.ts`, with helpers under `src/shared/`.
