#!/usr/bin/env bash
# apply.sh - Install the hibernation resume_offset guard.
#
# Installs:
#   • /usr/local/sbin/check-swap-offset                      (the checker/repairer)
#   • /etc/systemd/system/check-swap-offset.service           (oneshot run)
#   • /etc/systemd/system/check-swap-offset.timer            (every 30 min)
#   • /usr/lib/systemd/system-sleep/50-check-swap-offset      (before each sleep)
#
# It then enables the timer and runs a first check.
#
# Usage: sudo ./apply.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_DIR="/usr/local/sbin"
UNIT_DIR="/etc/systemd/system"
HOOK_DIR="/usr/lib/systemd/system-sleep"

# --- install files -----------------------------------------------------------
install -m 0755 -o root -g root "${SCRIPT_DIR}/check-swap-offset" "${BIN_DIR}/check-swap-offset"
install -m 0644 -o root -g root "${SCRIPT_DIR}/check-swap-offset.service" "${UNIT_DIR}/check-swap-offset.service"
install -m 0644 -o root -g root "${SCRIPT_DIR}/check-swap-offset.timer" "${UNIT_DIR}/check-swap-offset.timer"
install -d -m 0755 "${HOOK_DIR}"
install -m 0755 -o root -g root "${SCRIPT_DIR}/50-check-swap-offset" "${HOOK_DIR}/50-check-swap-offset"

# --- activate ----------------------------------------------------------------
systemctl daemon-reload
systemctl enable --now check-swap-offset.timer

echo "✅ Installed hibernation resume_offset guard."
echo

# --- first check (non-fatal: report the truth rather than hiding it) ---------
if "${BIN_DIR}/check-swap-offset" --check; then
    echo
    echo "✅ resume_offset is in sync with /swapfile."
else
    echo
    echo "⚠️  resume_offset has drifted. Repairing now..."
    "${BIN_DIR}/check-swap-offset"
fi

cat <<'EOF'

What this protects against
--------------------------
Hibernation resumes via resume_offset= on the kernel command line, which is the
swapfile's first physical extent in 4 KiB blocks. Recreating, resizing or
defragmenting /swapfile changes it. With a stale value the boot initramfs cannot
find the image and the hibernated session is silently lost, leaving only:

    PM: Image not found (code -16)

Trigger points
--------------
  • systemd timer, every 30 min (and 2 min after boot)
  • systemd-sleep hook, immediately before every suspend/hibernate
  • manually: sudo check-swap-offset

Inspect
-------
  sudo check-swap-offset --check
  systemctl list-timers check-swap-offset.timer
  journalctl -u check-swap-offset.service
EOF
