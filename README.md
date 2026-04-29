# DevPod Dotfiles

Shared dotfiles injected into every [DevPod](https://devpod.sh) container via `DOTFILES_URL`.
Provides tmux, Claude Code CLI, Codex CLI, and the `agents` session manager for phone-based
development via Termius + Tailscale.

## Why This Exists

Claude Code is a terminal-based AI coding assistant — no GUI, no IDE required.
This makes it uniquely suited for mobile development:

- **tmux** keeps sessions alive across disconnects. Start a Claude Code or Codex session
  from your desktop, detach, walk away, and reconnect from your phone — the full
  conversation and context is still there. Multiple sessions per workspace let you
  run parallel agent tasks. If tmux scrollback gets in the way, `agents --no-tmux`
  opens a direct shell inside the DevPod container instead.

- **Tailscale** creates a private mesh VPN between your devices. Your WSL2 instance
  gets a stable IP (100.x.x.x) accessible from anywhere — no port forwarding, no
  dynamic DNS, no exposing SSH to the internet.

- **Termius** (Android/iOS) provides a proper terminal with keyboard support,
  paste, and tmux-aware features. Combined with Tailscale, it turns your phone
  into a full development terminal.

The result: you can write code, review PRs, debug production issues, and run
AI-assisted development sessions from your phone — on the bus, in a waiting room,
or on the couch — with the same power as sitting at your desktop.

## What Gets Installed

`install.sh` runs automatically inside each new DevPod container and installs:

| Component | Purpose |
|-----------|---------|
| **tmux** | Persistent terminal sessions that survive disconnects |
| **Claude Code CLI** | AI-powered coding assistant |
| **Codex CLI** | OpenAI coding assistant |
| **agents** | session manager (auto-launches on login) |
| **.tmux.conf** | Container-optimized tmux config (mouse scroll/drag, OSC 52 clipboard, status bar at top) |
| **.bashrc** | Shell config (history, aliases, auto-venv, sources .bashrc.d/) |
| **.bashrc.d/** | Bash snippets (PATH, auto-launch agents) |

## Architecture

```
Phone (Termius) → Tailscale VPN → WSL2 (100.109.194.122:22)
  → agents → interactive menu → ssh WORKSPACE.devpod
  → Container agents → tmux or direct shell → Claude Code / Codex
```

DevPod provides built-in SSH tunneling via `ProxyCommand` entries in `~/.ssh/config`.
No SSH ports or openssh-server needed inside containers.

## Usage

### Create a DevPod workspace

```bash
# From WSL — DevPod auto-discovers .devcontainer/devcontainer.json
devpod up ~/git_wsl/alerts --ide none

# Repos with multiple devcontainer configs — DevPod shows a picker menu.
# Or specify explicitly with --devcontainer-path:
devpod up ~/git_wsl/wibble --devcontainer-path .devcontainer/devpod/devcontainer.json --ide none
devpod up ~/git_wsl/spartans-hockey --devcontainer-path .devcontainer/devpod/devcontainer.json --ide none

# Or with VS Code:
devpod up ~/git_wsl/alerts --ide vscode
```

### Connect from phone (Termius + Tailscale)

1. SSH into WSL2: `100.109.194.122:22` (user: `sean`)
2. Run `agents` — shows interactive menu of sessions + workspaces
3. Pick a workspace → auto-launches tmux or a direct shell for Claude Code / Codex

### Connect from WSL host

```bash
agents                         # Always shows interactive menu (detected workspace shown as hint)
agents alerts                  # Connect to alerts workspace (shows menu if sessions exist)
agents rcom frontend           # Connect to rcom-frontend session
agents --no-tmux rcom          # Direct DevPod shell, no tmux persistence
agents --local                 # Local tmux session in current dir (no DevPod)
agents --local mywork          # Local tmux session named "mywork"
agents --list                  # List all workspaces + status
```

`agents` always shows an interactive menu — it never auto-connects. When sessions
already exist inside a container, you choose between attaching to an existing session
or creating a new one. New sessions are named sequentially: `rcom`, `rcom-2`, `rcom-3`.

Tmux is the default because it preserves long-running phone/SSH sessions. Use
`agents --no-tmux WORKSPACE` when terminal scrollback matters more than persistence;
inside that direct shell, run `claude`, `claude resume`, `codex`, or `codex resume`
normally.

### Manage workspaces

```bash
devpod list                                    # Show all workspaces
devpod stop alerts                             # Stop (saves resources)
devpod up ~/git_wsl/alerts --ide none          # Restart
devpod delete alerts                           # Remove entirely
```

### tmux controls

| Action | Keys |
|--------|------|
| Detach (session persists) | `Ctrl+b`, `d` |
| New window | `Ctrl+b`, `c` |
| Switch window | `Ctrl+b`, `0-9` |
| Scroll up (enter copy mode) | Mouse wheel up |
| Select text (copy to clipboard) | Click + drag |
| Copy mode (keyboard) | `Ctrl+b`, `[` |
| Exit copy mode | `q` |
| Paste | `Ctrl+b`, `]` or right-click |

If scrolling shows repeated TUI frames, use `agents --no-tmux WORKSPACE` for a direct
shell. Claude Code and Codex both support resume flows, so tmux is convenient but not
required for every workflow.

## Updating Running Containers

After editing dotfiles, deploy changes to all running DevPod containers:

```bash
bash ~/git_wsl/dotfiles/scripts/deploy.sh
```

This pushes `.tmux.conf`, `agents`, `.bashrc`, and `.bashrc.d/` to all running
containers in parallel, reloads tmux if active, and updates the host-side `agents`
script at `~/.local/bin/agents`.

New containers automatically get the latest dotfiles via `devpod up` (DevPod clones
this repo and runs `install.sh`).

## Installation

### Prerequisites

- WSL2 (Ubuntu 24.04)
- [Docker Desktop](https://docs.docker.com/desktop/install/windows-install/) (or Docker Engine in WSL)
- [DevPod](https://devpod.sh) CLI (`/usr/local/bin/devpod`)
- [Tailscale](https://tailscale.com) (for phone access)
- openssh-server in WSL (for phone access via Termius)

### 1. Clone the dotfiles repo

```bash
git clone https://github.com/mccarthysean/dotfiles.git ~/git_wsl/dotfiles
```

### 2. Configure DevPod to use dotfiles (one-time)

```bash
devpod provider set-options docker DOTFILES_URL=https://github.com/mccarthysean/dotfiles
devpod context set-options -o DOTFILES_SCRIPT=install.sh
```

Every new `devpod up` will now clone this repo into the container and run `install.sh`
automatically — installing tmux, Claude Code, Codex, agents, .bashrc, and .tmux.conf.

### 3. Install the host-side `agents` script

The host-side script lives on your WSL machine (not inside containers). It handles workspace
discovery, auto-detection, and SSH tunneling into DevPod containers.

```bash
# First time install (or use deploy.sh for updates):
bash ~/git_wsl/dotfiles/scripts/deploy.sh
```

Ensure `~/.local/bin` is in your PATH (add to `~/.bashrc` if needed):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### 4. Set up persistent Claude Code authentication (one-time)

Generate a long-lived OAuth token so containers don't require browser auth on every rebuild:

```bash
claude setup-token
```

Save the token to `~/.claude/.setup-token`:

```bash
mkdir -p ~/.claude
echo "YOUR_TOKEN_HERE" > ~/.claude/.setup-token
chmod 600 ~/.claude/.setup-token
```

The host-side `agents` reads this token and passes it via `CLAUDE_CODE_OAUTH_TOKEN` env var
through SSH, so containers authenticate automatically.

### 5. Create your first DevPod workspace

```bash
devpod up ~/git_wsl/myproject --ide none
```

Then connect:

```bash
agents     # Interactive menu shows the new workspace
```

## Files

```
dotfiles/
├── install.sh          # Main installer (runs in every new container)
├── .bashrc             # Shell config (history, aliases, auto-venv, sources .bashrc.d/)
├── .tmux.conf          # tmux config (mouse scroll/drag, OSC 52 clipboard, status top)
├── bin/
│   ├── agents          # Container-side session manager
│   └── agents-host     # Host-side (WSL) orchestrator
├── .bashrc.d/
│   └── *.sh            # Bash snippets (PATH, auto-launch on login)
└── scripts/
    └── deploy.sh       # Push dotfiles updates to running containers + host
```

## Safety

All devcontainers use `sleep infinity` as their command — no production services
(inserters, schedulers, MQTT listeners, web servers) auto-start. Development servers
must be launched manually inside each container.
