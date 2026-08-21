#!/usr/bin/env bash
# keyboard-toggle.sh
#
# Disables/re-enables the internal AT keyboard by writing to the kernel's
# 'inhibited' sysfs attribute. This works at the evdev layer and blocks
# input regardless of X11/Wayland/keyd.
#
# Usage:
#   keyboard-toggle disable  - Disable internal keyboard
#   keyboard-toggle enable   - Enable internal keyboard  
#   keyboard-toggle status   - Show current state
#   keyboard-toggle test     - Test if external keyboard is present

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
INTERNAL_KBD_NAME="AT Translated Set 2 keyboard"
EXT_VENDOR="320f"
EXT_PRODUCT="5088"

usage() {
    echo "Usage: $SCRIPT_NAME {disable|enable|status|test}" >&2
    echo "" >&2
    echo "Commands:" >&2
    echo "  disable  - Disable internal keyboard (kernel inhibit)" >&2
    echo "  enable   - Enable internal keyboard (kernel uninhibit)" >&2
    echo "  status   - Show current state" >&2
    echo "  test     - Test if external keyboard is present" >&2
    exit 1
}

# Find the internal keyboard's inhibited sysfs file
find_inhibited_file() {
    for dev in /sys/devices/platform/i8042/serio0/input/input*/; do
        name_file="${dev}name"
        if [[ -f "$name_file" ]]; then
            name=$(cat "$name_file" 2>/dev/null || true)
            if [[ "$name" == "$INTERNAL_KBD_NAME" ]]; then
                echo "${dev}inhibited"
                return 0
            fi
        fi
    done
    return 1
}

# Check if internal keyboard is currently enabled
is_enabled() {
    local inhibited_file=$(find_inhibited_file)
    if [[ -n "$inhibited_file" && -f "$inhibited_file" ]]; then
        local val=$(cat "$inhibited_file" 2>/dev/null || echo "0")
        [[ "$val" == "0" ]]
        return $?
    fi
    return 1
}

# Disable internal keyboard (write 1 to inhibited)
disable_keyboard() {
    local inhibited_file=$(find_inhibited_file)
    if [[ -n "$inhibited_file" && -f "$inhibited_file" ]]; then
        echo 1 > "$inhibited_file"
        echo "$SCRIPT_NAME: disabled internal keyboard"
    else
        echo "$SCRIPT_NAME: internal keyboard not found" >&2
        exit 1
    fi
}

# Enable internal keyboard (write 0 to inhibited)
enable_keyboard() {
    local inhibited_file=$(find_inhibited_file)
    if [[ -n "$inhibited_file" && -f "$inhibited_file" ]]; then
        echo 0 > "$inhibited_file"
        echo "$SCRIPT_NAME: enabled internal keyboard"
    else
        echo "$SCRIPT_NAME: internal keyboard not found" >&2
        exit 1
    fi
}

# Check if external keyboard is connected
external_keyboard_present() {
    for dev in /sys/bus/usb/devices/*/; do
        vid_file="${dev}idVendor"
        pid_file="${dev}idProduct"
        if [[ -f "$vid_file" && -f "$pid_file" ]]; then
            vid=$(cat "$vid_file" 2>/dev/null || true)
            pid=$(cat "$pid_file" 2>/dev/null || true)
            if [[ "$vid" == "$EXT_VENDOR" && "$pid" == "$EXT_PRODUCT" ]]; then
                return 0
            fi
        fi
    done
    return 1
}

case "$1" in
    disable)
        if is_enabled; then
            disable_keyboard
        else
            echo "$SCRIPT_NAME: internal keyboard already disabled"
        fi
        ;;
    enable)
        if ! is_enabled; then
            enable_keyboard
        else
            echo "$SCRIPT_NAME: internal keyboard already enabled"
        fi
        ;;
    status)
        if is_enabled; then
            echo "Internal keyboard is ENABLED"
        else
            echo "Internal keyboard is DISABLED"
        fi
        exit 0
        ;;
    test)
        if external_keyboard_present; then
            echo "External keyboard (Telink IQUNIX 2.4GHz) is PRESENT"
            exit 0
        else
            echo "External keyboard (Telink IQUNIX 2.4GHz) is NOT present"
            exit 1
        fi
        ;;
    "")
        usage
        ;;
    *)
        echo "Unknown argument: $1" >&2
        usage
        ;;
esac

exit 0