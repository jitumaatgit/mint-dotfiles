#!/usr/bin/env bash
# sync-from-home.sh - copy updated configs from $HOME into the repo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
HOME_DIR="$HOME"
REPO_HOME="$REPO_ROOT/home"

echo "🔄 Syncing from $HOME_DIR to $REPO_HOME"
echo "📝 Using .gitignore for exclusions"

# Use rsync with exclude patterns from .gitignore if it exists
RSYNC_ARGS=(-av --delete --exclude-from="$REPO_ROOT/.gitignore")

# Add extra exclusions for safety
RSYNC_ARGS+=(--exclude='.git' --exclude='.git/' --exclude='install.sh' --exclude='sync-from-home.sh' --exclude='README.md' --exclude='.stow-localrc')

# Run rsync
rsync "${RSYNC_ARGS[@]}" "$HOME_DIR/" "$REPO_HOME/"

echo "✅ Sync complete!"
echo "💡 Review changes with: git diff && git add -p"