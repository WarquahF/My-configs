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
│   ├── config.jsonc            # layout + modules
│   ├── style.css               # liquid-glass theme
│   └── scripts/
│       ├── power-menu.sh       # rofi power menu (wlogout fallback)
│       ├── wifi-menu.sh        # rofi Wi-Fi menu (see below)
│       ├── bluetooth-menu.sh   # rofi Bluetooth menu
│       ├── screenshot-menu.sh  # rofi screenshots (fullscreen/region/window)
│       ├── screenrecord-menu.sh # rofi screen recorder (fullscreen/region/stop)
│       └── battery-info.sh     # battery details popup (see below)
├── hypr/
│   ├── README.md
│   ├── config/
│   │   ├── waybar.lua          # blur layer rules for waybar/rofi/wlogout
│   │   ├── capture.lua         # volume key binds (F2/F3 + XF86Audio*)
│   │   └── session.lua         # wlogout/lock/power keybinds
│   └── scripts/cursor-wiggle.py # shake-to-find-cursor daemon
├── wlogout/                    # overlay power menu (layout, style, icons)
├── kitty/kitty.conf            # standalone, no theme includes
├── btop/btop.conf              # minimal overrides, built-in theme
├── mako/config                 # notifications: 7s timeout, critical persists
├── rofi/
│   ├── wallpaper-picker.sh     # visual wallpaper browser (see below)
│   ├── wallpaper.rasi          # filmstrip theme (picker only)
│   └── wallpaper-menu.rasi     # category menu theme (picker only)
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
6. Adds `require("config.waybar")`, `require("config.capture")` and
   `require("config.session")` to `hyprland.lua` (backed up first) and
   verifies the existing `hl.exec_cmd("waybar")` autostart line.

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
    region (`slurp`), active window, 3s delay. Saves to
    `~/Pictures/Screenshots/`, copies to clipboard, opens
    `swappy`/`satty` if installed.
  - Screen recorder; **click** opens a rofi menu: fullscreen,
    region, stop. Saves `.mp4` to `~/Videos/Recordings/`
    (needs `wf-recorder`, red pill in bar while recording).
  - Power button; **click** opens the `wlogout` frosted overlay
    (lock/logout/suspend/reboot/shutdown), falling back to the rofi
    power menu when `wlogout` is missing.
- Subtle 0.2s transitions on hover/state changes; compact sizing
  tuned for 1080p @ 1.5x.

## Wallpapers (rofi picker + awww)

- Press **Super+Shift+W** to open the visual browser: pick a category
  (detected from your folder names), then scroll the thumbnail filmstrip.
  **Enter** applies instantly, **Esc** cancels. Type to filter anytime.
- The current wallpaper is marked (●) and pre-selected on open.
  The category menu also offers **Random wallpaper**.
- Applies via `awww` with a `center` grow transition (~0.9s, 60fps —
  no fade). Library: `~/Pictures/Wallpapers` by default; override with
  `$WALLPAPER_DIR` or a path in `~/.config/my-local-configs/wallpaper-dir`
  (static jpg/jpeg/png/webp/bmp; GIF/video/animated-webp excluded).
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
- Fast lock: **Super+L** (`hyprlock`, falls back to `loginctl lock-session`).
- Direct actions (no menu): **Super+Alt+L** lock · **Super+Alt+E** logout ·
  **Super+Alt+S** suspend · **Super+Alt+R** reboot · **Super+Alt+P** shutdown.
- Hibernate is intentionally omitted: this machine only has zram swap.
- Keybinds live in `hypr/config/session.lua`; `binds.lua` is untouched.

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
