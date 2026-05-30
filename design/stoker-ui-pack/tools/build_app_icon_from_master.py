#!/usr/bin/env python3
"""Build the Stoker app icon from the vector master (stoker-app-icon-master.pdf).

The master is the designer's 1024x1024 vector of the ember-aperture "Forge" mark. We:
  1. rasterize it with sips (CoreGraphics — no external deps, ships on every Mac),
  2. flood-fill the flat dark background inward from the four corners so the squircle
     corners become transparent. This follows the card's OWN rounded edge, so there is
     no hardcoded inset/radius to keep in sync with the artwork,
  3. downscale the 1024 master to every macOS .iconset slot, and
  4. assemble Stoker.icns via iconutil.

Deterministic + re-runnable. Requires sips + Pillow + iconutil (all present on macOS).
If Pillow is missing the caller (build-app.sh) falls back to the committed Stoker.icns.
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "assets/logo/stoker-app-icon-master.pdf"
OUT = ROOT / "assets/png/app-icon"
ICONSET = OUT / "AppIcon.iconset"

# The master renders with an opaque, perfectly flat dark background (sampled (9,12,12)); we
# flood-fill it from the four corners, seeding by corner *coordinate*, not by color.
SENTINEL = (255, 0, 255)  # magenta — absent from the ember/graphite/sage art
FLOOD_THRESH = 14         # tuned: carves the corners cleanly without eating the card body
ALPHA_CUT = 10

# macOS .iconset slots: (filename, pixel size). Apple assembles these into the .icns.
SLOTS = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]


def rasterize_master(px: int) -> Image.Image:
    """Rasterize the PDF master to a px*px opaque PNG via sips, return it as RGB.

    Renders into a private temp file (not the output dir) and always cleans it up, so a
    failed sips run can't leave a stray raster inside the iconset directory.
    """
    fd, tmp_path = tempfile.mkstemp(prefix="stoker-icon-", suffix=".png")
    os.close(fd)
    tmp = Path(tmp_path)
    try:
        subprocess.run(
            ["sips", "-s", "format", "png", "-z", str(px), str(px), str(MASTER), "--out", str(tmp)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        img = Image.open(tmp).convert("RGB")
        img.load()
        return img
    finally:
        tmp.unlink(missing_ok=True)


def carve_corners(rgb: Image.Image) -> Image.Image:
    """Flood-fill the flat background from the 4 corners and turn it transparent."""
    w, h = rgb.size
    work = rgb.copy()
    for corner in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        ImageDraw.floodfill(work, corner, SENTINEL, thresh=FLOOD_THRESH)
    diff = ImageChops.difference(work, Image.new("RGB", (w, h), SENTINEL)).convert("L")
    mask = diff.point(lambda v: 255 if v > ALPHA_CUT else 0)
    out = rgb.convert("RGBA")
    out.putalpha(mask)
    return out


def main() -> None:
    if not MASTER.exists():
        sys.exit(f"vector master not found: {MASTER}")
    ICONSET.mkdir(parents=True, exist_ok=True)

    master = carve_corners(rasterize_master(1024))
    master.save(OUT / "stoker-app-icon-1024.png")

    for name, px in SLOTS:
        master.resize((px, px), Image.Resampling.LANCZOS).save(ICONSET / name)

    subprocess.run(
        ["iconutil", "-c", "icns", str(ICONSET), "-o", str(OUT / "Stoker.icns")],
        check=True,
    )
    print(f"Built app icon from master -> {OUT / 'Stoker.icns'}")


if __name__ == "__main__":
    main()
