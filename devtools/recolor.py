#!/usr/bin/env python3
"""Recolours KayKit character textures for the Aetheric Monarchy (white coats,
Grenzer red, Habsburg black-and-gold). Run from the project root:
    python3 devtools/recolor.py
Writes assets/recolor/*.png, which data/visuals.json references via "texture".
"""
import colorsys
from PIL import Image

SRC = "assets/kaykit/adventures/%s_texture.png"
OUT = "assets/recolor/%s.png"

# (output, source texture, [(hue_min, hue_max, min_saturation, target_rgb)])
JOBS = [
    ("rogue_white", "rogue", [(130, 180, 0.45, (232, 228, 214)), (180, 200, 0.6, (196, 164, 64))]),
    # Settlers: Schoenbrunn yellow (the ochre of Habsburg palaces) with dark brown trim.
    ("rogue_schoenbrunn", "rogue", [(130, 180, 0.45, (214, 164, 58)), (180, 200, 0.6, (92, 62, 38))]),
    ("rogue_loden", "rogue", [(130, 180, 0.45, (98, 110, 82)), (180, 200, 0.6, (60, 70, 50))]),
    ("barbarian_red", "barbarian", [(190, 215, 0.3, (215, 52, 48))]),
    ("knight_white", "knight", [(195, 210, 0.1, (232, 228, 214))]),
    ("mage_black_gold", "mage", [(235, 255, 0.3, (40, 36, 38)), (180, 192, 0.5, (201, 164, 58))]),
]


def recolor(src, rules):
    im = Image.open(SRC % src).convert("RGBA")
    px = im.load()
    cache = {}
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c not in cache:
                r, g, b, a = c
                h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                out = c
                for lo, hi, smin, target in rules:
                    if lo <= h * 360 <= hi and s >= smin:
                        # Keep the swatch's shading: brighter source -> brighter target.
                        k = 0.55 + 0.6 * v
                        out = tuple(min(255, int(t * k)) for t in target) + (a,)
                        break
                cache[c] = out
            px[x, y] = cache[c]
    return im


if __name__ == "__main__":
    for name, src, rules in JOBS:
        recolor(src, rules).save(OUT % name)
        print("wrote", OUT % name)
