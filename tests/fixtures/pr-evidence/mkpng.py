#!/usr/bin/env python3
"""Write a small PNG for tests/fm-pr-evidence.test.sh with no external tool.

Usage: mkpng.py <out.png> <seed> <mark-pixels>
The image is 80x80 RGBA. <seed> changes the content hash. <mark-pixels> pixels
use the exact gate mark colour (#FF2D95), so 0 gives an unmarked image.
"""
import struct
import sys
import zlib

out, seed, marks = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
w = h = 80
rows = []
count = 0
for y in range(h):
    row = bytearray([0])
    for x in range(w):
        if count < marks:
            row += bytes((0xFF, 0x2D, 0x95, 0xFF))
            count += 1
        else:
            row += bytes(((x * 3 + seed) % 40, (y * 3 + seed * 7) % 40, (seed * 11) % 40, 0xFF))
    rows.append(bytes(row))


def chunk(tag, data):
    body = tag + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


with open(out, "wb") as fh:
    fh.write(b"\x89PNG\r\n\x1a\n")
    fh.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)))
    fh.write(chunk(b"IDAT", zlib.compress(b"".join(rows))))
    fh.write(chunk(b"IEND", b""))
