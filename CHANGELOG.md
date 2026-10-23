# Changelog

## v0.1.1 (2026-10-23)

### AgentNet Alpha 0.1.1

### New
- **A home Net with a hub.** Connect your own machines (a PC, a laptop, a server) into one Net with one hub. Agents, approvals, human tasks, mail and Beads are shared across them; agents can be started on, and continued on, another machine; a lost machine's agents can be restarted elsewhere. Settings → Net, a Net badge in the top bar and the `agentnet net` commands manage it.
- **Net-wide leases.** Agents can take a lease on a resource (a port, a test database, a folder) that only one holder at a time may use, across all machines.
- **Remote terminals.** Open an agent's terminal or a shell on another machine of your Net, and take over an agent's terminal.
- **Encrypted Net backups** with a one-time recovery code, and restore.
- **Manual sync of project folders between machines**, with a per-project switch.
- **Headless install for servers** (`install.sh --headless`), `install.sh --join` for adding a machine to a Net, and a reverse SSH tunnel option for the background service.
- **Link permissions.** Choose what each linked AgentNet may do on yours: which projects, whether it may start agents, how many, which models, a usage limit and an expiry. A Nodes page shows your machines and links as a live graph.
- **Private projects.** A "this machine only" switch keeps a project from being offered or started on other machines.
- **Local models through OpenCode** (for example LM Studio), with permission prompts answered from the app.
- **Bedrock through an AWS SSO profile**, with one-click sign-in renewal.
- **Project git actions in the app:** status, push, pull, and starting a merger agent by hand.
- **Unjailed agents** can be started one at a time (with a confirmation); helpers they start always stay jailed.
- **Names and colours** for your Net and each machine.
- **Connect Claude Code:** a skill and Agent Mail for your own Claude Code sessions, with an optional admin connection.
- **Command line parity:** commands for projects, to-dos, schedules, mail, providers, updates, settings, shared tools and scratch pads.
- **Agent tools** to rewrite or remove a to-do (`update_task`, `remove_task`).
- **User manual and install guides** for Linux desktop, Linux headless and Windows (WSL2), and a welcome tutorial that points to them.

### Improved
- Windows is supported through WSL2 only, with the Linux installer; the jail hides `/mnt` and WSL interop.
- Projects that are not git repositories are set up automatically; agents without a project run in your home folder; a folder browser and a Close project action.
- Scratch pads: collapse replies, retract blocks to one line, condense threads.
- Agents started from a pad's task can read that pad.
- Approvals fall back to the hook's message when the screen shows no prompt.
- Ubuntu 26.04 is supported as a base; the build links against Ubuntu 22.04's libraries for wider compatibility.
- The agent jail keeps DNS working on WSL.
- Tools installed outside the daemon's PATH (npm, nvm, bun folders) are found.

### Fixed
- A "merge blocked" state that stayed after a merger agent had resolved the branch.
- Agents killing the AgentNet daemon by mistake; the daemon now restarts and resumes after a stray stop.
- The `agentnet` command doing nothing when started through its `~/.local/bin` link.
- A flaky backup check and several Net layout problems.

### Notes
- Linux x86_64 only. You need your own Claude Code account.
- This is pre-release software: back up your work.
- Every release asset is listed in `SHA256SUMS`, which is signed (`SHA256SUMS.sig`), as is `manifest.json`.

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

