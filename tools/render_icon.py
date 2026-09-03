# -*- coding: utf-8 -*-
"""Render the two inventory pictures for the attachment, in Bohemia's own style.

Arma wants two different things and they are not interchangeable:

  item   the picture in the arsenal and in the item slot. 512 x 512, three quarter
         view. `picture` in CfgWeapons.
  slot   the overlay that is drawn onto the weapon's own inventory picture to show
         the attachment fitted. 256 x 128, flat side on. `iconPicture` in the
         weapon's WeaponSlotsInfo slot - per slot, which is why the device carries
         one muzzle slot per attachment.

Both layouts are measured off Bohemia's files rather than composed by eye:

    gear_muzzle_antenna_01_ca      512 x 512   mount 496.9, 250.0   axis 11.4 deg
    gear_muzzle_antenna_02_ca      512 x 512   mount 502.2, 103.1   axis  5.9 deg
    gear_muzzle_antenna_03_ca      512 x 512   mount 500.0, 228.8   axis  9.0 deg
    hgun_esd_01_antenna_01_f_ca    256 x 128   mount 175.6,  63.5   flat
    hgun_esd_01_antenna_03_f_ca    256 x 128   mount 247.0,  63.7   flat

The 512s all hang their mount at x = 500 and run away to the left; the 256x128s are
plain side views on the horizontal, mount to the right, centred on y = 64.

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

# Key light from the upper left and in front, which is where Bohemia's is. The ambient is
# high and the exposure low: these are read at 64 px in a list, and deep shadow there just
# turns into a black smudge.
LIGHT = (-0.45, 0.62, -0.65)
AMBIENT = 0.42
EXPOSURE = 2.2

# name: (width, height, yaw, pitch, mount point, tip point, output file)
PRESETS = {
    "item": (512, 512, 0.62, 0.30, (500.0, 236.0), (6.0, 314.0), "gear_camhead_ca.paa"),
    # Flat side on, mount where antenna 03 puts its own, tip just inside the left edge.
    # yaw and pitch of zero look straight down the model's Y, which lays the wand along the
    # horizontal with the mount - the origin - at the right, exactly as Bohemia's are.
    "slot": (256, 128, 0.0, 0.0, (247.0, 64.0), (7.0, 64.0), "hgun_esd_01_camhead_F_ca.paa"),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default=os.path.join(HERE, "addons", "esdcam", "model", "camhead.p3d"))
    ap.add_argument("--texture",
                    default=os.path.join(HERE, "addons", "esdcam", "data", "camhead_co.paa"))
    ap.add_argument("--preset", choices=sorted(PRESETS), default="item")
    ap.add_argument("--out", help="defaults to the preset's own file under data/ui")
    ap.add_argument("--supersample", type=int, default=4)
    ap.add_argument("--png", help="also keep the rendered PNG here")
    args = ap.parse_args()

    width, height, yaw, pitch, mount_at, tip_at, filename = PRESETS[args.preset]
    out = args.out or os.path.join(HERE, "addons", "esdcam", "data", "ui", filename)

    lods, _ = p3d.read(args.model)
    lod = min(lods, key=lambda l: l.resolution)
    texture = preview_p3d.load_texture(args.texture)

    # The mount is the model's origin by construction, and the tip is the far end of it.
    mount = (0.0, 0.0, 0.0)
    tip = min(lod.points, key=lambda p: p[0])[:3]

    scale = args.supersample
    rgb, drawn = preview_p3d.render(
        lod, texture, (width * scale, height * scale), yaw, pitch, (0.0, 0.0, 0.0),
        light=LIGHT, exposure=EXPOSURE, ambient=AMBIENT, coverage=True,
        place=(mount, tip,
               (mount_at[0] * scale, mount_at[1] * scale),
               (tip_at[0] * scale, tip_at[1] * scale)))

    rgba = np.dstack([rgb, np.where(drawn, 255, 0).astype(np.uint8)])
    # Premultiply before the downsample, or the transparent black around the silhouette
    # bleeds into the edge pixels and leaves a dark fringe on a light background.
    premultiplied = rgba.astype(np.float32)
    premultiplied[:, :, :3] *= premultiplied[:, :, 3:4] / 255.0
    small = np.array(Image.fromarray(premultiplied.astype(np.uint8), "RGBA")
                     .resize((width, height), Image.BOX), np.float32)
    alpha = small[:, :, 3:4]
    small[:, :, :3] = np.where(alpha > 0, small[:, :, :3] * 255.0 / np.maximum(alpha, 1), 0)
    icon = Image.fromarray(np.clip(small, 0, 255).astype(np.uint8), "RGBA")

    covered = (np.array(icon)[:, :, 3] > 8)
    rows = np.nonzero(covered.any(axis=1))[0]
    cols = np.nonzero(covered.any(axis=0))[0]

    os.makedirs(os.path.dirname(out), exist_ok=True)
    tool = find_imagetopaa()
    with tempfile.TemporaryDirectory() as work:
        png = args.png or os.path.join(work, os.path.basename(out).replace(".paa", ".png"))
        icon.save(png)
        if not tool:
            raise SystemExit("ImageToPAA not found - an icon with alpha has to be DXT5, and "
                             "the built in encoder does not pick that from a file name. "
                             "Set IMAGETOPAA.")
        # The _ca suffix is what tells ImageToPAA to keep the alpha channel; the name of the
        # temporary file therefore has to be the final one.
        subprocess.run([tool, png, out], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    print("%s   %d x %d, content x %d..%d  y %d..%d, %d bytes"
          % (os.path.relpath(out, HERE), width, height,
             cols.min(), cols.max(), rows.min(), rows.max(), os.path.getsize(out)))


if __name__ == "__main__":
    main()
