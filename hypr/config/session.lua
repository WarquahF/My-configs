-- Session / power integration (Liquid Glass desktop).
--
-- Replaces the Noctalia logout panel with wlogout overlay.
-- install.sh links this to ~/.config/hypr/config/session.lua and adds
-- require("config.session") next to require("config.waybar").
-- Noctalia itself is untouched — only our logout binds moved here.
--
-- Keybinds (checked against binds.lua, no conflicts):
--   SUPER + ALT + C   wlogout overlay (was noctalia panel-toggle session)
--   SUPER + L         fast lock via hyprlock (was noctalia session lock)
--   Direct (no menu), all SUPER+ALT + letter — none used in binds.lua:
--   SUPER + ALT + L   lock        SUPER + ALT + E   logout
--   SUPER + ALT + S   suspend     SUPER + ALT + R   reboot
--   SUPER + ALT + P   shutdown
-- Waybar power pill also launches wlogout (see waybar/config.jsonc).
-- wlogout runs as Wayland layer-shell overlay: no move/resize of Waybar,
-- no reserved space, no Waybar restart.

-- Fast lock (no menu). Falls back to loginctl when hyprlock is missing.
hl.bind("SUPER + L", hl.dsp.exec_cmd("sh -c 'command -v hyprlock >/dev/null && hyprlock || loginctl lock-session'"), { locked = true })

-- Full power overlay: lock / logout / suspend / reboot / shutdown.
-- Hibernate omitted: this machine has only zram swap (7.5G zram, no disk
-- swap), so systemctl hibernate cannot persist. Re-add when disk swap exists.
hl.bind("SUPER + ALT + C", hl.dsp.exec_cmd("sh -c 'command -v wlogout >/dev/null && wlogout -b 5 || $HOME/.config/waybar/scripts/power-menu.sh'"))

-- Direct actions (no menu). Shutdown/reboot act immediately.
hl.bind("SUPER + ALT + L", hl.dsp.exec_cmd("sh -c 'command -v hyprlock >/dev/null && hyprlock || loginctl lock-session'"), { locked = true })
hl.bind("SUPER + ALT + E", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind("SUPER + ALT + S", hl.dsp.exec_cmd("systemctl suspend"))
hl.bind("SUPER + ALT + R", hl.dsp.exec_cmd("systemctl reboot"))
hl.bind("SUPER + ALT + P", hl.dsp.exec_cmd("systemctl poweroff"))
