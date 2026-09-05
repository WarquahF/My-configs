#!/usr/bin/env bash
# Rofi Wi-Fi/network menu for Waybar (click the Wi-Fi icon).
# Requires: rofi, nmcli. Optional: kitty + nmtui (edit), hostnamectl (hostname).
set -euo pipefail

for dep in rofi nmcli; do
    command -v "$dep" >/dev/null 2>&1 || { echo "wifi-menu.sh: $dep is not installed" >&2; exit 1; }
done

notify() { notify-send "Wi-Fi" "$1" 2>/dev/null || true; }

OPT_ACTIVATE="󰖩  Activate a connection"
OPT_SAVED="󰈀  Saved connections"
OPT_EDIT="  Edit a connection"
OPT_HOST="  Set system host name"
OPT_RADIO="  Wi-Fi radio: "
OPT_QUIT="  Quit"

active_conn() { nmcli -t -f NAME connection show --active 2>/dev/null | head -n 3 | paste -sd "," -; }

# --- Activate: scan, pick strongest AP per SSID, connect (ask password if needed)
activate_wifi() {
    local rows choice ssid
    rows="$(nmcli -t -f SSID,SIGNAL device wifi list --rescan yes 2>/dev/null \
        | grep -v '^:' \
        | awk -F: '{ sig=$NF; sub(/:[^:]*$/, ""); if (!seen[$0]++ || sig+0 > best[$0]) { best[$0]=sig+0; line[$0]=$0 " (" sig "%)" } } END { for (s in line) print best[s] "\t" line[s] }' \
        | sort -rn | cut -f2-)"
    [[ -z "$rows" ]] && { notify "No Wi-Fi networks found"; exit 0; }
    choice="$(printf '%s\n' "$rows" | rofi -dmenu -p "Connect to")" || exit 0
    ssid="$(printf '%s' "$choice" | sed 's/ ([0-9]*%)$//')"
    if nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
        notify "Connected to $ssid"
    else
        local pass
        pass="$(rofi -dmenu -password -p "Password for $ssid")" || exit 0
        if nmcli device wifi connect "$ssid" password "$pass" >/dev/null 2>&1; then
            notify "Connected to $ssid"
        else
            notify "Could not connect to $ssid"
        fi
    fi
}

# --- Saved (wired, VPN, known Wi-Fi): pick one and bring it up
saved_connections() {
    local rows choice name
    rows="$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | tr ':' ' ')"
    [[ -z "$rows" ]] && { notify "No saved connections"; exit 0; }
    choice="$(printf '%s\n' "$rows" | rofi -dmenu -p "Saved connection")" || exit 0
    name="$(printf '%s' "$choice" | sed 's/ [^ ]*$//')"
    if nmcli connection up "$name" >/dev/null 2>&1; then
        notify "Activated $name"
    else
        notify "Could not activate $name"
    fi
}

# --- Edit: full terminal editor for advanced setups (passwords, EAP, static IP)
edit_connection() {
    if command -v kitty >/dev/null 2>&1; then
        kitty -e nmtui-edit &
    elif command -v nmtui-edit >/dev/null 2>&1; then
        notify "No terminal found for nmtui-edit"
        exit 1
    else
        notify "nmtui is not installed"
        exit 1
    fi
}

# --- Hostname: rename this machine (polkit may ask for authentication)
set_hostname() {
    local current new
    current="$(hostnamectl --static 2>/dev/null || hostname)"
    new="$(printf '' | rofi -dmenu -p "Host name [$current]")" || exit 0
    [[ -z "$new" ]] && exit 0
    if [[ "$new" =~ [[:space:]] ]]; then notify "Host name cannot contain spaces"; exit 1; fi
    if hostnamectl set-hostname "$new" 2>/dev/null; then
        notify "Host name set to $new"
    else
        notify "Could not set host name (authentication failed?)"
        exit 1
    fi
}

# --- Radio: toggle the Wi-Fi radio (airplane-mode style switch)
toggle_radio() {
    local state
    state="$(nmcli radio wifi)"
    if [[ "$state" == "enabled" ]]; then
        nmcli radio wifi off && notify "Wi-Fi radio off"
    else
        nmcli radio wifi on && notify "Wi-Fi radio on"
    fi
}

radio_state="$(nmcli radio wifi 2>/dev/null || echo unknown)"
choice="$(printf '%s\n' "$OPT_ACTIVATE" "$OPT_SAVED" "$OPT_EDIT" "$OPT_HOST" "$OPT_RADIO$radio_state" "$OPT_QUIT" \
    | rofi -dmenu -p "Wi-Fi" -mesg "Active: $(active_conn)")" || exit 0

case "$choice" in
    "$OPT_ACTIVATE") activate_wifi ;;
    "$OPT_SAVED")    saved_connections ;;
    "$OPT_EDIT")     edit_connection ;;
    "$OPT_HOST")     set_hostname ;;
    "$OPT_RADIO"*)   toggle_radio ;;
    *)               exit 0 ;;  # Quit or empty
esac
