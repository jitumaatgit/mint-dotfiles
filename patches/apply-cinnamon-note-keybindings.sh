#!/usr/bin/env bash
# apply-cinnamon-note-keybindings.sh -- bind the note workflow hotkeys in Cinnamon.
#
# These are the OS-level triggers for the note workflow. Cinnamon custom
# keybindings are the convention already in use on this machine (<Super>q runs
# wezterm), and they are preferable to the alternatives for one concrete
# reason: the command runs as the logged-in user, with the session's DISPLAY and
# PATH. keyd would work in more places, but /etc/keyd runs its `command()`
# bindings as root, so it would need to drop privileges and rebuild the user's
# environment before it could reach a socket in $XDG_RUNTIME_DIR.
#
#   <Super>t   nvim-tangent-capture          park a tangent in the parking lot
#   <Super>d   nvim-daily-note               go to (or focus) today's daily note
#   <Super>a   nvim-daily-note capture       add a task or a log entry to it
#
# The keys are free: no gsettings keybinding schema (Cinnamon, muffin, GNOME,
# metacity) binds a bare <Super>a, <Super>d or <Super>t. The nearest match,
# <Super>Tab, is a different key.
#
# One script rather than three: the slot bookkeeping (custom-list ordering,
# matching a slot by its command so re-ordering does not strand a binding) is
# the part that is easy to get subtly wrong once, and it is identical every
# time. Adding a fourth hotkey is a line in BINDINGS below.
#
# Idempotent. Re-running updates the existing slots instead of adding a second
# binding, so it is safe to run after any edit.
#
#   apply-cinnamon-note-keybindings.sh            register (default)
#   apply-cinnamon-note-keybindings.sh --check    exit 1 if any is not registered
#   apply-cinnamon-note-keybindings.sh --remove   unbind and drop the slots
set -euo pipefail

SCHEMA='org.cinnamon.desktop.keybindings'
SLOT_SCHEMA='org.cinnamon.desktop.keybindings.custom-keybinding'
SLOT_PATH='/org/cinnamon/desktop/keybindings/custom-keybindings/'

# key|name|command
BINDINGS=(
  '<Super>t|capture tangent|'"${HOME}/.local/bin/nvim-tangent-capture"
  '<Super>d|open daily note|'"${HOME}/.local/bin/nvim-daily-note"
  '<Super>a|capture task or log|'"${HOME}/.local/bin/nvim-daily-note capture"
)

die() { printf '%s\n' "$*" >&2; exit 1; }

# Custom keybinding slots are numbered (custom1, custom2, ...) and the live list
# of them is a separate key; a slot that exists but is not in custom-list is
# inert. Both have to be maintained.
collect_slots() {
  gsettings get "$SCHEMA" custom-list | command tr -d "[]' " | command tr ',' '\n' | command sed '/^$/d'
}

list_has() {
  case $'\n'"$2"$'\n' in *$'\n'"$1"$'\n'*) return 0 ;; esac
  return 1
}

write_slots() {
  local body="" sep="" s
  for s in "$@"; do
    body+="${sep}'${s}'"
    sep=','
  done
  gsettings set "$SCHEMA" custom-list "[${body}]"
}

slot_value() { gsettings get "${SLOT_SCHEMA}:${SLOT_PATH}$1/" "$2"; }
set_slot() { gsettings set "${SLOT_SCHEMA}:${SLOT_PATH}$1/" "$2" "$3"; }

# Whitespace-agnostic: the list arrives either as the newline-separated output
# of collect_slots or as a joined array, and comparing against a literal
# newline pattern silently fails on the latter.
list_has() {
  local want="$1" s
  for s in $2; do
    [[ "$s" == "$want" ]] && return 0
  done
  return 1
}
# Read a string-valued key as the bare value. gsettings prints GVariant strings
# with their quotes ("'/path/to/thing'"), which would never compare equal to the
# path being looked for. Not used for `binding`: that one is a list, and its
# brackets are part of the value.
slot_string() {
  local value
  value="$(slot_value "$1" "$2")"
  case "$value" in
    \'*\') value="${value#?}" value="${value%?}" ;;
  esac
  printf '%s' "$value"
}

# The slot running this command, if any. Matching on the command rather than
# reusing a fixed number means the script finds its own binding even if the user
# reordered custom-list by hand.
find_slot() {
  local want="$1" s
  for s in $2; do
    if [[ "$(slot_string "$s" command 2>/dev/null)" == "$want" ]]; then
      printf '%s' "$s"
      return 0
    fi
  done
  return 1
}

check_one() {
  local key="$1" want_name="$2" command="$3" slots slot
  slots="$(collect_slots)"
  if ! slot="$(find_slot "$command" "$slots")"; then
    printf 'note keybinding: %s not registered (no custom-keybinding slot runs %s)\n' "$key" "$command" >&2
    return 1
  fi
  list_has "$slot" "$slots" ||
    die "note keybinding: slot $slot exists but is not in $SCHEMA custom-list"
  [[ "$(slot_value "$slot" binding)" == "['${key}']" ]] ||
    die "note keybinding: $slot bound to $(slot_value "$slot" binding), expected ['${key}']"
  [[ "$(slot_string "$slot" name)" == "$want_name" ]] ||
    die "note keybinding: $slot named $(slot_string "$slot" name), expected $want_name"
  [[ -x "${command%% *}" ]] || die "note keybinding: ${command%% *} is missing or not executable (stow not run?)"
  printf 'note keybinding: %s -> %s (slot %s)\n' "$key" "$command" "$slot"
}
apply() {
  local -a slots=()
  local row key name command slot n=1
  # stops at the first newline, dropping every slot after custom1.
  mapfile -t slots < <(collect_slots)

  for row in "${BINDINGS[@]}"; do
    key="${row%%|*}"
    name="${row#*|}"; name="${name%%|*}"
    command="${row#*|*}"; command="${command#*|}"

    if ! slot="$(find_slot "$command" "${slots[*]:-}")"; then
      while list_has "custom$n" "${slots[*]:-}"; do
        n=$((n + 1))
      done
      slot="custom$n"
      slots+=("$slot")
    fi

    set_slot "$slot" name "$name"
    set_slot "$slot" binding "['${key}']"
    set_slot "$slot" command "$command"
    printf 'note keybinding: %s -> %s (slot %s)\n' "$key" "$command" "$slot"
  done

  write_slots "${slots[@]}"
  printf 'Cinnamon reads dconf live; no reload needed.\n'
}

remove() {
  local -a slots=()
  local row key command slot s
  local -a keep=()
  # mapfile, as in apply(): one slot per line, so read -a is not enough.
  mapfile -t slots < <(collect_slots)

  for row in "${BINDINGS[@]}"; do
    key="${row%%|*}"
    command="${row#*|*}"; command="${command#*|}"

    if slot="$(find_slot "$command" "${slots[*]:-}")"; then
      gsettings reset "${SLOT_SCHEMA}:${SLOT_PATH}${slot}/" name
      gsettings reset "${SLOT_SCHEMA}:${SLOT_PATH}${slot}/" binding
      gsettings reset "${SLOT_SCHEMA}:${SLOT_PATH}${slot}/" command
      keep=()
      for s in "${slots[@]}"; do
        [[ "$s" == "$slot" ]] || keep+=("$s")
      done
      slots=("${keep[@]}")
      printf 'note keybinding: removed %s (key %s)\n' "$slot" "$key"
    else
      printf 'note keybinding: %s was not registered\n' "$key"
    fi
  done

  write_slots "${slots[@]}"
}

case "${1:-}" in
  --check)
    rc=0
    for row in "${BINDINGS[@]}"; do
      check_one "${row%%|*}" "$(printf '%s' "${row#*|}" | command cut -d'|' -f1)" "${row#*|*|}" || rc=1
    done
    exit $rc
    ;;
  --remove) remove ;;
  "") apply ;;
  *) die "usage: $0 [--check|--remove]" ;;
esac
