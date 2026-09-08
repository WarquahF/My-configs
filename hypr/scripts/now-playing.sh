#!/usr/bin/env bash
# Now-playing line for the hyprlock lock screen (see ../hyprlock.conf).
#
# This is a separate script rather than an inline `cmd[...]` in hyprlock.conf
# because hyprlang parses `{{ ... }}` as an arithmetic expression, which
# collides with playerctl's own `{{ }}` template syntax:
#   Config error ... Invalid expression type: supported +, -, *, /
#
# Prints nothing when no player exists, so the lock screen simply has no
# now-playing row instead of showing a placeholder. Never fails loudly:
# hyprlock logs a widget command's stderr as an error.
#
# Output is pango markup (hyprlock renders label text as markup), so the
# track text is escaped -- an unescaped "&" in a title would break rendering.
set -uo pipefail

command -v playerctl >/dev/null 2>&1 || exit 0

# Nerd Font glyphs, written as escapes so this file stays plain ASCII:
#   F075A nf-md-music        F03E4 nf-md-pause
readonly ICON_PLAYING=$'\U000F075A'
readonly ICON_PAUSED=$'\U000F03E4'

status="$(playerctl status 2>/dev/null)" || exit 0
case "$status" in
    Playing) icon="$ICON_PLAYING" ;;
    Paused)  icon="$ICON_PAUSED" ;;
    *)       exit 0 ;;
esac

# markup_escape is playerctl's own escaper, applied per field.
title="$(playerctl metadata --format '{{ markup_escape(title) }}' 2>/dev/null)"
artist="$(playerctl metadata --format '{{ markup_escape(artist) }}' 2>/dev/null)"

# A title is the minimum worth showing; some streams report none.
[[ -n "$title" ]] || exit 0

if [[ -n "$artist" ]]; then
    printf '%s  %s \u00b7 %s\n' "$icon" "$title" "$artist"
else
    printf '%s  %s\n' "$icon" "$title"
fi
