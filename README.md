# AgentNet Alpha

AgentNet runs and coordinates many Claude Code agents: a daemon plus a desktop app, with Git, Beads and Agent Mail
underneath. You can see all your agents, their progress and their files in one place, and let them work together.

This is an **Alpha**: free to use (personal and commercial), closed source, and pre-release. Expect rough edges and
changes. Back up your work.

## Requirements

- **Linux** (other systems are not supported yet).
- A **Claude Code** account. You install Claude Code and sign in yourself, and pay for your own usage.
- Git.

Other programs AgentNet uses (Beads, Agent Mail, nats-server, bubblewrap) are separate software under their own
licences; see `THIRD-PARTY-NOTICES.md`.

## Install

On Ubuntu 22.04 or 24.04, Linux Mint or Pop!_OS (x86_64), download the installer and run it **as yourself** (not with
sudo):

```bash
curl -fsSLO https://github.com/AlpBingol/AgentNet/releases/latest/download/install.sh
bash install.sh
```

It asks how to install. **System** runs the few root steps with sudo. **User only** keeps everything in `~/.local` and
shows you the root commands. **Show me the commands** prints every step for you to run yourself. Every download is
checked. When it's done, sign in to Claude Code by running `claude`, then open AgentNet from your applications menu or
from the link it prints.

Later: `bash ~/.local/share/agentnet/install.sh doctor` checks everything, `… update` installs the newest release
(the app's Update button does the same), and `… uninstall` removes AgentNet and keeps your data.

## Licence

Using AgentNet Alpha means you accept the [End-User Licence Agreement](EULA.md). Please read it, especially the parts
on remote shutdown and data.

## Feedback

- Bugs and ideas: open an issue in this repository on GitHub.
- Email: alp.bingol+AgentNet@gmail.com (or the app's Feedback button)

AgentNet sends no telemetry. Feedback is sent only when you send it. Please leave secrets and other people's personal
data out of reports.
