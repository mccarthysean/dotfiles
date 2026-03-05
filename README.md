# DevPod Dotfiles

Shared dotfiles injected into every [DevPod](https://devpod.sh) container via `DOTFILES_URL`.
Provides tmux, Claude Code CLI, and the `claudes` session manager for phone-based
development via Termius + Tailscale.

## What Gets Installed

`install.sh` runs automatically inside each new DevPod container and installs:

| Component | Purpose |
|-----------|---------|
| **tmux** | Persistent terminal sessions that survive disconnects |
| **Claude Code CLI** | AI-powered coding assistant |
| **claudes** | tmux session manager (auto-launches on login) |
| **.tmux.conf** | Container-optimized tmux config (OSC 52 clipboard, status bar at top) |
| **.bashrc.d/** | Bash snippets (PATH, auto-launch claudes) |

## Architecture

```
Phone (Termius) → Tailscale VPN → WSL2 (100.109.194.122:22)
  → claudes → auto-detects workspace or shows menu → ssh WORKSPACE.devpod
  → Container auto-launches claudes → tmux → Claude Code
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
2. Run `claudes` — shows interactive menu of sessions + workspaces
3. Pick a workspace → auto-launches tmux → Claude Code

### Connect from WSL host

```bash
cd ~/git_wsl/rcom && claudes    # Auto-detects rcom workspace
claudes alerts                  # Connect to alerts workspace
claudes rcom frontend           # Connect to rcom-frontend session
claudes --list                  # List all workspaces + status
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
│   ├── claudes         # tmux session manager script
│   └── claude-session  # symlink → claudes (backwards compat)
└── .bashrc.d/
    └── *.sh            # Bash snippets (PATH, auto-launch on login)
```

## Safety

All devcontainers use `sleep infinity` as their command — no production services
(inserters, schedulers, MQTT listeners, web servers) auto-start. Development servers
must be launched manually inside each container.
