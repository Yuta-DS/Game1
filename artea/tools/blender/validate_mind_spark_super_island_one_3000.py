"""Validate the editable and runtime deliverables for Mind Spark Island One."""

from __future__ import annotations

import csv
import json
from collections import Counter
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]
ASSET_DIR = ROOT / "assets3D" / "mind_spark" / "super_island_one_3000"
BLEND_PATH = ASSET_DIR / "source" / "super_island_one_3000.blend"
GLB_PATH = ASSET_DIR / "super_island_one.glb"
BOM_PATH = ASSET_DIR / "bom" / "super_island_one_parts.csv"
MANIFEST_PATH = ASSET_DIR / "manifest.json"

EXPECTED = {
    "01_Deck_Paving": 600,
    "02_Rim_Retaining": 240,
    "03_Faceted_Keel": 500,
    "04_Lift_Machinery": 480,
    "05_Aether_Conservatory": 380,
    "06_Verdant_Crown_Garden": 420,
    "07_Rails_Lanterns": 280,
    "08_Gameplay_Fittings": 100,
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    for path in (BLEND_PATH, GLB_PATH, BOM_PATH, MANIFEST_PATH):
        require(path.is_file(), f"missing deliverable: {path}")
        require(path.stat().st_size > 0, f"empty deliverable: {path}")

    bpy.ops.wm.open_mainfile(filepath=str(BLEND_PATH))
    editable = [obj for obj in bpy.data.objects if obj.type == "MESH" and "part_id" in obj]
    require(len(editable) == 3000, f"expected 3000 editable meshes, got {len(editable)}")

    ids = [str(obj["part_id"]) for obj in editable]
    require(len(set(ids)) == 3000, "part IDs are not unique")
    require(ids == sorted(ids), "part IDs are not lexically ordered in the source")
    require(ids[0] == "MSI1-P0001" and ids[-1] == "MSI1-P3000", "part ID range is incomplete")

    counts = Counter(str(obj["category"]) for obj in editable)
    require(dict(counts) == EXPECTED, f"category counts differ: {dict(counts)}")
    for obj in editable:
        require(obj.data is not None and len(obj.data.polygons) > 0, f"empty mesh: {obj.name}")
        require(len(obj.material_slots) > 0, f"unmaterialed mesh: {obj.name}")

    with BOM_PATH.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    require(len(rows) == 3000, f"BOM row count differs: {len(rows)}")
    require({row["part_id"] for row in rows} == set(ids), "BOM/source IDs differ")

    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    require(manifest["editable_parts"] == 3000, "manifest editable count differs")
    require(manifest["runtime_batches"] == 9, "runtime batch count differs")
    require(manifest["category_counts"] == EXPECTED, "manifest category counts differ")

    with GLB_PATH.open("rb") as handle:
        require(handle.read(4) == b"glTF", "runtime asset is not a binary glTF")

    print(json.dumps({
        "status": "MSI1_VALIDATION_PASS",
        "editable_parts": len(editable),
        "runtime_batches": manifest["runtime_batches"],
        "category_counts": dict(counts),
        "glb_bytes": GLB_PATH.stat().st_size,
        "mini_game_support": manifest["mini_game_support"],
    }))


if __name__ == "__main__":
    main()
