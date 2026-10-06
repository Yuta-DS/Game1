"""Build the Artéa castle rooftop parapet as a Blender-authored module.

The GLB is visual-only in Godot. The existing procedural wall body remains the
authoritative collision so bevels, mortar joints, and quoins cannot snag the
player. Run with:

    blender --background --python tools/blender/build_castle_rooftop_parapet.py
"""

from __future__ import annotations

import json
import math
import os

import bpy
from mathutils import Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSET_DIR = os.path.join(ROOT, "assets3D", "castle_rooftop_parapet")
BLEND_PATH = os.path.join(ASSET_DIR, "blend", "castle_rooftop_parapet.blend")
GLB_PATH = os.path.join(ASSET_DIR, "glb", "castle_rooftop_parapet.glb")
MANIFEST_PATH = os.path.join(ASSET_DIR, "castle_rooftop_parapet_manifest.json")
RENDER_PATH = os.path.join(ROOT, "artifacts", "castle_rooftop_parapet_blender.png")

PANEL_LENGTH = 6.236
PANEL_DEPTH = 0.64
PANEL_HEIGHT = 1.18
BEVEL = 0.025

PALETTE = {
    "limestone": (0.60, 0.69, 0.73, 1.0),
    "limestone_light": (0.76, 0.82, 0.83, 1.0),
    "limestone_mid": (0.52, 0.61, 0.66, 1.0),
    "mortar": (0.39, 0.48, 0.54, 1.0),
}


def material(name, colour, roughness=0.82):
    result = bpy.data.materials.new(name)
    result.diffuse_color = colour
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = colour
    shader.inputs["Roughness"].default_value = roughness
    return result


def box(name, location, dimensions, mat, bevel=BEVEL):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel > 0.0:
        modifier = obj.modifiers.new("StoneEdge", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
    obj["visual_only"] = True
    obj["collision_policy"] = "godot_procedural_shell"
    return obj


def join_named(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    result = bpy.context.object
    result.name = name
    result["visual_only"] = True
    result["collision_policy"] = "godot_procedural_shell"
    return result


def build_panel(mats):
    core = box(
        "ParapetMortarCore",
        (0.0, 0.0, 0.53),
        (PANEL_LENGTH, PANEL_DEPTH - 0.10, 0.90),
        mats["mortar"],
        0.035,
    )
    base = box(
        "ParapetBrickMidBaseCourse",
        (0.0, 0.0, 0.105),
        (PANEL_LENGTH + 0.10, PANEL_DEPTH + 0.05, 0.21),
        mats["limestone_mid"],
        0.035,
    )

    bricks = []
    rows = 4
    row_height = 0.19
    gap_x = 0.045
    gap_z = 0.045
    face_y = PANEL_DEPTH * 0.5 - 0.01
    for face in (-1.0, 1.0):
        for row in range(rows):
            count = 5 if row % 2 == 0 else 6
            brick_width = (PANEL_LENGTH - gap_x * (count + 1)) / count
            start = -PANEL_LENGTH * 0.5 + gap_x + brick_width * 0.5
            z = 0.27 + row * (row_height + gap_z)
            for column in range(count):
                colour_key = "limestone_light" if (row + column) % 4 == 0 else "limestone"
                brick = box(
                    f"ParapetBrickLight_{'Front' if face > 0 else 'Rear'}_{row}_{column}",
                    (start + column * (brick_width + gap_x), face * face_y, z),
                    (brick_width, 0.11, row_height),
                    mats[colour_key],
                    0.018,
                )
                bricks.append(brick)

    quoins = []
    for side in (-1.0, 1.0):
        for level in range(3):
            z = 0.31 + level * 0.28
            depth = PANEL_DEPTH + (0.10 if level % 2 == 0 else 0.03)
            quoin = box(
                f"ParapetBrickMidQuoin_{'L' if side < 0 else 'R'}_{level}",
                (side * (PANEL_LENGTH * 0.5 - 0.16), 0.0, z),
                (0.34, depth, 0.25),
                mats["limestone_mid" if level % 2 else "limestone_light"],
                0.022,
            )
            quoins.append(quoin)

    capstones = []
    cap_count = 5
    cap_gap = 0.035
    cap_width = (PANEL_LENGTH + 0.18 - cap_gap * (cap_count - 1)) / cap_count
    for index in range(cap_count):
        x = -(PANEL_LENGTH + 0.18) * 0.5 + cap_width * 0.5 + index * (cap_width + cap_gap)
        capstones.append(
            box(
                f"ParapetContinuousCap_{index}",
                (x, 0.0, 1.08),
                (cap_width, PANEL_DEPTH + 0.18, 0.20),
                mats["limestone_light"],
                0.045,
            )
        )

    join_named([core, base], "ParapetMasonryBody")
    join_named(bricks + quoins, "ParapetBrickLightAshlarFacing")
    join_named(capstones, "ParapetCopingStones")


def configure_render():
    world = bpy.data.worlds.new("CastlePreviewWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (
        0.32, 0.46, 0.58, 1.0
    )
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.45

    bpy.ops.object.light_add(type="AREA", location=(2.5, -4.0, 5.0))
    key = bpy.context.object
    key.name = "PreviewKey"
    key.data.energy = 900.0
    key.data.shape = "DISK"
    key.data.size = 5.0
    key.rotation_euler = (math.radians(28), 0.0, math.radians(25))

    bpy.ops.object.light_add(type="AREA", location=(-3.5, 2.0, 2.8))
    fill = bpy.context.object
    fill.name = "PreviewFill"
    fill.data.energy = 500.0
    fill.data.size = 4.0

    bpy.ops.object.camera_add(location=(7.2, -8.0, 4.1))
    camera = bpy.context.object
    camera.name = "PreviewCamera"
    direction = Vector((0.0, 0.0, 0.62)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = 58
    bpy.context.scene.camera = camera

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = RENDER_PATH


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(os.path.dirname(BLEND_PATH), exist_ok=True)
    os.makedirs(os.path.dirname(GLB_PATH), exist_ok=True)
    os.makedirs(os.path.dirname(RENDER_PATH), exist_ok=True)

    mats = {name: material(f"Artea_{name}", colour) for name, colour in PALETTE.items()}
    build_panel(mats)
    configure_render()

    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    bpy.ops.object.select_all(action="DESELECT")
    runtime_meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    for obj in runtime_meshes:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
    )
    bpy.ops.render.render(write_still=True)

    triangles = sum(
        len(poly.vertices) - 2
        for obj in runtime_meshes
        for poly in obj.data.polygons
    )
    manifest = {
        "asset": "castle_rooftop_parapet",
        "source_blend": os.path.relpath(BLEND_PATH, ROOT),
        "runtime_glb": os.path.relpath(GLB_PATH, ROOT),
        "panel_length_m": PANEL_LENGTH,
        "panel_depth_m": PANEL_DEPTH,
        "panel_height_m": PANEL_HEIGHT,
        "runtime_mesh_groups": len(runtime_meshes),
        "triangle_count": triangles,
        "collision_policy": "visual_only_over_procedural_godot_wall",
        "web_profile": "low_poly_modular",
    }
    with open(MANIFEST_PATH, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
    print(f"CASTLE_ROOFTOP_PARAPET: wrote {BLEND_PATH}")
    print(f"CASTLE_ROOFTOP_PARAPET: wrote {GLB_PATH}")
    print(f"CASTLE_ROOFTOP_PARAPET: triangles={triangles}")


if __name__ == "__main__":
    main()
