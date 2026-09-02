# -*- coding: utf-8 -*-
"""Render the inventory picture for the attachment, in Bohemia's own style.

Measured off their files rather than guessed. Extracted from weapons_f_enoch.pbo:

    gear_muzzle_antenna_01_ca.paa   512 x 512   DXT5, alpha
    gear_muzzle_antenna_03_ca.paa   512 x 512   DXT5, alpha

Both are the attachment on a fully transparent background, lit softly from the upper
left, laid out along the diagonal from lower left to upper right so a long thin object
fills a square. That is what this reproduces, so the camera sits in the arsenal list
looking like it belongs between the antennas rather than next to them.

Rendered at 4x and boxed down, which is where the clean edge comes from - the
rasteriser itself has no antialiasing, and the alpha channel is the coverage mask
resampled the same way.

    python tools/render_icon.py
"""

import argparse
import math
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import p3d
import preview_p3d
from bake_textures import find_imagetopaa

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Three quarter view, then rolled so the wand runs across the square corner to corner -
# the same composition as the vanilla antenna pictures.
YAW = 0.62
PITCH = 0.30
ROLL = -0.60

# Key light from the upper left and in front, which is where Bohemia's is. The ambient is
# high and the exposure low: an icon is read at 64 px in a list, and deep shadow there just
# turns into a black smudge.
LIGHT = (-0.45, 0.62, -0.65)
AMBIENT = 0.42
EXPOSURE = 2.2


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default=os.path.join(HERE, "addons", "esdcam", "model", "camhead.p3d"))
    ap.add_argument("--texture",
                    default=os.path.join(HERE, "addons", "esdcam", "data", "camhead_co.paa"))
    ap.add_argument("--out", default=os.path.join(HERE, "addons", "esdcam", "data", "ui",
                                                  "gear_camhead_ca.paa"))
    ap.add_argument("--size", type=int, default=512)
    ap.add_argument("--supersample", type=int, default=4)
    ap.add_argument("--fill", type=float, default=0.96,
                    help="fraction of the frame the object fills; Bohemia's antenna 3 sits "
                         "at about 1.0 across and this matches it")
    ap.add_argument("--png", help="also keep the rendered PNG here")
    args = ap.parse_args()

    lods, _ = p3d.read(args.model)
    lod = min(lods, key=lambda l: l.resolution)
    texture = preview_p3d.load_texture(args.texture)

    big = args.size * args.supersample
    rgb, drawn = preview_p3d.render(
        lod, texture, big, YAW, PITCH, (0.0, 0.0, 0.0),
        roll=ROLL, light=LIGHT, exposure=EXPOSURE, ambient=AMBIENT, coverage=True,
        fit=args.fill)

    rgba = np.dstack([rgb, np.where(drawn, 255, 0).astype(np.uint8)])
    # Premultiply before the downsample, or the transparent black around the silhouette
    # bleeds into the edge pixels and leaves a dark fringe on a light background.
    premultiplied = rgba.astype(np.float32)
    premultiplied[:, :, :3] *= premultiplied[:, :, 3:4] / 255.0
    small = np.array(Image.fromarray(premultiplied.astype(np.uint8), "RGBA")
                     .resize((args.size, args.size), Image.BOX), np.float32)
    alpha = small[:, :, 3:4]
    small[:, :, :3] = np.where(alpha > 0, small[:, :, :3] * 255.0 / np.maximum(alpha, 1), 0)
    icon = Image.fromarray(np.clip(small, 0, 255).astype(np.uint8), "RGBA")

    covered = (np.array(icon)[:, :, 3] > 8)
    rows = np.nonzero(covered.any(axis=1))[0]
    cols = np.nonzero(covered.any(axis=0))[0]

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    tool = find_imagetopaa()
    with tempfile.TemporaryDirectory() as work:
        png = args.png or os.path.join(work, os.path.basename(args.out).replace(".paa", ".png"))
        icon.save(png)
        if not tool:
            raise SystemExit("ImageToPAA not found - an icon with alpha has to be DXT5, and "
                             "the built in encoder does not pick that from a file name. "
                             "Set IMAGETOPAA.")
        # The _ca suffix is what tells ImageToPAA to keep the alpha channel; the name of the
        # temporary file therefore has to be the final one.
        subprocess.run([tool, png, args.out], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    print("%s   %d x %d, content x %d..%d  y %d..%d, %d bytes"
          % (os.path.relpath(args.out, HERE), args.size, args.size,
             cols.min(), cols.max(), rows.min(), rows.max(), os.path.getsize(args.out)))


if __name__ == "__main__":
    main()
