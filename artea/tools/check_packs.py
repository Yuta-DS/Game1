"""Checks an exported Web build's Packs and prints their real sizes.

    python3 artea/tools/check_packs.py BUILD_DIR BUDGET_MB

Run by export-web-packs.sh after exporting. Fails (exit 1) when:
  * a Pack would delete Core files when mounted: a patch marks every Core file
    its preset leaves out as removed (directory flag 2);
  * an asset ships in two .pck files (issue #37: no asset duplicated across
    Packs). Engine metadata every patch carries is not an asset.
"""
import os
import struct
import sys

# Written by the exporter into every patch, and merged when mounted.
METADATA = {".godot/uid_cache.bin", ".godot/global_script_class_cache.cfg", "project.binary"}


def read_directory(path):
    """(name, size, flags) for each file in a PCK v3+ directory."""
    with open(path, "rb") as pck:
        if pck.read(4) != b"GDPC":
            sys.exit(f"{path} is not a pck")
        pck.seek(32)  # magic, version, engine version, pack flags, file base
        pck.seek(struct.unpack("<Q", pck.read(8))[0])
        entries = []
        for _ in range(struct.unpack("<I", pck.read(4))[0]):
            name = pck.read(struct.unpack("<I", pck.read(4))[0]).rstrip(b"\0").decode("utf-8", "replace")
            _offset, size = struct.unpack("<QQ", pck.read(16))
            pck.read(16)  # md5
            entries.append((name, size, struct.unpack("<I", pck.read(4))[0]))
        return entries


def main():
    build_dir, budget_mb = sys.argv[1], float(sys.argv[2])
    packs = sorted(f for f in os.listdir(build_dir) if f.endswith(".pck"))
    owner, problems = {}, []
    print("Exported Packs:")
    for pack in packs:
        entries = read_directory(os.path.join(build_dir, pack))
        removed = [name for name, _, flags in entries if flags & 2]
        if removed:
            problems.append(f"{pack} would delete {len(removed)} Core files when mounted, e.g. {removed[0]}")
        for name, size, flags in entries:
            if flags & 2 or size == 0 or name in METADATA:
                continue
            if name in owner:
                problems.append(f"{name} is in both {owner[name]} and {pack}")
            owner[name] = pack
        mb = os.path.getsize(os.path.join(build_dir, pack)) / 1048576
        print(f"  {mb:8.1f} MB  {pack}")
    core_mb = os.path.getsize(os.path.join(build_dir, "index.pck")) / 1048576
    state = f"{core_mb - budget_mb:.1f} MB over" if core_mb > budget_mb else "within"
    print(f"Core + Hub (index.pck): {core_mb:.1f} MB against a {budget_mb:.0f} MB budget ({state})")
    if problems:
        print("\n".join(problems[:20]), file=sys.stderr)
        sys.exit(f"{len(problems)} problem(s) with the exported Packs")


if __name__ == "__main__":
    main()
