"""Place the approved target above the generated parts render for review."""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "artifacts/milo_exact_target_crop.png"
RESULT = ROOT / "artifacts/milo_exact_target_parts_render.png"
OUTPUT = ROOT / "artifacts/milo_exact_parts_target_over_model.png"
CONTACT_SHEET = ROOT / "artifacts/milo_exact_parts_contact_sheet.png"

target_raw = Image.open(TARGET).convert("RGB")
result_raw = Image.open(RESULT).convert("RGB")
panel_width = 700


def fit_width(image):
    height = round(image.height * panel_width / image.width)
    return image.resize((panel_width, height), Image.Resampling.LANCZOS)


target = fit_width(target_raw)
result = fit_width(result_raw)
header = 48
gap = 14
canvas = Image.new("RGB", (panel_width, header * 2 + target.height + result.height + gap), "#142b3d")
draw = ImageDraw.Draw(canvas)
font = ImageFont.load_default(size=22)
draw.text((18, 13), "EXACT TARGET", fill="#f2e1a9", font=font)
canvas.paste(target, (0, header))
second_y = header + target.height + gap
draw.text((18, second_y + 13), "GENERATED PARTS - SAME FRONT ALIGNMENT", fill="#f2e1a9", font=font)
canvas.paste(result, (0, second_y + header))
canvas.save(OUTPUT)
print(f"MILO_EXACT_PARTS_COMPARISON: wrote {OUTPUT}")

# Each tuple is (label, target crop, generated-render crop).  Crops are kept
# explicit so a modeller can tune one named group without losing the full-body
# alignment context.  The approved target is always shown directly above the
# corresponding generated geometry.
part_crops = [
    ("EARS", (25, 0, 455, 205), (105, 35, 595, 280)),
    ("EYES + GLASSES", (45, 115, 435, 345), (105, 175, 595, 440)),
    ("NOSE + MOUSTACHE", (35, 240, 445, 450), (90, 330, 610, 565)),
    ("OUTFIT", (25, 350, 455, 640), (105, 455, 595, 735)),
    ("ARMS + PAWS", (0, 340, 480, 660), (65, 440, 635, 750)),
    ("LEGS + BOOTS", (75, 585, 405, 760), (125, 670, 575, 900)),
    ("TAIL", (325, 385, 480, 650), (470, 405, 700, 750)),
    ("FULL SILHOUETTE", (0, 0, target_raw.width, target_raw.height),
     (0, 0, result_raw.width, result_raw.height)),
]
columns = 2
card_width = 360
card_height = 470
sheet = Image.new(
    "RGB",
    (columns * card_width, math.ceil(len(part_crops) / columns) * card_height),
    "#142b3d",
)
sheet_draw = ImageDraw.Draw(sheet)


def review_crop(image, box):
    return ImageOps.contain(image.crop(box), (card_width - 20, 190), Image.Resampling.LANCZOS)


for index, (label, target_box, result_box) in enumerate(part_crops):
    column = index % columns
    row = index // columns
    x = column * card_width
    y = row * card_height
    sheet_draw.text((x + 10, y + 9), label, fill="#f2e1a9", font=font)
    target_part = review_crop(target_raw, target_box)
    result_part = review_crop(result_raw, result_box)
    sheet_draw.text((x + 10, y + 42), "TARGET", fill="#b8d9e8", font=font)
    sheet.paste(target_part, (x + (card_width - target_part.width) // 2, y + 68))
    generated_label_y = y + 68 + 190 + 8
    sheet_draw.text((x + 10, generated_label_y), "GENERATED PART", fill="#b8d9e8", font=font)
    sheet.paste(result_part, (x + (card_width - result_part.width) // 2,
                              generated_label_y + 26))

sheet.save(CONTACT_SHEET)
print(f"MILO_EXACT_PARTS_CONTACT_SHEET: wrote {CONTACT_SHEET}")
