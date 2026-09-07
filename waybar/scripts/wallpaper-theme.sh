#!/usr/bin/env bash
# Recolor Waybar from a wallpaper, then ask Waybar to reload its animated CSS.
# Uses Matugen when available; otherwise derives a compact dark palette with
# Python + Pillow. Usage: wallpaper-theme.sh /path/to/wallpaper
set -euo pipefail

IMAGE="${1:-}"
if [[ -z "$IMAGE" || ! -f "$IMAGE" ]]; then
    echo "usage: wallpaper-theme.sh /path/to/wallpaper" >&2
    exit 2
fi

# Matugen remains the preferred full-desktop theming path. Its configured
# Waybar post-hook reloads the bar after atomically regenerating matugen.css.
if command -v matugen >/dev/null 2>&1; then
    matugen image "$IMAGE"
    exit 0
fi

if ! command -v python3 >/dev/null 2>&1 \
    || ! python3 -c 'from PIL import Image' >/dev/null 2>&1; then
    echo "wallpaper-theme.sh: install python-pillow or matugen for wallpaper colors" >&2
    exit 1
fi

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
OUTPUT="$CONFIG_HOME/waybar/matugen.css"
mkdir -p "${OUTPUT%/*}"
TMP="$(mktemp "$OUTPUT.tmp.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

python3 - "$IMAGE" "$TMP" <<'PY'
import colorsys
import sys
from pathlib import Path

from PIL import Image

source, destination = Path(sys.argv[1]), Path(sys.argv[2])
with Image.open(source) as opened:
    image = opened.convert("RGB")
image.thumbnail((192, 192), Image.Resampling.LANCZOS)

# Quantization ignores one-off pixels and gives stable colors for photographs.
quantized = image.quantize(colors=24, method=Image.Quantize.MEDIANCUT)
palette = quantized.getpalette() or []
colors = quantized.getcolors() or []

candidates = []
for count, index in colors:
    offset = index * 3
    red, green, blue = (channel / 255 for channel in palette[offset:offset + 3])
    hue, saturation, value = colorsys.rgb_to_hsv(red, green, blue)
    if 0.16 <= value <= 0.96:
        # Prefer frequent, colorful mid-bright tones instead of tiny highlights.
        score = count * (0.30 + saturation * 1.70) * (1.15 - abs(value - 0.66))
        candidates.append((score, hue, saturation, value))

if candidates:
    _, hue, saturation, value = max(candidates)
else:
    red, green, blue = (sum(channel) / (255 * len(image.getdata())) for channel in zip(*image.getdata()))
    hue, saturation, value = colorsys.rgb_to_hsv(red, green, blue)

# Keep the accent readable while preserving the wallpaper's hue.
if saturation < 0.10:
    saturation = 0.18
accent = colorsys.hsv_to_rgb(hue, min(0.88, max(0.52, saturation * 1.18)), min(0.90, max(0.72, value * 1.08)))
surface = colorsys.hsv_to_rgb(hue, min(0.22, max(0.07, saturation * 0.24)), 0.095)
surface_fg = colorsys.hsv_to_rgb(hue, min(0.08, saturation * 0.10), 0.95)
outline = colorsys.hsv_to_rgb(hue, min(0.42, max(0.14, saturation * 0.48)), 0.62)
container = colorsys.hsv_to_rgb(hue, min(0.48, max(0.18, saturation * 0.55)), 0.27)


def hex_color(rgb):
    return "#" + "".join(f"{round(channel * 255):02x}" for channel in rgb)


def relative_luminance(rgb):
    def linear(channel):
        return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4
    red, green, blue = map(linear, rgb)
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue

# Pick whichever foreground actually contrasts more against the accent (WCAG
# ratio), instead of guessing from a fixed luminance threshold.
dark_fg = (0x11 / 255, 0x13 / 255, 0x18 / 255)
light_fg = (0xF8 / 255, 0xF9 / 255, 1.0)
accent_luminance = relative_luminance(accent)
dark_contrast = (accent_luminance + 0.05) / (relative_luminance(dark_fg) + 0.05)
light_contrast = (relative_luminance(light_fg) + 0.05) / (accent_luminance + 0.05)
accent_fg = "#111318" if dark_contrast >= light_contrast else "#f8f9ff"
css = f"""/* Generated from {source.name} by wallpaper-theme.sh. */
@define-color accent {hex_color(accent)};
@define-color accent-fg {accent_fg};
@define-color accent-container {hex_color(container)};
@define-color surface {hex_color(surface)};
@define-color surface-fg {hex_color(surface_fg)};
@define-color outline {hex_color(outline)};
@define-color warning #f0c070;
@define-color critical #f09393;
"""
destination.write_text(css, encoding="utf-8")
PY

mv -f "$TMP" "$OUTPUT"
trap - EXIT
pkill -SIGUSR2 -x waybar 2>/dev/null || true
