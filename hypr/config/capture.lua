-- Audio / media key shortcuts (Liquid Glass desktop).
--
-- Separate file so your binds.lua is never overwritten: install.sh links
-- this to ~/.config/hypr/config/capture.lua and adds require("config.capture")
-- next to require("config.waybar").
--
-- Screenshot / screen-recorder are WAYBAR-ONLY by design (no keybinds):
-- click the camera / record pills in the top bar for the rofi menus.
-- Nothing here binds Print or SUPER+ALT+R anymore.
--
-- binds.lua points every one of these at `noctalia msg ...`, and the
-- noctalia daemon is disabled, so they are all dead there. This file is
-- required after config.binds, so these working binds are registered last
-- and do the real job:
--   F3 / XF86AudioRaiseVolume   main volume +5%
--   F2 / XF86AudioLowerVolume   main volume -5%
--   XF86AudioMute               toggle output mute
--   XF86AudioMicMute            toggle microphone mute
--   XF86AudioPlay / Pause       play-pause the active player
--   XF86AudioNext / Prev        skip track
-- The bar icons stay as the clickable alternative (rofi menus).
-- Scroll on the bar's volume icon also adjusts volume.
--
-- Every bind below is { locked = true }, which is what makes the lock screen
-- usable while music plays: locking never pauses audio (see
-- ../hyprlock.conf), so you still need to be able to change the volume and
-- skip tracks without unlocking.

-- Main system volume via pactl (PipeWire/Pulse). Both the bare F2/F3 keys
-- and the XF86 media keysyms are bound so it works whether fnLock is on or
-- off. { locked = true } lets them work on the lock screen too,
-- { repeating = true } keeps changing volume while the key is held.
hl.bind("F3", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +5%"), { locked = true, repeating = true })
hl.bind("F2", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%"), { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +5%"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%"), { locked = true, repeating = true })

-- Mute toggles. Not repeating: holding the key must not flap the state.
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"), { locked = true })

-- Media transport via playerctl (MPRIS), so it drives whichever player is
-- actually playing -- Spotify, Firefox, mpv -- with no per-app config.
-- Both keysyms map to play-pause: the toggle is what a single key should do.
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
