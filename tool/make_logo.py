"""Generates assets/logo.png (256x256) for MSIX packaging: a rounded
indigo square with a white speech-bubble mark. Pure Python, no Pillow."""
import os, struct, zlib

W = H = 256
BG = (70, 83, 208)
FG = (255, 255, 255)

def inside_rounded(x, y, r):
    cx = min(max(x, r), W - 1 - r)
    cy = min(max(y, r), H - 1 - r)
    return ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 <= r

def bubble(x, y):
    # Ellipse body plus a tail at the lower left.
    ex, ey, rx, ry = 128, 118, 72, 54
    if ((x - ex) / rx) ** 2 + ((y - ey) / ry) ** 2 <= 1:
        return True
    # tail triangle
    if 66 <= x <= 110 and 150 <= y <= 196:
        return (y - 150) <= (x - 66) * 1.05 and (x - 66) <= 44 - (y - 150) * 0.2
    return False

def dots(x, y):
    for dx in (92, 128, 164):
        if ((x - dx) ** 2 + (y - 118) ** 2) ** 0.5 <= 11:
            return True
    return False

rows = []
for y in range(H):
    row = bytearray(b'\x00')
    for x in range(W):
        if not inside_rounded(x, y, 48):
            row += bytes((0, 0, 0, 0))
        elif bubble(x, y) and not dots(x, y):
            row += bytes(FG) + b'\xff'
        else:
            row += bytes(BG) + b'\xff'
    rows.append(bytes(row))
raw = b''.join(rows)

def chunk(t, d):
    c = struct.pack('>I', len(d)) + t + d
    return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)

png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
out = os.path.join(os.path.dirname(__file__), '..', 'assets', 'logo.png')
open(out, 'wb').write(png)
print('wrote', os.path.abspath(out), len(png), 'bytes')
