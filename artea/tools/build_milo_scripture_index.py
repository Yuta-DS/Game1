#!/usr/bin/env python3
"""Build Milo's offline WEB scripture corpus from the official VPL archive.

The runtime never downloads scripture. This build-time tool converts the
official, public-domain 66-book World English Bible Protestant edition into
small per-book JSON files suitable for Godot Web.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import urllib.request
import zipfile
from pathlib import Path


SOURCE_URL = "https://ebible.org/Scriptures/engwebp_vpl.zip"
BOOKS = [
    ("GEN", "Genesis", ["gen", "genesis"]),
    ("EXO", "Exodus", ["exo", "exod", "exodus"]),
    ("LEV", "Leviticus", ["lev", "leviticus"]),
    ("NUM", "Numbers", ["num", "numbers"]),
    ("DEU", "Deuteronomy", ["deu", "deut", "deuteronomy"]),
    ("JOS", "Joshua", ["jos", "josh", "joshua"]),
    ("JDG", "Judges", ["jdg", "judg", "judges"]),
    ("RUT", "Ruth", ["rut", "ruth"]),
    ("1SA", "1 Samuel", ["1 sa", "1 sam", "1 samuel", "first samuel"]),
    ("2SA", "2 Samuel", ["2 sa", "2 sam", "2 samuel", "second samuel"]),
    ("1KI", "1 Kings", ["1 ki", "1 kgs", "1 kings", "first kings"]),
    ("2KI", "2 Kings", ["2 ki", "2 kgs", "2 kings", "second kings"]),
    ("1CH", "1 Chronicles", ["1 ch", "1 chr", "1 chronicles", "first chronicles"]),
    ("2CH", "2 Chronicles", ["2 ch", "2 chr", "2 chronicles", "second chronicles"]),
    ("EZR", "Ezra", ["ezr", "ezra"]),
    ("NEH", "Nehemiah", ["neh", "nehemiah"]),
    ("EST", "Esther", ["est", "esther"]),
    ("JOB", "Job", ["job"]),
    ("PSA", "Psalms", ["ps", "psa", "psalm", "psalms"]),
    ("PRO", "Proverbs", ["pr", "pro", "prov", "proverb", "proverbs"]),
    ("ECC", "Ecclesiastes", ["ecc", "eccl", "ecclesiastes"]),
    ("SOL", "Song of Solomon", ["song", "song of songs", "song of solomon", "sos"]),
    ("ISA", "Isaiah", ["isa", "isaiah"]),
    ("JER", "Jeremiah", ["jer", "jeremiah"]),
    ("LAM", "Lamentations", ["lam", "lamentations"]),
    ("EZE", "Ezekiel", ["ezk", "ezek", "ezekiel"]),
    ("DAN", "Daniel", ["dan", "daniel"]),
    ("HOS", "Hosea", ["hos", "hosea"]),
    ("JOE", "Joel", ["jol", "joel"]),
    ("AMO", "Amos", ["amo", "amos"]),
    ("OBA", "Obadiah", ["oba", "obad", "obadiah"]),
    ("JON", "Jonah", ["jon", "jonah"]),
    ("MIC", "Micah", ["mic", "micah"]),
    ("NAH", "Nahum", ["nam", "nah", "nahum"]),
    ("HAB", "Habakkuk", ["hab", "habakkuk"]),
    ("ZEP", "Zephaniah", ["zep", "zeph", "zephaniah"]),
    ("HAG", "Haggai", ["hag", "haggai"]),
    ("ZEC", "Zechariah", ["zec", "zech", "zechariah"]),
    ("MAL", "Malachi", ["mal", "malachi"]),
    ("MAT", "Matthew", ["mat", "matt", "matthew"]),
    ("MAR", "Mark", ["mrk", "mark"]),
    ("LUK", "Luke", ["luk", "luke"]),
    ("JOH", "John", ["jhn", "john"]),
    ("ACT", "Acts", ["act", "acts"]),
    ("ROM", "Romans", ["rom", "romans"]),
    ("1CO", "1 Corinthians", ["1 co", "1 cor", "1 corinthians", "first corinthians"]),
    ("2CO", "2 Corinthians", ["2 co", "2 cor", "2 corinthians", "second corinthians"]),
    ("GAL", "Galatians", ["gal", "galatians"]),
    ("EPH", "Ephesians", ["eph", "ephesians"]),
    ("PHI", "Philippians", ["php", "phil", "philippians"]),
    ("COL", "Colossians", ["col", "colossians"]),
    ("1TH", "1 Thessalonians", ["1 th", "1 thes", "1 thess", "1 thessalonians", "first thessalonians"]),
    ("2TH", "2 Thessalonians", ["2 th", "2 thes", "2 thess", "2 thessalonians", "second thessalonians"]),
    ("1TI", "1 Timothy", ["1 ti", "1 tim", "1 timothy", "first timothy"]),
    ("2TI", "2 Timothy", ["2 ti", "2 tim", "2 timothy", "second timothy"]),
    ("TIT", "Titus", ["tit", "titus"]),
    ("PHM", "Philemon", ["phm", "philem", "philemon"]),
    ("HEB", "Hebrews", ["heb", "hebrews"]),
    ("JAM", "James", ["jas", "james"]),
    ("1PE", "1 Peter", ["1 pe", "1 pet", "1 peter", "first peter"]),
    ("2PE", "2 Peter", ["2 pe", "2 pet", "2 peter", "second peter"]),
    ("1JO", "1 John", ["1 jn", "1 john", "first john"]),
    ("2JO", "2 John", ["2 jn", "2 john", "second john"]),
    ("3JO", "3 John", ["3 jn", "3 john", "third john"]),
    ("JUD", "Jude", ["jud", "jude"]),
    ("REV", "Revelation", ["rev", "revelation"]),
]
LINE_RE = re.compile(r"^([1-3A-Z]{3}) (\d+):(\d+) (.+)$")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", type=Path, help="Existing engwebp_vpl.zip")
    parser.add_argument("--output", type=Path, default=Path("data/scripture"))
    args = parser.parse_args()
    archive = args.archive or Path("/tmp/engwebp_vpl.zip")
    if not archive.exists():
        archive.parent.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(SOURCE_URL, archive)

    archive_bytes = archive.read_bytes()
    with zipfile.ZipFile(archive) as zf:
        lines = zf.read("engwebp_vpl.txt").decode("utf-8-sig").splitlines()

    metadata = {code: (name, aliases) for code, name, aliases in BOOKS}
    corpus: dict[str, dict[str, dict[str, str]]] = {code: {} for code, _, _ in BOOKS}
    for line in lines:
        match = LINE_RE.match(line)
        if not match:
            continue
        code, chapter, verse, text = match.groups()
        if code in corpus:
            corpus[code].setdefault(chapter, {})[verse] = text.strip()

    missing = [code for code, chapters in corpus.items() if not chapters]
    if missing:
        raise SystemExit(f"Missing books in source: {', '.join(missing)}")

    out = args.output
    books_dir = out / "books"
    books_dir.mkdir(parents=True, exist_ok=True)
    manifest_books = []
    total_verses = 0
    for code, _, _ in BOOKS:
        name, aliases = metadata[code]
        chapters = corpus[code]
        count = sum(len(verses) for verses in chapters.values())
        total_verses += count
        filename = f"{code.lower()}.json"
        payload = {"code": code, "book": name, "translation": "WEBP", "chapters": chapters}
        (books_dir / filename).write_text(
            json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n",
            encoding="utf-8",
        )
        manifest_books.append({
            "code": code,
            "name": name,
            "aliases": aliases,
            "path": f"res://data/scripture/books/{filename}",
            "chapters": len(chapters),
            "verses": count,
        })

    manifest = {
        "schema_version": 1,
        "translation": "World English Bible, Protestant edition",
        "translation_code": "WEBP",
        "canon": "66-book Protestant canon",
        "license": "Public domain (official publisher designation)",
        "source_url": SOURCE_URL,
        "source_sha256": hashlib.sha256(archive_bytes).hexdigest(),
        "book_count": len(manifest_books),
        "verse_count": total_verses,
        "books": manifest_books,
    }
    out.mkdir(parents=True, exist_ok=True)
    (out / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Built {len(manifest_books)} books / {total_verses} verses in {out}")


if __name__ == "__main__":
    main()
