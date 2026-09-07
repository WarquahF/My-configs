# config-files — neat, on-demand helpers (zero idle cost)

This folder holds small reference configs that are NOT symlinked by
`install.sh` and never run in the background:

- Nothing here starts daemons or slows down the PC.
- `install.sh` links: waybar (+ sway variant), hypr/config, kitty, btop,
  mako, rofi, wlogout, sway, swaylock, matugen. Fingerprint + emergency
  helpers stay manual. `sddm/` stays reference-only (`/etc` untouched,
  greetd stays enabled) — see `../sddm/README.md`.

See `../emergency-restore.sh` for one-command rollback and
`../fingerprint/` for manual fingerprint setup.
