# AgentNet user manual

AgentNet runs and coordinates many Claude Code agents. A **daemon** on your machine starts, watches and connects the
agents; the **app** (a desktop window or a browser tab) is its window. Agents keep working when you close the app.

Usage comes from your own accounts. Only the models in a Claude subscription are known to work; everything else is
experimental. Problems? Use the **Feedback** button.

## 1. Basics

| Term | Meaning |
|---|---|
| **Net** | Your own AgentNet: its agents, tasks, mail, projects and settings. |
| **Agent** | A Claude Code session AgentNet started, with its own terminal, git branch and report. |
| **Project** | A git repo you work on. Agents branch from it. |
| **Task** | An item on the Task List; running it starts an agent. |

Every agent works in its own git **worktree** and **branch** (`agent/<id>`), so your checkout is never touched. It runs
inside a **jail** (a sandbox that sees only its worktree). The first time you open the app a **welcome tutorial** runs;
reopen it any time from the **?** menu. **Ctrl+K** opens the command palette (new agent, new terminal, pages, agents).

The top bar has the sidebar toggle, the usage meters, **Reload** (⟳), **Feedback**, the **Approvals** bell 🔔 and the
**?** help menu.

## 2. Agents

**New agent** asks for a project folder (or none), the task text, a name, the model and the effort. Pick a model your
subscription includes. Agents appear in the sidebar with their state: queued, running, needs approval, done and so on.
Open one to:

- watch its **terminal**, and **take over** to type into it directly;
- send it a message, or **interrupt** it (stops the current turn);
- read its **report** (what it did, the commits, every file it touched, and what is left for you);
- relaunch a finished or stopped agent where its session left off.

Normally every agent is jailed. When you start an individual agent you may choose to run it **without the jail**; a
confirmation appears, the agent shows an UNJAILED badge, and the choice does not carry over to its helpers or to a
relaunch.

**Grid** (the grid icon next to the agents) shows all live agents side by side; finished agents stay as their report
until you close them. **History** lists closed agents and their reports. **New terminal** opens a plain shell in the app.

### Summoning and the chain of command

An agent can **summon** helpers for parts of its task. Each helper answers to the agent that summoned it, works on its
own branch, and is merged into its summoner's branch. Limits (depth, helpers per tree) are in Settings. You can step in
anywhere: message, interrupt or stop any agent. Agents can also message each other.

### Approvals

When an agent asks for something only you may allow, the 🔔 shows it. Click it to approve or deny. Agents may also put
things on your **to-do list** (decisions and actions outside AgentNet); those appear at the top of their report.

## 3. Task List, Schedules and scratch pads

**Task List** is your work queue. Each task has a title, details, project, priority, model and effort, and either
**Auto** (starts as soon as there is room) or **Manual** (waits for Run). Drag to reorder. A task can be paused (its
agent stops, the branch and session are kept), resumed, stopped, edited while waiting, and removed (it stays in
History and can be re-added). The same list shows as a **kanban board** in its own window ("Tasks" in the sidebar).
The default model and effort for task runs are in Settings.

**Schedules** create tasks on a timer: a cron expression or a single time, in a time zone you choose, with a choice of
what happens if the machine was off at that time (run once, or skip).

**Scratch pad** is a live document for ideas. Each pad has an agent you can switch on: it asks questions, comments,
sorts ideas into topics, and can turn ideas into tasks on the Task List (the pad's **Execute** switch decides whether
those start by themselves). You set what the pad agent may do. Pads have collapsible replies, and blocks can be
retracted to one line.

## 4. Projects and merging

**Projects** lists your repos. Add a folder (a plain folder is turned into a git repo, with a first commit so agents
have something to branch from), or close a project: it leaves the list and nothing on disk changes. For each project:

- the **base branch** new agents start from;
- **Merge automatically**: when a root agent finishes, its branch is merged; if there are conflicts, a merger agent
  resolves them. Off: merge each branch yourself with one click;
- **Git actions**: status, `pull` (fast-forward only) and `push` of the current branch, and a **merger** agent that
  merges all unmerged agent branches into the base;
- **Beads**: an optional task tracker agents use to leave notes for each other and for later agents;
- **This machine only**: keeps the project's code and Beads on this machine (see chapter 9).

## 5. Mail and file reservations

Agents talk through **Agent Mail**: threads, replies, reading receipts. The **Mail** page shows the threads, lets you
mail an agent, and shows the health of the mailbox. Before editing files, agents **reserve** them; the Mail page
lists the reservations and flags clashes. **Leases** are stricter reservations (one holder at a time, with a number that
only goes up) for things like a port or a test database.

## 6. Usage, wind-down and limits

The top bar meters show your Claude usage windows. When usage nears its limit, AgentNet starts a **wind-down**:
agents estimate the work left; small tasks finish, the rest save their work and are **resumed automatically** when the
window resets. You can wind down now, let one agent keep working, or end the wind-down (also in the command palette).

**Settings** holds:

- **Limits**: active agents, helpers per tree, depth, and the wind-down thresholds;
- **Agents**: default model, effort, work strategy (fast, balanced, efficient: how agents decide to split work), and
  switches for **Claude in Chrome** (agents drive your Chrome in their own tab group) and for the MCP servers from
  your own Claude Code;
- **Shared tools**: skills and MCP servers one agent shares with all later agents. A new MCP server waits for your
  approval;
- **Connect Claude Code**: gives your own Claude Code an MCP server to list, start, message, interrupt and stop agents.
  Switching it off revokes its token;
- **Privacy**: AgentNet sends no telemetry;
- **Themes** and sounds: pick a look for the app;
- **Providers**: see below.

### Providers

Claude subscription models work out of the box. You can add others yourself: Amazon Bedrock, Google Vertex, Microsoft
Foundry, an Anthropic-compatible gateway, or a local model server (LM Studio, run through OpenCode). None is bundled and
they are experimental. Choose which provider new agents use under Settings → Providers; for Bedrock the page can run
the AWS sign-in and show the device link and code.

## 7. Updates, feedback and shutdown

- **Update**: a button appears when a newer signed release exists. It verifies, installs and restarts; agents are
  asked to save first. If the new release does not start, the previous one comes back.
- **Feedback** sends a bug report or request only when you press send. Leave secrets and other people's personal data
  out of reports.
- The daemon runs as a user service. Stopping it saves running agents first and they are resumed when it starts again.
- A remote shutdown switch exists for serious problems with a release; see the End-User Licence Agreement.

## 8. Command line

Everything in the app is also available with `agentnet` (useful over SSH and in scripts). `agentnet help` lists the
commands; add `--json` to any command for raw output.

```bash
agentnet status                               # who is working, what needs you
agentnet projects add ~/code/app --init
agentnet todo add "Fix the flaky test" --project app --auto --priority high
agentnet schedule add nightly --cron '0 2 * * *' --title "Dependency audit" --project app
agentnet providers
agentnet updates check && agentnet updates apply
```

## 9. Several machines: a home Net

One AgentNet can span your own machines on a home network: an always-on **hub** (best headless) and **workers**
(desktops, laptops, WSL2 installs) that come and go.

- The hub holds the Net's state, mail and a mirror of shared projects, queues work for absent workers and takes a
  daily encrypted **backup**. Workers join with a one-time **join code** (valid 24 hours, once; treat it as a secret),
  keep working offline and sync when the hub is back.
- Each worker keeps one outgoing connection to the hub, so NAT, laptops and WSL2 are fine.
- Projects are shared in the Net by default; **This machine only** keeps one private. A task can target a machine, with
  a fallback to the hub.
- Terminals of agents and shell sessions on other machines can be opened from the app (the other machine must allow
  terminals).
- Agents on a machine that is lost or paused can be restarted elsewhere (**Restart on**, **Auto-continue**).
- The **Nodes** page lists the machines. Set up with `agentnet net create-hub`, `agentnet net add-machine <name>` and
  `agentnet net join '<code>'`. Never copy `~/.agentnet` between machines.

Separate AgentNets can also be **linked**, for example a headless one on a server: you can summon helpers there from an
agent. The other side decides what a link may do (projects, models, number of agents, expiry).

## 10. Where things are

| What | Where |
|---|---|
| Your data, settings, token | `~/.agentnet` |
| The program | `~/.local/share/agentnet` |
| Commands | `~/.local/bin/agentnet`, `agentnetd` |

Install, update and remove: see the install guides for [Linux desktop](install-linux-desktop.md),
[Linux headless](install-linux-headless.md) and [Windows (WSL2)](install-windows.md).
