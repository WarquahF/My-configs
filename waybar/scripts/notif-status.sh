#!/usr/bin/env bash
# Notification bell state for Waybar (custom/notifications, return-type json).
# Shows the count of currently visible notifications; history size included
# in the tooltip. Requires: makoctl, jq.
set -euo pipefail

ICON=""

vis=0; hist=0
if command -v makoctl >/dev/null 2>&1; then
    vis="$(makoctl list -j 2>/dev/null | jq 'length' 2>/dev/null || echo 0)"
    hist="$(makoctl history -j 2>/dev/null | jq 'length' 2>/dev/null || echo 0)"
fi

if (( vis > 0 )); then
    latest="$(makoctl list -j 2>/dev/null \
        | jq -r '.[0] | "\(.app_name): \(.summary)"' 2>/dev/null \
        | tr -d '"' | head -c 100)"
    printf '{"text":"%s %s","class":"has-unread","tooltip":"%s new notification(s)\\nLatest: %s\\nClick for notification center"}' \
        "$ICON" "$vis" "$vis" "$latest"
elif (( hist > 0 )); then
    printf '{"text":"%s","class":"empty","tooltip":"No new notifications (%s in history)\\nClick for notification center"}' \
        "$ICON" "$hist"
else
    printf '{"text":"%s","class":"empty","tooltip":"No notifications\\nClick for notification center"}' "$ICON"
fi
