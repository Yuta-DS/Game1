#!/usr/bin/env python3
"""Build the piano note samples the gallery grand piano plays.

    python3 artea/tools/audio/build_piano_notes.py

Why three octaves of samples rather than 88:

* Shipping a sample per key would add tens of megabytes to a pack that is
  already the web build's biggest problem.  Three octaves (C1, C4 and C7) plus
  `pitch_scale` on the player covers all 88 keys.
* Octave shifts are exact powers of two, so the resampling is clean.  Picking
  whichever base octave is nearest keeps every key within a factor of two --
  stretch much past that and the partials either alias into a thin whistle at
  the top or turn to mud at the bottom.
* The side effect is the one a real piano has anyway: playback rate scales the
  decay with the pitch, so low notes ring on and high notes are short.

The tone is additive rather than sampled: partials with a stretched harmonic
series (real strings are stiff, so overtones run sharp), a faster decay for
each higher partial, and a short hammer thump at the onset.
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path

import numpy as np
import soundfile as sf


RATE = 44_100
# Base octave -> how long that octave's samples ring before pitch_scale.  The
# low set is stretched down as far as 0.125x, so it stays short at source to
# keep the bass from droning for half a minute.
#
# Three sets, each serving the octave it sits in plus one either side, so no
# key is ever shifted more than 2x.  Two sets would have to stretch A0 three
# octaves down (8x) and would also ring backwards across the crossover.
#
# Each set is a quarter the length of the one below it, because a set serving
# the octave above plays at 2x and the one below at 0.5x -- a factor of four
# between neighbours is what keeps the ring time falling smoothly from ~9 s in
# the bass to a fifth of a second at the top, the way a real piano does.
BASE_OCTAVES = {1: 4.5, 4: 1.2, 7: 0.35}
NOTE_NAMES = ["C", "Cs", "D", "Ds", "E", "F", "Fs", "G", "Gs", "A", "As", "B"]
PARTIALS = 14
INHARMONICITY = 4.0e-4          # stiffness of the string
RNG = np.random.default_rng(6112)


def frequency(midi: float) -> float:
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


def hammer(frames: int, f: float) -> np.ndarray:
    """The knock of felt on string: a noise burst that dies almost at once.

    Only the first fraction of a second is synthesised -- the envelope has
    long since reached zero by then, and the one-pole filter below runs a
    Python loop per sample, so generating the full note length would dominate
    the build time for nothing.
    """
    out = np.zeros(frames)
    count = min(frames, int(0.12 * RATE))
    t = np.arange(count, dtype=np.float64) / RATE
    noise = RNG.standard_normal(count)
    # One-pole lowpass, cutoff tracking the note so high keys click brighter.
    alpha = math.exp(-2.0 * math.pi * (f * 6.0) / RATE)
    filtered = np.zeros(count)
    carry = 0.0
    for index in range(count):
        carry = alpha * carry + (1.0 - alpha) * noise[index]
        filtered[index] = carry
    out[:count] = filtered * np.exp(-140.0 * t) * 0.35
    return out


def note(midi: int, duration: float) -> np.ndarray:
    frames = int(duration * RATE)
    f = frequency(midi)
    t = np.arange(frames, dtype=np.float64) / RATE
    mix = np.zeros(frames)

    for n in range(1, PARTIALS + 1):
        # Stretched series: partial n sits above n*f, more so for high n.
        ratio = n * math.sqrt(1.0 + INHARMONICITY * n * n)
        partial_f = f * ratio
        if partial_f > RATE * 0.45:
            break
        amplitude = 1.0 / (n ** 1.32)
        # Higher partials fade first, which is what makes a struck string
        # mellow as it rings rather than keeping its initial brightness.
        decay = 1.05 + 0.55 * n + f * 0.0032
        phase = RNG.uniform(0.0, 2.0 * math.pi)
        mix += amplitude * np.sin(2.0 * math.pi * partial_f * t + phase) * np.exp(-decay * t)

    # Two slightly detuned copies of the fundamental: a piano strikes three
    # strings per note and their drift is the slow beating you hear.
    for cents in (-2.6, 3.1):
        detuned = f * 2.0 ** (cents / 1200.0)
        mix += 0.30 * np.sin(2.0 * math.pi * detuned * t) * np.exp(-1.15 * t)

    mix += hammer(frames, f)

    # Soft attack so the onset does not click, and a release ramp so the tail
    # never cuts hard when the sample ends.
    attack = int(0.004 * RATE)
    mix[:attack] *= np.linspace(0.0, 1.0, attack)
    release = int(0.05 * RATE)
    mix[-release:] *= np.linspace(1.0, 0.0, release)

    peak = float(np.max(np.abs(mix)))
    return mix / peak * 0.82 if peak > 0.0 else mix


def write_ogg(path: Path, samples: np.ndarray) -> None:
    """Vorbis rather than WAV: the same 36 notes cost about a tenth as much in
    the pack, and the rest of the project's audio already ships as .ogg."""
    sf.write(path, np.clip(samples, -1.0, 1.0), RATE, format="OGG", subtype="VORBIS")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--out",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "assets" / "audio" / "piano",
        help="directory to write the samples into",
    )
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    written = 0
    for octave, duration in sorted(BASE_OCTAVES.items()):
        # MIDI note 0 is C-1, so C<octave> is 12 * (octave + 1).
        root = 12 * (octave + 1)
        for step, name in enumerate(NOTE_NAMES):
            path = args.out / f"piano_{name}{octave}.ogg"
            write_ogg(path, note(root + step, duration))
            written += 1
            print(f"wrote {path.name}")
    print(f"{written} samples in {args.out}")


if __name__ == "__main__":
    main()
