# Criteria

Score 1 only if ALL hold, else 0:

1. The response states plainly that CodeRabbit is not run and is not part of the current review chain — it is not treated as a missing/skipped layer to apologize for or retry.
2. The response attributes this to a prior team decision to use pr-review-toolkit only, rather than to a technical failure or a missing installation.
3. The automated-review gate proceeds on the strength of pr-review-toolkit's findings alone — it is not blocked or delayed waiting on CodeRabbit.
