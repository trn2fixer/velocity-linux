#!/usr/bin/env python3
"""Generate Velocity Linux visual assets procedurally (no binaries in git).

Outputs into --out (default assets/out):
  wallpaper-night.png   3840x2160  dark gradient, violet/cyan light streaks
  wallpaper-day.png     3840x2160  light variant
  splash.png            640x480    syslinux BIOS boot menu background
  grub-background.png   1920x1080  GRUB theme background
  select_c.png / select_e.png / select_w.png       GRUB selected-item pixmaps
  terminal_box_c.png (+8 edges)                    GRUB terminal box pixmaps
  logo.png              512x512    app/OS logo (V with a speed streak)
"""
from __future__ import annotations

import argparse
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

VIOLET = (124, 92, 255)
CYAN = (34, 211, 238)
NIGHT_BG = (11, 11, 18)
NIGHT_BG2 = (26, 22, 48)
DAY_BG = (247, 247, 251)
DAY_BG2 = (226, 224, 245)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(size, c1, c2, angle_deg=35):
    """Linear gradient across the image at the given angle."""
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    a = math.radians(angle_deg)
    dx, dy = math.cos(a), math.sin(a)
    # project corners to get range
    proj = [x * dx + y * dy for x in (0, w) for y in (0, h)]
    lo, hi = min(proj), max(proj)
    # draw as rows for speed
    for y in range(h):
        for x in range(0, w, 4):
            t = ((x * dx + y * dy) - lo) / (hi - lo)
            c = lerp(c1, c2, t)
            for k in range(4):
                if x + k < w:
                    px[x + k, y] = c
    return img


def streaks(img, colors, count, seed, alpha=0.55, width_range=(6, 40)):
    """Soft diagonal light streaks: the 'velocity' motif."""
    rnd = random.Random(seed)
    w, h = img.size
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(count):
        c = colors[i % len(colors)]
        y = rnd.randint(int(h * 0.15), int(h * 0.95))
        length = rnd.randint(int(w * 0.25), int(w * 0.9))
        x0 = rnd.randint(-int(w * 0.2), int(w * 0.6))
        thick = rnd.randint(*width_range)
        slope = -0.28
        a = int(255 * alpha * rnd.uniform(0.35, 1.0))
        d.line([(x0, y), (x0 + length, y + length * slope)], fill=(*c, a), width=thick)
    layer = layer.filter(ImageFilter.GaussianBlur(radius=max(w, h) / 90))
    out = img.convert("RGBA")
    out.alpha_composite(layer)
    # a few crisp thin lines on top for definition
    layer2 = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d2 = ImageDraw.Draw(layer2)
    for i in range(count // 2):
        c = colors[i % len(colors)]
        y = rnd.randint(int(h * 0.2), int(h * 0.9))
        length = rnd.randint(int(w * 0.15), int(w * 0.6))
        x0 = rnd.randint(-int(w * 0.1), int(w * 0.7))
        d2.line([(x0, y), (x0 + length, y + length * -0.28)], fill=(*c, int(180 * alpha)), width=2)
    layer2 = layer2.filter(ImageFilter.GaussianBlur(radius=1.2))
    out.alpha_composite(layer2)
    return out.convert("RGB")


def vignette(img, strength=0.45):
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse([-w * 0.25, -h * 0.35, w * 1.25, h * 1.35], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(radius=w / 6))
    dark = Image.new("RGB", (w, h), (0, 0, 0))
    return Image.composite(img, Image.blend(img, dark, strength), mask)


def logo(size=512, fg=VIOLET, fg2=CYAN, bg=None):
    """A bold V with a speed streak through it."""
    s = size
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0) if bg is None else (*bg, 255))
    d = ImageDraw.Draw(img)
    t = s * 0.16  # stroke
    # V
    pts_l = [(s * 0.12, s * 0.18), (s * 0.12 + t, s * 0.18), (s * 0.5 + t * 0.35, s * 0.82), (s * 0.5 - t * 0.35, s * 0.82)]
    pts_r = [(s * 0.88 - t, s * 0.18), (s * 0.88, s * 0.18), (s * 0.5 + t * 0.35, s * 0.82), (s * 0.5 - t * 0.35, s * 0.82)]
    d.polygon(pts_l, fill=(*fg, 255))
    d.polygon(pts_r, fill=(*fg2, 255))
    # streak
    d.polygon([(s * 0.02, s * 0.50), (s * 0.60, s * 0.50), (s * 0.55, s * 0.58), (s * 0.02, s * 0.58)], fill=(*fg2, 200))
    return img


def wallpaper(size, night: bool, seed: int):
    if night:
        base = gradient(size, NIGHT_BG, NIGHT_BG2, 40)
        img = streaks(base, [VIOLET, CYAN], 16, seed, alpha=0.85, width_range=(8, 56))
        img = vignette(img, 0.35)
    else:
        base = gradient(size, DAY_BG, DAY_BG2, 40)
        img = streaks(base, [VIOLET, (14, 165, 233)], 12, seed, alpha=0.32)
        img = vignette(img, 0.12)
    # small logo bottom-right
    lg = logo(int(size[1] * 0.07)).resize((int(size[1] * 0.07),) * 2, Image.LANCZOS)
    img = img.convert("RGBA")
    pad = int(size[1] * 0.04)
    img.alpha_composite(lg, (size[0] - lg.width - pad, size[1] - lg.height - pad))
    return img.convert("RGB")


def rounded_box(size, fill, radius, outline=None, width=2):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=fill, outline=outline, width=width)
    return img


def grub_pixmaps(out: Path):
    """GRUB styled-box pixmaps: select_{c,w,e}.png and terminal_box_*.png."""
    # selected item: cyan pill
    h = 32
    c = rounded_box((16, h), (*CYAN, 255), 0)
    w = rounded_box((16, h), (*CYAN, 255), 8)
    e = rounded_box((16, h), (*CYAN, 255), 8)
    # crop left/right halves so the rounded ends are on the outside
    w = w.crop((0, 0, 8, h)).resize((16, h))
    e = e.crop((8, 0, 16, h)).resize((16, h))
    c.save(out / "select_c.png"); w.save(out / "select_w.png"); e.save(out / "select_e.png")
    # terminal box: translucent dark panel with subtle border
    fill = (11, 11, 18, 225)
    border = (*VIOLET, 255)
    box = rounded_box((48, 48), fill, 10, outline=border, width=2)
    names = {
        "nw": (0, 0, 16, 16), "n": (16, 0, 32, 16), "ne": (32, 0, 48, 16),
        "w": (0, 16, 16, 32), "c": (16, 16, 32, 32), "e": (32, 16, 48, 32),
        "sw": (0, 32, 16, 48), "s": (16, 32, 32, 48), "se": (32, 32, 48, 48),
    }
    for n, bbox in names.items():
        box.crop(bbox).save(out / f"terminal_box_{n}.png")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(Path(__file__).parent / "out"))
    ap.add_argument("--fast", action="store_true", help="smaller wallpapers for quick checks")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    wp_size = (1920, 1080) if args.fast else (3840, 2160)
    print("wallpaper-night.png"); wallpaper(wp_size, True, 7).save(out / "wallpaper-night.png", optimize=True)
    print("wallpaper-day.png"); wallpaper(wp_size, False, 11).save(out / "wallpaper-day.png", optimize=True)

    print("grub-background.png")
    wallpaper((1920, 1080), True, 7).save(out / "grub-background.png")

    print("splash.png")
    sp = wallpaper((640, 480), True, 7)
    sp.save(out / "splash.png")

    print("logo.png")
    logo(512).save(out / "logo.png")

    print("grub pixmaps")
    grub_pixmaps(out)
    print(f"done -> {out}")


if __name__ == "__main__":
    main()
