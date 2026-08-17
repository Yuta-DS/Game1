"""Build a standalone, branch-free mixed leaf-growth crown for approval."""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


PROJECT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_crystal_branch_canopy as canopy

ROOT = PROJECT / "assets3D/tree_of_life/leaf_growth_crown"
BLEND_PATH = ROOT / "source/mixed_leaf_growth_crown.blend"
GLB_PATH = ROOT / "glb/mixed_leaf_growth_crown.glb"
MANIFEST_PATH = ROOT / "mixed_leaf_growth_crown_manifest.json"
TOP_PATH = PROJECT / "artifacts/tree_of_life_leaf_growth/mixed_leaf_growth_top.png"
FRONT_PATH = PROJECT / "artifacts/tree_of_life_leaf_growth/mixed_leaf_growth_front.png"


def leaf_width(t: float, width: float) -> float:
    body = math.sin(math.pi * min(1.0, max(0.0, t))) ** 0.70
    taper_bias = 0.74 + 0.35 * t
    serration = 1.0 + 0.12 * math.sin(t * math.tau * 5.5)
    return width * body * taper_bias * serration


def make_leaf_blade(name: str, length: float, width: float, mat,
        collection) -> bpy.types.Object:
    segments = 18
    vertices = []
    for index in range(segments + 1):
        t = index / segments
        half_width = leaf_width(t, width) * 0.5
        center_z = 0.18 * math.sin(math.pi * t) + 0.34 * t * t
        for lateral in (-1.0, 0.0, 1.0):
            edge_cup = (1.0 - abs(lateral)) * 0.20 * math.sin(math.pi * t)
            vertices.append((length * t, half_width * lateral, center_z + edge_cup))
    faces = []
    for index in range(segments):
        start = index * 3
        following = (index + 1) * 3
        faces.append((start, following, following + 1, start + 1))
        faces.append((start + 1, following + 1, following + 2, start + 2))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    solidify = obj.modifiers.new("LeafThickness", "SOLIDIFY")
    solidify.thickness = 0.105
    solidify.offset = -0.32
    bevel = obj.modifiers.new("LeafSoftEdge", "BEVEL")
    bevel.width = 0.055
    bevel.segments = 2
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.shade_smooth()
    bpy.ops.object.modifier_apply(modifier=solidify.name)
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.select_set(False)
    return obj


def transformed_points(obj: bpy.types.Object, points) -> tuple[tuple[float, float, float], ...]:
    bpy.context.view_layer.update()
    return tuple(tuple(obj.matrix_world @ Vector(point)) for point in points)


def add_leaf_veins(obj: bpy.types.Object, length: float, width: float,
        cyan, rim, collection, export_objects: list) -> tuple[int, int]:
    midrib_local = []
    for step in range(9):
        t = 0.04 + 0.90 * step / 8.0
        midrib_local.append((length * t, 0.0,
            0.24 + 0.18 * math.sin(math.pi * t) + 0.34 * t * t))
    midrib = canopy.make_tube(f"{obj.name}_CyanMidrib", transformed_points(obj, midrib_local),
        tuple(0.072 - 0.032 * step / 8.0 for step in range(9)), 6, cyan, collection)
    export_objects.append(midrib)
    vein_count = 1
    for vein_index, t in enumerate((0.28, 0.43, 0.58, 0.72, 0.84)):
        half_width = leaf_width(t, width) * 0.5
        start = Vector((length * (t - 0.055), 0.0,
            0.245 + 0.18 * math.sin(math.pi * t) + 0.34 * t * t))
        for side in (-1.0, 1.0):
            end_t = min(0.97, t + 0.10)
            end_half_width = leaf_width(end_t, width) * 0.5
            end = Vector((length * end_t, side * end_half_width * 0.82,
                0.18 + 0.14 * math.sin(math.pi * end_t) + 0.34 * end_t * end_t))
            middle = start.lerp(end, 0.55) + Vector((0.12, 0.0, 0.06))
            vein = canopy.make_tube(
                f"{obj.name}_CyanSideVein_{vein_index:02d}_{'L' if side < 0 else 'R'}",
                transformed_points(obj, (tuple(start), tuple(middle), tuple(end))),
                (0.036, 0.027, 0.014), 5, cyan, collection)
            export_objects.append(vein)
            vein_count += 1

    edge_segments = 16
    edge_count = 0
    for side, label in ((-1.0, "Left"), (1.0, "Right")):
        outline = []
        for step in range(edge_segments + 1):
            t = 0.015 + 0.97 * step / edge_segments
            outline.append((length * t, side * leaf_width(t, width) * 0.5,
                0.10 + 0.18 * math.sin(math.pi * t) + 0.34 * t * t))
        edge = canopy.make_tube(f"{obj.name}_LivingRim_{label}", transformed_points(obj, outline),
            tuple(0.032 for _ in outline), 5, rim, collection)
        export_objects.append(edge)
        edge_count += 1
    return vein_count, edge_count


def add_camera(name: str, location, target, ortho_scale: float) -> bpy.types.Object:
    data = bpy.data.cameras.new(name)
    data.type = "ORTHO"
    data.ortho_scale = ortho_scale
    camera = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(camera)
    camera.location = location
    camera.rotation_euler = ((Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler())
    return camera


def main() -> None:
    canopy.clear_scene()
    leaf_collection = bpy.data.collections.new("EditableLeafGrowthBlades")
    vein_collection = bpy.data.collections.new("RaisedLeafGrowthVeins")
    bpy.context.scene.collection.children.link(leaf_collection)
    bpy.context.scene.collection.children.link(vein_collection)

    materials = (
        canopy.material("MAT_GrowthLivingGreen", (0.26, 0.43, 0.095, 1), 0.06, 0.46,
            (0.055, 0.12, 0.012), 0.25),
        canopy.material("MAT_GrowthMagicViolet", (0.37, 0.16, 0.64, 1), 0.12, 0.32,
            (0.24, 0.06, 0.55), 0.55),
        canopy.material("MAT_GrowthSolarGlass", (0.055, 0.33, 0.54, 1), 0.20, 0.18,
            (0.04, 0.52, 0.78), 0.70),
        canopy.material("MAT_GrowthEmerald", (0.02, 0.36, 0.23, 1), 0.14, 0.28,
            (0.015, 0.40, 0.30), 0.55),
    )
    cyan = canopy.material("MAT_GrowthCyanVeins", (0.01, 0.35, 0.46, 1), 0.10, 0.20,
        (0.03, 0.72, 0.92), 3.2)
    rim = canopy.material("MAT_GrowthGoldenLivingRim", (0.52, 0.46, 0.12, 1), 0.58, 0.30,
        (0.16, 0.11, 0.012), 0.32)
    core_mat = canopy.material("MAT_ConcealedGrowthCore", (0.025, 0.075, 0.028, 1), 0.08, 0.70)

    export_objects = []
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=2.7,
        location=(0, 0, 0.15), scale=(1.35, 1.0, 0.25))
    core = bpy.context.object
    core.name = "ConcealedLeafGrowthCore"
    core.data.materials.append(core_mat)
    for owner in list(core.users_collection):
        owner.objects.unlink(core)
    leaf_collection.objects.link(core)
    export_objects.append(core)

    family_pattern = (0, 2, 0, 1, 3, 0, 1, 2, 0, 3, 1)
    fan_origins = ((-1.25, 0.65), (0.75, 1.00), (-0.65, -1.05), (1.30, -0.60))
    fan_directions = (155.0, 48.0, 218.0, -28.0)
    blade_count = 0
    vein_count = 0
    rim_count = 0
    family_counts = [0, 0, 0, 0]
    for fan_index, ((origin_x, origin_y), direction_degrees) in enumerate(
            zip(fan_origins, fan_directions)):
        blades_in_fan = 11
        for local_index in range(blades_in_fan):
            spread = (local_index / (blades_in_fan - 1) - 0.5) * 118.0
            angle_degrees = direction_degrees + spread
            angle = math.radians(angle_degrees)
            family = family_pattern[(fan_index * 3 + local_index) % len(family_pattern)]
            length = 7.0 + 1.65 * math.sin(local_index * 1.31 + fan_index * 0.7) ** 2
            width = 3.3 + 0.80 * math.cos(local_index * 1.17 + fan_index) ** 2
            blade = make_leaf_blade(f"GrowthBlade_{blade_count:03d}_Family_{family}",
                length, width, materials[family], leaf_collection)
            blade.location = (origin_x + math.cos(angle) * (0.22 + 0.12 * (local_index % 3)),
                origin_y + math.sin(angle) * (0.22 + 0.12 * (local_index % 3)),
                0.72 + fan_index * 0.24 + 0.18 * (local_index % 4))
            blade.rotation_euler = (
                math.radians(-7.0 + 3.0 * math.sin(local_index)),
                math.radians(-10.0 + 7.0 * math.cos(local_index * 0.9)),
                angle,
            )
            export_objects.append(blade)
            added_veins, added_rims = add_leaf_veins(
                blade, length, width, cyan, rim, vein_collection, export_objects)
            vein_count += added_veins
            rim_count += added_rims
            family_counts[family] += 1
            blade_count += 1

    world = bpy.context.scene.world or bpy.data.worlds.new("LeafGrowthWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.0015, 0.008, 0.022, 1.0)
    background.inputs["Strength"].default_value = 0.58
    key_data = bpy.data.lights.new("LeafGrowthKey", "AREA")
    key_data.energy = 3200
    key_data.size = 22
    key = bpy.data.objects.new("LeafGrowthKey", key_data)
    bpy.context.scene.collection.objects.link(key)
    key.location = (-15, -16, 28)
    fill_data = bpy.data.lights.new("LeafGrowthFill", "AREA")
    fill_data.energy = 2200
    fill_data.color = (0.16, 0.58, 1.0)
    fill_data.size = 18
    fill = bpy.data.objects.new("LeafGrowthFill", fill_data)
    bpy.context.scene.collection.objects.link(fill)
    fill.location = (18, 8, 22)

    top_camera = add_camera("LeafGrowthTopCamera", (0, 0, 42), (0, 0, 1.5), 31.0)
    front_camera = add_camera("LeafGrowthFrontCamera", (0, -34, 19), (0, 0, 2.0), 31.0)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 850
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    for path in (BLEND_PATH.parent, GLB_PATH.parent, TOP_PATH.parent):
        path.mkdir(parents=True, exist_ok=True)
    scene["asset_name"] = "Mixed Four-Family Leaf Growth Crown"
    scene["design_role"] = "standalone branch-free foliage growth approval module"
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in export_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = export_objects[0]
    bpy.ops.export_scene.gltf(filepath=str(GLB_PATH), export_format="GLB",
        use_selection=True, export_materials="EXPORT", export_yup=True)

    scene.camera = top_camera
    scene.render.filepath = str(TOP_PATH)
    bpy.ops.render.render(write_still=True)
    scene.camera = front_camera
    scene.render.filepath = str(FRONT_PATH)
    bpy.ops.render.render(write_still=True)

    manifest = {
        "asset": "mixed_leaf_growth_crown",
        "branch_free": True,
        "concealed_growth_core": True,
        "editable_leaf_blades": blade_count,
        "raised_cyan_vein_components": vein_count,
        "living_rim_components": rim_count,
        "leaf_family_counts": {
            "living_green": family_counts[0],
            "magic_violet": family_counts[1],
            "solar_glass": family_counts[2],
            "emerald_sensor": family_counts[3],
        },
        "source_blend": str(BLEND_PATH.relative_to(PROJECT)),
        "game_glb": str(GLB_PATH.relative_to(PROJECT)),
        "top_preview": str(TOP_PATH.relative_to(PROJECT)),
        "front_preview": str(FRONT_PATH.relative_to(PROJECT)),
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
