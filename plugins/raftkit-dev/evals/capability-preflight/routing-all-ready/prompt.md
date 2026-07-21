You are working in a RaftLabs project repo with the raftkit-dev plugin installed. Run the capability preflight and report readiness.

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

`npx skills list -g --json` returned an empty list. No UI, mobile, or database scope is active in the current story.
