#!/usr/bin/env bash
# apply-cinnamon-copyq-keybinding.sh -- bind the clipboard-history hotkey in Cinnamon.
#
#   <Super>v   copyq toggle   show or hide the clipboard history window
#
# The slot bookkeeping is the one already used by
# apply-cinnamon-note-keybindings.sh, and for the same reason: Cinnamon custom
# keybinding slots are numbered, the live list of them is a separate key, and a
# slot that is not in custom-list is inert. Both have to be maintained, and that
# is exactly the part it is easy to get subtly wrong once. Slots are found by
# their command rather than by a fixed number, so reordering custom-list by hand
# does not strand the binding.
#
# The key is free: no gsettings keybinding schema on this machine (Cinnamon,
# muffin, GNOME, media-keys) binds <Super>v, and no schema under
# /usr/share/glib-2.0/schemas mentions it either.
#
# One thing separates this from the note script, and it is why this is a
# separate file rather than another row in it: a keybinding alone is not enough
# here. With no CopyQ instance running, `copyq toggle` exits 1 ("Cannot connect
# to server"), so a bound key alone produces a hotkey that silently does nothing
# after the next login. The XDG autostart entry that starts CopyQ is therefore
# part of this contract: apply refuses to write the key without it, and
# --check verifies it. It is deployed by stow from
# home/.config/autostart/copyq.desktop, not written by this script: writing it
# here would write through the stow symlink into the repo, and the next
# `stow -R` would then report the repo dirty.
#
# Idempotent. Re-running updates the existing slot instead of adding a second
# binding, so it is safe to run after any edit. It also repairs the slot that
# was configured by hand before this script existed.
#
#   apply-cinnamon-copyq-keybinding.sh            register (default)
#   apply-cinnamon-copyq-keybinding.sh --check    exit 1 if not registered
#   apply-cinnamon-copyq-keybinding.sh --remove   unbind and drop the slot
set -euo pipefail

SCHEMA='org.cinnamon.desktop.keybindings'
SLOT_SCHEMA='org.cinnamon.desktop.keybindings.custom-keybinding'
SLOT_PATH='/org/cinnamon/desktop/keybindings/custom-keybindings/'

# key|name|command
BINDINGS=(
  '<Super>v|clipboard history|copyq toggle'
)

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
AUTOSTART_DEST="$HOME/.config/autostart/copyq.desktop"
AUTOSTART_SRC="$REPO_ROOT/home/.config/autostart/copyq.desktop"

die() { printf '%s\n' "$*" >&2; exit 1; }

# Custom keybinding slots are numbered (custom1, custom2, ...) and the live list
# of them is a separate key; a slot that exists but is not in custom-list is
# inert. Both have to be maintained.
collect_slots() {
  gsettings get "$SCHEMA" custom-list | command tr -d "[]' " | command tr ',' '\n' | command sed '/^$/d'
}

# Word-split rather than newline-matched: the list arrives either as the
# newline-separated output of collect_slots or as a joined array, and matching
# against a literal $'\n' pattern silently fails on the latter. The note script
# carries both versions of this function; this one keeps only the one that wins.
list_has() {
  local want="$1" s
  for s in $2; do
    [[ "$s" == "$want" ]] && return 0
  done
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

# gsettings prints GVariant strings with their quotes ("'/path/to/thing'"),
# which would never compare equal to the bare value being looked for. Not used
# for `binding`: that one is a list, and its brackets are part of the value.
slot_string() {
  local value
  value="$(slot_value "$1" "$2")"
  case "$value" in
    \'*\') value="${value#?}" value="${value%?}" ;;
  esac
  printf '%s' "$value"
}

# The slot running this command, if any.
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

# The autostart entry is what makes the hotkey survive a reboot, so it is a
# precondition rather than an afterthought. Compared against the repo payload
# rather than just tested for existence, so a hand edit to the deployed file
# fails loudly the same way an out-of-sync Cinnamon theme does.
check_autostart() {
  [[ -f "$AUTOSTART_SRC" ]] ||
    die "copyq keybinding: repo payload $AUTOSTART_SRC is missing"
  [[ -e "$AUTOSTART_DEST" ]] ||
    die "copyq keybinding: $AUTOSTART_DEST is not deployed; run stow -t \"\$HOME\" -d \"$REPO_ROOT\" home"
  cmp -s "$AUTOSTART_SRC" "$AUTOSTART_DEST" ||
    die "copyq keybinding: $AUTOSTART_DEST has drifted from $AUTOSTART_SRC; run stow again"
  printf 'copyq keybinding: autostart entry deployed\n'
  return 0
}

# The command has to exist on this machine at all. The note script can test
# this with [[ -x ]] because its commands are absolute paths under $HOME; this
# one is a bare name, so it needs the PATH lookup instead.
check_installed() {
  local command="$1"
  command -v "${command%% *}" >/dev/null ||
    die "copyq keybinding: ${command%% *} is not installed"
}

# Both halves of the contract, for apply(). --check reports the same two
# things, but only after establishing that the slot exists; apply needs them
# as a precondition, because it is the path that would otherwise write a
# keybinding pointing at a command this machine does not have at all.
check_prerequisites() {
  local row command
  for row in "${BINDINGS[@]}"; do
    command="${row#*|}"; command="${command#*|}"
    check_installed "$command"
  done
  check_autostart
}

check_one() {
  local key="$1" want_name="$2" command="$3" slots slot
  slots="$(collect_slots)"
  if ! slot="$(find_slot "$command" "$slots")"; then
    printf 'copyq keybinding: %s not registered (no custom-keybinding slot runs %s)\n' "$key" "$command" >&2
    return 1
  fi
  list_has "$slot" "$slots" ||
    die "copyq keybinding: slot $slot exists but is not in $SCHEMA custom-list"
  [[ "$(slot_value "$slot" binding)" == "['${key}']" ]] ||
    die "copyq keybinding: $slot bound to $(slot_value "$slot" binding), expected ['${key}']"
  [[ "$(slot_string "$slot" name)" == "$want_name" ]] ||
    die "copyq keybinding: $slot named $(slot_string "$slot" name), expected $want_name"
  check_installed "$command"
  check_autostart ||
    die "copyq keybinding: autostart entry not deployed"
  printf 'copyq keybinding: %s -> %s (slot %s)\n' "$key" "$command" "$slot"
}

apply() {
  local -a slots=()
  local row key name command slot n=1
  # gsettings prints custom-list on one line, so mapfile is needed to get one
  # slot per line; read -a would put the whole list into element 0.
  mapfile -t slots < <(collect_slots)

  # Precondition before any dconf write, and not something only --check covers:
  # the path that writes the binding is the one that must refuse to write it.
  check_prerequisites

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
    printf 'copyq keybinding: %s -> %s (slot %s)\n' "$key" "$command" "$slot"
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
      printf 'copyq keybinding: removed %s (key %s)\n' "$slot" "$key"
    else
      printf 'copyq keybinding: %s was not registered\n' "$key"
    fi
  done

  write_slots "${slots[@]}"
  printf 'copyq keybinding: keybinding unbound. The autostart entry is stow-managed, not this script'\''s;\n'
  printf '                       it keeps CopyQ running either way, which is what the history needs.\n'
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
