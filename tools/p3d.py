# -*- coding: utf-8 -*-
"""Reader and writer for MLOD P3D (P3DM) files - the format Object Builder saves.

Arma loads MLOD directly, so a model written here works in game without binarize.
"""

import struct


LOD_RESOLUTION = 0.0
LOD_VIEW_GUNNER = 1000.0
LOD_GEOMETRY = 1e13
LOD_MEMORY = 1e15
LOD_LAND_CONTACT = 2e13
LOD_SHADOW = 1e4
LOD_VIEW_GEOMETRY = 6e15
LOD_FIRE_GEOMETRY = 7e15


class Face:
    __slots__ = ("verts", "flags", "texture", "material")

    def __init__(self, verts, texture="", material="", flags=0):
        # verts: list of (point_index, normal_index, u, v), 3 or 4 entries
        self.verts = verts
        self.flags = flags
        self.texture = texture
        self.material = material


class Tagg:
    __slots__ = ("name", "data", "active")

    def __init__(self, name, data, active=True):
        self.name = name
        self.data = data
        self.active = active


class Lod:
    def __init__(self, resolution=LOD_RESOLUTION):
        self.points = []      # (x, y, z, flags)
        self.normals = []     # (x, y, z)
        self.faces = []
        self.taggs = []
        self.resolution = resolution

    def add_property(self, name, value):
        data = name.encode("ascii")[:63].ljust(64, b"\0") + value.encode("ascii")[:63].ljust(64, b"\0")
        self.taggs.append(Tagg("#Property#", data))

    def add_selection(self, name, point_mask, face_mask):
        self.taggs.append(Tagg(name, bytes(point_mask) + bytes(face_mask)))

    def add_mass(self, per_point):
        self.taggs.append(Tagg("#Mass#", struct.pack("<%df" % len(per_point), *per_point)))


def _read_asciiz(data, pos):
    end = data.index(b"\0", pos)
    return data[pos:end].decode("ascii", "replace"), end + 1


def read(path):
    with open(path, "rb") as handle:
        data = handle.read()
    if data[:4] != b"MLOD":
        raise ValueError("not an MLOD p3d: %s" % path)
    version, num_lods = struct.unpack_from("<II", data, 4)
    pos = 12
    lods = []
    for _ in range(num_lods):
        assert data[pos:pos + 4] == b"P3DM", data[pos:pos + 4]
        head = struct.unpack_from("<IIIIII", data, pos + 4)
        _major, _minor, n_pts, n_nrm, n_face, _flags = head
        pos += 28
        lod = Lod()
        for i in range(n_pts):
            x, y, z, f = struct.unpack_from("<fffI", data, pos + i * 16)
            lod.points.append((x, y, z, f))
        pos += n_pts * 16
        for i in range(n_nrm):
            lod.normals.append(struct.unpack_from("<fff", data, pos + i * 12))
        pos += n_nrm * 12
        for _ in range(n_face):
            (n_verts,) = struct.unpack_from("<I", data, pos)
            pos += 4
            verts = []
            for k in range(4):
                pi, ni, u, v = struct.unpack_from("<IIff", data, pos + k * 16)
                verts.append((pi, ni, u, v))
            pos += 64
            (flags,) = struct.unpack_from("<I", data, pos)
            pos += 4
            tex, pos = _read_asciiz(data, pos)
            mat, pos = _read_asciiz(data, pos)
            lod.faces.append(Face(verts[:n_verts], tex, mat, flags))
        assert data[pos:pos + 4] == b"TAGG", data[pos:pos + 4]
        pos += 4
        while True:
            active = data[pos] != 0
            pos += 1
            name, pos = _read_asciiz(data, pos)
            (length,) = struct.unpack_from("<I", data, pos)
            pos += 4
            payload = data[pos:pos + length]
            pos += length
            if name == "#EndOfFile#":
                break
            lod.taggs.append(Tagg(name, payload, active))
        (lod.resolution,) = struct.unpack_from("<f", data, pos)
        pos += 4
        lods.append(lod)
    return lods, version


def write(path, lods, version=257):
    out = bytearray()
    out += b"MLOD" + struct.pack("<II", version, len(lods))
    for lod in lods:
        out += b"P3DM" + struct.pack("<IIIIII", 28, 256,
                                     len(lod.points), len(lod.normals), len(lod.faces), 0)
        for x, y, z, f in lod.points:
            out += struct.pack("<fffI", x, y, z, f)
        for n in lod.normals:
            out += struct.pack("<fff", *n)
        for face in lod.faces:
            verts = list(face.verts) + [(0, 0, 0.0, 0.0)] * (4 - len(face.verts))
            out += struct.pack("<I", len(face.verts))
            for pi, ni, u, v in verts:
                out += struct.pack("<IIff", pi, ni, u, v)
            out += struct.pack("<I", face.flags)
            out += face.texture.encode("ascii") + b"\0"
            out += face.material.encode("ascii") + b"\0"
        out += b"TAGG"
        for tagg in lod.taggs:
            out += bytes([1 if tagg.active else 0])
            out += tagg.name.encode("ascii") + b"\0"
            out += struct.pack("<I", len(tagg.data)) + tagg.data
        out += b"\1" + b"#EndOfFile#\0" + struct.pack("<I", 0)
        out += struct.pack("<f", lod.resolution)
    with open(path, "wb") as handle:
        handle.write(out)
    return len(out)
