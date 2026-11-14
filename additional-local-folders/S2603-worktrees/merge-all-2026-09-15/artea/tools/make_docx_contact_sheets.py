import sys
from pathlib import Path
from PIL import Image, ImageDraw

source = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/Users/davidsovann/S2603/artea/artifacts/mind_spark_document_qa_v2")
pages = sorted(source.glob("page-*.png"), key=lambda p: int(p.stem.split("-")[1]))
thumb_w = int(sys.argv[2]) if len(sys.argv) > 2 else 360
gap = 18
label_h = 28
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 4
rows = int(sys.argv[4]) if len(sys.argv) > 4 else 4
prefix = sys.argv[5] if len(sys.argv) > 5 else "contact-sheet"

for sheet_index in range((len(pages) + cols * rows - 1) // (cols * rows)):
    batch = pages[sheet_index * cols * rows:(sheet_index + 1) * cols * rows]
    thumbs = []
    for page in batch:
        image = Image.open(page).convert("RGB")
        h = round(image.height * thumb_w / image.width)
        image.thumbnail((thumb_w, h), Image.Resampling.LANCZOS)
        thumbs.append((page, image.copy()))
    thumb_h = max(im.height for _, im in thumbs)
    canvas = Image.new("RGB", (cols * thumb_w + (cols + 1) * gap, rows * (thumb_h + label_h) + (rows + 1) * gap), "#d9e7ea")
    draw = ImageDraw.Draw(canvas)
    for idx, (page, image) in enumerate(thumbs):
        col = idx % cols
        row = idx // cols
        x = gap + col * (thumb_w + gap)
        y = gap + row * (thumb_h + label_h + gap)
        canvas.paste(image, (x, y))
        draw.text((x + 4, y + thumb_h + 5), page.stem, fill="#143343")
    canvas.save(source / f"{prefix}-{sheet_index + 1}.png")
