#!/usr/bin/env python3
"""Synthesises the game's sound effects into assets/sfx/*.wav (16-bit mono, 22050 Hz).

Soft bell-like tones built from a sine with a little overtone and a quick fade, so they stay
gentle for small kids. Re-run after changing a sound: python3 tools/make_sfx.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")


def tone(freq, dur, vol=0.5, attack=0.005, decay=6.0, overtone=0.25, slide=0.0):
    """One note: sine plus an octave overtone, sharp attack and exponential fade."""
    out = []
    phase = 0.0
    for i in range(int(RATE * dur)):
        t = i / RATE
        phase += 2 * math.pi * freq * (1.0 + slide * t / dur) / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t)
        out.append(vol * env * (math.sin(phase) + overtone * math.sin(2 * phase)))
    return out


def silence(dur):
    return [0.0] * int(RATE * dur)


def at(offset, track):
    return silence(offset) + track


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def noise(dur, vol=0.2, decay=40.0):
    rnd = random.Random(7)
    return [vol * math.exp(-decay * i / RATE) * (rnd.random() * 2 - 1) for i in range(int(RATE * dur))]


def write(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = 0.85 / peak if peak > 0.85 else 1.0
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples))
    print(path)


C5, E5, G5, A5, C6, E6, G6 = 523.25, 659.25, 783.99, 880.0, 1046.5, 1318.5, 1568.0

SOUNDS = {
    # A soft tap for every button.
    "click": tone(1400, 0.05, 0.35, decay=60, overtone=0.1),
    # Two rising notes.
    "correct": mix(tone(E5, 0.35, 0.45, decay=7), at(0.09, tone(A5, 0.45, 0.45, decay=6))),
    # Two gentle falling low notes (not a harsh buzzer).
    "wrong": mix(tone(330, 0.28, 0.45, decay=8, overtone=0.4), at(0.14, tone(247, 0.4, 0.45, decay=7, overtone=0.4))),
    # Coin pickup: quick high pair.
    "coin": mix(tone(1975, 0.12, 0.35, decay=25), at(0.06, tone(2637, 0.3, 0.35, decay=12))),
    # Round finished: arpeggio up.
    "win": mix(*[at(i * 0.1, tone(f, 0.5, 0.4, decay=5)) for i, f in enumerate([C5, E5, G5, C6])]),
    # Level up / new badge: bigger arpeggio ending on a held chord.
    "fanfare": mix(*[at(i * 0.09, tone(f, 0.35, 0.35, decay=8)) for i, f in enumerate([C5, E5, G5, C6, E6])],
                   at(0.5, tone(C6, 0.9, 0.3, decay=3)), at(0.5, tone(E6, 0.9, 0.25, decay=3)),
                   at(0.5, tone(G6, 0.9, 0.2, decay=3))),
    # Clock tick for the last seconds of the speed challenge.
    "tick": mix(tone(2000, 0.04, 0.3, decay=80, overtone=0.0), noise(0.03, 0.08, 120)),
    # Time is up.
    "timeup": mix(tone(G5, 0.25, 0.4, decay=10), at(0.18, tone(E5, 0.25, 0.4, decay=10)),
                  at(0.36, tone(C5, 0.6, 0.45, decay=5))),
    # Start of a challenge: a rising swoop.
    "start": mix(tone(440, 0.35, 0.35, decay=6, slide=1.0), at(0.2, tone(C6, 0.35, 0.35, decay=8))),
    # Sticker bought: sparkle.
    "buy": mix(*[at(i * 0.05, tone(f, 0.3, 0.25, decay=12)) for i, f in enumerate([C6, E6, G6, C6 * 2])]),
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, samples in SOUNDS.items():
        write(name, samples)
