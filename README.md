# CachyOS Hyprland Dotfiles — Liquid Glass Waybar

Minimal, premium desktop configuration for CachyOS + Hyprland.
The centerpiece is a floating, frosted-glass Waybar:
translucent islands, subtle border, soft shadow — no gradients, no glow,
no generic rice.

Noctalia is intentionally disabled and nothing here depends on it.

## System

- OS: CachyOS · Compositor: Hyprland (Lua config) · Shell: Zsh
- Terminal: Kitty · Editor: Zed · Bar: Waybar · Launcher/menu: rofi
- Font: MesloLGS Nerd Font Mono · Display: 1920×1080 @ 1.5x scale

## Structure

```
.
├── README.md
├── install.sh                  # symlink installer with backups + conflict prompt
├── emergency-restore.sh        # one-command rollback to newest backup
├── waybar/
│   ├── config.jsonc            # layout + modules (Hyprland)
│   ├── config-sway.jsonc       # same islands, sway/workspaces (Sway)
│   ├── style.css               # liquid-glass theme (+ matugen.css import)
│   ├── matugen.css             # fallback palette (copied; regenerated per wallpaper)
│   └── scripts/
│       ├── power-menu.sh       # rofi power menu (wlogout fallback, +Suspend)
│       ├── wifi-menu.sh        # rofi Wi-Fi menu (see below)
│       ├── bluetooth-menu.sh   # rofi Bluetooth menu
│       ├── screenshot-menu.sh  # silent capture (fullscreen/region/window)
│       ├── screenrecord-menu.sh # rofi screen recorder (fullscreen/region/stop)
│       ├── wallpaper-theme.sh  # animated Waybar colors from the wallpaper
│       └── battery-info.sh     # battery details popup (see below)
├── hypr/
│   ├── README.md
│   ├── config/
│   │   ├── waybar.lua          # blur layer rules for waybar/rofi/wlogout
│   │   ├── capture.lua         # volume/mute/media binds (F2/F3 + XF86Audio*)
│   │   ├── session.lua         # wlogout/lock/power keybinds
│   │   ├── navigation.lua      # Alt+Tab window switcher
│   │   ├── wallpaper.lua       # wallpaper scroll + cycle keybinds
│   │   └── matugen.lua         # fallback accent (copied; matugen regenerates)
│   ├── hyprlock.conf           # lock screen: current wallpaper + now playing
│   └── scripts/cursor-wiggle.py # shake-to-find-cursor daemon
├── sway/
│   ├── README.md               # side-by-side Sway session (Hyprland stays default)
│   └── config                # sway session reusing waybar-sway + wlogout + mako
├── swaylock/config             # Sway lock screen (swayidle + Super+L)
├── matugen/                    # wallpaper-driven colors (optional, graceful)
│   ├── README.md
│   ├── config.toml             # wallpaper set=false, 4 templates
│   └── templates/              # waybar / kitty / rofi / hypr templates
├── sddm/                       # side-by-side login config (reference only, greetd stays)
│   ├── README.md
│   ├── 10-theme.conf
│   └── 10-wayland.conf
├── wlogout/                    # overlay power menu (layout, style, icons)
├── kitty/
│   ├── kitty.conf            # standalone + `include colors.conf`
│   └── colors.conf           # fallback palette (copied; matugen regenerates)
├── btop/btop.conf              # minimal overrides, built-in theme
├── mako/config                 # notifications: 7s timeout, critical persists
├── rofi/
│   ├── wallpaper-picker.sh     # GUI-free animated wallpaper cycling
│   ├── wallpaper.rasi          # optional manual filmstrip theme
│   ├── wallpaper-menu.rasi     # optional manual category theme
│   └── matugen.rasi            # fallback accent (copied; matugen regenerates)
├── fingerprint/                # manual Goodix 27c6:5503 notes — never auto-run
├── config-files/               # on-demand reference helpers, nothing symlinked
└── wallpapers/README.md        # wallpapers live in ~/Pictures/Wallpapers
```

Only Waybar/Hyprland glue is versioned for Hyprland itself —
your existing `~/.config/hypr/` files are never overwritten.

## Installation

```sh
git clone <your-repo-url> ~/My-configs
cd ~/My-configs
chmod +x install.sh
./install.sh
hyprctl reload; pkill waybar; waybar &
```

What it does:

1. Checks required deps (`hyprctl`, `waybar`, `rofi`) and fails safely
   if any are missing — nothing is installed automatically.
2. If it finds existing (non-symlink) configs it would replace, it asks
   first: replace **all** (with backup), **ask per file**, or **abort**.
3. Creates `~/.config/{waybar/scripts,hypr/config,kitty,btop,mako,rofi,wlogout}`,
   `~/Pictures/{Wallpapers,Screenshots}` and `~/Videos/Recordings`.
4. Moves anything it replaces into
   `~/.config-backup-YYYYMMDD-HHMMSS/` (originals are moved, never deleted).
5. Symlinks repo files into `~/.config` and makes scripts executable.
6. Adds `require("config.waybar")`, `require("config.capture")`,
   `require("config.session")` and `require("config.navigation")` to
   `hyprland.lua` (backed up first) and verifies the existing
   `hl.exec_cmd("waybar")` autostart line.

Rollback anytime with `./emergency-restore.sh` (newest backup, asks first;
`--list` shows all backups, `--yes` skips the prompt).

## Waybar features

- **Left** — workspaces 1–5 (persistent, click to jump):
  active workspace is a distinct glass pill, inactive stays subtle,
  hover is visible, urgent is red-tinted.
- **Center** — live `HH:MM` clock; tooltip shows the full date and time
  on separate lines (single format group — this Waybar build rejects
  multiple `{}` groups in one tooltip string).
- **Right** — network, volume, battery, CPU temp, RAM, power button
  as separate pills:
  - Wi-Fi/ethernet/disconnected icons + tooltip (ESSID, signal, IP).
    **Click** opens a rofi Wi-Fi menu: activate a connection (scan +
    connect, password prompt if needed), saved connections,
    edit via `nmtui`, set system host name, toggle the Wi-Fi radio, quit.
  - Bluetooth with on/off/connected states; **click** opens a rofi menu:
    radio power, scan & pair, connect/disconnect devices.
  - Volume with low/medium/high/muted icons and `%`; scroll to adjust,
    click for `pavucontrol`, right-click to mute.
  - Battery with capacity-tracked icons, `%`, charging/plugged states,
    amber warning (~30%) and red critical (~15%), tooltip with time + power.
    **Click** opens a popup with time remaining, current draw,
    and the top power-consuming apps.
  - CPU temperature from the `coretemp` package sensor with icon scale,
    red alert past 85 °C; **click** drops a small panel under the bar with
    per-core temps (any key closes, `b` opens full `btop`).
  - RAM load with used/total/swap tooltip; **click** drops a small panel
    under the bar with availability and top memory consumers
    (any key closes, `b` opens full `btop`).
  - Keep-awake toggle: **click** the sun/moon icon to hold a logind
    inhibitor (`idle` + `sleep`) so the PC stays awake — no extra
    packages. Dim moon = normal, amber sun = staying awake.
  - Notification bell with unread count; **click** opens a rofi
    notification center (visible + history, dismiss-all action).
  - Screenshot camera; **click** opens a rofi menu: fullscreen,
    region (`slurp`), active window, 3s delay. Capture itself is silent,
    so no countdown notification can be embedded in the image. Saves to
    `~/Pictures/Screenshots/`, copies to clipboard, and opens
    `swappy`/`satty` if installed.
  - Screen recorder; **click** opens a rofi menu: fullscreen,
    region, stop. Records the **system audio you're playing** (Spotify,
    browser, games) via the default sink's monitor, and saves `.mp4` to
    `~/Videos/Recordings/` (needs `wf-recorder` + `pactl`; red pill in bar
    while recording). Set `SCREENREC_AUDIO=none` for silent video, or a
    source name to record a mic instead.
  - Power button; **click** opens the `wlogout` frosted overlay
    (lock/logout/suspend/reboot/shutdown), falling back to the rofi
    power menu when `wlogout` is missing.
- Subtle 0.2s transitions on hover/state changes; compact sizing
  tuned for 1080p @ 1.5x.

## Wallpapers (scroll or cycle, via awww)

- Press **Super+Shift+W** to scroll the library: **every** wallpaper at once
  in one horizontal thumbnail filmstrip — no folders, no category step.
  Scroll the strip, **Enter** applies instantly, **Esc** cancels. Type to
  filter anytime.
- The current wallpaper is marked (●) and pre-selected on open.
- Prefer no GUI at all? **Super+Alt+W** / **Super+Alt+Shift+W** jump straight
  to the next / previous wallpaper, entering from the matching side.
- These keybinds live in `hypr/config/wallpaper.lua`, so they are versioned
  here rather than in the untracked `binds.lua`.
- Prefer folders for a big mixed library? Run the picker with `--menu` for
  the category-first flow (which also offers **Random wallpaper**);
  `--random` applies one at random directly.
- Applies via `awww` with a 1.05s eased transition (60fps, no fade).
- Every change regenerates the Waybar palette and replays a short color
  transition. Matugen is used when installed; otherwise the included
  `wallpaper-theme.sh` derives colors with Python Pillow.
- Library: `~/Pictures/Wallpapers` by default; override with `$WALLPAPER_DIR`
  or a path in `~/.config/my-local-configs/wallpaper-dir` (static
  jpg/jpeg/png/webp/bmp; GIF/video/animated-webp excluded).
- Thumbnails are cached in `~/.cache/wallpaper-picker/` (built once by
  `install.sh`, refreshed automatically when you add/remove images).
- Your launcher theme is untouched: the picker uses its own
  `wallpaper.rasi` / `wallpaper-menu.rasi` via `rofi -config`.

## Notifications (mako)

- Every notification vanishes after **7 seconds** — no pile-up on the
  workspace. Expired items are kept in a 50-entry history.
- **Emergency (`critical`) notifications never auto-dismiss**; they stay
  until you dismiss them.
- The bell shows the unread count and lights up when something is waiting;
  clicking it opens the notification center (visible + recent history,
  with a dismiss-all action).
- Style (dark frosted pill, top-right) lives in `mako/config`.
  Apply changes with `makoctl reload`.

## Desktop feel (animations + wiggle cursor)

- Workspace switching uses a macOS-style **slidefade** on a smooth
  ease-out curve (your local `~/.config/hypr/config/animations.lua`,
  other animations untouched — not versioned here).
- **Shake to find the cursor:** wiggle the mouse fast and the cursor
  doubles in size, shrinking back when you stop. Tiny stdlib-only daemon
  (`hypr/scripts/cursor-wiggle.py`), started from Hyprland autostart,
  single-instance, logs to `~/.cache/cursor-wiggle.log`.

## Session & power (wlogout)

- The bar's power pill and **Super+Alt+C** open the `wlogout` overlay —
  a Wayland layer-shell surface, so Waybar never moves or restarts.
  Blur comes from the `wlogout` layer rule in `hypr/config/waybar.lua`.
  Five buttons: **Lock / Logout (= Signout) / Suspend / Reboot / Shutdown**.
- Fast lock: **Super+L** (`hyprlock` → `swaylock -f` → `loginctl` fallback).
  The lock screen is `hypr/hyprlock.conf` — see below.
- Direct actions (no menu): **Super+Alt+L** lock · **Super+Alt+E** logout ·
  **Super+Alt+S** suspend · **Super+Alt+R** reboot · **Super+Alt+P** shutdown.
- Portable across compositors: layout actions try
  `hyprctl` → `swaymsg` → `loginctl`, so the same overlay works in Sway.
  The rofi fallback (`power-menu.sh`) includes Suspend too.
- Hibernate is intentionally omitted: this machine only has zram swap.
- Keybinds live in `hypr/config/session.lua` (Hyprland) and `sway/config`
  (Sway); `binds.lua` is untouched.

## Lock screen (hyprlock)

- Shows **the wallpaper you currently have applied**, blurred, with a live
  clock, the date, and a now-playing line when something is playing.
- **Audio keeps playing while locked.** Nothing in the lock path pauses
  players, and volume / mute / play-pause / next / previous stay bound on the
  lock screen (`{ locked = true }` in `hypr/config/capture.lua`), so you can
  control the music without unlocking.
- The wallpaper comes from one fixed path,
  `~/.cache/wallpaper-picker/lock-background.jpg`, refreshed by the picker on
  every wallpaper change. So every lock entry point — Super+L, Super+Alt+L,
  the wlogout **Lock** button, `power-menu.sh` — shows the same current
  wallpaper, and the config itself never needs regenerating.
  Re-sync by hand: `wallpaper-picker.sh --sync-lock-image`.
- A screenshot background is deliberately **not** used: it would leak
  whatever was on screen when you locked. Missing cache file falls back to a
  dark fill instead of failing.
- Note: before this config existed, `hyprlock` had none at all — it exits
  with “No config file at …”, so Super+L fell through to
  `loginctl lock-session` and the screen never actually locked.

## Sway (side-by-side WM)

- Hyprland stays default. `sway/config` reuses the same Waybar islands
  (`waybar/config-sway.jsonc`: `sway/workspaces` + `sway/mode` left,
  identical right modules), the same wlogout overlay, mako, rofi, kitty.
- Launch: `sway` from a TTY or pick Sway in the greeter.
  Stop: Super+Alt+E or the wlogout overlay. See `sway/README.md`.
- Install: `sudo pacman -S sway swaylock swayidle swaybg`.

## Theming details (matugen + fallback)

- Every wallpaper change regenerates `~/.config/waybar/matugen.css`
  (see “Wallpapers” above). With matugen installed, `matugen/config.toml`
  additionally recolors kitty (`colors.conf`), rofi (`matugen.rasi`) and
  the Hypr accent (`config/matugen.lua`) from the same wallpaper.
- Generated files are real files (never symlinks); install.sh only copies
  fallbacks when missing, never clobbering generated output.
- Details in `matugen/README.md`.

## Login screen / SDDM (side-by-side reference)

- The system uses **greetd + noctalia-greeter**; `sddm/` never activates
  automatically and install.sh never touches `/etc` or switches greeters.
- To try SDDM: install it, `sudo cp sddm/*.conf /etc/sddm.conf.d/`,
  set a theme, test with `sddm-greeter --test-mode`. Steps in `sddm/README.md`.

## Known upstream quirk (Hyprland Lua build)

String dispatches like `hyprctl dispatch workspace 3` fail core-side
(`hl.dispatch` wrapping bug), so bar **click-to-switch** (`activate`)
and plain `hyprctl dispatch …` commands don't work until CachyOS ships
a fix. Workarounds already in place: Super+number keybinds (native Lua,
fully working), bar scroll and the power-menu logout use the
`hyprctl dispatch 'hl.dsp.…(…)'` object form, which works.

## Hyprland integration

- `hypr/config/waybar.lua` adds `blur = true` layer rules for the
  `waybar`, `rofi` and `wlogout` namespaces — this is what makes the bar
  frosted (Waybar CSS cannot blur by itself; there is no `backdrop-filter`).
- Blur strength stays in your `decorations.lua`; Noctalia's commented
  startup line is left as-is. See `hypr/README.md` for tuning.
- `hypr/config/capture.lua` (live after `hyprctl reload`): volume keys
  only — `F3` volume +5%, `F2` volume −5% (also bound on the
  `XF86Audio*` media keysyms, so fnLock on/off both work).
  Screenshot and screen recording are **waybar-only by design**: click
  the camera / record pills for the rofi menus (no Print/record keybinds).
- `hypr/config/session.lua`: wlogout + lock + direct power keybinds
  (see “Session & power” above).
- `hypr/config/navigation.lua`: **Alt+Tab** focuses the next window on the
  current workspace, **Alt+Shift+Tab** the previous — a classic app switcher.
  Uses the object-form dispatch, so it is unaffected by the string-dispatch
  bug noted above.

## Fingerprint (manual, optional)

`fingerprint/` documents Goodix 27c6:5503 setup (community driver,
enrollment, PAM notes). `install.sh` deliberately never touches it —
see `fingerprint/README.md` and `setup-fingerprint.sh --help`.

## Customizing the theme

All glass tokens live in `waybar/style.css`:

- Tint/opacity: the `rgba(16, 18, 24, 0.55)` island fills.
- Border: `rgba(255, 255, 255, 0.12)`; radius `14px`.
- Shadow: `0 8px 24px rgba(0,0,0,0.35)`.
- State colors: `#battery.warning/critical`, `#network.disconnected`,
  `#pulseaudio.muted`, `#workspaces button.urgent`.

After editing: `pkill waybar; waybar &` (no Hyprland reload needed).
For stronger frost, raise `decoration.blur.size/passes` in
`~/.config/hypr/config/decorations.lua` instead of touching opacity.

## Restoring backups

Every run that replaces something leaves a timestamped directory:

```sh
ls -d ~/.config-backup-*
# restore one file:
cp ~/.config-backup-20260904-180000/.config/waybar/style.css ~/.config/waybar/style.css
# restore everything from a run:
cp -r ~/.config-backup-20260904-180000/.config/. ~/.config/
hyprctl reload; pkill waybar; waybar &
# or simply:
./emergency-restore.sh
```

Symlinks can be removed with plain `rm` — your backups are real files,
so deleting a link never deletes the backup.
