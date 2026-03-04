# Claude Code + dev server helpers for DevPod containers

# Ensure local bin is in PATH
export PATH="$HOME/.local/bin:$PATH"

# Auto-launch claude-session on SSH login (not already in tmux, not in VS Code)
if [ -n "$SSH_CONNECTION" ] && [ -z "$TMUX" ] && [ -z "$VSCODE_INJECTION" ]; then
    if command -v claude-session &>/dev/null; then
        claude-session
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
