#!/usr/bin/env bash
# Rofi power menu for Hyprland (fallback for the wlogout overlay). Shows one
# icon tile per action, reusing the same icons wlogout uses so the two menus
# match. Requires: rofi. Lock prefers hyprlock/swaylock/gtklock -> loginctl.
set -euo pipefail

THEME="$HOME/.config/rofi/power.rasi"
ICONS="$HOME/.config/wlogout/icons"

LOCK="Lock"
LOGOUT="Log out"
SUSPEND="Suspend"
REBOOT="Reboot"
SHUTDOWN="Shutdown"

# label<TAB-less> plus rofi's icon protocol (NUL + "icon" + US + path). Falls
# back to a glyph in the label when the icon file is missing.
row() {
    local label="$1" icon="$2" glyph="$3"
    if [[ -f "$icon" ]]; then
        printf '%s\0icon\x1f%s\n' "$label" "$icon"
    else
        printf '%s  %s\n' "$glyph" "$label"
    fi
}

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

theme_arg=()
[[ -f "$THEME" ]] && theme_arg=(-config "$THEME")

choice="$({
    row "$LOCK"     "$ICONS/lock.png"     ""
    row "$LOGOUT"   "$ICONS/logout.png"   "󰅃"
    row "$SUSPEND"  "$ICONS/suspend.png"  "󰒲"
    row "$REBOOT"   "$ICONS/reboot.png"   "󰐉"
    row "$SHUTDOWN" "$ICONS/shutdown.png" "⏻"
} | rofi -dmenu "${theme_arg[@]}" -show-icons -p "Power" -no-custom)" || exit 0

# Glob-match so both forms resolve: the icon rows return the bare label, the
# glyph fallback returns "<glyph>  <label>".
case "$choice" in
    *"$LOCK")     lock_session ;;
    # NOTE: plain `hyprctl dispatch exit` is broken in this Hyprland Lua
    # build (string dispatches fail core-side); the Lua object form works.
    # swaymsg covers the Sway session; loginctl is the last resort.
    *"$LOGOUT")   hyprctl dispatch 'hl.dsp.exit()' 2>/dev/null \
                   || hyprctl dispatch exit 2>/dev/null \
                   || swaymsg exit 2>/dev/null \
                   || loginctl terminate-session "${XDG_SESSION_ID:-}" ;;
    *"$SUSPEND")  systemctl suspend ;;
    *"$REBOOT")   systemctl reboot ;;
    *"$SHUTDOWN") systemctl poweroff ;;
    *)            exit 0 ;;
esac
