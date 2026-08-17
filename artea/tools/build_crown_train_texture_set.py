"""Build deterministic hand-painted Crown Line texture tiles.

The train is assembled from thousands of independently editable pieces, so a
small shared texture library keeps the art direction consistent without
flattening those pieces into one baked mesh.
"""

from pathlib import Path
import math
import random

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "textures" / "crown_line_train"
SIZE = 512
OUT.mkdir(parents=True, exist_ok=True)


PALETTES = {
    "teal_leaf": ((11, 77, 84), (29, 143, 145), (89, 204, 190)),
    "navy_lacquer": ((3, 12, 34), (9, 32, 68), (24, 70, 110)),
    "aged_gold": ((83, 43, 8), (177, 105, 25), (247, 196, 83)),
    "ivory_stone": ((121, 112, 92), (205, 193, 160), (247, 231, 188)),
    "living_root": ((48, 23, 6), (112, 64, 20), (185, 124, 48)),
    "cyan_magic": ((2, 50, 71), (6, 135, 161), (102, 239, 242)),
}


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def base_noise(name, palette, seed):
    rng = random.Random(seed)
    low, mid, high = palette
    image = Image.new("RGB", (SIZE, SIZE))
    pixels = image.load()
    for y in range(SIZE):
        broad = .5 + .19 * math.sin(y / SIZE * math.tau * 2.0 + seed)
        for x in range(SIZE):
            grain = rng.uniform(-.16, .16)
            wave = .08 * math.sin((x * .055) + (y * .021) + seed)
            value = max(0.0, min(1.0, broad + grain + wave))
            pixels[x, y] = mix(low, mid, value * 1.25) if value < .8 else mix(mid, high, (value - .8) * 5.0)
    return image.filter(ImageFilter.GaussianBlur(.45))


def paint_details(name, image, seed):
    rng = random.Random(seed + 100)
    draw = ImageDraw.Draw(image, "RGBA")
    if name == "teal_leaf":
        # Gold-edged botanical veins echo the train's layered roof leaves.
        for offset in range(-256, 768, 128):
            draw.line((offset, 520, offset + 245, -8), fill=(229, 176, 58, 105), width=4)
            for branch in range(5):
                y = 90 + branch * 88
                x = offset + round((520 - y) * .465)
                draw.line((x, y, x - 70, y - 48), fill=(112, 218, 205, 90), width=3)
                draw.line((x, y, x + 72, y - 44), fill=(112, 218, 205, 90), width=3)
    elif name == "navy_lacquer":
        for _ in range(70):
            x, y = rng.randrange(SIZE), rng.randrange(SIZE)
            length = rng.randrange(8, 55)
            draw.line((x, y, x + length, y), fill=(72, 139, 169, rng.randrange(18, 55)), width=1)
        for y in range(64, SIZE, 128):
            draw.line((0, y, SIZE, y), fill=(178, 136, 52, 28), width=2)
    elif name == "aged_gold":
        for _ in range(95):
            x, y = rng.randrange(SIZE), rng.randrange(SIZE)
            draw.line((x, y, x + rng.randrange(4, 36), y + rng.randrange(-2, 3)),
                      fill=(58, 27, 5, rng.randrange(25, 95)), width=1)
        for radius in (78, 84, 90):
            draw.arc((256-radius, 256-radius, 256+radius, 256+radius), 12, 168,
                     fill=(255, 229, 130, 65), width=2)
    elif name == "ivory_stone":
        for _ in range(18):
            points = []
            x, y = rng.randrange(SIZE), rng.randrange(SIZE)
            for step in range(7):
                points.append((x + step * 18, y + rng.randrange(-16, 17)))
            draw.line(points, fill=(88, 76, 61, 50), width=2)
        for _ in range(120):
            x, y = rng.randrange(SIZE), rng.randrange(SIZE)
            draw.ellipse((x, y, x + 2, y + 2), fill=(255, 245, 205, 45))
    elif name == "living_root":
        for band in range(-2, 12):
            points = []
            for x in range(-16, SIZE + 17, 16):
                y = band * 55 + 14 * math.sin(x * .035 + band * 1.7)
                points.append((x, y))
            draw.line(points, fill=(230, 166, 70, 75), width=4)
            draw.line([(x, y + 8) for x, y in points], fill=(39, 17, 4, 65), width=2)
    elif name == "cyan_magic":
        for lane in range(5):
            points = []
            y = 48 + lane * 105
            for x in range(-32, SIZE + 64, 64):
                points.extend(((x, y), (x + 32, y), (x + 48, y - 18), (x + 64, y - 18)))
            draw.line(points, fill=(169, 255, 255, 105), width=4)
            for x in range(48, SIZE, 128):
                draw.ellipse((x-5, y-23, x+5, y-13), fill=(232, 255, 255, 170))
    return image


def channel_maps(name, albedo, seed):
    rng = random.Random(seed + 900)
    roughness = Image.new("L", (SIZE, SIZE))
    height = Image.new("L", (SIZE, SIZE))
    rp, hp = roughness.load(), height.load()
    rough_base = {
        "teal_leaf": 112, "navy_lacquer": 76, "aged_gold": 68,
        "ivory_stone": 142, "living_root": 176, "cyan_magic": 54,
    }[name]
    for y in range(SIZE):
        for x in range(SIZE):
            wave = math.sin(x * .045 + y * .019 + seed)
            rp[x, y] = max(18, min(235, round(rough_base + wave * 12 + rng.uniform(-16, 16))))
            hp[x, y] = max(42, min(215, round(128 + wave * 18 + rng.uniform(-12, 12))))
    return roughness.filter(ImageFilter.GaussianBlur(.5)), height.filter(ImageFilter.GaussianBlur(.7))


for index, (name, palette) in enumerate(PALETTES.items()):
    seed = 4100 + index * 137
    albedo = paint_details(name, base_noise(name, palette, seed), seed)
    roughness, height = channel_maps(name, albedo, seed)
    albedo.save(OUT / f"{name}_albedo.png")
    roughness.save(OUT / f"{name}_roughness.png")
    height.save(OUT / f"{name}_height.png")

print(f"CROWN_TRAIN_TEXTURE_SET: PASS ({len(PALETTES) * 3} maps in {OUT})")
