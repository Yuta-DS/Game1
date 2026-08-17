#!/usr/bin/env python3
"""Split the generated texture atlases into a reusable PBR material set."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
TEXTURE_DIR = ROOT / "assets/textures/mind_spark/quest_objects/torch_spark_socket"
SOURCE_DIR = TEXTURE_DIR / "source"

ATLASES = {
    "structural_atlas.png": (
        ("stone_dark", 0, 0, 188, 1.9),
        ("stone_mid", 1, 0, 156, 1.4),
        ("gunmetal", 0, 1, 92, 1.1),
        ("silver_edge", 1, 1, 76, 0.9),
    ),
    "energy_atlas.png": (
        ("cyan_energy", 0, 0, 66, 0.55),
        ("violet_energy", 1, 0, 72, 0.55),
        ("white_star_glow", 0, 1, 48, 0.35),
        ("violet_crystal_outline", 1, 1, 64, 0.65),
    ),
    "crystal_atlas.png": (
        ("blue_crystal", 0, 0, 58, 1.1),
        ("lavender_crystal", 1, 0, 62, 1.1),
        ("orb_glass", 0, 1, 44, 0.65),
        ("crown_crystal", 1, 1, 52, 0.9),
    ),
}

MATERIAL_TEXTURES = {
    "Stone_Dark": "stone_dark",
    "Stone_Mid": "stone_mid",
    "Stone_Edge": "silver_edge",
    "Gunmetal": "gunmetal",
    "Silver_Edge": "silver_edge",
    "Cyan_Energy": "cyan_energy",
    "Violet_Energy": "violet_energy",
    "White_Star_Glow": "white_star_glow",
    "Blue_Crystal": "blue_crystal",
    "Blue_Crystal_Outline": "cyan_energy",
    "Lavender_Crystal": "lavender_crystal",
    "Crown_Crystal": "crown_crystal",
    "Violet_Crystal_Outline": "violet_crystal_outline",
    "Orb_Glass": "orb_glass",
}


def build_normal(rgb: Image.Image, strength: float) -> Image.Image:
    height = np.asarray(rgb.convert("L"), dtype=np.float32) / 255.0
    # The socket is viewed at gameplay scale, so surface relief must remain
    # legible after mipmapping and Godot's mobile renderer filtering.
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength * 3.0
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength * 3.0
    nx = -dx
    ny = dy
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack((nx / length, ny / length, nz / length), axis=2)
    return Image.fromarray(np.uint8(np.clip((normal * 0.5 + 0.5) * 255.0, 0, 255)), "RGB")


def build_roughness(rgb: Image.Image, base: int) -> Image.Image:
    luminance = np.asarray(rgb.convert("L"), dtype=np.float32)
    variation = (luminance - 127.5) * 0.38
    roughness = np.uint8(np.clip(float(base) + variation, 20, 235))
    return Image.fromarray(roughness, "L")


def main() -> None:
    TEXTURE_DIR.mkdir(parents=True, exist_ok=True)
    for atlas_name, specs in ATLASES.items():
        atlas = Image.open(SOURCE_DIR / atlas_name).convert("RGB")
        half_w, half_h = atlas.width // 2, atlas.height // 2
        for name, column, row, roughness, normal_strength in specs:
            tile = atlas.crop((column * half_w, row * half_h, (column + 1) * half_w, (row + 1) * half_h))
            tile = tile.resize((1024, 1024), Image.Resampling.LANCZOS)
            tile.save(TEXTURE_DIR / f"{name}_basecolor.png", optimize=True)
            build_roughness(tile, roughness).save(TEXTURE_DIR / f"{name}_roughness.png", optimize=True)
            build_normal(tile, normal_strength).save(TEXTURE_DIR / f"{name}_normal.png", optimize=True)

    manifest = {
        "resolution": [1024, 1024],
        "maps": ["basecolor", "roughness", "normal"],
        "material_textures": MATERIAL_TEXTURES,
        "source_atlases": sorted(ATLASES),
    }
    (TEXTURE_DIR / "texture_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Built {len(MATERIAL_TEXTURES)} material assignments from 12 PBR texture surfaces")


if __name__ == "__main__":
    main()
