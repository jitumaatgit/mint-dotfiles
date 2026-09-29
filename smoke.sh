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

# wezterm's utils.lua is plain Lua with no test framework available, so it ships
# a self-check. Run it from the repo path rather than the stowed one.
echo "🧪 Running wezterm utils self-check"
if ! lua5.1 "$REPO_ROOT/home/.config/wezterm/utils_test.lua"; then
  echo "🚫 utils self-check failed"
  exit 1
fi

echo "✅ Smoke test passed"
