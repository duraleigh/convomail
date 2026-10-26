"""Generates assets/badges/badge_1.ico … badge_9.ico and badge_9plus.ico:
a 32x32 red circle with a white count, as PNG-in-ICO (what the Windows
taskbar overlay reads). Pure Python, no Pillow."""
import os, struct, zlib

W = H = 32
FONT = {  # 3x5 glyphs
    '0': ['111', '101', '101', '101', '111'], '1': ['010', '110', '010', '010', '111'],
    '2': ['111', '001', '111', '100', '111'], '3': ['111', '001', '111', '001', '111'],
    '4': ['101', '101', '111', '001', '001'], '5': ['111', '100', '111', '001', '111'],
    '6': ['111', '100', '111', '101', '111'], '7': ['111', '001', '010', '010', '010'],
    '8': ['111', '101', '111', '101', '111'], '9': ['111', '101', '111', '001', '111'],
    '+': ['000', '010', '111', '010', '000'],
}

def render(text):
    px = [[(0, 0, 0, 0) for _ in range(W)] for _ in range(H)]
    cx = cy = (W - 1) / 2
    r = W / 2 - 1
    for y in range(H):
        for x in range(W):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= r:
                a = 255 if d <= r - 1 else int(255 * (r - d))
                px[y][x] = (211, 47, 47, a)
    scale = 3
    gw = 3 * scale + scale  # glyph + gap
    total = len(text) * gw - scale
    ox = int((W - total) / 2)
    oy = int((H - 5 * scale) / 2)
    for i, ch in enumerate(text):
        g = FONT[ch]
        for gy in range(5):
            for gx in range(3):
                if g[gy][gx] == '1':
                    for sy in range(scale):
                        for sx in range(scale):
                            x = ox + i * gw + gx * scale + sx
                            y = oy + gy * scale + sy
                            if 0 <= x < W and 0 <= y < H:
                                px[y][x] = (255, 255, 255, 255)
    return px

def png_bytes(px):
    raw = b''.join(b'\x00' + b''.join(struct.pack('BBBB', *p) for p in row) for row in px)
    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')

def ico_bytes(png):
    header = struct.pack('<HHH', 0, 1, 1)
    entry = struct.pack('<BBBBHHII', W, H, 0, 0, 1, 32, len(png), 6 + 16)
    return header + entry + png

out = os.path.join(os.path.dirname(__file__), '..', 'assets', 'badges')
os.makedirs(out, exist_ok=True)
for n in range(1, 10):
    open(os.path.join(out, f'badge_{n}.ico'), 'wb').write(ico_bytes(png_bytes(render(str(n)))))
open(os.path.join(out, 'badge_9plus.ico'), 'wb').write(ico_bytes(png_bytes(render('9+'))))
print('wrote badges to', os.path.abspath(out))
