#!/usr/bin/env python3
"""Recolour the Tree of Life energy fibers inside the exported GLBs.

Why edit the GLB rather than re-run the Blender build: the committed
artea_tree_of_life.glb is not what build_artea_tree_of_life.py emits. The script
produces 727k triangles and three extra material groups, while the committed
asset holds 182k - the .blend was pruned after generation and exported from
there. Re-running the build to change a colour would silently discard that work.

A GLB is a JSON chunk followed by a binary chunk. Material colours live entirely
in the JSON, so they can be rewritten without touching a single vertex.

    python3 artea/tools/recolour_tree_fibers.py            # apply
    python3 artea/tools/recolour_tree_fibers.py --check    # report only
    python3 artea/tools/recolour_tree_fibers.py --restore  # undo from backup

Run Godot's importer afterwards so the .import cache picks the change up:

    Godot --headless --path artea --import
"""

from __future__ import annotations

import argparse
import json
import shutil
import struct
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent

GLBS = [
    PROJECT / "assets3D/tree_of_life/glb/artea_tree_of_life.glb",
    PROJECT / "assets3D/tree_of_life/canopy/glb/crystal_branch_canopy.glb",
]

# Cyan fiber materials, mapped to the blue the heart crystal uses. Base colour
# first, emissive second; alpha is carried through untouched.
BLUE_BASE = [0.02, 0.24, 0.86]
BLUE_EMISSIVE = [0.06, 0.34, 1.0]

TARGET_MATERIALS = {
    "MAT_CrystalSap_Cyan",
    "MAT_LeafCircuit_Cyan",
    "MAT_CanopyCyanSapEnergy",
    "MAT_RootCyanSapInlay",
    "MAT_CanopyCrystalPowerNode",
    "MAT_RootRelayCrystal",
}

JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942


def read_glb(path: Path):
    data = path.read_bytes()
    magic, version, _total = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        raise ValueError(f"{path.name} is not a GLB")
    chunks = []
    offset = 12
    while offset < len(data):
        length, kind = struct.unpack_from("<II", data, offset)
        body = data[offset + 8: offset + 8 + length]
        chunks.append((kind, body))
        offset += 8 + length + (-length % 4)
    return version, chunks


def write_glb(path: Path, version: int, chunks) -> None:
    payload = b""
    for kind, body in chunks:
        padding = b"\x20" if kind == JSON_CHUNK else b"\x00"
        pad = (-len(body)) % 4
        body = body + padding * pad
        payload += struct.pack("<II", len(body), kind) + body
    header = struct.pack("<III", 0x46546C67, version, 12 + len(payload))
    path.write_bytes(header + payload)


def recolour(path: Path, apply: bool) -> int:
    version, chunks = read_glb(path)
    changed = 0
    new_chunks = []
    for kind, body in chunks:
        if kind != JSON_CHUNK:
            new_chunks.append((kind, body))
            continue
        js = json.loads(body.decode("utf-8"))
        for material in js.get("materials", []):
            if material.get("name") not in TARGET_MATERIALS:
                continue
            pbr = material.setdefault("pbrMetallicRoughness", {})
            base = pbr.get("baseColorFactor", [1.0, 1.0, 1.0, 1.0])
            alpha = base[3] if len(base) > 3 else 1.0
            before = [round(c, 2) for c in base[:3]]
            pbr["baseColorFactor"] = BLUE_BASE + [alpha]
            if "emissiveFactor" in material:
                material["emissiveFactor"] = list(BLUE_EMISSIVE)
            print(f"  {material['name']:30} {before} -> {BLUE_BASE}")
            changed += 1
        new_chunks.append((kind, json.dumps(js, separators=(",", ":")).encode("utf-8")))
    if changed and apply:
        backup = path.with_suffix(path.suffix + ".precolour")
        if not backup.exists():
            shutil.copy2(path, backup)
        write_glb(path, version, new_chunks)
    return changed


def restore(path: Path) -> bool:
    backup = path.with_suffix(path.suffix + ".precolour")
    if not backup.exists():
        return False
    shutil.copy2(backup, path)
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="report without writing")
    parser.add_argument("--restore", action="store_true", help="restore from backup")
    args = parser.parse_args()

    total = 0
    for path in GLBS:
        if not path.exists():
            print(f"missing: {path}")
            continue
        print(f"{path.name}:")
        if args.restore:
            print("  restored" if restore(path) else "  no backup to restore")
            continue
        total += recolour(path, apply=not args.check)
    if not args.restore:
        print(f"\n{total} materials {'would change' if args.check else 'changed'}")
        if not args.check and total:
            print("Now run: Godot --headless --path artea --import")
    return 0


if __name__ == "__main__":
    sys.exit(main())
