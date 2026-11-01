#!/usr/bin/env python3
"""Paints a copy of the KayKit building atlas for each crown land / dark pact, so a
proclaimed city's roofs show its nation's colour. Run from the project root:
    python3 devtools/roofs.py
The team colour lives in a strip of the shared atlas (each team variant's UVs point
at its own strip); this finds the strips from the models' UVs and repaints them,
keeping the original shading. Writes assets/recolor/roofs_<land>.png.
"""
import colorsys, json, struct
from PIL import Image

B = "assets/kaykit/medieval/buildings/"
TEAMS = ["yellow", "red"]
# Roof colours: Austria Schoenbrunn gold, Croatia red, Bohemia white, Tyrol crimson,
# Hungary green; the Covenant's pacts in their banner colours.
COLORS = {
    "austria": (238, 182, 52), "croatia": (205, 40, 45), "bohemia": (236, 232, 222),
    "tyrol": (150, 24, 40), "hungary": (52, 128, 70),
    "throne": (110, 70, 140), "blood": (120, 10, 22), "bone": (214, 204, 178), "shadow": (48, 40, 72),
}


def uvs(team, name):
    g = json.load(open(f"{B}{team}/building_{name}_{team}.gltf"))
    data = open(f"{B}{team}/" + g["buffers"][0]["uri"], "rb").read()
    out = []
    for mesh in g["meshes"]:
        for prim in mesh["primitives"]:
            acc = g["accessors"][prim["attributes"]["TEXCOORD_0"]]
            bv = g["bufferViews"][acc["bufferView"]]
            off = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
            stride = bv.get("byteStride", 8)
            out += [struct.unpack_from("<2f", data, off + i * stride) for i in range(acc["count"])]
    return out


def strip_boxes(size):
    """Bounding box of each team's strip: pixels the team variants sample differently."""
    import os
    names = [f[len("building_"):-len("_yellow.gltf")] for f in os.listdir(B + "yellow") if f.endswith(".gltf")]
    boxes = {}
    for team in TEAMS:
        pts = []
        for n in names:
            try:
                mine, other = uvs(team, n), uvs("yellow" if team != "yellow" else "red", n)
            except (FileNotFoundError, KeyError):
                continue
            pts += [u for u, v in zip(mine, other) if abs(u[0] - v[0]) > 1e-4 or abs(u[1] - v[1]) > 1e-4]
        xs = [p[0] * size[0] for p in pts]
        ys = [p[1] * size[1] for p in pts]
        # The strips are whole 128-px columns of 32-px rows; snap to them.
        boxes[team] = (int(min(xs)) // 128 * 128, int(min(ys)) // 32 * 32,
                       -(-int(max(xs)) // 128) * 128, size[1])
    return boxes


def main():
    src = Image.open(B + "yellow/hexagons_medieval.png").convert("RGBA")
    boxes = strip_boxes(src.size)
    print("team strips:", boxes)
    for land, target in COLORS.items():
        im = src.copy()
        px = im.load()
        for team, (x0, y0, x1, y1) in boxes.items():
            for y in range(max(0, y0), min(im.height, y1)):
                for x in range(max(0, x0), min(im.width, x1)):
                    r, g, b, a = px[x, y]
                    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
                    if s < 0.35:
                        continue
                    # Keep the strip's light-to-dark gradient (it shades the roofs).
                    k = 0.25 + 1.25 * l
                    px[x, y] = tuple(min(255, int(c * k)) for c in target) + (a,)
        im.save(f"assets/recolor/roofs_{land}.png")
        print("wrote", land)


if __name__ == "__main__":
    main()
