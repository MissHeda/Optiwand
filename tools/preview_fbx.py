# -*- coding: utf-8 -*-
"""Orthographic preview of an FBX mesh, coloured by material.

The first thing to run when a new model arrives: it says which way round the mesh is,
which end carries which material, and how big it is in the modeller's units - all of
which fbx_to_p3d.py then needs to be told or has to assume.

    python tools/preview_fbx.py [source.fbx] [out.png]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fbx
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COLOURS = [(150, 150, 158), (110, 125, 145), (235, 200, 90), (70, 190, 235)]


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "art", "esdcam", "arma3_cam.fbx")
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "fbx_preview.png")

    root, _ = fbx.parse(src)
    objects = root.find("Objects")
    geo = objects.find("Geometry")
    verts = geo.find("Vertices").props[0]
    poly_index = geo.find("PolygonVertexIndex").props[0]
    materials = geo.find("LayerElementMaterial").find("Materials").props[0]
    names = [o.props[1].split("\0")[0] for o in objects.find_all("Material")]

    polys, current = [], []
    for i in poly_index:
        current.append(-i - 1 if i < 0 else i)
        if i < 0:
            polys.append(current)
            current = []
    pts = [(verts[i * 3], verts[i * 3 + 1], verts[i * 3 + 2]) for i in range(len(verts) // 3)]

    width, height, panel = 1500, 540, 500
    img = Image.new("RGB", (width, height), (24, 26, 30))
    draw = ImageDraw.Draw(img)
    views = [("side  (Y right, Z up)", 1, 2), ("top   (Y right, X up)", 1, 0),
             ("front (X right, Z up)", 0, 2)]

    for slot, (label, ax, ay) in enumerate(views):
        a_min, a_max = min(p[ax] for p in pts), max(p[ax] for p in pts)
        b_min, b_max = min(p[ay] for p in pts), max(p[ay] for p in pts)
        scale = (panel - 60) / max(a_max - a_min, b_max - b_min, 1e-9)
        ox = slot * panel + 30 - a_min * scale
        oy = height - 40 + b_min * scale
        # Painter's order along the axis pointing at the viewer, so the near side wins.
        depth = 3 - ax - ay
        for face in sorted(range(len(polys)),
                           key=lambda k: sum(pts[v][depth] for v in polys[k]) / len(polys[k])):
            colour = COLOURS[materials[face] % len(COLOURS)]
            draw.polygon([(ox + pts[v][ax] * scale, oy - pts[v][ay] * scale) for v in polys[face]],
                         outline=tuple(int(c * 0.4) for c in colour), fill=colour)
        draw.text((slot * panel + 30, 12), label, fill=(225, 225, 225))
        draw.text((slot * panel + 30, 28), "%s %.2f .. %.2f" % ("XYZ"[ax], a_min, a_max),
                  fill=(150, 150, 150))
        draw.text((slot * panel + 30, 42), "%s %.2f .. %.2f" % ("XYZ"[ay], b_min, b_max),
                  fill=(150, 150, 150))

    for i, name in enumerate(names):
        draw.rectangle([10 + i * 120, height - 22, 26 + i * 120, height - 8],
                       fill=COLOURS[i % len(COLOURS)])
        draw.text((32 + i * 120, height - 21), name, fill=(210, 210, 210))

    img.save(out)
    print("wrote %s   %d polygons, %d materials" % (out, len(polys), len(names)))


if __name__ == "__main__":
    main()
