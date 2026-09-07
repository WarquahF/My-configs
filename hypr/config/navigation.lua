-- Window navigation (Liquid Glass desktop).
--
-- Separate file so your binds.lua is never overwritten: install.sh links this
-- to ~/.config/hypr/config/navigation.lua and adds require("config.navigation")
-- alongside the other requires.
--
--   ALT + Tab         focus the next window on this workspace (app switcher)
--   ALT + SHIFT + Tab  focus the previous window
--
-- Uses the object-form dispatch through hyprctl (the same idiom the power
-- binds in session.lua use): plain string dispatches like `dispatch cyclenext`
-- are broken in this CachyOS Hyprland Lua build, but `hyprctl dispatch
-- 'hl.dsp.<dispatcher>(...)'` works. Because each bind runs as a command, a
-- dispatcher name this build spells differently only no-ops when pressed --
-- it can never error at load time and break the rest of your config.
--
-- To also raise the focused window (useful for floating windows), append
-- "; hyprctl dispatch 'hl.dsp.bringactivetotop()'" to the ALT+Tab command.

hl.bind("ALT + Tab", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.cyclenext()'"))
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.cyclenext(prev)'"))
