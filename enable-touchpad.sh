#!/usr/bin/env bash
# enable-touchpad.sh - make sure the touchpad is enabled, resolving the device
#                      by udev instead of by a hardcoded index.
#
# WHY IT USED TO BE WRONG
#   The previous version hardcoded /sys/class/input/input5. Three traps:
#     - input5 is "PS/2 Generic Mouse" on this machine; the touchpad is input30
#     - input numbers drift whenever a USB receiver replugs or the driver
#       re-enumerates, so any literal index is stale the moment it is written
#     - event numbers drift independently of input numbers: the touchpad is
#       input30 but its event node is event5. Reading "event5" out of
#       touchegg/libinput output and using it as an input index is almost
#       certainly how "input5" was arrived at.
#
# HOW IT RESOLVES
#   Asks udev for ID_INPUT_TOUCHPAD=1 - the same property libinput uses to
#   decide a device is a touchpad. Readable from /run/udev without root.
#   Verified to match exactly one device on this machine.
#
# WHAT IT CHANGES
#   1. org.cinnamon.desktop.peripherals.touchpad send-events -> 'enabled'
#      The only knob observed flipping on this machine. Every transition is
#      logged by touchpad-watch.service to ~/.local/state/touchpad-events.log,
#      with the process that made the change.
#   2. the kernel `inhibited` flag -> 0, when set. This is the mechanism
#      keyboard-toggle uses on the internal keyboard, and the only sysfs knob
#      that blocks input below X11.
#   3. power/control -> 'on', ONLY when the driver reports a runtime_status of
#      active or suspended. On this machine it reports 'unsupported', meaning
#      the device can never be runtime-suspended - there is nothing to keep
#      awake, so the write is skipped rather than performed for show.
#
# USAGE
#   ./enable-touchpad.sh            report, repair what is wrong, install unit
#   ./enable-touchpad.sh --report   report only, change nothing
#   ./enable-touchpad.sh --repair   repair only, do not touch the unit
#   ./enable-touchpad.sh --quiet    no output unless something is wrong
#
#   --repair is a leaf: it never re-installs the unit. The unit's ExecStart
#   uses it, so running the unit cannot make the script install and re-enable
#   the unit again.
set -uo pipefail

SCHEMA=org.cinnamon.desktop.peripherals.touchpad
KEY=send-events
UNIT_NAME=enable-touchpad.service
UNIT_DIR="$HOME/.config/systemd/user"
UNIT_FILE="$UNIT_DIR/$UNIT_NAME"
SELF="$(readlink -f "${BASH_SOURCE[0]}")"

MODE=install   # install | repair | report
QUIET=0

usage() {
    cat <<EOF
enable-touchpad.sh - resolve the touchpad by udev ID_INPUT_TOUCHPAD and keep it enabled

Usage:
  $0              report state, repair what is wrong, install the login unit
  $0 --report     report only, change nothing
  $0 --repair     repair only, do not touch the unit
  $0 --quiet      repair only and silently (this is what the unit runs)
  $0 --help       this message
EOF
}

say()  { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
ok()   { [ "$QUIET" -eq 1 ] || printf '  OK    %s\n' "$*"; }
warn() { printf '  WARN  %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

case "${1:-}" in
    -h|--help)  usage; exit 0 ;;
    --report)   MODE=report ;;
    --repair)   MODE=repair ;;
    --quiet)    MODE=repair; QUIET=1 ;;
    "")         ;;
    *)          printf 'unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
esac

# --- resolution ---------------------------------------------------------------

# Echo every /sys/class/input/inputN that udev classifies as a touchpad, one per
# line. The caller decides what to do when there is more than one.
touchpad_candidates() {
    local d
    for d in /sys/class/input/input*; do
        [ -e "$d/uevent" ] || continue
        if udevadm info --query=property --path="$d" 2>/dev/null \
             | grep -qx 'ID_INPUT_TOUCHPAD=1'; then
            printf '%s\n' "$d"
        fi
    done
}

resolve_touchpad() {
    local found count
    found="$(touchpad_candidates)"
    [ -n "$found" ] || return 1
    count="$(printf '%s\n' "$found" | wc -l)"
    [ "$count" -eq 1 ] || return 2
    printf '%s\n' "$found"
}

DEV=""
DEV_NAME=""
DEV_EVENT=""

load_device() {
    local rc=0 dev e
    dev="$(resolve_touchpad)" || rc=$?

    case "$rc" in
        0) ;;
        1) die "no input device has ID_INPUT_TOUCHPAD=1 - is the touchpad present?" ;;
        2) die "more than one touchpad found:
$(touchpad_candidates)
       refusing to guess which one you mean" ;;
        *) die "could not enumerate input devices" ;;
    esac

    DEV="$dev"
    DEV_NAME="$(cat "$dev/name")"

    # Through /sys/class the event node appears as a directory named eventM,
    # not a symlink, so glob for it rather than resolving a link target.
    for e in "$dev"/event*; do
        [ -e "$e" ] || continue
        DEV_EVENT="${e##*/}"
        break
    done
}

read_attr() { cat "$1" 2>/dev/null || printf 'unreadable'; }

# Write a sysfs attribute, reporting rather than dying on failure.
write_attr() {  # write_attr <path> <value> <label>
    local path=$1 value=$2 label=$3 current
    current="$(read_attr "$path")"

    if [ "$current" = "$value" ]; then
        ok "$label already ${value}"
        return 0
    fi

    if [ "$MODE" = report ]; then
        warn "$label is '${current}', should be '${value}'"
        return 1
    fi

    if printf '%s' "$value" | sudo tee "$path" > /dev/null 2>&1; then
        printf '  FIXED %s -> %s\n' "$label" "$value"
        printf '        %s\n' "$path" >&2
    else
        warn "could not write ${value} to $path"
        return 1
    fi
}

# --- report -------------------------------------------------------------------

report() {
    say "touchpad"
    say "  device                 $DEV"
    say "  name                   $DEV_NAME"
    say "  event node             /dev/input/${DEV_EVENT:-unknown}"
    say "  gsettings send-events  $(gsettings get "$SCHEMA" "$KEY" 2>/dev/null)"
    say "  inhibited              $(read_attr "$DEV/inhibited")"
    say "  power/control          $(read_attr "$DEV/power/control")"
    say "  power/runtime_status   $(read_attr "$DEV/power/runtime_status")"
    say "  power/runtime_enabled  $(read_attr "$DEV/power/runtime_enabled")"
}

# --- repair ------------------------------------------------------------------

repair() {
    local status rc=0

    # 1. the gsettings key: the one thing observed actually flipping.
    status="$(gsettings get "$SCHEMA" "$KEY" 2>/dev/null)"
    if [ "$status" = "'enabled'" ]; then
        ok "send-events already 'enabled'"
    elif [ "$MODE" = report ]; then
        warn "send-events is $status"
        rc=1
    elif gsettings set "$SCHEMA" "$KEY" enabled 2>/dev/null; then
        printf "  FIXED send-events -> 'enabled'\n"
    else
        warn "could not set send-events"
        rc=1
    fi

    # 2. the kernel inhibit flag, if this kernel exposes it.
    if [ -e "$DEV/inhibited" ]; then
        write_attr "$DEV/inhibited" 0 "inhibited" || rc=1
    fi

    # 3. runtime autosuspend, but only where it can actually happen.
    status="$(read_attr "$DEV/power/runtime_status")"
    case "$status" in
        active|suspended)
            write_attr "$DEV/power/control" on "power/control" || rc=1
            ;;
        *)
            say "  SKIP  power/control (runtime_status is '$status', so this device"
            say "        never runtime-suspends - nothing to keep awake)"
            ;;
    esac

    return "$rc"
}

# --- login unit ---------------------------------------------------------------

install_unit() {
    mkdir -p "$UNIT_DIR"
    cat > "$UNIT_FILE" <<EOF
# Generated by $SELF - do not edit by hand, re-run that script instead.
[Unit]
Description=Keep the touchpad enabled (resolves the device by ID_INPUT_TOUCHPAD)

[Service]
Type=oneshot
ExecStart=$SELF --repair --quiet

[Install]
WantedBy=default.target
EOF
    say "  wrote $UNIT_FILE"

    systemctl --user daemon-reload
    if systemctl --user enable --now "$UNIT_NAME" > /dev/null 2>&1; then
        say "  enabled + started $UNIT_NAME"
    else
        warn "could not enable $UNIT_NAME (try: systemctl --user status $UNIT_NAME)"
    fi
}

# --- main --------------------------------------------------------------------

load_device
say "enable-touchpad: $DEV_NAME ($DEV, event ${DEV_EVENT:-unknown})"

case "$MODE" in
    report)  report; repair > /dev/null ;;   # repair is a dry-run in this mode
    repair)  report; repair || warn "some repairs failed - see above" ;;
    *)       report; repair || warn "some repairs failed - see above"; install_unit ;;
esac