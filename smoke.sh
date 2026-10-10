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

# The daily-note module shares the engine but pins its own decisions: which
# section a task or a log entry lands in, how it is spelled, and that going to
# the daily note focuses the window already showing it instead of burning a
# buffer.
echo "🧪 Running daily-note self-check"
if ! nvim --headless -u NONE -i NONE -l "$REPO_ROOT/home/.config/nvim/lua/custom/daily-note_test.lua"; then
  echo "🚫 daily-note self-check failed"
  exit 1
fi

# The system-wide trigger picks an editor by process ancestry. --diagnose is the
# read-only form of that path: it must run and must not open a float while
# looking. It exits 0 even with no editor running, which is a valid state.
echo "🧪 Running nvim-daily-note resolution check"
if ! "$REPO_ROOT/home/.local/bin/nvim-daily-note" --diagnose >/dev/null 2>&1; then
  echo "🚫 nvim-daily-note --diagnose failed"
  exit 1
fi

# The regression guard for the one bug that actually bit: the capture branch
# once stopped assigning its cold-start command, so the script handed wezterm
# nothing to run and <Super>a opened a blank terminal that looked like "a new
# terminal". Resolution is forced to fail with an empty XDG_RUNTIME_DIR, so the
# stub terminal below records whatever the cold start would really exec.
echo "🧪 Checking nvim-daily-note cold-start argv"
cold_dir=$(command mktemp -d)
command rm -rf "$cold_dir"
command mkdir -p "$cold_dir/stub"
command tee "$cold_dir/stub/wezterm" "$cold_dir/stub/x-terminal-emulator" \
    "$cold_dir/stub/notify-send" >/dev/null <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$(dirname "$0")/argv"
EOF
command chmod +x "$cold_dir/stub/wezterm" "$cold_dir/stub/x-terminal-emulator" "$cold_dir/stub/notify-send"

for action in "" capture; do
  rm -f "$cold_dir/stub/argv"
  XDG_RUNTIME_DIR="$cold_dir" PATH="$cold_dir/stub:$PATH" \
    "$REPO_ROOT/home/.local/bin/nvim-daily-note" $action </dev/null >/dev/null 2>&1
  if [[ ! -f "$cold_dir/stub/argv" ]]; then
    echo "🚫 nvim-daily-note ${action:-open}: cold start spawned no terminal"
    exit 1
  fi
  if ! grep -q 'nvim' "$cold_dir/stub/argv"; then
    echo "🚫 nvim-daily-note ${action:-open}: cold start ran no editor: $(cat "$cold_dir/stub/argv")"
    exit 1
  fi
  echo "   ${action:-open} -> $(cat "$cold_dir/stub/argv")"
done
command rm -rf "$cold_dir"

# The complaint that led to the notifications: the hotkey either worked or did
# not, and nothing said which. This forces the "cannot start anything" ending
echo "🧪 Checking nvim-daily-note failure reporting"
fail_dir=$(command mktemp -d)
command rm -rf "$fail_dir"
command mkdir -p "$fail_dir/bin"
# A PATH with exactly the tools the script is allowed to use and no terminal to
# start: wezterm and xdotool live in /usr/bin, so hiding them needs the allowlist
# to be the whole PATH rather than a directory in front of it.
for tool in nvim sed awk sort cut timeout tmux id bash env printf rm mkdir tee; do
  real=$(command -v "$tool" 2>/dev/null) || continue
  # Builtins need no symlink, and symlinking a bare name creates a link pointing
  # at itself.
  [[ "$real" == /* ]] || continue
  command ln -s "$real" "$fail_dir/bin/$tool"
done
# An absolute shebang: the stub cannot find the interpreter through a PATH that
# exists only to hide a terminal.
command tee "$fail_dir/bin/notify-send" >/dev/null <<'EOF'
#!/bin/bash
# ${0%/*} rather than dirname: this PATH exists to hold nothing that could
# start a terminal, so the stub cannot depend on one.
printf '%s\n' "$*" >"${0%/*}/argv"
EOF
command chmod +x "$fail_dir/bin/notify-send"

XDG_RUNTIME_DIR="$fail_dir" PATH="$fail_dir/bin" \
  "$REPO_ROOT/home/.local/bin/nvim-daily-note" capture </dev/null >/dev/null 2>&1 || true
argv_file="$fail_dir/bin/argv"
if [[ ! -f "$argv_file" ]]; then
  echo "🚫 nvim-daily-note reported its failure nowhere (notify-send not called)"
  exit 1
fi
if ! grep -qi 'not opened' "$argv_file"; then
  echo "🚫 nvim-daily-note reported the wrong thing: $(cat "$argv_file")"
  exit 1
fi
echo "   failure -> $(command tr '\n' ' ' <"$argv_file")"
command rm -rf "$fail_dir"

# The resolution contract is that exactly the socket address arrives on stdout.
# The caller reads it with a command substitution, so anything the
# terminal-raising helpers print would be handed on as part of the address --
# and that address is then used as a socket path, which fails in a way that
# reads as a wedged editor. A stub terminal reporting a title no window can have
# makes all of raise_wezterm_pane() run, ending on its "no such window" branch,
# without touching a real window.
echo "🧪 Checking editor resolution prints nothing but the socket"
raise_dir=$(command mktemp -d)
command rm -rf "$raise_dir"
command mkdir -p "$raise_dir/bin"
command tee "$raise_dir/bin/wezterm" >/dev/null <<'EOF'
#!/bin/bash
printf 'WINID TABID PANEID WORKSPACE SIZE TITLE CWD\n'
printf '   99    99      0 default 80x24 smoke-no-such-window title\n'
EOF
command chmod +x "$raise_dir/bin/wezterm"
resolve_out=$(PATH="$raise_dir/bin:$PATH" bash -c '
  source "$1/home/.local/lib/nvim-editor-socket.sh"
  raise_wezterm_pane 0 || true
' _ "$REPO_ROOT" 2>/dev/null)
if [[ -n "$resolve_out" ]]; then
  echo "🚫 raise_wezterm_pane polluted stdout: '$resolve_out'"
  exit 1
fi
echo "   clean"
command rm -rf "$raise_dir"

# The note hotkeys live in dconf, outside this repo, so --check is the only thing
# that notices them drifting or never having been applied at all. One call checks
# all three (tangent, daily note, capture) because they share the slot logic.
echo "🧪 Checking Cinnamon note keybindings"
if ! "$REPO_ROOT/patches/apply-cinnamon-note-keybindings.sh" --check; then
  echo "🚫 note keybindings not registered; run patches/apply-cinnamon-note-keybindings.sh"
  exit 1
fi

# Unlike the note keys, this one's command is not a script this repo versions,
# so on a fresh clone with no CopyQ installed the keying cannot exist and a
# hard failure here would be wrong. --check is also what asserts the autostart
# entry: dconf alone gives a hotkey that silently dies at the next login.
if command -v copyq >/dev/null; then
  echo "🧪 Checking Cinnamon copyq keybinding"
  if ! "$REPO_ROOT/patches/apply-cinnamon-copyq-keybinding.sh" --check; then
    echo "🚫 copyq keybinding not registered; run patches/apply-cinnamon-copyq-keybinding.sh"
    exit 1
  fi
else
  echo "⏭  copyq not installed; skipping copyq keybinding check"
fi

# wezterm keybinding check: an event with no handler is silent, and a duplicate
# binding silently disables one of the two. Loaded, not grep'd, for the reason
# quick_select_test.py documents.
echo "🧪 Running wezterm note-keybinding check"
if ! python3 "$REPO_ROOT/home/.config/wezterm/note_keys_test.py"; then
  echo "🚫 wezterm note-keybinding check failed"
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
