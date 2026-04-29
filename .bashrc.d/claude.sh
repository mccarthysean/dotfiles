# Claude Code, Codex, and dev server helpers for DevPod containers

# Ensure local bin is in PATH
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"

# ntfy notification endpoint — shared ntfy-claude container on traefik-public Docker network
# Used by Claude Code hooks (ntfy-permission.sh, ntfy-idle.sh) for phone notifications
export NTFY_URL="${NTFY_URL:-http://ntfy-claude:80}"

# Auto-launch agents on interactive login (not already in tmux, not in VS Code)
# DevPod SSH tunnels don't set $SSH_CONNECTION, so we check for interactive shell instead
if [ -z "$TMUX" ] && [ -z "$VSCODE_INJECTION" ] && [[ $- == *i* ]]; then
    if command -v agents &>/dev/null; then
        agents
    fi
fi

# Dev server management aliases (project-agnostic — detect scripts location)
for scripts_dir in /project/scripts /workspace/scripts; do
    if [ -f "$scripts_dir/dev-servers.sh" ]; then
        alias ds="bash $scripts_dir/dev-servers.sh"
        alias ds-status="bash $scripts_dir/dev-servers.sh status"
        alias ds-start="bash $scripts_dir/dev-servers.sh start"
        alias ds-stop="bash $scripts_dir/dev-servers.sh stop"
        alias ds-restart="bash $scripts_dir/dev-servers.sh restart"
        break
    fi
done
