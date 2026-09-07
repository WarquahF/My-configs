#!/usr/bin/env bash
# Notification bell state for Waybar (custom/notifications, return-type json).
# Shows the count of currently visible notifications; history size included
# in the tooltip. Requires: makoctl, jq.
set -euo pipefail

ICON=""

# emit <text> <class> <tooltip>: one Waybar JSON object, correctly escaped.
# jq owns the quoting so arbitrary notification text (quotes, backslashes,
# newlines) can never break the JSON and blank the module.
emit() { jq -cn --arg text "$1" --arg class "$2" --arg tooltip "$3" \
    '{text: $text, class: $class, tooltip: $tooltip}'; }

vis=0; hist=0
if command -v makoctl >/dev/null 2>&1; then
    vis="$(makoctl list -j 2>/dev/null | jq 'length' 2>/dev/null || echo 0)"
    hist="$(makoctl history -j 2>/dev/null | jq 'length' 2>/dev/null || echo 0)"
fi

if (( vis > 0 )); then
    # jq slices by codepoint, so truncation stays valid UTF-8.
    latest="$(makoctl list -j 2>/dev/null \
        | jq -r '.[0] | ((.app_name // "") + ": " + (.summary // ""))[0:100]' 2>/dev/null)"
    emit "$ICON $vis" "has-unread" \
        "$vis new notification(s)"$'\n'"Latest: $latest"$'\n'"Click for notification center"
elif (( hist > 0 )); then
    emit "$ICON" "empty" \
        "No new notifications ($hist in history)"$'\n'"Click for notification center"
else
    emit "$ICON" "empty" \
        "No notifications"$'\n'"Click for notification center"
fi
