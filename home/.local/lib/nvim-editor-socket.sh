#!/usr/bin/env bash
# nvim-editor-socket.sh -- find the nvim the user is actually looking at.
#
# Sourced by nvim-tangent-capture and nvim-daily-note: both need to reach the
# running editor, and the reasoning below is the same either way. Nothing here
# knows what the keystroke was for, so a third feature needs a script, not a
# third copy of this file.
#
# Sourcing contract:
#   nvim_editor_socket <fire-expr> <ping-expr>
#     Runs <fire-expr> in the right editor and prints its socket address on
#     stdout. Nothing printed and a non-zero status when no editor answers.
#     With `diagnose=1` (set by the caller before calling) nothing is fired and
#     only reachability is reported, because opening a float to find out which
#     editor *would* be used is not a diagnostic, it is the feature.
#
# --- Why finding the right nvim is not a one-liner ---------------------------
#
# Nvim is a client-server program (see `:h tui.txt`): running `nvim` starts a
# builtin *UI client*, which starts a `nvim --embed` *server* as a child. The
# server holds the buffers, loads the config, runs the capture module, and owns
# the socket; the client owns the terminal and has no socket at all.
#
# So neither of the two obvious heuristics works:
#   * "the socket owner is the editor"  -- true, but it is not the process that
#     looks like an editor. It has no controlling terminal (`tty_nr` 0, `tpgid`
#     -1 in /proc/<pid>/stat), exactly like an unrelated hidden `nvim --embed`
#     spawned by other tooling. Filtering on "has a tty" therefore rejects the
#     one socket that matters and, worse, a naive scan can pick a *different*
#     hidden server and open the float somewhere nobody can see it.
#   * "the pane's pid is the editor"    -- in the client-server build the pane's
#     pid is the *client*, which has no socket.
#
# What does work is process ancestry: a socket is the right one when its owner
# is the tmux pane's process or a descendant of it (pane -> client -> server).
# Lineage is also what makes several sessions distinguishable, so no
# cooperation from the nvim side is needed beyond the socket it already has.
#
# Resolution order:
#   1. $NVIM                        -- we are inside nvim's :terminal
#   2. the tmux pane running nvim   -- attached/active pane first
#   3. any editor with a terminal   -- the only one, newest first if several
#   4. start one                    -- a new window, float already armed

diagnose=0
verbose=0

say() { (( verbose )) && printf '%s\n' "$*" >&2; return 0; }

# --- process and socket helpers ---------------------------------------------

# The pid in a server address. nvim builds generated addresses as
# `stdpath("run")/<name>.<pid>.<counter>` (see :h serverstart()), so the name is
# a shortcut to the owner that costs nothing.
socket_pid() {
  local base="${1##*/}"
  base="${base#nvim.}"
  printf '%s' "${base%%.*}"
}

# Strip the parenthesised comm field first: it may contain spaces, which would
# shift every column after it. Fields then start at the process state.
proc_field() {
  command sed -e 's/^[0-9]* ([^)]*) //' "/proc/$1/stat" 2>/dev/null | command awk -v f="$2" '{print $f}'
}

proc_parent() { proc_field "$1" 2; }
has_tty() { local tty; tty="$(proc_field "$1" 5)"; [[ -n "$tty" && "$tty" != 0 ]]; }

# An editor the user can see. Either it owns a terminal itself (single-process
# builds) or its parent does (this build, where the parent is the UI client).
lineage_visible() {
  local pid="$1" depth=0
  while [[ -n "$pid" && "$pid" != 0 && $depth -lt 2 ]]; do
    has_tty "$pid" && return 0
    pid="$(proc_parent "$pid")"
    depth=$((depth + 1))
  done
  return 1
}

# Is `ancestor` the process itself or one of its ancestors?
lineage_has() {
  local pid="$1" want="$2" depth=0
  while [[ -n "$pid" && "$pid" != 0 && $depth -lt 12 ]]; do
    [[ "$pid" == "$want" ]] && return 0
    pid="$(proc_parent "$pid")"
    depth=$((depth + 1))
  done
  return 1
}

# Owner of a socket, trustworthy even if the naming convention ever changes:
# fall back to asking the server when the pid in the name is not alive.
owner_pid() {
  local pid
  pid="$(socket_pid "$1")"
  if kill -0 "$pid" 2>/dev/null; then
    printf '%s' "$pid"
    return 0
  fi
  pid="$(timeout 3 nvim --server "$1" --remote-expr 'getpid()' 2>/dev/null)"
  [[ "$pid" =~ ^[0-9]+$ ]] && printf '%s' "$pid"
}

# Ask the server to run <expr>. Returns non-zero for a stale socket file, a
# server whose session predates this feature, or a wedged process; `timeout` so
# a hung nvim cannot hang the hotkey.
fire_socket() {
  local sock="$1" expr="$2"
  [[ -n "$sock" && -S "$sock" ]] || return 1
  timeout 3 nvim --server "$sock" --remote-expr "$expr" >/dev/null 2>&1
}

# Read-only reachability, for --diagnose: opening a float to find out which
# editor *would* be used is not a diagnostic, it is the feature. `exists()`
# returns 2 for a user command, which doubles as "this nvim has the module
# loaded" -- a session started before this was installed answers 0, and that is
# worth saying rather than reporting a bare failure.
ping_socket() {
  local sock="$1" ping="$2" out
  [[ -n "$sock" && -S "$sock" ]] || return 1
  out="$(timeout 3 nvim --server "$sock" --remote-expr "$ping" 2>/dev/null)"
  if [[ "$out" != 2 ]]; then
    say "  $sock: answered, but has no matching command (started before this was installed?)"
    return 1
  fi
  return 0
}

attempt_socket() {
  if (( diagnose )); then
    ping_socket "$1" "$3"
  else
    fire_socket "$1" "$2"
  fi
}

# --- bring the resolved editor's terminal to the front --------------------
#
# Resolving an editor the user cannot see is only half the job. A float opened
# in a window that sits behind another one reads exactly like a hotkey that did
# nothing, so the window has to come forward too -- and finding it is a
# different lookup from the socket, because the editor and the window holding
# it are reached by different means.
#
# `wezterm cli activate-pane` is deliberately not used: it activates a pane
# inside the *focused* GUI window and leaves the X11 focus where it was, so it
# cannot raise a window that is already in the background (verified on this
# machine: exit 0, `_NET_ACTIVE_WINDOW` unchanged). The X window has to be
# raised directly, which needs its id -- and the only link from a wezterm pane
# to its X window is the title, because wezterm names a window after the tab
# that is showing.
#
# The tmux pane is remembered when resolution came through one, so the window
# holding the terminal is showing the right half of it as well.
NVIM_EDITOR_TMUX_PANE=""

# The wezterm pane id, from the environment the running editor inherited:
# wezterm exports WEZTERM_PANE to every process it spawns, so the server carries
# it verbatim and the id cannot be stale. The raw `$VAR` form rather than
# environ("VAR") on purpose -- environ() is not available in this configuration
# (E118, too many arguments) and this is the one that answers.
editor_wezterm_pane() {
  local sock="$1" pane
  pane="$(timeout 3 nvim --server "$sock" --remote-expr '$WEZTERM_PANE' 2>/dev/null)"
  [[ "$pane" =~ ^[0-9]+$ ]] && printf '%s' "$pane"
}

# The title a pane shows, which is the name of the X window showing it.
# Built from the table rather than JSON because nothing else here needs the
# extra columns. Column 7 is the CWD: the title is everything up to it, so a
# CWD containing spaces does not shift it.
wezterm_pane_title() {
  wezterm cli list 2>/dev/null |
    command awk -v want="$1" '
      $3 == want { title = ""; for (i = 6; i < NF; i++) title = title (title ? " " : "") $i; print title }'
}

# Raise the X window showing `pane`.
#
# The title match is exact on both sides: `search` is a substring/regex match,
# so its hits are re-read with getwindowname, which also keeps a title with
# regex characters in it harmless.
#
# Ambiguity is left alone rather than guessed at. Two windows can both be
# titled "nvim"; raising the wrong one is worse than reporting that the one
# holding the editor could not be identified.
raise_wezterm_pane() {
  local pane="$1" title win
  command -v wezterm >/dev/null 2>&1 && command -v xdotool >/dev/null 2>&1 || return 1

  title="$(wezterm_pane_title "$pane")"
  if [[ -z "$title" ]]; then
    say "wezterm pane $pane: no title; cannot find its window"
    return 1
  fi

  local -a found=()
  while read -r win; do
    [[ -n "$win" ]] || continue
    if [[ "$(xdotool getwindowname "$win" 2>/dev/null)" == "$title" ]]; then
      found+=("$win")
    fi
  done < <(xdotool search --onlyvisible --name "$title" 2>/dev/null)

  case ${#found[@]} in
    1)
      if xdotool windowactivate "${found[0]}" 2>/dev/null; then
        say "raised window \"$title\" (${found[0]})"
        return 0
      fi
      return 1
      ;;
    0)
      say "no visible window titled \"$title\"; the editor may be behind a window title that has changed"
      return 1
      ;;
    *)
      say "${#found[@]} visible windows are titled \"$title\"; not guessing which one"
      return 1
      ;;
  esac
}

# Bring the pane holding the editor forward inside tmux, so the terminal window
# that shows it is showing the right half. Errors are ignored: an
# unattached session still has its active window moved, which is a no-op until
# it is attached to.
select_tmux_pane() {
  local pane="$1"
  [[ -n "$pane" ]] || return 0
  tmux select-window -t "$pane" >/dev/null 2>&1
  tmux select-pane -t "$pane" >/dev/null 2>&1
  return 0
}

# Bring the editor forward, wherever it is hiding. Never fatal: the capture has
# already been fired when this runs, so a terminal that cannot be found costs a
# notification and nothing else.
raise_editor_terminal() {
  local sock="$1"
  select_tmux_pane "$NVIM_EDITOR_TMUX_PANE"

  local pane
  pane="$(editor_wezterm_pane "$sock")"
  if [[ -z "$pane" ]]; then
    say "no wezterm pane for $sock; terminal left where it is"
    return 1
  fi
  raise_wezterm_pane "$pane"
}

# --- resolution --------------------------------------------------------------

sockets=()
owners=()

collect_sockets() {
  local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" sock pid
  for sock in "$runtime_dir"/nvim.*; do
    [[ -S "$sock" ]] || continue
    pid="$(owner_pid "$sock")"
    if [[ -z "$pid" ]]; then
      say "$sock: no live owner (stale)"
      continue
    fi
    sockets+=("$sock")
    owners+=("$pid")
    say "candidate $sock pid $pid"
  done
}

# Pane lines ordered most-interesting-first: attached and focused panes before
# panes in detached sessions.
panes_by_rank() {
  tmux list-panes -a -F '#{?session_attached,0,2} #{?window_active,0,1} #{?pane_active,0,1} #{pane_id} #{pane_pid}' 2>/dev/null |
    command awk '{ rank = ($1 == 0 && $2 == 0 && $3 == 0) ? 0 : ($1 == 0 ? 1 : 2); print rank, $4, $5 }' |
    command sort -n -k1,1
}

nvim_editor_socket() {
  local expr="$1" ping="$2"

  sockets=()
  owners=()
  NVIM_EDITOR_TMUX_PANE=""
  collect_sockets

  # Reached, so the entry has already been fired into the editor. Bringing the
  # window forward is safe now, and it is a no-op when it is already the one
  # the user is looking at.
  resolved() {
    local sock="$1" pane="${2:-}"
    NVIM_EDITOR_TMUX_PANE="$pane"
    printf '%s' "$sock"
    (( diagnose )) || raise_editor_terminal "$sock"
    return 0
  }

  if [[ -n "${NVIM:-}" ]]; then
    say "\$NVIM: $NVIM"
    if attempt_socket "$NVIM" "$expr" "$ping"; then
      resolved "$NVIM"
      return 0
    fi
    say "\$NVIM did not answer; falling through"
  fi

  if tmux list-panes -a >/dev/null 2>&1; then
    local rank pane_id pane_pid i
    while read -r rank pane_id pane_pid; do
      [[ -n "${pane_pid:-}" ]] || continue
      for i in "${!sockets[@]}"; do
        if lineage_has "${owners[i]}" "$pane_pid"; then
          say "tmux $pane_id pid $pane_pid (rank $rank) -> ${sockets[i]} pid ${owners[i]}"
          if attempt_socket "${sockets[i]}" "$expr" "$ping"; then
            resolved "${sockets[i]}" "$pane_id"
            return 0
          fi
        fi
      done
    done < <(panes_by_rank)
  else
    say "tmux: no server"
  fi

  # No tmux, or no pane with an editor in it. Any editor whose process tree
  # reaches a terminal qualifies; if there are several, the newest wins, because
  # the alternative -- refusing -- helps nobody.
  local -a ordered=()
  local pid
  while read -r pid; do
    for i in "${!owners[@]}"; do
      [[ "${owners[i]}" == "$pid" ]] || continue
      if lineage_visible "$pid"; then
        ordered+=("${sockets[i]}")
        say "standalone ${sockets[i]} pid $pid"
      else
        say "${sockets[i]} pid $pid: no terminal in its lineage; skipped"
      fi
    done
  done < <(printf '%s\n' "${owners[@]}" | command sort -nr)

  (( ${#ordered[@]} > 1 )) && say "${#ordered[@]} standalone editors; trying newest first"
  local sock
  for sock in "${ordered[@]}"; do
    if attempt_socket "$sock" "$expr" "$ping"; then
      resolved "$sock"
      return 0
    fi
  done

  say "no reachable editor"
  return 1
}

