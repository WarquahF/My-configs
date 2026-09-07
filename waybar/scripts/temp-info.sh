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
# Robust fallback: search thermal zones by type (x86_pkg_temp preferred,
# then TCPU), not by hardcoded number — zone numbers shift across boots.
if [[ -z "$pkg" ]]; then
    for z in /sys/class/thermal/thermal_zone*/; do
        [[ -r "$z/type" && -r "$z/temp" ]] || continue
        t="$(cat "$z/type" 2>/dev/null)"
        if [[ "$t" == "x86_pkg_temp" ]]; then
            pkg="$(( $(cat "$z/temp") / 1000 )).0°C"
            break
        fi
    done
fi
if [[ -z "$pkg" ]]; then
    for z in /sys/class/thermal/thermal_zone*/; do
        [[ -r "$z/type" && -r "$z/temp" ]] || continue
        t="$(cat "$z/type" 2>/dev/null)"
        if [[ "$t" == "TCPU" ]]; then
            raw="$(cat "$z/temp" 2>/dev/null)"
            # TCPU reports millidegree on this machine (54050 = 54°C).
            if (( raw > 1000 )); then pkg="$(( raw / 1000 )).0°C";
            else pkg="${raw}.0°C"; fi
            break
        fi
    done
fi
# Last resort: coretemp hwmon by driver name, not hwmon number.
if [[ -z "$pkg" ]]; then
    for h in /sys/class/hwmon/hwmon*/; do
        [[ "$(cat "$h/name" 2>/dev/null)" == "coretemp" && -r "$h/temp1_input" ]] || continue
        raw="$(cat "$h/temp1_input" 2>/dev/null)"
        pkg="$(( raw / 1000 )).0°C"
        break
    done
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
