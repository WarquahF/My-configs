#!/usr/bin/env bash
# Fingerprint helper — MANUAL ONLY, never called by install.sh.
# Wraps fprintd enroll/verify/list + prints PAM instructions.
# Usage: setup-fingerprint.sh [--help|enroll|verify|list|pam-info]
set -euo pipefail
cmd="${1:---help}"
have() { command -v "$1" >/dev/null 2>&1; }
case "$cmd" in
    --help|-h|help)
        echo "usage: setup-fingerprint.sh [enroll|verify|list|pam-info]"
        echo "  enroll   fprintd-enroll for current user (Goodix 27c6:5503)"
        echo "  verify   fprintd-verify"
        echo "  list     fprintd-list"
        echo "  pam-info show manual /etc/pam.d steps (does NOT edit PAM)"
        ;;
    enroll)
        have fprintd-enroll || { echo "missing: fprintd (sudo pacman -S fprintd libfprint)" >&2; exit 1; }
        lsusb | grep -i "27c6:5503" || echo "warning: Goodix 27c6:5503 not seen in lsusb"
        fprintd-enroll "$USER"
        ;;
    verify)
        have fprintd-verify || { echo "missing: fprintd" >&2; exit 1; }
        fprintd-verify "$USER"
        ;;
    list)
        have fprintd-list || { echo "missing: fprintd" >&2; exit 1; }
        fprintd-list "$USER"
        ;;
    pam-info)
        cat <<'EOF'
Manual PAM step (backup first, then add as FIRST auth line):
  auth sufficient pam_fprintd.so
Files typically edited: /etc/pam.d/login, /etc/pam.d/sudo
Example:
  sudo cp /etc/pam.d/sudo /etc/pam.d/sudo.bak-$(date +%Y%m%d)
  sudoedit /etc/pam.d/sudo
This script never edits /etc/pam.d automatically.
EOF
        ;;
    *) echo "unknown: $cmd (try --help)" >&2; exit 1 ;;
esac
