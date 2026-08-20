#!/usr/bin/env bash
# keyboard-toggle.sh
#
# Disables/re-enables the internal AT keyboard via serio unbind/bind.
# This script is intended to be called from a udev rule on external keyboard connect/disconnect.
# It is idempotent and logs actions to /var/log/keyboard-toggle.log.

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
LOGFILE="/var/log/keyboard-toggle.log"
SERIO_ID="serio0"   # the serio device for the internal AT keyboard
AT_DRIVER="atkbd"

# Limit to 'disable', 'enable', or 'status'.  The script is tiny; 0/1/2 arguents.
case "$1" in
    disable)
        ACTION="unbind"
        ;;
    enable)
        ACTION="bind"
        ;;
        status)
            if [[ -f /sys/bus/serio/drivers/${AT_DRIVER}/$SERIO_ID ]]; then
                STATE="bound"
            else
                STATE="unbound"
            fi
            echo "Keyboard is currently $STATE" >&2
            exit 0
            ;;
    "")
        >&2 echo "Usage: $SCRIPT_NAME {disable|enable|status}"
        exit 1
        ;;
    *)
        >&2 echo "Unknown argument: $1"
        exit 1
        ;;
esac

# Helper: check if already in target state.
has_state() {
    local action=$1
    if [[ "$action" == "unbind" ]]; then
        # If the driver has bindings then it's bound. Unbinding removes them.
        [[ -f /sys/bus/serio/drivers/${AT_DRIVER}/$SERIO_ID ]] && return 0
    else
        [[ ! -f /sys/bus/serio/drivers/${AT_DRIVER}/$SERIO_ID ]] && return 0
    fi
    return 1
}

if has_state "$ACTION"; then
    echo "$SCRIPT_NAME: already $ACTIONd" | tee -a "$LOGFILE"
    exit 0
fi

# Perform the action using sysfs.
        if [[ "$ACTION" == "unbind" ]]; then
            echo "$SCRIPT_NAME: unbound internal keyboard ($SERIO_ID)" | tee -a "$LOGFILE"
            echo "$SERIO_ID" > /sys/bus/serio/drivers/${AT_DRIVER}/unbind
        elif [[ "$ACTION" == "bind" ]]; then
            echo "$SCRIPT_NAME: bound internal keyboard ($SERIO_ID)" | tee -a "$LOGFILE"
            echo "$SERIO_ID" > /sys/bus/serio/drivers/${AT_DRIVER}/bind
        fi

exit 0