# -*- coding: utf-8 -*-
"""Turn the camera model from arma3_cam.fbx into addons/esdcam/model/camhead.p3d.

Neither Blender nor the Arma 3 Tools are installed here, so this does the export
itself: read the binary FBX, put the mesh into Arma's coordinates, and write MLOD.
Arma loads MLOD directly - binarize only matters for a signed release build.

--------------------------------------------------------------------------------
Placement

Measured off the three vanilla antennas of the Spectrum Device, they all sit with
their origin at the device and reach along -X:

    muzzle_antenna_01_F   X -0.392 .. +0.007    40 cm
    muzzle_antenna_02_F   X -0.410 .. +0.298    71 cm
    muzzle_antenna_03_F   X -0.557 .. +0.000    56 cm

So the mount end of the wand goes to (0,0,0) and the camera head to x = -LENGTH.
In the FBX the long axis is the mesh's local Y, with the head at +Y - read out of
it, not assumed: the `cam` and `blitz` materials sit at the +Y extreme.

--------------------------------------------------------------------------------
Axes, winding and normals

Blender is right handed (X right, Y forward, Z up), Arma is left handed (X right,
Y up, Z forward). Naming the same physical directions therefore flips handedness,
and on top of that the model's long axis has to move from Y to -X:

    arma = (-by, bz, bx) * scale

That map has determinant -1, which is a mirroring, and two things follow from it.
The vertex order is left exactly as it is - the mirroring already turns Blender's
"counter clockwise seen from outside" into Arma's "clockwise seen from outside".
And the normals get an extra minus, because a normal is a pseudovector: under a
map M it transforms as det(M) * M^-T * n, which for an orthogonal M is -M*n.

    normal = -(-ny, nz, nx) = (ny, -nz, -nx)

Both of those are measured, not argued. Over Bohemia's own MLOD samples - the
house, the heli, the car and the boat in Arma 3 Samples - the signed volume of
the mesh and the flux of the stored normals both come out negative, evaluated
with the ordinary right handed formulas. A model that comes out positive in
either is inside out, and Arma culls its front faces: you look straight through
it. check() below measures both and refuses to write a model that fails.

Note what check() deliberately does NOT rely on: that cross(v1-v0, v2-v0) agrees
with the stored normal. It does, in Bohemia's models and in ours - but a model
with both flipped passes that test just as happily, so on its own it proves
nothing about which way round the thing is.
"""

import argparse
import math
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fbx
import p3d

TEXTURE = r"z\opw\addons\esdcam\data\camhead_co.paa"
MATERIAL = r"z\opw\addons\esdcam\data\camhead.rvmat"


def read_mesh(path):
    root, _ = fbx.parse(path)
    geo = root.find("Objects").find("Geometry")
    verts = geo.find("Vertices").props[0]
    poly_index = geo.find("PolygonVertexIndex").props[0]

    normal_layer = geo.find("LayerElementNormal")
    normals = normal_layer.find("Normals").props[0]
    normal_index = normal_layer.find("NormalsIndex")
    normal_index = normal_index.props[0] if normal_index else None

    uv_layer = geo.find("LayerElementUV")
    uv = uv_layer.find("UV").props[0]
    uv_index = uv_layer.find("UVIndex").props[0]

    points = [(verts[i * 3], verts[i * 3 + 1], verts[i * 3 + 2]) for i in range(len(verts) // 3)]

    faces, current = [], []
    for slot, vertex in enumerate(poly_index):
        point = -vertex - 1 if vertex < 0 else vertex
        current.append((point,
                        normal_index[slot] if normal_index else slot,
                        uv_index[slot]))
        if vertex < 0:
            faces.append(current)
            current = []
    return points, normals, uv, faces


def fan(face):
    """P3D faces are triangles or quads; anything wider becomes a fan."""
    if len(face) <= 4:
        return [face]
    return [[face[0], face[i], face[i + 1]] for i in range(1, len(face) - 1)]


def build(path, length, name_note):
    points, normals, uv, faces = read_mesh(path)

    ys = [p[1] for p in points]
    y_min, y_max = min(ys), max(ys)
    scale = length / (y_max - y_min)

    # Centre on the mount end, not on the bounding box: that ring is what plugs into
    # the device, so it is the one that has to sit on the axis.
    ring = [p for p in points if abs(p[1] - y_min) < 1e-4]
    cx = sum(p[0] for p in ring) / len(ring)
    cz = sum(p[2] for p in ring) / len(ring)

    def to_arma(p):
        return (-(p[1] - y_min) * scale, (p[2] - cz) * scale, (p[0] - cx) * scale)

    def dir_to_arma(n):
        # -M*n, not M*n: see "Axes, winding and normals" at the top.
        v = (n[1], -n[2], -n[0])
        d = math.sqrt(v[0] ** 2 + v[1] ** 2 + v[2] ** 2) or 1.0
        return (v[0] / d, v[1] / d, v[2] / d)

    lod = p3d.Lod(p3d.LOD_RESOLUTION)
    lod.points = [to_arma(p) + (0,) for p in points]
    lod.normals = [dir_to_arma((normals[i * 3], normals[i * 3 + 1], normals[i * 3 + 2]))
                   for i in range(len(normals) // 3)]

    uv_pairs = []
    for face in faces:
        for piece in fan(face):
            verts = [(point, normal, uv[u * 2], 1.0 - uv[u * 2 + 1])
                     for point, normal, u in piece]
            lod.faces.append(p3d.Face(verts, TEXTURE, MATERIAL))
            uv_pairs.extend((v[2], v[3]) for v in verts)

    # UV set 0 again as a tagg, the way Object Builder saves it.
    payload = struct.pack("<I", 0) + b"".join(struct.pack("<ff", u, v) for u, v in uv_pairs)
    lod.taggs.append(p3d.Tagg("#UVSet#", payload))

    xs = [p[0] for p in lod.points]
    ys2 = [p[1] for p in lod.points]
    zs = [p[2] for p in lod.points]
    box = (min(xs), max(xs), min(ys2), max(ys2), min(zs), max(zs))

    return lod, box, scale, (cx, y_min, cz)


def geometry_lod(box, mass):
    """One convex box around the whole wand - the same shape the model this replaces
    used. It only ever matters for the item lying on the ground; in the muzzle slot
    the weapon's own geometry is what the engine collides with."""
    x0, x1, y0, y1, z0, z1 = box
    corners = [(x, y, z) for x in (x0, x1) for y in (y0, y1) for z in (z0, z1)]
    lod = p3d.Lod(p3d.LOD_GEOMETRY)
    lod.points = [c + (0,) for c in corners]
    lod.normals = [(-1, 0, 0), (1, 0, 0), (0, -1, 0), (0, 1, 0), (0, 0, -1), (0, 0, 1)]
    #      index = 4*x + 2*y + z, with 0 meaning the low side
    quads = [
        ([0, 1, 3, 2], 0),   # x = x0, outward -X
        ([4, 6, 7, 5], 1),   # x = x1, outward +X
        ([0, 4, 5, 1], 2),   # y = y0, outward -Y
        ([2, 3, 7, 6], 3),   # y = y1, outward +Y
        ([0, 2, 6, 4], 4),   # z = z0, outward -Z
        ([1, 5, 7, 3], 5),   # z = z1, outward +Z
    ]
    for indices, normal in quads:
        pts = [corners[i] for i in indices]
        a = [pts[1][i] - pts[0][i] for i in range(3)]
        b = [pts[2][i] - pts[0][i] for i in range(3)]
        cross = (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
        if sum(cross[i] * lod.normals[normal][i] for i in range(3)) < 0:
            indices = list(reversed(indices))
        lod.faces.append(p3d.Face([(i, normal, 0.0, 0.0) for i in indices]))
    lod.add_mass([mass / 8.0] * 8)
    return lod


def memory_lod(length, tip_gap):
    lod = p3d.Lod(p3d.LOD_MEMORY)
    lod.points = [(-length, 0.0, 0.0, 0), (-length + tip_gap, 0.0, 0.0, 0)]
    lod.add_selection("usti hlavne", [1, 0], [])
    lod.add_selection("konec hlavne", [0, 1], [])
    return lod


def triangles(lod):
    for face in lod.faces:
        pts = [lod.points[v[0]][:3] for v in face.verts]
        nrm = [lod.normals[v[1]] for v in face.verts]
        for k in range(1, len(pts) - 1):
            yield (pts[0], pts[k], pts[k + 1]), (nrm[0], nrm[k], nrm[k + 1])


def _cross(u, w):
    return (u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0])


def check(lod):
    """Is the model the right way out?

    Two numbers, both evaluated with the ordinary right handed formulas, and both
    negative in every MLOD Bohemia ships:

      volume   the signed volume the winding describes.  Sign says whether the faces
               are wound clockwise or counter clockwise seen from outside.
      flux     the divergence integral of the stored normals, which for a closed
               surface is three times the volume.  Sign says which way the normals
               point, independently of the winding.

    Checking them separately matters. Flip both and the model still looks consistent
    with itself while being inside out, which is exactly the mistake this catches.
    """
    volume = flux = 0.0
    for pts, nrm in triangles(lod):
        a, b, c = pts
        volume += (a[0] * (b[1] * c[2] - b[2] * c[1])
                   - a[1] * (b[0] * c[2] - b[2] * c[0])
                   + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6.0
        edge = _cross([b[i] - a[i] for i in range(3)], [c[i] - a[i] for i in range(3)])
        area = 0.5 * math.sqrt(sum(x * x for x in edge))
        n = [(nrm[0][i] + nrm[1][i] + nrm[2][i]) / 3.0 for i in range(3)]
        length = math.sqrt(sum(x * x for x in n)) or 1.0
        mid = [(a[i] + b[i] + c[i]) / 3.0 for i in range(3)]
        flux += area * sum(mid[i] * n[i] / length for i in range(3)) / 3.0
    return volume, flux


def main():
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap = argparse.ArgumentParser()
    ap.add_argument("--fbx", default=os.path.join(here, "art", "esdcam", "arma3_cam.fbx"))
    ap.add_argument("--out", default=os.path.join(here, "addons", "esdcam", "model", "camhead.p3d"))
    ap.add_argument("--length", type=float, default=0.42, help="overall length in metres")
    ap.add_argument("--mass", type=float, default=0.5, help="kg, geometry LOD")
    args = ap.parse_args()

    lod, box, scale, origin = build(args.fbx, args.length, None)
    volume, flux = check(lod)

    lods = [lod,
            geometry_lod(box, args.mass),
            memory_lod(args.length, 0.05)]
    size = p3d.write(args.out, lods)

    print("%s" % os.path.relpath(args.out, here))
    print("  resolution LOD  %d points, %d normals, %d faces" %
          (len(lod.points), len(lod.normals), len(lod.faces)))
    print("  scale           %.6f  (mount ring centred on %.4f, %.4f in FBX X/Z)" %
          (scale, origin[0], origin[2]))
    print("  bounding box    x %.3f .. %.3f   y %.3f .. %.3f   z %.3f .. %.3f" % box)
    print("  winding         signed volume %+.6f  %s" %
          (volume, "ok" if volume < 0 else "INSIDE OUT"))
    print("  normals         flux          %+.6f  %s" %
          (flux, "ok" if flux < 0 else "INSIDE OUT"))
    print("  %d bytes" % size)
    if volume >= 0 or flux >= 0:
        raise SystemExit("model is inside out - Arma would cull its front faces and you "
                         "would look straight through it")


if __name__ == "__main__":
    main()
