# -*- coding: utf-8 -*-
"""Render the two inventory pictures for the attachment, in Bohemia's own style.

Arma wants two different things and they are not interchangeable:

  item   the picture in the arsenal and in the item slot. 512 x 512, three quarter
         view. `picture` in CfgWeapons.
  slot   the overlay that is drawn onto the weapon's own inventory picture to show
         the attachment fitted. 256 x 128, flat side on. `iconPicture` in the
         weapon's WeaponSlotsInfo slot - per slot, which is why the device carries
         one muzzle slot per attachment.

The model is on Bohemia's textures, so it is rendered with them: Blender, Cycles, an
orthographic camera, the device's own _co, _as, _smdi and _nohq. Layouts are measured off
Bohemia's files rather than composed by eye:

    gear_muzzle_antenna_01_ca      512 x 512   mount 496.9, 250.0   axis 11.4 deg
    gear_muzzle_antenna_02_ca      512 x 512   mount 502.2, 103.1   axis  5.9 deg
    gear_muzzle_antenna_03_ca      512 x 512   mount 500.0, 228.8   axis  9.0 deg
    hgun_esd_01_antenna_01_f_ca    256 x 128   mount 175.6,  63.5   flat
    hgun_esd_01_antenna_03_f_ca    256 x 128   mount 247.0,  63.7   flat

The 512s all hang their mount at x = 500 and run away to the left, and like antenna 02's
the coax leaves the picture on the right. The slot overlay is laid out like antenna 02's
instead of antenna 03's, because it has to show the coax too: the wand to the left of the
mount and the loop into the device to the right of it. That moves the mount off the right
edge, and MuzzleSlot4's iconPosition with it - see CfgWeapons.hpp.

Brightness is anchored to Bohemia's pictures through their own model: antenna 03 is
rendered through exactly the same setup, its median is compared with the median of
gear_muzzle_antenna_03_ca, and the curve that takes one to the other is applied to the
wand. The wand ends up as much lighter or darker than antenna 03 as it really is.

    python tools/render_icon.py [--preset item|slot]

Needs Blender (BLENDER, or the Steam install), the Arma 3 Tools, Bohemia's Spectrum Device
textures unpacked (--bi-data, or OPW_BI_DATA) and art/esdcam/reference/ for the anchor.
"""

import argparse
import glob
import json
import math
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_camhead
import imagetopaa

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LENGTH = build_camhead.DEFAULT_LENGTH
REFERENCE_LENGTH = 0.5563  # muzzle_antenna_03_F

# name: (width, height, yaw, pitch, mount pixel, tip pixel, reference median, output file)
#
# The reference median is Bohemia's own picture of antenna 03, over its opaque pixels:
#
#     gear_muzzle_antenna_03_ca      median 55.0   max 184
#     hgun_esd_01_antenna_03_f_ca    median 49.3   max  80
PRESETS = {
    "item": (512, 512, 0.62, 0.30, (500.0, 236.0), (16.0, 314.0), 55.0, "gear_camhead_ca.paa"),
    # Flat side on. 275 px per metre - a little under antenna 02's 330 - so wand and coax
    # loop both fit: tip at 6, mount at 165, the loop's far end at about 250.
    "slot": (256, 128, 0.0, 0.0, (165.0, 64.0), (6.0, 64.0), 49.3,
             "hgun_esd_01_camhead_F_ca.paa"),
}
# Where antenna 03 goes in its own pictures, for the brightness anchor.
REFERENCE_LAYOUT = {
    "item": ((500.0, 228.8), 9.0),
    "slot": ((247.0, 63.7), 0.0),
}


def find_blender():
    override = os.environ.get("BLENDER")
    if override:
        return override
    for pattern in ("%s:/SteamLibrary/steamapps/common/Blender/blender.exe",
                    "%s:/Steam/steamapps/common/Blender/blender.exe",
                    "%s:/Program Files/Blender Foundation/Blender*/blender.exe"):
        for drive in "CDEFG":
            found = sorted(glob.glob(pattern % drive))
            if found:
                return found[-1]
    raise SystemExit("Blender not found - set BLENDER")


def find_bi_data(arg):
    for candidate in (arg, os.environ.get("OPW_BI_DATA"),
                      r"E:\KAM arma 3 (P drive)\a3\weapons_f_enoch\pistols\esd_01\data",
                      r"P:\a3\weapons_f_enoch\pistols\esd_01\data"):
        if candidate and os.path.isfile(os.path.join(candidate, "esd_01_co.paa")):
            return candidate
    raise SystemExit("Bohemia's esd_01 textures not found - unpack weapons_f_enoch.pbo and "
                     "pass its pistols\\esd_01\\data folder as --bi-data")


def camera(yaw, pitch, mount_px, tip_px, width, height, length):
    """An orthographic camera that puts the mount (the origin) and the tip (-length on X)
    on the given pixels. Directions in Blender's axes, which are Arma's with Y and Z
    swapped."""
    cy, sy, cp, sp = math.cos(yaw), math.sin(yaw), math.cos(pitch), math.sin(pitch)
    # In Arma's axes: X right and Y up on screen for yaw = pitch = 0, looking along +Z.
    right = np.array([cy, 0.0, -sy])
    up = np.array([sp * sy, cp, sp * cy])
    forward = np.array([cp * sy, -sp, cp * cy])
    swap = lambda v: np.array([v[0], v[2], v[1]])
    right, up, forward = swap(right), swap(up), swap(forward)

    tip = np.array([-length, 0.0, 0.0])
    seen = np.array([tip @ right, tip @ up])
    wanted = np.array([tip_px[0] - mount_px[0], -(tip_px[1] - mount_px[1])])
    roll = math.atan2(wanted[1], wanted[0]) - math.atan2(seen[1], seen[0])
    right, up = (math.cos(roll) * right - math.sin(roll) * up,
                 math.sin(roll) * right + math.cos(roll) * up)
    per_metre = np.linalg.norm(wanted) / np.linalg.norm(seen)

    dx = (mount_px[0] - width / 2.0) / per_metre
    dy = (height / 2.0 - mount_px[1]) / per_metre
    location = -right * dx - up * dy - forward * 3.0
    return {"right": right.tolist(), "up": up.tolist(), "forward": forward.tolist(),
            "location": location.tolist(), "ortho_scale": max(width, height) / per_metre}


def calibrate(rgb, gamma):
    """A power curve rather than a gain: it moves the middle and leaves both ends where
    they are, so nothing clips."""
    return np.clip(255.0 * (rgb.astype(np.float32) / 255.0) ** gamma, 0, 255).astype(np.uint8)


def median(rgba):
    covered = rgba[:, :, 3] > 128
    return float(np.median(rgba[:, :, :3][covered].astype(np.float32).mean(axis=1)))


def downsample(rgba, width, height):
    """Premultiplied, so the transparent black round the silhouette does not bleed into the
    edge pixels as a dark fringe."""
    pre = rgba.astype(np.float32)
    pre[:, :, :3] *= pre[:, :, 3:4] / 255.0
    small = np.array(Image.fromarray(pre.astype(np.uint8), "RGBA").resize((width, height), Image.BOX),
                     np.float32)
    alpha = small[:, :, 3:4]
    small[:, :, :3] = np.where(alpha > 0, small[:, :, :3] * 255.0 / np.maximum(alpha, 1), 0)
    return np.clip(small, 0, 255).astype(np.uint8)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preset", choices=sorted(PRESETS) + ["all"], default="all")
    ap.add_argument("--model", default=os.path.join(HERE, "addons", "esdcam", "model", "camhead.p3d"))
    ap.add_argument("--reference", default=os.path.join(
        HERE, "art", "esdcam", "reference", "muzzle_antenna_03_F_mlod.p3d"))
    ap.add_argument("--bi-data")
    ap.add_argument("--supersample", type=int, default=2)
    ap.add_argument("--samples", type=int, default=128)
    ap.add_argument("--png", help="folder to keep the final PNGs in")
    args = ap.parse_args()

    tool = imagetopaa.find_imagetopaa()
    if not tool:
        raise SystemExit("ImageToPAA not found - set IMAGETOPAA")
    blender = find_blender()
    bi_data = find_bi_data(args.bi_data)
    presets = sorted(PRESETS) if args.preset == "all" else [args.preset]

    with tempfile.TemporaryDirectory() as work:
        maps = {}
        for name in ("co", "as", "smdi", "nohq"):
            maps[name] = imagetopaa.to_png(tool, os.path.join(bi_data, "esd_01_%s.paa" % name),
                                           os.path.join(work, "esd_01_%s.png" % name))
        lens_co, white, flat = (os.path.join(work, n + ".png") for n in ("lens_co", "white", "flat"))
        Image.fromarray(build_camhead.lens_colour(), "RGBA").save(lens_co)
        Image.new("RGB", (8, 8), (255, 255, 255)).save(white)
        Image.new("RGB", (8, 8), (128, 128, 255)).save(flat)
        lens = {"co": lens_co, "as": white, "smdi": white, "nohq": flat}
        # The rubber's rvmat darkens the atlas through its ambient and diffuse, which the
        # render does not read, so the atlas itself goes darker here.
        rubber_co = os.path.join(work, "rubber_co.png")
        Image.fromarray((np.array(Image.open(maps["co"]).convert("RGB")) * 0.5).astype(np.uint8)).save(rubber_co)
        rubber = dict(maps, co=rubber_co, nohq=flat)

        jobs = []
        for preset in presets:
            width, height, yaw, pitch, mount_px, tip_px, _target, _file = PRESETS[preset]
            s = args.supersample
            jobs.append({"p3d": args.model, "lod": 1.0, "width": width * s, "height": height * s,
                         "out": os.path.join(work, preset + ".png"),
                         "camera": camera(yaw, pitch, (mount_px[0] * s, mount_px[1] * s),
                                          (tip_px[0] * s, tip_px[1] * s), width * s, height * s, LENGTH)})
            if os.path.isfile(args.reference):
                (rx, ry), axis = REFERENCE_LAYOUT[preset]
                span = abs(tip_px[0] - mount_px[0]) * REFERENCE_LENGTH / LENGTH
                ref_tip = (rx - span * math.cos(math.radians(axis)), ry + span * math.sin(math.radians(axis)))
                jobs.append({"p3d": args.reference, "lod": 1.0, "width": width * s, "height": height * s,
                             "out": os.path.join(work, preset + "_reference.png"),
                             "camera": camera(yaw, pitch, (rx * s, ry * s), (ref_tip[0] * s, ref_tip[1] * s),
                                              width * s, height * s, REFERENCE_LENGTH)})

        spec = {"samples": args.samples, "jobs": jobs, "materials": {
            build_camhead.MATERIAL: maps, build_camhead.RUBBER_MATERIAL: rubber,
            build_camhead.LENS_MATERIAL: lens}}
        spec_path = os.path.join(work, "jobs.json")
        json.dump(spec, open(spec_path, "w"))
        subprocess.run([blender, "-b", "--factory-startup", "-P",
                        os.path.join(HERE, "tools", "blender_render.py"), "--", spec_path],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        for preset in presets:
            width, height, *_rest, target, filename = PRESETS[preset]
            rgba = np.array(Image.open(os.path.join(work, preset + ".png")).convert("RGBA"))
            reference = os.path.join(work, preset + "_reference.png")
            if os.path.isfile(reference):
                ref_median = median(np.array(Image.open(reference).convert("RGBA")))
                gamma = math.log(target / 255.0) / math.log(ref_median / 255.0)
                note = "antenna 03 renders at %.1f against Bohemia's %.1f" % (ref_median, target)
            else:
                gamma = math.log(target / 255.0) / math.log(median(rgba) / 255.0)
                note = "no reference - set to Bohemia's antenna 03 median directly"
            before = median(rgba)
            rgba[:, :, :3] = calibrate(rgba[:, :, :3], gamma)
            icon = downsample(rgba, width, height)
            out = os.path.join(HERE, "addons", "esdcam", "data", "ui", filename)
            imagetopaa.to_paa(tool, icon, out)
            if args.png:
                os.makedirs(args.png, exist_ok=True)
                Image.fromarray(icon, "RGBA").save(os.path.join(args.png, filename.replace(".paa", ".png")))
            print("%s  %dx%d  median %.1f -> %.1f  (%s)" % (
                os.path.relpath(out, HERE), width, height, before, median(icon), note))


if __name__ == "__main__":
    main()
