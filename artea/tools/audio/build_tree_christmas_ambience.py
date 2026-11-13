#!/usr/bin/env python3
"""Build the original, lightweight Tree of Life Christmas ambience loop."""

from __future__ import annotations

import argparse
import math
import wave
from pathlib import Path

import numpy as np


RATE = 44_100
BPM = 120.0
BEAT = 60.0 / BPM
BARS = 16
DURATION = BARS * 4 * BEAT
FRAMES = int(DURATION * RATE)
RNG = np.random.default_rng(2603)


def frequency(midi: float) -> float:
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


def pan_gains(pan: float) -> tuple[float, float]:
    angle = (max(-1.0, min(1.0, pan)) + 1.0) * math.pi * 0.25
    return math.cos(angle), math.sin(angle)


def add_note(mix: np.ndarray, start_beat: float, beats: float, midi: float,
             amplitude: float, instrument: str, pan: float = 0.0) -> None:
    start = int(start_beat * BEAT * RATE)
    count = min(int(beats * BEAT * RATE), FRAMES - start)
    if count <= 0:
        return
    t = np.arange(count, dtype=np.float64) / RATE
    f = frequency(midi)
    if instrument == "glock":
        signal = (
            np.sin(2.0 * math.pi * f * t) * np.exp(-3.8 * t)
            + 0.48 * np.sin(2.0 * math.pi * f * 2.01 * t + 0.3) * np.exp(-5.5 * t)
            + 0.22 * np.sin(2.0 * math.pi * f * 3.97 * t + 0.8) * np.exp(-7.0 * t)
        )
        attack = np.minimum(t / 0.006, 1.0)
        envelope = attack * np.exp(-1.75 * t)
    elif instrument == "celesta":
        signal = (
            np.sin(2.0 * math.pi * f * t)
            + 0.32 * np.sin(2.0 * math.pi * f * 2.0 * t + 0.15)
            + 0.12 * np.sin(2.0 * math.pi * f * 3.0 * t + 0.4)
        )
        attack = np.minimum(t / 0.015, 1.0)
        envelope = attack * np.exp(-0.9 * t)
    elif instrument == "strings":
        signal = np.zeros_like(t)
        for cents, weight in [(-7.0, 0.34), (0.0, 0.42), (6.0, 0.32)]:
            detuned = f * 2.0 ** (cents / 1200.0)
            signal += weight * (
                np.sin(2.0 * math.pi * detuned * t)
                + 0.18 * np.sin(2.0 * math.pi * detuned * 2.0 * t)
                + 0.07 * np.sin(2.0 * math.pi * detuned * 3.0 * t)
            )
        attack = np.minimum(t / 0.38, 1.0)
        release = np.minimum((count / RATE - t) / 0.55, 1.0)
        envelope = attack * np.maximum(0.0, release)
    else:  # warm bass
        signal = np.sin(2.0 * math.pi * f * t) + 0.20 * np.sin(4.0 * math.pi * f * t)
        attack = np.minimum(t / 0.03, 1.0)
        release = np.minimum((count / RATE - t) / 0.22, 1.0)
        envelope = attack * np.maximum(0.0, release)
    left, right = pan_gains(pan)
    voice = amplitude * signal * envelope
    mix[start:start + count, 0] += voice * left
    mix[start:start + count, 1] += voice * right


def add_sleigh_bell(mix: np.ndarray, start_beat: float, amplitude: float, pan: float) -> None:
    start = int(start_beat * BEAT * RATE)
    count = min(int(0.16 * RATE), FRAMES - start)
    if count <= 0:
        return
    t = np.arange(count, dtype=np.float64) / RATE
    noise = RNG.normal(0.0, 1.0, count)
    bright = np.concatenate(([0.0], np.diff(noise)))
    metal = (
        np.sin(2.0 * math.pi * 3250.0 * t)
        + 0.65 * np.sin(2.0 * math.pi * 4480.0 * t + 0.7)
        + 0.38 * np.sin(2.0 * math.pi * 6120.0 * t + 1.1)
    )
    envelope = np.exp(-24.0 * t) * np.minimum(t / 0.002, 1.0)
    voice = amplitude * (0.38 * bright + 0.62 * metal) * envelope
    left, right = pan_gains(pan)
    mix[start:start + count, 0] += voice * left
    mix[start:start + count, 1] += voice * right


def add_reverb(mix: np.ndarray) -> np.ndarray:
    dry = mix.copy()
    wet = mix.copy()
    for delay_seconds, gain, cross in [
        (0.113, 0.20, False), (0.181, 0.15, True), (0.293, 0.11, False),
        (0.419, 0.075, True), (0.677, 0.045, False),
    ]:
        delay = int(delay_seconds * RATE)
        if cross:
            wet[delay:, 0] += dry[:-delay, 1] * gain
            wet[delay:, 1] += dry[:-delay, 0] * gain
        else:
            wet[delay:] += dry[:-delay] * gain
    return wet


def build() -> np.ndarray:
    mix = np.zeros((FRAMES, 2), dtype=np.float64)

    # Sixteen bars of warm I-IV-V harmony. The second eight bars add a higher
    # countermelody, so the loop develops without becoming busy near dialogue.
    chords = [
        (60, 64, 67), (60, 64, 67), (65, 69, 72), (65, 69, 72),
        (67, 71, 74), (67, 71, 74), (60, 64, 67), (67, 71, 74),
    ] * 2
    for bar, chord in enumerate(chords):
        beat = bar * 4.0
        for note_index, note in enumerate(chord):
            add_note(mix, beat, 4.15, note, 0.055, "strings", (note_index - 1) * 0.28)
            add_note(mix, beat + 0.05, 1.8, note + 12, 0.045, "celesta",
                     (note_index - 1) * 0.38)
        add_note(mix, beat, 1.75, chord[0] - 24, 0.115, "bass", -0.08)
        add_note(mix, beat + 2.0, 1.75, chord[0] - 17, 0.085, "bass", 0.08)

    # A public-domain festive bell motif, arranged as a restrained landmark
    # ambience rather than a loud foreground song.
    motif = [
        (0.0, .55, 64), (.75, .55, 64), (1.5, 1.15, 64),
        (4.0, .55, 64), (4.75, .55, 64), (5.5, 1.15, 64),
        (8.0, .55, 64), (8.75, .55, 67), (9.5, .55, 60),
        (10.25, .55, 62), (11.0, 2.15, 64),
        (16.0, .55, 65), (16.75, .55, 65), (17.5, .55, 65),
        (18.25, .55, 65), (19.0, .55, 65), (19.75, .55, 64),
        (20.5, .55, 64), (21.25, .55, 64), (22.0, .55, 64),
        (22.75, .55, 62), (23.5, .55, 62), (24.25, .55, 64),
        (25.0, 1.8, 62), (27.0, 2.6, 67),
    ]
    for half in (0.0, 32.0):
        for index, (beat, length, note) in enumerate(motif):
            variation = 12 if half > 0.0 and index % 7 == 3 else 0
            add_note(mix, half + beat, length, note + 12 + variation,
                     0.13 if variation == 0 else 0.07, "glock", -0.22 if index % 2 == 0 else 0.22)

    # Alternating sleigh bells provide an unmistakable Christmas pulse while
    # keeping transients soft enough for nearby dialogue and accessibility.
    for step in range(BARS * 8):
        beat = step * 0.5
        accent = 0.050 if step % 8 in (0, 4) else 0.026
        add_sleigh_bell(mix, beat, accent, -0.55 if step % 2 == 0 else 0.55)

    mix = add_reverb(mix)
    # A short equal-power seam prevents clicks when Godot loops the WAV.
    seam = int(0.08 * RATE)
    ramp = np.linspace(0.0, 1.0, seam)[:, None]
    blended = mix[-seam:] * (1.0 - ramp) + mix[:seam] * ramp
    mix[:seam] = blended
    mix[-seam:] = blended
    peak = float(np.max(np.abs(mix)))
    return mix * (0.91 / peak if peak > 0.0 else 1.0)


def write_wav(path: Path, mix: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.asarray(np.clip(mix, -1.0, 1.0) * 32767.0, dtype="<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    write_wav(args.output, build())
    print(f"Wrote {args.output} ({DURATION:.1f}s, stereo, {RATE} Hz)")


if __name__ == "__main__":
    main()
