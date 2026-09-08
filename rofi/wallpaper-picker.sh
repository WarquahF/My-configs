#!/usr/bin/env bash
# Wallpaper switcher for Hyprland + awww.
# Two ways to change wallpaper, both driven by the same library and transition:
# a scrollable filmstrip of every wallpaper (the default), and blind cycling
# for when you just want the next one without a popup.
#
#   wallpaper-picker.sh                  scroll EVERY wallpaper at once (flat)
#   wallpaper-picker.sh --menu           category menu first, then the filmstrip
#   wallpaper-picker.sh --browse <cat>   open the filmstrip directly on a scope
#   wallpaper-picker.sh --next           next wallpaper (no popup)
#   wallpaper-picker.sh --previous       previous wallpaper (no popup)
#   wallpaper-picker.sh --random [cat]   apply a random static wallpaper
#   wallpaper-picker.sh --build-cache    (re)scan library + build thumbnails
#   wallpaper-picker.sh --sync-lock-image  re-point the lock screen at it
#
# Static images only (jpg/jpeg/png/webp/bmp; animated webp excluded).
# Categories are detected dynamically from subfolder names — nothing hardcoded.
# Requires: awww (+ daemon, started on demand). Rofi + Pillow are only needed
# for the optional browser/thumbnails. Waybar recoloring uses Matugen or Pillow.
# Wallpaper dir: $WALLPAPER_DIR env, ~/.config/my-local-configs/wallpaper-dir,
# or ~/Pictures/Wallpapers (in that order). Keeps public repo reproducible.
set -euo pipefail

resolve_wallpaper_dir() {
    if [[ -n "${WALLPAPER_DIR:-}" && -d "$WALLPAPER_DIR" ]]; then
        printf '%s' "$WALLPAPER_DIR"; return 0
    fi
    local override="$HOME/.config/my-local-configs/wallpaper-dir"
    if [[ -f "$override" ]]; then
        local d; d="$(head -n1 "$override" | sed 's|^~|'"$HOME"'|')"
        if [[ -d "$d" ]]; then printf '%s' "$d"; return 0; fi
    fi
    printf '%s' "$HOME/Pictures/Wallpapers"
}
WALLPAPER_DIR="$(resolve_wallpaper_dir)"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-picker"
THUMB_DIR="$CACHE_DIR/thumbs"
LIBRARY="$CACHE_DIR/library.tsv"
SCAN_STAMP="$CACHE_DIR/scan.stamp"   # holds a library signature (see below)
CURRENT_FILE="$CACHE_DIR/current"
# One stable path for "the wallpaper that is currently applied", so
# hypr/hyprlock.conf can point at a fixed file instead of being regenerated
# per lock. Kept as JPEG because hyprlock picks its loader by extension.
LOCK_IMAGE="$CACHE_DIR/lock-background.jpg"
SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"
THEME_SCRIPT="$HOME/.config/waybar/scripts/wallpaper-theme.sh"
if [[ ! -x "$THEME_SCRIPT" && -x "$SCRIPT_DIR/../waybar/scripts/wallpaper-theme.sh" ]]; then
    THEME_SCRIPT="$SCRIPT_DIR/../waybar/scripts/wallpaper-theme.sh"
fi
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

# --- lock screen: keep one fixed path pointing at the current wallpaper -----
refresh_lock_image() {
    # $1 = source image. Re-encodes to a capped-size JPEG at $LOCK_IMAGE so
    # every lock entry point (Super+L, wlogout, power-menu.sh) shows the
    # wallpaper without hyprlock needing to know today's filename.
    local src="$1" tmp
    command -v python3 >/dev/null 2>&1 || return 0
    tmp="$(mktemp "$LOCK_IMAGE.tmp.XXXXXX")" || return 0
    # Written to a temp file and moved into place: hyprlock reads this at
    # lock time and must never see a half-encoded image.
    if python3 - "$src" "$tmp" <<'EOF' 2>/dev/null; then
import sys
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
with Image.open(src) as opened:
    image = opened.convert("RGB")
# Cap the long side: hyprlock blurs this anyway, and a 4K-plus source would
# only slow the lock screen down.
image.thumbnail((3840, 3840), Image.Resampling.LANCZOS)
image.save(dst, "JPEG", quality=92)
EOF
        mv -f "$tmp" "$LOCK_IMAGE"
    else
        rm -f "$tmp"
    fi
}

current_wallpaper() {
    if [[ -s "$CURRENT_FILE" ]]; then
        head -n1 "$CURRENT_FILE"
        return
    fi
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

# A fingerprint of the whole library: every file's path, mtime and size.
# Comparing this (not just the newest mtime) makes the cache notice deletions
# and files copied in with an older timestamp — both invisible to a
# newest-mtime-only check, which can only ever move forward.
library_signature() {
    find "$WALLPAPER_DIR" -type f -printf '%p\t%T@\t%s\n' 2>/dev/null \
        | LC_ALL=C sort | sha1sum | cut -d' ' -f1
}

scan_library() {
    mkdir -p "$CACHE_DIR"
    local tmp f rel mtime cat
    tmp="$(mktemp)"
    while IFS= read -r -d '' f; do
        is_static_image "$f" || continue
        rel="${f#$WALLPAPER_DIR/}"
        mtime="$(stat -c %Y "$f")"
        if [[ "$rel" == */* ]]; then cat="${rel%%/*}"; else cat="Top level"; fi
        printf '%s\t%s\t%s\n' "$f" "$mtime" "$cat" >> "$tmp"
    done < <(find "$WALLPAPER_DIR" -type f -print0 2>/dev/null)
    LC_ALL=C sort -t$'\t' -k3,3 -k1,1 -o "$LIBRARY" "$tmp"
    rm -f "$tmp"
    library_signature > "$SCAN_STAMP"
}

library_fresh() {
    [[ -f "$LIBRARY" && -f "$SCAN_STAMP" ]] || return 1
    [[ "$(cat "$SCAN_STAMP" 2>/dev/null)" == "$(library_signature)" ]]
}

# --- thumbnails: 360px JPEGs keyed by path hash --------------------------------
# One Python process ensures every in-scope thumbnail exists and prints
# "path<TAB>thumb<TAB>category" for each. Doing this in a single process is the
# whole reason the picker opens fast: the previous per-file version forked
# sha1sum once per wallpaper (~1600 forks, measured ~2.2s before rofi even
# appeared). Pillow is imported lazily so a machine with a prebuilt cache but
# no Pillow still lists the thumbnails it already has.
ensure_thumbs() {
    # $1 = scope (ALL or a category); $2 = "progress" to log counts to stderr.
    mkdir -p "$THUMB_DIR"
    python3 - "$LIBRARY" "$THUMB_DIR" "$THUMB_SIZE" "$1" "${2:-}" <<'PY'
import hashlib, os, sys

library, thumb_dir, size, scope = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
progress = len(sys.argv) > 5 and sys.argv[5] == "progress"

try:
    from PIL import Image
    have_pil = True
except Exception:
    have_pil = False

rows = []
with open(library, encoding="utf-8") as handle:
    for line in handle:
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 3:
            continue
        path, category = parts[0], parts[2]
        if scope != "ALL" and category != scope:
            continue
        rows.append((path, category))

total, built = len(rows), 0
for index, (path, category) in enumerate(rows, 1):
    key = hashlib.sha1(path.encode("utf-8")).hexdigest()
    thumb = os.path.join(thumb_dir, key + ".jpg")
    try:
        stale = (not os.path.exists(thumb)) or os.path.getmtime(path) > os.path.getmtime(thumb)
    except OSError:
        stale = True
    if stale and have_pil:
        try:
            image = Image.open(path)
            image.draft("RGB", (size, size))
            image.load()
            image.thumbnail((size, size * 9 // 16))
            image.convert("RGB").save(thumb, "JPEG", quality=84)
            built += 1
        except Exception:
            pass
    if os.path.exists(thumb):
        sys.stdout.write(f"{path}\t{thumb}\t{category}\n")
    if progress and index % 200 == 0:
        sys.stderr.write(f"thumbnails {index}/{total}\n")
        sys.stderr.flush()
if progress:
    sys.stderr.write(f"cache ready: {total} images ({built} built)\n")
    sys.stderr.flush()
PY
}

build_cache() {
    # Full (re)scan, then build every missing thumbnail in one pass. Instant
    # no-op when the cache is already complete. Rows go to /dev/null; the
    # progress + summary lines land on stderr, which install.sh captures.
    library_fresh || scan_library
    ensure_thumbs ALL progress >/dev/null
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
    # $1 = category or ALL. Grid of every wallpaper as a live preview; the
    # focused cell enlarges, clicking or Enter applies, Esc cancels.
    local scope="$1" current accent
    local -a files=() thumbs=() labels=()
    local f thumb cat label
    current="$(current_wallpaper)"
    # ensure_thumbs is one process (see above); this loop is pure bash builtins.
    while IFS=$'\t' read -r f thumb cat; do
        files+=("$f"); thumbs+=("$thumb")
        if [[ "$scope" == "ALL" ]]; then label="$cat/${f##*/}"; else label="${f##*/}"; fi
        [[ "$f" == "$current" ]] && label="● $label"
        labels+=("$label")
    done < <(ensure_thumbs "$scope")
    (( ${#files[@]} > 0 )) || { notify "No wallpapers in scope: $scope"; return 0; }

    # Pre-select (and so pre-enlarge) the wallpaper already on screen, so the
    # grid opens focused on what you are looking at.
    local sel="" i
    for i in "${!files[@]}"; do
        if [[ "${files[$i]}" == "$current" ]]; then sel="-selected-row $i"; break; fi
    done

    # Tint the focus border with the live wallpaper accent, so the picker
    # matches the desktop it is sitting on. Absent file -> theme default.
    local -a accent_arg=()
    accent="$(sed -n 's/^@define-color accent #\([0-9a-fA-F]\{6\}\);$/\1/p' \
        "$HOME/.config/waybar/matugen.css" 2>/dev/null | head -n1)"
    [[ -n "$accent" ]] && accent_arg=(-theme-str "* { accent: #$accent; }")

    # shellcheck disable=SC2086
    local idx
    idx="$({ for i in "${!files[@]}"; do
        printf '%s\0icon\x1f%s\n' "${labels[$i]}" "${thumbs[$i]}"
    done } | rofi -dmenu -config "$THEME" -show-icons -i -p "Wallpapers" \
        "${accent_arg[@]}" $sel -format i)" || return 0
    [[ "$idx" =~ ^[0-9]+$ ]] || return 0
    apply_wallpaper "${files[$idx]}"
}

# awww's grow/outer transitions take a centre point. Grow the new wallpaper
# out from the mouse cursor, so applying feels like it comes from where you
# clicked. Percentages (floats) keep it scale-independent, and --invert-y
# flips hyprctl's top-left origin to awww's bottom-left one.
cursor_fraction() {
    command -v hyprctl >/dev/null 2>&1 || return 1
    python3 - <<'PY' 2>/dev/null
import json, subprocess, sys
try:
    raw = subprocess.check_output(["hyprctl", "cursorpos"]).decode().strip()
    cx, cy = (int(v.strip()) for v in raw.split(","))
    monitors = json.loads(subprocess.check_output(["hyprctl", "-j", "monitors"]))
except Exception:
    sys.exit(1)
monitor = next((m for m in monitors if m.get("focused")), monitors[0] if monitors else None)
if not monitor:
    sys.exit(1)
width = monitor["width"] / monitor["scale"]
height = monitor["height"] / monitor["scale"]
fx = min(max((cx - monitor["x"]) / width, 0.0), 1.0)
fy = min(max((cy - monitor["y"]) / height, 0.0), 1.0)
print(f"{fx:.4f},{fy:.4f}")
PY
}

apply_wallpaper() {
    # $1 = image path; $2 = awww transition. Default is a grow from the cursor:
    # the zesty reveal used when you pick from the grid. cycle_wallpaper passes
    # left/right, so blind cycling still slides in from the matching side.
    local image="$1" transition="${2:-grow}"
    ensure_daemon || return 1

    # Ignore repeat-key overlap instead of letting old transitions/colors win.
    if command -v flock >/dev/null 2>&1; then
        exec 9>"$CACHE_DIR/change.lock"
        flock -n 9 || return 0
    fi

    # A long, strong ease-out at 90fps reads as "zesty" without a hard wipe.
    local -a targs=(--transition-type "$transition" --transition-fps 90 \
        --transition-duration 1.2 --transition-bezier .16,1,.3,1)
    case "$transition" in
        grow|outer)
            local pos; pos="$(cursor_fraction)" \
                && targs+=(--transition-pos "$pos" --invert-y)
            ;;
        wipe|wave) targs+=(--transition-angle 30) ;;
    esac

    if awww img "$image" "${targs[@]}" >/dev/null 2>&1; then
        printf '%s\n' "$image" > "$CURRENT_FILE"
    else
        notify "Could not set wallpaper: ${image##*/}"
        return 1
    fi

    # No success notification: the wallpaper itself is the feedback. Keeping
    # this synchronous prevents an older color job from winning during cycling.
    if [[ -x "$THEME_SCRIPT" ]]; then
        "$THEME_SCRIPT" "$image" >/dev/null 2>&1 || true
    fi

    refresh_lock_image "$image"
}

cycle_wallpaper() {
    # $1 = next or previous. New images enter from the matching side.
    local direction="${1:-next}" current index=-1 target transition i
    local -a files=()
    mapfile -t files < <(cut -f1 "$LIBRARY")
    (( ${#files[@]} > 0 )) || { notify "No wallpapers found in $WALLPAPER_DIR"; return 0; }

    current="$(current_wallpaper)"
    for i in "${!files[@]}"; do
        if [[ "${files[$i]}" == "$current" ]]; then index="$i"; break; fi
    done

    if [[ "$direction" == "previous" ]]; then
        if (( index < 0 )); then
            target=$((${#files[@]} - 1))
        else
            target=$(( (index - 1 + ${#files[@]}) % ${#files[@]} ))
        fi
        transition="left"
    else
        target=$(( (index + 1) % ${#files[@]} ))
        transition="right"
    fi
    apply_wallpaper "${files[$target]}" "$transition"
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
    # Default: one flat filmstrip of every wallpaper, no folder step. This is
    # what Super+Shift+W opens (hypr/config/wallpaper.lua).
    "")            browse "ALL" ;;
    # Blind cycling, for the Super+Alt+W / Super+Alt+Shift+W pair.
    --next)        cycle_wallpaper next ;;
    --previous)    cycle_wallpaper previous ;;
    --build-cache) build_cache ;;
    --browse)      browse "${2:-ALL}" ;;
    # Opt-in category menu (folders first), for large mixed libraries.
    --menu)
        scope="$(pick_category)" || exit 0
        if [[ "$scope" == "RANDOM" ]]; then random_wallpaper "ALL"; else browse "$scope"; fi
        ;;
    --random)      random_wallpaper "${2:-ALL}" ;;
    # Point the lock screen at whatever is on screen right now. install.sh
    # runs this once so the first lock already shows the wallpaper.
    --sync-lock-image)
        image="$(current_wallpaper)"
        [[ -n "$image" && -f "$image" ]] || { echo "no current wallpaper to sync" >&2; exit 1; }
        refresh_lock_image "$image"
        [[ -f "$LOCK_IMAGE" ]] || { echo "could not write $LOCK_IMAGE (is python-pillow installed?)" >&2; exit 1; }
        echo "lock screen background synced from ${image##*/}"
        ;;
    *) echo "usage: wallpaper-picker.sh [--next|--previous|--browse <cat>|--menu|--build-cache|--random [category]|--sync-lock-image]" >&2; exit 1 ;;
esac
