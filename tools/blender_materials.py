# -*- coding: utf-8 -*-
"""
Materialien fuer OptiwandModel.blend und ein Render zum Anschauen.

Der Grund, warum das Modell bisher schlecht aussah, ist nicht in erster Linie die Form:
es hatte ueberhaupt keine Materialien. Ein grauer Blockout im Werkbank-Render sieht
zwangslaeufig nach Platzhalter aus. Dieses Skript gibt jedem Bereich ein Material und
rendert das Ergebnis, damit die Formfrage ueberhaupt beurteilbar wird.

Ausfuehren: In Blender OptiwandModel.blend oeffnen, Scripting-Tab, dieses File laden,
Run druecken. Das Ergebnis liegt danach unter RENDER_OUT.

Die Bereichsgrenzen unten sind relativ zur gemessenen Bounding Box, nicht hart verdrahtet.
Das Skript druckt am Ende, wie viele Flaechen in welchem Bereich gelandet sind - stimmt die
Verteilung nicht, sind das die Zahlen, an denen man dreht, nicht der Aufbau.
"""

import os
import math

import bpy
from mathutils import Vector

OBJ_NAME = "MirrorLP"
RENDER_OUT = os.path.join(os.path.expanduser("~"), "Desktop", "optiwand_material.png")
RENDER_RES = (1400, 800)

# Bereichsgrenzen als Anteil der Modelllaenge, von der Spitze (Blender -X) aus gemessen
LENS_FRONT = 0.045          # vorderste 4.5 % -> Objektiv
POLE_FROM = 0.10            # Stange: dieser Abschnitt der Laenge ...
POLE_TO = 0.62              # ... bis hierher
POLE_RADIUS = 0.0055        # und nur, was duenn genug um die Laengsachse liegt
GRIP_BACK = 0.80            # hinterste 20 % ...
GRIP_BELOW = 0.0            # ... unterhalb dieser Hoehe -> Griffgummi


def principled(name, base, rough, metal=0.0, emit=None, emit_strength=1.4):
    """Ein Material anlegen oder das vorhandene gleichen Namens neu einstellen."""
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (base[0], base[1], base[2], 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit is not None:
        # Der Name des Emissions-Sockets hat sich zwischen Blender-Versionen geaendert
        for key in ("Emission Color", "Emission"):
            if key in b.inputs:
                b.inputs[key].default_value = (emit[0], emit[1], emit[2], 1.0)
                break
        if "Emission Strength" in b.inputs:
            b.inputs["Emission Strength"].default_value = emit_strength
    return m


def build():
    obj = bpy.data.objects.get(OBJ_NAME)
    if obj is None:
        raise SystemExit("Objekt %r nicht gefunden - falsche .blend offen?" % OBJ_NAME)
    me = obj.data

    # ---------------------------------------------------------------- Materialien
    me.materials.clear()
    for m in (
        principled("opw_body",   (0.055, 0.058, 0.062), 0.52),           # Polymergehaeuse
        principled("opw_rubber", (0.020, 0.020, 0.022), 0.90),           # Griffgummi
        principled("opw_metal",  (0.300, 0.310, 0.330), 0.34, 0.85),     # Teleskopstange
        principled("opw_lens",   (0.018, 0.026, 0.045), 0.06, 0.20),     # Objektiv
        principled("opw_screen", (0.020, 0.020, 0.020), 0.25, 0.0,
                   emit=(0.32, 0.60, 0.53)),                             # Bildschirm
    ):
        me.materials.append(m)
    BODY, RUBBER, METAL, LENS, SCREEN = range(5)

    # ---------------------------------------------------------------- Bereiche messen
    xs = [v.co.x for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    xmin, xmax = min(xs), max(xs)
    length = xmax - xmin
    zmin, zmax = min(zs), max(zs)

    lens_x = xmin + length * LENS_FRONT
    pole_a = xmin + length * POLE_FROM
    pole_b = xmin + length * POLE_TO
    grip_x = xmin + length * GRIP_BACK
    grip_z = zmin + (zmax - zmin) * 0.5 if GRIP_BELOW == 0.0 else GRIP_BELOW

    # Der Bildschirm steht als Vertexgruppe fest - das ist die einzige Zuordnung, die
    # exakt sein muss, weil da spaeter das Render-Target draufliegt.
    grp = obj.vertex_groups.get("screen")
    if grp is None:
        raise SystemExit("Vertexgruppe 'screen' fehlt")
    gi = grp.index
    screen_v = set(v.index for v in me.vertices
                   if any(g.group == gi for g in v.groups))

    counts = dict.fromkeys(("body", "rubber", "metal", "lens", "screen"), 0)
    for p in me.polygons:
        c = p.center
        radial = math.sqrt(c.y * c.y + c.z * c.z)

        if screen_v and all(vi in screen_v for vi in p.vertices):
            p.material_index = SCREEN
            counts["screen"] += 1
        elif c.x < lens_x:
            p.material_index = LENS
            counts["lens"] += 1
        elif pole_a < c.x < pole_b and radial < POLE_RADIUS:
            p.material_index = METAL
            counts["metal"] += 1
        elif c.x > grip_x and c.z < grip_z:
            p.material_index = RUBBER
            counts["rubber"] += 1
        else:
            p.material_index = BODY
            counts["body"] += 1

    me.update()

    # Weiche Kanten mit Winkelgrenze - ohne das wirkt jedes Rohr facettiert
    for p in me.polygons:
        p.use_smooth = True
    if hasattr(me, "use_auto_smooth"):        # bis Blender 4.0
        me.use_auto_smooth = True
        me.auto_smooth_angle = math.radians(40.0)
    else:                                     # ab 4.1 als Modifier
        if not any(mod.type == "NODES" and "Smooth by Angle" in (mod.name or "")
                   for mod in obj.modifiers):
            try:
                bpy.context.view_layer.objects.active = obj
                bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40.0))
            except Exception:
                pass

    return obj, counts, (xmin, xmax, length, zmin, zmax)


def light_and_render(obj):
    sc = bpy.context.scene

    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "CYCLES"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue

    # Hintergrund: dunkelgrau, damit ein dunkles Geraet noch Kontur hat
    if sc.world is None:
        sc.world = bpy.data.worlds.new("World")
    sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.050, 0.053, 0.060, 1.0)
        bg.inputs[1].default_value = 1.0

    centre = obj.matrix_world @ (0.125 * sum(
        (Vector(c) for c in obj.bound_box), Vector()))

    target = bpy.data.objects.get("OPW_Look")
    if target is None:
        target = bpy.data.objects.new("OPW_Look", None)
        bpy.context.collection.objects.link(target)
    target.location = centre

    def aimed(name, data, loc):
        o = bpy.data.objects.get(name)
        if o is None:
            o = bpy.data.objects.new(name, data)
            bpy.context.collection.objects.link(o)
        o.data = data
        o.location = loc
        for c in list(o.constraints):
            o.constraints.remove(c)
        c = o.constraints.new("TRACK_TO")
        c.target = target
        c.track_axis = "TRACK_NEGATIVE_Z"
        c.up_axis = "UP_Y"
        return o

    for name, loc, energy, size in (
        ("OPW_Key",  (0.30, -0.70, 0.80), 190.0, 1.3),
        ("OPW_Fill", (-0.80, -0.50, 0.05), 55.0, 1.8),
        ("OPW_Rim",  (-0.25, 0.75, 0.50), 120.0, 1.1),
    ):
        d = bpy.data.lights.get(name) or bpy.data.lights.new(name, "AREA")
        d.type = "AREA"
        d.energy = energy
        d.size = size
        aimed(name, d, Vector(loc) + centre)

    cd = bpy.data.cameras.get("OPW_Cam") or bpy.data.cameras.new("OPW_Cam")
    cd.lens = 85.0
    cam = aimed("OPW_Cam", cd, centre + Vector((0.05, -1.15, 0.42)))
    sc.camera = cam

    sc.render.resolution_x, sc.render.resolution_y = RENDER_RES
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.filepath = RENDER_OUT
    bpy.ops.render.render(write_still=True)
    return RENDER_OUT


obj, counts, bounds = build()
xmin, xmax, length, zmin, zmax = bounds
print("Laenge %.1f cm, Hoehe %.1f cm" % (length * 100.0, (zmax - zmin) * 100.0))
print("Flaechen je Material:")
for k in ("body", "rubber", "metal", "lens", "screen"):
    print("  %-7s %5d" % (k, counts[k]))
out = light_and_render(obj)
print("Render: %s" % out)
