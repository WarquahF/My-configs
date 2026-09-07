#!/usr/bin/env bash
# Install the CachyOS + Hyprland dotfiles from this repo.
# - Symlinks repo files into ~/.config (backing up anything replaced)
# - Asks before replacing someone else's existing dotfiles (all/select/abort)
# - Wires Hyprland waybar/session integration without touching other config
# - Never installs packages; missing deps are reported, not fetched.
# - Rollback anytime with ./emergency-restore.sh (see config-files/).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME:-}"
if [[ -z "$HOME_DIR" || ! -d "$HOME_DIR" ]]; then
    echo "error: could not detect a valid home directory (\$HOME=$HOME_DIR)" >&2
    exit 1
fi

BACKUP_DIR="$HOME_DIR/.config-backup-$(date +%Y%m%d-%H%M%S)"
log()  { printf '[install] %s\n' "$*"; }
warn() { printf '[install] warning: %s\n' "$*" >&2; }

# --- Dependency check (fail safe, install nothing) -------------------------
missing_required=0
for dep in hyprctl waybar rofi; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "[install] error: required dependency missing: $dep" >&2
        missing_required=1
    fi
done
if [[ "$missing_required" -ne 0 ]]; then
    echo "[install] install the missing packages first (e.g. sudo pacman -S waybar rofi), then re-run." >&2
    exit 1
fi
for opt in nmcli nmtui pactl pavucontrol loginctl systemctl python3 grim slurp wl-copy jq swappy satty wf-recorder wlogout hyprlock sway swaylock swayidle swaybg swaymsg matugen sddm; do
    command -v "$opt" >/dev/null 2>&1 || warn "optional tool missing: $opt (some bar actions degrade gracefully)"
done
command -v wlogout >/dev/null 2>&1 || warn "wlogout not installed: power button falls back to rofi (sudo pacman -S wlogout)"
command -v hyprlock >/dev/null 2>&1 || warn "hyprlock not installed: lock falls back to loginctl (sudo pacman -S hyprlock)"
command -v sway >/dev/null 2>&1 || warn "sway not installed: sway/ config is inert until you install it (sudo pacman -S sway swaylock swayidle swaybg)"
if ! command -v matugen >/dev/null 2>&1 \
    && ! python3 -c 'from PIL import Image' >/dev/null 2>&1; then
    warn "wallpaper colors need matugen or python-pillow (sudo pacman -S python-pillow)"
fi
if ! command -v sddm >/dev/null 2>&1; then
    warn "sddm not installed: sddm/ stays as side-by-side reference, greetd untouched (sudo pacman -S sddm)"
fi

# --- Helpers ----------------------------------------------------------------
# backup_if_exists is single-shot per run: the FIRST original wins. If the same
# path is backed up twice in one run, the second call keeps the pristine backup
# and just drops the current copy, so an already-patched file never overwrites
# the original we saved.
backup_if_exists() {
    # backup_if_exists <path>: move existing file/dir/symlink into $BACKUP_DIR.
    local target="$1"
    if [[ -e "$target" || -L "$target" ]]; then
        local rel="${target#$HOME_DIR/}"
        if [[ -e "$BACKUP_DIR/$rel" || -L "$BACKUP_DIR/$rel" ]]; then
            log "already backed up ~/$rel, keeping original"
            rm -rf "$target"
            return
        fi
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        mv "$target" "$BACKUP_DIR/$rel"
        log "backed up ~/$rel"
    fi
}

# Installer mode: all = replace everything (with backup), select = ask per
# file. Non-tty defaults to all (script-safe).
INSTALL_MODE="all"
ask_replace() {
    # ask_replace <home-relative-dest>: return 0 if this file may be replaced.
    local dest_rel="$1"
    if [[ "$INSTALL_MODE" == "all" ]]; then return 0; fi
    local ans
    read -rp "[install] replace ~/$dest_rel with repo version? [y/N] " ans || return 1
    [[ "$ans" == [yY]* ]]
}

link_file() {
    # link_file <repo-relative-src> <home-relative-dest>
    local src="$REPO_DIR/$1" dest="$HOME_DIR/$2"
    if [[ ! -e "$src" ]]; then
        warn "repo file missing, skipping: $1"
        return
    fi
    mkdir -p "$(dirname "$dest")"
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
        log "already linked: ~/$2"
        return
    fi
    if [[ -e "$dest" || -L "$dest" ]]; then
        if ! ask_replace "$2"; then
            log "skipped ~/$2 (kept yours)"
            return
        fi
    fi
    backup_if_exists "$dest"
    ln -sfn "$src" "$dest"
    log "linked ~/$2 -> $1"
}

# --- Link manifest: repo file  ->  home destination -------------------------
# Single source of truth for what gets symlinked, used by BOTH the conflict
# preflight and the linking loop, so the prompt can never disagree with what
# is actually replaced. Scripts and icons are globbed, so new files are
# picked up without editing this list.
LINK_SRC=(); LINK_DEST=()
add_link() { LINK_SRC+=("$1"); LINK_DEST+=("$2"); }

add_link "waybar/config.jsonc"      ".config/waybar/config.jsonc"
add_link "waybar/config-sway.jsonc" ".config/waybar/config-sway.jsonc"
add_link "waybar/style.css"         ".config/waybar/style.css"
for f in "$REPO_DIR"/waybar/scripts/*.sh; do
    add_link "waybar/scripts/$(basename "$f")" ".config/waybar/scripts/$(basename "$f")"
done
add_link "hypr/config/waybar.lua"        ".config/hypr/config/waybar.lua"
add_link "hypr/config/capture.lua"       ".config/hypr/config/capture.lua"
add_link "hypr/config/session.lua"       ".config/hypr/config/session.lua"
add_link "hypr/config/navigation.lua"    ".config/hypr/config/navigation.lua"
add_link "hypr/scripts/cursor-wiggle.py" ".config/hypr/scripts/cursor-wiggle.py"
add_link "kitty/kitty.conf" ".config/kitty/kitty.conf"
add_link "btop/btop.conf"   ".config/btop/btop.conf"
add_link "mako/config"      ".config/mako/config"
add_link "rofi/wallpaper-picker.sh" ".config/rofi/wallpaper-picker.sh"
add_link "rofi/wallpaper.rasi"      ".config/rofi/wallpaper.rasi"
add_link "rofi/wallpaper-menu.rasi" ".config/rofi/wallpaper-menu.rasi"
add_link "wlogout/layout"    ".config/wlogout/layout"
add_link "wlogout/style.css" ".config/wlogout/style.css"
for f in "$REPO_DIR"/wlogout/icons/*.png; do
    add_link "wlogout/icons/$(basename "$f")" ".config/wlogout/icons/$(basename "$f")"
done
# Sway session (Hyprland stays default) and its lock screen.
add_link "sway/config"     ".config/sway/config"
add_link "swaylock/config" ".config/swaylock/config"
# matugen: config plus every template, so new templates need no edit here.
add_link "matugen/config.toml" ".config/matugen/config.toml"
for f in "$REPO_DIR"/matugen/templates/*; do
    add_link "matugen/templates/$(basename "$f")" ".config/matugen/templates/$(basename "$f")"
done

# --- Preflight: someone else's dotfiles? Ask before touching them ------------
# A destination counts as a conflict only when it is a real file (not one of
# our symlinks): that means it is someone's existing dotfile we would replace.
conflicts=()
for i in "${!LINK_DEST[@]}"; do
    dest="$HOME_DIR/${LINK_DEST[$i]}"
    [[ -L "$dest" ]] && continue
    [[ -e "$dest" ]] && conflicts+=("${LINK_DEST[$i]}")
done
if (( ${#conflicts[@]} > 0 )) && [[ -t 0 ]]; then
    echo "[install] existing configs found that this would replace (backed up, never deleted):"
    printf '  - ~/%s\n' "${conflicts[@]}"
    echo "[install] installing can remove/replace some or all of your current configs (originals go to $BACKUP_DIR)."
    PS3="[install] replace? (1=all 2=ask-per-file 3=abort) "
    select choice in "all (recommended, with backup)" "ask me per file" "abort"; do
        case "$REPLY" in
            1) INSTALL_MODE="all"; break ;;
            2) INSTALL_MODE="select"; break ;;
            3) echo "[install] aborted, nothing changed."; exit 0 ;;
            *) echo "pick 1, 2 or 3." ;;
        esac
    done
fi

# --- Directories --------------------------------------------------------------
mkdir -p "$HOME_DIR/.config/waybar/scripts" "$HOME_DIR/.config/hypr/config" \
         "$HOME_DIR/.config/kitty" "$HOME_DIR/.config/btop" \
         "$HOME_DIR/.config/mako" "$HOME_DIR/.config/rofi" \
         "$HOME_DIR/.config/wlogout" \
         "$HOME_DIR/.config/sway" "$HOME_DIR/.config/swaylock" \
         "$HOME_DIR/.config/matugen/templates" \
         "$HOME_DIR/Pictures/Wallpapers" "$HOME_DIR/Pictures/Screenshots" \
         "$HOME_DIR/Videos/Recordings"

# copy_fallback <repo-relative-src> <home-relative-dest>
# For matugen-generated outputs: copy the static fallback ONLY when the
# destination does not exist yet, so `matugen image ...` output is never
# clobbered on re-runs. Existing real files (incl. matugen output) are kept.
copy_fallback() {
    local src="$REPO_DIR/$1" dest="$HOME_DIR/$2"
    if [[ ! -e "$src" ]]; then
        warn "repo file missing, skipping: $1"
        return
    fi
    mkdir -p "$(dirname "$dest")"
    if [[ -e "$dest" || -L "$dest" ]]; then
        log "kept existing ~/$2 (matugen output or yours, not overwritten)"
        return
    fi
    cp "$src" "$dest"
    log "copied fallback ~/$2 (from $1)"
}

# --- Symlink everything in the manifest ---------------------------------------
mkdir -p "$HOME_DIR/.config/hypr/scripts"
for i in "${!LINK_SRC[@]}"; do
    link_file "${LINK_SRC[$i]}" "${LINK_DEST[$i]}"
done
# Executable bits (repo-side; the symlinks inherit them).
chmod +x "$REPO_DIR"/waybar/scripts/*.sh
chmod +x "$REPO_DIR/hypr/scripts/cursor-wiggle.py"
chmod +x "$REPO_DIR/rofi/wallpaper-picker.sh"
log "waybar scripts, cursor-wiggle and wallpaper picker are executable"

HYPR_MAIN="$HOME_DIR/.config/hypr/hyprland.lua"
if [[ -f "$HYPR_MAIN" ]]; then
    # Single backup covers all require lines below (originals are moved, never deleted).
    if grep -q 'require("config.waybar")' "$HYPR_MAIN" \
    && grep -q 'require("config.capture")' "$HYPR_MAIN" \
    && grep -q 'require("config.session")' "$HYPR_MAIN" \
    && grep -q 'require("config.navigation")' "$HYPR_MAIN"; then
        log "hyprland.lua already requires config.waybar + config.capture + config.session + config.navigation"
    else
        backup_if_exists "$HYPR_MAIN"
        # Re-create from backup with the requires added
        # (order: windowrules, waybar, capture, session, navigation).
        cp "$BACKUP_DIR/.config/hypr/hyprland.lua" "$HYPR_MAIN"
        if ! grep -q 'require("config.waybar")' "$HYPR_MAIN"; then
            if grep -q 'require("config.windowrules")' "$HYPR_MAIN"; then
                sed -i '/require("config.windowrules")/a require("config.waybar")' "$HYPR_MAIN"
            else
                printf '\nrequire("config.waybar")\n' >> "$HYPR_MAIN"
            fi
            log "added require(\"config.waybar\") to hyprland.lua"
        fi
        if ! grep -q 'require("config.capture")' "$HYPR_MAIN"; then
            if grep -q 'require("config.waybar")' "$HYPR_MAIN"; then
                sed -i '/require("config.waybar")/a require("config.capture")' "$HYPR_MAIN"
            else
                printf '\nrequire("config.capture")\n' >> "$HYPR_MAIN"
            fi
            log "added require(\"config.capture\") to hyprland.lua"
        fi
        if ! grep -q 'require("config.session")' "$HYPR_MAIN"; then
            if grep -q 'require("config.capture")' "$HYPR_MAIN"; then
                sed -i '/require("config.capture")/a require("config.session")' "$HYPR_MAIN"
            else
                printf '\nrequire("config.session")\n' >> "$HYPR_MAIN"
            fi
            log "added require(\"config.session\") to hyprland.lua (wlogout, Noctalia untouched)"
        fi
        if ! grep -q 'require("config.navigation")' "$HYPR_MAIN"; then
            if grep -q 'require("config.session")' "$HYPR_MAIN"; then
                sed -i '/require("config.session")/a require("config.navigation")' "$HYPR_MAIN"
            else
                printf '\nrequire("config.navigation")\n' >> "$HYPR_MAIN"
            fi
            log "added require(\"config.navigation\") to hyprland.lua (alt+tab)"
        fi
    fi
else
    warn "$HYPR_MAIN not found; create it with: require(\"config.waybar\")"
fi

AUTOSTART="$HOME_DIR/.config/hypr/config/autostart.lua"
if [[ -f "$AUTOSTART" ]]; then
    have_waybar=0; grep -q 'hl.exec_cmd("waybar")' "$AUTOSTART" && have_waybar=1
    [[ "$have_waybar" -eq 1 ]] || warn "autostart.lua has no waybar line; add: hl.exec_cmd(\"waybar\") then re-run"

    # mako/awww/cursor-wiggle each anchor off the line before it, so they must
    # be applied to ONE working copy. Back up once, restore the pristine file
    # once, then add whatever is missing. The old code re-copied the pristine
    # backup before every edit, which reset the file and dropped the edits made
    # moments earlier. All three need the waybar anchor line to exist.
    if [[ "$have_waybar" -eq 1 ]] \
       && { ! grep -q 'exec_cmd("mako")' "$AUTOSTART" \
            || ! grep -q 'exec_cmd("awww-daemon")' "$AUTOSTART" \
            || ! grep -q 'cursor-wiggle' "$AUTOSTART"; }; then
        backup_if_exists "$AUTOSTART"
        cp "$BACKUP_DIR/.config/hypr/config/autostart.lua" "$AUTOSTART"
        if ! grep -q 'exec_cmd("mako")' "$AUTOSTART"; then
            # Inside the hyprland.start callback, next to the waybar line.
            sed -i '/hl.exec_cmd("waybar")/a \    hl.exec_cmd("mako")' "$AUTOSTART"
            log "added mako startup to autostart.lua (exits quietly if already running)"
        fi
        if ! grep -q 'exec_cmd("awww-daemon")' "$AUTOSTART"; then
            sed -i '/hl.exec_cmd("mako")/a \    hl.exec_cmd("awww-daemon")' "$AUTOSTART"
            log "added awww-daemon startup to autostart.lua"
        fi
        if ! grep -q 'cursor-wiggle' "$AUTOSTART"; then
            sed -i 's|hl.exec_cmd("awww-daemon")|hl.exec_cmd("awww-daemon")\n    hl.exec_cmd("python3 $HOME/.config/hypr/scripts/cursor-wiggle.py")|' "$AUTOSTART"
            log "added cursor-wiggle startup to autostart.lua"
        fi
    elif [[ "$have_waybar" -eq 1 ]]; then
        log "autostart.lua already launches waybar + mako + awww-daemon + cursor-wiggle"
    fi
fi

# --- mako: reload the daemon so the freshly linked config takes effect --------
if command -v makoctl >/dev/null 2>&1; then
    makoctl reload 2>/dev/null && log "mako config reloaded" \
        || warn "mako not running; it starts on next login (autostart line added above)"
else
    warn "mako is not installed; notifications need it (sudo pacman -S mako)"
fi

# --- rofi wallpaper picker: one-time thumbnail cache build --------------------
# Links and the executable bit are handled by the manifest loop above; your
# launcher theme stays untouched (the picker uses its own wallpaper*.rasi).
if [[ -d "$HOME_DIR/Pictures/Wallpapers" ]]; then
    # Instant no-op when the cache is already fresh.
    "$REPO_DIR/rofi/wallpaper-picker.sh" --build-cache 2>&1 | tail -n 2
else
    warn "wallpaper directory not found; picker cache build skipped"
fi

# --- Generated colour files: static fallbacks, only when missing --------------
# These are matugen outputs (or our Pillow fallback's). Never symlinked and
# never overwritten, so a generated palette survives re-running the installer.
copy_fallback "waybar/matugen.css"       ".config/waybar/matugen.css"
copy_fallback "hypr/config/matugen.lua"  ".config/hypr/config/matugen.lua"
copy_fallback "kitty/colors.conf"        ".config/kitty/colors.conf"
copy_fallback "rofi/matugen.rasi"        ".config/rofi/matugen.rasi"
command -v matugen >/dev/null 2>&1 \
    && log "matugen found: full desktop colors update with each wallpaper" \
    || log "matugen not found: built-in Pillow fallback recolors Waybar"

# --- Sway (side-by-side WM, Hyprland stays default) ---------------------------
# Links come from the manifest; this only reports whether Sway is usable.
if command -v swaymsg >/dev/null 2>&1; then
    swaymsg -t get_version >/dev/null 2>&1 && log "swaymsg: sway IPC OK" \
        || warn "swaymsg present but no sway session running (config still linked)"
elif command -v sway >/dev/null 2>&1; then
    log "sway installed (swaymsg check skipped, no session running)"
fi

# --- SDDM (side-by-side reference only — /etc untouched, greetd stays) --------
# Copy manually when you want to try it; see sddm/README.md.
log "sddm/: reference drop-ins only (sudo cp sddm/*.conf /etc/sddm.conf.d/ to try)"

# --- Helpers made executable (repo-side, idempotent) --------------------------
chmod +x "$REPO_DIR/emergency-restore.sh" 2>/dev/null || true

# --- Validate ------------------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
    python3 - "$REPO_DIR/waybar/config.jsonc" "$REPO_DIR/waybar/config-sway.jsonc" <<'EOF'
import json, re, sys
for path in sys.argv[1:]:
    text = open(path).read()
    text = re.sub(r'//.*', '', text)              # strip // comments
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)  # strip /* */ comments
    json.loads(text)
    print(f'[install] {path.split("/")[-1]}: valid JSONC')
EOF
fi
if command -v python3 >/dev/null 2>&1; then
    python3 - "$REPO_DIR/matugen/config.toml" <<'EOF'
import sys
try:
    import tomllib
except ImportError:
    print('[install] matugen config.toml: tomllib unavailable, skipped'); sys.exit(0)
tomllib.load(open(sys.argv[1], 'rb'))
print('[install] matugen config.toml: valid TOML')
EOF
fi
bash -n "$REPO_DIR/install.sh" && log "install.sh: syntax OK"
for script in "$REPO_DIR"/waybar/scripts/*.sh; do
    bash -n "$script" || exit 1
done
bash -n "$REPO_DIR/rofi/wallpaper-picker.sh" || exit 1
bash -n "$REPO_DIR/emergency-restore.sh" || exit 1
log "shell scripts: syntax OK"
if command -v python3 >/dev/null 2>&1; then
    python3 -m py_compile "$REPO_DIR/hypr/scripts/cursor-wiggle.py" \
        && log "cursor-wiggle.py: syntax OK"
fi
if command -v luac >/dev/null 2>&1; then
    # Parse-only (-p): catches syntax errors before a bad file breaks a
    # Hyprland reload. The undefined `hl` global is fine — -p never executes.
    for f in "$REPO_DIR"/hypr/config/*.lua; do
        luac -p "$f" 2>/dev/null || warn "lua syntax check failed: ${f#"$REPO_DIR"/}"
    done
    log "hypr lua files: syntax checked"
fi

log "done. Backups (if any) are in: $BACKUP_DIR"
log "reload Hyprland (hyprctl reload) and restart waybar: pkill waybar; waybar &"
