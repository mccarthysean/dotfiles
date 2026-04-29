#!/bin/bash
# DevPod dotfiles installer — runs inside each new container
# Installs tmux, Claude Code, Codex, agents (session manager), and bash snippets
# Assumes Debian/Ubuntu-based containers (apt-get)

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

echo "Installing dotfiles from $DOTFILES_DIR..."

# ─── Install required packages if missing (Debian/Ubuntu) ───
PACKAGES_TO_INSTALL=()
command -v tmux &>/dev/null || PACKAGES_TO_INSTALL+=(tmux)
command -v curl &>/dev/null || PACKAGES_TO_INSTALL+=(curl)

if [ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]; then
    echo "  Installing packages: ${PACKAGES_TO_INSTALL[*]}..."
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq "${PACKAGES_TO_INSTALL[@]}" >/dev/null 2>&1
    echo "  ✓ Packages installed"
fi

# ─── Install GitHub CLI (gh) if missing ───
if ! command -v gh &>/dev/null; then
    echo "  Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | $SUDO dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq gh >/dev/null 2>&1
    echo "  ✓ GitHub CLI installed"
fi

# ─── Install AWS CLI if missing ───
if ! command -v aws &>/dev/null; then
    echo "  Installing AWS CLI..."
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -qo /tmp/awscliv2.zip -d /tmp
    $SUDO /tmp/aws/install --update >/dev/null 2>&1
    rm -rf /tmp/awscliv2.zip /tmp/aws
    echo "  ✓ AWS CLI installed"
fi

# ─── Install Claude Code if missing ───
if ! command -v claude &>/dev/null; then
    echo "  Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash 2>/dev/null
    echo "  ✓ Claude Code installed"
fi

# ─── Install Codex if missing ───
if ! command -v codex &>/dev/null; then
    echo "  Installing Codex..."
    if command -v bun &>/dev/null; then
        bun install -g @openai/codex >/dev/null 2>&1
    elif command -v npm &>/dev/null; then
        npm install -g @openai/codex >/dev/null 2>&1
    else
        echo "  Error: neither bun nor npm found. Cannot install Codex."
        exit 1
    fi
    echo "  ✓ Codex installed"
fi

# ─── tmux config (container version — OSC 52 clipboard, no win32yank) ───
if [ -f "$DOTFILES_DIR/.tmux.conf" ]; then
    cp "$DOTFILES_DIR/.tmux.conf" ~/
    echo "  ✓ .tmux.conf"
fi

# ─── agents script ───
mkdir -p ~/.local/bin
if [ -f "$DOTFILES_DIR/bin/agents" ]; then
    cp "$DOTFILES_DIR/bin/agents" ~/.local/bin/
    chmod +x ~/.local/bin/agents
    rm -f ~/.local/bin/claudes ~/.local/bin/claude-session
    echo "  ✓ agents"
fi

# ─── .bashrc ───
if [ -f "$DOTFILES_DIR/.bashrc" ]; then
    cp "$DOTFILES_DIR/.bashrc" ~/
    echo "  ✓ .bashrc"
fi

# ─── Bash snippets ───
mkdir -p ~/.bashrc.d
for f in "$DOTFILES_DIR"/.bashrc.d/*.sh; do
    [ -f "$f" ] || continue
    cp "$f" ~/.bashrc.d/
    echo "  ✓ .bashrc.d/$(basename "$f")"
done

# ─── Claude Code settings (provided by bind mount from ~/.claude-docker/) ───
if [ -f ~/.claude/settings.json ]; then
    hooks=$(grep -c '"hooks"' ~/.claude/settings.json 2>/dev/null || echo "0")
    if [ "$hooks" -gt 0 ]; then
        echo "  ✓ Claude Code settings.json (hooks active)"
    else
        echo "  ⚠ Claude Code settings.json exists but no hooks found"
    fi
fi

echo "Dotfiles installed successfully."
