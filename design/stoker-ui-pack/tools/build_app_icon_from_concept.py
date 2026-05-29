#!/usr/bin/env python3
"""Build the Stoker app icon from the AI concept raster.

Large slots (128px+) come from the AI concept image (the look the user approved),
resampled to 1024 and masked to the pack's squircle so corners are transparent.
Small slots (16/32/64) use the hand-authored simplified SVGs so they stay legible.
Deterministic + re-runnable. Requires Pillow + rsvg-convert + iconutil.
"""
from __future__ import annotations
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
CONCEPT = ROOT / "assets/generated/stoker-imagegen-app-icon-concept.png"
LOGO = ROOT / "assets/logo"
OUT = ROOT / "assets/png/app-icon"
ICONSET = OUT / "AppIcon.iconset"
PREVIEW = Path("/tmp/stoker_icon2")


def squircle_mask(size: int) -> Image.Image:
    """Rounded-rect mask matching stoker-app-icon-source.svg (rect 46,46 -> 978,978, r218 on 1024)."""
    s = size / 1024
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle((46 * s, 46 * s, 978 * s, 978 * s), radius=int(218 * s), fill=255)
    return m


def render_svg(svg: Path, px: int) -> Image.Image:
    out = PREVIEW / f"_svg_{svg.stem}_{px}.png"
    subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), "-o", str(out), str(svg)], check=True)
    return Image.open(out).convert("RGBA")


def main() -> None:
    PREVIEW.mkdir(parents=True, exist_ok=True)
    ICONSET.mkdir(parents=True, exist_ok=True)

    # AI master @1024 — crop to the concept's content bounds (measured ~75..1179 in the
    # 1254 frame), scale the card to fill the icon tile, then keep only (card alpha n squircle)
    # so the card reaches the tile edge with transparent corners and no leftover dark margin.
    src = Image.open(CONCEPT).convert("RGBA")
    crop = src.crop((75, 75, 1179, 1179))           # centered square containing all content
    side, off = 920, 52                             # ticks land at inset ~52 (mask inset 46 -> not clipped)
    card = crop.resize((side, side), Image.Resampling.LANCZOS)
    ai = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    ai.alpha_composite(card, (off, off))
    _, _, _, card_alpha = ai.split()
    ai.putalpha(Image.composite(card_alpha, Image.new("L", (1024, 1024), 0), squircle_mask(1024)))
    ai.save(OUT / "stoker-app-icon-1024.png")
    ai.save(PREVIEW / "master-1024.png")

    big = lambda px: ai.resize((px, px), Image.Resampling.LANCZOS)
    svg16, svg32, svg64 = (LOGO / "stoker-app-icon-16.svg",
                           LOGO / "stoker-app-icon-32.svg",
                           LOGO / "stoker-app-icon-64.svg")

    slots = {
        "icon_16x16.png": render_svg(svg16, 16),
        "icon_16x16@2x.png": render_svg(svg32, 32),
        "icon_32x32.png": render_svg(svg32, 32),
        "icon_32x32@2x.png": render_svg(svg64, 64),
        "icon_128x128.png": big(128),
        "icon_128x128@2x.png": big(256),
        "icon_256x256.png": big(256),
        "icon_256x256@2x.png": big(512),
        "icon_512x512.png": big(512),
        "icon_512x512@2x.png": big(1024),
    }
    for name, img in slots.items():
        img.save(ICONSET / name)
        # preview copies for the small + a mid size
        if name in ("icon_16x16.png", "icon_32x32.png", "icon_32x32@2x.png", "icon_128x128.png"):
            img.save(PREVIEW / name)

    subprocess.run(["iconutil", "-c", "icns", str(ICONSET), "-o", str(OUT / "Stoker.icns")], check=True)
    print(f"Built icon from concept -> {OUT/'Stoker.icns'}")


if __name__ == "__main__":
    main()
