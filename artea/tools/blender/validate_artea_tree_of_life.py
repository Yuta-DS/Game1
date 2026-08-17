"""Independent source and GLB validator for the Artéa Tree of Life."""

import json
import os
import sys

import bpy


PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSET_ROOT = os.path.join(PROJECT_ROOT, "assets3D", "tree_of_life")
BLEND_PATH = os.path.join(ASSET_ROOT, "source", "artea_tree_of_life.blend")
GLB_PATH = os.path.join(ASSET_ROOT, "glb", "artea_tree_of_life.glb")
MANIFEST_PATH = os.path.join(ASSET_ROOT, "tree_of_life_manifest.json")
REPORT_PATH = os.path.join(ASSET_ROOT, "tree_of_life_validation.json")


def descendants(root):
    result = []
    pending = list(root.children)
    while pending:
        obj = pending.pop()
        result.append(obj)
        pending.extend(obj.children)
    return result


def bounds(meshes):
    minimum = [float("inf")] * 3
    maximum = [float("-inf")] * 3
    for obj in meshes:
        for corner in obj.bound_box:
            point = obj.matrix_world @ __import__("mathutils").Vector(corner)
            for axis in range(3):
                minimum[axis] = min(minimum[axis], point[axis])
                maximum[axis] = max(maximum[axis], point[axis])
    return minimum, maximum


def fail(errors, message):
    errors.append(message)
    print(f"[tree-validator][ERROR] {message}")


def main():
    errors = []
    if not os.path.exists(BLEND_PATH):
        fail(errors, f"missing Blender source: {BLEND_PATH}")
    if not os.path.exists(GLB_PATH):
        fail(errors, f"missing game GLB: {GLB_PATH}")
    if not os.path.exists(MANIFEST_PATH):
        fail(errors, f"missing manifest: {MANIFEST_PATH}")
    if errors:
        sys.exit(1)

    with open(MANIFEST_PATH, encoding="utf-8") as file:
        manifest = json.load(file)

    bpy.ops.wm.open_mainfile(filepath=BLEND_PATH)
    source_root = bpy.data.objects.get("ArteaTreeOfLife_SourceRoot")
    if source_root is None:
        fail(errors, "source root ArteaTreeOfLife_SourceRoot is missing")
        source_meshes = []
    else:
        source_meshes = [
            obj for obj in descendants(source_root)
            if obj.type == 'MESH' and obj.get("export_group") != "CollisionGuides"
        ]
    source_vertices = sum(len(obj.data.vertices) for obj in source_meshes)
    source_edges = sum(len(obj.data.edges) for obj in source_meshes)
    source_faces = sum(len(obj.data.polygons) for obj in source_meshes)
    leaf_modules = sum(int(obj.get("leaf_module_count", 0)) for obj in source_meshes)
    leaf_power_nodes = sum(
        1 for obj in source_meshes if obj.get("module_type") == "crystal_leaf_power_node"
    )
    leaf_tech_spines = sum(
        1 for obj in source_meshes if obj.get("module_type") == "black_biotech_leaf_spine"
    )
    if len(source_meshes) < 1_300:
        fail(errors, f"only {len(source_meshes)} named source modules; expected at least 1300")
    if source_vertices < 100_000:
        fail(errors, f"only {source_vertices} distinct editable vertices; expected at least 100000")
    if leaf_modules < 4_900:
        fail(errors, f"only {leaf_modules} leaf modules; expected at least 4900")
    if leaf_power_nodes < 44 or leaf_tech_spines < 88:
        fail(errors, f"powered foliage is incomplete: {leaf_power_nodes} crystal nodes, {leaf_tech_spines} tech spines")
    if manifest["source"]["vertices"] != source_vertices:
        fail(errors, "manifest/source Blender vertex count mismatch")
    if not manifest["source"]["requirement_met"]:
        fail(errors, "manifest says the editable-component requirement is not met")
    if manifest.get("version") != 3 or len(manifest.get("blueprint_references", [])) != 4:
        fail(errors, "manifest is not tied to the four component-blueprint references")
    design = manifest.get("design", {})
    if design.get("silhouette") != "braided_twin_trunk_gothic_arch":
        fail(errors, "manifest does not identify the redesigned twin-trunk silhouette")
    if design.get("foundation_depth_m") != 14.0 or design.get("player_clear_path_m") != 9.5:
        fail(errors, "foundation depth or player-clear path differs from the component blueprints")
    if design.get("foliage_style") != "dense_crystal_powered_branch_fans" \
            or len(design.get("leaf_families", [])) != 4:
        fail(errors, "manifest does not identify the four-family crystal-powered leaf redesign")
    if manifest["source"].get("leaf_power_nodes") != leaf_power_nodes \
            or manifest["source"].get("leaf_tech_spines") != leaf_tech_spines:
        fail(errors, "manifest/source powered-foliage component counts differ")
    collision = manifest.get("collision_policy", {})
    if len(collision.get("trunk_pillars", [])) != 2 or len(collision.get("root_proxies", [])) != 12:
        fail(errors, "manifest collision layout is not the authored 2-trunk/12-root system")

    # Import the GLB into a clean scene to prove it stands alone.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB_PATH)
    cameras = [obj.name for obj in bpy.data.objects if obj.type == 'CAMERA']
    lights = [obj.name for obj in bpy.data.objects if obj.type == 'LIGHT']
    if cameras or lights:
        fail(errors, f"GLB unexpectedly contains cameras/lights: {cameras + lights}")
    game_root = bpy.data.objects.get("ArteaTreeOfLifeModel")
    if game_root is None:
        fail(errors, "GLB root ArteaTreeOfLifeModel is missing")
        game_meshes = []
    else:
        game_meshes = [obj for obj in descendants(game_root) if obj.type == 'MESH']
    expected_groups = {
        "Branches", "BrassEngineering", "CrystalTechnology", "FoliageMagic",
        "FoliageNature", "FoliageSolarGlass", "Foundation", "Roots", "Trunk", "WisdomStar",
    }
    actual_groups = {obj.name.split(".")[0] for obj in game_meshes}
    if actual_groups != expected_groups:
        fail(errors, f"GLB system meshes differ: expected {sorted(expected_groups)}, got {sorted(actual_groups)}")
    material_names = {material.name.split(".")[0] for material in bpy.data.materials}
    for required in (
        "MAT_LivingBark", "MAT_EngineeredBrass", "MAT_CrystalSap_Cyan",
        "MAT_Leaf_Forest", "MAT_Leaf_VioletMagic", "MAT_SolarGlassLeaf",
        "MAT_BlackBioTechSpine", "MAT_Leaf_EmeraldSensor",
        "MAT_LeafCircuit_Cyan",
        "MAT_EngineeredFoundationDark", "MAT_GoldInlayStone",
        "MAT_HeartCrystalInnerViolet", "MAT_WisdomGold",
    ):
        if required not in material_names:
            fail(errors, f"required GLB material is missing: {required}")
    minimum, maximum = bounds(game_meshes) if game_meshes else ([0, 0, 0], [0, 0, 0])
    dimensions = [maximum[index] - minimum[index] for index in range(3)]
    if max(dimensions) < 60.0:
        fail(errors, f"imported tree is unexpectedly small: dimensions={dimensions}")
    if max(dimensions) > 90.0:
        fail(errors, f"imported tree exceeds the authored design envelope: dimensions={dimensions}")

    report = {
        "passed": not errors,
        "errors": errors,
        "source": {
            "named_mesh_modules": len(source_meshes),
            "vertices": source_vertices,
            "edges": source_edges,
            "faces": source_faces,
            "editable_elements": source_vertices + source_edges + source_faces,
            "leaf_modules": leaf_modules,
            "leaf_power_nodes": leaf_power_nodes,
            "leaf_tech_spines": leaf_tech_spines,
        },
        "game_export": {
            "mesh_nodes": len(game_meshes),
            "systems": sorted(actual_groups),
            "dimensions_m": dimensions,
            "materials": sorted(material_names),
        },
    }
    with open(REPORT_PATH, "w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)
    if errors:
        print(f"TREE_OF_LIFE_VALIDATION: FAIL — {len(errors)} errors")
        sys.exit(1)
    print(
        "TREE_OF_LIFE_VALIDATION: PASS — "
        f"{source_vertices} distinct editable vertices, {len(source_meshes)} modules, "
        f"{len(game_meshes)} optimized GLB systems"
    )


if __name__ == "__main__":
    main()
