"""Build the compact Godot runtime form of the authored gravity bough.

The editable source remains unchanged.  Repeated wood and biofiber pieces are
joined into two meshes, leaf families retain their authored socket transforms,
and their relief geometry is reduced for the million-leaf canopy population.
"""

from pathlib import Path

import bpy


PROJECT = Path(__file__).resolve().parents[2]
SOURCE = PROJECT / "assets3D/tree_of_life/gravity_leaf_bough/source/gravity_leaf_bough.blend"
OUTPUT_BLEND = PROJECT / "assets3D/tree_of_life/gravity_leaf_bough/source/gravity_leaf_bough_runtime.blend"
OUTPUT_GLB = PROJECT / "assets3D/tree_of_life/gravity_leaf_bough/glb/gravity_leaf_bough_runtime.glb"


def join_objects(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.hide_set(False)
        obj.hide_viewport = False
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = name
    return joined


def decimate_shared_leaf_families(leaves):
    by_mesh = {}
    for leaf in leaves:
        by_mesh.setdefault(leaf.data, []).append(leaf)
    for source_mesh, family in by_mesh.items():
        representative = family[0]
        representative.data = source_mesh.copy()
        modifier = representative.modifiers.new("RuntimeLeafReduction", "DECIMATE")
        modifier.ratio = 0.16
        modifier.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = representative
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        runtime_mesh = representative.data
        for leaf in family[1:]:
            leaf.data = runtime_mesh


def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    mesh_objects = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    leaves = [obj for obj in mesh_objects if obj.name.startswith("GravityBough_SocketLeaf_")]
    transfer_nodes = [obj for obj in mesh_objects if obj.name.startswith("Biofiber_LeafTransferNode_")]
    pulses = [obj for obj in mesh_objects if obj.name.startswith("Biofiber_MainFlowPulse_")]
    twig_streaks = [obj for obj in mesh_objects if obj.name.startswith("Biofiber_LeafTwig_")]
    lateral_streaks = [obj for obj in mesh_objects if obj.name.startswith("Biofiber_Lateral_")]
    lateral_sap_streaks = [
        obj for obj in mesh_objects if obj.name.startswith("GravityBough_LateralSap_")
    ]
    for obsolete_effect in pulses + twig_streaks + lateral_streaks + lateral_sap_streaks:
        bpy.data.objects.remove(obsolete_effect, do_unlink=True)

    retained = set(leaves + transfer_nodes)
    remainder = [
        obj for obj in mesh_objects
        if obj not in retained
        and obj not in pulses
        and obj not in twig_streaks
        and obj not in lateral_streaks
        and obj not in lateral_sap_streaks
    ]
    flow = [obj for obj in remainder if obj.name.startswith("Biofiber_") or "CyanSap" in obj.name or "LateralSap" in obj.name]
    structure = [obj for obj in remainder if obj not in flow]

    decimate_shared_leaf_families(leaves)
    structure_mesh = join_objects(structure, "GravityBough_CombinedStructure")
    flow_mesh = join_objects(flow, "Biofiber_CombinedFlow")

    # The joined meshes are repeated hundreds of times, so reduce internal
    # tessellation while preserving the authored branch silhouette.
    for obj, ratio in ((structure_mesh, 0.42), (flow_mesh, 0.55)):
        modifier = obj.modifiers.new("RuntimeStructureReduction", "DECIMATE")
        modifier.ratio = ratio
        modifier.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)

    export_objects = [structure_mesh, flow_mesh] + leaves + transfer_nodes
    for obj in export_objects:
        obj.hide_render = False
        obj.hide_viewport = False

    OUTPUT_BLEND.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_GLB.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in export_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = structure_mesh
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT_GLB),
        export_format="GLB",
        use_selection=True,
        export_materials="EXPORT",
        export_yup=True,
    )
    print(
        "RUNTIME_BOUGH: structure=1 flow=1 leaves=%d transfer_nodes=%d output=%s"
        % (len(leaves), len(transfer_nodes), OUTPUT_GLB)
    )


if __name__ == "__main__":
    main()
