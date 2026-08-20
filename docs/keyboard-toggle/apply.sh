#!/usr/bin/env bash
# apply.sh - Install keyboard-toggle helper and udev rule
#
# This script installs the helper script and the udev rule to:
#   • /usr/local/sbin/keyboard-toggle (helper)
#   • /etc/udev/rules.d/99-keyboard-toggle.rules
#
# It then reloads udev and forces the correct state: if an external
# keyboard is already connected, it will issue the disable action.
#
# Usage: sudo ./apply.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

BIN_DIR="/usr/local/sbin"
RULES_DIR="/etc/udev/rules.d"
LOGFILE="/var/log/keyboard-toggle.log"

# Ensure log file exists and is readable by root
if [[ ! -f "$LOGFILE" ]]; then
    touch "$LOGFILE"
    chown root:root "$LOGFILE"
    chmod 0644 "$LOGFILE"
fi

# Install helper script
install -m 0755 -o root -g root "${SCRIPT_DIR}/keyboard-toggle.sh" "${BIN_DIR}/keyboard-toggle"

# Install udev rule
install -m 0644 -o root -g root "${SCRIPT_DIR}/99-keyboard-toggle.rules" "${RULES_DIR}/99-keyboard-toggle.rules"

# Reload udev
udevadm control --reload

echo "✅ udev rules reloaded."

# Optionally trigger udev on the external keyboard device
# Find any matching USB device in the current system
usb_dev=$(udevadm info --query=path --name=/dev/input/event* 2>/dev/null | grep -m1 -E '/usb.*[0-9]-[0-9]+:.?' || true)
if [[ -n "$usb_dev" ]]; then
    # The device exists; send a quick trigger to force state
    udevadm trigger --subsystem-match=usb --name="${usb_dev#*/devices/}"
    echo "🔌 External USB keyboard detected – ensuring internal keyboard is disabled."
    "${BIN_DIR}/keyboard-toggle" disable
else
    echo "⌨️  No external keyboard detected – internal keyboard remains enabled."
fi

# Success message
cat <<'EOF'
✅ Installation complete.

To test:
  • Plug/unplug the external keyboard and watch:
      • the internal laptop keyboard stops working when connected.
      • it returns when disconnected.
  • Check current state: sudo keyboard-toggle status
  • View log: tail -f /var/log/keyboard-toggle.log
EOF
