# -*- coding: utf-8 -*-
"""
Turns the camera model in Blender into the muzzle attachment camhead.p3d, baked texture
included, so the Blender materials reach the game.

To run: open the .blend, Scripting tab, load this file, Run.
The source objects are left untouched - work happens on a copy called OPW_CamHead.

--------------------------------------------------------------------------------------
Why anything is baked

Arma cannot read Blender node trees. Noise and wave textures, bump, glass - all of that
exists only in Blender. The one way to bring that look into the game is to bake it into an
image and ship that image as a texture. BAKE below is what does it.

--------------------------------------------------------------------------------------
Why the orientation is what it is

Measured against the three vanilla antennas of the Spectrum Device, read out of their p3d:

    muzzle_antenna_01_F   X -0.392 .. +0.007    40 cm
    muzzle_antenna_02_F   X -0.410 .. +0.298    71 cm
    muzzle_antenna_03_F   X -0.557 .. +0.000    56 cm

All three sit with their origin at the device and extend along -X. That is exactly where
this script puts the model: mount at (0,0,0), camera head at x = -LENGTH.

Axes: the exporter writes Blender (x,y,z) as Arma (x,z,y), so the long axis lies on X in
both worlds.
"""

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

# ---------------------------------------------------------------------------------- Knobs
SRC_NAMES = []                  # empty = take every visible mesh object in the scene
SKIP_PREFIX = ("REF_", "OPW_")  # never collect the reference rig or our own work copies

WORK = "OPW_CamHead"
LENGTH = 0.42                   # overall length in metres
MASS = 0.5                      # kg in the geometry LOD

# Which end goes into the device.
#
# False, meaning the thick one: the flange is the mount and the camera head is the thin end.
# This was read the wrong way round at first - the many vertices at the thin end are the
# concentric rings of the optic, not a connector.
MOUNT_AT_THIN_END = False

BAKE = True                     # bake the Blender materials into a texture
BAKE_SIZE = 2048
BAKE_NORMAL = True              # also a normal map, which brings the ribbing along
REUNWRAP = True                 # re-unwrap when the existing UV uses too little of the tile
# Healthy band for the occupied UV area. Too little means wasted resolution; above 1.0 means
# overlapping islands, where one spot in the texture paints several spots on the model and
# the bake becomes useless. The model came in at 3.95, so heavily overlapped.
UV_MIN_COVERAGE = 0.35
UV_MAX_COVERAGE = 1.05

LOD_RESOLUTION = "-1.0"         # Toolbox enum; the numeric value lives in lodDistance
LOD_GEOMETRY = "1.000e+13"
LOD_MEMORY = "1.000e+15"

# Where to write the p3d and the baked textures.
#
# Normally found on its own: this file lives in <repo>/tools, so the repo is one level up.
# Blender's text editor does not always set __file__ though - when the script is pasted in
# rather than opened from disk - so there are two fallbacks: the OPTIWAND_ROOT environment
# variable, and REPO_ROOT below for setting it by hand.
REPO_ROOT = ""


def find_repo():
    def looks_right(p):
        return bool(p) and os.path.isdir(os.path.join(p, "addons"))

    if looks_right(REPO_ROOT):
        return REPO_ROOT

    here = globals().get("__file__")
    if here:
        guess = os.path.dirname(os.path.dirname(os.path.abspath(here)))
        if looks_right(guess):
            return guess

    env = os.environ.get("OPTIWAND_ROOT")
    if looks_right(env):
        return env

    return None

notes = {}


# -------------------------------------------------------------------------------- Tools
def enable_toolbox():
    if hasattr(bpy.types.Object, "armaObjProps"):
        return "was already on"
    names = ["bl_ext.user_default.ArmaToolbox", "ArmaToolbox"]
    try:
        import addon_utils
        for mod in addon_utils.modules():
            if "armatoolbox" in mod.__name__.lower() and mod.__name__ not in names:
                names.append(mod.__name__)
    except Exception:
        pass
    for name in names:
        try:
            bpy.ops.preferences.addon_enable(module=name)
            if hasattr(bpy.types.Object, "armaObjProps"):
                return "switched on: %s" % name
        except Exception:
            continue
    return "FAILED - enable it by hand under Edit > Preferences > Add-ons"


def set_lod(obj, lod_id, distance=0.0):
    p = getattr(obj, "armaObjProps", None)
    if p is None:
        return "no armaObjProps"
    bad = []
    for attr, val in (("isArmaObject", True), ("lod", lod_id), ("lodDistance", distance)):
        try:
            setattr(p, attr, val)
        except Exception as exc:
            bad.append("%s -> %s" % (attr, exc))
    return "; ".join(bad) if bad else "ok"


def set_material(mat, texture, rvmat=""):
    p = getattr(mat, "armaMatProps", None)
    if p is None:
        return "no armaMatProps"
    for attr, val in (("texType", "Texture"), ("texture", texture), ("rvMat", rvmat)):
        try:
            setattr(p, attr, val)
        except Exception:
            pass
    return "ok"


def drop(name, keep_active):
    """Remove an object. Never the active one - Blender hard crashes with no error."""
    old = bpy.data.objects.get(name)
    if old is None:
        return
    if keep_active is not None and keep_active.name in bpy.context.view_layer.objects:
        bpy.context.view_layer.objects.active = keep_active
    me_old = old.data
    bpy.data.objects.remove(old, do_unlink=True)
    if me_old is not None and me_old.users == 0:
        bpy.data.meshes.remove(me_old)


# ---------------------------------------------------------------------------- Start
notes["toolbox"] = enable_toolbox()

if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
    bpy.ops.object.mode_set(mode="OBJECT")

if SRC_NAMES:
    sources = [bpy.data.objects[n] for n in SRC_NAMES if n in bpy.data.objects]
else:
    sources = [o for o in bpy.context.scene.objects
               if o.type == "MESH" and not o.name.startswith(SKIP_PREFIX)]
if not sources:
    raise SystemExit("No source objects found")
notes["sources"] = [o.name for o in sources]

coll = sources[0].users_collection[0] if sources[0].users_collection \
    else bpy.context.scene.collection

for nm in (WORK, WORK + "Geo", WORK + "Mem"):
    drop(nm, sources[0])

# ---------------------------------------------------------------------- Merge the parts
#
# Through the evaluated object so modifiers come along - the model uses Mirror for the mount
# and "Smooth by Angle" for the edges. Without that half the geometry would be missing.
dg = bpy.context.evaluated_depsgraph_get()
copies = []
for o in sources:
    c = bpy.data.objects.new(WORK + "_part", bpy.data.meshes.new_from_object(o.evaluated_get(dg)))
    c.matrix_world = o.matrix_world
    coll.objects.link(c)
    copies.append(c)

for ob in bpy.context.view_layer.objects:
    ob.select_set(False)
for c in copies:
    c.select_set(True)
bpy.context.view_layer.objects.active = copies[0]
if len(copies) > 1:
    bpy.ops.object.join()

work = bpy.context.view_layer.objects.active
work.name = WORK
work.data.name = WORK

# Bake the transforms in without an operator: apply the object matrix straight to the verts.
work.data.transform(work.matrix_world)
work.matrix_world = Matrix.Identity(4)
me = work.data

# Resolve n-gons. Only those - the exporter accepts quads.
bm = bmesh.new()
bm.from_mesh(me)
ngons = [f for f in bm.faces if len(f.verts) > 4]
notes["ngons"] = len(ngons)
if ngons:
    bmesh.ops.triangulate(bm, faces=ngons)
bm.to_mesh(me)
bm.free()


def bounds():
    lo = Vector([min(v.co[i] for v in me.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in me.vertices) for i in range(3)])
    return lo, hi


# ------------------------------------------------------------------------------- Orient
lo, hi = bounds()
long_ax = max(range(3), key=lambda i: hi[i] - lo[i])
perp = [i for i in range(3) if i != long_ax]
span = hi[long_ax] - lo[long_ax]
mid = [(lo[i] + hi[i]) / 2.0 for i in range(3)]


def edge_radius(at_max):
    rs = []
    for v in me.vertices:
        t = (v.co[long_ax] - lo[long_ax]) / span
        if (t > 0.9) if at_max else (t < 0.1):
            rs.append(((v.co[perp[0]] - mid[perp[0]]) ** 2
                       + (v.co[perp[1]] - mid[perp[1]]) ** 2) ** 0.5)
    return max(rs) if rs else 0.0


thin_at_max = edge_radius(True) < edge_radius(False)
notes["thin_end"] = "max" if thin_at_max else "min"
mount_at_max = thin_at_max if MOUNT_AT_THIN_END else (not thin_at_max)

# Turn the long axis onto X, with the mount end towards +X.
if long_ax == 1:
    me.transform(Matrix.Rotation(math.radians(-90.0 if mount_at_max else 90.0), 4, "Z"))
elif long_ax == 2:
    me.transform(Matrix.Rotation(math.radians(90.0 if mount_at_max else -90.0), 4, "Y"))
elif not mount_at_max:
    me.transform(Matrix.Rotation(math.radians(180.0), 4, "Z"))

lo, hi = bounds()
me.transform(Matrix.Translation((-hi.x, -(lo.y + hi.y) / 2.0, -(lo.z + hi.z) / 2.0)))
lo, hi = bounds()
me.transform(Matrix.Scale(LENGTH / (hi.x - lo.x), 4))
lo, hi = bounds()
notes["length_cm"] = round((hi.x - lo.x) * 100, 2)
notes["across_cm"] = [round((hi.y - lo.y) * 100, 2), round((hi.z - lo.z) * 100, 2)]

# ----------------------------------------------------------------------------- Check UV
root = find_repo()
notes["repo"] = root


def uv_coverage():
    """Fraction of the tile the islands occupy by area.

    Ueber die Dreiecksflaeche, nicht ueber abgetastete Eckpunkte: eine grosse Insel hat nur
    drei Ecken und wuerde beim Abtasten als fast leer gelten. Genau daran hat die erste
    Fassung die Abdeckung dramatisch unterschaetzt.
    """
    if not me.uv_layers:
        return 0.0
    uvs = me.uv_layers.active.data
    total = 0.0
    for p in me.polygons:
        li = list(p.loop_indices)
        a = uvs[li[0]].uv
        for k in range(1, len(li) - 1):
            b, c = uvs[li[k]].uv, uvs[li[k + 1]].uv
            total += abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)) * 0.5
    return total


cov = uv_coverage()
notes["uv_coverage_before"] = round(cov, 3)

if BAKE and REUNWRAP and (cov < UV_MIN_COVERAGE or cov > UV_MAX_COVERAGE):
    # The supplied UV uses too little of the tile - baked, the texture would be mostly empty
    # and the model correspondingly coarse in game. Re-unwrapping costs nothing here, because
    # the Blender materials are procedural and need no UV at all.
    for ob in bpy.context.view_layer.objects:
        ob.select_set(False)
    work.select_set(True)
    bpy.context.view_layer.objects.active = work
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.01)
    # Pack tightly again after unwrapping. Smart Project otherwise leaves much of the tile
    # unused, and unused tile means resolution thrown away on the model.
    try:
        bpy.ops.uv.select_all(action="SELECT")
        bpy.ops.uv.average_islands_scale()
        bpy.ops.uv.pack_islands(rotate=True, margin=0.01)
    except Exception as exc:
        notes["uv_pack"] = str(exc)
    bpy.ops.object.mode_set(mode="OBJECT")
    notes["uv"] = "re-unwrapped"
    notes["uv_coverage_after"] = round(uv_coverage(), 3)
else:
    notes["uv"] = "used existing"

# ---------------------------------------------------------------- Backen
BAKED_CO = "camhead_co"
BAKED_NOHQ = "camhead_nohq"
art = os.path.join(root, "art", "esdcam") if root else None


def relink_missing_images():
    """Look for missing image textures next to the .blend.

    If one is missing, Blender bakes magenta at that spot - which is exactly what showed up
    on the optic in the first run.
    """
    missing = [i.name for i in bpy.data.images
               if i.source == "FILE" and i.filepath
               and not os.path.exists(bpy.path.abspath(i.filepath))]
    if not missing:
        return "none were missing"
    here = os.path.dirname(bpy.data.filepath) or os.path.expanduser("~")
    try:
        bpy.ops.file.find_missing_files(directory=here)
    except Exception as exc:
        return "search failed: %s" % exc
    still = [i.name for i in bpy.data.images
             if i.source == "FILE" and i.filepath
             and not os.path.exists(bpy.path.abspath(i.filepath))]
    return "%d were missing, %d still missing" % (len(missing), len(still))


def demetal(restore=None):
    """Metallic to zero before baking, back afterwards.

    A diffuse bake yields base_color * (1 - metallic). For metallic materials that is black
    by definition. For Arma we want the base colour in the _co texture; the metallic
    impression comes from the specular in the rvmat anyway.
    """
    if restore is not None:
        for node, val in restore:
            node.inputs["Metallic"].default_value = val
        return None
    saved = []
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        for node in mat.node_tree.nodes:
            if node.type == "BSDF_PRINCIPLED" and "Metallic" in node.inputs:
                inp = node.inputs["Metallic"]
                if not inp.is_linked and inp.default_value > 0.0:
                    saved.append((node, inp.default_value))
                    inp.default_value = 0.0
    return saved


def bake_pass(kind, image_name, filename, colorspace):
    """One bake pass onto a fresh image, then saved as PNG."""
    img = bpy.data.images.get(image_name)
    if img is not None:
        bpy.data.images.remove(img)
    img = bpy.data.images.new(image_name, BAKE_SIZE, BAKE_SIZE,
                              alpha=False, float_buffer=False)
    img.colorspace_settings.name = colorspace

    # Every material needs an active image texture node as the bake target.
    nodes_added = []
    for slot in work.material_slots:
        mat = slot.material
        if mat is None:
            # Empty slot - merging brings these in from parts with no material of their own.
            # Left unfilled, the bake reports "No active image found in material slot" and
            # leaves those faces unpainted.
            mat = bpy.data.materials.get("opw_camhead_fill") \
                or bpy.data.materials.new("opw_camhead_fill")
            mat.use_nodes = True
            slot.material = mat
        if not mat.use_nodes:
            mat.use_nodes = True
        node = mat.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = img
        node.select = True
        mat.node_tree.nodes.active = node
        nodes_added.append((mat, node))

    for ob in bpy.context.view_layer.objects:
        ob.select_set(False)
    work.select_set(True)
    bpy.context.view_layer.objects.active = work

    try:
        bpy.ops.object.bake(type=kind, use_clear=True, margin=8)
        ok = "ok"
    except Exception as exc:
        ok = "FEHLER: %s" % exc

    for mat, node in nodes_added:
        mat.node_tree.nodes.remove(node)

    path = None
    if ok == "ok" and art:
        if not os.path.isdir(art):
            os.makedirs(art)
        path = os.path.join(art, filename)
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
    return ok, path


if BAKE and root:
    sc = bpy.context.scene
    prev_engine = sc.render.engine
    sc.render.engine = "CYCLES"
    try:
        sc.cycles.device = "CPU"
        sc.cycles.samples = 16
    except Exception:
        pass
    sc.render.bake.use_pass_direct = False
    sc.render.bake.use_pass_indirect = False
    sc.render.bake.use_pass_color = True
    sc.render.bake.margin = 8

    notes["images"] = relink_missing_images()

    # Unhook metallic for the colour pass only; for the normal map it makes no difference.
    saved = demetal()
    notes["metallic_zeroed"] = len(saved)
    notes["bake_co"], notes["path_co"] = bake_pass(
        "DIFFUSE", BAKED_CO, "camhead_co.png", "sRGB")
    demetal(saved)

    if BAKE_NORMAL:
        notes["bake_nohq"], notes["path_nohq"] = bake_pass(
            "NORMAL", BAKED_NOHQ, "camhead_nohq.png", "Non-Color")
    sc.render.engine = prev_engine

# ----------------------------------------------------------------------- Arma material
#
# After baking, a single material carries the whole look. Colour comes from the baked
# texture, lighting from the rvmat.
me.materials.clear()
mat = bpy.data.materials.get("opw_camhead") or bpy.data.materials.new("opw_camhead")
sep = os.sep
if BAKE:
    tex = "z" + sep + "opw" + sep + "addons" + sep + "esdcam" + sep + "data" + sep + "camhead_co.paa"
else:
    tex = "#(argb,8,8,3)color(0.180,0.185,0.195,1)"
rv = "z" + sep + "opw" + sep + "addons" + sep + "esdcam" + sep + "data" + sep + "camhead.rvmat"
notes["material"] = set_material(mat, tex, rv)
me.materials.append(mat)
for p in me.polygons:
    p.material_index = 0
me.update()

# ------------------------------------------------------------------------------- LODs
notes["resolution"] = set_lod(work, LOD_RESOLUTION, 0.0)

# Geometry: a simple box. Arma wants convex bodies here, and a copy of the visual model
# would be neither convex nor necessary - the attachment does not get shot at.
lo, hi = bounds()
gv = [(x, y, z) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
gf = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
gme = bpy.data.meshes.new(WORK + "Geo")
gme.from_pydata(gv, [], gf)
gme.update()
geo = bpy.data.objects.new(WORK + "Geo", gme)
coll.objects.link(geo)
notes["geometry"] = set_lod(geo, LOD_GEOMETRY, 0.0)

# The exporter reads mass from a bmesh float layer called "FHQWeights", not from
# armaObjProps.mass. Without that layer the export aborts with a KeyError.
bm = bmesh.new()
bm.from_mesh(geo.data)
layer = bm.verts.layers.float.get("FHQWeights") or bm.verts.layers.float.new("FHQWeights")
for v in bm.verts:
    v[layer] = MASS / max(1, len(bm.verts))
bm.to_mesh(geo.data)
bm.free()
try:
    geo.armaObjProps.mass = MASS
except Exception:
    pass

# Memory points. muzzlePos and muzzleEnd from the ItemInfo point here; the vector from
# "konec hlavne" to "usti hlavne" is the view direction, -X here as on the antennas.
mme = bpy.data.meshes.new(WORK + "Mem")
mme.from_pydata([(lo.x, 0.0, 0.0), (lo.x + 0.05, 0.0, 0.0)], [], [])
mme.update()
mem = bpy.data.objects.new(WORK + "Mem", mme)
coll.objects.link(mem)
notes["memory"] = set_lod(mem, LOD_MEMORY, 1.0)
for gname, idx in (("usti hlavne", 0), ("konec hlavne", 1)):
    mem.vertex_groups.new(name=gname).add([idx], 1.0, "REPLACE")

# ----------------------------------------------------------------------------- Export
out = os.path.join(root, "addons", "esdcam", "model", "camhead.p3d") if root else None

for ob in bpy.context.view_layer.objects:
    ob.select_set(False)
for ob in (work, geo, mem):
    ob.select_set(True)
bpy.context.view_layer.objects.active = work

found = []
for modname in dir(bpy.ops):
    try:
        mod = getattr(bpy.ops, modname)
    except Exception:
        continue
    for opname in dir(mod):
        if "p3d" in (modname + "." + opname).lower():
            found.append((modname, opname))
picked = next((f for f in found if "export" in (f[0] + f[1]).lower()
               and "batch" not in f[1].lower()), None)

if picked is None:
    notes["export"] = "no p3d export operator found"
elif out is None:
    notes["export"] = "repo not found - set REPO_ROOT or OPTIWAND_ROOT"
else:
    op = getattr(getattr(bpy.ops, picked[0]), picked[1])
    try:
        keys = sorted(op.get_rna_type().properties.keys())
    except Exception:
        keys = []
    # mergeSameLOD off: one object per LOD, so there is nothing to merge.
    extra = {"mergeSameLOD": False} if "mergeSameLOD" in keys else {}
    if not os.path.isdir(os.path.dirname(out)):
        os.makedirs(os.path.dirname(out))
    try:
        op(filepath=out, **extra)
        notes["export"] = ("ok, %d KB" % (os.path.getsize(out) // 1024)) \
            if os.path.exists(out) else "operator ran, file missing"
    except Exception as exc:
        notes["export"] = "FEHLER: %s" % exc

notes["tris"] = sum(len(p.vertices) - 2 for p in me.polygons)
notes["target"] = out

print("=" * 74)
for k in ("toolbox", "sources", "ngons", "thin_end", "length_cm", "across_cm", "tris",
          "uv", "uv_coverage_before", "uv_coverage_after", "uv_pack",
          "images", "metallic_zeroed",
          "bake_co", "path_co", "bake_nohq", "path_nohq",
          "material", "resolution", "geometry", "memory", "export", "target"):
    if k in notes:
        print("  %-20s %s" % (k, notes[k]))
