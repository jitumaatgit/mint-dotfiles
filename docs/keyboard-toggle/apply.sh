#!/usr/bin/env bash
# apply.sh - Install keyboard-toggle udev rules and helper script
#
# This script installs the udev rules and helper script to:
#   • /usr/local/sbin/keyboard-toggle (helper script)
#   • /etc/udev/rules.d/99-keyboard-toggle.rules
#
# It then reloads udev and sets the initial state based on whether
# an external keyboard is currently connected.
#
# Usage: sudo ./apply.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

BIN_DIR="/usr/local/sbin"
RULES_DIR="/etc/udev/rules.d"
FLAG_FILE="/run/keyboard-toggle-external-present"
VENDOR_ID="320f"
PRODUCT_ID="5088"

# Install helper script
install -m 0755 -o root -g root "${SCRIPT_DIR}/keyboard-toggle.sh" "${BIN_DIR}/keyboard-toggle"

# Install udev rule
install -m 0644 -o root -g root "${SCRIPT_DIR}/99-keyboard-toggle.rules" "${RULES_DIR}/99-keyboard-toggle.rules"

# Clean up any existing flag file to ensure fresh state
rm -f "$FLAG_FILE"

# Reload udev
udevadm control --reload

echo "✅ udev rules reloaded."

# Check if external keyboard is currently connected by scanning USB devices
# for matching vendor/product ID.
found=0
for dev in /sys/bus/usb/devices/*/; do
    vid_file="${dev}idVendor"
    pid_file="${dev}idProduct"
    if [[ -f "$vid_file" && -f "$pid_file" ]]; then
        vid=$(cat "$vid_file" 2>/dev/null || true)
        pid=$(cat "$pid_file" 2>/dev/null || true)
        if [[ "$vid" == "$VENDOR_ID" && "$pid" == "$PRODUCT_ID" ]]; then
            found=1
            break
        fi
    fi
done

if [[ $found -eq 1 ]]; then
    echo "🔌 External USB keyboard detected – disabling internal keyboard."
    touch "$FLAG_FILE"
    "${BIN_DIR}/keyboard-toggle" disable
else
    echo "⌨️  No external keyboard detected – internal keyboard remains enabled."
    rm -f "$FLAG_FILE"
fi

# Trigger udev to apply rules to all existing devices
udevadm trigger --subsystem-match=input --attr-match=name="AT Translated Set 2 keyboard"

# Success message
cat <<'EOF'
✅ Installation complete.

To test:
  • Plug/unplug the external keyboard and watch:
      • the internal laptop keyboard stops working when connected.
      • it returns when disconnected.
  • Check current state: sudo keyboard-toggle status
  • Test external detection: sudo keyboard-toggle test
  • Manually disable: sudo keyboard-toggle disable
  • Manually enable: sudo keyboard-toggle enable

Note: The internal keyboard is disabled via libinput ignore, which is
persistent across events and works with Cinnamon Wayland.
EOF