# -*- coding: utf-8 -*-
"""
Macht aus dem Kameramodell in Blender den Muendungsaufsatz camhead.p3d - inklusive
gebackener Textur, damit die Materialien aus Blender im Spiel ankommen.

Ausfuehren: die .blend oeffnen, Scripting-Tab, diese Datei laden, Run.
Die Quellobjekte bleiben unangetastet - gearbeitet wird auf einer Kopie namens OPW_CamHead.

--------------------------------------------------------------------------------------
Warum gebacken wird

Arma liest keine Blender-Node-Baeume. Rausch- und Wellentexturen, Bump, Glas - all das
existiert nur in Blender. Der einzige Weg, dieses Aussehen ins Spiel zu bringen, ist es
in ein Bild zu backen und dieses Bild als Textur mitzugeben. Genau das macht BAKE hier.

--------------------------------------------------------------------------------------
Warum die Ausrichtung so ist, wie sie ist

Gemessen an den drei Vanilla-Antennen des Spectrum Device, ausgelesen aus deren p3d:

    muzzle_antenna_01_F   X -0.392 .. +0.007    40 cm
    muzzle_antenna_02_F   X -0.410 .. +0.298    71 cm
    muzzle_antenna_03_F   X -0.557 .. +0.000    56 cm

Alle drei sitzen mit dem Ursprung am Geraet und erstrecken sich nach -X. Genau dorthin
bringt dieses Skript das Modell: Halterung auf (0,0,0), Kamerakopf bei x = -LENGTH.

Achsen: der Exporter schreibt Blender (x,y,z) als Arma (x,z,y). Die Laengsachse liegt also
in beiden Welten auf X.
"""

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

# ---------------------------------------------------------------------------- Stellschrauben
SRC_NAMES = []                  # leer = alle sichtbaren Mesh-Objekte der Szene nehmen
SKIP_PREFIX = ("REF_", "OPW_")  # Referenzrig und eigene Arbeitskopien nie einsammeln

WORK = "OPW_CamHead"
LENGTH = 0.42                   # Gesamtlaenge in Metern
MASS = 0.5                      # kg im Geometrie-LOD

# Welches Ende steckt im Geraet.
#
# False, also das dicke: der Flansch ist die Halterung, der Kamerakopf ist das duenne Ende.
# Andersherum gemessen hatte ich es zuerst falsch - die vielen Vertices am duennen Ende sind
# die konzentrischen Ringe der Optik, nicht ein Stecker.
MOUNT_AT_THIN_END = False

BAKE = True                     # Blender-Materialien in eine Textur backen
BAKE_SIZE = 2048
BAKE_NORMAL = True              # zusaetzlich eine Normal Map (holt die Riffelung mit)
REUNWRAP = True                 # neu auspacken, wenn die vorhandene UV zu wenig Flaeche nutzt
# Gesunde Spanne fuer die belegte UV-Flaeche. Zu wenig heisst verschenkte Aufloesung,
# ueber 1.0 heisst ueberlappende Inseln - dann malt eine Stelle der Textur mehrere Stellen
# des Modells an und der Bake wird unbrauchbar. Das Modell kam mit 3.95, also stark ueberlappt.
UV_MIN_COVERAGE = 0.35
UV_MAX_COVERAGE = 1.05

LOD_RESOLUTION = "-1.0"         # Toolbox-Enum, der Zahlenwert steckt in lodDistance
LOD_GEOMETRY = "1.000e+13"
LOD_MEMORY = "1.000e+15"

CANDIDATES = [
    r"C:\Users\Heda\GitHub Repos\Optiwand",
    r"C:\Users\Heda\GitHub Repos\Tactical-Mirror-Wand",
]

notes = {}


# ---------------------------------------------------------------------------- Werkzeug
def enable_toolbox():
    if hasattr(bpy.types.Object, "armaObjProps"):
        return "lief schon"
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
                return "eingeschaltet: %s" % name
        except Exception:
            continue
    return "FEHLGESCHLAGEN - von Hand unter Edit > Preferences > Add-ons einschalten"


def set_lod(obj, lod_id, distance=0.0):
    p = getattr(obj, "armaObjProps", None)
    if p is None:
        return "kein armaObjProps"
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
        return "kein armaMatProps"
    for attr, val in (("texType", "Texture"), ("texture", texture), ("rvMat", rvmat)):
        try:
            setattr(p, attr, val)
        except Exception:
            pass
    return "ok"


def drop(name, keep_active):
    """Objekt entfernen. Nie das aktive - Blender stuerzt sonst ohne Fehlermeldung ab."""
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
    raise SystemExit("Keine Quellobjekte gefunden")
notes["quellen"] = [o.name for o in sources]

coll = sources[0].users_collection[0] if sources[0].users_collection \
    else bpy.context.scene.collection

for nm in (WORK, WORK + "Geo", WORK + "Mem"):
    drop(nm, sources[0])

# ---------------------------------------------------------------- Teile zusammenfassen
#
# Ueber das ausgewertete Objekt, damit Modifier mitkommen - das Modell benutzt Mirror fuer
# die Halterung und "Smooth by Angle" fuer die Kanten. Ohne das fehlte die halbe Geometrie.
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

# Transformationen einbacken, ohne Operator: die Objektmatrix direkt auf die Vertices legen.
work.data.transform(work.matrix_world)
work.matrix_world = Matrix.Identity(4)
me = work.data

# N-Gons aufloesen. Nur die - Vierecke laesst der Exporter durch.
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


# ---------------------------------------------------------------- Ausrichten
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
notes["duennes_ende"] = "max" if thin_at_max else "min"
mount_at_max = thin_at_max if MOUNT_AT_THIN_END else (not thin_at_max)

# Laengsachse auf X drehen, Montage-Ende nach +X.
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
notes["laenge_cm"] = round((hi.x - lo.x) * 100, 2)
notes["quer_cm"] = [round((hi.y - lo.y) * 100, 2), round((hi.z - lo.z) * 100, 2)]

# ---------------------------------------------------------------- UV pruefen
root = next((p for p in CANDIDATES if os.path.isdir(p)), None)
notes["repo"] = root


def uv_coverage():
    """Anteil der Kachel, den die Inseln flaechenmaessig belegen.

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
notes["uv_abdeckung_vorher"] = round(cov, 3)

if BAKE and REUNWRAP and (cov < UV_MIN_COVERAGE or cov > UV_MAX_COVERAGE):
    # Die mitgelieferte UV nutzt zu wenig der Kachel - gebacken waere die Textur dann
    # groesstenteils leer und das Modell im Spiel entsprechend grob. Neu auspacken kostet
    # nichts, weil die Blender-Materialien prozedural sind und gar keine UV brauchen.
    for ob in bpy.context.view_layer.objects:
        ob.select_set(False)
    work.select_set(True)
    bpy.context.view_layer.objects.active = work
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.01)
    # Nach dem Auspacken noch einmal dicht packen. Smart Project laesst sonst viel Kachel
    # ungenutzt, und ungenutzte Kachel heisst verschenkte Aufloesung auf dem Modell.
    try:
        bpy.ops.uv.select_all(action="SELECT")
        bpy.ops.uv.average_islands_scale()
        bpy.ops.uv.pack_islands(rotate=True, margin=0.01)
    except Exception as exc:
        notes["uv_pack"] = str(exc)
    bpy.ops.object.mode_set(mode="OBJECT")
    notes["uv"] = "neu ausgepackt"
    notes["uv_abdeckung_nachher"] = round(uv_coverage(), 3)
else:
    notes["uv"] = "vorhandene benutzt"

# ---------------------------------------------------------------- Backen
BAKED_CO = "camhead_co"
BAKED_NOHQ = "camhead_nohq"
art = os.path.join(root, "art", "esdcam") if root else None


def relink_missing_images():
    """Fehlende Bildtexturen neben der .blend suchen.

    Fehlt eine, backt Blender an dieser Stelle Magenta - im ersten Durchgang war genau das
    an der Optik zu sehen.
    """
    missing = [i.name for i in bpy.data.images
               if i.source == "FILE" and i.filepath
               and not os.path.exists(bpy.path.abspath(i.filepath))]
    if not missing:
        return "keine fehlten"
    here = os.path.dirname(bpy.data.filepath) or os.path.expanduser("~")
    try:
        bpy.ops.file.find_missing_files(directory=here)
    except Exception as exc:
        return "Suche fehlgeschlagen: %s" % exc
    still = [i.name for i in bpy.data.images
             if i.source == "FILE" and i.filepath
             and not os.path.exists(bpy.path.abspath(i.filepath))]
    return "%d gefehlt, %d weiterhin fehlend" % (len(missing), len(still))


def demetal(restore=None):
    """Metallic vor dem Backen auf null, danach zurueck.

    Ein Diffuse-Bake liefert base_color * (1 - metallic). Bei metallischen Materialien ist
    das per Definition Schwarz - der erste Durchgang kam deshalb fast komplett schwarz
    heraus. Fuer Arma wollen wir die Grundfarbe in der _co-Textur; der metallische Eindruck
    entsteht dort ohnehin ueber den Glanz in der rvmat.
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
    """Ein Backdurchgang auf ein neues Bild, danach als PNG gespeichert."""
    img = bpy.data.images.get(image_name)
    if img is not None:
        bpy.data.images.remove(img)
    img = bpy.data.images.new(image_name, BAKE_SIZE, BAKE_SIZE,
                              alpha=False, float_buffer=False)
    img.colorspace_settings.name = colorspace

    # Jedes Material braucht einen aktiven Bildtextur-Knoten als Backziel.
    nodes_added = []
    for slot in work.material_slots:
        mat = slot.material
        if mat is None:
            # Leerer Slot - beim Zusammenfassen kommt der von Teilen ohne eigenes Material.
            # Ohne Fuellung meldet der Backvorgang "No active image found in material slot"
            # und laesst diese Flaechen unbemalt.
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

    notes["bilder"] = relink_missing_images()

    # Metallic nur fuer den Farbdurchgang aushaengen, fuer die Normal Map ist es egal.
    saved = demetal()
    notes["metallic_genullt"] = len(saved)
    notes["bake_co"], notes["pfad_co"] = bake_pass(
        "DIFFUSE", BAKED_CO, "camhead_co.png", "sRGB")
    demetal(saved)

    if BAKE_NORMAL:
        notes["bake_nohq"], notes["pfad_nohq"] = bake_pass(
            "NORMAL", BAKED_NOHQ, "camhead_nohq.png", "Non-Color")
    sc.render.engine = prev_engine

# ---------------------------------------------------------------- Arma-Material
#
# Nach dem Backen traegt ein einziges Material die gesamte Optik. Die Farbe kommt aus der
# gebackenen Textur, die Beleuchtung aus der rvmat.
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

# ---------------------------------------------------------------- LODs
notes["resolution"] = set_lod(work, LOD_RESOLUTION, 0.0)

# Geometrie: ein einfacher Quader. Arma will hier konvexe Koerper, und eine Kopie des
# Sichtmodells waere weder konvex noch noetig - der Aufsatz wird nicht beschossen.
lo, hi = bounds()
gv = [(x, y, z) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
gf = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
gme = bpy.data.meshes.new(WORK + "Geo")
gme.from_pydata(gv, [], gf)
gme.update()
geo = bpy.data.objects.new(WORK + "Geo", gme)
coll.objects.link(geo)
notes["geometry"] = set_lod(geo, LOD_GEOMETRY, 0.0)

# Masse liest der Exporter aus einem bmesh-Float-Layer "FHQWeights", nicht aus
# armaObjProps.mass. Fehlt der Layer, bricht der Export mit einem KeyError ab.
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

# Speicherpunkte. muzzlePos und muzzleEnd aus der ItemInfo zeigen hierher; der Vektor von
# "konec hlavne" nach "usti hlavne" ist die Blickrichtung, hier -X wie bei den Antennen.
mme = bpy.data.meshes.new(WORK + "Mem")
mme.from_pydata([(lo.x, 0.0, 0.0), (lo.x + 0.05, 0.0, 0.0)], [], [])
mme.update()
mem = bpy.data.objects.new(WORK + "Mem", mme)
coll.objects.link(mem)
notes["memory"] = set_lod(mem, LOD_MEMORY, 1.0)
for gname, idx in (("usti hlavne", 0), ("konec hlavne", 1)):
    mem.vertex_groups.new(name=gname).add([idx], 1.0, "REPLACE")

# ---------------------------------------------------------------- Export
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
    notes["export"] = "kein p3d-Export-Operator gefunden"
elif out is None:
    notes["export"] = "Repo nicht gefunden - CANDIDATES anpassen"
else:
    op = getattr(getattr(bpy.ops, picked[0]), picked[1])
    try:
        keys = sorted(op.get_rna_type().properties.keys())
    except Exception:
        keys = []
    # mergeSameLOD aus: ein Objekt je LOD, da gibt es nichts zu verschmelzen.
    extra = {"mergeSameLOD": False} if "mergeSameLOD" in keys else {}
    if not os.path.isdir(os.path.dirname(out)):
        os.makedirs(os.path.dirname(out))
    try:
        op(filepath=out, **extra)
        notes["export"] = ("ok, %d KB" % (os.path.getsize(out) // 1024)) \
            if os.path.exists(out) else "Operator lief, Datei fehlt"
    except Exception as exc:
        notes["export"] = "FEHLER: %s" % exc

notes["tris"] = sum(len(p.vertices) - 2 for p in me.polygons)
notes["ziel"] = out

print("=" * 74)
for k in ("toolbox", "quellen", "ngons", "duennes_ende", "laenge_cm", "quer_cm", "tris",
          "uv", "uv_abdeckung_vorher", "uv_abdeckung_nachher", "uv_pack",
          "bilder", "metallic_genullt",
          "bake_co", "pfad_co", "bake_nohq", "pfad_nohq",
          "material", "resolution", "geometry", "memory", "export", "ziel"):
    if k in notes:
        print("  %-20s %s" % (k, notes[k]))
