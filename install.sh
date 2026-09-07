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
# backup_if_exists is single-shot per run: the FIRST original wins.
# Repeated calls on the same path (e.g. autostart.lua patched 3x) must NOT
# overwrite the pristine backup with an already-patched file.
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

# --- Preflight: someone else's dotfiles? Ask before touching them ------------
conflicts=()
for cand in .config/waybar/config.jsonc .config/waybar/config-sway.jsonc .config/waybar/style.css \
            .config/hypr/config/waybar.lua .config/kitty/kitty.conf \
            .config/btop/btop.conf .config/mako/config .config/rofi/config.rasi \
            .config/sway/config .config/swaylock/config .config/matugen/config.toml; do
    if [[ -e "$HOME_DIR/$cand" || -L "$HOME_DIR/$cand" ]]; then
        # Ours already? then not a conflict.
        case "$cand" in
            .config/waybar/config.jsonc) repo_src="$REPO_DIR/waybar/config.jsonc" ;;
            .config/waybar/config-sway.jsonc) repo_src="$REPO_DIR/waybar/config-sway.jsonc" ;;
            .config/waybar/style.css) repo_src="$REPO_DIR/waybar/style.css" ;;
            .config/hypr/config/waybar.lua) repo_src="$REPO_DIR/hypr/config/waybar.lua" ;;
            .config/kitty/kitty.conf) repo_src="$REPO_DIR/kitty/kitty.conf" ;;
            .config/btop/btop.conf) repo_src="$REPO_DIR/btop/btop.conf" ;;
            .config/mako/config) repo_src="$REPO_DIR/mako/config" ;;
            .config/sway/config) repo_src="$REPO_DIR/sway/config" ;;
            .config/swaylock/config) repo_src="$REPO_DIR/swaylock/config" ;;
            .config/matugen/config.toml) repo_src="$REPO_DIR/matugen/config.toml" ;;
            *) repo_src="" ;;
        esac
        if [[ -n "$repo_src" && -L "$HOME_DIR/$cand" && "$(readlink "$HOME_DIR/$cand")" == "$repo_src" ]]; then
            continue
        fi
        # Real file (not symlink) = someone's dotfiles.
        if [[ ! -L "$HOME_DIR/$cand" ]]; then conflicts+=("$cand"); fi
    fi
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

# --- Waybar -------------------------------------------------------------------
link_file "waybar/config.jsonc" ".config/waybar/config.jsonc"
link_file "waybar/config-sway.jsonc" ".config/waybar/config-sway.jsonc"
link_file "waybar/style.css" ".config/waybar/style.css"
copy_fallback "waybar/matugen.css" ".config/waybar/matugen.css"
for script in "$REPO_DIR"/waybar/scripts/*.sh; do
    name="$(basename "$script")"
    link_file "waybar/scripts/$name" ".config/waybar/scripts/$name"
    chmod +x "$script"
done
log "waybar scripts are executable"

# --- Hyprland: blur layerrule only, existing config untouched -----------------
link_file "hypr/config/waybar.lua" ".config/hypr/config/waybar.lua"
link_file "hypr/config/capture.lua" ".config/hypr/config/capture.lua"
link_file "hypr/config/session.lua" ".config/hypr/config/session.lua"
copy_fallback "hypr/config/matugen.lua" ".config/hypr/config/matugen.lua"
mkdir -p "$HOME_DIR/.config/hypr/scripts"
link_file "hypr/scripts/cursor-wiggle.py" ".config/hypr/scripts/cursor-wiggle.py"
chmod +x "$REPO_DIR/hypr/scripts/cursor-wiggle.py"

HYPR_MAIN="$HOME_DIR/.config/hypr/hyprland.lua"
if [[ -f "$HYPR_MAIN" ]]; then
    # Single backup covers all require lines below (originals are moved, never deleted).
    if grep -q 'require("config.waybar")' "$HYPR_MAIN" \
    && grep -q 'require("config.capture")' "$HYPR_MAIN" \
    && grep -q 'require("config.session")' "$HYPR_MAIN"; then
        log "hyprland.lua already requires config.waybar + config.capture + config.session"
    else
        backup_if_exists "$HYPR_MAIN"
        # Re-create from backup with the requires added (order: windowrules, waybar, capture, session).
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
    fi
else
    warn "$HYPR_MAIN not found; create it with: require(\"config.waybar\")"
fi

AUTOSTART="$HOME_DIR/.config/hypr/config/autostart.lua"
if [[ -f "$AUTOSTART" ]]; then
    if grep -q 'hl.exec_cmd("waybar")' "$AUTOSTART"; then
        log "autostart.lua already launches waybar (noctalia stays disabled)"
    else
        warn "autostart.lua has no waybar line; add: hl.exec_cmd(\"waybar\")"
    fi
    if grep -q 'exec_cmd("mako")' "$AUTOSTART"; then
        log "autostart.lua already launches mako"
    else
        backup_if_exists "$AUTOSTART"
        cp "$BACKUP_DIR/.config/hypr/config/autostart.lua" "$AUTOSTART"
        # Inside the hyprland.start callback, next to the waybar line.
        sed -i '/hl.exec_cmd("waybar")/a \    hl.exec_cmd("mako")' "$AUTOSTART"
        log "added mako startup to autostart.lua (exits quietly if already running)"
    fi
    if grep -q 'exec_cmd("awww-daemon")' "$AUTOSTART"; then
        log "autostart.lua already launches awww-daemon"
    else
        backup_if_exists "$AUTOSTART"
        cp "$BACKUP_DIR/.config/hypr/config/autostart.lua" "$AUTOSTART"
        sed -i '/hl.exec_cmd("mako")/a \    hl.exec_cmd("awww-daemon")' "$AUTOSTART"
        log "added awww-daemon startup to autostart.lua"
    fi
    if grep -q 'cursor-wiggle' "$AUTOSTART"; then
        log "autostart.lua already launches cursor-wiggle"
    else
        backup_if_exists "$AUTOSTART"
        cp "$BACKUP_DIR/.config/hypr/config/autostart.lua" "$AUTOSTART"
        sed -i 's|hl.exec_cmd("awww-daemon")|hl.exec_cmd("awww-daemon")\n    hl.exec_cmd("python3 $HOME/.config/hypr/scripts/cursor-wiggle.py")|' "$AUTOSTART"
        log "added cursor-wiggle startup to autostart.lua"
    fi
fi

# --- mako: notification daemon (7s timeout, critical persists) -----------------
link_file "mako/config" ".config/mako/config"
if command -v makoctl >/dev/null 2>&1; then
    makoctl reload 2>/dev/null && log "mako config reloaded" \
        || warn "mako not running; it starts on next login (autostart line added above)"
else
    warn "mako is not installed; notifications need it (sudo pacman -S mako)"
fi

# --- rofi wallpaper picker (own theme file; your launcher theme untouched) ----
link_file "rofi/wallpaper-picker.sh" ".config/rofi/wallpaper-picker.sh"
link_file "rofi/wallpaper.rasi" ".config/rofi/wallpaper.rasi"
link_file "rofi/wallpaper-menu.rasi" ".config/rofi/wallpaper-menu.rasi"
copy_fallback "rofi/matugen.rasi" ".config/rofi/matugen.rasi"
chmod +x "$REPO_DIR/rofi/wallpaper-picker.sh"
if [[ -d "$HOME_DIR/Pictures/Wallpapers" ]]; then
    # One-time thumbnail build; instant no-op when the cache is fresh.
    "$REPO_DIR/rofi/wallpaper-picker.sh" --build-cache 2>&1 | tail -n 2
else
    warn "wallpaper directory not found; picker cache build skipped"
fi

# --- Kitty / btop (backed up, Noctalia includes dropped) ----------------------
link_file "kitty/kitty.conf" ".config/kitty/kitty.conf"
copy_fallback "kitty/colors.conf" ".config/kitty/colors.conf"
link_file "btop/btop.conf" ".config/btop/btop.conf"

# --- wlogout (overlay power menu, replaces Noctalia session) ------------------
# Covers lock / logout (= signout) / suspend / reboot / shutdown on both
# Hyprland and Sway (compositor fallbacks in layout + power-menu.sh).
link_file "wlogout/layout" ".config/wlogout/layout"
link_file "wlogout/style.css" ".config/wlogout/style.css"
for icon in "$REPO_DIR"/wlogout/icons/*.png; do
    link_file "wlogout/icons/$(basename "$icon")" ".config/wlogout/icons/$(basename "$icon")"
done

# --- Sway (side-by-side WM, Hyprland stays default) ---------------------------
link_file "sway/config" ".config/sway/config"
link_file "swaylock/config" ".config/swaylock/config"
if command -v swaymsg >/dev/null 2>&1; then
    swaymsg -t get_version >/dev/null 2>&1 && log "swaymsg: sway IPC OK" \
        || warn "swaymsg present but no sway session running (config still linked)"
elif command -v sway >/dev/null 2>&1; then
    log "sway installed (swaymsg check skipped, no session running)"
fi

# --- matugen (optional wallpaper theming, static fallback otherwise) ----------
link_file "matugen/config.toml" ".config/matugen/config.toml"
for tmpl in "$REPO_DIR"/matugen/templates/*; do
    link_file "matugen/templates/$(basename "$tmpl")" ".config/matugen/templates/$(basename "$tmpl")"
done
command -v matugen >/dev/null 2>&1 \
    && log "matugen found: full desktop colors update with each wallpaper" \
    || log "matugen not found: built-in Pillow fallback recolors Waybar"

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

log "done. Backups (if any) are in: $BACKUP_DIR"
log "reload Hyprland (hyprctl reload) and restart waybar: pkill waybar; waybar &"
