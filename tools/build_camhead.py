# -*- coding: utf-8 -*-
"""Build addons/esdcam/model/camhead.p3d on Bohemia's own Spectrum Device textures.

The attachment is an endoscope, the kind sold with a pistol grip and a screen, or the
mirrorgun in Ready or Not: the Spectrum Device is the grip and the screen, and what goes on
its muzzle slot is the thin black cable with the camera at its end.

Only the connector that sits on the device comes from the artist's FBX, and it stays on
Bohemia's atlas, a3\\weapons_f_enoch\\pistols\\esd_01\\data\\esd_01_co.paa, exactly where
antenna 03 has its own: the connector was modelled off muzzle_antenna_03_F and still matches
it to a fraction of a millimetre, so each face is projected onto the nearest face of that
model and takes its UVs from there. Everything in front of it is built here, as one solid
of revolution - see endoscope():

    collar        tapers from the connector down to the strain relief.
    strain relief the ribbed cone where a cable leaves its plug.
    coil          spare cable in a few loops, hanging just in front of the strain relief,
                  as if the cable could be paid out further.
    cable         thin and smooth.
    camera head   a slim metal-less sleeve, a step wider than the cable.
    lens          a texture and material of our own, because nothing on the atlas reads as
                  glass: a coated lens in a ring of LEDs, with its reflections painted on, so
                  it shows whatever the light does - see lens_colour().

All but the lens wears black rubber: the plain panel of the atlas with a darker, duller
material of its own - see write_rubber_material().

Behind the collar a thin coax takes antenna 02's route under the device into the lower socket
under its display, on antenna 02's own coax and plug on the atlas.

A cable is never quite straight, so the stretch in front of the coil is built straight and
given a slight sway from side to side last - see SWAYS and bent(). The connector stays where it is. The memory
points stay on the straight axis: they say where the view looks, which the sway is not
meant to change.

Writes LOD 1 and 2, two shadow volumes and a shadow buffer LOD, the geometry box and the
memory points, plus the materials of rubber and lens and the lens's texture.

    python tools/build_camhead.py

What it needs depends on where it runs. Everywhere: Python 3 with numpy, and
art/esdcam/arma3_cam.fbx, which is in the repo. Two more things are Bohemia's and only
exist on a machine with Arma - locally, not in a cloud session or CI, which have nothing
but the git checkout - and the build gets by without either:

    art/esdcam/reference/muzzle_antenna_03_F_mlod.p3d
        Bohemia's antenna, local only (ignored by git, and it must stay so). With it, the
        connector is projected onto it afresh. Without it, the connector keeps the UVs the
        committed camhead.p3d already has, each face found again by its corners - see
        StoredHead. That writes the same model to the byte, for as long as the FBX and
        the connector's mapping stay as they are; once either changes, the build stops and
        asks for the reference.

    ImageToPAA, from the Arma 3 Tools (or IMAGETOPAA=path), plus Pillow to feed it
        writes the lens's texture, camhead_lens_co.paa. Without it that file is left as it
        is in git, which is right for as long as lens_colour() is unchanged. The p3d and the
        rvmats are written either way.

So in the cloud numpy is all it takes, for every change but one to the FBX, the connector's
mapping or lens_colour() - those need the machine with Arma. Locally, with the reference and
the Tools, the build makes every file from scratch.
"""

import argparse
import math
import os
import struct
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fbx
import fbx_to_p3d
import imagetopaa
import p3d
from fbx_to_p3d import DEFAULT_LENGTH

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL = os.path.join(HERE, "addons", "esdcam", "model", "camhead.p3d")

BI_DATA = r"a3\weapons_f_enoch\pistols\esd_01\data"
TEXTURE = BI_DATA + r"\esd_01_co.paa"
MATERIAL = BI_DATA + r"\esd_01.rvmat"
RUBBER_MATERIAL = r"z\opw\addons\esdcam\data\camhead_rubber.rvmat"
LENS_MATERIAL = r"z\opw\addons\esdcam\data\camhead_lens.rvmat"
LENS_TEXTURE = r"z\opw\addons\esdcam\data\camhead_lens_co.paa"

ATLAS = 2048.0

# ------------------------------------------------------------------------------ atlas
# Antenna 01's panel in atlas pixels, (x0, y0, x1, y1), clear of screws and labels: measured
# off esd_01_co with the UV layouts of the device and its antennas drawn over it.
PLAIN_RECT = (430.0, 1770.0, 630.0, 1890.0)

# Antenna 02's coax: u runs along the cable at 1.6 per metre, v once round it.
CABLE_U = (0.1583, 0.5370)
CABLE_V = (0.0326, 0.0481)
CABLE_U_PER_M = 1.6
# Antenna 02's plug, unrolled the same way: u along its axis at 2.0 per metre.
PLUG_U0 = 0.4209
PLUG_X0 = 0.1703
PLUG_U_PER_M = 2.0
PLUG_V = (0.6890, 0.7212)

# ------------------------------------------------------------------------------ geometry
# What is kept of the FBX: faces entirely behind this, on the device's side.
CONNECTOR_X = -0.0318

# The endoscope, as (distance from the mount, radius), in metres. It starts with a core
# inside the connector, which is open at the sides: without it you look right through.
COLLAR = [(0.002, 0.0155), (0.026, 0.0155), (0.028, 0.0228), (0.036, 0.0228), (0.040, 0.0195), (0.046, 0.0125), (0.052, 0.0105)]
RELIEF_END = 0.105
RELIEF_RIBS = 7
RELIEF_RADIUS = (0.0100, 0.0058)
CABLE_RADIUS = 0.0042
# Where the straight cable ends and the coil's tube takes over, overlapping it a little.
CABLE_START = 0.212
HEAD = [(0.512, CABLE_RADIUS), (0.514, 0.0058), (0.528, 0.0062), (0.530, 0.0068), (0.5345, 0.0068),
        (0.5355, 0.0062), (0.5375, 0.0062), (0.5385, 0.0068), (0.577, 0.0068), (DEFAULT_LENGTH, 0.0062)]
LENS_RADIUS = HEAD[-1][1]

# The coil: loops in the wand's vertical plane, hanging below the axis, each beside the last.
COIL_START_X = -0.215
COIL_X = -0.175
COIL_END_X = -0.100
COIL_RADIUS = 0.034
COIL_TURNS = 3
COIL_PITCH = 0.0095

# The stretch of cable that sways, in front of the coil. Essentially straight, with a few soft
# turns left and right that cancel out, so the wand still points forward and stays within
# about 2 mm of its axis. (x, degrees of turn).
BEND_START = -0.25
BEND_END = -0.512
SWAYS = [
    (-0.290, 1.0),
    (-0.380, -2.0),
    (-0.470, 1.0),
]
# Half the length of cable a turn takes up, in metres.
SWAY_REACH = 0.035

# The coax behind the collar, thin as antenna 02's: down from the collar's underside, then
# antenna 02's route under the device and up into the socket. Model space, to the plug.
COAX_RADIUS = 0.0022
# Antenna 02's plug sits in the lower socket under the display, on this axis (Y, Z),
# pointing forward. Ours goes in the same place.
PLUG_AXIS = (0.0714, -0.0004)
PLUG_PROFILE = [  # (x, r): a plain SMA style plug, socket end first
    (0.1703, 0.0020), (0.1762, 0.0021), (0.1763, 0.0034), (0.1789, 0.0034),
    (0.1791, 0.0037), (0.1795, 0.0034), (0.1831, 0.0034), (0.1834, 0.0037),
    (0.1839, 0.0037), (0.1841, 0.0031), (0.1913, 0.0031), (0.2002, 0.0024),
    (0.2004, COAX_RADIUS),
]
COAX_ROUTE = [
    (-0.040, -0.010, -0.002),
    (-0.036, -0.030, -0.008),
    (-0.031, -0.055, -0.015),
    (-0.021, -0.082, -0.023),
    (-0.002, -0.104, -0.032),
    (0.025, -0.1174, -0.0391),
    (0.0817, -0.1285, -0.0416),
    (0.1454, -0.1326, -0.0391),
    (0.1997, -0.1278, -0.0359),
    (0.2306, -0.1180, -0.0345),
    (0.2488, -0.1076, -0.0336),
    (0.2652, -0.0959, -0.0325),
    (0.2784, -0.0818, -0.0311),
    (0.2875, -0.0653, -0.0289),
    (0.2955, -0.0394, -0.0249),
    (0.2958, -0.0219, -0.0205),
    (0.2939, 0.0031, -0.0159),
    (0.2886, 0.0188, -0.0120),
    (0.2761, 0.0411, -0.0069),
    (0.2506, 0.0601, -0.0022),
    (0.2347, 0.0666, -0.0011),
    (0.2185, 0.0702, -0.0007),
    (0.2004, PLUG_AXIS[0], PLUG_AXIS[1]),
]

# How far the flat lens's normals lean out at its rim, so light and reflections move over
# it the way they do on a curved front element.
LENS_DOME = 0.5

# The shadow buffer LOD, which Arma draws its shadow maps from.
SHADOW_BUFFER = 11000.0


def px(x, y):
    return (x / ATLAS, y / ATLAS)


def norm(v):
    v = np.asarray(v, float)
    length = np.linalg.norm(v)
    return v / length if length > 1e-12 else v


def shown(path):
    """A path as seen from the repo, for the log."""
    try:
        return os.path.relpath(path, HERE)
    except ValueError:  # on another drive
        return path


# ------------------------------------------------------------------------------ mesh
class Mesh:
    """Faces as [(point, normal, uv)], wound counter clockwise seen from outside and with
    outward normals - the ordinary right handed way. Lod.mesh() turns them round."""

    def __init__(self):
        self.faces = []

    def add(self, corners, material=MATERIAL):
        self.faces.append((orient(corners), material))


def orient(corners):
    """Wind a face so its right handed cross product agrees with its normals."""
    p = [np.asarray(c[0], float) for c in corners]
    n = sum(np.asarray(c[1], float) for c in corners)
    cross = np.cross(p[1] - p[0], p[2] - p[0])
    if np.linalg.norm(cross) < 1e-14 and len(p) > 3:
        cross = np.cross(p[2] - p[0], p[3] - p[0])
    return list(corners) if cross @ n >= 0 else list(corners)[::-1]


class Lod:
    """Points, normals and faces of one MLOD LOD.

    Arma stores faces the other way round: in every MLOD Bohemia ships, the right handed
    cross product of a face and its stored normals both point inwards (see check() in
    fbx_to_p3d). So everything goes in reversed, with negated normals."""

    def __init__(self, resolution):
        self.lod = p3d.Lod(resolution)
        self._points = {}
        self._normals = {}

    def point(self, p):
        key = tuple(round(float(c) * 1e6) for c in p)
        if key not in self._points:
            self._points[key] = len(self.lod.points)
            self.lod.points.append((float(p[0]), float(p[1]), float(p[2]), 0))
        return self._points[key]

    def normal(self, n):
        key = tuple(round(float(c) * 1e5) for c in n)
        if key not in self._normals:
            self._normals[key] = len(self.lod.normals)
            self.lod.normals.append((float(n[0]), float(n[1]), float(n[2])))
        return self._normals[key]

    def mesh(self, mesh, triangles=False):
        for corners, material in mesh.faces:
            stored = [(p, -np.asarray(n, float), uv) for p, n, uv in reversed(corners)]
            pieces = [stored]
            if triangles and len(stored) == 4:
                pieces = [stored[:3], [stored[0], stored[2], stored[3]]]
            for piece in pieces:
                verts = [(self.point(p), self.normal(n), float(uv[0]), float(uv[1]))
                         for p, n, uv in piece]
                if len({v[0] for v in verts}) < 3:
                    continue  # collapsed onto an axis
                texture = LENS_TEXTURE if material == LENS_MATERIAL else TEXTURE if material else ""
                self.lod.faces.append(p3d.Face(verts, texture, material))

    def finish(self):
        # One section per material, and the UV set once more as a tagg, the way Object
        # Builder saves it.
        self.lod.faces.sort(key=lambda f: (f.material != MATERIAL, f.material))
        payload = struct.pack("<I", 0) + b"".join(
            struct.pack("<ff", v[2], v[3]) for f in self.lod.faces for v in f.verts)
        self.lod.taggs.append(p3d.Tagg("#UVSet#", payload))
        return self.lod

    def sharp_edges(self):
        edges = set()
        for f in self.lod.faces:
            ids = [v[0] for v in f.verts]
            for i in range(len(ids)):
                a, b = ids[i], ids[(i + 1) % len(ids)]
                edges.add((min(a, b), max(a, b)))
        self.lod.taggs.append(p3d.Tagg("#SharpEdges#", b"".join(
            struct.pack("<II", a, b) for a, b in sorted(edges))))
        return self.lod


# ------------------------------------------------------------------------------ the FBX
def read_wand(path, length):
    """The artist's mesh in model space as [(corners, material name)], right handed."""
    root, _ = fbx.parse(path)
    geo = root.find("Objects").find("Geometry")
    materials = geo.find("LayerElementMaterial").find("Materials").props[0]
    names = ["Plastik", "Schlauch", "blitz", "cam"]

    points, normals, _uv, faces = fbx_to_p3d.read_mesh(path)
    ys = [p[1] for p in points]
    y_min, y_max = min(ys), max(ys)
    scale = length / (y_max - y_min)
    ring = [p for p in points if abs(p[1] - y_min) < 1e-4]
    cx = sum(p[0] for p in ring) / len(ring)
    cz = sum(p[2] for p in ring) / len(ring)

    def to_arma(p):
        return np.array([-(p[1] - y_min) * scale, (p[2] - cz) * scale, (p[0] - cx) * scale])

    def outward_normal(i):
        # Blender's normal in Arma axes. The FBX keeps its own vertex order, which in
        # Arma axes is clockwise seen from outside; reversed below to the right handed way.
        return norm((-normals[i * 3 + 1], normals[i * 3 + 2], normals[i * 3]))

    out = []
    for index, face in enumerate(faces):
        for piece in fbx_to_p3d.fan(face):
            corners = [(to_arma(points[pt]), outward_normal(nr), None) for pt, nr, _u in piece]
            out.append((corners[::-1], names[materials[index]]))
    return out


def face_normal(corners):
    p = [c[0] for c in corners]
    return norm(np.cross(p[1] - p[0], p[2] - p[0]))


# ------------------------------------------------------------------------------ mount head
class Reference:
    """Antenna 03's resolution LOD as triangles with UVs, to project onto."""

    def __init__(self, path):
        lods, _ = p3d.read(path)
        lod = next(l for l in lods if abs(l.resolution - 1.0) < 1e-6)
        tris, uvs = [], []
        for face in lod.faces:
            for a, b, c in ((0, 1, 2), (0, 2, 3))[:len(face.verts) - 2]:
                vs = [face.verts[a], face.verts[b], face.verts[c]]
                tris.append([lod.points[v[0]][:3] for v in vs])
                uvs.append([(v[2], v[3]) for v in vs])
        self.tri = np.array(tris)
        self.uv = np.array(uvs)
        # Stored inward-wound, so the outward normal is the negated cross product.
        n = -np.cross(self.tri[:, 1] - self.tri[:, 0], self.tri[:, 2] - self.tri[:, 0])
        self.normal = n / (np.linalg.norm(n, axis=1)[:, None] + 1e-20)

        # The antenna's far end cap, a disc of 3 cm, as a planar map (Y, Z) -> UV. Our
        # collar ends in a flat disc the antenna does not have - its rubber tube carries
        # on there - and this is the antenna's nearest thing to one.
        rows, uvs = [], []
        for face in lod.faces:
            if all(lod.points[v[0]][0] < -0.5555 for v in face.verts):
                for v in face.verts:
                    p = lod.points[v[0]]
                    rows.append((p[1], p[2], 1.0))
                    uvs.append((v[2], v[3]))
        self.cap, *_ = np.linalg.lstsq(np.array(rows), np.array(uvs), rcond=None)
        self.worst, self.unmatched = 0.0, 0

    def map_head(self, corners):
        """A face of the mount head: projected where antenna 03 has a face under it, the
        antenna's end cap on our flat disc, plain panel where neither fits."""
        uv, dist = self.project(corners)
        if uv is not None:
            self.worst = max(self.worst, dist)
        elif face_normal(corners)[0] < -0.7:
            uv = self.map_cap(corners)
        else:
            self.unmatched += 1
            uv = map_cylinder(corners, PLAIN_RECT, (0.0, -0.10))
        return uv

    def summary(self):
        return ("mount head on antenna 03: furthest %.2f mm, %d faces without a match"
                % (self.worst * 1000, self.unmatched))

    def map_cap(self, corners):
        return [tuple(float(x) for x in np.array([c[0][1], c[0][2], 1.0]) @ self.cap)
                for c in corners]

    def distance(self, p):
        """Distance from p to every triangle."""
        a, b, c = self.tri[:, 0], self.tri[:, 1], self.tri[:, 2]
        n = np.cross(b - a, c - a)
        n /= np.linalg.norm(n, axis=1)[:, None] + 1e-20
        height = ((p - a) * n).sum(1)
        q = p - n * height[:, None]
        inside = np.ones(len(a), bool)
        for s, e in ((a, b), (b, c), (c, a)):
            inside &= (np.cross(e - s, q - s) * n).sum(1) >= -1e-12
        edge = np.full(len(a), np.inf)
        for s, e in ((a, b), (b, c), (c, a)):
            se = e - s
            t = np.clip(((p - s) * se).sum(1) / ((se * se).sum(1) + 1e-20), 0, 1)
            edge = np.minimum(edge, np.linalg.norm(p - (s + se * t[:, None]), axis=1))
        return np.where(inside, np.abs(height), edge)

    def project(self, corners):
        """UVs for one of our faces, from the reference triangle under its centre. Corners
        past that triangle's edge carry on along the same affine mapping, which for the
        planar, evenly mapped faces of a lathed part is the mapping of its neighbour too."""
        pts = np.array([c[0] for c in corners])
        dist = self.distance(pts.mean(0))
        dist = np.where(self.normal @ face_normal(corners) > 0.6, dist, np.inf)
        k = int(np.argmin(dist))
        if not np.isfinite(dist[k]) or dist[k] > 0.003:
            return None, None
        a, b, c = self.tri[k]
        e1, e2 = b - a, c - a
        d00, d01, d11 = e1 @ e1, e1 @ e2, e2 @ e2
        det = d00 * d11 - d01 * d01
        out = []
        for p in pts:
            d = p - a
            v = (d11 * (d @ e1) - d01 * (d @ e2)) / det
            w = (d00 * (d @ e2) - d01 * (d @ e1)) / det
            uv = (1 - v - w) * self.uv[k][0] + v * self.uv[k][1] + w * self.uv[k][2]
            out.append((float(uv[0]), float(uv[1])))
        return out, float(dist[k])


class StoredHead:
    """The mount head as the committed camhead.p3d already has it, for wherever antenna 03
    is not to hand - a cloud session or CI has the repo and nothing of Bohemia's. Each
    face of the head is found again among that model's faces and keeps its UVs, so the
    build writes the very model the reference gave, rather than a second mapping that
    only looks like it.

    Faces are found by their corners. p3d keeps positions as float32 and Lod.point()
    merges corners closer than a micrometre, so a stored point lies within nanometres of
    the corner it was made from, while no two points of the model are closer than 0.1 mm:
    whatever lies inside TOLERANCE is that point. Rounding both to a grid instead would
    miss now and then - a float32 just across a grid line from its float64 rounds the
    other way. A face that is not there, corner for corner, means the FBX or the head's
    mapping has moved on since the model was built, and only the reference can map it
    then. So that stops the build instead of inventing UVs."""

    TOLERANCE = 1e-5  # 0.01 mm

    def __init__(self, path):
        lods, _ = p3d.read(path)
        lod = next(l for l in lods if abs(l.resolution - 1.0) < 1e-6)
        self.path = path
        self.points = np.array([p[:3] for p in lod.points])
        # By point indices in the order stored, which is ours reversed (see Lod.mesh).
        self.faces = {tuple(v[0] for v in f.verts): [(v[2], v[3]) for v in f.verts]
                      for f in lod.faces}
        self.matched = 0

    def map_head(self, corners):
        pts = np.array([c[0] for c in reversed(corners)])
        dist = np.linalg.norm(self.points[None, :, :] - pts[:, None, :], axis=2)
        ids = tuple(int(i) for i in dist.argmin(1))
        if dist.min(1).max() > self.TOLERANCE or ids not in self.faces:
            x, y, z = pts.mean(0)
            raise SystemExit(
                "mount head face at (%.4f, %.4f, %.4f) is not in %s - the FBX or the head's "
                "mapping changed since it was built, so it needs the reference again"
                % (x, y, z, shown(self.path)))
        self.matched += 1
        return self.faces[ids][::-1]

    def summary(self):
        return "mount head as committed: %d faces found again, UVs unchanged" % self.matched


# ------------------------------------------------------------------------------ mappings
def angle(p):
    """Angle round the wand's axis: 0 on top (+Y), growing towards +Z."""
    return math.atan2(p[2], p[1])


def unwrapped(corners):
    a = [angle(c[0]) % (2 * math.pi) for c in corners]
    if max(a) - min(a) > math.pi:
        a = [x + 2 * math.pi if x < math.pi else x for x in a]
    return a


def map_cylinder(corners, rect, x_range, around_u=True):
    """Wrap a face round the wand's axis into rect: once round along one side, the given
    stretch of X along the other. Two pixels are kept back so that the face across the
    seam, which runs one step past a full turn, stays inside."""
    x0, y0, x1, y1 = rect
    lo, hi = x_range
    out = []
    for c, a in zip(corners, unwrapped(corners)):
        t = (c[0][0] - lo) / (hi - lo)
        s = a / (2 * math.pi)
        if around_u:
            out.append(px(x0 + s * (x1 - x0 - 8), y0 + t * (y1 - y0)))
        else:
            out.append(px(x0 + t * (x1 - x0), y0 + s * (y1 - y0 - 3)))
    return out


def map_lens(corners, centre, radius):
    """The lens's disc across its whole texture, with normals that lean out towards the rim
    like those of a curved front element."""
    out = []
    for p, _n, _uv in corners:
        y, z = (p[1] - centre[0]) / radius, (p[2] - centre[1]) / radius
        normal = norm((-1.0, y * LENS_DOME, z * LENS_DOME))
        out.append((p, normal, (0.5 + z * 0.5, 0.5 - y * 0.5)))
    return out


# ------------------------------------------------------------------------------ the model
def connector(wand, mount):
    """The faces of the artist's mesh that stay, mapped onto Bohemia's atlas."""
    mesh = Mesh()
    for corners, _name in wand:
        if min(p[0][0] for p in corners) > CONNECTOR_X:
            mesh.faces.append(([(p, n, u) for (p, n, _), u in zip(corners, mount.map_head(corners))], MATERIAL))
    print("  " + mount.summary())
    return mesh


def rubber_uv(t, s):
    """t along the part in metres, s once round it."""
    x0, y0, x1, y1 = PLAIN_RECT
    return px(x0 + s * (x1 - x0 - 8), y0 + t / DEFAULT_LENGTH * (y1 - y0))


def endoscope(detail):
    """What can be turned on the wand's axis: collar and strain relief, then the cable with
    the camera head, with the lens as the disc that closes its end. The coil between the
    two is a tube of its own - see coil_path()."""
    relief = []
    step = (RELIEF_END - COLLAR[-1][0]) / RELIEF_RIBS
    for i in range(RELIEF_RIBS):
        start = COLLAR[-1][0] + i * step
        radius = RELIEF_RADIUS[0] + (RELIEF_RADIUS[1] - RELIEF_RADIUS[0]) * i / (RELIEF_RIBS - 1)
        if detail:
            relief += [(start, radius), (start + step * 0.55, radius),
                       (start + step * 0.7, radius - 0.0014), (start + step * 0.9, radius - 0.0014)]
        else:
            relief.append((start, radius))
    mesh = Mesh()
    sides = 16 if detail else 8
    for profile in (COLLAR[:-1] + relief + [(RELIEF_END, CABLE_RADIUS)], [(CABLE_START, CABLE_RADIUS)] + HEAD):
        lathe(mesh, profile, (0.0, 0.0, 0.0), (-1.0, 0.0, 0.0), sides, rubber_uv, RUBBER_MATERIAL)
    centre = np.array([-DEFAULT_LENGTH, 0.0, 0.0])
    rim = [centre + np.array([0.0, math.cos(a), math.sin(a)]) * LENS_RADIUS
           for a in np.linspace(0, 2 * math.pi, sides * 2 if detail else sides, endpoint=False)]
    for a, b in zip(rim, rim[1:] + rim[:1]):
        mesh.add(map_lens([(p, None, None) for p in (centre, a, b)], (0.0, 0.0), LENS_RADIUS), LENS_MATERIAL)
    return mesh


def coil_path(detail):
    """From the straight cable into the loops and on to the strain relief. Each loop lies
    beside the last, so the cable drifts sideways through them, and it moves over to the
    side of the first loop and back from that of the last on the way in and out."""
    side = COIL_PITCH * COIL_TURNS / 2
    ease = lambda t: t * t * (3 - 2 * t)
    path = [np.array([x, 0.0, -side * ease(i / 4.0)]) for i, x in enumerate(np.linspace(COIL_START_X, COIL_X, 5))]
    count = COIL_TURNS * (28 if detail else 12)
    for i in range(1, count + 1):
        a = 2 * math.pi * COIL_TURNS * i / count
        path.append(np.array([COIL_X + COIL_RADIUS * math.sin(a), -COIL_RADIUS + COIL_RADIUS * math.cos(a),
                              -side + COIL_PITCH * a / (2 * math.pi)]))
    path += [np.array([x, 0.0, side * (1 - ease((i + 1) / 5.0))])
             for i, x in enumerate(np.linspace(COIL_X, COIL_END_X, 6)[1:])]
    return path


def build_coil(mesh, radius, sides, material=RUBBER_MATERIAL, caps=False):
    path = coil_path(sides > 6)
    tube(mesh, path, radius, sides, lambda i, k: rubber_uv(i / len(path) * DEFAULT_LENGTH, k / sides), material, caps)


def coax_path(max_turn, max_step=0.06):
    return resample(catmull_rom(COAX_ROUTE), max_turn, max_step)


def catmull_rom(points, samples=24):
    """Centripetal Catmull-Rom through the points, as a dense polyline."""
    pts = [np.asarray(p, float) for p in points]
    pts = [2 * pts[0] - pts[1]] + pts + [2 * pts[-1] - pts[-2]]
    out = [pts[1]]
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        t1 = np.linalg.norm(p1 - p0) ** 0.5
        t2 = t1 + np.linalg.norm(p2 - p1) ** 0.5
        t3 = t2 + np.linalg.norm(p3 - p2) ** 0.5
        for k in range(1, samples + 1):
            t = t1 + (t2 - t1) * k / samples
            a1 = (t1 - t) / t1 * p0 + t / t1 * p1
            a2 = (t2 - t) / (t2 - t1) * p1 + (t - t1) / (t2 - t1) * p2
            a3 = (t3 - t) / (t3 - t2) * p2 + (t - t2) / (t3 - t2) * p3
            b1 = (t2 - t) / t2 * a1 + t / t2 * a2
            b2 = (t3 - t) / (t3 - t1) * a2 + (t - t1) / (t3 - t1) * a3
            out.append((t2 - t) / (t2 - t1) * b1 + (t - t1) / (t2 - t1) * b2)
    return out


def resample(line, max_turn, max_step):
    """Keep a point wherever the direction has turned by max_turn degrees since the last
    one kept, or after max_step metres of straight."""
    keep = [line[0]]
    run = 0.0
    for i in range(1, len(line) - 1):
        run += float(np.linalg.norm(line[i] - line[i - 1]))
        held = norm(line[i] - keep[-1])
        ahead = norm(line[i + 1] - line[i])
        turn = math.degrees(math.acos(max(-1.0, min(1.0, float(held @ ahead)))))
        if turn >= max_turn or run >= max_step:
            keep.append(line[i])
            run = 0.0
    keep.append(line[-1])
    return keep


def frames(path):
    """Parallel transported frames along a polyline."""
    tangents = [norm(path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)])
                for i in range(len(path))]
    ref = np.array([0.0, 1.0, 0.0]) if abs(tangents[0][1]) < 0.9 else np.array([0.0, 0.0, 1.0])
    n = norm(np.cross(np.cross(tangents[0], ref), tangents[0]))
    out = []
    for t in tangents:
        n = norm(n - t * (n @ t))
        out.append((t, n, np.cross(t, n)))
    return out


def tube(mesh, path, radius, sides, uv_fn, material=MATERIAL, caps=False, fr=None):
    """A tube along the path. uv_fn(i, k): UV at ring i, side k of 0..sides. fr: frames
    from a longer path this one is a piece of, so the pieces meet ring on ring."""
    fr = fr or frames(path)
    rings = []
    for p, (_t, n, b) in zip(path, fr):
        ring = []
        for k in range(sides + 1):
            a = 2 * math.pi * k / sides
            d = n * math.cos(a) + b * math.sin(a)
            ring.append((p + d * radius, d))
        rings.append(ring)
    for i in range(len(path) - 1):
        for k in range(sides):
            mesh.add([(rings[ii][kk][0], rings[ii][kk][1], uv_fn(ii, kk))
                      for ii, kk in ((i, k), (i, k + 1), (i + 1, k + 1), (i + 1, k))], material)
    if caps:
        for i, sign in ((0, -1.0), (len(path) - 1, 1.0)):
            t = fr[i][0] * sign
            for k in range(sides):
                mesh.add([(path[i], t, (0.0, 0.0)), (rings[i][k][0], t, (0.0, 0.0)),
                          (rings[i][k + 1][0], t, (0.0, 0.0))], material)


def plug_uv(x, s):
    return (PLUG_U0 + (x - PLUG_X0) * PLUG_U_PER_M, PLUG_V[0] + (PLUG_V[1] - PLUG_V[0]) * s)


def build_cable(mesh, path, sides):
    """The strip of coax on the atlas is about 24 cm of cable. Bohemia's own cable starts
    it over in each of its pieces; this one starts it over whenever it runs out, as a
    separate tube, so the restart is a clean seam rather than one face smeared back across
    the whole strip."""
    lengths = [0.0]
    for a, b in zip(path, path[1:]):
        lengths.append(lengths[-1] + float(np.linalg.norm(b - a)))
    strip = (CABLE_U[1] - CABLE_U[0]) / CABLE_U_PER_M
    runs, start = [], 0
    for i in range(1, len(path)):
        if i == len(path) - 1 or lengths[i + 1] - lengths[start] > strip:
            runs.append((start, i))
            start = i
    fr = frames(path)
    for a, b in runs:
        offsets = [x - lengths[a] for x in lengths[a:b + 1]]
        tube(mesh, path[a:b + 1], COAX_RADIUS, sides,
             lambda i, k, offsets=offsets: (CABLE_U[0] + offsets[i] * CABLE_U_PER_M,
                                            CABLE_V[0] + (CABLE_V[1] - CABLE_V[0]) * k / sides),
             fr=fr[a:b + 1])
    return len(runs)


def build_plug(mesh, sides):
    lathe(mesh, PLUG_PROFILE, (0.0, PLUG_AXIS[0], PLUG_AXIS[1]), (1.0, 0.0, 0.0), sides,
          lambda t, s: plug_uv(t, s))


def lathe(mesh, profile, origin, axis, sides, uv_fn, material=MATERIAL, closed=False):
    """Solid of revolution, profile [(t, r)] along the axis. Faces are flat along the
    profile and smooth round it; uv_fn(t, s) with s going once round, 0..1."""
    o = np.asarray(origin, float)
    t_dir = norm(axis)
    ref = np.array([0.0, 1.0, 0.0]) if abs(t_dir[1]) < 0.9 else np.array([0.0, 0.0, 1.0])
    n0 = norm(np.cross(np.cross(t_dir, ref), t_dir))
    b0 = np.cross(t_dir, n0)
    dirs = [n0 * math.cos(2 * math.pi * k / sides) + b0 * math.sin(2 * math.pi * k / sides)
            for k in range(sides + 1)]
    for (ta, ra), (tb, rb) in zip(profile, profile[1:]):
        dt, dr = tb - ta, rb - ra
        span = math.hypot(dt, dr)
        if span < 1e-9:
            continue
        na, nr = -dr / span, dt / span
        for k in range(sides):
            mesh.add([(o + t_dir * t + dirs[kk] * r, t_dir * na + dirs[kk] * nr, uv_fn(t, kk / sides))
                      for kk, (t, r) in ((k, (ta, ra)), (k + 1, (ta, ra)), (k + 1, (tb, rb)), (k, (tb, rb)))],
                     material)
    if closed:
        for (t, r), sign in ((profile[0], -1.0), (profile[-1], 1.0)):
            centre = o + t_dir * t
            for k in range(sides):
                mesh.add([(centre, t_dir * sign, (0.0, 0.0)),
                          (centre + dirs[k] * r, t_dir * sign, (0.0, 0.0)),
                          (centre + dirs[k + 1] * r, t_dir * sign, (0.0, 0.0))], material)


# ------------------------------------------------------------------------------ the bend
def bend_rotation(x):
    """How the wand's cross section at x is turned by the sways it has passed."""
    side = 0.0
    for centre, degrees in SWAYS:
        t = min(max((centre + SWAY_REACH - x) / (2 * SWAY_REACH), 0.0), 1.0)
        side += math.radians(degrees) * t * t * (3 - 2 * t)
    cs, ss = math.cos(side), math.sin(side)
    return np.array([[cs, 0.0, ss], [0.0, 1.0, 0.0], [-ss, 0.0, cs]])


def bend_axis():
    """The bent centre line, sampled by the distance along it from BEND_START: the same
    length as the straight one, so the wand does not stretch."""
    x = np.linspace(BEND_START, BEND_END, 2048)
    ahead = np.array([bend_rotation(v) @ np.array([-1.0, 0.0, 0.0]) for v in x])
    step = (x[0] - x[1]) * (ahead[:-1] + ahead[1:]) / 2
    return x, np.vstack([np.zeros(3), np.cumsum(step, axis=0)]) + np.array([BEND_START, 0.0, 0.0])


BEND_X, BEND_LINE = bend_axis()


def bent(mesh):
    """The mesh with the cable swaying and everything beyond it carried along. Each cross
    section moves as a whole, so winding and closed volumes survive, and whatever lies on
    the mount's side of BEND_START keeps its exact coordinates."""
    out = Mesh()
    for corners, material in mesh.faces:
        moved = []
        for p, n, uv in corners:
            p = np.asarray(p, float)
            if p[0] < BEND_START:
                x = max(p[0], BEND_END)
                turn = bend_rotation(x)
                line = np.array([np.interp(-x, -BEND_X, BEND_LINE[:, k]) for k in range(3)])
                p, n = line + turn @ np.array([p[0] - x, p[1], p[2]]), turn @ np.asarray(n, float)
            moved.append((p, n, uv))
        out.faces.append((moved, material))
    return out


def subdivide(mesh, detail):
    """Cut every face that runs through a sway across the wand's axis, so the turn has rings
    to act on: the lathe's cable is one long ring of quads, and the lengths between sways
    stay straight and need none. Points, normals and UVs are interpolated, so the straight
    mesh looks just as it did, and neighbouring faces are cut at the same places, so no
    T-junctions appear."""
    steps = (-1.0, -0.5, 0.0, 0.5, 1.0) if detail else (-1.0, 0.0, 1.0)
    levels = [sway[0] + s * SWAY_REACH for sway in SWAYS for s in steps]

    def split(corner, other, x):
        # The same way round from either face, so both get the very same point.
        if tuple(corner[0]) > tuple(other[0]):
            corner, other = other, corner
        k = (x - corner[0][0]) / (other[0][0] - corner[0][0])
        mix = lambda a, b: np.asarray(a, float) + (np.asarray(b, float) - np.asarray(a, float)) * k
        return mix(corner[0], other[0]), norm(mix(corner[1], other[1])), tuple(mix(corner[2], other[2]))

    def clip(corners, x, keep):
        out = []
        for a, b in zip(corners, corners[1:] + corners[:1]):
            if keep(a[0][0]):
                out.append(a)
            if keep(a[0][0]) != keep(b[0][0]):
                out.append(split(a, b, x))
        return out

    result = Mesh()
    for corners, material in mesh.faces:
        xs = [c[0][0] for c in corners]
        cuts = [v for v in levels if min(xs) + 1e-6 < v < max(xs) - 1e-6]
        rest = list(corners)
        for x in sorted(cuts):
            piece = clip(rest, x, lambda v, x=x: v <= x)
            rest = clip(rest, x, lambda v, x=x: v >= x)
            result.faces.extend((part, material) for part in convex_pieces(piece))
        result.faces.extend((part, material) for part in convex_pieces(rest))
    return result


def convex_pieces(corners):
    """A convex polygon as faces Arma can hold, which have three or four corners."""
    if len(corners) <= 4:
        return [corners]
    return [[corners[0], corners[i], corners[i + 1]] for i in range(1, len(corners) - 1)]


# ------------------------------------------------------------------------------ LODs
def wand_mesh(fixed, detail):
    mesh = Mesh()
    mesh.faces = fixed.faces + endoscope(detail).faces
    return mesh


def resolution_lod(resolution, fixed, detail):
    lod = Lod(resolution)
    lod.mesh(bent(subdivide(wand_mesh(fixed, detail), detail)))
    extra = Mesh()
    sides = 8 if detail else 5
    build_coil(extra, CABLE_RADIUS, 10 if detail else 6)
    build_cable(extra, coax_path(3.0 if detail else 10.0), sides)
    build_plug(extra, 12 if detail else 8)
    lod.mesh(extra)
    return lod.finish()


def convex_hull(points, eps=1e-9):
    """Triangles (i, j, k) of the convex hull, wound counter clockwise seen from outside.
    Quickhull: start from a tetrahedron, then always take the point furthest outside, let
    it eat the connected patch of faces it sees and close the hole with a fan from the
    horizon. Furthest first and a connected patch keep the many coplanar points of a cut
    from tearing the hull. eps is in metres, a point closer than that to a face counts as
    on it; keep it far below the spacing of the points (slab_hulls() puts them on a 10 um
    grid), as a tolerance anywhere near that spacing lets a patch grow round a face it
    skipped, and the hull folds. Returns [] for a flat set."""
    p = np.asarray(points, float)
    if len(p) < 4:
        return []
    a = int(np.argmin(p[:, 0]))
    b = int(np.argmax(np.linalg.norm(p - p[a], axis=1)))
    ab = p[b] - p[a]
    c = int(np.argmax(np.linalg.norm(np.cross(ab, p - p[a]), axis=1)))
    n = np.cross(ab, p[c] - p[a])
    if np.linalg.norm(n) < 1e-12:
        return []
    n = n / np.linalg.norm(n)
    d = int(np.argmax(np.abs((p - p[a]) @ n)))
    if abs((p[d] - p[a]) @ n) < eps:
        return []
    if (p[d] - p[a]) @ n > 0:
        b, c = c, b

    faces, owner = {}, {}  # face -> (normal, offset); directed edge -> face

    def add(f):
        n = np.cross(p[f[1]] - p[f[0]], p[f[2]] - p[f[0]])
        n = n / (np.linalg.norm(n) or 1.0)
        faces[f] = (n, n @ p[f[0]])
        for k in range(3):
            owner[(f[k], f[(k + 1) % 3])] = f

    for f in ((a, b, c), (a, d, b), (b, d, c), (c, d, a)):
        add(f)
    done = {a, b, c, d}
    while True:
        keys = list(faces)
        normals = np.array([faces[f][0] for f in keys])
        offsets = np.array([faces[f][1] for f in keys])
        dist = p @ normals.T - offsets  # points x faces
        dist[list(done)] = -1.0
        best = np.unravel_index(int(np.argmax(dist)), dist.shape)
        if dist[best] <= eps:
            return sorted(faces)
        i, start = int(best[0]), keys[best[1]]
        done.add(i)
        seen, todo = {start}, [start]
        while todo:  # the connected patch i sees
            f = todo.pop()
            for k in range(3):
                g = owner.get((f[(k + 1) % 3], f[k]))
                if g not in seen and faces[g][0] @ p[i] - faces[g][1] > eps:
                    seen.add(g)
                    todo.append(g)
        horizon = [(f[k], f[(k + 1) % 3]) for f in seen for k in range(3)
                   if owner[(f[(k + 1) % 3], f[k])] not in seen]
        for f in seen:
            del faces[f]
            for k in range(3):
                if owner.get((f[k], f[(k + 1) % 3])) == f:
                    del owner[(f[k], f[(k + 1) % 3])]
        for u, v in horizon:
            add((u, v, i))


def components(faces):
    """The face lists of the separate pieces of a mesh, joined where corners meet."""
    key = lambda q: tuple(round(float(c) * 1e6) for c in q)
    parent = {}

    def find(k):
        while parent.setdefault(k, k) != k:
            parent[k] = parent[parent[k]]
            k = parent[k]
        return k

    for corners, _material in faces:
        first = find(key(corners[0][0]))
        for corner in corners[1:]:
            parent[find(key(corner[0]))] = first
    groups = {}
    for face in faces:
        groups.setdefault(find(key(face[0][0][0])), []).append(face)
    return [groups[k] for k in sorted(groups)]


def slab_hulls(mesh, out, gap, inset, bins=None):
    """Each piece of the mesh cut into slabs across the wand's axis, every slab replaced by
    its convex hull: closed by construction, and as close to the visible surface as a set
    of convex pieces gets. Appends one Mesh per hull to out. The slabs are bounded where the mesh has its rings of corners,
    no two closer than gap; each hull is pulled in by inset towards the slab's middle, in
    the plane of the cut only, so neighbouring slabs still meet. bins: keep only the
    outermost point per angle bin and slab side, for a coarse LOD."""
    for piece in components(mesh.faces):
        edges = []
        for corners, _material in piece:
            pts = [np.asarray(q[0], float) for q in corners]
            edges += [(pts[k], pts[(k + 1) % len(pts)]) for k in range(len(pts))]
        xs = sorted({round(float(e[0][0]), 6) for e in edges})
        levels = [xs[0]]
        for x in xs[1:]:
            if x - levels[-1] >= gap:
                levels.append(x)
        if levels[-1] != xs[-1]:
            if len(levels) > 1 and xs[-1] - levels[-1] < gap / 2:
                levels[-1] = xs[-1]
            else:
                levels.append(xs[-1])
        for x0, x1 in zip(levels, levels[1:]):
            pts = []
            for p, q in edges:
                for r in (p, q):
                    if x0 - 1e-7 <= r[0] <= x1 + 1e-7:
                        pts.append(r)
                lo, hi = (p, q) if p[0] < q[0] else (q, p)
                for x in (x0, x1):
                    if lo[0] < x - 1e-7 and hi[0] > x + 1e-7:
                        pts.append(lo + (hi - lo) * (x - lo[0]) / (hi[0] - lo[0]))
            pts = np.unique(np.round(np.array(pts), 6), axis=0)
            centre = pts[:, 1:].mean(axis=0)
            radial = pts[:, 1:] - centre
            r = np.linalg.norm(radial, axis=1)
            if bins:
                angle = np.floor((np.arctan2(radial[:, 1], radial[:, 0]) + math.pi)
                                 / (2 * math.pi) * bins).astype(int)
                side = pts[:, 0] > (x0 + x1) / 2
                best = {}
                for k in range(len(pts)):
                    slot = (side[k], angle[k])
                    if slot not in best or r[k] > r[best[slot]]:
                        best[slot] = k
                keep = sorted(best.values())
                pts, radial, r = pts[keep], radial[keep], r[keep]
                # Out to the slab's ends, or neighbouring slabs would leave gaps.
                pts = pts.copy()
                pts[:, 0] = np.where(side[keep], x1, x0)
            scale = np.maximum(r - inset, r * 0.85) / np.where(r > 1e-9, r, 1.0)
            pts = np.column_stack([pts[:, 0], centre + radial * scale[:, None]])
            # On a 10 um grid: coarser than Lod.point() merges corners by, so no face
            # collapses there, and no near twins for the hull to choke on.
            pts = np.unique(np.round(pts, 5), axis=0)
            hull = Mesh()
            for f in convex_hull(pts):
                tri = [pts[k] for k in f]
                n = norm(np.cross(tri[1] - tri[0], tri[2] - tri[0]))
                hull.add([(q, n, (0.0, 0.0)) for q in tri], "")
            if hull.faces:
                out.append(hull)


def shadow_mesh(fixed, detail):
    """Closed pieces, a little inside the visible surface: what a shadow volume wants. What
    lies along the wand's axis as slab hulls of its own visible mesh, which is not closed
    itself where the connector meets the collar; coil, coax and plug, which do not, as closed
    solids of the same shape as their visible ones."""
    pieces = []
    flat = lambda *_: (0.0, 0.0)
    slab_hulls(subdivide(wand_mesh(fixed, detail), detail), pieces, 0.001, 0.0006, None if detail else 8)
    m = Mesh()
    build_coil(m, CABLE_RADIUS - 0.0006, 8 if detail else 6, "", True)
    tube(m, coax_path(6.0 if detail else 20.0, 0.06 if detail else 0.08), COAX_RADIUS - 0.0004,
         6 if detail else 4, flat, material="", caps=True)
    plug = [(t, max(r - 0.0004, 0.0005)) for t, r in PLUG_PROFILE]
    lathe(m, plug, (0.0, PLUG_AXIS[0], PLUG_AXIS[1]), (1.0, 0.0, 0.0), 12 if detail else 6, flat,
          material="", closed=True)
    # Bent as hulls, not before: the cut into slabs relies on the wand's axis being X. The
    # coil and the coax lie behind BEND_START.
    return [bent(piece) for piece in pieces] + [m]


def shadow_lod(resolution, pieces):
    """Every edge sharp, as a shadow volume must have them. Each piece gets points of its
    own: where two slabs meet, their rings may lie on the same spot, and sharing those
    points would leave edges with four faces on them instead of two."""
    lod = Lod(resolution)
    for piece in pieces:
        lod._points = {}
        lod.mesh(piece, triangles=True)
    return lod.sharp_edges()


def shadow_buffer_lod(resolution, pieces):
    """What the shadow map is drawn from, as on antenna 03, whose visual LODs then cast no
    shadow of their own (lodnoshadow). The same closed pieces as the shadow volume, so
    near and far shadows have the same outline."""
    lod = Lod(resolution)
    for piece in pieces:
        lod._points = {}
        lod.mesh(piece, triangles=True)
    return lod.lod


def manifold(lod):
    """Edges that are not used exactly twice, once each way: 0 for a proper volume."""
    count = {}
    for f in lod.faces:
        ids = [v[0] for v in f.verts]
        for k in range(len(ids)):
            e = (ids[k], ids[(k + 1) % len(ids)])
            count[e] = count.get(e, 0) + 1
    return sum(1 for (a, b), n in count.items() if n != 1 or count.get((b, a)) != 1)


def geometry_lod(mass):
    lod = fbx_to_p3d.geometry_lod((-DEFAULT_LENGTH, 0.0, -0.10, COLLAR[2][1], -COLLAR[2][1], COLLAR[2][1]), mass)
    # As on Bohemia's antennas: the origin is the mount point and has to stay there.
    lod.add_property("autocenter", "0")
    return lod


# ------------------------------------------------------------------------------ materials
def stage(n, texture, scale=1, extra=""):
    return ("class Stage%d {\n    texture = \"%s\";\n%s    uvSource = \"tex\";\n"
            "    class uvTransform {\n        aside[] = {%d,0,0};\n        up[] = {0,1,0};\n"
            "        dir[] = {0,0,0};\n        pos[] = {0,0,0};\n    };\n};\n\n"
            % (n, texture, extra, scale))


def write_rubber_material():
    """Bohemia's esd_01.rvmat with less of everything: the plain panel of their atlas comes
    out as dull black rubber, the way the cable of a real endoscope looks, and its smooth
    surface needs no normal map. """
    text = (
        "// Generated by tools/build_camhead.py - change the script, not this file.\n"
        "//\n"
        "// The endoscope's black rubber: the plain panel of Bohemia's atlas, darker and duller\n"
        "// than their esd_01.rvmat renders it.\n\n"
        "class StageTI {\n    texture = \"a3\\data_f\\default_vehicle_ti_ca.paa\";\n};\n\n"
        "ambient[] = {0.45,0.45,0.45,1};\ndiffuse[] = {0.5,0.5,0.5,1};\nforcedDiffuse[] = {0,0,0,1};\n"
        "emmisive[] = {0,0,0,0};\nspecular[] = {0.12,0.12,0.12,1};\nspecularPower = 30;\n"
        "PixelShaderID = \"Super\";\nVertexShaderID = \"Super\";\n\n"
        + stage(1, "#(argb,8,8,3)color(0.5,0.5,1,1,NOHQ)")
        + stage(2, "#(argb,8,8,3)color(0.5,0.5,0.5,0.5,DT)")
        + stage(3, "#(argb,8,8,3)color(0.0,0.0,0.0,0.0,MC)")
        + stage(4, BI_DATA + "\\esd_01_as.paa")
        + stage(5, BI_DATA + "\\esd_01_smdi.paa")
        + stage(6, "#(ai,64,64,1)fresnel(0.4,0.2)")
        + stage(7, "a3\\data_f\\env_land_co.paa", extra="    useWorldEnvMap = \"true\";\n")
    )
    path = os.path.join(HERE, "addons", "esdcam", "data", "camhead_rubber.rvmat")
    with open(path, "w", newline="\n") as handle:
        handle.write(text.rstrip("\n") + "\n")


# ------------------------------------------------------------------------------ lens
def write_lens_material():
    """Glass as far as the shader goes: full specular, a tight highlight and a strong
    reflection of the sky. forcedDiffuse keeps the painted reflections of lens_colour()
    readable when the lens faces away from the sun, without making it glow in the dark."""
    text = (
        "// Generated by tools/build_camhead.py - change the script, not this file.\n"
        "//\n"
        "// The camera wand's lens: glass with its reflections painted into camhead_lens_co.paa.\n\n"
        "class StageTI {\n    texture = \"a3\\data_f\\default_vehicle_ti_ca.paa\";\n};\n\n"
        "ambient[] = {1,1,1,1};\ndiffuse[] = {1,1,1,1};\nforcedDiffuse[] = {0.6,0.6,0.6,1};\n"
        "emmisive[] = {0,0,0,0};\nspecular[] = {1,1,1,1};\nspecularPower = 300;\n"
        "PixelShaderID = \"Super\";\nVertexShaderID = \"Super\";\n\n"
        + stage(1, "#(argb,8,8,3)color(0.5,0.5,1,1,NOHQ)")
        + stage(2, "#(argb,8,8,3)color(0.5,0.5,0.5,0.5,DT)")
        + stage(3, "#(argb,8,8,3)color(0.0,0.0,0.0,0.0,MC)")
        + stage(4, "#(argb,8,8,3)color(1,1,1,1,AS)")
        + stage(5, "#(argb,8,8,3)color(1,1,1,1,SMDI)")
        + stage(6, "#(ai,64,64,1)fresnel(1.3,0.9)")
        + stage(7, "a3\\data_f\\env_land_co.paa", extra="    useWorldEnvMap = \"true\";\n")
    )
    path = os.path.join(HERE, "addons", "esdcam", "data", "camhead_lens.rvmat")
    with open(path, "w", newline="\n") as handle:
        handle.write(text.rstrip("\n") + "\n")


def lens_colour():
    """The front of the camera head, painted: glass with the violet and green sheen of an
    anti-reflection coating, a dark pupil and two highlights, in a ring of white LEDs. Not a
    real reflection, but at a centimetre across nobody can tell, and it reads as a lens from
    any angle and in any light. The top of the picture is the top of the lens."""
    size = 256
    v, u = np.mgrid[0:size, 0:size]
    face_x, face_y = (u + 0.5) / size * 2 - 1, (v + 0.5) / size * 2 - 1
    # The lens takes up the middle of the face, the LEDs the ring round it.
    x, y = face_x / 0.66, face_y / 0.66
    r = np.hypot(x, y)
    around = np.arctan2(y, x)

    def glow(cx, cy, rx, ry):
        return np.exp(-(((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2))

    def band(radius, width, towards, spread):
        off = np.angle(np.exp(1j * (around - towards)))
        return np.exp(-((r - radius) / width) ** 2) * np.exp(-(off / spread) ** 2)

    def add(colour, amount):
        rgb[:] = rgb + np.array(colour)[None, None, :] * amount[:, :, None]

    rgb = np.zeros((size, size, 3)) + np.array([0.03, 0.03, 0.06])
    glass = np.clip((0.86 - r) / 0.02, 0, 1)
    add((0.03, 0.05, 0.12), glass * (1 - r))
    add((0.62, 0.18, 0.85), glass * band(0.60, 0.20, math.radians(-135), 1.0))
    add((0.10, 0.70, 0.55), glass * band(0.50, 0.17, math.radians(45), 0.9))
    add((0.15, 0.35, 0.95), glass * band(0.72, 0.09, math.radians(-30), 0.8))
    add((0.60, 0.42, 0.10), glass * band(0.36, 0.08, math.radians(150), 0.7))
    pupil = np.clip((r - 0.20) / 0.07, 0, 1)
    rgb[:] = rgb * pupil[:, :, None] + np.array([0.01, 0.01, 0.02])[None, None, :] * (1 - pupil[:, :, None])
    add((1.0, 1.0, 1.0), glass * glow(-0.34, -0.40, 0.20, 0.13))
    add((0.8, 0.9, 1.0), glass * glow(0.32, 0.38, 0.07, 0.05))
    # The barrel: dark metal with one bright ring where it holds the glass.
    barrel = np.clip((r - 0.86) / 0.02, 0, 1)[:, :, None]
    rgb[:] = rgb * (1 - barrel) + 0.07 * barrel
    add((0.42, 0.42, 0.45), np.exp(-((r - 0.88) / 0.018) ** 2))
    for a in np.linspace(0, 2 * math.pi, 8, endpoint=False):
        add((0.95, 0.98, 1.0), np.exp(-((face_x - 0.79 * math.cos(a)) ** 2 + (face_y - 0.79 * math.sin(a)) ** 2) / 0.085 ** 2))
    add((0.30, 0.30, 0.32), np.exp(-((np.hypot(face_x, face_y) - 0.97) / 0.03) ** 2))

    out = np.zeros((size, size, 4), np.uint8)
    out[:, :, :3] = np.clip(rgb * 255, 0, 255)
    out[:, :, 3] = 255
    return out


# ------------------------------------------------------------------------------ main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fbx", default=os.path.join(HERE, "art", "esdcam", "arma3_cam.fbx"))
    ap.add_argument("--reference", default=os.path.join(
        HERE, "art", "esdcam", "reference", "muzzle_antenna_03_F_mlod.p3d"))
    ap.add_argument("--out", default=MODEL)
    ap.add_argument("--mass", type=float, default=0.5, help="kg, geometry LOD")
    args = ap.parse_args()

    print("camhead.p3d")
    # The reference whenever it is there. The committed model is read before anything is
    # written, so it is still the one from git even when --out is that same file.
    if os.path.isfile(args.reference):
        print("  mount head UVs: projected onto %s" % shown(args.reference))
        mount = Reference(args.reference)
    elif os.path.isfile(MODEL):
        print("  mount head UVs: no %s, so taken from %s as committed"
              % (shown(args.reference), shown(MODEL)))
        mount = StoredHead(MODEL)
    else:
        raise SystemExit("%s missing - an MLOD of Bohemia's muzzle_antenna_03_F - and no %s "
                         "to take the mount head from either" % (args.reference, MODEL))
    tool = imagetopaa.find_imagetopaa()

    fixed = connector(read_wand(args.fbx, DEFAULT_LENGTH), mount)
    lod1, lod2 = resolution_lod(1.0, fixed, True), resolution_lod(2.0, fixed, False)
    # Antenna 03's arrangement: the visual LODs cast no shadow, shadow volumes and a
    # shadow buffer LOD do it for them.
    for lod in (lod1, lod2):
        lod.add_property("lodnoshadow", "1")
    near, far = shadow_mesh(fixed, True), shadow_mesh(fixed, False)
    shadow, shadow_far = shadow_lod(p3d.LOD_SHADOW, near), shadow_lod(p3d.LOD_SHADOW + 10, far)
    buffer = shadow_buffer_lod(SHADOW_BUFFER, near)
    open_edges = manifold(shadow) + manifold(shadow_far)
    volume, flux = fbx_to_p3d.check(lod1)
    size = p3d.write(args.out, [lod1, lod2, shadow, shadow_far, buffer, geometry_lod(args.mass),
                                fbx_to_p3d.memory_lod(DEFAULT_LENGTH)])

    write_rubber_material()
    write_lens_material()
    if tool:
        imagetopaa.to_paa(tool, lens_colour(),
                          os.path.join(HERE, "addons", "esdcam", "data", "camhead_lens_co.paa"))

    for name, lod in (("LOD 1", lod1), ("LOD 2", lod2), ("shadow", shadow),
                      ("shadow far", shadow_far), ("buffer", buffer)):
        print("  %-10s %5d points %5d faces" % (name, len(lod.points), len(lod.faces)))
    print("  shadow volumes: %d pieces near, %d far, %d edges not closed"
          % (len(near), len(far), open_edges))
    print("  winding %+.6f  normals %+.6f  %s" % (
        volume, flux, "ok" if volume < 0 and flux < 0 else "INSIDE OUT"))
    print("  %d bytes" % size)
    if not tool:
        print("  camhead_lens_co.paa not written: no ImageToPAA (Arma 3 Tools, or set IMAGETOPAA).\n"
              "  The one in git is lens_colour() and nothing else, so it holds until that changes.")
    if volume >= 0 or flux >= 0:
        raise SystemExit("model is inside out")
    if open_edges:
        raise SystemExit("shadow volume is not closed")


if __name__ == "__main__":
    main()
