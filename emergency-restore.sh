#!/usr/bin/env bash
# Emergency restore — jump back to your pre-install configuration.
# On-demand only: no daemon, no background work, zero idle cost.
#
# What it does:
#   1. Finds the newest ~/.config-backup-* (and manual backups).
#   2. Shows what would be restored, asks for confirmation.
#   3. Removes our symlinks and copies the backup files back.
#   4. Reloads Hyprland + restarts Waybar (same as install.sh outro).
#
# Usage:
#   ./emergency-restore.sh              # interactive, newest backup
#   ./emergency-restore.sh --list       # list available backups
#   ./emergency-restore.sh --yes        # restore newest without asking
#   ./emergency-restore.sh <backup-dir> # restore a specific backup
set -euo pipefail
HOME_DIR="${HOME:-}"; [[ -d "$HOME_DIR" ]] || { echo "no HOME" >&2; exit 1; }
list_backups() { ls -dt "$HOME_DIR"/.config-backup-* 2>/dev/null || true; }
if [[ "${1:-}" == "--list" ]]; then list_backups; exit 0; fi
BACKUP=""
if [[ -n "${1:-}" && -d "$1" ]]; then BACKUP="$1"
elif [[ "${1:-}" == "--yes" ]]; then BACKUP="$(list_backups | head -n1)"
else BACKUP="$(list_backups | head -n1)"
fi
[[ -n "$BACKUP" && -d "$BACKUP" ]] || { echo "no backup found in $HOME_DIR/.config-backup-*" >&2; exit 1; }
echo "[emergency] backup: $BACKUP"
echo "[emergency] contains:"; find "$BACKUP" -type f | head -n 20
if [[ "${1:-}" != "--yes" ]]; then
    read -rp "[emergency] restore these files? [y/N] " ans
    [[ "$ans" == [yY]* ]] || { echo "aborted."; exit 0; }
fi
# Remove the symlink at each path THIS backup will restore, so `cp` writes a
# real file instead of following (and overwriting through) the link. Scoped to
# the backed-up paths only — unrelated symlinks elsewhere in ~/.config, broken
# or not, are never touched.
while IFS= read -r -d '' src; do
    dest="$HOME_DIR/.config/${src#"$BACKUP"/.config/}"
    [[ -L "$dest" ]] && rm -f "$dest"
done < <(find "$BACKUP/.config" -type f -print0 2>/dev/null || true)
cp -a "$BACKUP"/.config/. "$HOME_DIR/.config/"
echo "[emergency] restored from $BACKUP"
hyprctl reload 2>/dev/null || true
pkill waybar 2>/dev/null || true
sleep 1; nohup waybar >/tmp/waybar.log 2>&1 & disown || true
echo "[emergency] done. Hyprland reloaded, Waybar restarted."
