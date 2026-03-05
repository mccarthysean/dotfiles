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
| **.tmux.conf** | Container-optimized tmux config (OSC 52 clipboard, right-click paste, status bar at top) |
| **.bashrc** | Shell config (history, aliases, auto-venv, sources .bashrc.d/) |
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
claudes frontend                # From rcom dir → auto-creates rcom-frontend
claudes --list                  # List all workspaces + status
```

Running `claudes` twice from the same workspace auto-creates numbered sessions
(`rcom`, `rcom-2`, `rcom-3`, etc.) when the previous session already has a client attached.
Detached sessions re-attach normally.

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
| Paste | `Ctrl+b`, `]` or right-click |

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
automatically — installing tmux, Claude Code, claudes, .bashrc, and .tmux.conf.

### 3. Install the host-side `claudes` script

The host-side script lives on your WSL machine (not inside containers). It handles workspace
discovery, auto-detection, and SSH tunneling into DevPod containers.

```bash
mkdir -p ~/.local/bin
cp ~/git_wsl/dotfiles/bin/claudes-host ~/.local/bin/claudes
chmod +x ~/.local/bin/claudes
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

The host-side `claudes` reads this token and passes it via `CLAUDE_CODE_OAUTH_TOKEN` env var
through SSH, so containers authenticate automatically.

### 5. Create your first DevPod workspace

```bash
devpod up ~/git_wsl/myproject --ide none
```

Then connect:

```bash
cd ~/git_wsl/myproject
claudes
```

## Files

```
dotfiles/
├── install.sh          # Main installer (runs in every new container)
├── .bashrc             # Shell config (history, aliases, auto-venv, sources .bashrc.d/)
├── .tmux.conf          # tmux config (OSC 52, right-click paste, status top)
├── bin/
│   ├── claudes         # Container-side tmux session manager
│   ├── claudes-host    # Host-side (WSL) orchestrator — backup copy
│   └── claude-session  # symlink → claudes (backwards compat)
└── .bashrc.d/
    └── *.sh            # Bash snippets (PATH, auto-launch on login)
```

## Safety

All devcontainers use `sleep infinity` as their command — no production services
(inserters, schedulers, MQTT listeners, web servers) auto-start. Development servers
must be launched manually inside each container.
