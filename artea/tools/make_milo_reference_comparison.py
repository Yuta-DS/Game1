from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


ROOT = Path("/Users/davidsovann/S2603/artea")
REFERENCE_APPEARANCE = Path("/var/folders/j8/tctb8gfs2_72jd0t0t7hzq9h0000gn/T/codex-clipboard-f63f6e07-a7d5-4d16-b6e6-aacdf9c6e900.png")
REFERENCE_GAME = Path("/var/folders/j8/tctb8gfs2_72jd0t0t7hzq9h0000gn/T/codex-clipboard-b048517b-d0ca-407f-84a0-aebe59b729de.png")
RESULT = ROOT / "artifacts/milo_scholar_preview.png"
OUTPUT = ROOT / "artifacts/milo_reference_side_by_side.png"

height = 760
header = 64
gap = 16
background = (20, 43, 61)

appearance = Image.open(REFERENCE_APPEARANCE).convert("RGB")
game = Image.open(REFERENCE_GAME).convert("RGB")
result = Image.open(RESULT).convert("RGB")

# Image 2 is the scale/style evidence. Crop around its Milo while retaining a
# narrow strip of the neighboring villager for an honest proportion comparison.
game = game.crop((190, 180, 850, 1000))
# Crop the render to the same character-card framing as the supplied targets.
result = result.crop((245, 135, 655, 835))


def fit(image, target_height, target_width=600):
    ratio = min(target_width / image.width, target_height / image.height)
    return image.resize((round(image.width * ratio), round(image.height * ratio)), Image.Resampling.LANCZOS)


panels = [
    ("APPEARANCE TARGET", fit(appearance, height, 520)),
    ("IN-GAME STYLE / SCALE", fit(game, height, 610)),
    ("NEW RIGGED MODEL", fit(result, height, 610)),
]
width = sum(panel.width for _, panel in panels) + gap * (len(panels) + 1)
canvas = Image.new("RGB", (width, height + header + gap * 2), background)
draw = ImageDraw.Draw(canvas)
font = ImageFont.load_default(size=22)
x = gap
for label, panel in panels:
    label_box = draw.textbbox((0, 0), label, font=font)
    label_width = label_box[2] - label_box[0]
    draw.text((x + (panel.width - label_width) / 2, 20), label, fill=(242, 225, 169), font=font)
    y = header + gap + (height - panel.height) // 2
    canvas.paste(panel, (x, y))
    x += panel.width + gap

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
canvas.save(OUTPUT)
print(f"MILO_REFERENCE_COMPARISON: wrote {OUTPUT}")
