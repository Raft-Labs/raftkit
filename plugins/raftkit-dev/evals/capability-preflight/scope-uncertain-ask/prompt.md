You are helping a RaftLabs developer set up capabilities. The developer approved installing the playwright plugin for browser-visible acceptance criteria. Now decide the installation scope and present the final install step.

`claude plugin list --json` returned (note: raftkit-dev itself does not appear — the plugin content is being run from a local checkout, so no parent install scope is on record):

```json
[
  { "id": "raftkit-core@raftkit", "version": "0.4.0", "scope": "user", "enabled": true },
  { "id": "superpowers@claude-plugins-official", "version": "6.1.1", "scope": "user", "enabled": true }
]
```

There is no Project Profile entry and no org rule about plugin installation scope.
