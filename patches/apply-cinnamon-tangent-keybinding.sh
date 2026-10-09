#!/usr/bin/env bash
# apply-cinnamon-tangent-keybinding.sh -- bind <Super>t to nvim-tangent-capture.
#
# This is the OS-level trigger for the tangent capture. Cinnamon custom
# keybindings are the convention already in use on this machine (<Super>q runs
# wezterm), and they are preferable to the alternatives for one concrete
# reason: the command runs as the logged-in user, with the session's DISPLAY and
# PATH. keyd would work in more places, but /etc/keyd runs its `command()`
# bindings as root, so it would need to drop privileges and rebuild the user's
# environment before it could reach a socket in $XDG_RUNTIME_DIR.
#
# <Super>t is free: no gsettings keybinding schema (Cinnamon, muffin, GNOME,
# metacity, runtime) binds it. The nearest match, <Super>Tab, is a different
# key.
#
# Idempotent. Re-running updates the existing slot instead of adding a second
# binding, so it is safe to run after any edit.
#
#   apply-cinnamon-tangent-keybinding.sh            register (default)
#   apply-cinnamon-tangent-keybinding.sh --check    exit 1 if not registered as expected
#   apply-cinnamon-tangent-keybinding.sh --remove   unbind and drop the slot
set -euo pipefail

KEY='<Super>t'
NAME='capture tangent'
COMMAND="${HOME}/.local/bin/nvim-tangent-capture"

SCHEMA='org.cinnamon.desktop.keybindings'
SLOT_SCHEMA='org.cinnamon.desktop.keybindings.custom-keybinding'
SLOT_PATH='/org/cinnamon/desktop/keybindings/custom-keybindings/'

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
  local s
  for s in $1; do
    if [[ "$(slot_string "$s" command 2>/dev/null)" == "$COMMAND" ]]; then
      printf '%s' "$s"
      return 0
    fi
  done
  return 1
}

check() {
  local slots slot
  slots="$(collect_slots)"
  if ! slot="$(find_slot "$slots")"; then
    printf 'tangent keybinding: not registered (no custom-keybinding slot runs %s)\n' "$COMMAND" >&2
    return 1
  fi
  list_has "$slot" "$slots" ||
    die "tangent keybinding: slot $slot exists but is not in $SCHEMA custom-list"
  [[ "$(slot_value "$slot" binding)" == "['${KEY}']" ]] ||
    die "tangent keybinding: $slot bound to $(slot_value "$slot" binding), expected ['${KEY}']"
  [[ "$(slot_string "$slot" name)" == "$NAME" ]] ||
    die "tangent keybinding: $slot named $(slot_string "$slot" name), expected $NAME"
  [[ -x "$COMMAND" ]] || die "tangent keybinding: $COMMAND is missing or not executable (stow not run?)"
  printf 'tangent keybinding: %s -> %s (slot %s)\n' "$KEY" "$COMMAND" "$slot"
}

apply() {
  local slots slot n
  slots="$(collect_slots)"

  if slot="$(find_slot "$slots")"; then
    :
  else
    n=1
    while list_has "custom$n" "$slots"; do
      n=$((n + 1))
    done
    slot="custom$n"
    slots="${slots}
${slot}"
  fi

  set_slot "$slot" name "$NAME"
  set_slot "$slot" binding "['${KEY}']"
  set_slot "$slot" command "$COMMAND"
  write_slots $slots

  printf 'tangent keybinding: %s -> %s (slot %s)\n' "$KEY" "$COMMAND" "$slot"
  printf 'Cinnamon reads dconf live; no reload needed.\n'
}

remove() {
  local slots slot s
  slots="$(collect_slots)"
  if ! slot="$(find_slot "$slots")"; then
    printf 'tangent keybinding: nothing to remove\n'
    return 0
  fi

  gsettings reset "${SLOT_SCHEMA}:${SLOT_PATH}${slot}/" name
  gsettings reset "${SLOT_SCHEMA}:${SLOT_PATH}${slot}/" binding
  gsettings reset "${SLOT_SCHEMA}:${SLOT_PATH}${slot}/" command

  local -a keep=()
  for s in $slots; do
    [[ "$s" == "$slot" ]] || keep+=("$s")
  done
  write_slots "${keep[@]}"

  printf 'tangent keybinding: removed slot %s\n' "$slot"
}

case "${1:-}" in
  --check) check ;;
  --remove) remove ;;
  "") apply ;;
  *) die "usage: $0 [--check|--remove]" ;;
esac
