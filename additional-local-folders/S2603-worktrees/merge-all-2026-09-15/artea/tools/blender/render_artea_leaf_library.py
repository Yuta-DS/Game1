"""Render a deterministic inspection board for the standalone leaf library."""

import os

import bpy
from mathutils import Vector


PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLEND_PATH = os.path.join(
    PROJECT_ROOT, "assets3D", "tree_of_life", "leaves", "source", "artea_leaf_library.blend")
OUTPUT_PATH = os.path.join(
    PROJECT_ROOT, "artifacts", "tree_of_life_leaves", "leaf_library_blender.png")


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()


def add_text(text, location, size=0.34, color=(0.95, 0.70, 0.25, 1.0)):
    curve = bpy.data.curves.new(f"Preview_{text}", 'FONT')
    curve.body = text
    curve.align_x = 'CENTER'
    curve.size = size
    curve.extrude = 0.006
    obj = bpy.data.objects.new(f"Preview_{text}", curve)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    material = bpy.data.materials.new(f"PreviewMat_{text}")
    material.diffuse_color = color
    material.use_nodes = True
    material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = color
    material.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = color
    material.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 0.35
    obj.data.materials.append(material)


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND_PATH)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = OUTPUT_PATH
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("Preview_World")
    scene.world.color = (0.002, 0.008, 0.025)

    background_material = bpy.data.materials.new("Preview_Background")
    background_material.diffuse_color = (0.002, 0.012, 0.035, 1)
    background_material.use_nodes = True
    background_bsdf = background_material.node_tree.nodes["Principled BSDF"]
    background_bsdf.inputs["Base Color"].default_value = (0.002, 0.012, 0.035, 1)
    background_bsdf.inputs["Emission Color"].default_value = (0.002, 0.012, 0.035, 1)
    background_bsdf.inputs["Emission Strength"].default_value = 1.0
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, -0.45))
    bpy.context.object.data.materials.append(background_material)

    camera_data = bpy.data.cameras.new("Preview_Camera")
    camera = bpy.data.objects.new("Preview_Camera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = (0, 0, 18)
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = 24.0
    look_at(camera, (0, 0, 0))
    scene.camera = camera

    light_data = bpy.data.lights.new("Preview_Key", 'AREA')
    light_data.energy = 1100
    light_data.shape = 'DISK'
    light_data.size = 8.0
    light = bpy.data.objects.new("Preview_Key", light_data)
    scene.collection.objects.link(light)
    light.location = (0, 0, 9)
    look_at(light, (0, 0, 0))

    add_text("LIVING LEAF FAN", (-4.1, 6.75, 1.1))
    add_text("MAGIC RUNE LEAF", (5.5, 6.75, 1.1))
    add_text("SOLAR-GLASS SCIENCE LEAF", (-2.0, -0.65, 1.1), 0.28)
    add_text("EMERALD SENSOR LEAF", (5.5, -0.65, 1.1), 0.30)
    add_text("FOUR EDITABLE LEAF OBJECTS  |  10K+ VERTICES EACH", (0, -7.0, 1.1), 0.27,
             (0.10, 0.82, 1.0, 1.0))

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    bpy.ops.render.render(write_still=True)
    print(f"ARTEA_LEAF_LIBRARY_RENDER: PASS — {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
