# Recipe · review-at-happy-moment

**Version: v1**

Ask for a review at the moment the user is happiest — right after a success — and
never pester a user who already rated.

## Applies when

The story adds a review ask, a rating prompt, an app-store review request, or an
NPS-style solicitation.

## Story pattern

> As the product, I want to ask for a review right after a user's first clear
> success, so that ratings come from happy users and no one is asked twice.

- **Happy moment:** the prompt fires at the story's **defined happy moment** — e.g.
  first successful transaction, first completed booking, first shared result. The
  story names the moment; the recipe supplies the mechanism.
- **Never re-ask a rater:** a user who has rated is **never asked again**. This
  guard is authoritative — it holds across sessions, devices, and reinstalls,
  which is why rating state lives on the backend, not only on the device.

## Implementation pattern

Rating state is **synced to the backend**, keyed to the user, so "has this user
rated?" survives reinstalls and is consistent across a user's devices.

- On the happy-moment event, check backend rating state for the user. If already
  rated → **do not prompt**. If not → prompt, and on a rating record the new state
  to the backend.
- **Side effect (documented):** the review prompt **syncs rating state to the
  backend** (read before prompting, write after rating). Treat a rating-state
  write as best-effort-durable; never show the prompt to a user the backend says
  has already rated.
- Optionally throttle re-prompts for users who dismissed without rating, per the
  story — but a user who *rated* is out of the pool permanently.

### Web variant (React / Next.js)

Happy-moment event fires client-side; rating state is read/written through the
app's API to the backend before/after showing an in-app rating UI.

### Mobile variant (Expo)

Same backend rating-state gate, then hand off to the OS native review flow (e.g.
StoreReview) once the user opts in. The OS may rate-limit its own prompt; the
backend "already rated" guard is what guarantees no re-ask on RaftLabs' side.

## Acceptance criteria (this recipe's own)

- The prompt fires at the story's defined happy moment, not arbitrarily.
- Rating state is **synced to the backend**, keyed to the user.
- A user recorded as rated is **never re-asked** — the check happens before every
  prompt and survives reinstall / device change.
- Prompt copy defaults are stated but the story's exact strings override them.

## Accessibility baseline

The rating UI (web) has labelled controls, keyboard reachability, and focus
management; on mobile the native review flow carries the OS accessibility support.
