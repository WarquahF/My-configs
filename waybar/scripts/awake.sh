#!/usr/bin/env bash
# Keep-awake toggle for Waybar (click the coffee icon).
# Holds a logind inhibitor (idle + sleep) via systemd-inhibit inside a
# transient user unit — no daemons, no extra packages, no pidfiles.
# State = whether the unit is active, so a dead inhibitor can never
# leave the bar stuck showing the wrong state.
# Usage: awake.sh status   -> JSON for waybar (return-type json)
#        awake.sh toggle   -> flip on/off with a notification
set -euo pipefail

UNIT="waybar-awake"
ICON_ON=""
ICON_OFF=""

is_on() { systemctl --user is-active -q "$UNIT" 2>/dev/null; }

cmd_status() {
    if is_on; then
        printf '{"text":"%s","class":"awake-on","tooltip":"Awake: ON — PC will not idle or sleep\\nClick to allow sleep"}' "$ICON_ON"
    else
        printf '{"text":"%s","class":"awake-off","tooltip":"Awake: OFF — idle and sleep allowed\\nClick to keep PC awake"}' "$ICON_OFF"
    fi
}

cmd_toggle() {
    if is_on; then
        systemctl --user stop "$UNIT" 2>/dev/null || true
        notify-send "Awake off" "Idle and sleep allowed again" 2>/dev/null || true
    else
        systemd-run --user --unit="$UNIT" --collect \
            systemd-inhibit --what=idle:sleep --who=waybar \
            --why="Keep awake (toggled from status bar)" --mode=block \
            sleep infinity >/dev/null 2>&1
        notify-send "Awake on" "PC will stay awake until toggled off" 2>/dev/null || true
    fi
}

case "${1:-status}" in
    status) cmd_status ;;
    toggle) cmd_toggle ;;
    *) echo "usage: awake.sh [status|toggle]" >&2; exit 1 ;;
esac
