"""Validate the standalone leaf library without touching Tree of Life assets."""

import json
import os
import sys

import bpy


PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LEAF_ROOT = os.path.join(PROJECT_ROOT, "assets3D", "tree_of_life", "leaves")
BLEND_PATH = os.path.join(LEAF_ROOT, "source", "artea_leaf_library.blend")
GLB_PATH = os.path.join(LEAF_ROOT, "glb", "artea_leaf_library.glb")
MANIFEST_PATH = os.path.join(LEAF_ROOT, "leaf_library_manifest.json")
REPORT_PATH = os.path.join(LEAF_ROOT, "leaf_library_validation.json")
LIVING_ALBEDO_PATH = os.path.join(LEAF_ROOT, "textures", "living_leaf_olive_albedo.png")
LIVING_BRANCH_ALBEDO_PATH = os.path.join(LEAF_ROOT, "textures", "living_branch_teal_albedo.png")
EXPECTED_TYPES = {
    "living_leaf_fan", "magic_rune_leaf",
    "solar_glass_science_leaf", "emerald_sensor_leaf",
}


def descendants(root):
    result = []
    pending = list(root.children)
    while pending:
        obj = pending.pop()
        result.append(obj)
        pending.extend(obj.children)
    return result


def main():
    errors = []
    for path in (BLEND_PATH, GLB_PATH, MANIFEST_PATH, LIVING_ALBEDO_PATH, LIVING_BRANCH_ALBEDO_PATH):
        if not os.path.exists(path):
            errors.append(f"missing leaf-library artifact: {path}")
    if errors:
        print("\n".join(errors))
        sys.exit(1)
    with open(MANIFEST_PATH, encoding="utf-8") as file:
        manifest = json.load(file)
    if manifest.get("scope") != "leaves_only_no_tree_geometry":
        errors.append("manifest scope is not leaf-only")
    if manifest.get("tree_files_modified") is not False:
        errors.append("manifest does not prove tree files remained out of scope")
    individual_glbs = manifest.get("individual_game_glbs", {})
    if set(individual_glbs) != EXPECTED_TYPES:
        errors.append("manifest does not expose four individual leaf GLBs")
    for leaf_type, relative_path in individual_glbs.items():
        if not os.path.exists(os.path.join(PROJECT_ROOT, relative_path)):
            errors.append(f"missing individual GLB for {leaf_type}: {relative_path}")

    bpy.ops.wm.open_mainfile(filepath=BLEND_PATH)
    roots = [obj for obj in bpy.data.objects if obj.get("standalone_leaf_asset")]
    actual_types = {obj.get("leaf_type") for obj in roots}
    if actual_types != EXPECTED_TYPES:
        errors.append(f"source leaf types differ: {sorted(actual_types)}")
    source_counts = {}
    for root in roots:
        leaf_type = root.get("leaf_type")
        meshes = [obj for obj in descendants(root) if obj.type == 'MESH']
        vertices = sum(len(obj.data.vertices) for obj in meshes)
        modules = len(meshes)
        source_counts[leaf_type] = {"vertices": vertices, "named_modules": modules}
        if vertices < 10_000:
            errors.append(f"{leaf_type} has only {vertices} vertices; expected at least 10,000")
        if modules < 8:
            errors.append(f"{leaf_type} has only {modules} logical modules")
        expected = manifest.get("leaves", {}).get(leaf_type, {})
        if vertices != expected.get("vertices") or modules != expected.get("named_modules"):
            errors.append(f"manifest/source mismatch for {leaf_type}")
        required_modules = {obj.get("module_type") for obj in meshes}
        if "blade_facets" not in required_modules:
            errors.append(f"{leaf_type} has no editable blade facets")
        if not ({"gold_outline", "solar_glass_frame"} & required_modules):
            errors.append(f"{leaf_type} has no clear editable outline")
        if leaf_type == "living_leaf_fan":
            leaflets = [obj for obj in meshes if obj.name.startswith("LivingFan_Leaflet_")]
            if len(leaflets) != 7:
                errors.append(f"living fan exposes {len(leaflets)} separate leaflets instead of seven")
            if any(not obj.data.uv_layers for obj in leaflets):
                errors.append("one or more Living fan leaflets have no UV map")

    for material_name in ("MAT_LeafLibrary_ForestA", "MAT_LeafLibrary_ForestB", "MAT_LeafLibrary_ForestC"):
        material = bpy.data.materials.get(material_name)
        image_nodes = ([node for node in material.node_tree.nodes if node.type == 'TEX_IMAGE']
                       if material and material.use_nodes else [])
        if not image_nodes or image_nodes[0].image is None:
            errors.append(f"{material_name} is not wired to the Living Leaf albedo texture")
    branch_material = bpy.data.materials.get("MAT_LeafLibrary_LivingVein")
    branch_images = ([node for node in branch_material.node_tree.nodes if node.type == 'TEX_IMAGE']
                     if branch_material and branch_material.use_nodes else [])
    if not branch_images or branch_images[0].image is None:
        errors.append("Living branch material is not wired to its teal albedo texture")
    branch_objects = [obj for obj in bpy.data.objects
                      if obj.name in {"LivingFan_CrystalVeins", "LivingFan_EnergyPetioles"}]
    if len(branch_objects) != 2 or any(not obj.data.uv_layers for obj in branch_objects):
        errors.append("Living branch and vein networks do not expose ribbon UV maps")

    if any("TreeOfLife" in obj.name or "Trunk" in obj.name or "Root" in obj.name
           for obj in bpy.data.objects):
        errors.append("leaf-only Blender file contains tree/trunk/root geometry")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB_PATH)
    if any(obj.type in {'CAMERA', 'LIGHT'} for obj in bpy.data.objects):
        errors.append("leaf GLB unexpectedly contains a camera or light")
    glb_roots = [obj for obj in bpy.context.scene.objects
                 if obj.parent is None and obj.name in {
                     "LivingLeafFan", "MagicRuneLeaf", "SolarGlassScienceLeaf", "EmeraldSensorLeaf"
                 }]
    if len(glb_roots) != 4:
        errors.append(f"leaf GLB does not expose four reusable roots: {len(glb_roots)}")

    report = {
        "passed": not errors,
        "errors": errors,
        "scope": "leaves_only_no_tree_geometry",
        "leaf_types": source_counts,
        "glb_reusable_roots": sorted(obj.name for obj in glb_roots),
    }
    with open(REPORT_PATH, "w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)
    if errors:
        for error in errors:
            print(f"[leaf-library][ERROR] {error}")
        sys.exit(1)
    print("ARTEA_LEAF_LIBRARY_VALIDATION: PASS")
    for leaf_type, counts in sorted(source_counts.items()):
        print(f"  {leaf_type}: {counts['vertices']} editable vertices, {counts['named_modules']} modules")


if __name__ == "__main__":
    main()
