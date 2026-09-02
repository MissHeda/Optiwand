# -*- coding: utf-8 -*-
"""Reader and writer for Arma's PAA textures.

Written because neither Arma 3 Tools (ImageToPAA) nor a working LZO binding is on
this machine. Mipmaps are stored uncompressed: PAA marks compression per mipmap
through the top bit of the width, and ImageToPAA itself leaves the smaller levels
uncompressed, so the game reads this happily. The file is bigger than one from
ImageToPAA - not enough to matter for a 42 cm hand-held device.
"""

import struct

TYPE_DXT1 = 0xFF01
TYPE_DXT5 = 0xFF05

_TYPE_NAME = {TYPE_DXT1: "DXT1", TYPE_DXT5: "DXT5"}


# ------------------------------------------------------------------------------ reading
def read(path):
    with open(path, "rb") as handle:
        data = handle.read()
    (kind,) = struct.unpack_from("<H", data, 0)
    pos = 2
    taggs = []
    while data[pos:pos + 4] == b"GGAT":
        name = data[pos + 4:pos + 8][::-1].decode("ascii")
        (length,) = struct.unpack_from("<I", data, pos + 8)
        taggs.append((name, data[pos + 12:pos + 12 + length]))
        pos += 12 + length
    (palette,) = struct.unpack_from("<H", data, pos)
    pos += 2 + palette
    mips = []
    while True:
        width, height = struct.unpack_from("<HH", data, pos)
        if width == 0 and height == 0:
            break
        length = int.from_bytes(data[pos + 4:pos + 7], "little")
        compressed = bool(width & 0x8000)
        mips.append((width & 0x7FFF, height, compressed, data[pos + 7:pos + 7 + length]))
        pos += 7 + length
    return {"type": kind, "name": _TYPE_NAME.get(kind, hex(kind)), "taggs": taggs, "mips": mips}


# ------------------------------------------------------------------------------ DXT
def _pack565(c):
    return ((c[0] >> 3) << 11) | ((c[1] >> 2) << 5) | (c[2] >> 3)


def _unpack565(v):
    r = (v >> 11) & 0x1F
    g = (v >> 5) & 0x3F
    b = v & 0x1F
    return (r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)


def encode_surface(rgba, dxt5):
    """rgba: numpy uint8 array (height, width, 4), both sides a multiple of 4.

    Endpoints come from the colour box of each 4x4 block, inset by a sixteenth to pull
    them off the outliers - the cheap encoder every DXT compressor starts from. Good
    enough for a hand-held prop; nobody is going to read texel noise off a 42 cm wand.
    """
    import numpy as np

    h, w = rgba.shape[:2]
    bh, bw = h // 4, w // 4
    blocks = rgba.reshape(bh, 4, bw, 4, 4).transpose(0, 2, 1, 3, 4).reshape(bh * bw, 16, 4)
    rgb = blocks[:, :, :3].astype(np.int16)

    lo = rgb.min(axis=1)
    hi = rgb.max(axis=1)
    inset = (hi - lo) >> 4
    lo = np.minimum(lo + inset, 255)
    hi = np.maximum(hi - inset, 0)

    def pack(c):
        return (((c[:, 0] >> 3) << 11) | ((c[:, 1] >> 2) << 5) | (c[:, 2] >> 3)).astype(np.uint16)

    c0, c1 = pack(hi), pack(lo)
    # 4-colour mode needs c0 > c1; where the quantised endpoints come out the wrong way
    # round, swap them rather than falling into the 3-colour + transparent mode.
    swap = c0 < c1
    c0, c1 = np.where(swap, c1, c0).astype(np.uint16), np.where(swap, c0, c1).astype(np.uint16)

    def unpack(v):
        v = v.astype(np.int32)
        r = (v >> 11) & 0x1F
        g = (v >> 5) & 0x3F
        b = v & 0x1F
        return np.stack([(r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)], axis=1)

    a, b = unpack(c0), unpack(c1)
    ramp = np.stack([a, b, (2 * a + b) // 3, (a + 2 * b) // 3], axis=1)      # (n, 4, 3)
    d = ((rgb[:, :, None, :] - ramp[:, None, :, :]) ** 2).sum(axis=3)         # (n, 16, 4)
    idx = d.argmin(axis=2).astype(np.uint32)
    flat = c0 == c1
    idx[flat] = 0
    bits = (idx << (2 * np.arange(16, dtype=np.uint32))[None, :]).sum(axis=1, dtype=np.uint64)

    out = np.zeros((bh * bw, 8 if not dxt5 else 16), dtype=np.uint8)
    off = 8 if dxt5 else 0
    out[:, off + 0] = c0 & 0xFF
    out[:, off + 1] = c0 >> 8
    out[:, off + 2] = c1 & 0xFF
    out[:, off + 3] = c1 >> 8
    for k in range(4):
        out[:, off + 4 + k] = (bits >> np.uint64(8 * k)) & np.uint64(0xFF)

    if dxt5:
        alpha = blocks[:, :, 3].astype(np.int16)
        a0 = alpha.max(axis=1)
        a1 = alpha.min(axis=1)
        steps = np.arange(6, dtype=np.int16)
        aramp = np.concatenate([
            np.stack([a0, a1], axis=1),
            ((7 - steps)[None, :] * a0[:, None] + (steps + 1)[None, :] * a1[:, None]) // 7,
        ], axis=1)                                                            # (n, 8)
        ad = np.abs(alpha[:, :, None] - aramp[:, None, :])
        aidx = ad.argmin(axis=2).astype(np.uint64)
        aidx[a0 == a1] = 0
        abits = (aidx << (3 * np.arange(16, dtype=np.uint64))[None, :]).sum(axis=1, dtype=np.uint64)
        out[:, 0] = a0
        out[:, 1] = a1
        for k in range(6):
            out[:, 2 + k] = (abits >> np.uint64(8 * k)) & np.uint64(0xFF)

    return out.tobytes()


# ------------------------------------------------------------------------------ writing
def write(path, mip_surfaces, kind, average, maximum, swizzle=None):
    """mip_surfaces: [(width, height, raw dxt bytes)] largest first."""
    body = bytearray()
    offsets = []
    header_len = 2 + (12 + 4) * 2 + ((12 + 4) if swizzle else 0) + (12 + 64) + 2
    for width, height, raw in mip_surfaces:
        offsets.append(header_len + len(body))
        body += struct.pack("<HH", width, height)
        body += len(raw).to_bytes(3, "little")
        body += raw
    body += b"\0" * 6

    offs = list(offsets) + [0] * (16 - len(offsets))
    out = bytearray()
    out += struct.pack("<H", kind)
    taggs = [("AVGCTAGG", struct.pack("<I", average)),
             ("MAXCTAGG", struct.pack("<I", maximum))]
    if swizzle:
        taggs.append(("SWIZTAGG", swizzle))
    for name, payload in taggs:
        out += b"GGAT" + name[:4].encode("ascii")[::-1] + struct.pack("<I", len(payload)) + payload
    offs_data = struct.pack("<16I", *offs)
    out += b"GGAT" + b"SFFO" + struct.pack("<I", len(offs_data)) + offs_data
    out += struct.pack("<H", 0)
    assert len(out) == header_len, (len(out), header_len)
    out += body
    with open(path, "wb") as handle:
        handle.write(out)
    return len(out)


# ------------------------------------------------------------------------------ decoding
def decode_surface(raw, width, height, dxt5):
    """Decode raw DXT back to a flat list of RGBA tuples, row major."""
    out = [None] * (width * height)
    pos = 0
    for by in range(0, height, 4):
        for bx in range(0, width, 4):
            if dxt5:
                a0, a1 = raw[pos], raw[pos + 1]
                abits = int.from_bytes(raw[pos + 2:pos + 8], "little")
                pos += 8
                if a0 > a1:
                    aramp = [a0, a1] + [((7 - i) * a0 + (i + 1) * a1) // 7 for i in range(6)]
                else:
                    aramp = [a0, a1] + [((5 - i) * a0 + (i + 1) * a1) // 5 for i in range(4)] + [0, 255]
            c0, c1 = struct.unpack_from("<HH", raw, pos)
            (bits,) = struct.unpack_from("<I", raw, pos + 4)
            pos += 8
            a = _unpack565(c0)
            b = _unpack565(c1)
            if c0 > c1:
                ramp = [a, b, tuple((2 * a[i] + b[i]) // 3 for i in range(3)),
                        tuple((a[i] + 2 * b[i]) // 3 for i in range(3))]
            else:
                ramp = [a, b, tuple((a[i] + b[i]) // 2 for i in range(3)), (0, 0, 0)]
            for i in range(16):
                x, y = bx + i % 4, by + i // 4
                if x >= width or y >= height:
                    continue
                c = ramp[(bits >> (2 * i)) & 3]
                al = aramp[(abits >> (3 * i)) & 7] if dxt5 else 255
                out[y * width + x] = (c[0], c[1], c[2], al)
    return out
