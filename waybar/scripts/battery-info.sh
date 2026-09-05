#!/usr/bin/env bash
# Battery details popup for Waybar (click the battery icon).
# Shows time remaining + top power consumers. Requires: rofi, upower.
set -euo pipefail

for dep in rofi upower; do
    command -v "$dep" >/dev/null 2>&1 || { echo "battery-info.sh: $dep is not installed" >&2; exit 1; }
done

BAT="$(upower -e 2>/dev/null | grep -m1 BAT)" || { echo "battery-info.sh: no battery found" >&2; exit 1; }
info="$(upower -i "$BAT")"
prop() { printf '%s' "$info" | awk -F: -v k="$1" '$1 ~ k { gsub(/^ +| +$/, "", $2); print $2; exit }'; }

state="$(prop 'state')"
percent="$(prop 'percentage')"
rate="$(prop 'energy-rate')"
to_empty="$(prop 'time to empty')"
to_full="$(prop 'time to full')"

if [[ "$state" == "discharging" ]]; then
    headline="$percent — discharging, $to_empty left"
elif [[ "$state" == "charging" ]]; then
    headline="$percent — charging, $to_full to full"
else
    headline="$percent — $state"
fi

top="$(ps -eo comm,%cpu --sort=-%cpu 2>/dev/null | awk 'NR>1 && $1!="ps" && $2+0>0.5 { printf "  %s — %s%%\n", $1, $2 }' | head -n 5)"
[[ -z "$top" ]] && top="  (idle — nothing drawing significant power)"

printf 'Time remaining: %s\nDraw: %s\n\nTop power consumers (by CPU):\n%s\n' \
    "${to_empty:-$to_full}" "${rate:-unknown}" "$top" \
    | rofi -dmenu -p "Battery" -mesg "$headline" -l 9 >/dev/null || true
exit 0
