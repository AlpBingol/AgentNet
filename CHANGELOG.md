# Changelog

## v0.1.0 (2026-10-16)

### AgentNet Alpha 0.1.0

The first public Alpha of AgentNet: run and coordinate many Claude Code agents from one app.

### What's in it
- Agents in their own git worktrees, with summoning, live control, Agent Mail, file reservations and Beads.
- A Task List with a kanban board, schedules, scratch pads and per-agent task reports.
- Usage-aware wind-down: agents estimate the work left, small tasks finish, the rest save and resume after the reset.
- Optional model providers (Bedrock, Vertex, Foundry or a gateway), added by you; none are bundled.
- Shared skills and MCP servers for all later agents, and Claude in Chrome for agents.
- A welcome tutorial, a Feedback button, and signed updates with an Update button.

### Install
Ubuntu 22.04 / 24.04, Linux Mint or Pop!_OS (x86_64):

```bash
curl -fsSLO https://github.com/AlpBingol/AgentNet/releases/latest/download/install.sh
bash install.sh
```

### Notes
- Linux x86_64 only. You need your own Claude Code account.
- This is pre-release software: back up your work.
- Every release asset is listed in `SHA256SUMS`, which is signed (`SHA256SUMS.sig`), as is `manifest.json`.

