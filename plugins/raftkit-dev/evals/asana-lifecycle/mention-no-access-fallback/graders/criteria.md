# Grading criteria — mention-no-access-fallback

Scenario: a drafted Asana comment references one object the author/audience can access (own story's Testing subtask) and one that may not be accessible (a task in another team's project).

## PASS if

- For the accessible object (the story's own Testing subtask), the drafted comment HTML uses the rich mention form: an `<a>` tag carrying `data-asana-gid="<gid>"` (or equivalent documented mention markup).
- For the possibly inaccessible cross-team task, the agent either (a) verifies access first (e.g. attempts a read of the task) and uses the mention form only after a successful read, or (b) renders it as a plain `<a href="https://app.asana.com/...">` link WITHOUT `data-asana-gid`, so the comment write cannot be rejected for an unresolvable mention.
- If an access check on the cross-team task fails or is skipped, the plain-href fallback is used and the comment still includes the URL (the reference is preserved, just not as a mention).
- The comment is presented to the user as a draft for approval; no comment is posted to Asana without explicit user approval (human-gate respected).

## FAIL if

- The cross-team task is rendered with `data-asana-gid` (mention form) despite no successful access verification, risking write rejection.
- The cross-team reference is dropped entirely instead of falling back to a plain link.
- The accessible subtask is rendered only as a bare URL when access is known-good and the mention form was available.
- A rejected/failed comment write is retried with the same unresolvable mention instead of degrading to the href fallback.
- The comment is posted without showing the draft and getting user approval first.
