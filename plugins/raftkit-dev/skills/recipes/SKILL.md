---
name: recipes
description: This skill should be used whenever RaftKit's implement or ui-creation skills plan or build a common non-core feature that RaftLabs has already decided once — an in-app auto-update prompt, a review-at-happy-moment ask, or platform-native mobile UI structure — or need RaftLabs' standard web-stack defaults. It is the source of truth for those baked-in decisions and the three v1 feature recipes, plus the rules for how a recipe is applied, how a Project Profile override or a story conflict is resolved, and what to do when no recipe exists. Consult it before designing any such feature from scratch so solved problems are dropped in, not re-invented and re-bugged.
user-invocable: false
---

# RaftKit Feature Recipes & Baked-in Defaults

Stop re-deciding solved problems. This is RaftLabs' library of standard web/mobile
decisions plus three ready feature recipes. `implement` and `ui-creation` read this
content and apply it **verbatim** when a story asks for one of these features —
instead of designing it from scratch and re-introducing the same bugs on every
project.

This skill ships **content and rules, not code**. A recipe is a pattern the
implementing skill follows; nothing here is a component library or a package to
install (see "Scope").

## What a recipe is

A recipe = **pre-written story pattern + implementation pattern + its own ACs +
a version marker**, versioned in raftkit-dev and changed only by PR. Each recipe
is **stack-pack aware**: it names a web variant (React / Next.js) and a mobile
variant (Expo). The RaftLabs stack is fact — React/Next.js web, Expo mobile,
Node.js and AWS Serverless backend.

## The v1 content (exactly this — no more)

| Content | File | Applies when |
|---|---|---|
| Web-stack defaults | [references/web-defaults.md](references/web-defaults.md) | any web story consults defaults |
| Recipe · in-app auto-update | [references/recipe-in-app-auto-update.md](references/recipe-in-app-auto-update.md) | a story asks users be prompted onto the latest version |
| Recipe · review-at-happy-moment | [references/recipe-review-at-happy-moment.md](references/recipe-review-at-happy-moment.md) | a story adds a review / rating ask |
| Recipe · platform-native UI structure | [references/recipe-native-ui-structure.md](references/recipe-native-ui-structure.md) | a mobile story builds screens |

## When a recipe applies

A recipe is applied **only when the story asks for that feature** — recipes respect
the story's scope. A story adding a payment flow does not pull in the review recipe
just because the recipe exists. When the story does ask for a recipe's feature,
apply the recipe's pattern **verbatim** rather than re-planning the feature from
scratch; the plan then **names which recipes were applied**.

## Resolution order (what wins)

When defaults, a recipe, the story, and a Project Profile all speak to the same
decision, resolve in this order — highest wins:

1. **Project Profile override.** A project may override a default or a recipe
   **choice only** through an explicit entry in its Project Profile. Silent
   per-repo divergence is not allowed. When an override applies, it wins and the
   **deviation is noted in the plan**. (Where the Project Profile lives is owned
   by onboarding/core — reference it abstractly; never hardcode a path.) A Project
   Profile overrides recipe/default *choices* only — it **never** overrides an
   explicit story requirement or `[AC]`. If a Profile entry contradicts the story,
   the **story wins** and the clash is surfaced exactly like a story-vs-recipe
   conflict (below). The story is source-of-truth #1.
2. **The story's explicit requirements.** On a **direct conflict between the story
   and a recipe, the STORY wins** — the recipe never overrides an explicit story
   requirement. Surface the conflict to the PM as a **possible recipe update**, so
   the recipe can be corrected by PR if the story revealed a better default.
3. **The recipe / default itself**, as the fallback when nothing above speaks.

A Project Profile override and a story conflict are different events: the first is
a sanctioned, pre-declared deviation (note it, move on); the second is an
unexpected clash the PM should see (story wins, flag it).

## When no recipe exists

A story may ask for a feature no recipe covers. **Never block on a missing recipe.**
`implement` proceeds normally, designs the feature for that story, and **proposes
the pattern as a future recipe** (a board proposal, not a change to this diff — new
recipes are added post-pilot by PR).

## Scope

- **Exactly three recipes + the web defaults** in v1. Do not add a fourth here.
- Recipes are **patterns, not packages** — no shared UI component library.
- **No store-submission automation.**
- New recipes and default changes go through **PR to raftkit-dev**; project-level
  deviations go in the **Project Profile**, never into a plugin.

## Guardrails

- **Plain English out** — every line a human reads follows `raftkit-core/house-rules`' plain-language rules; a house term gets its one-line gloss on first use.
