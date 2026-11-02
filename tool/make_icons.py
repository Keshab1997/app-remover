#!/usr/bin/env python3
"""Generate every brand asset for Goodbye Apps from one geometric source.

docs/01 asks for a flat two-colour glyph — a slightly tilted app tile with an
arrow leaving to the right — on solid #3D5AFE. No gradient (it turns to mud at
Play's small sizes), no lettering (illegible in a 48px launcher tile), and no
resemblance to any other uninstaller.

    python3 tool/make_icons.py            # write every asset
    python3 tool/make_icons.py --check     # report sizes without writing

The geometry lives in `glyph()` only: the SVG master and every PNG are drawn
from it, so the two can never drift apart.

    assets/branding/icon.svg, icon.png, icon_fg.png, icon_mono.png
    assets/branding/feature-graphic.png
    android/.../res/mipmap-*/ic_launcher{,_round}.png        (legacy, API < 26)
    android/.../res/drawable-*/ic_launcher_foreground.png     (adaptive layers)
    android/.../res/mipmap-anydpi-v26/ic_launcher{,_round}.xml
    android/.../res/values/colors.xml
    web/icons/*, web/favicon.png, web/index.html, web/manifest.json
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android/app/src/main/res"
BRANDING = ROOT / "assets/branding"

BLUE = (0x3D, 0x5A, 0xFE, 255)  # theme seed, lib/main.dart
DARK = (0x1A, 0x23, 0x7E, 255)  # docs/01 brand table
ACCENT = (0x00, 0xE5, 0xA0, 255)
WHITE = (255, 255, 255, 255)
TRANSPARENT = (0, 0, 0, 0)

# Legacy launcher icons (docs/01 §2) and the adaptive foreground layers, whose
# canvas is 108dp with a 72dp safe zone: the glyph fills about 62%.
LEGACY_SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
FOREGROUND_SIZES = {k: round(v * 108 / 48) for k, v in LEGACY_SIZES.items()}
GLYPH_RATIO = 0.62
SS = 4  # supersample factor, then LANCZOS down for clean edges


def glyph(box: float) -> dict:
    """The mark's geometry in a square canvas of `box` px — one source of truth.

    A filled app tile, tilted 8° for motion, with a horizontal arrow cut out
    of it. The cut runs past the tile's right edge, so the arrow disappears
    into the background: that is the whole "goodbye" idea, and it survives
    being drawn 24 px wide. It is deliberately not an outline — a stroked tile
    plus an overlapping arrow turned to mud below 48 px.
    """
    g = box * GLYPH_RATIO
    cx, cy = box / 2, box / 2
    # The tile is deliberately smaller than the glyph box: blue air around it
    # is what keeps the cut readable when the whole mark is 32 px wide.
    side = g * 0.86
    return {
        "tile_cx": cx - g * 0.02,
        "tile_cy": cy,
        "tile_side": side,
        "tile_radius": side * 0.26,
        "tilt": 8.0,
        # Arrow, in the same coordinate space, horizontal by design. A wide
        # head matters more than a tidy one: at 32 px a 1.1x flare is invisible.
        "tail_x": cx - side * 0.20,
        "tip_x": cx + side * 0.74,
        "shaft": side * 0.24,
        "head_base": cx + side * 0.22,
        "head_half": side * 0.40,
        "cy": cy,
    }


def _tile_mask(size: int, geo: dict) -> Image.Image:
    """Greedy L-mode mask of the tilted tile."""
    W = size * SS
    tile = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(tile)
    side = geo["tile_side"] * SS
    cx, cy = geo["tile_cx"] * SS, geo["tile_cy"] * SS
    d.rounded_rectangle(
        [cx - side / 2, cy - side / 2, cx + side / 2, cy + side / 2],
        radius=geo["tile_radius"] * SS,
        fill=255,
    )
    return tile.rotate(geo["tilt"], resample=Image.BICUBIC, center=(cx, cy))


def _arrow_mask(size: int, geo: dict) -> Image.Image:
    W = size * SS
    hole = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(hole)
    s = SS
    shaft = geo["shaft"] * s
    tail, tip = geo["tail_x"] * s, geo["tip_x"] * s
    base, cy = geo["head_base"] * s, geo["cy"] * s
    head = geo["head_half"] * s
    d.rectangle([tail, cy - shaft / 2, base, cy + shaft / 2], fill=255)
    d.polygon([(tip, cy), (base, cy - head), (base, cy + head)], fill=255)
    r = shaft / 2
    d.ellipse([tail - r, cy - r, tail + r, cy + r], fill=255)
    return hole


def glyph_mask(size: int) -> Image.Image:
    """White where the mark is, at `size` px canvas, supersampled."""
    geo = glyph(size)
    return ImageChops.subtract(_tile_mask(size, geo), _arrow_mask(size, geo))


def render(box: int, color, background=None) -> Image.Image:
    """The mark (and optionally the brand tile behind it) as an RGBA image."""
    img = Image.new("RGBA", (box * SS, box * SS), TRANSPARENT)
    if background == "tile":
        # Legacy launcher icon: the blue rounded square carries the mark.
        d = ImageDraw.Draw(img)
        side = box * SS
        inset = side * 0.03
        d.rounded_rectangle(
            [inset, inset, side - inset, side - inset],
            radius=side * 0.235,
            fill=BLUE,
        )
    mask = glyph_mask(box)
    solid = Image.new("RGBA", mask.size, color)
    img.paste(solid, (0, 0), mask)
    return img.resize((box, box), Image.LANCZOS)


def svg_master(path: Path) -> None:
    """Vector source for Figma, built from the same numbers via an SVG mask."""
    box = 1024
    geo = glyph(box)
    side, rad = geo["tile_side"], geo["tile_radius"]
    tcx, tcy = geo["tile_cx"], geo["tile_cy"]
    x0, y0 = tcx - side / 2, tcy - side / 2
    shaft = geo["shaft"]
    arrow = (
        f"M {geo['tail_x']:.1f} {tcy - shaft / 2:.1f} "
        f"L {geo['head_base']:.1f} {tcy - shaft / 2:.1f} "
        f"L {geo['head_base']:.1f} {tcy - geo['head_half']:.1f} "
        f"L {geo['tip_x']:.1f} {tcy:.1f} "
        f"L {geo['head_base']:.1f} {tcy + geo['head_half']:.1f} "
        f"L {geo['head_base']:.1f} {tcy + shaft / 2:.1f} "
        f"L {geo['tail_x']:.1f} {tcy + shaft / 2:.1f} Z"
    )
    path.write_text(
        f"""<svg xmlns="http://www.w3.org/2000/svg" width="{box}" height="{box}"
     viewBox="0 0 {box} {box}" role="img" aria-label="Goodbye Apps">
  <!-- Generated by tool/make_icons.py — change the script, not this file. -->
  <defs>
    <mask id="arrow-cut" maskUnits="userSpaceOnUse" width="{box}" height="{box}">
      <rect x="{x0:.1f}" y="{y0:.1f}" width="{side:.1f}" height="{side:.1f}"
            rx="{rad:.1f}" fill="#fff"
            transform="rotate({geo['tilt']:.1f} {tcx:.1f} {tcy:.1f})"/>
      <path d="{arrow}" fill="#000"/>
      <circle cx="{geo['tail_x']:.1f}" cy="{tcy:.1f}" r="{shaft / 2:.1f}" fill="#000"/>
    </mask>
  </defs>
  <rect width="{box}" height="{box}" rx="{box * 0.235:.1f}" fill="#3D5AFE"/>
  <rect width="{box}" height="{box}" fill="#FFFFFF" mask="url(#arrow-cut)"/>
</svg>
"""
    )


def _fit(draw: ImageDraw.ImageDraw, text: str, px: int, max_w: float, font_name: str) -> int:
    """Largest font size <= px that keeps `text` inside max_w."""
    # Measured on the supersampled canvas, so the width comes back in canvas px.
    while px > 20 and draw.textlength(text, font=ImageFont.truetype(font_name, px * SS)) / SS > max_w:
        px -= 2
    return px


def feature_graphic(path: Path) -> None:
    """1024×500, Play's hero banner.

    docs/01 §4 forbids anything cropping outside the frame, so every line is
    measured and shrunk to fit its column rather than trusting a hand-picked
    point size.
    """
    w, h = 1024, 500
    img = Image.new("RGBA", (w * SS, h * SS), BLUE)
    mark = render(500, WHITE)
    img.alpha_composite(
        mark.resize((int(300 * SS), int(300 * SS)), Image.LANCZOS), (int(40 * SS), int(100 * SS))
    )

    d = ImageDraw.Draw(img)
    left = 336
    right = w - 48
    max_w = right - left
    bold, regular = "DejaVuSans-Bold.ttf", "DejaVuSans.ttf"

    lines = [
        ("Goodbye Apps", bold, 92, WHITE),
        ("Uninstall apps in two taps.", regular, 42, ACCENT),
        ("Sizes, dates and system apps —", regular, 30, (255, 255, 255, 215)),
        ("all visible before you delete.", regular, 30, (255, 255, 255, 215)),
    ]
    y = 96
    placed = []
    for text, name, px, colour in lines:
        size = _fit(d, text, px, max_w, name)
        font = ImageFont.truetype(name, size * SS)
        d.text((left * SS, y * SS), text, font=font, fill=colour)
        box = d.textbbox((left * SS, y * SS), text, font=font)
        placed.append((text, size, [v / SS for v in box]))
        step = size + (26 if name == bold else 12)
        y += step
        # the tagline block sits tighter under the title
        if text == "Goodbye Apps":
            y += 12

    for text, size, (x0, top, x1, bottom) in placed:
        assert x1 <= right + 1, f"feature graphic: {text!r} runs to {x1:.0f} > {right}"
        assert bottom <= h - 12, f"feature graphic: {text!r} bottom {bottom:.0f}"
        assert size >= 30, f"feature graphic: {text!r} shrank to {size}px"
    print("feature graphic lines:", [(t[:22], sz) for t, sz, _ in placed])

    img.resize((w, h), Image.LANCZOS).convert("RGB").save(path)


def adaptive_xml(path: Path) -> None:
    path.write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/make_icons.py. The monochrome layer is the same white
     mark: Android 13+ tints it for themed icons, so it must stay flat. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
""")


def web_shell(colors: dict) -> None:
    """Keep the PWA shell on the same brand as the app (docs/01 table)."""
    web = ROOT / "web"
    for name, size in (
        ("icons/Icon-192.png", 192),
        ("icons/Icon-512.png", 512),
        ("icons/Icon-maskable-192.png", 192),
        ("icons/Icon-maskable-512.png", 512),
        ("favicon.png", 64),
    ):
        flat = render(size, WHITE, background="tile").convert("RGB")
        flat.save(web / name)
    manifest = (web / "manifest.json").read_text()
    for key in ("background_color", "theme_color"):
        for old in ("#0175C2",):
            manifest = manifest.replace(old, colors[key])
    (web / "manifest.json").write_text(manifest)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true", help="report, do not write")
    args = ap.parse_args()

    BRANDING.mkdir(parents=True, exist_ok=True)
    sizes = []

    full = render(1024, WHITE, background="tile")
    fg = render(1024, WHITE)
    mono = render(1024, WHITE)
    play = full.resize((512, 512), Image.LANCZOS).convert("RGB")  # alpha-free

    if not args.check:
        svg_master(BRANDING / "icon.svg")
        full.save(BRANDING / "icon.png")
        fg.save(BRANDING / "icon_fg.png")
        mono.save(BRANDING / "icon_mono.png")
        play.save(BRANDING / "play-icon-512.png")
        feature_graphic(BRANDING / "feature-graphic.png")

        (RES / "mipmap-anydpi-v26").mkdir(parents=True, exist_ok=True)
        for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
            adaptive_xml(RES / "mipmap-anydpi-v26" / name)
        (RES / "values" / "colors.xml").write_text(
            """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- docs/01 brand table; keep in step with the seed in lib/main.dart. -->
    <color name="ic_launcher_background">#3D5AFE</color>
</resources>
""")
        for bucket, size in LEGACY_SIZES.items():
            out = render(size, WHITE, background="tile")
            for stem in ("ic_launcher", "ic_launcher_round"):
                out.save(RES / f"mipmap-{bucket}" / f"{stem}.png")
        for bucket, size in FOREGROUND_SIZES.items():
            d = RES / f"drawable-{bucket}"
            d.mkdir(parents=True, exist_ok=True)
            render(size, WHITE).save(d / "ic_launcher_foreground.png")
        web_shell({"background_color": "#3D5AFE", "theme_color": "#3D5AFE"})

    written = sorted(
        x
        for x in [
            *BRANDING.glob("*"),
            *RES.glob("mipmap-*/*.png"),
            *RES.glob("drawable-*/*.png"),
        ]
        if x.suffix == ".png"
    ) + sorted([*RES.glob("mipmap-anydpi-v26/*.xml"), *BRANDING.glob("*.svg")])
    for path in written:
        if path.suffix == ".png":
            with Image.open(path) as im:
                sizes.append(
                    f"{str(path.relative_to(ROOT)):54} {im.size[0]}x{im.size[1]} {im.mode}"
                )
        else:
            sizes.append(f"{str(path.relative_to(ROOT)):54} {path.stat().st_size} bytes")
    print("\n".join(sizes))
    return 0


if __name__ == "__main__":
    sys.exit(main())
