# -*- coding: utf-8 -*-
"""Render an MLOD p3d with its PAA textures, as a sanity check before launching Arma.

A z-buffered software rasteriser with per-pixel texture lookup and one headlight.
Not a beauty shot - it exists to answer "is it the right way round, is the texture
on the right faces, is the scale sane" without starting the game.

    python tools/preview_p3d.py addons/esdcam/model/camhead.p3d out.png
"""

import argparse
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import p3d
import paa


def load_texture(path):
    """The largest mipmap that is not LZO compressed - the decoder in tools/paa.py reads
    raw DXT only, and ImageToPAA leaves the small levels raw. 128x128 on a 520 px render
    of a 42 cm object is more than the eye gets out of it anyway."""
    data = paa.read(path)
    usable = [m for m in data["mips"] if not m[2]]
    if not usable:
        raise SystemExit("%s: every mipmap is LZO compressed, nothing to preview" % path)
    width, height, _compressed, raw = usable[0]
    px = paa.decode_surface(raw, width, height, data["type"] == paa.TYPE_DXT5)
    out = np.array(px, np.uint8).reshape(height, width, 4)
    if any(t[0] == "SWIZ" for t in data["taggs"]):
        out[:, :, 0] = 255 - out[:, :, 3]
        out[:, :, 3] = 255
    return out


def render(lod, texture, size, yaw, pitch, background):
    xs = [p[0] for p in lod.points]
    ys = [p[1] for p in lod.points]
    zs = [p[2] for p in lod.points]
    centre = np.array([(min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2])
    extent = max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)) or 1.0

    cy, sy = math.cos(yaw), math.sin(yaw)
    cp, sp = math.cos(pitch), math.sin(pitch)
    rot = np.array([[cy, 0, -sy], [sp * sy, cp, sp * cy], [cp * sy, -sp, cp * cy]])

    pts = (np.array([p[:3] for p in lod.points]) - centre) @ rot.T
    # Negated: p3d normals follow Arma's left handed convention, and this rasteriser
    # shades with the ordinary right handed one. Without the minus the model comes out
    # lit from the inside - which is also what a correct model looks like here, so do
    # not read a preview as proof that the orientation is right. check() does that.
    nrm = -np.array(lod.normals) @ rot.T

    scale = size * 0.86 / extent
    sx = size / 2 + pts[:, 0] * scale
    sy_ = size / 2 - pts[:, 1] * scale

    colour = np.zeros((size, size, 3), np.float32)
    colour[:] = background
    depth = np.full((size, size), 1e9, np.float32)

    th, tw = texture.shape[:2]
    light = np.array([0.35, 0.55, -0.75])
    light = light / np.linalg.norm(light)

    tris = []
    for face in lod.faces:
        idx = [(v[0], v[1], v[2], v[3]) for v in face.verts]
        for k in range(1, len(idx) - 1):
            tris.append((idx[0], idx[k], idx[k + 1]))

    for tri in tris:
        p = [(sx[v[0]], sy_[v[0]], pts[v[0]][2]) for v in tri]
        area = (p[1][0] - p[0][0]) * (p[2][1] - p[0][1]) - (p[1][1] - p[0][1]) * (p[2][0] - p[0][0])
        if abs(area) < 1e-9:
            continue
        x0 = max(int(min(q[0] for q in p)), 0)
        x1 = min(int(max(q[0] for q in p)) + 1, size)
        y0 = max(int(min(q[1] for q in p)), 0)
        y1 = min(int(max(q[1] for q in p)) + 1, size)
        if x0 >= x1 or y0 >= y1:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        w0 = ((p[1][0] - gx) * (p[2][1] - gy) - (p[1][1] - gy) * (p[2][0] - gx)) / area
        w1 = ((p[2][0] - gx) * (p[0][1] - gy) - (p[2][1] - gy) * (p[0][0] - gx)) / area
        w2 = 1.0 - w0 - w1
        inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
        if not inside.any():
            continue
        z = w0 * p[0][2] + w1 * p[1][2] + w2 * p[2][2]
        window = depth[y0:y1, x0:x1]
        hit = inside & (z < window)
        if not hit.any():
            continue

        u = w0 * tri[0][2] + w1 * tri[1][2] + w2 * tri[2][2]
        v = w0 * tri[0][3] + w1 * tri[1][3] + w2 * tri[2][3]
        tx = np.clip((u * tw).astype(int), 0, tw - 1)
        ty = np.clip((v * th).astype(int), 0, th - 1)
        albedo = texture[ty, tx, :3].astype(np.float32) / 255.0

        n = (w0[..., None] * nrm[tri[0][1]] + w1[..., None] * nrm[tri[1][1]]
             + w2[..., None] * nrm[tri[2][1]])
        n /= np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-9)
        lambert = np.clip((n * light).sum(axis=2), 0, 1)
        shade = 0.22 + 0.9 * lambert
        rgb = np.clip(albedo * shade[..., None] * 2.6, 0, 1)

        window[hit] = z[hit]
        target = colour[y0:y1, x0:x1]
        target[hit] = rgb[hit]
    return (colour * 255).astype(np.uint8)


def main():
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap = argparse.ArgumentParser()
    ap.add_argument("model", nargs="?",
                    default=os.path.join(here, "addons", "esdcam", "model", "camhead.p3d"))
    ap.add_argument("out", nargs="?", default=os.path.join(here, "camhead_preview.png"))
    ap.add_argument("--texture",
                    default=os.path.join(here, "addons", "esdcam", "data", "camhead_co.paa"))
    ap.add_argument("--size", type=int, default=520)
    args = ap.parse_args()

    lods, _ = p3d.read(args.model)
    lod = lods[0]
    texture = load_texture(args.texture)

    views = [("3/4", 0.9, 0.45), ("side", 0.0, 0.0), ("head on", -1.5708, 0.0), ("top", 0.0, 1.4)]
    sheet = Image.new("RGB", (args.size * len(views), args.size + 22), (18, 19, 22))
    from PIL import ImageDraw
    draw = ImageDraw.Draw(sheet)
    for i, (label, yaw, pitch) in enumerate(views):
        img = render(lod, texture, args.size, yaw, pitch, (0.07, 0.075, 0.085))
        sheet.paste(Image.fromarray(img), (i * args.size, 22))
        draw.text((i * args.size + 8, 6), label, fill=(225, 225, 225))
    sheet.save(args.out)
    print("wrote %s" % args.out)


if __name__ == "__main__":
    main()
