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

-- wlogout power overlay (replaces Noctalia session). Layer-shell overlay:
-- appears above Waybar/desktop, reserves no space, moves/resizes nothing.
hl.layer_rule({
    match = { namespace = "wlogout" },
    blur = true,
    ignore_alpha = 0.3,
})

-- Dropdown info panels (temp-info.sh / mem-info.sh --popup, launched as
-- `kitty --class waybar-dropdown`). Small floating windows pinned under
-- the top-right bar cluster (bar bottom ~= 48px). Sizes are tuned per
-- panel; any key closes the panel, "b" swaps it for full btop.
hl.window_rule({
    match = { class = "^(waybar-dropdown)$", title = "^(CPU Temp)$" },
    float = true,
    size = { "460", "300" },
    move = { "monitor_w - 472", "56" },
})

hl.window_rule({
    match = { class = "^(waybar-dropdown)$", title = "^(Memory)$" },
    float = true,
    size = { "460", "400" },
    move = { "monitor_w - 472", "56" },
})
