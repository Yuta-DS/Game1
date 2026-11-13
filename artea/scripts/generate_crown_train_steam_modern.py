#!/usr/bin/env python3
"""Generate the Crown Line steam, sci-fi orb, and geared traction loop."""

from array import array
import math
import random
import wave
from pathlib import Path


SAMPLE_RATE = 44_100
DURATION = 8.0
TAU = math.tau
OUTPUT = Path(__file__).resolve().parents[1] / "assets/audio/train/crown_train_steam_modern_loop.wav"
HORN_OUTPUT = Path(__file__).resolve().parents[1] / "assets/audio/train/crown_train_power_whistle_horn.wav"


def pulse(phase: float, attack: float, decay: float) -> float:
    return (1.0 - math.exp(-phase * attack)) * math.exp(-phase * decay)


def write_stereo_wav(path: Path, left: array, right: array) -> None:
    peak = max(max(abs(value) for value in left), max(abs(value) for value in right), 0.001)
    gain = 0.88 / peak
    pcm = array("h")
    for index in range(len(left)):
        pcm.append(int(max(-1.0, min(1.0, math.tanh(left[index] * gain * 1.18))) * 32767))
        pcm.append(int(max(-1.0, min(1.0, math.tanh(right[index] * gain * 1.18))) * 32767))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def generate() -> None:
    frame_count = int(SAMPLE_RATE * DURATION)
    randomizer = random.Random(0xC0A17A1)
    left = array("f", [0.0]) * frame_count
    right = array("f", [0.0]) * frame_count
    low_noise = 0.0
    mid_noise = 0.0

    for index in range(frame_count):
        time = index / SAMPLE_RATE
        raw_noise = randomizer.uniform(-1.0, 1.0)
        low_noise += (raw_noise - low_noise) * 0.006
        mid_noise += (raw_noise - mid_noise) * 0.085
        airy_noise = raw_noise - mid_noise

        # Four exhaust beats per second with a classic quartered steam cadence.
        chuff_position = time * 4.0
        chuff_index = int(chuff_position)
        chuff_phase = chuff_position - chuff_index
        chuff_envelope = pulse(chuff_phase, 58.0, 8.2)
        chuff_weight = (1.0, 0.84, 0.94, 0.78)[chuff_index % 4]
        steam_chuff = (mid_noise * 0.74 + low_noise * 0.38 + airy_noise * 0.10)
        steam_chuff *= chuff_envelope * chuff_weight

        # Piston body and a short rail joint give the exhaust physical weight.
        piston = math.sin(TAU * 66.0 * time) * chuff_envelope * 0.25
        joint_phase = (time * 8.0) % 1.0
        joint = pulse(joint_phase, 130.0, 27.0)
        rail_tick = (
            math.sin(TAU * 790.0 * time) * 0.11
            + math.sin(TAU * 158.0 * time) * 0.09
        ) * joint

        # Stable modern traction fundamentals beneath the steam mechanism.
        motor_lfo = math.sin(TAU * 0.25 * time)
        modern_motor = math.sin(TAU * (52.0 * time + motor_lfo * 0.035)) * 0.20
        modern_motor += math.sin(TAU * 104.0 * time + 0.45) * 0.095
        modern_motor += math.sin(TAU * 208.0 * time + 1.1) * 0.032
        modern_motor += math.sin(TAU * 312.5 * time + motor_lfo * 0.55) * 0.024

        # The luminous nose orb breathes once per second. Close harmonic fifths
        # make it read as stored sci-fi energy, while opposite stereo phases make
        # the field appear to rotate around the engine rather than sit in mono.
        orb_breath = 0.58 + 0.42 * (0.5 + 0.5 * math.sin(TAU * time - math.pi / 2.0)) ** 2
        orb_phase = math.sin(TAU * 0.25 * time) * 0.42
        orb_core = math.sin(TAU * (174.0 * time + motor_lfo * 0.055)) * 0.085
        orb_core += math.sin(TAU * 261.5 * time + orb_phase) * 0.050
        orb_core += math.sin(TAU * 349.0 * time - orb_phase) * 0.034
        orb_core *= orb_breath
        orb_left = math.sin(TAU * 523.0 * time + orb_phase) * orb_breath * 0.020
        orb_right = math.sin(TAU * 523.0 * time - orb_phase) * orb_breath * 0.020
        energy_phase = (time * 2.0) % 1.0
        energy_snap = pulse(energy_phase, 95.0, 17.0)
        energy_shimmer = airy_noise * energy_snap * 0.060

        # Twelve gear teeth mesh per second, locked to every third steam chuff.
        # A low wheel body plus two short metal harmonics suggests interlocking
        # brass gears without turning the engine into continuous harsh rattling.
        gear_position = time * 12.0
        gear_index = int(gear_position)
        gear_phase = gear_position - gear_index
        gear_tooth = pulse(gear_phase, 115.0, 31.0)
        gear_weight = 1.0 if gear_index % 3 == 0 else 0.68
        gear_mesh = math.sin(TAU * 430.0 * time) * gear_tooth * gear_weight * 0.075
        gear_mesh += math.sin(TAU * 645.0 * time + 0.3) * gear_tooth * 0.032
        gear_mesh += math.sin(TAU * 86.0 * time) * gear_tooth * 0.055

        boiler_breath = (low_noise * 0.16 + airy_noise * 0.035) * (
            0.82 + 0.18 * math.sin(TAU * 0.5 * time)
        )
        body = steam_chuff * 0.62 + piston + rail_tick + modern_motor + boiler_breath
        body += orb_core + energy_shimmer + gear_mesh
        # Alternate exhaust slightly across the stereo field without weakening
        # the centered motor, so the loop remains convincing through 3D panning.
        chuff_pan = -0.07 if chuff_index % 2 == 0 else 0.07
        left[index] = body + steam_chuff * chuff_pan + orb_left
        right[index] = body - steam_chuff * chuff_pan + orb_right

    # Crossfade the generated noise state back to the opening while the periodic
    # motor and piston phases already meet exactly at the eight-second boundary.
    seam_frames = int(SAMPLE_RATE * 0.30)
    seam_start = frame_count - seam_frames
    for offset in range(seam_frames):
        blend = offset / max(1, seam_frames - 1)
        blend = blend * blend * (3.0 - 2.0 * blend)
        tail = seam_start + offset
        left[tail] = left[tail] * (1.0 - blend) + left[offset] * blend
        right[tail] = right[tail] * (1.0 - blend) + right[offset] * blend


    # Soft saturation glues steam, gears, and the energized orb together.
    write_stereo_wav(OUTPUT, left, right)
    print(OUTPUT)


def generate_horn() -> None:
    duration = 3.2
    frame_count = int(SAMPLE_RATE * duration)
    randomizer = random.Random(0x484F524E)
    left = array("f", [0.0]) * frame_count
    right = array("f", [0.0]) * frame_count
    air = 0.0
    slow_air = 0.0
    # Tuned from the frequency profile of the supplied real-train reference:
    # a bright four-bell air horn with dense upper energy, not a low foghorn.
    chimes = ((318.0, 0.31), (377.0, 0.28), (428.0, 0.25), (637.0, 0.13))
    for index in range(frame_count):
        time = index / SAMPLE_RATE
        attack = min(1.0, time / 0.14)
        release = min(1.0, (duration - time) / 0.66)
        envelope = math.sin(attack * math.pi * 0.5) * max(0.0, release) ** 1.28
        pressure = 0.965 + 0.022 * math.sin(TAU * 1.65 * time) \
            + 0.013 * math.sin(TAU * 3.7 * time + 0.8)
        # Integrating this startup pressure curve makes every chime rise roughly
        # two percent into tune without the phase discontinuity of direct FM.
        pressure_phase_time = time - 0.0045 * (1.0 - math.exp(-time * 4.4))
        bore_flutter = math.sin(TAU * 5.1 * time) * 0.016
        # A four-chime locomotive chord gives the blast its unmistakable train
        # identity. Each bell includes imperfect second/third partials; the tiny
        # left/right detuning produces natural acoustic beating instead of chorus.
        horn_left = 0.0
        horn_right = 0.0
        for chime_index, (frequency, weight) in enumerate(chimes):
            phase_offset = chime_index * 0.23
            left_phase = TAU * frequency * 0.9992 * pressure_phase_time + phase_offset + bore_flutter
            right_phase = TAU * frequency * 1.0011 * pressure_phase_time + phase_offset + 0.035 - bore_flutter
            horn_left += math.sin(left_phase) * weight
            horn_left += math.sin(left_phase * 2.013 + 0.41) * weight * 0.115
            horn_left += math.sin(left_phase * 3.027 + 0.86) * weight * 0.037
            horn_right += math.sin(right_phase) * weight
            horn_right += math.sin(right_phase * 2.009 + 0.46) * weight * 0.115
            horn_right += math.sin(right_phase * 3.021 + 0.91) * weight * 0.037
        low_body = math.sin(TAU * 159.0 * time) * 0.075
        raw = randomizer.uniform(-1.0, 1.0)
        air += (raw - air) * 0.12
        slow_air += (raw - slow_air) * 0.008
        turbulence = 0.88 + 0.12 * math.sin(TAU * 23.0 * time + slow_air * 0.8)
        steam_air = ((raw - air) * 0.050 + (air - slow_air) * 0.11 + slow_air * 0.055) * turbulence
        pressure_attack = math.exp(-time * 6.5) * (raw - air) * 0.18
        open_latch = pulse(time / 0.20, 82.0, 14.0) if time < 0.20 else 0.0
        close_time = duration - time
        close_latch = pulse(close_time / 0.24, 70.0, 13.0) if 0.0 < close_time < 0.24 else 0.0
        valve_clunk = (math.sin(TAU * 510.0 * time) + math.sin(TAU * 108.0 * time)) \
            * (open_latch * 0.085 + close_latch * 0.065)
        release_hiss = (raw - slow_air) * max(0.0, 1.0 - close_time / 0.70) * 0.13
        shared = (low_body + steam_air + pressure_attack + valve_clunk) * envelope + release_hiss
        left[index] = shared + horn_left * pressure * envelope
        right[index] = shared + horn_right * pressure * envelope
    write_stereo_wav(HORN_OUTPUT, left, right)
    print(HORN_OUTPUT)


if __name__ == "__main__":
    generate()
    generate_horn()
