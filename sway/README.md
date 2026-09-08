# Sway (side-by-side with Hyprland — Hyprland stays default).
#
# Launch: `sway` from a TTY, or pick the Sway session in your greeter.
# Stop: Super+Alt+E (swaymsg exit) or the wlogout overlay (Super+Alt+C).
#
# What you get: the same Liquid Glass Waybar (Sway module set), the same
# wlogout power overlay (lock/logout/suspend/reboot/shutdown), the same
# rofi/mako/kitty stack, and session binds mirroring hypr/config/session.lua.
#
# Files:
#   sway/config              -> ~/.config/sway/config (this session)
#   ../waybar/config-sway.jsonc -> ~/.config/waybar/config-sway.jsonc (bar)
#   ../swaylock/config       -> ~/.config/swaylock/config (lock screen)
#
# Notes:
# - Screenshots/recordings stay Waybar-only (camera/record pills), same as Hyprland.
# - Wallpaper: `output * bg ...` line in sway/config (swaybg). The rofi
#   wallpaper picker targets awww/Hyprland; on Sway set wallpaper with
#   `swaybg -i <img> -m fill` then optionally `matugen image <img>`.
# - wlogout layout + rofi power-menu.sh already handle both compositors
#   (hyprctl -> swaymsg -> loginctl fallbacks), so no fork needed.
