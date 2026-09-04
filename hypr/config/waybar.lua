-- Waybar liquid-glass integration.
--
-- The frosted look needs real compositor blur: Waybar's translucent fills
-- (see ../../waybar/style.css) are blurred by Hyprland via this layer rule.
-- Requires: require("config.waybar") in hyprland.lua (handled by install.sh).
-- Blur itself stays configured in config/decorations.lua; this file only
-- opts the Waybar (and rofi menu) surfaces into it.

hl.layer_rule({
    match = { namespace = "waybar" },
    blur = true,
    blur_popups = true,
    ignore_alpha = 0.3,
})

-- Rofi power menu (~/.config/waybar/scripts/power-menu.sh) gets the same
-- treatment so it floats over a softly blurred background.
hl.layer_rule({
    match = { namespace = "rofi" },
    blur = true,
    ignore_alpha = 0.3,
})
