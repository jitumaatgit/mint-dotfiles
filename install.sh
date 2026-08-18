#!/usr/bin/env bash
# install.sh - symlink dotfiles using GNU stow

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

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

echo "✅ Installation complete!"
echo "💡 Tip: To remove a specific module later, run:"
echo "   stow -D <module> -t \$HOME"