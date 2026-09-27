#!/usr/bin/env bash
# enable-touchpad.sh
# Ensure the system‑wide touchpad (input5) stays enabled at every login.

INPUT_PATH="/sys/class/input/input5/power/runtime_enabled"

# Enable the device for the current session
if [ -f "$INPUT_PATH" ]; then
    echo "Enabling touchpad…"
    printf '1' | sudo tee "$INPUT_PATH" > /dev/null
    echo "touchpad enabled: $(cat "$INPUT_PATH")"
else
    echo "Error: $INPUT_PATH not found – touchpad device may have a different path.\nRun 'libinput list-devices | grep -i touchpad' to locate the correct input node." >&2
    exit 1
fi

# Install or update a user‑level systemd unit to enable it on login
UNIT_DIR="$HOME/.config/systemd/user"
mkdir -p "$UNIT_DIR"
UNIT_FILE="$UNIT_DIR/enable-touchpad.service"
cat > "$UNIT_FILE" <<'EOF'
[Unit]
Description=Keep touchpad enabled after login
After=systemd-logind.service

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'printf "1" | sudo tee /sys/class/input/input5/power/runtime_enabled > /dev/null'

[Install]
WantedBy=default.target
EOF

# Reload user daemons and enable the unit
echo "Reloading systemd user daemon…"
systemctl --user daemon-reload

echo "Enabling the unit…"
systemctl --user enable --now enable-touchpad
echo "Done. Verify with 'systemctl --user status enable-touchpad'"
