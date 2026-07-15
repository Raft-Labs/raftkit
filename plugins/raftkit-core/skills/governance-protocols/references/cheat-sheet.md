# 💡 Internal Team Cheat Sheet

To ensure the team quickly learns the basic mechanics of Claude Code without getting bogged down in tutorials, pin these 5 critical bullet points in your team workspace:

- **Keep It Clean:** Never leave a Claude Code terminal session open for days. When you finish a task, type exit and open a fresh terminal. This wipes the active token cache and stops hallucinations instantly.
- **Audit Your Usage:** Anytime your session starts feeling slow or answering oddly, run /context to look at your active file memory grid, or /usage to see your active session token costs.
- **The Golden Triage Rule:** If you are on an Opus or Fable model, use it strictly for architecture design or tracking deep asynchronous bugs. For writing code, running tests, or rewriting components, drop back down to /model sonnet to save tokens and execute faster.
- **Let the Orchestrator Slicing Happen:** When you type a massive feature request, the AI is instructed to stop and show you a breakdown table. Don't fight it—type yes to let it spin up background subagents via /agents to handle the heavy lifting cleanly.
- **Watch for Warnings:** If a background subagent gets stuck trying to fix a broken TypeScript type or a NextJS build error more than 3 times, it will pause itself and alert your main terminal screen. Use /agents view <name> to step in and fix the typo for it.
