# Install AgentNet on a Linux server (headless)

A headless install has no window: the same features, managed from a browser on another machine or with the
`agentnet` command over SSH.

## Requirements

- Ubuntu 22.04, 24.04 or 26.04 (also Mint, Pop!_OS), x86_64, with SSH access and a user that can use `sudo`.
- A **Claude Code** account, or another model provider you add yourself (see the manual, "Providers").
- An internet connection.

## Steps

1. Log in over SSH as a normal user (not root) and download the installer:

   ```bash
   curl -fsSLO https://github.com/AlpBingol/AgentNet/releases/latest/download/install.sh
   ```

2. Run it with the headless option:

   ```bash
   bash install.sh --headless
   ```

   The installer offers this by itself when it finds no desktop. Choose **System**, **User only** or **Show me the
   commands** as described in the [Linux desktop guide](install-linux-desktop.md). The window and its libraries are
   skipped; the service is set to keep running after you log out.
3. Sign in to your provider. For Claude Code:

   ```bash
   claude
   ```

   Open the link it prints in a browser on your own computer, then paste the code back.
4. Check that it is running:

   ```bash
   agentnet status
   ```

   It says `headless`.
5. Register a project (a git repo; `--init` makes one from a plain folder):

   ```bash
   agentnet projects add ~/code/app --init
   ```

6. Reach the app from your own computer through an SSH tunnel, then open the link in your browser:

   ```bash
   ssh -L 7420:127.0.0.1:7420 user@server
   ```

   ```bash
   echo "http://127.0.0.1:7420/#token=$(cat ~/.agentnet/nets/default/token)"
   ```

   Run the second command on the server and open the printed link on your computer. Everything the app does is also
   available as `agentnet` commands; `agentnet help` lists them.
7. Check everything with `bash ~/.local/share/agentnet/install.sh doctor`.

To make the server part of a home Net with your other machines, see "Several machines" in the [manual](manual.md).

## Update

```bash
bash ~/.local/share/agentnet/install.sh update
```

or `agentnet updates check` and `agentnet updates apply`. The install stays headless.

## Remove

```bash
bash ~/.local/share/agentnet/install.sh uninstall
```

Your data in `~/.agentnet` is kept; add `--purge` to delete it. The "keep running after logout" setting stays on;
turn it off with `sudo loginctl disable-linger $USER`.
