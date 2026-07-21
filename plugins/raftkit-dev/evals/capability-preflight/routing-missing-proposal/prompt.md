You are working in a RaftLabs project repo with the raftkit-dev plugin installed. The current story has browser-visible acceptance criteria (the QA sheet requires checking the rendered page in a real browser). Run the capability preflight.

`claude plugin list --json` returned:

```json
[
  { "id": "raftkit-core@raftkit", "version": "0.4.0", "scope": "user", "enabled": true },
  { "id": "raftkit-dev@raftkit", "version": "0.12.0", "scope": "user", "enabled": true },
  { "id": "superpowers@claude-plugins-official", "version": "6.1.1", "scope": "user", "enabled": true },
  { "id": "claude-md-management@claude-plugins-official", "version": "1.0.0", "scope": "user", "enabled": true },
  { "id": "code-simplifier@claude-plugins-official", "version": "1.0.0", "scope": "user", "enabled": true },
  { "id": "security-guidance@claude-plugins-official", "version": "2.0.6", "scope": "user", "enabled": true },
  { "id": "pr-review-toolkit@claude-plugins-official", "version": "1.0.0", "scope": "user", "enabled": true }
]
```

`claude plugin list --available` shows `playwright` exists in the claude-plugins-official marketplace.
