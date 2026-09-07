-- Wallpaper keybinds (Liquid Glass desktop).
--
-- These lived only in ~/.config/hypr/config/binds.lua, which this repo
-- deliberately never tracks, so the shortcut was not versioned and drifted
-- out of sync with the picker: binds.lua called the script with no argument,
-- which had become "silently advance one wallpaper" rather than the scroll.
-- Owning the binds here keeps the key and the behaviour in one place.
--
-- install.sh links this to ~/.config/hypr/config/wallpaper.lua and adds
-- require("config.wallpaper") to hyprland.lua. It is required after
-- config.binds, so it wins over the old binds.lua line without editing it.
--
--   SUPER + SHIFT + W         scroll every wallpaper (horizontal filmstrip)
--   SUPER + ALT + W           next wallpaper, no GUI
--   SUPER + ALT + SHIFT + W   previous wallpaper, no GUI
--
-- Checked against binds.lua: SUPER+SHIFT+W was the old picker bind and is
-- reclaimed here; SUPER+ALT+W and SUPER+ALT+SHIFT+W are unused there
-- (SUPER+ALT holds the session actions C/L/E/S/R/P, and SUPER+ALT+SHIFT
-- only uses digits 1-3 for monitor focus).
--
-- Wrapped in `sh -c` because Hyprland's Lua exec does not expand $HOME,
-- and hardcoding /home/<user> would not survive being published.

local picker = "$HOME/.config/rofi/wallpaper-picker.sh"

-- The scroll: one flat filmstrip of the whole library, current wallpaper
-- marked and pre-selected. Enter applies, Esc cancels, typing filters.
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("sh -c '" .. picker .. "'"))

-- Blind cycling, for when you just want the next one. New wallpapers slide
-- in from the side matching the direction.
hl.bind("SUPER + ALT + W", hl.dsp.exec_cmd("sh -c '" .. picker .. " --next'"))
hl.bind("SUPER + ALT + SHIFT + W", hl.dsp.exec_cmd("sh -c '" .. picker .. " --previous'"))
