#!/usr/bin/env python3
"""Summarize files in the split Godot 4 Web PCK without reconstructing it."""

from __future__ import annotations

import argparse
import struct
from collections import defaultdict
from pathlib import Path


PART_SIZE = 8 * 1024 * 1024


def read_at(build: Path, offset: int, length: int) -> bytes:
    result = bytearray()
    while length:
        part_index, inner_offset = divmod(offset, PART_SIZE)
        with (build / f"index.pck.part{part_index:02d}").open("rb") as stream:
            stream.seek(inner_offset)
            chunk = stream.read(min(length, PART_SIZE - inner_offset))
        if not chunk:
            raise ValueError(f"PCK ended while reading offset {offset}")
        result.extend(chunk)
        offset += len(chunk)
        length -= len(chunk)
    return bytes(result)


def audit(build: Path, top: int) -> None:
    header = read_at(build, 0, 112)
    if header[:4] != b"GDPC":
        raise ValueError("Not a Godot PCK")
    directory_offset = struct.unpack_from("<Q", header, 32)[0]
    count = struct.unpack("<I", read_at(build, directory_offset, 4))[0]
    cursor = directory_offset + 4
    files: list[tuple[int, str]] = []
    groups: dict[str, list[int]] = defaultdict(list)
    for _ in range(count):
        path_length = struct.unpack("<I", read_at(build, cursor, 4))[0]
        cursor += 4
        path = read_at(build, cursor, path_length).rstrip(b"\0").decode("utf-8")
        cursor += path_length
        offset, size = struct.unpack("<QQ", read_at(build, cursor, 16))
        cursor += 36  # offset, size, MD5, flags
        files.append((size, path))
        group = Path(path).suffix or "[none]"
        groups[group].append(size)
        if offset + size > directory_offset:
            raise ValueError(f"File overlaps PCK directory: {path}")
    print(f"Godot PCK: {count:,} files; {directory_offset:,} bytes of payload")
    print("Largest files:")
    for size, path in sorted(files, reverse=True)[:top]:
        print(f"{size / 1048576:7.1f} MiB  {path}")
    print("By extension:")
    for extension, sizes in sorted(groups.items(), key=lambda item: sum(item[1]), reverse=True):
        print(f"{sum(sizes) / 1048576:7.1f} MiB  {len(sizes):5d}  {extension}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("build", type=Path, nargs="?", default=Path("builds/web"))
    parser.add_argument("--top", type=int, default=35)
    args = parser.parse_args()
    audit(args.build, args.top)
