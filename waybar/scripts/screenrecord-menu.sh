#!/usr/bin/env bash
# Screen recorder menu for Waybar (click the record icon).
# Rofi UI over wf-recorder: fullscreen, region, stop.
# Saves to ~/Videos/Recordings/ as .mp4 — watch in any player, export anywhere.
# Requires: rofi, wf-recorder (sudo pacman -S wf-recorder).
# Optional: slurp (region), notify-send.
# Usage: screenrecord-menu.sh          -> rofi menu
#        screenrecord-menu.sh status   -> JSON for waybar (return-type json)
#        screenrecord-menu.sh toggle   -> start fullscreen / stop if recording
set -euo pipefail

for dep in rofi; do
    command -v "$dep" >/dev/null 2>&1 || { echo "screenrecord-menu.sh: $dep is not installed" >&2; exit 1; }
done

notify() { notify-send "Screen recorder" "$1" 2>/dev/null || true; }

# 3-2-1 countdown so the rofi menu is gone before recording starts.
countdown() {
    for i in 3 2 1; do
        notify "Recording starts in $i…"
        sleep 1
    done
}

DIR="$HOME/Videos/Recordings"
mkdir -p "$DIR"
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/waybar-screenrecord-file"
ICON_REC="󰑋"
ICON_STOP="󰓛"

is_recording() { pgrep -x wf-recorder >/dev/null 2>&1; }

need_recorder() {
    if ! command -v wf-recorder >/dev/null 2>&1; then
        notify "wf-recorder is not installed (sudo pacman -S wf-recorder)"
        echo "screenrecord-menu.sh: wf-recorder is not installed" >&2
        exit 1
    fi
}

start_full() {
    need_recorder
    is_recording && { notify "Already recording — stop it first"; exit 0; }
    countdown
    local file="$DIR/Recording-$(date +%Y%m%d-%H%M%S).mp4"
    wf-recorder -f "$file" >/dev/null 2>&1 &
    printf '%s' "$file" > "$STATE_FILE"
    notify "Recording fullscreen… (click icon to stop)"
}

start_region() {
    need_recorder
    is_recording && { notify "Already recording — stop it first"; exit 0; }
    if ! command -v slurp >/dev/null 2>&1; then
        notify "slurp is not installed (region recording needs it)"
        exit 1
    fi
    local geo file
    geo="$(slurp 2>/dev/null)" || exit 0
    [[ -z "$geo" ]] && exit 0
    countdown
    file="$DIR/Recording-$(date +%Y%m%d-%H%M%S).mp4"
    wf-recorder -g "$geo" -f "$file" >/dev/null 2>&1 &
    printf '%s' "$file" > "$STATE_FILE"
    notify "Recording region… (click icon to stop)"
}

stop_recording() {
    is_recording || { notify "Not recording"; exit 0; }
    # SIGINT lets wf-recorder finalize the mp4 cleanly.
    pkill -INT -x wf-recorder 2>/dev/null || true
    sleep 1
    local file=""
    [[ -f "$STATE_FILE" ]] && file="$(cat "$STATE_FILE")"
    rm -f "$STATE_FILE"
    if [[ -n "$file" && -f "$file" ]]; then
        notify "Saved: $file"
    else
        notify "Recording stopped"
    fi
}

cmd_status() {
    if is_recording; then
        printf '{"text":"%s","class":"recording","tooltip":"Recording…\\nClick to stop"}' "$ICON_REC"
    else
        printf '{"text":"%s","class":"idle","tooltip":"Screen recorder\\nClick for fullscreen / region / stop"}' "$ICON_REC"
    fi
}

cmd_toggle() {
    if is_recording; then
        stop_recording
    else
        start_full
    fi
}

OPT_FULL="󰑋  Record full screen"
OPT_REGION="󰑋  Record region"
OPT_STOP="$ICON_STOP  Stop recording"
OPT_QUIT="  Quit"

case "${1:-menu}" in
    status) cmd_status ;;
    toggle) cmd_toggle ;;
    menu)
        if is_recording; then
            choice="$(printf '%s\n' "$OPT_STOP" "$OPT_QUIT" \
                | rofi -dmenu -p "Recording…")" || exit 0
            case "$choice" in
                "$OPT_STOP") stop_recording ;;
                *) exit 0 ;;
            esac
        else
            choice="$(printf '%s\n' "$OPT_FULL" "$OPT_REGION" "$OPT_QUIT" \
                | rofi -dmenu -p "Record")" || exit 0
            case "$choice" in
                "$OPT_FULL") start_full ;;
                "$OPT_REGION") start_region ;;
                *) exit 0 ;;
            esac
        fi
        ;;
    *) echo "usage: screenrecord-menu.sh [menu|status|toggle]" >&2; exit 1 ;;
esac
