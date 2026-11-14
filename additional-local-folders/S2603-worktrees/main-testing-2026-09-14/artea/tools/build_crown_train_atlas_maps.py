"""Slice the approved Crown Line atlas into complete PBR material sets."""

from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/textures/crown_line_train/concept/crown_line_full_body_texture_atlas_v1.png"
OUT = ROOT / "assets/textures/crown_line_train/concept/maps"
OUT.mkdir(parents=True, exist_ok=True)

# 4x3 atlas cells, inset enough to discard the presentation borders/gutters.
COLS = ((24, 309), (334, 615), (642, 919), (947, 1228))
ROWS = ((26, 408), (437, 817), (844, 1227))
NAMES = (
    "roof_teal_enamel", "roof_turquoise_enamel", "ivory_ceramic", "aged_gold",
    "navy_lacquer", "cyan_circuit_glass", "cyan_crystal", "violet_crystal",
    "living_root", "rail_steel", "cream_interior", "indigo_floral_upholstery",
)

ROUGHNESS = {
    "roof_teal_enamel": .34, "roof_turquoise_enamel": .30, "ivory_ceramic": .42,
    "aged_gold": .23, "navy_lacquer": .29, "cyan_circuit_glass": .17,
    "cyan_crystal": .12, "violet_crystal": .13, "living_root": .58,
    "rail_steel": .28, "cream_interior": .52, "indigo_floral_upholstery": .48,
}
METALLIC = {
    "aged_gold": .92, "rail_steel": .86, "navy_lacquer": .48,
    "roof_teal_enamel": .24, "roof_turquoise_enamel": .20,
}
EMISSION = {
    "cyan_circuit_glass": 1.0, "cyan_crystal": .90, "violet_crystal": .82,
    "living_root": .18, "indigo_floral_upholstery": .08,
}
# Material-only sampling windows remove the concept sheet's decorative frame
# and object silhouette before tiling.  This prevents a complete crystal or
# complete root knot from being repeated on every small editable component.
DETAIL_CROPS = {
    "roof_teal_enamel": (52, 64, 454, 458),
    "roof_turquoise_enamel": (48, 70, 462, 454),
    "ivory_ceramic": (82, 58, 414, 388),
    "aged_gold": (34, 28, 354, 292),
    "navy_lacquer": (74, 72, 438, 390),
    "cyan_circuit_glass": (24, 24, 488, 488),
    "cyan_crystal": (82, 70, 418, 414),
    "violet_crystal": (116, 66, 398, 394),
    "living_root": (176, 0, 510, 154),
    "rail_steel": (34, 24, 474, 212),
    "cream_interior": (44, 42, 466, 466),
    "indigo_floral_upholstery": (24, 28, 486, 356),
}


def normal_from_height(height, strength=3.0):
    data = np.asarray(height, dtype=np.float32) / 255.0
    dy, dx = np.gradient(data)
    nx, ny, nz = -dx * strength, -dy * strength, np.ones_like(data)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    rgb = np.stack(((nx / length + 1) * 127.5,
                    (ny / length + 1) * 127.5,
                    (nz / length + 1) * 127.5), axis=-1)
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")


atlas = Image.open(SOURCE).convert("RGB")
for index, name in enumerate(NAMES):
    row, col = divmod(index, 4)
    x0, x1 = COLS[col]
    y0, y1 = ROWS[row]
    swatch = atlas.crop((x0, y0, x1, y1)).resize((512, 512), Image.Resampling.LANCZOS)
    albedo = swatch.crop(DETAIL_CROPS[name]).resize((512, 512), Image.Resampling.LANCZOS)
    # Preserve the generated hand-painted detail while keeping the swatch
    # practical on small pieces through mild contrast compression.
    albedo = ImageEnhance.Contrast(albedo).enhance(.92)
    if name == "living_root":
        # Cyan nodes are separate editable meshes on the bogie. Removing them
        # from the repeated tile keeps every short root branch naturally brown.
        albedo = ImageOps.colorize(albedo.convert("L"), (28, 12, 4), (198, 132, 58))
    elif name == "violet_crystal":
        albedo = ImageOps.colorize(albedo.convert("L"), (42, 8, 78), (238, 142, 255))
    elif name == "cyan_crystal":
        albedo = ImageOps.colorize(albedo.convert("L"), (4, 52, 72), (154, 247, 255))
    luminance = albedo.convert("L")
    low_frequency = luminance.filter(ImageFilter.GaussianBlur(5.5))
    detail = Image.fromarray(np.clip(
        128 + (np.asarray(luminance, dtype=np.int16) - np.asarray(low_frequency, dtype=np.int16)) * 2,
        0, 255).astype(np.uint8), "L")
    rough_base = round(ROUGHNESS[name] * 255)
    rough = Image.fromarray(np.clip(
        rough_base + (np.asarray(detail, dtype=np.int16) - 128) * .28,
        8, 246).astype(np.uint8), "L")
    metal_value = round(METALLIC.get(name, .06) * 255)
    metallic = Image.new("L", (512, 512), metal_value)
    height = ImageEnhance.Contrast(detail.filter(ImageFilter.GaussianBlur(.55))).enhance(1.3)
    normal = normal_from_height(height, 3.8 if name == "living_root" else 2.4)
    emission_amount = EMISSION.get(name, 0.0)
    if emission_amount:
        bright = np.asarray(luminance, dtype=np.float32) / 255.0
        mask = np.clip((bright - .50) * 2.3 * emission_amount, 0, 1)
        color = np.asarray(albedo, dtype=np.float32)
        emission = Image.fromarray(np.clip(color * mask[..., None], 0, 255).astype(np.uint8), "RGB")
    else:
        emission = Image.new("RGB", (512, 512), (0, 0, 0))
    for suffix, image in (
        ("albedo", albedo), ("roughness", rough), ("metallic", metallic),
        ("height", height), ("normal", normal), ("emission", emission),
    ):
        image.save(OUT / f"{name}_{suffix}.png", optimize=True)

print(f"CROWN_TRAIN_ATLAS_MAPS: PASS ({len(NAMES)} materials, {len(NAMES) * 6} maps)")
