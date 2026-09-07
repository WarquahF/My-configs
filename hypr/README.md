# Hyprland integration

This repo ships four Hyprland files: `config/waybar.lua` (blur rules),
`config/capture.lua` (volume key binds), `config/session.lua`
(wlogout/lock/power keybinds) and `config/matugen.lua` (fallback accent,
copied — matugen regenerates it, optional `require("config.matugen")`).
Everything else in `~/.config/hypr/` is left untouched.

## What it does

- Adds a `waybar` layer rule enabling Hyprland blur behind the bar
  (the frosted-glass effect; Waybar CSS alone cannot blur).
- Adds the same treatment for the `rofi` and `wlogout` layers used by
  the menus and the power overlay.

Blur strength itself stays in your existing
`~/.config/hypr/config/decorations.lua` (`decoration.blur`).
Noctalia stays disabled — nothing here references it.

## Wiring

`install.sh` symlinks the file to
`~/.config/hypr/config/waybar.lua` and ensures `hyprland.lua` contains:

```lua
require("config.waybar")
require("config.capture")
require("config.session")
```

Waybar autostart is the existing line in
`~/.config/hypr/config/autostart.lua`:

```lua
hl.exec_cmd("waybar")
```

The installer verifies that line exists and adds it back if missing.

## Manual setup

```sh
mkdir -p ~/.config/hypr/config
ln -sfn "$PWD/hypr/config/waybar.lua" ~/.config/hypr/config/waybar.lua
grep -q 'config.waybar' ~/.config/hypr/hyprland.lua \
  || sed -i '/require("config.windowrules")/a require("config.waybar")' ~/.config/hypr/hyprland.lua
hyprctl reload
```

## Tuning the glass

- More/less frost: `decoration.blur.size` and `passes` in `decorations.lua`.
- More/less tint: the `rgba(...)` fills in `waybar/style.css`.
- Sharper bar over busy wallpapers: raise `ignore_alpha` slightly
  (e.g. `0.4`) in `config/waybar.lua`.
