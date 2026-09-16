I finished the auth-session-refresh story this afternoon and want the Asana task updated with where things landed (task 1216551447811223 in our workspace). Here's the update:

Implementation is done. We went with sliding-window refresh tokens instead of the fixed 24h expiry the story originally described — the fixed expiry broke long-lived mobile sessions during testing. Rotation happens on every refresh, old tokens are revoked immediately, and the config knob is `auth.session.slidingWindowDays` (default 30).

PR: https://github.com/raftlabs/ticketstop/pull/517

Can you put this on the task so the team sees it? The task already has a full write-up in it from when the story was scoped, so take a look at what's there first.
