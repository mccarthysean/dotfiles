#!/bin/bash
# DevPod dotfiles installer — runs inside each new container
# Installs tmux, SSH server, Claude Code, claude-session, and bash snippets
# Assumes Debian/Ubuntu-based containers (apt-get)

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

echo "Installing dotfiles from $DOTFILES_DIR..."

# ─── Install required packages if missing (Debian/Ubuntu) ───
PACKAGES_TO_INSTALL=()
command -v tmux &>/dev/null || PACKAGES_TO_INSTALL+=(tmux)
command -v sshd &>/dev/null || PACKAGES_TO_INSTALL+=(openssh-server)
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

# ─── SSH server for remote access (phone via Termius + Tailscale) ───
install_ssh() {
    $SUDO mkdir -p /run/sshd
    $SUDO sed -i 's/#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    $SUDO sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    echo "root:claude" | $SUDO chpasswd 2>/dev/null

    # Set up authorized_keys from mounted .ssh
    $SUDO mkdir -p /root/.ssh
    $SUDO chmod 700 /root/.ssh
    if [ -d /root/.ssh ]; then
        for pubkey in /root/.ssh/*.pub; do
            if [ -f "$pubkey" ]; then
                $SUDO cat "$pubkey" >> /root/.ssh/authorized_keys
            fi
        done
        [ -f /root/.ssh/authorized_keys ] && $SUDO chmod 600 /root/.ssh/authorized_keys
    fi

    # Start sshd if not already running
    if ! pgrep -x sshd >/dev/null 2>&1; then
        $SUDO /usr/sbin/sshd 2>/dev/null || true
    fi
    echo "  ✓ SSH server configured and started"
}

if [ -f /etc/ssh/sshd_config ]; then
    install_ssh
fi

# ─── tmux config (container version — OSC 52 clipboard, no win32yank) ───
if [ -f "$DOTFILES_DIR/.tmux.conf" ]; then
    cp "$DOTFILES_DIR/.tmux.conf" ~/
    echo "  ✓ .tmux.conf"
fi

# ─── claude-session script ───
mkdir -p ~/.local/bin
if [ -f "$DOTFILES_DIR/bin/claude-session" ]; then
    cp "$DOTFILES_DIR/bin/claude-session" ~/.local/bin/
    chmod +x ~/.local/bin/claude-session
    echo "  ✓ claude-session"
fi

# ─── Bash snippets ───
mkdir -p ~/.bashrc.d
for f in "$DOTFILES_DIR"/.bashrc.d/*.sh; do
    [ -f "$f" ] || continue
    cp "$f" ~/.bashrc.d/
    echo "  ✓ .bashrc.d/$(basename "$f")"
done

# ─── Source .bashrc.d from .bashrc if not already configured ───
if ! grep -q 'bashrc.d' ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc <<'SNIPPET'

# Source custom dotfile snippets
for f in ~/.bashrc.d/*.sh; do [ -r "$f" ] && . "$f"; done
SNIPPET
    echo "  ✓ Added .bashrc.d sourcing to .bashrc"
fi

echo "Dotfiles installed successfully."
