#!/usr/bin/env bash
# Screenshot menu for Waybar (click the camera icon).
# Rofi UI over grim + slurp: fullscreen, region, active window.
# Saves to ~/Pictures/Screenshots/, copies to clipboard, notifies.
# Requires: rofi, grim. Optional: slurp (region), wl-copy (clipboard),
# hyprctl+jq (active window), swappy/satty (edit), notify-send.
set -euo pipefail

for dep in rofi grim; do
    command -v "$dep" >/dev/null 2>&1 || { echo "screenshot-menu.sh: $dep is not installed" >&2; exit 1; }
done

notify() { notify-send "Screenshot" "$1" 2>/dev/null || true; }

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/Screenshot-$(date +%Y%m%d-%H%M%S).png"

copy_clipboard() {
    if command -v wl-copy >/dev/null 2>&1; then
        wl-copy < "$FILE" 2>/dev/null || true
    fi
}

after_save() {
    copy_clipboard
    notify "Saved: $FILE"
    # Open editor if available, without blocking the bar.
    if command -v swappy >/dev/null 2>&1; then
        swappy -f "$FILE" &
    elif command -v satty >/dev/null 2>&1; then
        satty --filename "$FILE" --output-filename "$FILE" &
    fi
}

take_full() {
    grim "$FILE" && after_save
}

take_region() {
    if ! command -v slurp >/dev/null 2>&1; then
        notify "slurp is not installed (region capture needs it)"
        exit 1
    fi
    local geo
    geo="$(slurp 2>/dev/null)" || exit 0
    [[ -z "$geo" ]] && exit 0
    grim -g "$geo" "$FILE" && after_save
}

take_window() {
    if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        local geo
        geo="$(hyprctl activewindow -j 2>/dev/null | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
        if [[ -n "$geo" && "$geo" != "null,null nullxnull" ]]; then
            grim -g "$geo" "$FILE" && after_save
            return
        fi
    fi
    # Fallback: fullscreen when geometry is unavailable.
    take_full
}

take_delayed() {
    notify "Capturing fullscreen in 5s…"
    sleep 5
    take_full
}

OPT_FULL="󰹑  Full screen"
OPT_REGION="󰹑  Select region"
OPT_WINDOW="󰹑  Active window"
OPT_DELAY="󰹑  Full screen (5s delay)"
OPT_QUIT="  Quit"

choice="$(printf '%s\n' "$OPT_FULL" "$OPT_REGION" "$OPT_WINDOW" "$OPT_DELAY" "$OPT_QUIT" \
    | rofi -dmenu -p "Screenshot")" || exit 0

case "$choice" in
    "$OPT_FULL")   take_full ;;
    "$OPT_REGION") take_region ;;
    "$OPT_WINDOW") take_window ;;
    "$OPT_DELAY")  take_delayed ;;
    *)             exit 0 ;;
esac
