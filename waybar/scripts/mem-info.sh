#!/usr/bin/env bash
# RAM usage dropdown for Waybar (click the memory icon).
# Meant to run inside a small floating kitty window (see on-click in
# waybar/config.jsonc + the waybar-dropdown rule in hypr/config/waybar.lua):
# prints a compact report, then any key closes it, "b" opens full btop.
# Run without flags to just print the report (e.g. in a terminal).
set -euo pipefail

C_HDR=$'\e[1;36m' C_DIM=$'\e[2m' C_OFF=$'\e[0m'

read -r total used avail < <(free -m | awk '/^Mem:/ { print $2, $3, $7 }')
read -r stot sused < <(free -m | awk '/^Swap:/ { print $2, $3 }')
pct=$(( used * 100 / total ))
gib() { awk -v m="$1" 'BEGIN { printf "%.1f", m/1024 }'; }

printf '%b Memory  %s%%  (%s / %s GiB)%b\n\n' "$C_HDR" "$pct" "$(gib "$used")" "$(gib "$total")" "$C_OFF"
printf ' %-10s %s GiB\n' "Available" "$(gib "$avail")"
printf ' %-10s %s / %s MiB\n' "Swap" "$sused" "$stot"
printf '\n Top by memory:\n'
ps -eo comm,rss --sort=-rss 2>/dev/null \
    | awk 'NR>1 && $1!="ps" && $2+0>20480 { printf " %-10s %.1f GiB\n", $1, $2/1024/1024; c++ } c>=5 { exit }'

if [[ "${1:-}" == "--popup" ]]; then
    printf '\n%b%s%b\n' "$C_DIM" "any key: close • b: full monitor" "$C_OFF"
    read -rsn1 key; echo
    if [[ "$key" == [bB] ]]; then
        exec env LC_ALL=C.UTF-8 btop
    fi
fi
