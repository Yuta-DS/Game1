"""Independent Blender validator for the 12 Mind Spark quest object GLBs.

Clears the scene and imports each GLB fresh (no shared state with the build
script), then checks structural and asset-quality invariants that the build
pipeline promises: root/LOD0/LOD1/LOD2 hierarchy, UVs, textured hero
materials, state-group parts, UCX collision, absence of cameras/lights, and
strictly decreasing triangle counts across LODs.

Run headlessly:
    /Applications/Blender.app/Contents/MacOS/Blender --background --python \
        tools/blender/validate_mind_spark_quest_objects.py

Exits with a non-zero status (via sys.exit) if any check fails.
"""

import json
import os
import sys

import bpy

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GLB_DIR = os.path.join(REPO_ROOT, "assets3D", "mind_spark", "quest_objects", "glb")
REPORT_PATH = os.path.join(os.path.dirname(__file__), "mind_spark_quest_objects_report.json")
VALIDATION_REPORT_PATH = os.path.join(os.path.dirname(__file__),
                                       "mind_spark_quest_objects_validation.json")

OBJECT_IDS = [
    "thought_spark_socket",
    "evidence_scanner",
    "perspective_lens",
    "memory_constellation_board",
    "logic_gate_arch",
    "truth_bridge_tile",
    "focus_bell_beacon",
    "warden_anchor",
    "calm_rain_basin",
    "identity_reflection_mirror",
    "checkpoint_server_root",
    "clear_path_projector",
]

EXPECTED_STATES = ("inactive", "active", "completed")


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # Explicitly remove every object/collection/mesh/material/image rather than
    # relying on users==0 orphan purging: unlinked-but-still-referenced names
    # (e.g. "LOD0") otherwise persist in bpy.data and the next import gets
    # renamed to "LOD0.001", silently breaking name-based lookups.
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for coll in list(bpy.data.collections):
        bpy.data.collections.remove(coll)
    for block_list in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for block in list(block_list):
            block_list.remove(block)


def find_root_objects():
    return [o for o in bpy.data.objects if o.parent is None]


def collect_children(obj):
    return list(obj.children)


def mesh_objects_under(obj):
    result = []
    for child in obj.children:
        if child.type == 'MESH':
            result.append(child)
        result.extend(mesh_objects_under(child))
    return result


def count_tris(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    eval_obj = obj.evaluated_get(depsgraph)
    mesh = eval_obj.to_mesh()
    total = 0
    for poly in mesh.polygons:
        total += max(0, len(poly.vertices) - 2)
    eval_obj.to_mesh_clear()
    return total


def validate_object(obj_id, errors, warnings):
    glb_path = os.path.join(GLB_DIR, f"{obj_id}.glb")
    if not os.path.exists(glb_path):
        errors.append(f"[{obj_id}] GLB file missing at {glb_path}")
        return None

    reset_scene()
    bpy.ops.import_scene.gltf(filepath=glb_path)

    # --- no camera / light -------------------------------------------------
    for o in bpy.data.objects:
        if o.type in ('CAMERA', 'LIGHT'):
            errors.append(f"[{obj_id}] unexpected {o.type} object '{o.name}' in GLB")

    roots = find_root_objects()
    mesh_free_roots = [r for r in roots if r.type == 'EMPTY']
    if len(mesh_free_roots) != 1:
        errors.append(f"[{obj_id}] expected exactly 1 root empty, found {len(mesh_free_roots)}: "
                       f"{[r.name for r in roots]}")
        return None
    root = mesh_free_roots[0]

    if not root.name.endswith("Model"):
        warnings.append(f"[{obj_id}] root node '{root.name}' does not end with 'Model'")

    lod_children = {c.name: c for c in collect_children(root) if c.type == 'EMPTY'}
    missing_lods = [lod for lod in ("LOD0", "LOD1", "LOD2") if lod not in lod_children]
    if missing_lods:
        errors.append(f"[{obj_id}] missing LOD nodes: {missing_lods}")
        return None

    lod_meshes = {}
    lod_tris = {}
    for lod in ("LOD0", "LOD1", "LOD2"):
        meshes = mesh_objects_under(lod_children[lod])
        if not meshes:
            errors.append(f"[{obj_id}] {lod} has no mesh children")
        lod_meshes[lod] = meshes
        lod_tris[lod] = sum(count_tris(m) for m in meshes)

    # --- triangle ordering: LOD0 > LOD1 > LOD2, LOD0 within budget ---------
    t0, t1, t2 = lod_tris["LOD0"], lod_tris["LOD1"], lod_tris["LOD2"]
    if not (t0 > t1 > t2):
        errors.append(f"[{obj_id}] triangle ordering violated: LOD0={t0} LOD1={t1} LOD2={t2}")
    if t0 < 8000:
        errors.append(f"[{obj_id}] LOD0 triangle count {t0} is below the 8k minimum")
    if t0 > 40000:
        errors.append(f"[{obj_id}] LOD0 triangle count {t0} exceeds the 40k maximum")
    if not (10000 <= t0 <= 25000):
        warnings.append(f"[{obj_id}] LOD0 triangle count {t0} is outside the preferred 10k-25k band")

    # --- UVs on every LOD0 mesh --------------------------------------------
    for m in lod_meshes["LOD0"]:
        if not m.data.uv_layers:
            errors.append(f"[{obj_id}] LOD0 mesh '{m.name}' has no UV layer")

    # --- UCX collision -------------------------------------------------------
    ucx_objs = [o for o in lod_meshes["LOD0"] if o.name.startswith("UCX_")]
    if not ucx_objs:
        errors.append(f"[{obj_id}] no UCX_ collision mesh found under LOD0")

    # --- active material textures on hero surfaces --------------------------
    textured_polys_found = False
    for m in lod_meshes["LOD0"]:
        if m.name.startswith("UCX_"):
            continue
        for mat_slot in m.data.materials:
            if mat_slot is None or not mat_slot.use_nodes:
                continue
            for node in mat_slot.node_tree.nodes:
                if node.type == 'TEX_IMAGE' and node.image is not None:
                    if "Albedo" in mat_slot.name:
                        used = any(p.material_index == list(m.data.materials).index(mat_slot)
                                   for p in m.data.polygons)
                        if used:
                            textured_polys_found = True
    if not textured_polys_found:
        errors.append(f"[{obj_id}] no LOD0 mesh has polygons actively assigned to a textured "
                       f"albedo material slot")

    # --- state parts ---------------------------------------------------------
    lod0_names = {m.name for m in lod_meshes["LOD0"]}
    found_states = set()
    for state in EXPECTED_STATES:
        suffix = f"_{state.capitalize()}"
        alt_names = {
            "inactive": ("_Inactive",),
            "active": ("_Active",),
            "completed": ("_Completed", ""),
        }
        for name in lod0_names:
            lname = name.lower()
            if state in lname:
                found_states.add(state)
    if len(found_states) < 1:
        errors.append(f"[{obj_id}] no recognizable state-suffixed parts found under LOD0")

    return dict(
        object_id=obj_id,
        root_node=root.name,
        triangles_lod0=t0,
        triangles_lod1=t1,
        triangles_lod2=t2,
        ucx_nodes=[o.name for o in ucx_objs],
        lod0_mesh_count=len(lod_meshes["LOD0"]),
        states_detected=sorted(found_states),
        textured_hero_found=textured_polys_found,
    )


def main():
    errors = []
    warnings = []
    results = []

    for obj_id in OBJECT_IDS:
        result = validate_object(obj_id, errors, warnings)
        if result:
            results.append(result)

    report = dict(
        objects=results,
        errors=errors,
        warnings=warnings,
        passed=len(errors) == 0,
    )
    with open(VALIDATION_REPORT_PATH, "w") as f:
        json.dump(report, f, indent=2)

    print(f"[validate] checked {len(OBJECT_IDS)} objects, {len(results)} produced results")
    for w in warnings:
        print(f"[validate][WARN] {w}")
    for e in errors:
        print(f"[validate][FAIL] {e}")

    if errors:
        print(f"[validate] FAILED with {len(errors)} error(s)")
        sys.exit(1)
    print("[validate] PASSED")


if __name__ == "__main__":
    main()
