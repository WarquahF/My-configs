#!/usr/bin/env bash
# CPU temperature for Waybar — one resolver, two front-ends:
#   temp-info.sh --status   -> JSON for the bar (custom/temperature module)
#   temp-info.sh --popup    -> compact dropdown in a floating kitty window
#                              (any key closes it, "b" opens full btop)
#   temp-info.sh            -> same report, no key wait (plain terminal use)
#
# The CPU package sensor is resolved by driver name / thermal-zone type,
# never by a hardcoded hwmon number, so zone/hwmon renumbering across boots
# or hardware changes is safe. The bar and the popup share resolve_pkg(),
# so they can never disagree about which sensor is the CPU.
set -euo pipefail

CRIT=85   # °C; matches #custom-temperature.critical in waybar/style.css
C_HDR=$'\e[1;36m' C_RED=$'\e[1;31m' C_DIM=$'\e[2m' C_OFF=$'\e[0m'

# resolve_pkg: echo the CPU package temperature as "<int>.0°C", or nothing.
# Order: coretemp "Package id 0" -> x86_pkg_temp zone -> TCPU zone ->
# coretemp hwmon (matched by driver name, not by hwmonN index).
resolve_pkg() {
    local pkg="" z t raw h
    if command -v sensors >/dev/null 2>&1; then
        pkg="$(sensors coretemp-isa-0000 2>/dev/null | awk '/^Package id 0:/ { print $4; exit }')"
    fi
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
    if [[ -z "$pkg" ]]; then
        for h in /sys/class/hwmon/hwmon*/; do
            [[ "$(cat "$h/name" 2>/dev/null)" == "coretemp" && -r "$h/temp1_input" ]] || continue
            raw="$(cat "$h/temp1_input" 2>/dev/null)"
            pkg="$(( raw / 1000 )).0°C"
            break
        done
    fi
    [[ -n "$pkg" ]] && printf '%s' "$pkg"
}

# --- Bar status (custom/temperature, return-type json) ----------------------
# Every interpolated value is constrained (integer temp, fixed icon/class),
# so hand-built JSON here is safe and keeps the bar module jq-free.
if [[ "${1:-}" == "--status" || "${1:-}" == "status" ]]; then
    pkg="$(resolve_pkg)"
    if [[ -z "$pkg" ]]; then
        printf '{"text":"","tooltip":"No CPU sensor found","class":"unknown"}\n'
        exit 0
    fi
    temp="${pkg%%.*}"; temp="${temp//[^0-9]/}"; temp="${temp:-0}"
    icons=("" "" "" "" "")   # cool -> hot, mirrors the old format-icons ramp
    idx=$(( temp / 20 )); (( idx > 4 )) && idx=4
    class="normal"; (( temp >= CRIT )) && class="critical"
    printf '{"text":"%s %d°C","tooltip":"CPU package: %d°C","class":"%s"}\n' \
        "${icons[$idx]}" "$temp" "$temp" "$class"
    exit 0
fi

# --- Report / popup ---------------------------------------------------------
pkg="$(resolve_pkg)"
if [[ -z "$pkg" ]]; then echo "No CPU sensor found" >&2; exit 1; fi

cores=""; extra=""
if command -v sensors >/dev/null 2>&1; then
    cores="$(sensors coretemp-isa-0000 2>/dev/null | awk '/^Core [0-9]+:/ { print $1, $2, $3 }')"
    extra="$(sensors 2>/dev/null | awk '/^Composite:/ { print "SSD", $2; exit }')"
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
