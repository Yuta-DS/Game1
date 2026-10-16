"""Independently validate all three Mind Spark puzzle-control GLBs."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]
ASSET_ROOT = ROOT / "assets3D" / "mind_spark" / "puzzle_control_kit"
MANIFEST_PATH = ASSET_ROOT / "puzzle_control_kit_manifest.json"
REPORT_PATH = ASSET_ROOT / "validation_report.json"


def descendants(root):
    pending, result = list(root.children), []
    while pending:
        obj = pending.pop()
        result.append(obj)
        pending.extend(obj.children)
    return result


def main():
    manifest = json.loads(MANIFEST_PATH.read_text())
    errors, results = [], {}
    for kind, spec in manifest["assets"].items():
        path = ROOT / spec["glb"]
        bpy.ops.wm.read_factory_settings(use_empty=True)
        if not path.exists():
            errors.append(f"{kind}: missing GLB")
            continue
        bpy.ops.import_scene.gltf(filepath=str(path))
        roots = [obj for obj in bpy.data.objects if obj.parent is None]
        if len(roots) != 1:
            errors.append(f"{kind}: expected one root, got {len(roots)}")
            continue
        meshes = [obj for obj in descendants(roots[0]) if obj.type == "MESH"]
        non_triangles = sum(1 for obj in meshes for face in obj.data.polygons
                            if len(face.vertices) != 3)
        triangle_count = sum(len(obj.data.polygons) for obj in meshes)
        groups = {str(obj.get("semantic_group", "")) for obj in meshes}
        if non_triangles:
            errors.append(f"{kind}: {non_triangles} non-triangle faces")
        if groups != {"STONE", "GOLD", "GLASS", "MOVING", "MICRO"}:
            errors.append(f"{kind}: invalid runtime groups {sorted(groups)}")
        if triangle_count != int(spec["triangles"]):
            errors.append(f"{kind}: triangle count changed {triangle_count}")
        results[kind] = {
            "root": roots[0].name,
            "runtime_meshes": len(meshes),
            "triangles": triangle_count,
            "groups": sorted(groups),
            "bytes": path.stat().st_size,
        }
    report = {"passed": not errors, "assets": results, "errors": errors}
    REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    if errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
