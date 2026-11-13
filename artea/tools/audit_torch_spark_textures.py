"""Audit texture coverage for every editable Torch Spark Socket polygon."""

from __future__ import annotations

from collections import Counter
import json
from pathlib import Path

import bpy


BLEND_FILE = Path(
    "/Users/davidsovann/GAME/Crystal_Star_Pedestal/"
    "crystal_star_pedestal_textured_master.blend"
)
MANIFEST = Path(
    "/Users/davidsovann/S2603/artea/assets/textures/mind_spark/quest_objects/"
    "torch_spark_socket/texture_manifest.json"
)


def main() -> None:
    bpy.ops.wm.open_mainfile(filepath=str(BLEND_FILE))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    failures: list[str] = []
    material_usage: Counter[str] = Counter()
    surface_usage: Counter[str] = Counter()
    polygon_count = 0

    for obj in meshes:
        if not obj.data.uv_layers:
            failures.append(f"{obj.name}: missing UV map")
        if not obj.material_slots:
            failures.append(f"{obj.name}: no material slots")
            continue

        for polygon in obj.data.polygons:
            polygon_count += 1
            if polygon.material_index >= len(obj.material_slots):
                failures.append(f"{obj.name}: polygon {polygon.index} has invalid material index")
                continue
            material = obj.material_slots[polygon.material_index].material
            if material is None:
                failures.append(f"{obj.name}: polygon {polygon.index} has no material")
                continue
            material_usage[material.name] += 1
            if not material.get("torch_spark_texture_surface"):
                failures.append(f"{obj.name}: {material.name} has no assigned texture surface")
            else:
                surface_usage[material["torch_spark_texture_surface"]] += 1
            node_tree = material.node_tree
            if node_tree is None:
                failures.append(f"{obj.name}: {material.name} has no shader nodes")
                continue
            image_labels = {
                node.label
                for node in node_tree.nodes
                if node.type == "TEX_IMAGE" and node.image is not None
            }
            missing = {"PBR Base Color", "PBR Roughness", "PBR Normal"} - image_labels
            if missing:
                failures.append(
                    f"{obj.name}: {material.name} missing {', '.join(sorted(missing))}"
                )

    print(f"TEXTURE_AUDIT meshes={len(meshes)} polygons={polygon_count}")
    print("TEXTURE_AUDIT material_usage=" + ", ".join(
        f"{name}:{count}" for name, count in sorted(material_usage.items())
    ))
    expected_surfaces = set(json.loads(MANIFEST.read_text())["material_textures"].values())
    missing_surfaces = expected_surfaces - set(surface_usage)
    if missing_surfaces:
        failures.append("unused generated surfaces: " + ", ".join(sorted(missing_surfaces)))
    print(f"TEXTURE_AUDIT unique_surfaces={len(surface_usage)}/{len(expected_surfaces)}")
    if failures:
        for failure in failures[:100]:
            print(f"TEXTURE_AUDIT_FAILURE {failure}")
        raise RuntimeError(f"Texture coverage failed with {len(failures)} surface errors")
    print("TEXTURE_AUDIT PASS: every editable polygon has UVs and all three PBR maps")


if __name__ == "__main__":
    main()
