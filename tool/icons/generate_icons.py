#!/usr/bin/env python3
"""Draws the Tessera app icon and fans it out to every platform's slots.

The mark is three tesserae — rhombus tiles — meeting at a point, which is both a
rhombille tessellation (the mosaic the game is named for) and an isometric cube.
Thin grout gaps keep it reading as three separate tiles rather than one solid
shape, which is what survives the 48 px launcher grid.

Run it from the repository root:

    python tool/icons/generate_icons.py

Everything it writes is committed, so CI never needs Python or Pillow. Re-run it
only when the artwork changes, then commit the diff.
"""

from __future__ import annotations

import math
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

# --- brand ------------------------------------------------------------------
# Lifted from the Classic Arcade skin so the icon and the game agree: the near
# black field is that skin's background, and the three tile colours are its
# teal, purple and yellow kinds.
FIELD_DARK = (0x07, 0x09, 0x12)
FIELD_LIGHT = (0x14, 0x1A, 0x33)
GLOW = (0x21, 0xE6, 0xC1)

FACE_TOP = ((0xFF, 0xD2, 0x3F), (0xFF, 0xEB, 0xA3))  # base, highlight
FACE_LEFT = ((0x18, 0xB8, 0x9B), (0x21, 0xE6, 0xC1))
FACE_RIGHT = ((0x8A, 0x3D, 0xF0), (0xC2, 0x92, 0xFF))

SS = 4  # supersample factor; everything is drawn big and shrunk with LANCZOS

# Both are fractions of the canvas. Tuned against a 48 px launcher render: any
# looser and the three rhombi stop resolving into a cube.
GROUT = 0.018  # gap cut between neighbouring tiles
DRIFT = 0.012  # how far each tile slides off the shared centre


def lerp(a: tuple[int, ...], b: tuple[int, ...], t: float) -> tuple[int, ...]:
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def hexagon(cx: float, cy: float, r: float) -> list[tuple[float, float]]:
    """Pointy-top hexagon: the silhouette the three rhombi add up to."""
    return [
        (cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)))
        for a in (-90, -30, 30, 90, 150, 210)
    ]


def faces(cx: float, cy: float, r: float) -> list[list[tuple[float, float]]]:
    """The three rhombi, each sharing the hexagon's centre."""
    v = hexagon(cx, cy, r)
    c = (cx, cy)
    # v = [top, upper-right, lower-right, bottom, lower-left, upper-left]
    return [
        [v[0], v[1], c, v[5]],  # top face
        [v[5], c, v[3], v[4]],  # left face
        [v[1], v[2], v[3], c],  # right face
    ]


def shrink(poly: list[tuple[float, float]], inset: float) -> list[tuple[float, float]]:
    """Pull a polygon in towards its centroid — this is what cuts the grout."""
    n = len(poly)
    gx = sum(p[0] for p in poly) / n
    gy = sum(p[1] for p in poly) / n
    out = []
    for x, y in poly:
        d = math.hypot(x - gx, y - gy) or 1.0
        out.append((x - (x - gx) / d * inset, y - (y - gy) / d * inset))
    return out


def explode(poly, cx: float, cy: float, distance: float):
    """Slide a face away from the shared centre.

    Grout alone still reads as one bevelled cube. Drifting each rhombus outwards
    separates them into three tiles that happen to line up — which is the game —
    without losing the cube at launcher size.
    """
    n = len(poly)
    gx = sum(p[0] for p in poly) / n
    gy = sum(p[1] for p in poly) / n
    d = math.hypot(gx - cx, gy - cy) or 1.0
    ox, oy = (gx - cx) / d * distance, (gy - cy) / d * distance
    return [(x + ox, y + oy) for x, y in poly]


def fillet(poly: list[tuple[float, float]], radius: float, steps: int = 12):
    """Replace each corner with a quadratic bezier so the tiles read as cut
    stone rather than as vector shards at small sizes."""
    n = len(poly)
    out: list[tuple[float, float]] = []
    for i in range(n):
        prev, cur, nxt = poly[i - 1], poly[i], poly[(i + 1) % n]
        d_prev = math.hypot(cur[0] - prev[0], cur[1] - prev[1]) or 1.0
        d_next = math.hypot(nxt[0] - cur[0], nxt[1] - cur[1]) or 1.0
        r = min(radius, d_prev / 2, d_next / 2)
        a = (cur[0] + (prev[0] - cur[0]) / d_prev * r,
             cur[1] + (prev[1] - cur[1]) / d_prev * r)
        b = (cur[0] + (nxt[0] - cur[0]) / d_next * r,
             cur[1] + (nxt[1] - cur[1]) / d_next * r)
        for s in range(steps + 1):
            t = s / steps
            u = 1 - t
            out.append((
                u * u * a[0] + 2 * u * t * cur[0] + t * t * b[0],
                u * u * a[1] + 2 * u * t * cur[1] + t * t * b[1],
            ))
    return out


def gradient_fill(size: int, poly, top: tuple[int, int, int],
                  bottom: tuple[int, int, int]):
    """A vertical two-stop gradient clipped to `poly`, as an RGBA layer."""
    y0 = min(p[1] for p in poly)
    y1 = max(p[1] for p in poly)
    span = max(1.0, y1 - y0)

    # One column of colour spanning the polygon's own vertical extent, clamped
    # outside it, stretched across the canvas.
    column = Image.new("RGB", (1, size))
    px = column.load()
    for y in range(size):
        t = min(1.0, max(0.0, (y - y0) / span))
        px[0, y] = lerp(top, bottom, t)
    full = column.resize((size, size), Image.Resampling.BILINEAR)

    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).polygon(poly, fill=255)
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    layer.paste(full, (0, 0), mask)
    return layer


def backdrop(size: int) -> Image.Image:
    """Deep indigo field, a teal glow behind the mark, and a ghost rhombille
    tiling so the icon hints at the mosaic it sits in."""
    img = Image.new("RGB", (size, size), FIELD_DARK)

    # Diagonal lift from bottom-left to top-right.
    ramp = Image.new("RGB", (1, size))
    px = ramp.load()
    for y in range(size):
        px[0, y] = lerp(FIELD_LIGHT, FIELD_DARK, y / max(1, size - 1))
    img = ramp.resize((size, size), Image.Resampling.BILINEAR)

    # Ghost tessellation: the same three-rhombus cell, repeated, barely visible.
    ghost = Image.new("L", (size, size), 0)
    gd = ImageDraw.Draw(ghost)
    r = size * 0.085
    dx, dy = r * math.sqrt(3), r * 1.5
    row = 0
    y = -dy
    while y < size + dy:
        x = -dx + (dx / 2 if row % 2 else 0)
        while x < size + dx:
            for face in faces(x, y, r):
                gd.polygon(face, outline=255, width=max(1, int(size * 0.0022)))
            x += dx
        y += dy
        row += 1
    img.paste(lerp(FIELD_LIGHT, (255, 255, 255), 0.18),
              (0, 0), ghost.point(lambda v: int(v * 0.16)))

    # Radial glow centred on the mark.
    glow = Image.radial_gradient("L").resize((size, size), Image.Resampling.BILINEAR)
    glow = glow.point(lambda v: max(0, 150 - v))
    img.paste(GLOW, (0, 0), glow.point(lambda v: int(v * 0.42)))
    return img


def mark(size: int, scale: float) -> Image.Image:
    """The three tesserae, as a transparent RGBA layer."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cx = cy = size / 2
    r = size * scale
    grout = max(1.0, size * GROUT)
    drift = size * DRIFT
    corner = size * 0.022

    palette = (FACE_TOP, FACE_LEFT, FACE_RIGHT)
    for face, (base, hi) in zip(faces(cx, cy, r), palette):
        poly = fillet(shrink(explode(face, cx, cy, drift), grout), corner)
        # Top face is lit from above; the two side faces fall off downwards.
        layer.alpha_composite(gradient_fill(size, poly, hi, base))

    # A soft drop shadow under the whole mark, so it sits on the field.
    silhouette = Image.new("L", (size, size), 0)
    ImageDraw.Draw(silhouette).polygon(
        fillet(hexagon(cx, cy, r + drift), corner), fill=255
    )
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 130), (0, int(size * 0.018)), silhouette)
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.03))
    shadow.alpha_composite(layer)
    return shadow


def silhouette_mark(size: int, scale: float) -> Image.Image:
    """Flat white version for the Android 13+ themed (monochrome) layer."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx = cy = size / 2
    r = size * scale
    grout = max(1.0, size * GROUT)
    drift = size * DRIFT
    for face in faces(cx, cy, r):
        poly = fillet(shrink(explode(face, cx, cy, drift), grout), size * 0.022)
        d.polygon(poly, fill=(255, 255, 255, 255))
    return layer


def rounded_mask(size: int, radius_ratio: float) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=size * radius_ratio, fill=255
    )
    return mask


def render(size: int, *, shape: str = "rounded", scale: float = 0.30) -> Image.Image:
    """One icon at one size. `shape` is the field treatment."""
    big = size * SS
    if shape == "transparent":
        img = mark(big, scale)
    else:
        field = backdrop(big).convert("RGBA")
        field.alpha_composite(mark(big, scale))
        img = field
        if shape == "rounded":
            img.putalpha(rounded_mask(big, 0.225))
        elif shape == "circle":
            circle = Image.new("L", (big, big), 0)
            ImageDraw.Draw(circle).ellipse((0, 0, big - 1, big - 1), fill=255)
            img.putalpha(circle)
    return img.resize((size, size), Image.Resampling.LANCZOS)


def render_mono(size: int, scale: float) -> Image.Image:
    return silhouette_mark(size * SS, scale).resize(
        (size, size), Image.Resampling.LANCZOS
    )


def render_background(size: int) -> Image.Image:
    """The adaptive icon's background layer: field only, full bleed, no mark.

    Android crops this to whatever shape the launcher wants, so it must carry no
    detail near the edges — the gradient and the glow both centre safely.
    """
    return backdrop(size * SS).resize((size, size), Image.Resampling.LANCZOS)


def flatten(img: Image.Image) -> Image.Image:
    """iOS rejects icons with an alpha channel."""
    base = Image.new("RGB", img.size, FIELD_DARK)
    base.paste(img, (0, 0), img)
    return base


# --- output -----------------------------------------------------------------

ROOT = pathlib.Path(__file__).resolve().parents[2]

ANDROID_DENSITIES = {
    "mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0,
}

IOS_ICONS = {
    "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60, "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120, "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180, "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152, "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}


def write(img: Image.Image, rel: str) -> None:
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"  {rel}  {img.size[0]}x{img.size[1]}")


def main() -> int:
    print("master")
    master = render(1024, shape="rounded")
    write(master, "assets/branding/icon_master_1024.png")
    write(render(1024, shape="square"), "assets/branding/icon_master_square_1024.png")

    print("android — legacy mipmaps")
    for density, factor in ANDROID_DENSITIES.items():
        px = round(48 * factor)
        write(render(px, shape="rounded"),
              f"android/app/src/main/res/mipmap-{density}/ic_launcher.png")
        write(render(px, shape="circle"),
              f"android/app/src/main/res/mipmap-{density}/ic_launcher_round.png")

    print("android — adaptive layers")
    for density, factor in ANDROID_DENSITIES.items():
        px = round(108 * factor)
        # 108dp canvas, 72dp safe zone: the mark has to stay well inside.
        write(render(px, shape="transparent", scale=0.25),
              f"android/app/src/main/res/mipmap-{density}/ic_launcher_foreground.png")
        write(render_mono(px, 0.25),
              f"android/app/src/main/res/mipmap-{density}/ic_launcher_monochrome.png")
        write(render_background(px),
              f"android/app/src/main/res/mipmap-{density}/ic_launcher_background.png")

    print("ios")
    for name, px in IOS_ICONS.items():
        write(flatten(render(px, shape="square")),
              f"ios/Runner/Assets.xcassets/AppIcon.appiconset/{name}")

    print("web")
    write(render(32, shape="square"), "web/favicon.png")
    for px in (192, 512):
        write(flatten(render(px, shape="rounded")), f"web/icons/Icon-{px}.png")
        # Maskable icons are cropped by the platform: full bleed, smaller mark.
        write(flatten(render(px, shape="square", scale=0.24)),
              f"web/icons/Icon-maskable-{px}.png")

    print("windows")
    ico = render(256, shape="rounded")
    ico_path = ROOT / "windows/runner/resources/app_icon.ico"
    ico.save(ico_path, format="ICO",
             sizes=[(16, 16), (24, 24), (32, 32), (48, 48),
                    (64, 64), (128, 128), (256, 256)])
    print(f"  windows/runner/resources/app_icon.ico  16..256")

    print("store")
    write(flatten(render(512, shape="square")), "assets/branding/play_store_512.png")
    write(feature_graphic(), "assets/branding/play_feature_graphic_1024x500.png")
    return 0


def load_font(size: int):
    """Any geometric bold face the host happens to have.

    The graphic is committed, so a different machine picking a different font
    only matters when someone regenerates it — the run prints which one it used.
    """
    for name in ("bahnschrift.ttf", "segoeuib.ttf", "arialbd.ttf",
                 "DejaVuSans-Bold.ttf", "Arial Bold.ttf"):
        for root in ("C:/Windows/Fonts/", "/usr/share/fonts/truetype/dejavu/",
                     "/Library/Fonts/", ""):
            try:
                return ImageFont.truetype(root + name, size), name
            except OSError:
                continue
    return ImageFont.load_default(), "PIL default (install a TTF for a better banner)"


def feature_graphic() -> Image.Image:
    """The 1024x500 banner Play shows at the top of the listing."""
    w, h = 1024 * 2, 500 * 2
    side = max(w, h)
    field = backdrop(side).convert("RGBA")
    # Crop centred, or the radial glow lands off the bottom of the banner.
    top = (side - h) // 2
    img = field.crop(((side - w) // 2, top, (side - w) // 2 + w, top + h))

    glyph_px = int(h * 0.66)
    img.alpha_composite(mark(glyph_px, 0.30),
                        (int(w * 0.075), (h - glyph_px) // 2))

    title_font, used = load_font(int(h * 0.20))
    tag_font, _ = load_font(int(h * 0.062))
    print(f"  banner font: {used}")

    d = ImageDraw.Draw(img)
    tx = int(w * 0.40)
    # Baselines chosen so the two-line block centres on the same axis as the mark.
    d.text((tx, h * 0.50), "TESSERA", font=title_font,
           fill=(0xFF, 0xFF, 0xFF), anchor="ls")
    d.text((tx + 4, h * 0.645), "LINE UP THE MOSAIC", font=tag_font,
           fill=GLOW, anchor="ls")
    return flatten(img.resize((1024, 500), Image.Resampling.LANCZOS))


if __name__ == "__main__":
    sys.exit(main())
