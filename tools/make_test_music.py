"""Writes three 40-second sine-tone WAV files into the given folder for testing."""
import math
import struct
import sys
import wave

TRACKS = [
    "01 - Night Drive on the Neon Highway (Extended Version)",
    "02 - Chrome Hearts",
    "03 - Sunset Arcade",
]
RATE = 8000

folder = sys.argv[1]
for i, name in enumerate(TRACKS):
    freq = 220 * (i + 1)
    with wave.open(f"{folder}/{name}.wav", "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(3000 * math.sin(2 * math.pi * freq * t / RATE)))
            for t in range(RATE * 40)
        ))
