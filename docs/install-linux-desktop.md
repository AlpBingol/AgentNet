# Install AgentNet on Linux (desktop)

## Requirements

- Ubuntu 22.04, 24.04 or 26.04, Linux Mint or Pop!_OS, on an x86_64 PC with a desktop.
- A **Claude Code** account. You sign in yourself and pay for your own usage.
- An internet connection, and a user account that can use `sudo` (only for a few system packages; AgentNet itself
  never needs root).
- About 1 GB of free disk space, plus room for your projects.

Never run the installer with `sudo`; it refuses to run as root.

## Steps

1. Open a terminal and download the installer:

   ```bash
   curl -fsSLO https://github.com/AlpBingol/AgentNet/releases/latest/download/install.sh
   ```

2. Run it as yourself:

   ```bash
   bash install.sh
   ```

3. Choose how to install:
   - **1 System**: the installer lists the few root steps (git, curl, bubblewrap, desktop libraries, an AppArmor
     profile if your system needs one), asks for your `sudo` password once and does everything.
   - **2 User only**: everything goes into `~/.local`. The root steps are printed for you to run in another terminal;
     press Enter when done and it checks again.
   - **3 Show me the commands**: every step is printed for you to run yourself; nothing runs by itself.

   Every download is checked against a signed checksum list. If a step is already done it is skipped, so running the
   installer again continues where it stopped.
4. When it asks, let it add `~/.local/bin` to your `PATH` (answer `y`), then open a new terminal.
5. Sign in to Claude Code:

   ```bash
   claude
   ```

   Follow the link it prints, then close it with `/exit`.
6. Open **AgentNet** from your applications menu, or use the link the installer printed (it looks like
   `http://127.0.0.1:7420/#token=…`). The welcome tutorial starts on first run.
7. Check everything with:

   ```bash
   bash ~/.local/share/agentnet/install.sh doctor
   ```

   Each line shows ✓ or ✗ and what to do about it.

## Update

Click the **Update** button in the app when it appears, or run:

```bash
bash ~/.local/share/agentnet/install.sh update
```

The new release is verified, replaced and restarted. If it does not start within 45 seconds, the previous release
is put back. Running agents are asked to save first.

## Remove

```bash
bash ~/.local/share/agentnet/install.sh uninstall
```

This removes what the installer installed and keeps your data in `~/.agentnet`. Add `--purge` to delete that too.
Claude Code, git, curl and bubblewrap are left in place.
