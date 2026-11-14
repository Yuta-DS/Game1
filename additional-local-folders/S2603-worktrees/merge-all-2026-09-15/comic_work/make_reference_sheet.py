from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


paths = sorted(Path("/Users/davidsovann/S2603/comic_work/reference_images").glob("*.png"))
canvas = Image.new("RGB", (1320, 960), (23, 36, 60))
draw = ImageDraw.Draw(canvas)
font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 22)

for index, path in enumerate(paths):
    image = Image.open(path).convert("RGB")
    image.thumbnail((410, 255))
    x = 15 + (index % 3) * 435
    y = 15 + (index // 3) * 315
    canvas.paste(image, (x + (410 - image.width) // 2, y))
    draw.text((x, y + 265), path.name, fill="white", font=font)

canvas.save("/Users/davidsovann/S2603/comic_work/reference_sheet.png")
