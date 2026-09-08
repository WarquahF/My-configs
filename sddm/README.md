# SDDM — side-by-side login-screen config (greetd stays active).
#
# This repo never touches /etc automatically and never switches your
# display manager. These files are reference drop-ins: copy them by hand
# only when you want to try SDDM.
#
# Current system: greetd + noctalia-greeter-session (see
# `systemctl status display-manager`). SDDM is NOT installed.
#
# To try SDDM:
#   1. sudo pacman -S sddm qt6-svg qt6-virtualkeyboard qt6-multimedia
#   2. sudo mkdir -p /etc/sddm.conf.d
#      sudo cp sddm/10-theme.conf sddm/10-wayland.conf /etc/sddm.conf.d/
#      # edit User=/Session= in 10-theme.conf first if you enable autologin
#   3. Pick a theme, e.g. yay -S sddm-astronaut-theme
#      and set Current= in 10-theme.conf to match.
#   4. Test without rebooting: `sddm-greeter --test-mode --theme <name>`
#   5. Switch (logs you out, save work first):
#        sudo systemctl disable greetd.service
#        sudo systemctl enable sddm.service
#        sudo reboot
#   6. Roll back anytime:
#        sudo systemctl disable sddm.service
#        sudo systemctl enable greetd.service
#
# Files here:
#   10-theme.conf   theme / font / cursor / numlock (edit Current= for yours)
#   10-wayland.conf Wayland greeter defaults + HiDPI (matches 1080p @ 1.5x)
#   theme.conf.user example override for per-theme background (see below)

# --- Per-theme background override (example, do NOT copy as-is) ---
# SDDM reads <theme-dir>/theme.conf.user on top of theme.conf, so your
# change survives theme updates. Example for a theme named "astronaut":
#   sudo cp /usr/share/sddm/themes/astronaut/theme.conf \
#           /usr/share/sddm/themes/astronaut/theme.conf.user
#   then set:  [General] background=/home/YOU/Pictures/Wallpapers/yours.jpg
