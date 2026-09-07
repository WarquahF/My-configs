-- matugen template -> ~/.config/hypr/config/matugen.lua (accent only).
-- Read by hypr/config/tiling.lua for the focused-window glow.
-- Without matugen, waybar/scripts/wallpaper-theme.sh writes the same file
-- from its Pillow palette, so the accent follows the wallpaper either way.
-- Hyprland colours are 0xAARRGGBB, hence the explicit ff alpha.
return {
    accent = "0xff{{colors.primary.default.hex_stripped}}",
}
