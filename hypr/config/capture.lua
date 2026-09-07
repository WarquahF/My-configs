-- Volume-key shortcuts (Liquid Glass desktop).
--
-- Separate file so your binds.lua is never overwritten: install.sh links
-- this to ~/.config/hypr/config/capture.lua and adds require("config.capture")
-- next to require("config.waybar").
--
-- Screenshot / screen-recorder are WAYBAR-ONLY by design (no keybinds):
-- click the camera / record pills in the top bar for the rofi menus.
-- Nothing here binds Print or SUPER+ALT+R anymore.
--
-- Volume (binds.lua points these at dead Noctalia, so they do nothing there;
-- these working binds are registered after and do the real job):
--   F3 / XF86AudioRaiseVolume   main volume +5%
--   F2 / XF86AudioLowerVolume   main volume -5%
-- The bar icons stay as the clickable alternative (rofi menus).
-- Scroll on the bar's volume icon also adjusts volume.

-- Main system volume via pactl (PipeWire/Pulse). Both the bare F2/F3 keys
-- and the XF86 media keysyms are bound so it works whether fnLock is on or
-- off. { locked = true } lets them work on the lock screen too,
-- { repeating = true } keeps changing volume while the key is held.
hl.bind("F3", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +5%"), { locked = true, repeating = true })
hl.bind("F2", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%"), { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +5%"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%"), { locked = true, repeating = true })
