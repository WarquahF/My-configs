#!/usr/bin/env bash
# Install the CachyOS + Hyprland dotfiles from this repo.
# - Symlinks repo files into ~/.config (backing up anything replaced)
# - Wires the Hyprland waybar.lua integration without touching other config
# - Never installs packages; missing deps are reported, not fetched.
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
for opt in nmcli nmtui pactl pavucontrol loginctl systemctl python3; do
    command -v "$opt" >/dev/null 2>&1 || warn "optional tool missing: $opt (some bar actions degrade gracefully)"
done

# --- Helpers ----------------------------------------------------------------
backup_if_exists() {
    # backup_if_exists <path>: move existing file/dir/symlink into $BACKUP_DIR.
    local target="$1"
    if [[ -e "$target" || -L "$target" ]]; then
        local rel="${target#$HOME_DIR/}"
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        mv "$target" "$BACKUP_DIR/$rel"
        log "backed up ~/$rel"
    fi
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
    backup_if_exists "$dest"
    ln -sfn "$src" "$dest"
    log "linked ~/$2 -> $1"
}

# --- Directories --------------------------------------------------------------
mkdir -p "$HOME_DIR/.config/waybar/scripts" "$HOME_DIR/.config/hypr/config" \
         "$HOME_DIR/.config/kitty" "$HOME_DIR/.config/btop" \
         "$HOME_DIR/Pictures/Wallpapers"

# --- Waybar -------------------------------------------------------------------
link_file "waybar/config.jsonc" ".config/waybar/config.jsonc"
link_file "waybar/style.css" ".config/waybar/style.css"
link_file "waybar/scripts/power-menu.sh" ".config/waybar/scripts/power-menu.sh"
chmod +x "$REPO_DIR/waybar/scripts/power-menu.sh"
log "power-menu.sh is executable"

# --- Hyprland: blur layerrule only, existing config untouched -----------------
link_file "hypr/config/waybar.lua" ".config/hypr/config/waybar.lua"

HYPR_MAIN="$HOME_DIR/.config/hypr/hyprland.lua"
if [[ -f "$HYPR_MAIN" ]]; then
    if grep -q 'require("config.waybar")' "$HYPR_MAIN"; then
        log "hyprland.lua already requires config.waybar"
    else
        backup_if_exists "$HYPR_MAIN"
        # Re-create from backup with the require added after windowrules.
        cp "$BACKUP_DIR/.config/hypr/hyprland.lua" "$HYPR_MAIN"
        if grep -q 'require("config.windowrules")' "$HYPR_MAIN"; then
            sed -i '/require("config.windowrules")/a require("config.waybar")' "$HYPR_MAIN"
        else
            printf '\nrequire("config.waybar")\n' >> "$HYPR_MAIN"
        fi
        log "added require(\"config.waybar\") to hyprland.lua"
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
fi

# --- Kitty / btop (backed up, Noctalia includes dropped) ----------------------
link_file "kitty/kitty.conf" ".config/kitty/kitty.conf"
link_file "btop/btop.conf" ".config/btop/btop.conf"

# --- Validate ------------------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
    python3 - "$REPO_DIR/waybar/config.jsonc" <<'EOF'
import json, re, sys
text = open(sys.argv[1]).read()
text = re.sub(r'//.*', '', text)              # strip // comments
text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)  # strip /* */ comments
json.loads(text)
print('[install] waybar config.jsonc: valid JSONC')
EOF
fi
bash -n "$REPO_DIR/waybar/scripts/power-menu.sh" && log "power-menu.sh: syntax OK"
bash -n "$REPO_DIR/install.sh" && log "install.sh: syntax OK"

log "done. Backups (if any) are in: $BACKUP_DIR"
log "reload Hyprland (hyprctl reload) and restart waybar: pkill waybar; waybar &"
