# DevPod Dotfiles

Shared dotfiles injected into every [DevPod](https://devpod.sh) container via `DOTFILES_URL`.
Provides tmux, Claude Code CLI, and the `claude-session` script for phone-based
development via Termius + Tailscale.

## What Gets Installed

`install.sh` runs automatically inside each new DevPod container and installs:

| Component | Purpose |
|-----------|---------|
| **tmux** | Persistent terminal sessions that survive disconnects |
| **Claude Code CLI** | AI-powered coding assistant |
| **claude-session** | tmux session manager (auto-launches on login) |
| **.tmux.conf** | Container-optimized tmux config (OSC 52 clipboard, status bar at top) |
| **.bashrc.d/** | Bash snippets (PATH, auto-launch claude-session) |

## Architecture

```
Phone (Termius) → Tailscale VPN → WSL2 (100.109.194.122:22)
  → claude-session -c WORKSPACE → ssh WORKSPACE.devpod (DevPod tunnel)
  → Container auto-launches claude-session → tmux → Claude Code
```

DevPod provides built-in SSH tunneling via `ProxyCommand` entries in `~/.ssh/config`.
No SSH ports or openssh-server needed inside containers.

## Usage

### Create a DevPod workspace

```bash
# From WSL — DevPod auto-discovers .devcontainer/devcontainer.json
devpod up ~/git_wsl/alerts --ide none

# Or with VS Code:
devpod up ~/git_wsl/alerts --ide vscode
```

### Connect from phone (Termius + Tailscale)

1. SSH into WSL2: `100.109.194.122:22` (user: `sean`)
2. Run `claude-session -c alerts` to tunnel into the DevPod container
3. Auto-launches tmux → Claude Code

### Connect from WSL host

```bash
ssh alerts.devpod               # Direct DevPod tunnel
claude-session -c alerts        # Same, via claude-session wrapper
claude-session --devpod         # List available workspaces
```

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
| Copy mode | `Ctrl+b`, `[` |
| Paste | `Ctrl+b`, `]` |

## Configuration

### DevPod dotfiles setup (one-time)

```bash
devpod provider set-options docker DOTFILES_URL=https://github.com/mccarthysean/dotfiles
```

## Files

```
dotfiles/
├── install.sh          # Main installer (runs in every new container)
├── .tmux.conf          # tmux config (OSC 52, xterm-256color, status top)
├── bin/
│   └── claude-session  # tmux session manager script
└── .bashrc.d/
    └── *.sh            # Bash snippets (PATH, auto-launch on login)
```

## Safety

All devcontainers use `sleep infinity` as their command — no production services
(inserters, schedulers, MQTT listeners, web servers) auto-start. Development servers
must be launched manually inside each container.
