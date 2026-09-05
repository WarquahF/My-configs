#!/usr/bin/env bash
# CPU temperature dropdown for Waybar (click the temperature icon).
# Meant to run inside a small floating kitty window (see on-click in
# waybar/config.jsonc + the waybar-dropdown rule in hypr/config/waybar.lua):
# prints a compact report, then any key closes it, "b" opens full btop.
# Run without flags to just print the report (e.g. in a terminal).
set -euo pipefail

C_HDR=$'\e[1;36m' C_RED=$'\e[1;31m' C_DIM=$'\e[2m' C_OFF=$'\e[0m'

pkg=""; cores=""; extra=""
if command -v sensors >/dev/null 2>&1; then
    pkg="$(sensors coretemp-isa-0000 2>/dev/null | awk '/^Package id 0:/ { print $4; exit }')"
    cores="$(sensors coretemp-isa-0000 2>/dev/null | awk '/^Core [0-9]+:/ { print $1, $2, $3 }')"
    extra="$(sensors 2>/dev/null | awk '/^Composite:/ { print "SSD", $2; exit }')"
fi
if [[ -z "$pkg" && -r /sys/class/thermal/thermal_zone7/temp ]]; then
    pkg="$(( $(cat /sys/class/thermal/thermal_zone7/temp) / 1000 )).0°C"
fi
if [[ -z "$pkg" ]]; then
    echo "No CPU sensor found" >&2; exit 1
fi

printf '%b CPU Temp%b\n\n' "$C_HDR" "$C_OFF"
printf ' %-9s %s\n' "Package" "$pkg"
while read -r _ core temp; do
    [[ -z "$core" ]] && continue
    name="Core ${core%:}"
    num="${temp//[^0-9]/}"; num="${num:0:2}"
    if (( num >= 80 )); then printf ' %-9s %b%s%b\n' "$name" "$C_RED" "$temp" "$C_OFF";
    else printf ' %-9s %s\n' "$name" "$temp"; fi
done <<< "$cores"
[[ -n "$extra" ]] && printf ' %-9s %s\n' $extra

if [[ "${1:-}" == "--popup" ]]; then
    printf '\n%b%s%b\n' "$C_DIM" "any key: close • b: full monitor" "$C_OFF"
    read -rsn1 key; echo
    if [[ "$key" == [bB] ]]; then
        exec env LC_ALL=C.UTF-8 btop
    fi
fi
