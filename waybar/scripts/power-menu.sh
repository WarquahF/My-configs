#!/usr/bin/env bash
# Minimal rofi power menu for Hyprland. No Noctalia, no extra dependencies.
# Requires: rofi. Lock prefers hyprlock/swaylock/gtklock, falls back to loginctl.
set -euo pipefail

LOCK="  Lock"
LOGOUT="󰍃  Log out"
REBOOT="󰜉  Reboot"
SHUTDOWN="⏻  Shutdown"

lock_session() {
    if command -v hyprlock >/dev/null 2>&1; then
        exec hyprlock
    elif command -v swaylock >/dev/null 2>&1; then
        exec swaylock -f
    elif command -v gtklock >/dev/null 2>&1; then
        exec gtklock
    elif command -v loginctl >/dev/null 2>&1; then
        exec loginctl lock-session
    else
        notify-send "Power menu" "No screen locker found" 2>/dev/null || true
        exit 1
    fi
}

if ! command -v rofi >/dev/null 2>&1; then
    echo "power-menu.sh: rofi is not installed" >&2
    exit 1
fi

choice="$(printf '%s\n' "$LOCK" "$LOGOUT" "$REBOOT" "$SHUTDOWN" \
    | rofi -dmenu -p "Power" -no-custom)" || exit 0

case "$choice" in
    "$LOCK")     lock_session ;;
    # NOTE: plain `hyprctl dispatch exit` is broken in this Hyprland Lua
    # build (string dispatches fail core-side); the Lua object form works.
    "$LOGOUT")   hyprctl dispatch 'hl.dsp.exit()' ;;
    "$REBOOT")   systemctl reboot ;;
    "$SHUTDOWN") systemctl poweroff ;;
    *)           exit 0 ;;
esac
