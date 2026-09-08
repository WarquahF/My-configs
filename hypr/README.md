# Hyprland integration

This repo ships these Hyprland files:

| File | What it owns |
| --- | --- |
| `config/waybar.lua` | blur layer rules for waybar/rofi/wlogout |
| `config/capture.lua` | volume, mute and media key binds |
| `config/session.lua` | wlogout / lock / power keybinds |
| `config/navigation.lua` | Alt+Tab window switcher |
| `config/wallpaper.lua` | wallpaper scroll + cycle keybinds |
| `config/tiling.lua` | how the dwindle layout moves + the focus glow |
| `config/matugen.lua` | current accent (generated — see below) |
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

## Tiling feel (`config/tiling.lua`)

Your `animations.lua` and `decorations.lua` keep owning the **static** look —
gaps, rounding, opacity, blur, border colours. `tiling.lua` is required after
them and overrides only the **motion**, so deleting its require line restores
your settings on the next reload.

- **Tiles settle instead of teleporting.** `windowsMove` runs on a spring
  that overshoots slightly and comes back, so every reflow — opening,
  closing, swapping, resizing a neighbour — reads as weight rather than a
  redraw somewhere else.
- **Windows scale into their slot** (`popin 85%`) instead of flying in from a
  screen edge, and closing reverses it.
- **Focus reacts**: the border colour eases, and the gradient sweeps once
  when focus lands.
- **The focused window is lit in the wallpaper's accent colour**
  (`decoration.glow`), and that colour changes as you scroll wallpapers —
  see below.
- **Dwindle ergonomics**: `preserve_split` keeps a container's orientation
  when a sibling closes; `smart_resizing` resizes the edge you are pulling.
  Floating windows snap to neighbours and screen edges.

It is deliberately motion-first. This machine is Intel UHD G4 driving
1920x1080 with `blur.passes = 4`, so there is little per-frame headroom:
everything here costs only while something is moving. The two effects that
would cost every frame are handled accordingly — `borderangle` runs `once`
per focus change rather than `loop` (a loop repaints forever, on battery
too), and `decoration.motion_blur` ships **off**, with a commented one-liner
at the bottom of the file if you want to try it.

## The accent follows the wallpaper

`waybar/scripts/wallpaper-theme.sh` already derived a Waybar palette from
each wallpaper. It now applies that same accent to Hyprland:

1. writes it to `~/.config/hypr/config/matugen.lua`, which `tiling.lua`
   reads, so the glow survives a reload;
2. pushes it to the running compositor so the change is immediate.

That second step uses `hyprctl eval` with an `hl.config{}` call, not
`hyprctl keyword` — this Lua-config build rejects keywords outright:

```
$ hyprctl keyword decoration:glow:color "rgba(e67946ff)"
keyword can't work with non-legacy parsers. Use eval.
```

With matugen installed its own hypr template writes the same file and its
post_hook reloads Hyprland, so the accent follows the wallpaper either way.

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
