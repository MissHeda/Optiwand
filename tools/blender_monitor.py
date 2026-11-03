# -*- coding: utf-8 -*-
"""Runs inside Blender, driven by tools/render_monitor.py - not meant to be started by hand.

    blender -b --factory-startup -P tools/blender_monitor.py -- monitor.png

Models the field monitor head on and renders it with a hole where the screen is, onto a
transparent background. One Blender unit is 1000 pixels of the picture, with the centre of the
housing at the origin. The sizes are the ones render_monitor.py works out the layout from.
"""

import math
import sys

import bpy

CANVAS = (2048, 1328)
HOUSING = (2000, 1280)
SCREEN = (1760, 990)
SCREEN_Y = 55
OUT = sys.argv[sys.argv.index("--") + 1]


def rounded(cx, cy, w, h, r, segments=10):
    """A rounded rectangle in pixels, as a closed loop in Blender units."""
    points = []
    for sx, sy, start in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        for k in range(segments + 1):
            a = math.radians(start + 90.0 * k / segments)
            points.append(((cx + sx * (w / 2 - r) + r * math.cos(a)) / 1000.0,
                           (cy + sy * (h / 2 - r) + r * math.sin(a)) / 1000.0))
    return points


def material(name, colour, roughness, grain=0.0, metallic=0.0, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*colour, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    if grain:
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 900.0
        noise.inputs["Detail"].default_value = 6.0
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = grain
        bump.inputs["Distance"].default_value = 0.002
        nt.links.new(noise.outputs[0], bump.inputs["Height"])
        nt.links.new(bump.outputs[0], bsdf.inputs["Normal"])
    return mat


def plate(name, outline, hole, z, depth, bevel, mat):
    """A flat part: an outline, perhaps a hole in it, given depth and rounded edges. A curve
    rather than a mesh, because a 2D curve fills itself round the hole."""
    data = bpy.data.curves.new(name, "CURVE")
    data.dimensions = "2D"
    data.fill_mode = "BOTH"
    data.extrude = depth / 2.0
    data.bevel_depth = bevel
    data.bevel_resolution = 4
    data.offset = -bevel
    for loop in [outline] + ([hole] if hole else []):
        spline = data.splines.new("POLY")
        spline.points.add(len(loop) - 1)
        for point, (x, y) in zip(spline.points, loop):
            point.co = (x, y, 0.0, 1.0)
        spline.use_cyclic_u = True
    data.materials.append(mat)
    obj = bpy.data.objects.new(name, data)
    obj.location = (0.0, 0.0, z + depth / 2.0)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def text(body, x, y, z, size, mat, align="CENTER"):
    data = bpy.data.curves.new(body, "FONT")
    data.body = body
    data.size = size
    data.align_x = align
    data.align_y = "CENTER"
    data.extrude = 0.001
    data.materials.append(mat)
    obj = bpy.data.objects.new(body, data)
    obj.location = (x / 1000.0, y / 1000.0, z)
    bpy.context.scene.collection.objects.link(obj)


def cylinder(x, y, z, radius, depth, mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=radius / 1000.0, depth=depth, location=(x / 1000.0, y / 1000.0, z))
    bpy.context.object.data.materials.append(mat)
    bpy.ops.object.shade_smooth()


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

body = material("body", (0.022, 0.022, 0.024), 0.55, grain=0.15)
rubber = material("rubber", (0.012, 0.012, 0.013), 0.72, grain=0.35)
gloss = material("gloss", (0.004, 0.004, 0.005), 0.16)
orange = material("orange", (0.85, 0.27, 0.03), 0.42)
ink = material("ink", (0.01, 0.01, 0.01), 0.5)
print_grey = material("print", (0.34, 0.34, 0.36), 0.6)
steel = material("steel", (0.25, 0.25, 0.27), 0.38, metallic=1.0)
slot = material("slot", (0.01, 0.01, 0.01), 0.8)
led = material("led", (0.08, 0.9, 0.2), 0.3, emission=1.2)

w, h = HOUSING
sw, sh = SCREEN
screen_hole = rounded(0, SCREEN_Y, sw + 44, sh + 44, 14)
plate("body", rounded(0, 0, w - 30, h - 30, 60), screen_hole, 0.0, 0.06, 0.006, body)
plate("bumper", rounded(0, 0, w, h, 72), rounded(0, 0, w - 116, h - 116, 34), 0.0, 0.1, 0.016, rubber)
# The hole in this one is the exact edge of the picture, so it has no bevel to eat into it.
plate("lip", rounded(0, SCREEN_Y, sw + 60, sh + 60, 16), rounded(0, SCREEN_Y, sw, sh, 6), 0.012, 0.05, 0.0, gloss)

row = -h / 2 + 58 + 71
# What the keys do in game, in a row in the middle of the bar, evenly spaced.
BUTTONS = ("ZOOM -", "ZOOM +", "IR", "RESET")
BUTTON_W, BUTTON_GAP = 150, 34
for i, label in enumerate(BUTTONS):
    x = (i - (len(BUTTONS) - 1) / 2.0) * (BUTTON_W + BUTTON_GAP)
    plate("button" + label, rounded(x, row, BUTTON_W, 72, 14), None, 0.06, 0.016, 0.006, orange)
    text(label, x, row, 0.0875, 0.034, ink)

text("KAISERKOM", -w / 2 + 92, row + 14, 0.0675, 0.062, print_grey, "LEFT")
text("FIELD INSPECTION DISPLAY", -w / 2 + 92, row - 30, 0.0675, 0.026, print_grey, "LEFT")
cylinder(800, row, 0.07, 12, 0.012, led)

for sx in (-1, 1):
    for sy in (-1, 1):
        x, y = sx * (w / 2 - 30), sy * (h / 2 - 30)
        cylinder(x, y, 0.103, 15, 0.008, steel)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x / 1000.0, y / 1000.0, 0.1075),
                                        rotation=(0.0, 0.0, math.radians(30 + 40 * (sx + sy))))
        bpy.context.object.scale = (0.024, 0.0045, 0.001)
        bpy.context.object.data.materials.append(slot)

scene.render.engine = "CYCLES"
scene.cycles.samples = 256
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.view_settings.view_transform = "Standard"
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.resolution_x, scene.render.resolution_y = CANVAS
scene.render.filepath = OUT

world = bpy.data.worlds.new("studio")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.6, 0.6, 0.63, 1.0)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.16

camera_data = bpy.data.cameras.new("camera")
camera_data.type = "ORTHO"
camera_data.ortho_scale = CANVAS[0] / 1000.0
camera = bpy.data.objects.new("camera", camera_data)
camera.location = (0.0, 0.0, 3.0)
scene.collection.objects.link(camera)
scene.camera = camera

for name, energy, rotation in (("key", 1.9, (-0.62, -0.5, 0.0)), ("rim", 0.5, (0.8, 0.55, 0.0))):
    light = bpy.data.lights.new(name, "SUN")
    light.energy = energy
    light.angle = math.radians(14)
    obj = bpy.data.objects.new(name, light)
    obj.rotation_euler = rotation
    scene.collection.objects.link(obj)

bpy.ops.render.render(write_still=True)
