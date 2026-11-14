from pathlib import Path
import sys

from docx import Document


def extract(path: Path) -> None:
    document = Document(path)
    print(f"# {path.name}")
    for paragraph in document.paragraphs:
        text = paragraph.text.strip()
        if text:
            style = paragraph.style.name if paragraph.style else ""
            print(f"[{style}] {text}")
    for table_index, table in enumerate(document.tables, start=1):
        print(f"\n[TABLE {table_index}]")
        for row in table.rows:
            cells = [" ".join(cell.text.split()) for cell in row.cells]
            print(" | ".join(cells))


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        extract(Path(arg))
