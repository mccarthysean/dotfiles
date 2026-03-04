# DevPod Dotfiles

Shared dotfiles injected into every [DevPod](https://devpod.sh) container via `DOTFILES_URL`.
Provides SSH access, tmux, Claude Code CLI, and the `claude-session` script for phone-based
development via Termius + Tailscale.

## What Gets Installed

`install.sh` runs automatically inside each new DevPod container and installs:

| Component | Purpose |
|-----------|---------|
| **tmux** | Persistent terminal sessions that survive disconnects |
| **openssh-server** | SSH into containers from phone or host |
| **Claude Code CLI** | AI-powered coding assistant |
| **claude-session** | tmux session manager (auto-launches on SSH login) |
| **.tmux.conf** | Container-optimized tmux config (OSC 52 clipboard, status bar at top) |
| **.bashrc.d/** | Bash snippets (PATH, auto-launch claude-session on SSH) |

## SSH Port Allocation

Each repo gets a unique SSH port so multiple workspaces can run simultaneously:

| Repo | SSH Port | Stack |
|------|----------|-------|
| rcom | 2222 | Flask + FastAPI + React |
| wibble | 2223 | FastAPI + React 19 |
| spartans-hockey | 2224 | FastAPI + React |
| myijack-api | 2225 | FastAPI |
| timescale_db | 2226 | Python + TimescaleDB |
| gateway_can_to_mqtt | — | `network_mode: host` (port mapping N/A) |
| postgresql_scheduler | 2228 | Python + PostgreSQL |
| alerts | 2229 | Python + Alerting |
| mqtt_jobs | 2230 | Python + MQTT |
| mqtt_listener | 2231 | Python + MQTT |
| traefik_ijack | 2232 | Traefik |
| monitoring | 2233 | Grafana + Loki |

Port mappings are configured per-repo in `docker-compose.dev.yml` as `"XXXX:22"`.

## Architecture

```
Phone (Termius) → Tailscale VPN → WSL2 (100.109.194.122:XXXX)
  → Docker port mapping → Container sshd (port 22)
  → .bashrc auto-launches claude-session → tmux → Claude Code
```

DevPod's dotfiles injection clones this repo and runs `install.sh` inside every new container,
so SSH + tmux + Claude Code work without modifying any project Dockerfile.

## Usage

### Create a DevPod workspace

```bash
# From WSL — DevPod auto-discovers .devcontainer/devcontainer.json
devpod up ~/git_wsl/wibble --ide none

# Or with VS Code:
devpod up ~/git_wsl/wibble --ide vscode
```

### Connect from phone (Termius + Tailscale)

| Setting | Value |
|---------|-------|
| Host | `100.109.194.122` |
| Port | See table above (e.g., 2223 for wibble) |
| User | `root` |
| Auth | SSH keys (auto-configured) or password `claude` |

On connect, `.bashrc` auto-launches `claude-session` → tmux → Claude Code.

### Connect from WSL host

```bash
claude-session -c 2223    # SSH into wibble container
claude-session --ports    # Show port allocation table
```

### Manage workspaces

```bash
devpod list                                    # Show all workspaces
devpod stop wibble                             # Stop (saves resources)
devpod up ~/git_wsl/wibble --ide none          # Restart
devpod delete wibble                           # Remove entirely
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

### SSH authentication

The `~/.ssh` directory is bind-mounted read-only into containers at `/root/.ssh`.
`install.sh` copies `*.pub` files into `/root/.ssh/authorized_keys` automatically.
Password fallback: `root:claude`.

## Files

```
dotfiles/
├── install.sh          # Main installer (runs in every new container)
├── .tmux.conf          # tmux config (OSC 52, xterm-256color, status top)
├── bin/
│   └── claude-session  # tmux session manager script
└── .bashrc.d/
    └── *.sh            # Bash snippets (PATH, auto-launch on SSH)
```

## Safety

All devcontainers use `sleep infinity` as their command — no production services
(inserters, schedulers, MQTT listeners, web servers) auto-start. Development servers
must be launched manually inside each container.
