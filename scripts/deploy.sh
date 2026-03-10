#!/usr/bin/env bash
# deploy.sh — Push dotfiles updates to all running DevPod containers + WSL host
#
# Usage:
#   bash ~/git_wsl/dotfiles/scripts/deploy.sh
#
# What it does:
#   1. Updates the host-side claudes script at ~/.local/bin/claudes
#   2. Discovers all running DevPod containers
#   3. Pushes .tmux.conf, claudes, .bashrc, .bashrc.d/, and Claude Code settings.json to each container
#   4. Reloads tmux config in containers with active sessions
#
# Files are base64-encoded for safe transfer through SSH (no escaping issues).
# All containers are updated in parallel for speed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVPOD_WS_DIR="$HOME/.devpod/contexts/default/workspaces"
SSH_TIMEOUT=5

echo ""
echo "  Dotfiles Deploy"
echo "  ═══════════════"
echo ""

# ─── Step 1: Update host-side claudes ───

mkdir -p "$HOME/.local/bin"
cp "$SCRIPT_DIR/bin/claudes-host" "$HOME/.local/bin/claudes"
chmod +x "$HOME/.local/bin/claudes"
echo "  [host] Updated ~/.local/bin/claudes"

# ─── Step 2: Discover running DevPod containers ───

if [ ! -d "$DEVPOD_WS_DIR" ]; then
    echo "  No DevPod workspaces found at $DEVPOD_WS_DIR"
    echo ""
    echo "  Done (host only)."
    exit 0
fi

declare -a WORKSPACES=()
declare -A WS_UID=()

for ws_dir in "$DEVPOD_WS_DIR"/*/; do
    json="$ws_dir/workspace.json"
    [ -f "$json" ] || continue

    id=$(grep -o '"id":"[^"]*"' "$json" | head -1 | sed 's/"id":"//;s/"//')
    uid=$(grep -o '"uid":"[^"]*"' "$json" | head -1 | sed 's/"uid":"//;s/"//')
    [ -n "$id" ] || continue

    WORKSPACES+=("$id")
    WS_UID["$id"]="$uid"
done

# Check which workspaces have running containers
containers=$(docker ps --format "{{.Names}}" 2>/dev/null || true)
declare -a RUNNING=()

for ws in "${WORKSPACES[@]}"; do
    uid="${WS_UID[$ws]:-}"
    [ -n "$uid" ] || continue
    if echo "$containers" | grep -q "^${uid}-"; then
        RUNNING+=("$ws")
    fi
done

if [ ${#RUNNING[@]} -eq 0 ]; then
    echo "  No running DevPod containers found."
    echo ""
    echo "  Done (host only)."
    exit 0
fi

echo "  Found ${#RUNNING[@]} running containers: ${RUNNING[*]}"
echo ""

# ─── Step 3: Base64-encode files for safe transfer ───

TMUX_B64=$(base64 -w0 "$SCRIPT_DIR/.tmux.conf")
CLAUDES_B64=$(base64 -w0 "$SCRIPT_DIR/bin/claudes")
BASHRC_B64=$(base64 -w0 "$SCRIPT_DIR/.bashrc")

# Encode all .bashrc.d/ files as a tar archive
BASHRC_D_B64=$(tar -cf - -C "$SCRIPT_DIR" .bashrc.d/ 2>/dev/null | base64 -w0)

# Claude Code settings.json (hooks, permissions, MCP config)
# Source from the host's ~/.claude/settings.json (the canonical config)
SETTINGS_B64=$(base64 -w0 "$HOME/.claude/settings.json")

# ─── Step 4: Deploy to each container in parallel ───

for ws in "${RUNNING[@]}"; do
    (
        ssh -o ConnectTimeout="$SSH_TIMEOUT" -o BatchMode=yes \
            "${ws}.devpod" bash -s -- "$TMUX_B64" "$CLAUDES_B64" "$BASHRC_B64" "$BASHRC_D_B64" "$SETTINGS_B64" 2>&1 <<'REMOTE'
# Decode and install files
mkdir -p ~/.local/bin ~/.bashrc.d

echo "$1" | base64 -d > ~/.tmux.conf
echo "$2" | base64 -d > ~/.local/bin/claudes
chmod +x ~/.local/bin/claudes
ln -sf ~/.local/bin/claudes ~/.local/bin/claude-session
echo "$3" | base64 -d > ~/.bashrc
echo "$4" | base64 -d | tar -xf - -C ~/
echo "$5" | base64 -d > ~/.claude/settings.json

# Clean up any stale tmux socket (left behind by previous kill-server)
for sock in /tmp/tmux-*/default; do
    [ -S "$sock" ] || continue
    # If no tmux server is listening, the socket is stale — remove it
    if ! tmux list-sessions >/dev/null 2>&1; then
        rm -f "$sock"
    fi
done

# Reload tmux if running
if tmux source-file ~/.tmux.conf 2>/dev/null; then
    echo "files updated, tmux reloaded"
else
    echo "files updated (tmux not running)"
fi
REMOTE
    ) 2>&1 | sed "s/^/  [$ws] /" &
done

wait

echo ""
echo "  Done."
