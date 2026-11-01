# -*- coding: utf-8 -*-
"""Runs inside Blender, driven by tools/render_icon.py - not meant to be started by hand.

    blender -b --factory-startup -P tools/blender_render.py -- jobs.json

Reads MLOD p3ds with tools/p3d.py, gives every face the material its rvmat path stands
for, and renders each job through an orthographic camera onto a transparent background.
"""

import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import p3d

spec = json.load(open(sys.argv[sys.argv.index("--") + 1]))
_images = {}


def image(path, data=False):
    if (path, data) not in _images:
        im = bpy.data.images.load(path)
        if data:
            im.colorspace_settings.name = "Non-Color"
        _images[(path, data)] = im
    return _images[(path, data)]


def material(name, maps):
    """Bohemia's Super shader, roughly: _co for colour, darkened by the green of _as,
    _smdi green for the specular level and blue for its sharpness, _nohq for normals."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]

    def tex(path, data=False, scale=None):
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = image(path, data)
        if scale:
            uv = nt.nodes.new("ShaderNodeUVMap")
            mapping = nt.nodes.new("ShaderNodeMapping")
            mapping.inputs["Scale"].default_value = (scale[0], scale[1], 1.0)
            nt.links.new(uv.outputs["UV"], mapping.inputs["Vector"])
            nt.links.new(mapping.outputs["Vector"], node.inputs["Vector"])
        return node

    def separate(node):
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(node.outputs["Color"], sep.inputs["Color"])
        return sep

    colour = tex(maps["co"]).outputs["Color"]
    occlusion = separate(tex(maps["as"], True))
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(colour, mix.inputs[6])
    nt.links.new(occlusion.outputs["Green"], mix.inputs[7])
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])

    smdi = separate(tex(maps["smdi"], True))
    rough = nt.nodes.new("ShaderNodeMapRange")
    rough.inputs["From Min"].default_value = 1.0
    rough.inputs["From Max"].default_value = 0.0
    rough.inputs["To Min"].default_value = 0.18
    rough.inputs["To Max"].default_value = 0.85
    nt.links.new(smdi.outputs["Blue"], rough.inputs["Value"])
    nt.links.new(rough.outputs["Result"], bsdf.inputs["Roughness"])
    spec_level = nt.nodes.new("ShaderNodeMath")
    spec_level.operation = "MULTIPLY"
    spec_level.inputs[1].default_value = 0.6
    nt.links.new(smdi.outputs["Green"], spec_level.inputs[0])
    nt.links.new(spec_level.outputs[0], bsdf.inputs["Specular IOR Level"])

    normal = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tex(maps["nohq"], True, maps.get("nohq_scale")).outputs["Color"], normal.inputs["Color"])
    nt.links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def load(path, resolution):
    lods, _ = p3d.read(path)
    lod = min(lods, key=lambda l: abs(l.resolution - resolution))
    # Arma is left handed with Y up; swapping Y and Z is the change of handedness and
    # leaves the model the right way round.
    mesh = bpy.data.meshes.new(os.path.basename(path))
    mesh.from_pydata([(p[0], p[2], p[1]) for p in lod.points], [],
                     [[v[0] for v in f.verts] for f in lod.faces])
    uv = mesh.uv_layers.new()
    slots = {}
    for poly, face in zip(mesh.polygons, lod.faces):
        for loop, v in zip(poly.loop_indices, face.verts):
            uv.data[loop].uv = (v[2], 1.0 - v[3])
        key = face.material.lower()
        if key not in slots:
            slots[key] = len(mesh.materials)
            mesh.materials.append(materials[key])
        poly.material_index = slots[key]
    mesh.update()
    normals = [(-lod.normals[v[1]][0], -lod.normals[v[1]][2], -lod.normals[v[1]][1])
               for face in lod.faces for v in face.verts]
    mesh.normals_split_custom_set(normals)
    obj = bpy.data.objects.new(mesh.name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


bpy.ops.wm.read_factory_settings(use_empty=True)
materials = {key.lower(): material(key, maps) for key, maps in spec["materials"].items()}
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = spec.get("samples", 128)
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.view_settings.view_transform = "Standard"
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"

world = bpy.data.worlds.new("studio")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.5, 0.5, 0.52, 1.0)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.45

camera_data = bpy.data.cameras.new("camera")
camera_data.type = "ORTHO"
camera = bpy.data.objects.new("camera", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera

lights = []
for name, energy in (("key", 6.0), ("fill", 1.6), ("rim", 4.0)):
    light = bpy.data.lights.new(name, "SUN")
    light.energy = energy
    light.angle = math.radians(12)
    obj = bpy.data.objects.new(name, light)
    scene.collection.objects.link(obj)
    lights.append(obj)

for job in spec["jobs"]:
    for obj in [o for o in scene.objects if o.type == "MESH"]:
        bpy.data.objects.remove(obj)
    load(job["p3d"], job.get("lod", 1.0))
    cam = job["camera"]
    right, up, forward = (Vector(cam[k]) for k in ("right", "up", "forward"))
    camera.matrix_world = Matrix((
        (right.x, up.x, -forward.x, cam["location"][0]),
        (right.y, up.y, -forward.y, cam["location"][1]),
        (right.z, up.z, -forward.z, cam["location"][2]),
        (0, 0, 0, 1)))
    camera_data.ortho_scale = cam["ortho_scale"]
    camera_data.clip_end = 20.0
    # Lights are set relative to the view, so both pictures are lit the same way:
    # key from the upper left in front, a weak fill from the right, a rim from behind.
    for obj, d in zip(lights, ((-0.55, 0.75, -0.55), (0.85, -0.1, -0.5), (0.25, 0.55, 0.8))):
        towards = right * d[0] + up * d[1] + forward * d[2]
        obj.rotation_euler = (-towards).to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_x = job["width"]
    scene.render.resolution_y = job["height"]
    scene.render.filepath = job["out"]
    bpy.ops.render.render(write_still=True)
