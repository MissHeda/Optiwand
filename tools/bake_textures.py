# -*- coding: utf-8 -*-
"""Fold the four per-material bakes into one Arma texture set and write PAA.

The model came out of Blender with a separate 4096x4096 bake per material
(Plastik, Schlauch, blitz, cam) over one shared UV layout. Four materials on a
42 cm prop is three too many, so this composites them into a single set - one
_co, _nohq, _smdi, _as - by rasterising each material's UV islands and taking
that material's bake inside its own islands.

Everything outside every island is filled by dilating the island content
outwards. Without that, mipmapping drags the bake background into the
silhouette - and the _as background is fully occluded black, which would show up
as dirt around every edge.

Channel conventions, per Bohemia:
    _smdi   R unused, G specular level, B specular power
    _as     G is the only channel read
so those two are passed through as they are; only the neutral fill differs.

    python tools/bake_textures.py [--size 1024]
"""

import argparse
import glob
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fbx
import paa

MATERIALS = ["Plastik", "Schlauch", "blitz", "cam"]

# Fill for texels no material claims, per map. Chosen so a stray sample is invisible
# rather than a black smear.
NEUTRAL = {
    "co": (0, 0, 0, 255),
    "nohq": (128, 128, 255, 255),
    "smdi": (255, 0, 153, 255),
    "as": (255, 255, 255, 255),
}
SOURCE_SUFFIX = {"co": "CO", "nohq": "NOHQ", "smdi": "SMDI", "as": "AS"}

# Materials that make up the housing. These are the ones --tint acts on; the lens and the
# LEDs are signal colours and are left where the artist put them.
HOUSING = ("Plastik", "Schlauch")

# Median of Bohemia's own esd_01_co.paa, the Spectrum Device's colour texture, measured over
# the whole sheet. The wand's own bake sits at 19/19/19 - next to the device it reads almost
# black, which is what --tint is for.
SPECTRUM_GREY = (35, 36, 38)


def load_uv_islands(fbx_path, size, margin=0):
    """One 0/255 mask per material, in texture space (image row 0 is v = 1)."""
    root, _ = fbx.parse(fbx_path)
    geo = root.find("Objects").find("Geometry")
    uv_layer = geo.find("LayerElementUV")
    uv = uv_layer.find("UV").props[0]
    uv_index = uv_layer.find("UVIndex").props[0]
    poly_index = geo.find("PolygonVertexIndex").props[0]
    materials = geo.find("LayerElementMaterial").find("Materials").props[0]

    faces, current = [], []
    for slot, vertex in enumerate(poly_index):
        current.append(uv_index[slot])
        if vertex < 0:
            faces.append(current)
            current = []

    masks = []
    for mat_id in range(len(MATERIALS)):
        img = Image.new("L", (size, size), 0)
        draw = ImageDraw.Draw(img)
        for face, face_mat in zip(faces, materials):
            if face_mat != mat_id:
                continue
            pts = [(uv[i * 2] * size, (1.0 - uv[i * 2 + 1]) * size) for i in face]
            draw.polygon(pts, fill=255, outline=255)
        if margin:
            img = img.filter(ImageFilter.MaxFilter(margin * 2 + 1))
        masks.append(np.array(img) > 127)
    return masks


def dilate(rgba, filled, rounds):
    """Grow the filled region outwards, one texel a round, so mip levels stay clean."""
    for _ in range(rounds):
        if filled.all():
            break
        acc = np.zeros(rgba.shape, np.uint32)
        count = np.zeros(filled.shape, np.uint32)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            src = np.roll(np.roll(rgba, dy, axis=0), dx, axis=1)
            have = np.roll(np.roll(filled, dy, axis=0), dx, axis=1)
            acc += src * have[:, :, None]
            count += have
        grow = (~filled) & (count > 0)
        safe = np.maximum(count, 1)[:, :, None]
        rgba = np.where(grow[:, :, None], (acc // safe).astype(np.uint8), rgba)
        filled = filled | grow
    return rgba, filled


def tint_housing(sources, exact, target):
    """Lift the housing to a target colour, per channel, by gain rather than by offset.

    A gain keeps the bake's own contrast - panel lines, wear, the darker recesses stay
    exactly as far apart as they were, the whole thing just sits at a different level. An
    offset would flatten all of that towards the target.

    The gain is set from the median rather than the mean so a few blown highlights in the
    bake cannot drag it."""
    reference = np.concatenate(
        [sources[MATERIALS.index(m)][exact[MATERIALS.index(m)]][:, :3] for m in HOUSING],
        axis=0)
    if reference.size == 0:
        return sources, None, None

    median = np.median(reference, axis=0)
    gain = np.array(target, float) / np.maximum(median, 1.0)

    out = list(sources)
    for material in HOUSING:
        index = MATERIALS.index(material)
        data = sources[index].astype(np.float32)
        data[:, :, :3] = np.clip(data[:, :, :3] * gain, 0, 255)
        out[index] = data.astype(np.uint8)
    return out, median, gain


def composite(source_dir, exact, grown, kind, size, tint=None):
    """Paint each material inside its own UV islands, then let the margins spread only
    into texels no material owns.

    The margin used to be applied before painting, which let a material's margin write
    over the next one's real surface. blitz - eight tiny scattered islands over a brown
    LED bake - put 209 brown texels into the middle of the grey body that way, and they
    showed up in game as a scatter of small brown dots. Ownership comes first now, and the
    margin only ever fills no man's land."""
    out = np.zeros((size, size, 4), np.uint8)
    out[:] = NEUTRAL[kind]
    owned = np.zeros((size, size), bool)
    for mask in exact:
        owned |= mask

    sources = []
    for name in MATERIALS:
        path = os.path.join(source_dir, "%s_%s.png" % (name, SOURCE_SUFFIX[kind]))
        img = Image.open(path).convert("RGBA")
        if img.size != (size, size):
            img = img.resize((size, size), Image.BOX)
        sources.append(np.array(img))

    # Colour only. Tinting a normal map would bend the normals, and _smdi and _as are not
    # colours at all - green and blue there are specular and occlusion.
    if tint is not None and kind == "co":
        sources, median, gain = tint_housing(sources, exact, tint)
        if median is not None:
            print("  housing tinted  rgb %s -> %s   (gain %s)"
                  % (median.astype(int).tolist(), list(tint), gain.round(2).tolist()))

    filled = np.zeros((size, size), bool)
    for mat_id, data in enumerate(sources):
        out = np.where(exact[mat_id][:, :, None], data, out)
        filled |= exact[mat_id]
    for mat_id, data in enumerate(sources):
        margin = grown[mat_id] & ~owned & ~filled
        out = np.where(margin[:, :, None], data, out)
        filled |= margin

    out, _ = dilate(out, filled, rounds=max(8, size // 64))
    return out


def mip_chain(rgba):
    levels = [rgba]
    img = Image.fromarray(rgba, "RGBA")
    while min(img.size) > 4:
        img = img.resize((img.size[0] // 2, img.size[1] // 2), Image.BOX)
        levels.append(np.array(img))
    return levels


def pack_argb(rgb):
    r, g, b = (int(v) for v in rgb)
    return (0xFF << 24) | (r << 16) | (g << 8) | b


def write_paa(path, levels, kind):
    """A normal map goes out the way ImageToPAA writes one: the red channel lives in
    the DXT5 alpha block, inverted, and a SWIZ tagg tells the engine to put it back.
    Alpha carries a full byte per texel where the colour block gives red five bits,
    and red is where the normal's X sits."""
    normal = kind == "nohq"
    top = levels[0]
    average = pack_argb(top[:, :, :3].reshape(-1, 3).mean(axis=0).round())
    maximum = pack_argb(top[:, :, :3].reshape(-1, 3).max(axis=0))

    surfaces = []
    for level in levels:
        data = level
        if normal:
            data = level.copy()
            data[:, :, 3] = 255 - level[:, :, 0]
            data[:, :, 0] = 0
        raw = paa.encode_surface(data, dxt5=normal)
        surfaces.append((level.shape[1], level.shape[0], raw))

    kind_id = paa.TYPE_DXT5 if normal else paa.TYPE_DXT1
    swizzle = b"\x05\x04\x02\x03" if normal else None
    return paa.write(path, surfaces, kind_id, average, maximum, swizzle)


def find_imagetopaa():
    """ImageToPAA ships with the Arma 3 Tools. Where it is found it wins over the
    encoder in tools/paa.py: it is Bohemia's own, and it LZO-compresses the mipmaps,
    which is roughly a fifth of the file size. Set IMAGETOPAA to override the search."""
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


def convert_with_imagetopaa(tool, rgba, out_path):
    """The suffix of the file name is what picks the format: ImageToPAA reads its own
    TexConvert.cfg, which is where the rule that _nohq goes out as swizzled DXT5 lives.
    So the temporary PNG has to carry the final name, not a scratch one."""
    with tempfile.TemporaryDirectory() as work:
        png = os.path.join(work, os.path.basename(out_path).replace(".paa", ".png"))
        Image.fromarray(rgba, "RGBA").save(png)
        subprocess.run([tool, png, out_path], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return os.path.getsize(out_path)


def main():
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap = argparse.ArgumentParser()
    ap.add_argument("--fbx", default=os.path.join(here, "art", "esdcam", "arma3_cam.fbx"))
    ap.add_argument("--source", default=os.path.join(here, "art", "esdcam", "bake"))
    ap.add_argument("--out", default=os.path.join(here, "addons", "esdcam", "data"))
    ap.add_argument("--name", default="camhead")
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--margin", type=int, default=2)
    ap.add_argument("--encoder", choices=("auto", "imagetopaa", "builtin"), default="auto")
    ap.add_argument("--tint", default=",".join(str(c) for c in SPECTRUM_GREY),
                    help="target colour of the housing as R,G,B, or 'none' to keep the bake "
                         "as it is. Default is the Spectrum Device's own grey.")
    args = ap.parse_args()

    tint = None
    if args.tint.lower() not in ("none", "off", ""):
        tint = [int(v) for v in args.tint.replace(" ", "").split(",")]
        if len(tint) != 3:
            raise SystemExit("--tint wants three numbers, e.g. --tint 35,36,38")

    tool = None if args.encoder == "builtin" else find_imagetopaa()
    if args.encoder == "imagetopaa" and not tool:
        raise SystemExit("ImageToPAA not found. Set IMAGETOPAA, or use --encoder builtin.")
    print("encoder: %s" % (tool or "built in (tools/paa.py)"))

    print("UV islands from %s at %d px" % (os.path.basename(args.fbx), args.size))
    exact = load_uv_islands(args.fbx, args.size)
    grown = load_uv_islands(args.fbx, args.size, args.margin)
    for name, mask in zip(MATERIALS, exact):
        print("  %-9s %5.2f %% of the sheet" % (name, 100.0 * mask.mean()))

    for kind in ("co", "nohq", "smdi", "as"):
        rgba = composite(args.source, exact, grown, kind, args.size, tint)
        out = os.path.join(args.out, "%s_%s.paa" % (args.name, kind))
        if tool:
            size = convert_with_imagetopaa(tool, rgba, out)
        else:
            size = write_paa(out, mip_chain(rgba), kind)
        print("  %-18s %6d KB" % (os.path.basename(out), size // 1024))


if __name__ == "__main__":
    main()
