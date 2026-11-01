# -*- coding: utf-8 -*-
"""Bohemia's ImageToPAA, from the Arma 3 Tools, in both directions."""

import glob
import os
import subprocess
import tempfile

from PIL import Image


def find_imagetopaa():
    """ImageToPAA ships with the Arma 3 Tools, which keep no registry entry, so the usual
    Steam libraries are searched. Set IMAGETOPAA to override the search."""
    override = os.environ.get("IMAGETOPAA")
    if override:
        return override if os.path.isfile(override) else None
    for drive in "CDEFG":
        for library in ("Steam", "SteamLibrary", "Program Files (x86)/Steam"):
            found = glob.glob("%s:/%s/steamapps/common/Arma 3 Tools/ImageToPAA/ImageToPAA.exe"
                              % (drive, library))
            if found:
                return found[0]
    return None


def to_paa(tool, rgba, out_path):
    """The suffix of the file name is what picks the format: ImageToPAA reads its own
    TexConvert.cfg, which is where the rule that _nohq goes out as swizzled DXT5 lives.
    So the temporary PNG has to carry the final name, not a scratch one."""
    with tempfile.TemporaryDirectory() as work:
        png = os.path.join(work, os.path.basename(out_path).replace(".paa", ".png"))
        Image.fromarray(rgba, "RGBA").save(png)
        subprocess.run([tool, png, out_path], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return os.path.getsize(out_path)


def to_png(tool, paa_path, png_path):
    """The other way round - the only reader here for Bohemia's LZO compressed PAAs."""
    subprocess.run([tool, paa_path, png_path], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return png_path
