# Install AgentNet on Windows (WSL2)

On Windows, AgentNet runs in **Ubuntu under WSL2**, a real Ubuntu that Windows runs for you. You use it from your
Windows browser. There is no native Windows build.

## Requirements

- Windows 11, or Windows 10 22H2 with WSL from the Microsoft Store.
- An x64 CPU with virtualization turned on in the BIOS/UEFI (it usually is).
- A **Claude Code** account.

## Steps

1. **Install WSL2 and Ubuntu.** Open PowerShell as Administrator:

   ```powershell
   wsl --install -d Ubuntu-24.04
   ```

   Restart Windows if asked. Ubuntu opens and asks for a Linux user name and password. Check that it is WSL 2:

   ```powershell
   wsl -l -v
   ```

2. **Download the installer** inside Ubuntu:

   ```bash
   cd ~
   curl -fsSLO https://github.com/AlpBingol/AgentNet/releases/latest/download/install.sh
   ```

3. **Run it** and choose mode 1 (System):

   ```bash
   bash install.sh
   ```

   On WSL it also:
   - turns on **systemd** if it is off. WSL then must restart once: run `wsl --shutdown` in PowerShell, open Ubuntu
     again and run `bash install.sh` again. It continues where it stopped;
   - keeps the AgentNet service running with no Ubuntu window open;
   - sets `instanceIdleTimeout=-1` in your `%UserProfile%\.wslconfig`, so WSL does not stop Ubuntu (and your agents)
     when the last window closes. This applies to all your WSL distributions until `wsl --shutdown` or a reboot;
   - adds `agentnet-wsl.cmd` to your Windows Startup folder, so AgentNet starts when you log in to Windows;
   - skips the Linux desktop window; you use the Windows browser instead.

4. **Sign in to Claude.** Run `claude` in Ubuntu. It prints a link: open it in your Windows browser and paste the code
   back if asked.
5. Run `wsl --shutdown` once in PowerShell and open Ubuntu again, so the `.wslconfig` setting takes effect.
6. **Open AgentNet** in your Windows browser (Edge, Chrome or Firefox). The installer offers to open it. To print the
   link again, in Ubuntu:

   ```bash
   echo "http://127.0.0.1:7420/#token=$(cat ~/.agentnet/nets/default/token)"
   ```

7. **Check:** `bash ~/install.sh doctor`. Then close every Ubuntu window, wait a minute and open the link again; it
   should still answer, also after a Windows restart.

**Keep your projects inside Ubuntu** (for example `~/code/...`), not under `/mnt/c/...`: Windows drives are slow from
WSL, agents cannot see them, and file permissions are wrong. Use `git clone` inside Ubuntu. Your Ubuntu files appear in
Explorer under `\\wsl.localhost\Ubuntu-24.04\home\<you>`.

### If the installer cannot reach Windows

Add this to `%UserProfile%\.wslconfig` (create the file if needed):

```ini
[general]
instanceIdleTimeout=-1
```

To start Ubuntu at logon, press Win+R, type `shell:startup`, and create `agentnet-wsl.cmd` in that folder:

```bat
@echo off
start "" /min wsl.exe -d Ubuntu-24.04 --exec /bin/true
```

## Update

Use the **Update** button in the app, or in Ubuntu: `bash ~/.local/share/agentnet/install.sh update`.

## Remove

```bash
bash ~/.local/share/agentnet/install.sh uninstall
```

This also removes `agentnet-wsl.cmd` and, if you agree, the `.wslconfig` line. Your data in `~/.agentnet` is kept
(`--purge` deletes it). Turn the always-on setting off with `sudo loginctl disable-linger $USER`. To remove Ubuntu
itself: `wsl --unregister Ubuntu-24.04` in PowerShell (this deletes all its files).
