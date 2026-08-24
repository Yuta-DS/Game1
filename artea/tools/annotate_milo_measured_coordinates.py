"""Draw the measured 2D landmarks that drive the 3D Milo reconstruction."""

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SPEC_PATH = ROOT / "tools/blender/milo_measured_npc_spec.json"
REFERENCE = ROOT / "artifacts/milo_exact_target_crop.png"
OUTPUT = ROOT / "artifacts/milo_measured_coordinate_overlay.png"

spec = json.loads(SPEC_PATH.read_text())
image = Image.open(REFERENCE).convert("RGB").resize(
    (spec["reference_image"]["width_px"], spec["reference_image"]["height_px"]),
    Image.Resampling.LANCZOS,
)
draw = ImageDraw.Draw(image, "RGBA")
font = ImageFont.load_default(size=15)
axis_x = spec["reference_image"]["character_axis_px"]
draw.line((axis_x, 0, axis_x, image.height), fill=(255, 90, 90, 170), width=2)

palette = [(255, 214, 102, 220), (99, 220, 255, 220), (244, 135, 255, 220),
           (138, 255, 161, 220), (255, 153, 102, 220)]
label_index = 0
for name, part in spec["parts"].items():
    boxes = []
    if "reference_bbox_px" in part:
        boxes.append(part["reference_bbox_px"])
    boxes.extend(part.get("reference_bboxes_px", []))
    colour = palette[label_index % len(palette)]
    for box in boxes:
        draw.rectangle(box, outline=colour, width=2)
    if boxes:
        left, top, _, _ = boxes[0]
        draw.rectangle((left, top, left + min(190, len(name) * 8 + 8), top + 19),
                       fill=(10, 25, 35, 190))
        draw.text((left + 3, top + 2), name, font=font, fill=colour)
        label_index += 1

image.save(OUTPUT)
print(f"MILO_MEASURED_COORDINATES: {len(spec['parts'])} part measurements -> {OUTPUT}")
