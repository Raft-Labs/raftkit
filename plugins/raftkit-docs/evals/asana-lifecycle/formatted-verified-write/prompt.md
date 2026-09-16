I just wrapped up the payments-retry story and need to post a status update as a comment on its Asana task (the one I have open — task 1216551447799999 in our workspace). Here's what I want the comment to say, roughly in this shape:

## Status: Ready for QA

What shipped:
- Retry queue with exponential backoff (max 5 attempts)
- Dead-letter handling for payments that exhaust retries
- Alerting when the dead-letter count > 10

Notes: the config uses `retry.maxAttempts` & falls back to 3 if unset.

PR: https://github.com/raftlabs/ticketstop/pull/482

Please post that to the task, make sure the formatting actually looks right in Asana (headings, bullets, the link), and confirm it went through correctly.
