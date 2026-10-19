#!/usr/bin/env python3
"""Fail when two project resources declare the same Godot UID."""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
SKIP_PARTS = {".git", ".godot", "builds"}
UID_PATTERN = re.compile(r'\buid\s*=\s*"?(uid://[a-z0-9]+)"?')
REFERENCE_PATTERN = re.compile(
    r'\[ext_resource\b[^\]]*\buid="(uid://[a-z0-9]+)"[^\]]*\bpath="(res://[^"]+)"'
)
HEADER_SUFFIXES = {".tscn", ".tres"}


def declared_uid(path: Path) -> str | None:
    try:
        if path.name.endswith(".uid"):
            return path.read_text(encoding="utf-8").strip() or None
        if path.suffix in HEADER_SUFFIXES:
            first_line = path.open(encoding="utf-8").readline()
            match = UID_PATTERN.search(first_line)
            return match.group(1) if match else None
        if path.suffix == ".import":
            with path.open(encoding="utf-8") as handle:
                for line in handle:
                    match = UID_PATTERN.search(line)
                    if match:
                        return match.group(1)
                    if line.strip() == "[deps]":
                        break
    except (OSError, UnicodeDecodeError) as error:
        print(f"Unable to read {path.relative_to(PROJECT_ROOT)}: {error}", file=sys.stderr)
        raise
    return None


def main() -> int:
    owners: dict[str, list[Path]] = defaultdict(list)
    declared_by_resource: dict[str, str] = {}
    for path in PROJECT_ROOT.rglob("*"):
        if not path.is_file() or any(part in SKIP_PARTS for part in path.parts):
            continue
        if not (path.name.endswith(".uid") or path.suffix in HEADER_SUFFIXES | {".import"}):
            continue
        uid = declared_uid(path)
        if uid:
            relative_path = path.relative_to(PROJECT_ROOT)
            owners[uid].append(relative_path)
            if path.name.endswith(".uid"):
                resource_path = str(relative_path)[:-4]
            elif path.suffix == ".import":
                imported_path = Path(str(path)[:-7])
                resource_path = str(relative_path)[:-7] if imported_path.exists() else ""
            else:
                resource_path = str(relative_path)
            if resource_path:
                declared_by_resource[f"res://{resource_path}"] = uid

    duplicate_groups = {uid: paths for uid, paths in owners.items() if len(paths) > 1}
    if duplicate_groups:
        print(f"Duplicate Godot resource UIDs: {len(duplicate_groups)}", file=sys.stderr)
        for uid, paths in sorted(duplicate_groups.items()):
            print(f"  {uid}", file=sys.stderr)
            for path in sorted(paths):
                print(f"    {path}", file=sys.stderr)
        return 1

    invalid_references: list[tuple[Path, str, str, str]] = []
    for path in PROJECT_ROOT.rglob("*"):
        if not path.is_file() or path.suffix not in HEADER_SUFFIXES:
            continue
        if any(part in SKIP_PARTS for part in path.parts):
            continue
        for match in REFERENCE_PATTERN.finditer(path.read_text(encoding="utf-8")):
            referenced_uid, resource_path = match.groups()
            declared = declared_by_resource.get(resource_path)
            if declared and referenced_uid != declared:
                invalid_references.append(
                    (path.relative_to(PROJECT_ROOT), resource_path, referenced_uid, declared)
                )
    if invalid_references:
        print(f"Stale Godot resource UID references: {len(invalid_references)}", file=sys.stderr)
        for owner, resource, actual, expected in invalid_references:
            print(f"  {owner}: {resource} uses {actual}; expected {expected}", file=sys.stderr)
        return 1

    print(f"Unique Godot resource UID declarations: {len(owners)}; stale references: 0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
