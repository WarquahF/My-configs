# matugen — wallpaper-driven Material You colors (optional).
#
# Without matugen installed, `wallpaper-theme.sh` still recolors Waybar
# from each wallpaper using Python Pillow. With matugen, one command also
# recolors Kitty + rofi (+ Hypr accent):
#
#   sudo pacman -S matugen            # or: yay -S matugen-bin
#   matugen image ~/Pictures/Wallpapers/yours.jpg
#
# The wallpaper cycler (`rofi/wallpaper-picker.sh`, Super+Shift+W) calls
# the theme helper automatically after every apply — no extra step needed.
#
# Files:
#   config.toml            symlinked to ~/.config/matugen/config.toml
#   templates/*            symlinked to ~/.config/matugen/templates/
#   ../waybar/matugen.css  COPIED to ~/.config/waybar/matugen.css (fallback)
#   ../kitty/colors.conf   COPIED to ~/.config/kitty/colors.conf (fallback)
#   ../rofi/matugen.rasi   COPIED to ~/.config/rofi/matugen.rasi (fallback)
#   ../hypr/config/matugen.lua COPIED (fallback accent, optional require)
#
# Generated files are real files (never symlinks) so matugen can
# overwrite them. Delete one and re-run install.sh to restore the fallback.
# Roll back to the static theme anytime: re-run install.sh or
# `cp waybar/matugen.css ~/.config/waybar/matugen.css; pkill -SIGUSR2 waybar`.
