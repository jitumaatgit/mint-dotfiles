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

# The quick-select patterns are Lua long strings, and a pattern ending in "]"
# needs a doubled bracket or Lua silently swallows the entries after it. That
# corruption passes `luac -p`, so this test loads the real config instead.
echo "🧪 Running wezterm quick-select pattern test"
if ! python3 "$REPO_ROOT/home/.config/wezterm/quick_select_test.py"; then
  echo "🚫 quick-select pattern test failed"
  exit 1
fi

# The tangent capture module is deliberately vanilla Lua, so it can be checked
# with no plugins in the way. -i NONE as well as -u NONE: the test asserts that
# registers come out untouched, which only means something if it is not
# starting from the machine's shada.
echo "🧪 Running tangent-capture self-check"
if ! nvim --headless -u NONE -i NONE -l "$REPO_ROOT/home/.config/nvim/lua/custom/tangent-capture_test.lua"; then
  echo "🚫 tangent-capture self-check failed"
  exit 1
fi

# The system-wide trigger picks an editor by process ancestry. --diagnose is the
# read-only form of that path: it must run and must not open a float while
# looking. It exits 0 even with no editor running, which is a valid state.
echo "🧪 Running nvim-tangent-capture resolution check"
if ! "$REPO_ROOT/home/.local/bin/nvim-tangent-capture" --diagnose >/dev/null 2>&1; then
  echo "🚫 nvim-tangent-capture --diagnose failed"
  exit 1
fi

# The hotkey lives in dconf, outside this repo, so --check is the only thing
# that notices it drifting or never having been applied at all.
echo "🧪 Checking Cinnamon tangent keybinding"
if ! "$REPO_ROOT/patches/apply-cinnamon-tangent-keybinding.sh" --check; then
  echo "🚫 tangent keybinding not registered; run patches/apply-cinnamon-tangent-keybinding.sh"
  exit 1
fi


# The Chicago95 Cinnamon override has to stay applied to the theme, not just to
# a copy of it. --check is a pure read and exits 1 when the live stylesheet has
# drifted from the versioned payload, which is exactly what happens when the
# theme is re-extracted from upstream. Skips itself when the theme is not
# installed, so this stays runnable on a fresh clone.
if [ -f "$HOME/.themes/Chicago95/cinnamon/cinnamon.css" ]; then
  echo "🧪 Running Chicago95 Cinnamon override sync check"
  if ! "$REPO_ROOT/patches/apply-cinnamon6-override.sh" --check; then
    echo "🚫 Cinnamon override out of sync; re-run patches/apply-cinnamon6-override.sh"
    exit 1
  fi

  echo "🧪 Running Cinnamon selector coverage gate"
  if ! python3 "$REPO_ROOT/patches/cinnamon6-coverage.py" --gate --quiet; then
    echo "🚫 Cinnamon selector coverage regressed"
    exit 1
  fi
else
  echo "⏭  Chicago95 not installed; skipping Cinnamon override checks"
fi

echo "✅ Smoke test passed"
