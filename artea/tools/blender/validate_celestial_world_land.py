"""Independently reimport and validate the game-ready celestial land GLB."""
import hashlib
import json
import math
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets3D/mind_spark/celestial_land_runtime"


def main():
    manifest = json.loads((OUT / "build_manifest.json").read_text())
    with (ROOT / manifest["source"]).open("rb") as stream:
        source_hash = hashlib.file_digest(stream, "sha256").hexdigest()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OUT / "celestial_land.glb"))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    checks = {
        "source_master_checksum_unchanged": source_hash == manifest["source_sha256"],
        "five_mesh_families": len(meshes) == 5,
        "included_part_ids_unique": len({p["part_id"] for p in manifest["parts"]}) == 1720,
        "all_80_condenser_parts_retained": sum(p["source_name"].startswith("CC7_") for p in manifest["parts"]) == 80,
        "triangle_budget": sum(len(o.data.polygons) for o in meshes) < 650000,
        "triangle_count_matches_export": sum(len(o.data.polygons) for o in meshes) == manifest["runtime_triangles"],
        "finite_vertices": all(math.isfinite(c) for o in meshes for v in o.data.vertices for c in v.co),
        "all_faces_triangles": all(len(p.vertices) == 3 for o in meshes for p in o.data.polygons),
        "positive_face_areas": all(p.area > 1e-20 for o in meshes for p in o.data.polygons),
        "shallow_inlay_clearance": max((o.matrix_world @ v.co).z for o in meshes for v in o.data.vertices) < 0.0004,
        "no_import_repairs_needed": not any(o.data.validate() for o in meshes),
    }
    result = {"passed": all(checks.values()), "checks": checks,
              "triangles": sum(len(o.data.polygons) for o in meshes),
              "mesh_nodes": len(meshes), "bytes": (OUT / "celestial_land.glb").stat().st_size}
    (OUT / "validation_report.json").write_text(json.dumps(result, indent=2) + "\n")
    print("CELESTIAL_REIMPORT_VALIDATION: " + json.dumps(result), flush=True)
    assert result["passed"], result


if __name__ == "__main__":
    main()
