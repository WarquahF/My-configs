#!/usr/bin/env python3
"""cursor-wiggle.py — macOS-style shake-to-find-cursor for Hyprland.

Watches cursor velocity over Hyprland's command socket. A fast
back-and-forth wiggle temporarily doubles the cursor size; it shrinks
back once the mouse calms down. Cooldown prevents flapping.

No third-party dependencies (stdlib only). Cursor theme/size come from
XCURSOR_THEME / XCURSOR_SIZE at runtime — never hardcoded.
Single-instance via pidfile; events appended to ~/.cache/cursor-wiggle.log.
"""
import collections
import math
import os
import socket
import subprocess
import sys
import time

POLL_INTERVAL = 0.025   # seconds between position samples
WINDOW = 0.35           # seconds of history used for wiggle detection
MIN_PATH = 700.0        # px travelled inside WINDOW to qualify
MIN_LEG = 100.0         # px per direction leg (filters out jitter)
MIN_REVERSALS = 2       # direction flips required (filters fast flings)
CALM_SPEED = 150.0      # px/s below which the cursor counts as calm
CALM_TIME = 0.9         # calm seconds before shrinking back
COOLDOWN = 1.2          # seconds after a restore before retriggering


def sock_path():
    rt = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    return os.path.join(rt, "hypr", sig, ".socket.sock")


def cursor_pos(path):
    """Return (x, y) or None. One short-lived connection per poll."""
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(1.0)
            s.connect(path)
            s.sendall(b"cursorpos")
            data = s.recv(64).decode(errors="replace")
        x, y = data.replace(",", " ").split()[:2]
        return float(x), float(y)
    except Exception:
        return None


def is_wiggle(samples):
    """samples: deque of (t, x, y), ascending time. True on wiggle."""
    if len(samples) < 3:
        return False
    # Only the trailing WINDOW matters; older history must not veto.
    cutoff = samples[-1][0] - WINDOW
    pts = [p for p in samples if p[0] >= cutoff]
    if len(pts) < 3:
        return False
    path = 0.0
    reversals = 0
    leg = 0.0
    last_sign = 0
    prev = pts[0]
    for _, x, y in pts[1:]:
        dx = x - prev[0]
        path += math.hypot(dx, y - prev[1])
        prev = (x, y)
        if abs(dx) < 2.0:
            continue
        sign = 1 if dx > 0 else -1
        if sign != last_sign:
            if leg >= MIN_LEG and last_sign != 0:
                reversals += 1
            leg = 0.0
            last_sign = sign
        leg += abs(dx)
    span = pts[-1][0] - pts[0][0]
    return span <= WINDOW and path >= MIN_PATH and reversals >= MIN_REVERSALS


def speed(samples, window):
    """px/s over the trailing `window` seconds."""
    if len(samples) < 2:
        return 0.0
    now = samples[-1][0]
    pts = [(t, x, y) for t, x, y in samples if now - t <= window]
    if len(pts) < 2:
        return 0.0
    dist = sum(math.hypot(b[1] - a[1], b[2] - a[2]) for a, b in zip(pts, pts[1:]))
    span = pts[-1][0] - pts[0][0]
    return dist / span if span > 0 else 0.0


def set_cursor(theme, size):
    subprocess.run(["hyprctl", "setcursor", theme, str(size)],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def log(msg):
    try:
        line = f"{time.strftime('%H:%M:%S')} {msg}\n"
        path = os.path.expanduser("~/.cache/cursor-wiggle.log")
        if os.path.exists(path) and os.path.getsize(path) > 100 * 1024:
            os.remove(path)
        with open(path, "a") as f:
            f.write(line)
    except OSError:
        pass


def single_instance():
    rt = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    pidfile = os.path.join(rt, "cursor-wiggle.pid")
    try:
        with open(pidfile) as f:
            old = int(f.read().strip())
        os.kill(old, 0)
        return False  # already running
    except (OSError, ValueError):
        pass
    with open(pidfile, "w") as f:
        f.write(str(os.getpid()))
    return True


def main():
    if not single_instance():
        sys.exit(0)
    theme = os.environ.get("XCURSOR_THEME") or "Bibata-Modern-Ice"
    try:
        size = int(os.environ.get("XCURSOR_SIZE") or 24)
    except ValueError:
        size = 24
    big = size * 2

    path = sock_path()
    samples = collections.deque()
    enlarged = False
    calm_since = 0.0
    cooling_until = 0.0
    log(f"watching (theme={theme} size={size})")

    while True:
        pos = cursor_pos(path)
        now = time.monotonic()
        if pos is None:
            time.sleep(1.0)
            continue
        samples.append((now, pos[0], pos[1]))
        while samples and now - samples[0][0] > max(WINDOW, CALM_TIME + 0.2):
            samples.popleft()

        if not enlarged:
            if now >= cooling_until and is_wiggle(samples):
                set_cursor(theme, big)
                enlarged = True
                calm_since = now
                log("TRIGGER: cursor enlarged")
        else:
            if speed(samples, 0.5) < CALM_SPEED:
                if now - calm_since >= CALM_TIME:
                    set_cursor(theme, size)
                    enlarged = False
                    cooling_until = now + COOLDOWN
                    log("restored: cursor normal size")
            else:
                calm_since = now
        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()
