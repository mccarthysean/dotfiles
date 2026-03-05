#!/bin/bash
# DevPod dotfiles installer — runs inside each new container
# Installs tmux, Claude Code, claudes (session manager), and bash snippets
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

# ─── Install Claude Code if missing ───
if ! command -v claude &>/dev/null; then
    echo "  Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash 2>/dev/null
    echo "  ✓ Claude Code installed"
fi

# ─── tmux config (container version — OSC 52 clipboard, no win32yank) ───
if [ -f "$DOTFILES_DIR/.tmux.conf" ]; then
    cp "$DOTFILES_DIR/.tmux.conf" ~/
    echo "  ✓ .tmux.conf"
fi

# ─── claudes script ───
mkdir -p ~/.local/bin
if [ -f "$DOTFILES_DIR/bin/claudes" ]; then
    cp "$DOTFILES_DIR/bin/claudes" ~/.local/bin/
    chmod +x ~/.local/bin/claudes
    ln -sf ~/.local/bin/claudes ~/.local/bin/claude-session  # compat
    echo "  ✓ claudes"
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

echo "Dotfiles installed successfully."
