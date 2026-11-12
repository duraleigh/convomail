# Makes Précis's own "sent" sound: two soft rising notes, about a third of a
# second, quiet. Written from scratch here (no outside sound file is used).
#
#   python tool/make_sent_sound.py
import math
import os
import struct
import wave

RATE = 44100
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')


def note(freq, start, length, level):
    """One soft bell-like note: a pure tone with a little of its octave, a quick rise and a slow fall."""
    out = {}
    for i in range(int(length * RATE)):
        t = i / RATE
        rise = min(1.0, t / 0.012)
        fall = math.exp(-t * 9.0)
        v = math.sin(2 * math.pi * freq * t) + 0.22 * math.sin(2 * math.pi * freq * 2 * t) + 0.08 * math.sin(2 * math.pi * freq * 3 * t)
        out[int(start * RATE) + i] = level * rise * fall * v
    return out


total = int(0.42 * RATE)
mix = [0.0] * total
for part in (note(659.25, 0.00, 0.30, 0.30), note(987.77, 0.085, 0.33, 0.26)):
    for i, v in part.items():
        if i < total:
            mix[i] += v
# A gentle fade at the very end so it never clicks.
for i in range(total - 800, total):
    mix[i] *= (total - i) / 800
peak = max(abs(v) for v in mix)
frames = b''.join(struct.pack('<h', int(max(-1.0, min(1.0, v / peak * 0.42)) * 32767)) for v in mix)
for path in (os.path.join(root, 'assets', 'sounds', 'sent.wav'), os.path.join(root, 'android', 'app', 'src', 'main', 'res', 'raw', 'sent.wav')):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)
    print(os.path.relpath(path, root), os.path.getsize(path), 'bytes')
