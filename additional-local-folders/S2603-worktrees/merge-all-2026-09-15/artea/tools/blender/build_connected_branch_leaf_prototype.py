"""Build an isolated, editable Tree-of-Life branch and leaf prototype.

This approval asset deliberately stays separate from the production tree.  It
proves the hierarchy main limb -> secondary bough -> tertiary twig -> leaf base
before the system is repeated across the complete canopy.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


PROJECT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_crystal_branch_canopy as canopy

ROOT = PROJECT / "assets3D/tree_of_life/branch_leaf_prototype"
BLEND_PATH = ROOT / "source/connected_branch_leaf_prototype.blend"
GLB_PATH = ROOT / "glb/connected_branch_leaf_prototype.glb"
MANIFEST_PATH = ROOT / "connected_branch_leaf_prototype_manifest.json"
FRONT_PATH = PROJECT / "artifacts/tree_of_life_branch_leaf/branch_leaf_front.png"
SIDE_PATH = PROJECT / "artifacts/tree_of_life_branch_leaf/branch_leaf_side.png"


def quadratic_point(path, t: float) -> tuple[Vector, Vector]:
    start, middle, end = (Vector(point) for point in path)
    remaining = 1.0 - t
    position = start * remaining * remaining
    position += middle * 2.0 * remaining * t + end * t * t
    tangent = (middle - start) * 2.0 * remaining + (end - middle) * 2.0 * t
    return position, tangent


def build_paths():
    main = (
        (-17.0, 0.0, 0.0), (-11.0, 0.2, 0.8), (-4.0, -0.4, 1.9),
        (4.0, 0.5, 3.2), (13.0, -0.3, 4.6), (22.0, 0.2, 5.8),
    )
    secondary = []
    for joint_index in range(1, 5):
        source = Vector(main[joint_index])
        for side in (-1.0, 1.0):
            reach = 7.8 + joint_index * 0.65
            secondary.append((
                tuple(source),
                (source.x + 2.6, side * (3.8 + joint_index * 0.4), source.z + 1.9),
                (source.x + 5.6, side * reach, source.z + 3.6 + 0.3 * joint_index),
            ))
    tertiary = []
    parent_for_tertiary = []
    for secondary_index, path in enumerate(secondary):
        side = 1.0 if path[-1][1] >= 0.0 else -1.0
        for branch_offset, source_index in enumerate((1, 2)):
            source = Vector(path[source_index])
            direction = Vector((1.0, side * (0.72 + branch_offset * 0.16), 0.36)).normalized()
            middle = source + direction * (2.5 + 0.35 * branch_offset)
            middle.z += 0.45
            end = source + direction * (5.0 + 0.65 * branch_offset)
            end.z += 0.25 + 0.45 * math.sin(secondary_index * 1.3)
            tertiary.append((tuple(source), tuple(middle), tuple(end)))
            parent_for_tertiary.append(secondary_index)
    return main, secondary, tertiary, parent_for_tertiary


def add_preview_camera(name: str, location, target) -> bpy.types.Object:
    camera_data = bpy.data.cameras.new(name)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 48.0
    camera = bpy.data.objects.new(name, camera_data)
    bpy.context.scene.collection.objects.link(camera)
    camera.location = location
    camera.rotation_euler = ((Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler())
    return camera


def main() -> None:
    canopy.clear_scene()
    branch_collection = bpy.data.collections.new("ConnectedBranchHierarchy")
    leaf_collection = bpy.data.collections.new("OrderedAttachedLeaves")
    bpy.context.scene.collection.children.link(branch_collection)
    bpy.context.scene.collection.children.link(leaf_collection)

    wood = canopy.material("MAT_PrototypeLivingWood", (0.24, 0.078, 0.020, 1), 0.16, 0.42,
        (0.09, 0.018, 0.003), 0.12)
    wood_mid = canopy.material("MAT_PrototypeTwigWood", (0.30, 0.105, 0.028, 1), 0.12, 0.48,
        (0.11, 0.025, 0.004), 0.10)
    cyan = canopy.material("MAT_PrototypeCyanSap", (0.01, 0.27, 0.38, 1), 0.12, 0.20,
        (0.04, 0.82, 1.0), 5.0)
    brass = canopy.material("MAT_PrototypeBrassJoint", (0.66, 0.30, 0.055, 1), 0.82, 0.22)
    export_objects = []
    main_path, secondary_paths, tertiary_paths, _parents = build_paths()

    main_radii = (1.65, 1.48, 1.28, 1.03, 0.78, 0.48)
    main_branch = canopy.make_tube("PrototypeMainPoweredLimb", main_path, main_radii, 12,
        wood, branch_collection)
    export_objects.append(main_branch)
    main_channel_path = tuple((x, y, z + main_radii[index] * 0.78)
        for index, (x, y, z) in enumerate(main_path))
    export_objects.append(canopy.make_tube("PrototypeMainCyanSapChannel", main_channel_path,
        tuple(radius * 0.105 for radius in main_radii), 7, cyan, branch_collection))
    main_vectors = [Vector(point) for point in main_path]
    for joint_index in range(1, len(main_path) - 1):
        tangent = main_vectors[joint_index + 1] - main_vectors[joint_index - 1]
        export_objects.append(canopy.add_collar(
            f"PrototypeMainArticulation_{joint_index:02d}", main_path[joint_index], tangent,
            main_radii[joint_index] * 1.08, brass, branch_collection))

    for index, path in enumerate(secondary_paths):
        radii = (0.82, 0.48, 0.22)
        export_objects.append(canopy.make_tube(
            f"PrototypeSecondaryBough_{index:02d}", path, radii, 9, wood_mid, branch_collection))
        channel_path = tuple((x, y, z + radii[point_index] * 0.72)
            for point_index, (x, y, z) in enumerate(path))
        export_objects.append(canopy.make_tube(
            f"PrototypeSecondaryCyanSap_{index:02d}", channel_path,
            (0.065, 0.045, 0.020), 6, cyan, branch_collection))
        tangent = Vector(path[1]) - Vector(path[0])
        export_objects.append(canopy.add_collar(
            f"PrototypeSecondaryJoint_{index:02d}", path[0], tangent,
            radii[0] * 1.06, brass, branch_collection))

    for index, path in enumerate(tertiary_paths):
        export_objects.append(canopy.make_tube(
            f"PrototypeLeafBearingTwig_{index:02d}", path, (0.30, 0.16, 0.055),
            7, wood_mid, branch_collection))
        if index % 2 == 0:
            channel_path = tuple((x, y, z + (0.18, 0.10, 0.035)[point_index])
                for point_index, (x, y, z) in enumerate(path))
            export_objects.append(canopy.make_tube(
                f"PrototypeTwigCyanSap_{index:02d}", channel_path,
                (0.030, 0.022, 0.012), 5, cyan, branch_collection))

    templates = [canopy.append_leaf_template(source, leaf_collection)
        for source in canopy.LEAF_SOURCES]
    leaf_counts = {source.slug: 0 for source in canopy.LEAF_SOURCES}
    leaf_index = 0
    leaves_per_twig = 8
    for twig_index, path in enumerate(tertiary_paths):
        for rank in range(leaves_per_twig):
            t = 0.28 + 0.68 * (rank + 0.5) / leaves_per_twig
            position, tangent = quadratic_point(path, t)
            lateral = Vector((-tangent.y, tangent.x, 0.0)).normalized()
            position += lateral * (-0.22 if rank % 2 == 0 else 0.22)
            position.z += 0.12 * math.sin(rank * 1.7 + twig_index)
            family = canopy.LEAF_FAMILY_PATTERN[leaf_index % len(canopy.LEAF_FAMILY_PATTERN)]
            template = templates[family]
            leaf = template.copy()
            leaf.data = template.data
            leaf.hide_render = False
            leaf.hide_viewport = False
            leaf.name = f"PrototypeAttachedLeaf_{canopy.LEAF_SOURCES[family].slug}_{leaf_index:03d}"
            leaf.location = tuple(position)
            rotation_z = math.degrees(math.atan2(tangent.y, tangent.x)) + 90.0
            rotation_z += -10.0 if rank % 2 == 0 else 10.0
            leaf.rotation_euler = tuple(math.radians(value) for value in
                (38.0 + 13.0 * t, (rank % 3 - 1) * 6.0, rotation_z))
            family_scale = (0.40, 0.37, 0.36, 0.29)[family]
            leaf.scale = Vector((family_scale,) * 3)
            leaf_collection.objects.link(leaf)
            export_objects.append(leaf)
            leaf_counts[canopy.LEAF_SOURCES[family].slug] += 1
            leaf_index += 1
    for template in templates:
        bpy.data.objects.remove(template, do_unlink=True)

    world = bpy.context.scene.world or bpy.data.worlds.new("BranchLeafPrototypeWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.002, 0.010, 0.025, 1.0)
    background.inputs["Strength"].default_value = 0.72
    key_data = bpy.data.lights.new("PrototypeKey", "AREA")
    key_data.energy = 2900
    key_data.size = 22
    key = bpy.data.objects.new("PrototypeKey", key_data)
    bpy.context.scene.collection.objects.link(key)
    key.location = (-8, -22, 32)
    fill_data = bpy.data.lights.new("PrototypeFill", "AREA")
    fill_data.energy = 1700
    fill_data.color = (0.20, 0.62, 1.0)
    fill_data.size = 18
    fill = bpy.data.objects.new("PrototypeFill", fill_data)
    bpy.context.scene.collection.objects.link(fill)
    fill.location = (24, 14, 25)

    front_camera = add_preview_camera("BranchLeafFrontCamera", (3, -48, 46), (3, 0, 4))
    side_camera = add_preview_camera("BranchLeafSideCamera", (52, 0, 36), (3, 0, 4))
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 700
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"

    for path in (BLEND_PATH.parent, GLB_PATH.parent, FRONT_PATH.parent):
        path.mkdir(parents=True, exist_ok=True)
    scene["asset_name"] = "Connected Branch and Four-Family Leaf Prototype"
    scene["attachment_hierarchy"] = "main_limb/secondary_bough/tertiary_twig/leaf_base"
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in export_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = export_objects[0]
    bpy.ops.export_scene.gltf(filepath=str(GLB_PATH), export_format="GLB",
        use_selection=True, export_materials="EXPORT", export_yup=True)

    scene.camera = front_camera
    scene.render.filepath = str(FRONT_PATH)
    bpy.ops.render.render(write_still=True)
    scene.camera = side_camera
    scene.render.filepath = str(SIDE_PATH)
    bpy.ops.render.render(write_still=True)

    manifest = {
        "asset": "connected_branch_leaf_prototype",
        "main_limbs": 1,
        "secondary_boughs": len(secondary_paths),
        "tertiary_leaf_twigs": len(tertiary_paths),
        "attached_compound_leaves": leaf_index,
        "leaf_counts": leaf_counts,
        "all_leaves_attached_to_tertiary_twigs": True,
        "source_blend": str(BLEND_PATH.relative_to(PROJECT)),
        "game_glb": str(GLB_PATH.relative_to(PROJECT)),
        "front_preview": str(FRONT_PATH.relative_to(PROJECT)),
        "side_preview": str(SIDE_PATH.relative_to(PROJECT)),
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
