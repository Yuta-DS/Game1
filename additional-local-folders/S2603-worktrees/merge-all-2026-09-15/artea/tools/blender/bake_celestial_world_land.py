"""Derive the gameplay-safe land shell from the untouched v07 authoring master.

Run with Blender --background --python tools/blender/bake_celestial_world_land.py.
No source .blend is saved. Five material-batched meshes replace thousands of
runtime-generated nodes. The original 3,000 independently editable parts remain
in celestial_condenser_v07; runtime omissions are explicitly recorded.
"""
import hashlib
import json
import math
from collections import Counter
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets3D/mind_spark/celestial_condenser_v07/source/celestial_condenser_v07.blend"
OUT = ROOT / "assets3D/mind_spark/celestial_land_runtime"
FAMILIES = {
    "01_Rock_Anchors": "CelestialRockAnchors",
    "02_Civic_Deck": "CelestialIvoryDeck",
    "03_Civic_Facade": "CelestialArchesAndCondenser",
    "06_Steam_Machinery": "CelestialSteamDistribution",
    "07_Maintenance_Balcony": "CelestialServiceBalcony",
}
# Normalised radius: the source's main circular paving meets the existing
# cylinder floor exactly. Godot scales this common resource by each zone radius.
DECK_RADIUS = 7.83


def checksum(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    before = checksum(SOURCE)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    objects = sorted((o for o in bpy.data.objects if o.type == "MESH" and o.get("part_id")),
                     key=lambda o: o["part_id"])
    assert len(objects) == 3000
    included = [o for o in objects if o["family"] in FAMILIES]
    omitted = [o for o in objects if o["family"] not in FAMILIES]
    record = []
    source_triangles = 0
    for obj in included:
        old_triangles = len(obj.data.polygons)
        source_triangles += old_triangles
        # Bake transform first so simplification respects the actual silhouette.
        obj.data.transform(obj.matrix_world)
        obj.matrix_world = Matrix.Identity(4)
        if obj["family"] == "02_Civic_Deck":
            # Flatten raised inlay into an engraving-scale reveal (<0.07 m on
            # the largest island). Preserve the rest of the deck thickness.
            for vertex in obj.data.vertices:
                if vertex.co.z > 0:
                    vertex.co.z *= 0.055
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(3),
                                verts=list(bm.verts), edges=list(bm.edges),
                                delimit={"MATERIAL"})
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        bm.to_mesh(obj.data)
        bm.free()
        # Keep every included component; reduce over-tessellation within each
        # one independently so small bolts cannot disappear into larger parts.
        if len(obj.data.polygons) > 220:
            bpy.context.view_layer.objects.active = obj
            decimate = obj.modifiers.new("RuntimeTriangleBudget", "DECIMATE")
            decimate.ratio = max(0.18, 120 / len(obj.data.polygons))
            decimate.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=decimate.name)
        # Collapse can leave degenerate indices on the source's tiny bevels.
        # Clean them explicitly, before recording counts and before export.
        obj.data.validate(clean_customdata=True)
        obj.data.transform(Matrix.Scale(1 / DECK_RADIUS, 4))
        obj.data.update()
        if obj["family"] == "02_Civic_Deck":
            if obj.data.has_custom_normals:
                bpy.context.view_layer.objects.active = obj
                bpy.ops.mesh.customdata_custom_splitnormals_clear()
            # Do not interpolate a wide paving face toward its tiny bevel:
            # that creates visible triangular light patches after GLB import.
            for face in obj.data.polygons:
                if face.normal.z > 0.9:
                    face.use_smooth = False
        record.append({"part_id": obj["part_id"], "source_name": obj.name,
                       "family": obj["family"], "source_triangles": old_triangles,
                       "runtime_triangles": len(obj.data.polygons)})
        if len(record) % 400 == 0:
            print(f"CELESTIAL_REDUCTION: {len(record)}/{len(included)} parts", flush=True)
    assert sum(o.get("assembly") == "Twin-vessel steam condenser" for o in included) == 80
    family_parts = {family: [o for o in included if o["family"] == family] for family in FAMILIES}
    groups = []
    for family, name in FAMILIES.items():
        parts = family_parts[family]
        bpy.ops.object.select_all(action="DESELECT")
        for obj in parts:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = name
        obj.data.name = name + "Mesh"
        for key in list(obj.keys()):
            del obj[key]
        obj["runtime_family"] = family
        obj["source_part_count"] = len(parts)
        obj["source_revision"] = "v07"
        # Export one surface per used material, not hundreds of duplicate slots.
        bpy.ops.object.material_slot_remove_unused()
        groups.append(obj)
    total = sum(len(o.data.polygons) for o in groups)
    assert total < 650000, f"Runtime shell exceeds triangle budget: {total}"
    assert max(v.co.z for o in groups for v in o.data.vertices) < 0.0004
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in groups:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = groups[0]
    path = OUT / "celestial_land.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                             export_extras=True, export_cameras=False, export_lights=False)
    assert checksum(SOURCE) == before, "Authoring master changed"
    report = {
        "source": str(SOURCE.relative_to(ROOT)), "source_sha256": before,
        "source_master_parts": 3000, "source_master_unchanged": True,
        "included_parts": len(record), "omitted_parts": len(omitted),
        "omitted_families": dict(Counter(o["family"] for o in omitted)),
        "omission_reason": "Preserve existing gameplay routes and props; do not scale concept furniture into obstacles.",
        "source_selected_triangles": source_triangles, "runtime_triangles": total,
        "mesh_nodes": len(groups), "glb_bytes": path.stat().st_size,
        "normalised_deck_radius": 1.0, "deck_inlay_max_height_per_radius": 0.0004,
        "condenser_parts_preserved": 80,
        "collision_policy": "No imported collisions; existing zone floors, route decks and recovery volumes remain authoritative.",
        "families": {o["runtime_family"]: {"mesh": o.name,
                     "triangles": len(o.data.polygons), "materials": len(o.data.materials)} for o in groups},
        "parts": record,
    }
    (OUT / "build_manifest.json").write_text(json.dumps(report, indent=2) + "\n")
    print("CELESTIAL_RUNTIME: " + json.dumps({k: v for k, v in report.items() if k not in ("parts", "families")}), flush=True)


if __name__ == "__main__":
    main()
