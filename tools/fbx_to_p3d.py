# -*- coding: utf-8 -*-
"""The FBX side of the camera model: reading it, placing it, checking it.

tools/build_camhead.py builds camhead.p3d with what is here - read the binary FBX, put the
mesh into Arma's coordinates, check it is the right way out. Run on its own, this only
measures: --fit-mount derives the wand's length from a vanilla antenna.

    python tools/fbx_to_p3d.py --fit-mount art/esdcam/reference/muzzle_antenna_03_F_mlod.p3d

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
Scale

The FBX carries no real world scale - 13.2 units, which taken literally would be a
13 metre wand - so the size has to come from somewhere else. It comes from the
model itself: the mount head was built off muzzle_antenna_03_F, the SD Jammer
Antenna, and at one single scale factor every feature of it lands on the vanilla
one. Measured against a MLOD copy of that antenna:

    distance from device    antenna 03    this model
              1 mm            42.6 mm       42.5 mm     mounting collar
             30 mm            42.6 mm       42.5 mm
             41 mm            81.0 mm       81.0 mm     shoulder
             60 mm           123.3 mm      123.3 mm     flange
             75 mm            66.2 mm       66.2 mm     start of the tube
             87 mm            65.9 mm       65.9 mm

That is the whole justification for DEFAULT_LENGTH below. --fit-mount re-derives
it from a reference p3d rather than trusting the constant; the reference is a
Bohemia asset, so it lives under art/ and is not part of the repo.

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
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fbx
import p3d

# Overall length in metres, so that the mount head comes out the size of the vanilla
# antenna's - see "Scale" above. muzzle_antenna_03_F itself is 55.6 cm.
DEFAULT_LENGTH = 0.579


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


def memory_lod(length):
    """The vector from konec hlavne to usti hlavne is the direction the head looks, so
    the gap between them only has to be long enough to be well conditioned. A fixed
    fraction of the length keeps it that way at any scale."""
    lod = p3d.Lod(p3d.LOD_MEMORY)
    lod.points = [(-length, 0.0, 0.0, 0), (-length * 0.88, 0.0, 0.0, 0)]
    lod.add_selection("usti hlavne", [1, 0], [])
    lod.add_selection("konec hlavne", [0, 1], [])
    return lod


def radius_profile(path, limit, step=0.0005):
    """Largest radius around the X axis per slice, over the first `limit` metres from
    the device. The shape of the mount head, in a form two models can be compared in."""
    lods, _ = p3d.read(path)
    lod = min(lods, key=lambda l: l.resolution)
    bins = {}
    for x, y, z, _flags in lod.points:
        distance = -x
        if 0.0 <= distance <= limit:
            slot = int(distance / step)
            bins[slot] = max(bins.get(slot, 0.0), math.hypot(y, z))
    return bins, step


def fit_mount(reference, model, limit=0.12):
    """Scale factor that lays this model's mount head onto the reference antenna's.

    The score is the median of the per-slice relative differences, not the mean: the
    two profiles have sharp steps that never land on exactly the same slice, and a
    handful of those outliers would drag a least squares fit off an otherwise exact
    match. Returns (factor, median relative deviation)."""
    ref, step = radius_profile(reference, limit)
    ours, _ = radius_profile(model, limit)

    def at(bins, distance, window=3):
        slot = int(distance / step)
        found = [bins[j] for j in range(slot - window, slot + window + 1) if j in bins]
        return max(found) if found else None

    best = None
    for thousandths in range(500, 4001):
        factor = thousandths / 1000.0
        errors = []
        for j in range(2, int(limit / step)):
            distance = j * step
            want = at(ref, distance)
            have = at(ours, distance / factor)
            if want is None or have is None or want < 0.002:
                continue
            errors.append(abs(math.log(have * factor / want)))
        if len(errors) < 20:
            continue
        score = sorted(errors)[len(errors) // 2]
        if best is None or score < best[0]:
            best = (score, factor)
    if best is None:
        raise SystemExit("cannot fit: %s and %s do not overlap" % (reference, model))
    return best[1], best[0]


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
    ap.add_argument("--model", default=os.path.join(here, "addons", "esdcam", "model", "camhead.p3d"))
    ap.add_argument("--fit-mount", metavar="REFERENCE.p3d", required=True,
                    help="an MLOD of a vanilla antenna to match the mount head to")
    args = ap.parse_args()

    lods, _ = p3d.read(args.model)
    current = max(-p[0] for p in min(lods, key=lambda l: l.resolution).points)
    factor, deviation = fit_mount(args.fit_mount, args.model)
    print("fitted to %s: factor %.4f, median deviation %.2f %% -> length %.4f m (now %.4f)"
          % (os.path.basename(args.fit_mount), factor, 100 * deviation,
             round(current * factor, 4), current))


if __name__ == "__main__":
    main()
