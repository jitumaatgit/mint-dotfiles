#!/usr/bin/env bash
# $1 = title (may be empty), $2 = message
# app_name is always `ntfy` — Part 2's forwarder whitelists omp's app_name,
# guaranteeing ntfy popups are never re-forwarded.
set -euo pipefail

title="${1:-ntfy}"
body="$2"

# Sound follows the tags the publisher set, so one script covers every sender:
# a soft blip for ordinary notifications, an alarm clock for pomo timers, and
# a bell for overdue checkmate tasks. `NTFY_TAGS` is set by ntfy-client for the
# subscribed command; the publisher does not need a local config to match.
sound_for() {
  case ",${NTFY_TAGS:-}," in
    *,alarm_clock,*) echo alarm-clock-elapsed.oga ;;
    *,warning,*)     echo bell.oga ;;
    *)               echo dialog-information.oga ;;
  esac
}

# Played after the popup is queued, in the background, so a missing sound
# device can neither delay nor suppress the notification (`set -e`).
SOUND="${NTFY_SOUND:-/usr/share/sounds/freedesktop/stereo/$(sound_for)}"

if command -v notify-send >/dev/null 2>&1; then
  notify-send -a ntfy "$title" "$body"
else
  busctl call --user org.freedesktop.Notifications /org/freedesktop/Notifications \
    org.freedesktop.Notifications.Notify susssasa{sv}i \
    ntfy 0 "" "$title" "$body" 0 0 8000
fi

# Every ntfy popup goes through here, so this is also what makes due-task and
# pomo alerts audible. Backgrounded so the client does not wait on the sound,
# and `timeout` so a player that cannot reach the device cannot pile up — one
# stuck process per notification is how a burst once left tens of thousands.
timeout 5 paplay "$SOUND" >/dev/null 2>&1 &
