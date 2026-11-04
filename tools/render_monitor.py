# -*- coding: utf-8 -*-
"""Render the field monitor the camera picture is shown on: addons/mirror/data/monitor_ca.paa.

The monitor is a picture, not a stack of UI controls: a housing modelled and lit in Blender
(tools/blender_monitor.py), with a hole where the screen is and its edge shaded over
that hole here. The camera picture sits behind it in the overlay and shows through - see
addons/mirror/gui.hpp.

    python tools/render_monitor.py [--png folder]

A paa has to measure a power of two, so the 2048 x 1328 render is stored squeezed into 2048 x
1024; the control it goes on stretches it back. Where the screen sits in the picture is
fixed by the sizes in blender_monitor.py, and MONITOR_* in addons/mirror/script_component.hpp
has to agree - this prints the numbers.

Needs Blender (BLENDER, or the Steam install), the Arma 3 Tools and Pillow.
"""

import argparse
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import imagetopaa
import render_icon

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "addons", "mirror", "data", "monitor_ca.paa")

CANVAS = (2048, 1328)
SCREEN = (144, 114, 1760, 990)  # x, y, w, h in the render


def glass(rgba):
    """What the screen adds over the picture behind it: a dark edge where the frame shades it.
    Nothing lighter than that - a reflection across the glass reads as a see-through screen."""
    x0, y0, w, h = SCREEN
    v, u = np.mgrid[0:h, 0:w]
    edge = np.minimum.reduce([u, w - 1 - u, v, h - 1 - v]).astype(np.float32)
    alpha = 0.34 * np.exp(-edge / 16.0)

    area = rgba[y0:y0 + h, x0:x0 + w].astype(np.float32)
    hole = area[:, :, 3] < 8                                 # the frame's own pixels stay as rendered
    area[:, :, :3][hole] = 0.0
    area[:, :, 3][hole] = (alpha * 255.0)[hole]
    rgba[y0:y0 + h, x0:x0 + w] = np.clip(area, 0, 255).astype(np.uint8)
    return rgba


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--png", help="folder to keep the final PNG in")
    args = ap.parse_args()

    tool = imagetopaa.find_imagetopaa()
    if not tool:
        raise SystemExit("ImageToPAA not found - set IMAGETOPAA")
    with tempfile.TemporaryDirectory() as work:
        path = os.path.join(work, "monitor.png")
        subprocess.run([render_icon.find_blender(), "-b", "--factory-startup", "-P",
                        os.path.join(HERE, "tools", "blender_monitor.py"), "--", path],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        rgba = np.array(Image.open(path).convert("RGBA"))
    if (rgba.shape[1], rgba.shape[0]) != CANVAS:
        raise SystemExit("render came out %dx%d" % (rgba.shape[1], rgba.shape[0]))

    x0, y0, w, h = SCREEN
    middle = rgba[y0 + 8:y0 + h - 8, x0 + 8:x0 + w - 8, 3]
    if middle.max() > 8:
        raise SystemExit("the screen's hole is not where SCREEN says it is")
    full = glass(rgba)
    icon = render_icon.downsample(full, 2048, 1024)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    imagetopaa.to_paa(tool, icon, OUT)
    if args.png:
        os.makedirs(args.png, exist_ok=True)
        Image.fromarray(full, "RGBA").save(os.path.join(args.png, "monitor_full.png"))
    print("%s  2048x1024" % os.path.relpath(OUT, HERE))
    print("MONITOR_ASPECT   %.5f" % (CANVAS[1] / float(CANVAS[0])))
    print("MONITOR_SCREEN_X %.5f  Y %.5f  W %.5f  H %.5f" % (x0 / float(CANVAS[0]), y0 / float(CANVAS[1]),
                                                              w / float(CANVAS[0]), h / float(CANVAS[1])))


if __name__ == "__main__":
    main()
