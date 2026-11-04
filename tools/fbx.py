# -*- coding: utf-8 -*-
"""Minimal reader for binary FBX files (Kaydara FBX Binary, version 6100-7700).

Only as much of the format as the model pipeline needs: the node tree with its
properties. Enough to pull vertices, polygons, normals, UVs and per-face material
indices out of a Blender export without a Blender install.
"""

import struct
import zlib


class Node:
    __slots__ = ("name", "props", "children")

    def __init__(self, name, props, children):
        self.name = name
        self.props = props
        self.children = children

    def find(self, name):
        for c in self.children:
            if c.name == name:
                return c
        return None

    def find_all(self, name):
        return [c for c in self.children if c.name == name]

    def __repr__(self):
        return "<Node %s props=%d children=%d>" % (self.name, len(self.props), len(self.children))


_ARRAY_FMT = {b"f": ("f", 4), b"d": ("d", 8), b"l": ("q", 8), b"i": ("i", 4), b"b": ("b", 1)}
_SCALAR_FMT = {b"Y": ("<h", 2), b"C": ("<?", 1), b"I": ("<i", 4),
               b"F": ("<f", 4), b"D": ("<d", 8), b"L": ("<q", 8)}


def _read_property(data, pos):
    kind = data[pos:pos + 1]
    pos += 1
    if kind in _SCALAR_FMT:
        fmt, size = _SCALAR_FMT[kind]
        (value,) = struct.unpack_from(fmt, data, pos)
        return value, pos + size
    if kind in _ARRAY_FMT:
        fmt, size = _ARRAY_FMT[kind]
        length, encoding, comp_len = struct.unpack_from("<III", data, pos)
        pos += 12
        raw = data[pos:pos + comp_len]
        pos += comp_len
        if encoding == 1:
            raw = zlib.decompress(raw)
        return list(struct.unpack("<%d%s" % (length, fmt), raw[:length * size])), pos
    if kind in (b"S", b"R"):
        (length,) = struct.unpack_from("<I", data, pos)
        pos += 4
        raw = data[pos:pos + length]
        pos += length
        if kind == b"S":
            return raw.decode("utf-8", "replace"), pos
        return raw, pos
    raise ValueError("unknown FBX property type %r at %d" % (kind, pos - 1))


def _read_node(data, pos, wide):
    if wide:
        end_offset, num_props, prop_len = struct.unpack_from("<QQQ", data, pos)
        pos += 24
    else:
        end_offset, num_props, prop_len = struct.unpack_from("<III", data, pos)
        pos += 12
    (name_len,) = struct.unpack_from("<B", data, pos)
    pos += 1
    if end_offset == 0:
        return None, pos + name_len
    name = data[pos:pos + name_len].decode("utf-8", "replace")
    pos += name_len

    props = []
    for _ in range(num_props):
        value, pos = _read_property(data, pos)
        props.append(value)
    pos = pos + prop_len - prop_len  # properties are contiguous; pos already advanced

    children = []
    while pos < end_offset:
        child, pos = _read_node(data, pos, wide)
        if child is None:
            break
        children.append(child)
    return Node(name, props, children), end_offset


def parse(path):
    """Return (root Node with the top level records as children, fbx version)."""
    with open(path, "rb") as handle:
        data = handle.read()
    if not data.startswith(b"Kaydara FBX Binary"):
        raise ValueError("not a binary FBX: %s" % path)
    (version,) = struct.unpack_from("<I", data, 23)
    wide = version >= 7500
    pos = 27
    top = []
    while pos < len(data) - 16:
        node, pos = _read_node(data, pos, wide)
        if node is None:
            break
        top.append(node)
    return Node("<root>", [], top), version


def dump(node, depth=0, max_depth=6):
    pad = "  " * depth
    summary = []
    for p in node.props:
        if isinstance(p, list):
            summary.append("[%d]" % len(p))
        elif isinstance(p, str):
            summary.append(repr(p[:60]))
        else:
            summary.append(repr(p))
    print("%s%s %s" % (pad, node.name, ", ".join(summary)))
    if depth < max_depth:
        for c in node.children:
            dump(c, depth + 1, max_depth)
