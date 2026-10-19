"""Independently import and validate the production Heavenly Star Gate GLB."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]
ASSET_ROOT = ROOT / "assets3D" / "mind_spark" / "heavenly_star_gate"
GLB_PATH = ASSET_ROOT / "glb" / "mind_spark_heavenly_star_gate.glb"
MANIFEST_PATH = ASSET_ROOT / "mind_spark_heavenly_star_gate_manifest.json"
REPORT_PATH = ASSET_ROOT / "validation_report.json"


def descendants(root):
    result, pending = [], list(root.children)
    while pending:
        obj = pending.pop()
        result.append(obj)
        pending.extend(obj.children)
    return result


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    manifest = json.loads(MANIFEST_PATH.read_text())
    errors = []
    if not GLB_PATH.exists():
        errors.append("GLB is missing")
    else:
        bpy.ops.import_scene.gltf(filepath=str(GLB_PATH))
    roots = [obj for obj in bpy.data.objects if obj.parent is None]
    root = roots[0] if roots else None
    if len(roots) != 1:
        errors.append(f"expected one root, got {[obj.name for obj in roots]}")
    meshes = [obj for obj in descendants(root) if obj.type == "MESH"] if root else []
    group_names = {obj.name for obj in meshes}
    required = {
        "MSHG_Foundation", "MSHG_PylonStone", "MSHG_Mechanism",
        "MSHG_GateLeafLeft", "MSHG_GateLeafRight", "MSHG_CrownStone",
        "MSHG_PowerStar", "MSHG_Trim", "MSHG_MicroDetail",
    }
    missing = sorted(required - group_names)
    if missing:
        errors.append(f"missing runtime groups: {missing}")
    non_triangles = [(obj.name, polygon.index, len(polygon.vertices))
                     for obj in meshes for polygon in obj.data.polygons
                     if len(polygon.vertices) != 3]
    if non_triangles:
        errors.append(f"non-triangle polygons: {non_triangles[:8]}")
    triangle_count = sum(len(obj.data.polygons) for obj in meshes)
    if not 40000 <= triangle_count <= 180000:
        errors.append(f"triangle count outside production envelope: {triangle_count}")
    materials = {mat.name for obj in meshes for mat in obj.data.materials if mat}
    required_materials = {"MSHG_MAT_IVORY_LIGHT", "MSHG_MAT_PALE_GOLD",
                          "MSHG_MAT_AETHER", "MSHG_MAT_TEAL", "MSHG_MAT_BRONZE"}
    if not required_materials.issubset(materials):
        errors.append(f"missing materials: {sorted(required_materials - materials)}")
    if manifest.get("editable_source_modules", 0) < 300:
        errors.append("editable module count is below 300")
    if manifest.get("all_faces_triangulated") is not True:
        errors.append("manifest does not certify triangular topology")
    report = {
        "passed": not errors,
        "root": root.name if root else None,
        "runtime_meshes": len(meshes),
        "runtime_groups": sorted(group_names),
        "triangles": triangle_count,
        "materials": sorted(materials),
        "editable_source_modules": manifest.get("editable_source_modules"),
        "errors": errors,
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    if errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
