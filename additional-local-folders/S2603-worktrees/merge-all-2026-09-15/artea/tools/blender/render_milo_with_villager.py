"""Render the exact production Milo and market-villager game models together."""

from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "artifacts" / "milo_with_real_villager.png"


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def position_character(imported, name, x_position):
    """Place both production GLBs at their native in-game scale."""
    root = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(root)
    top_level = [obj for obj in imported if obj.parent not in imported]
    for obj in top_level:
        obj.parent = root

    meshes = [obj for obj in imported if obj.type == "MESH"]
    bpy.context.view_layer.update()
    corners = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    low = Vector((min(p.x for p in corners), min(p.y for p in corners), min(p.z for p in corners)))
    high = Vector((max(p.x for p in corners), max(p.y for p in corners), max(p.z for p in corners)))
    root.location = (
        x_position - (low.x + high.x) * 0.5,
        -(low.y + high.y) * 0.5,
        -low.z,
    )
    return root


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(
    filepath=str(ROOT / "assets3D/characters/milo_villager_lowpoly.glb")
)
milo_objects = list(bpy.context.scene.objects)
position_character(
    milo_objects,
    "Mayor Milo",
    -0.82,
)
before = set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets3D/characters/Barbarian.glb"))
villager_objects = [obj for obj in bpy.context.scene.objects if obj not in before]
position_character(
    villager_objects,
    "Market Villager",
    0.82,
)

bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.015))
ground = bpy.context.object
ground_material = bpy.data.materials.new("Artea Grass")
ground_material.diffuse_color = (0.11, 0.32, 0.09, 1)
ground.data.materials.append(ground_material)

bpy.ops.object.camera_add(location=(0, -15.0, 3.1))
camera = bpy.context.object
camera.data.lens = 62
look_at(camera, (0, 0, 1.45))
bpy.context.scene.camera = camera

for location, energy, size, color in (
    ((-3.5, -4.0, 6.0), 950, 4.0, (1.0, 0.83, 0.68)),
    ((4.0, -2.5, 3.6), 540, 3.0, (0.45, 0.72, 1.0)),
):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.data.energy = energy
    light.data.size = size
    light.data.color = color
    look_at(light, (0, 0, 0.9))

world = bpy.context.scene.world or bpy.data.worlds.new("World")
bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.18, 0.46, 0.68, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.65

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUTPUT)
scene.view_settings.look = "AgX - Medium High Contrast"
scene.render.film_transparent = False
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.render.render(write_still=True)
print(f"MILO_VILLAGER_RENDER: wrote {OUTPUT}")
