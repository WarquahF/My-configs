# Hyprland integration

This repo ships these Hyprland files:

| File | What it owns |
| --- | --- |
| `config/waybar.lua` | blur layer rules for waybar/rofi/wlogout |
| `config/capture.lua` | volume, mute and media key binds |
| `config/session.lua` | wlogout / lock / power keybinds |
| `config/navigation.lua` | Alt+Tab window switcher |
| `config/wallpaper.lua` | wallpaper scroll + cycle keybinds |
| `config/matugen.lua` | fallback accent (copied — matugen regenerates it, optional `require("config.matugen")`) |
| `hyprlock.conf` | the lock screen |

Everything else in `~/.config/hypr/` is left untouched — in particular
`binds.lua`, `autostart.lua` and `decorations.lua` stay yours.

## What it does

- Adds a `waybar` layer rule enabling Hyprland blur behind the bar
  (the frosted-glass effect; Waybar CSS alone cannot blur).
- Adds the same treatment for the `rofi` and `wlogout` layers used by
  the menus and the power overlay.

Blur strength itself stays in your existing
`~/.config/hypr/config/decorations.lua` (`decoration.blur`).
Noctalia stays disabled — nothing here references it.

## Binds this repo owns

`binds.lua` routes most hardware and wallpaper keys through
`noctalia msg ...`, and the noctalia daemon is disabled, so those binds are
dead. Rather than editing your `binds.lua`, these modules are required
**after** `config.binds`, so the working bind is registered last and wins:

| Key | Action |
| --- | --- |
| `Super+Shift+W` | scroll every wallpaper (horizontal filmstrip) |
| `Super+Alt+W` / `Super+Alt+Shift+W` | next / previous wallpaper, no GUI |
| `Super+L` | lock (see `hyprlock.conf`) |
| `Super+Alt+C` | wlogout power overlay |
| `F2` / `F3`, `XF86AudioRaise/LowerVolume` | volume ±5% |
| `XF86AudioMute` / `XF86AudioMicMute` | toggle output / mic mute |
| `XF86AudioPlay/Pause/Next/Prev` | `playerctl` transport |

Every audio and media bind carries `{ locked = true }`, so it keeps working
on the lock screen. That is deliberate: locking does not pause audio, so you
need to be able to adjust volume and skip tracks without unlocking.

## Lock screen (`hyprlock.conf`)

Without a config file `hyprlock` refuses to start, so `Super+L` fell through
to `loginctl lock-session` — which does nothing when no locker is registered.
The screen never actually locked. `hyprlock.conf` is that missing config, and
because it lives at the standard path every entry point (`Super+L`,
`Super+Alt+L`, the wlogout Lock button, `power-menu.sh`) runs plain
`hyprlock` and gets the same screen.

It shows **the wallpaper you currently have applied**, blurred, plus a live
clock and a now-playing line. It reads one fixed path,
`~/.cache/wallpaper-picker/lock-background.jpg`, which
`rofi/wallpaper-picker.sh` re-encodes on every wallpaper change; that is why
the config never needs regenerating. Re-sync by hand with:

```sh
~/.config/rofi/wallpaper-picker.sh --sync-lock-image
```

If that file is missing the lock screen falls back to a dark fill rather
than failing. A screenshot background is deliberately not used: it would
leak whatever was on screen when you locked.

## Wiring

`install.sh` symlinks each module into `~/.config/hypr/config/` and ensures
`hyprland.lua` contains, in this order:

```lua
require("config.waybar")
require("config.capture")
require("config.session")
require("config.navigation")
require("config.wallpaper")
```

The list is `HYPR_MODULES` in `install.sh`: one array drives the symlinks and
these require lines, so a new module is named in exactly one place.

Waybar autostart is the existing line in
`~/.config/hypr/config/autostart.lua`:

```lua
hl.exec_cmd("waybar")
```

The installer verifies that line exists and **warns if it is missing** (it
does not synthesise placement inside your `hyprland.start` callback). The
mako / awww-daemon / cursor-wiggle autostart lines anchor off it, so add the
waybar line and re-run `install.sh` if you see that warning.

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
