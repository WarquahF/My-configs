#!/usr/bin/env bash
# Notification center for Waybar (click the bell icon).
# Rofi panel: currently visible notifications, then recent history,
# plus actions. Dismissed/expired items stay in mako history until
# replaced (max 50). Requires: rofi, makoctl, jq.
set -euo pipefail

for dep in rofi makoctl jq; do
    command -v "$dep" >/dev/null 2>&1 || { echo "notif-center.sh: $dep is not installed" >&2; exit 1; }
done

ACTION_CLEAR="  Dismiss all visible"
ACTION_QUIT="  Quit"

rows=""
vis_n=0
if (( $(makoctl list -j 2>/dev/null | jq 'length') > 0 )); then
    while IFS= read -r line; do
        rows="$(printf '%s\n● %s' "$rows" "$line")"
        vis_n=$(( vis_n + 1 ))
    done < <(makoctl list -j 2>/dev/null \
        | jq -r '.[] | "\(.app_name) — \(.summary)"' | tr -d '"' | head -n 10)
fi
hist_rows="$(makoctl history -j 2>/dev/null \
    | jq -r '.[-15:] | reverse | .[] | "○ \(.app_name) — \(.summary)"' \
    | tr -d '"' | head -n 15)"
[[ -n "$hist_rows" ]] && rows="$(printf '%s\n%s' "$rows" "$hist_rows")"
rows="$(printf '%s\n%s\n%s' "$rows" "$ACTION_CLEAR" "$ACTION_QUIT")"
rows="$(printf '%s' "$rows" | sed '/^$/d')"
nlines="$(printf '%s' "$rows" | wc -l)"

choice="$(printf '%s' "$rows" | rofi -dmenu -p "Notifications" -l "$nlines")" || exit 0
[[ "$choice" == "$ACTION_CLEAR" ]] && makoctl dismiss -a
exit 0
