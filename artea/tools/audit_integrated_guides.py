from collections import Counter
from pathlib import Path

from docx import Document


DOCS = {
    "mind": Path("/Users/davidsovann/Documents/World_One_Mind_Spark_Concise_Developer_Guide_Implementation_Blueprints.docx"),
    "heart": Path("/Users/davidsovann/Documents/World_Two_Heart_Melody_Concise_Developer_Guide_Implementation_Blueprints.docx"),
    "creator": Path("/Users/davidsovann/Documents/World_Three_Creators_Light_Concise_Developer_Guide_Implementation_Blueprints.docx"),
}

REQUIRED = (
    "55–70 minutes",
    "Mother Guardian",
    "Mayor Milo",
    "World Gate",
    "Crown Train",
    "identity_axis_counts",
)

LEGACY = (
    "Raphael",
    "Uriel",
    "Everlasting Father",
    "Guardian of Clear Thinking",
    "14–16 minutes",
    "2 main quests",
    "implementation addendum",
    "train arrival",
)


def document_text(document: Document) -> str:
    blocks = [p.text.strip() for p in document.paragraphs if p.text.strip()]
    for table in document.tables:
        for row in table.rows:
            for cell in row.cells:
                text = cell.text.strip()
                if text:
                    blocks.append(text)
    return "\n".join(blocks)


def main() -> None:
    failed = False
    for name, path in DOCS.items():
        document = Document(path)
        text = document_text(document)
        missing = [value for value in REQUIRED if value not in text]
        old = [value for value in LEGACY if value.casefold() in text.casefold()]
        headings = [
            p.text.strip()
            for p in document.paragraphs
            if p.text.strip() and p.style.name.startswith("Heading")
        ]
        duplicate_headings = [
            heading for heading, count in Counter(headings).items() if count > 1
        ]
        image_count = len(document.inline_shapes)
        ok = not missing and not old and not duplicate_headings and image_count == 9
        failed |= not ok
        print(
            f"{name}: ok={ok} images={image_count} "
            f"missing={missing or 'none'} legacy={old or 'none'} "
            f"duplicate_headings={duplicate_headings or 'none'}"
        )
    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()
