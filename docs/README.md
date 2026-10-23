# AgentNet user documentation

This folder is the single source for the user docs. `scripts/release/publish.sh` copies it into the public repo as
`docs/`, and the wiki and the in-app help are built from the same files. Write for users: Markdown and images only
(no source files), no personal names, machine names, IP addresses or home paths (`scripts/release/alpha/pii.sh`
checks), and no internal documents (SPEC, DECISIONS, HANDOFF).

## Contents

- [Manual](manual.md): every feature of AgentNet, page by page.
- Install guides:
  - [Linux desktop](install-linux-desktop.md)
  - [Linux headless (servers)](install-linux-headless.md)
  - [Windows (WSL2)](install-windows.md)
- Several machines: see chapter 9 of the manual.
