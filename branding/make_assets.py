#!/usr/bin/env python3
"""Render the GameTDP OS artwork into system_files/ (and repo_content/ for the README).

Style follows the TDPlay logo: dark navy circle, tall lavender Oswald letters, red play triangle.

Usage: python3 branding/make_assets.py [path/to/Oswald.ttf]
Needs Pillow and `cjxl` (brew install jpeg-xl). The font is not committed; by default it is
read from the sibling tdplay-os project.
"""
import json
import math
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SYS = ROOT / "system_files"
FONT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT.parent / "tdplay-os/assets/Oswald.ttf"

LAVENDER = (177, 120, 211)
RED = (205, 28, 12)
RED_DEEP = (173, 19, 2)
NAVY = (4, 7, 17)
NAVY_TOP = (26, 23, 51)


def font(size, weight="Regular"):
    f = ImageFont.truetype(str(FONT), size)
    f.set_variation_by_name(weight)
    return f


def play_triangle(draw, x, y, h, fill):
    """Right-pointing triangle with its left edge at x, vertically centred on y."""
    w = h * 0.86
    draw.polygon([(x, y - h / 2), (x + w, y), (x, y + h / 2)], fill=fill)
    return w


def text_width(draw, s, f, spacing=0):
    return sum(draw.textlength(ch, font=f) for ch in s) + spacing * (len(s) - 1)


def draw_spaced(draw, x, y, s, f, fill, spacing=0):
    for ch in s:
        draw.text((x, y), ch, font=f, fill=fill, anchor="ls")
        x += draw.textlength(ch, font=f) + spacing
    return x


def logo(size=1024):
    """Round badge: GAME on top, TDP + play triangle below."""
    s = size
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    # Circle with a subtle top-to-bottom gradient
    grad = Image.new("RGBA", (s, s))
    gd = ImageDraw.Draw(grad)
    for y in range(s):
        t = y / (s - 1)
        col = tuple(int(NAVY_TOP[i] * (1 - t) + NAVY[i] * t) for i in range(3))
        gd.line([(0, y), (s, y)], fill=col + (255,))
    mask = Image.new("L", (s, s), 0)
    pad = int(s * 0.02)
    ImageDraw.Draw(mask).ellipse([pad, pad, s - pad, s - pad], fill=255)
    img.paste(grad, (0, 0), mask)

    # Soft highlight like the TDPlay badge
    glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [s * 0.52, s * 0.14, s * 0.60, s * 0.22], fill=(255, 255, 255, 110)
    )
    glow = glow.filter(ImageFilter.GaussianBlur(s * 0.025))
    img = Image.alpha_composite(img, Image.composite(glow, Image.new("RGBA", (s, s)), mask))

    d = ImageDraw.Draw(img)
    f = font(int(s * 0.265), "Regular")
    sp = s * 0.014
    line1_base = s * 0.47
    line2_base = s * 0.76

    w1 = text_width(d, "GAME", f, sp)
    draw_spaced(d, (s - w1) / 2, line1_base, "GAME", f, LAVENDER + (255,), sp)

    tri_h = s * 0.14
    tri_gap = s * 0.03
    w2 = text_width(d, "TDP", f, sp) + tri_gap + tri_h * 0.86
    x = (s - w2) / 2
    x = draw_spaced(d, x, line2_base, "TDP", f, LAVENDER + (255,), sp) - sp + tri_gap
    cap_h = f.getbbox("T", anchor="ls")[1]  # negative: cap height above baseline
    tri_y = line2_base + cap_h / 2

    tri = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    play_triangle(ImageDraw.Draw(tri), x, tri_y, tri_h, RED + (255,))
    halo = tri.filter(ImageFilter.GaussianBlur(s * 0.012))
    img = Image.alpha_composite(img, halo)
    img = Image.alpha_composite(img, tri)
    return img


def wordmark(height=96, color=LAVENDER):
    """'GameTDP OS' + play triangle on a transparent background (boot splash)."""
    f = font(int(height * 0.8), "Regular")
    probe = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    sp = height * 0.03
    tw = text_width(probe, "GAMETDP OS", f, sp)
    tri_h = height * 0.42
    w = int(tw + height * 0.12 + tri_h * 0.86 + height * 0.1)
    img = Image.new("RGBA", (w, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base = height * 0.86
    x = draw_spaced(d, height * 0.05, base, "GAMETDP OS", f, color + (255,), sp)
    cap_h = f.getbbox("G", anchor="ls")[1]
    play_triangle(d, x - sp + height * 0.12, base + cap_h / 2, tri_h, RED + (255,))
    return img


def wallpaper(w=3840, h=2160):
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / (h - 1)
        col = tuple(int((10, 10, 24)[i] * (1 - t) + NAVY[i] * t) for i in range(3))
        d.line([(0, y), (w, y)], fill=col + (255,))

    # Large colour glows, blurred at low resolution for speed
    sw, sh = w // 8, h // 8
    g = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    gd.ellipse([-sw * 0.25, -sh * 0.55, sw * 0.55, sh * 0.45], fill=LAVENDER + (70,))
    gd.ellipse([sw * 0.55, sh * 0.55, sw * 1.3, sh * 1.45], fill=RED_DEEP + (95,))
    gd.ellipse([sw * 0.36, sh * 0.28, sw * 0.64, sh * 0.62], fill=RED_DEEP + (45,))
    g = g.filter(ImageFilter.GaussianBlur(sw * 0.09)).resize((w, h), Image.BICUBIC)
    img = Image.alpha_composite(img, g)

    # Perspective floor grid fading into the horizon
    horizon = int(h * 0.64)
    vx = w / 2
    grid = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gr = ImageDraw.Draw(grid)
    lw = max(2, w // 1400)
    for i in range(-40, 41):
        gr.line([(vx, horizon), (vx + i * w * 0.06, h * 1.6)], fill=LAVENDER + (120,), width=lw)
    # Rows at geometrically increasing depth; screen y = horizon + C / depth
    for k in range(60):
        y = horizon + (h - horizon) * 1.3 / (1.28 ** k)
        if y - horizon < 3:
            break
        if y <= h:
            gr.line([(0, y), (w, y)], fill=LAVENDER + (120,), width=lw)
    fade = Image.new("L", (w, h), 0)
    fd = ImageDraw.Draw(fade)
    for y in range(horizon, h):
        t = (y - horizon) / (h - horizon)
        fd.line([(0, y), (w, y)], fill=int(255 * min(1, t * 1.6) * 0.55))
    grid.putalpha(ImageChops.multiply(grid.getchannel("A"), fade))
    img = Image.alpha_composite(img, grid)

    # Horizon glow line
    hl = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(hl).line([(0, horizon), (w, horizon)], fill=RED + (200,), width=6)
    img = Image.alpha_composite(img, hl.filter(ImageFilter.GaussianBlur(10)))
    img = Image.alpha_composite(img, hl.filter(ImageFilter.GaussianBlur(2)))

    # Badge with a red halo behind it
    bs = int(h * 0.36)
    badge = logo(1024).resize((bs, bs), Image.LANCZOS)
    bx, by = int(vx - bs / 2), int(horizon - bs * 0.98)
    halo = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse([bx - 40, by - 40, bx + bs + 40, by + bs + 40], fill=RED_DEEP + (120,))
    img = Image.alpha_composite(img, halo.filter(ImageFilter.GaussianBlur(90)))
    img.alpha_composite(badge, (bx, by))

    wm = wordmark(int(h * 0.045), (205, 170, 230))
    img.alpha_composite(wm, (int(vx - wm.width / 2), int(horizon + h * 0.05)))
    return img.convert("RGB")


def save(img, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    print("wrote", path.relative_to(ROOT))


def main():
    big = logo(1024)
    save(big.resize((512, 512), Image.LANCZOS), SYS / "usr/share/pixmaps/gametdp-logo.png")
    for px in (16, 22, 24, 32, 48, 64, 128, 256, 512):
        save(big.resize((px, px), Image.LANCZOS),
             SYS / f"usr/share/icons/hicolor/{px}x{px}/apps/gametdp-logo.png")

    save(wordmark(72), SYS / "usr/share/plymouth/themes/spinner/watermark.png")

    wp = wallpaper()
    wdir = SYS / "usr/share/wallpapers/GameTDP"
    png = ROOT / "branding/wallpaper-3840x2160.png"
    save(wp, png)
    jxl = wdir / "contents/images/3840x2160.jxl"
    jxl.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["cjxl", str(png), str(jxl), "-d", "1", "--quiet"], check=True)
    print("wrote", jxl.relative_to(ROOT))
    save(wp.resize((800, 450), Image.LANCZOS), wdir / "contents/screenshot.png")
    (wdir / "metadata.json").write_text(json.dumps({
        "KPlugin": {
            "Authors": [{"Name": "GameTDP OS"}],
            "Id": "GameTDP",
            "License": "CC-BY-SA-4.0",
            "Name": "GameTDP",
        }
    }, indent=4) + "\n")
    print("wrote", (wdir / "metadata.json").relative_to(ROOT))

    save(wp.resize((1280, 720), Image.LANCZOS), ROOT / "repo_content/wallpaper-preview.png")
    save(big.resize((256, 256), Image.LANCZOS), ROOT / "repo_content/logo.png")


if __name__ == "__main__":
    main()
