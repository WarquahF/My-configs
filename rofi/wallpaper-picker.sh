#!/usr/bin/env bash
# Visual wallpaper picker for Hyprland + awww.
# Opens a horizontal rofi card browser (thumbnails, keyboard/mouse/trackpad),
# applies the pick with an animated awww transition.
#
#   wallpaper-picker.sh                  browse (category menu, then browser)
#   wallpaper-picker.sh --browse <cat>  open the browser directly on a scope
#   wallpaper-picker.sh --random [cat]   apply a random static wallpaper
#   wallpaper-picker.sh --build-cache    (re)scan library + build thumbnails
#
# Static images only (jpg/jpeg/png/webp/bmp; animated webp excluded).
# Categories are detected dynamically from subfolder names — nothing hardcoded.
# Requires: rofi, awww (+daemon, started on demand), python3 + PIL (thumbs).
set -euo pipefail

WALLPAPER_DIR="/home/warquahf/Pictures/Wallpapers"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-picker"
THUMB_DIR="$CACHE_DIR/thumbs"
LIBRARY="$CACHE_DIR/library.tsv"
SCAN_STAMP="$CACHE_DIR/scan.stamp"
THUMB_SIZE=360
THEME="$HOME/.config/rofi/wallpaper.rasi"
MENU_THEME="$HOME/.config/rofi/wallpaper-menu.rasi"
RANDOM_LABEL=" Random wallpaper"

notify() { notify-send "Wallpapers" "$1" 2>/dev/null || true; }

# --- awww daemon: use it if running, start it exactly once if not ------------
ensure_daemon() {
    if awww query >/dev/null 2>&1; then return 0; fi
    setsid awww-daemon >/dev/null 2>&1 < /dev/null &
    for _ in $(seq 1 25); do
        awww query >/dev/null 2>&1 && return 0
        sleep 0.2
    done
    notify "Could not start awww-daemon"
    return 1
}

current_wallpaper() {
    awww query 2>/dev/null | sed -n 's/.*currently displaying: image: //p' | head -n1
}

# --- library scan: path<TAB>mtime<TAB>category, plus freshness stamp ---------
is_static_image() {
    # $1 = file. Excludes video/animation; multi-frame webp counts as animated.
    case "${1,,}" in
        *.jpg|*.jpeg|*.png|*.bmp) return 0 ;;
        *.webp)
            command -v magick >/dev/null 2>&1 || return 0
            [[ "$(magick identify -format '%n\n' "$1" 2>/dev/null | head -n1)" == "1" ]] && return 0
            return 1 ;;
        *) return 1 ;;
    esac
}

scan_library() {
    mkdir -p "$CACHE_DIR"
    local tmp newest=0 f rel mtime cat
    tmp="$(mktemp)"
    while IFS= read -r -d '' f; do
        is_static_image "$f" || continue
        rel="${f#$WALLPAPER_DIR/}"
        mtime="$(stat -c %Y "$f")"
        (( mtime > newest )) && newest="$mtime"
        if [[ "$rel" == */* ]]; then cat="${rel%%/*}"; else cat="Top level"; fi
        printf '%s\t%s\t%s\n' "$f" "$mtime" "$cat" >> "$tmp"
    done < <(find "$WALLPAPER_DIR" -type f -print0 2>/dev/null)
    LC_ALL=C sort -t$'\t' -k3,3 -k1,1 -o "$LIBRARY" "$tmp"
    rm -f "$tmp"
    printf '%s\n' "$newest" > "$SCAN_STAMP"
}

library_fresh() {
    [[ -f "$LIBRARY" && -f "$SCAN_STAMP" ]] || return 1
    local stamp newest
    stamp="$(cat "$SCAN_STAMP")"
    newest="$(find "$WALLPAPER_DIR" -type f -printf '%T@\n' 2>/dev/null | sort -rn | head -n1 | cut -d. -f1)"
    [[ -n "$newest" && "$newest" -le "$stamp" ]]
}

# --- thumbnails: 360px JPEGs keyed by path hash, rebuilt when stale ---------
thumb_for() {
    # $1 = source image. Echoes thumb path; returns nonzero when unusable.
    local src="$1" key out
    key="$(printf '%s' "$src" | sha1sum | cut -d' ' -f1)"
    out="$THUMB_DIR/$key.jpg"
    if [[ -f "$out" && ! "$src" -nt "$out" ]]; then printf '%s' "$out"; return 0; fi
    mkdir -p "$THUMB_DIR"
    if python3 - "$src" "$out" "$THUMB_SIZE" <<'EOF' 2>/dev/null; then
import sys
from PIL import Image
src, dst, size = sys.argv[1], sys.argv[2], int(sys.argv[3])
im = Image.open(src)
im.draft('RGB', (size, size))
im.load()
im.thumbnail((size, size // 16 * 9))
im.convert('RGB').save(dst, quality=84)
EOF
        printf '%s' "$out"; return 0
    fi
    return 1
}

build_cache() {
    # Full (re)scan + every thumbnail. One-time cost (~1ms/scan row,
    # ~80ms/thumb); subsequent opens only fill gaps.
    local total=0 done=0 f
    library_fresh || scan_library
    total="$(wc -l < "$LIBRARY")"
    while IFS=$'\t' read -r f _ _; do
        thumb_for "$f" >/dev/null || true
        done=$(( done + 1 ))
        (( done % 200 == 0 )) && printf 'thumbnails %s/%s\n' "$done" "$total"
    done < "$LIBRARY"
    printf 'cache ready: %s images\n' "$total"
}

# --- rofi frontends -----------------------------------------------------------
pick_category() {
    # Emits the chosen category, "ALL", or "RANDOM". Esc -> nonzero exit.
    local rows counts total
    total="$(wc -l < "$LIBRARY")"
    rows="$(printf ' All (%s wallpapers)\n%s\n' "$total" "$RANDOM_LABEL")"
    # "name (count)" rows, alphabetical; folders come straight from disk.
    counts="$(awk -F'\t' '{ c[$3]++ } END { for (k in c) printf "%s (%d)\n", k, c[k] }' "$LIBRARY" \
        | LC_ALL=C sort)"
    rows="$(printf '%s\n%s' "$rows" "$counts")"
    local choice
    choice="$(printf '%s' "$rows" | rofi -dmenu -config "$MENU_THEME" -p "Wallpapers" \
        -mesg "Pick a category, or type to filter" -i)" || return 1
    [[ "$choice" == "$RANDOM_LABEL"* ]] && { printf 'RANDOM\n'; return 0; }
    if [[ "$choice" == " All ("* ]]; then printf 'ALL\n'; return 0; fi
    printf '%s\n' "${choice% (*)}"
}

browse() {
    # $1 = category or ALL. Card browser; applies the pick, Esc cancels.
    local scope="$1" current
    local -a files=() thumbs=() labels=()
    local f _ cat thumb label
    current="$(current_wallpaper)"
    while IFS=$'\t' read -r f _ cat; do
        if [[ "$scope" != "ALL" && "$cat" != "$scope" ]]; then continue; fi
        thumb="$(thumb_for "$f")" || continue
        files+=("$f"); thumbs+=("$thumb")
        if [[ "$scope" == "ALL" ]]; then label="$cat/${f##*/}"; else label="${f##*/}"; fi
        [[ "$f" == "$current" ]] && label="● $label"
        labels+=("$label")
    done < "$LIBRARY"
    (( ${#files[@]} > 0 )) || { notify "No wallpapers in scope: $scope"; return 0; }

    local sel="" i
    for i in "${!files[@]}"; do
        if [[ "${files[$i]}" == "$current" ]]; then sel="-selected-row $i"; break; fi
    done
    # shellcheck disable=SC2086
    local idx
    idx="$({ for i in "${!files[@]}"; do
        printf '%s\0icon\x1f%s\n' "${labels[$i]}" "${thumbs[$i]}"
    done } | rofi -dmenu -config "$THEME" -show-icons -i -p "Wallpapers" \
        -mesg "$scope · ${#files[@]} wallpapers · Enter applies · Esc cancels" \
        $sel -format i)" || return 0
    [[ "$idx" =~ ^[0-9]+$ ]] || return 0
    apply_wallpaper "${files[$idx]}"
}

apply_wallpaper() {
    # $1 = image path. Daemon must be up (started on demand, never duplicated).
    ensure_daemon || return 1
    awww img "$1" --transition-type center --transition-duration 0.9 \
        --transition-fps 60 >/dev/null 2>&1 &
    disown
    notify "Wallpaper: ${1##*/}"
}

random_wallpaper() {
    # $1 = category or ALL (default ALL).
    local scope="${1:-ALL}" pool pick
    if [[ "$scope" == "ALL" ]]; then
        pool="$(cut -f1 "$LIBRARY")"
    else
        pool="$(awk -F'\t' -v c="$scope" '$3 == c { print $1 }' "$LIBRARY")"
    fi
    [[ -z "$pool" ]] && { notify "No wallpapers in scope: $scope"; return 0; }
    pick="$(printf '%s\n' "$pool" | shuf -n1)"
    apply_wallpaper "$pick"
}

# --- entry --------------------------------------------------------------------
[[ -d "$WALLPAPER_DIR" ]] || { notify "Wallpaper directory not found: $WALLPAPER_DIR"; exit 1; }
mkdir -p "$CACHE_DIR"
library_fresh || scan_library

case "${1:-}" in
    --build-cache) build_cache ;;
    --browse)      browse "${2:-ALL}" ;;
    --random)      random_wallpaper "${2:-ALL}" ;;
    "")
        scope="$(pick_category)" || exit 0
        if [[ "$scope" == "RANDOM" ]]; then random_wallpaper "ALL"; else browse "$scope"; fi
        ;;
    *) echo "usage: wallpaper-picker.sh [--browse <cat>|--build-cache|--random [category]]" >&2; exit 1 ;;
esac
