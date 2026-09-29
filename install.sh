#!/usr/bin/env bash
# install.sh - symlink dotfiles using GNU stow

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

echo "🔧 Checking for GNU stow..."
if ! command -v stow &>/dev/null; then
    echo "❌ GNU stow not found. Please install it first:"
    echo "   Ubuntu/Debian: sudo apt install stow"
    echo "   Fedora: sudo dnf install stow"
    echo "   macOS: brew install stow"
    exit 1
fi

echo "📦 Symlinking dotfiles from $REPO_ROOT/home to $HOME"
stow -t "$HOME" -d "$REPO_ROOT" home

# bat resolves custom themes from a compiled cache in $HOME/.cache/bat, and it
# does NOT build that cache on first run. Without this, a fresh machine gets the
# stowed theme file but silently renders with bat's default theme, emitting only
# a stderr line nobody sees:
#   [bat warning]: Unknown theme 'Catppuccin-Mocha', using default.
# Verified: before this step a comment rendered #75715e (default); after,
# #6c7086 (the theme's overlay0). Must run AFTER stow, since that is what puts
# the theme in place.
if command -v bat &>/dev/null; then
    bat cache --build &>/dev/null
    echo "🔨 Built bat theme cache"
fi

echo "✅ Installation complete!"
echo "💡 Tip: To remove a specific module later, run:"
echo "   stow -D <module> -t \$HOME"
