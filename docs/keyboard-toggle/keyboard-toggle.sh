#!/usr/bin/env bash
# keyboard-toggle.sh
#
# Disables/re-enables the internal AT keyboard by managing the udev flag file.
# This script works with the udev rules in 99-keyboard-toggle.rules.
#
# The udev rules use /run/keyboard-toggle-external-present as a flag to
# indicate when the external keyboard is present. When the flag exists,
# the internal keyboard is ignored by libinput.
#
# Usage:
#   keyboard-toggle disable  - Disable internal keyboard (set flag)
#   keyboard-toggle enable   - Enable internal keyboard (clear flag)
#   keyboard-toggle status   - Show current state
#   keyboard-toggle test     - Test if external keyboard is present

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
FLAG_FILE="/run/keyboard-toggle-external-present"
INTERNAL_KBD="AT Translated Set 2 keyboard"

usage() {
    echo "Usage: $SCRIPT_NAME {disable|enable|status|test}" >&2
    echo "" >&2
    echo "Commands:" >&2
    echo "  disable  - Disable internal keyboard (set flag file)" >&2
    echo "  enable   - Enable internal keyboard (clear flag file)" >&2
    echo "  status   - Show current state" >&2
    echo "  test     - Test if external keyboard is present" >&2
    exit 1
}

case "$1" in
    disable)
        touch "$FLAG_FILE"
        echo "$SCRIPT_NAME: internal keyboard disabled (flag set)"
        ;;
    enable)
        rm -f "$FLAG_FILE"
        echo "$SCRIPT_NAME: internal keyboard enabled (flag cleared)"
        ;;
    status)
        if [[ -f "$FLAG_FILE" ]]; then
            echo "Internal keyboard is DISABLED (external keyboard present)"
        else
            echo "Internal keyboard is ENABLED (no external keyboard)"
        fi
        exit 0
        ;;
    test)
        # Check if any USB device matches the external keyboard
        if udevadm info --query=all --name=/dev/input/event* 2>/dev/null | grep -q "ID_VENDOR_ID=320f.*ID_MODEL_ID=5088"; then
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

# Trigger udev to re-evaluate the internal keyboard
# This applies the LIBINPUT_IGNORE_DEVICE property based on flag state
udevadm trigger --subsystem-match=input --attr-match=name="$INTERNAL_KBD" 2>/dev/null || true

exit 0