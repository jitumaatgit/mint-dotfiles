#!/usr/bin/env bash
# Smoke test for dotfiles repo
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Deploy stow
stow -t "$HOME" -d "$REPO_ROOT" home

# Verify that a key symlink exists
if [ ! -L "$HOME/.bashrc" ]; then
  echo "🚫 .bashrc symlink missing"
  exit 1
fi

echo "✅ Smoke test passed"