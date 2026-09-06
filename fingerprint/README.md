# Fingerprint (Goodix 27c6:5503) — manual setup, NOT in install.sh

Detected on this machine:

```
Bus 003 Device 003: ID 27c6:5503 Shenzhen Goodix Technology Co.,Ltd. Goodix FingerPrint Device
```

This folder is versioned for reference, but `install.sh` deliberately
ignores it — fingerprint touches `/etc/pam.d` + hardware enrollment and
must never auto-run on someone else's machine.

## Install (manual, one time)

```sh
sudo pacman -S --needed fprintd libfprint
fprintd-enroll "$USER"
```

> `No devices available` on 27c6:5503 is expected with stock libfprint —
> mainline has no 5503 driver. Use the community driver below; do NOT
> enable PAM until `fprintd-list` actually sees the device.

## Enable for login / sudo (manual, with backup)

```sh
sudo cp /etc/pam.d/login /etc/pam.d/login.bak-$(date +%Y%m%d)
sudo cp /etc/pam.d/sudo /etc/pam.d/sudo.bak-$(date +%Y%m%d)
# Add as the FIRST auth line (sufficient = fingerprint OR password):
#   auth sufficient pam_fprintd.so
sudoedit /etc/pam.d/login
sudoedit /etc/pam.d/sudo
```

See `setup-fingerprint.sh --help` for guided steps. Nothing here runs
automatically.

## Goodix 27c6:5503 needs a community driver (stock = No devices available)

- Driver: `https://github.com/Duro02/goodix-5503-linux` (daily-use, LGPL).
- Only for firmware `GF3258_RTSEC_APP_10063` + IAP `MILAN_RTSEC_IAP_10027`.
- One-time PSK write breaks Windows fingerprint pairing (asks confirmation).
- Expect ~50% first-press retry; retry almost always passes.

```sh
sudo pacman -S --needed base-devel git meson ninja gobject-introspection cairo opencv libgudev libgusb openssl pixman python python-pip curl innoextract fprintd
git clone https://github.com/Duro02/goodix-5503-linux ~/goodix-5503-linux
cd ~/goodix-5503-linux
bash packaging/arch/build-package.sh
sudo pacman -U --noconfirm --overwrite '*' .tools/packages/libfprint-goodix5503-*.pkg.tar.zst
python -m venv .venv
.venv/bin/pip install -e '.[whitebox]'
.venv/bin/goodix-5503-setup
fprintd-list "$USER"
sudo fprintd-enroll "$USER"
```
