"""Render isometric, front, and top verification views of the game GLB."""

import math
import os

import bpy
from mathutils import Vector


PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GLB_PATH = os.path.join(PROJECT_ROOT, "assets3D", "tree_of_life", "glb", "artea_tree_of_life.glb")
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "artifacts", "tree_of_life_blender")
os.makedirs(OUTPUT_DIR, exist_ok=True)


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()


def material(name, color, metallic=0.0, roughness=0.8):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def add_environment():
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.film_transparent = False
    scene.view_settings.exposure = 0.28
    if scene.world is None:
        scene.world = bpy.data.worlds.new("ArteaTreeVerificationWorld")
    scene.world.color = (0.004, 0.008, 0.025)
    world = scene.world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.003, 0.008, 0.025, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.30

    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=40.0, depth=0.55, location=(0, 0, -0.32))
    floor = bpy.context.active_object
    floor.name = "VerificationCourt"
    floor.data.materials.append(material("MAT_VerificationCourt", (0.055, 0.07, 0.12), 0.28, 0.72))
    bpy.ops.mesh.primitive_torus_add(major_radius=27.0, minor_radius=0.16, major_segments=96,
                                    minor_segments=8, location=(0, 0, 0.03))
    ring = bpy.context.active_object
    ring.data.materials.append(material("MAT_VerificationRing", (0.04, 0.62, 0.82), 0.42, 0.25))

    for name, location, energy, color, size in (
        ("Key", (32, -38, 58), 3400, (0.78, 0.90, 1.0), 32),
        ("WarmFill", (-34, -24, 35), 2400, (1.0, 0.60, 0.30), 28),
        ("CanopyRim", (0, 35, 54), 3000, (0.25, 0.72, 1.0), 26),
    ):
        bpy.ops.object.light_add(type='AREA', location=location)
        light = bpy.context.active_object
        light.name = name
        light.data.energy = energy
        light.data.color = color
        light.data.shape = 'DISK'
        light.data.size = size
        look_at(light, (0, 0, 24))

    # Sun lights do not fall off with the landmark's large scale, so the bark
    # and green foliage remain readable while cyan emissive circuits still pop.
    for name, location, energy, color in (
        ("CoolSun", (45, -60, 80), 1.5, (0.72, 0.86, 1.0)),
        ("WarmSun", (-55, -25, 45), 0.85, (1.0, 0.66, 0.34)),
    ):
        bpy.ops.object.light_add(type='SUN', location=location)
        sun = bpy.context.active_object
        sun.name = name
        sun.data.energy = energy
        sun.data.color = color
        sun.data.angle = math.radians(18.0)
        look_at(sun, (0, 0, 22))

    bpy.ops.object.camera_add()
    camera = bpy.context.active_object
    camera.name = "VerificationCamera"
    camera.data.lens = 56
    camera.data.sensor_width = 36
    scene.camera = camera
    return camera


def render_view(camera, name, location, target, lens=56, ortho_scale=None):
    camera.location = location
    camera.data.lens = lens
    if ortho_scale is None:
        camera.data.type = 'PERSP'
    else:
        camera.data.type = 'ORTHO'
        camera.data.ortho_scale = ortho_scale
    look_at(camera, target)
    bpy.context.scene.render.filepath = os.path.join(OUTPUT_DIR, f"{name}.png")
    bpy.ops.render.render(write_still=True)
    print(f"TREE_OF_LIFE_RENDER: wrote {bpy.context.scene.render.filepath}")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB_PATH)
    camera = add_environment()
    render_view(camera, "isometric", (78, -102, 66), (0, 0, 25), lens=58)
    render_view(camera, "front", (0, -128, 30), (0, 0, 26), lens=62)
    render_view(camera, "top", (0, 0, 120), (0, 0, 20), ortho_scale=86)
    render_view(camera, "leaf_system_closeup", (43, -58, 41), (17, -20, 34), lens=68)
    print("TREE_OF_LIFE_RENDER: PASS")


if __name__ == "__main__":
    main()
