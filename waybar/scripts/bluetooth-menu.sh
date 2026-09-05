#!/usr/bin/env bash
# Bluetooth menu for Waybar (click the Bluetooth icon).
# Rofi UI over bluetoothctl: radio power, scan & pair, connect/disconnect.
# Requires: rofi, bluetoothctl. No blueman or other GUI needed.
set -euo pipefail

for dep in rofi bluetoothctl; do
    command -v "$dep" >/dev/null 2>&1 || { echo "bluetooth-menu.sh: $dep is not installed" >&2; exit 1; }
done

notify() { notify-send "Bluetooth" "$1" 2>/dev/null || true; }
bt() { bluetoothctl "$@" 2>/dev/null; }

OPT_POWER="󰂯  Power: "
OPT_SCAN="󰂯  Scan & pair new device"
OPT_CONN="󰂱  Connect / disconnect device"
OPT_QUIT="  Quit"

powered() { bt show | awk '/Powered:/ { print $2; exit }'; }

toggle_power() {
    if [[ "$(powered)" == "yes" ]]; then
        bt power off >/dev/null && notify "Bluetooth off"
    else
        command -v rfkill >/dev/null 2>&1 && rfkill unblock bluetooth 2>/dev/null || true
        bt power on >/dev/null && notify "Bluetooth on" || notify "Could not power on"
    fi
}

scan_pair() {
    [[ "$(powered)" == "yes" ]] || { notify "Turn Bluetooth power on first"; exit 0; }
    notify "Scanning for 8 seconds…"
    bt --timeout 8 scan on >/dev/null
    local rows choice mac
    rows="$(bt devices | sed 's/^Device //')"
    [[ -z "$rows" ]] && { notify "No devices found"; exit 0; }
    choice="$(printf '%s\n' "$rows" | rofi -dmenu -p "Pair device")" || exit 0
    mac="$(printf '%s' "$choice" | awk '{ print $1 }')"
    [[ -z "$mac" ]] && exit 0
    bt trust "$mac" >/dev/null
    if bt pair "$mac" >/dev/null; then
        bt connect "$mac" >/dev/null && notify "Paired and connected: $choice" \
            || notify "Paired (connect it from the menu): $choice"
    else
        notify "Pairing failed: $choice"
    fi
}

toggle_device() {
    [[ "$(powered)" == "yes" ]] || { notify "Turn Bluetooth power on first"; exit 0; }
    local rows choice mac connected
    rows="$(bt devices Paired 2>/dev/null | sed 's/^Device //'; bt devices | sed 's/^Device //')" \
        || rows="$(bt devices | sed 's/^Device //')"
    rows="$(printf '%s\n' "$rows" | awk '!seen[$0]++' | grep -v '^$')"
    [[ -z "$rows" ]] && { notify "No known devices — scan first"; exit 0; }
    choice="$(printf '%s\n' "$rows" | rofi -dmenu -p "Device")" || exit 0
    mac="$(printf '%s' "$choice" | awk '{ print $1 }')"
    [[ -z "$mac" ]] && exit 0
    connected="$(bt info "$mac" | awk '/Connected:/ { print $2; exit }')"
    if [[ "$connected" == "yes" ]]; then
        bt disconnect "$mac" >/dev/null && notify "Disconnected: $choice"
    else
        bt connect "$mac" >/dev/null && notify "Connected: $choice" \
            || notify "Could not connect: $choice"
    fi
}

state="Power: $(powered 2>/dev/null || echo no)"
conn="$(bt devices Connected 2>/dev/null | sed 's/^Device //' | head -n 2 | paste -sd "," -)"
choice="$(printf '%s\n' "$OPT_POWER$state" "$OPT_SCAN" "$OPT_CONN" "$OPT_QUIT" \
    | rofi -dmenu -p "Bluetooth" -mesg "Connected: ${conn:-none}")" || exit 0

case "$choice" in
    "$OPT_POWER"*) toggle_power ;;
    "$OPT_SCAN")   scan_pair ;;
    "$OPT_CONN")   toggle_device ;;
    *)             exit 0 ;;
esac
