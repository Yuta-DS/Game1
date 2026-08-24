"""Replace the engine roof halo with an animated celestial crown mechanism."""

import math
import os

import bpy
from mathutils import Vector


PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND_PATH = os.path.join(
    PROJECT_DIR, "assets3D", "crown_line_train", "crown_line_lego_train.blend"
)
RENDER_PATH = os.path.join(
    PROJECT_DIR, "artifacts", "blender_crown_train_celestial_halo.png"
)
ENGINE_PARENT = "TRAIN_Engine_Assembly"
HALO_Y = -16.0


def finish(obj, name, material, parent):
    obj.name = "TRAIN_" + name
    if obj.data is not None:
        obj.data.name = obj.name + "_Mesh"
        obj.data.materials.clear()
        obj.data.materials.append(material)
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world
    return obj


def torus(name, location, major_radius, minor_radius, material, parent):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=64,
        minor_segments=10,
        location=location,
    )
    return finish(bpy.context.object, name, material, parent)


def beam(name, start, end, radius, material, parent):
    start = Vector(start)
    end = Vector(end)
    direction = end - start
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=10,
        radius=radius,
        depth=direction.length,
        location=(start + end) * .5,
    )
    obj = bpy.context.object
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return finish(obj, name, material, parent)


def sphere(name, location, radius, material, parent):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=radius, location=location)
    return finish(bpy.context.object, name, material, parent)


def crystal(name, location, radius, height, material, parent):
    """A compact faceted bipyramid that reads as a magical crown point."""
    x, y, z = location
    bpy.ops.mesh.primitive_cone_add(
        vertices=6, radius1=radius, radius2=0.0, depth=height * .58,
        location=(x, y, z + height * .16),
    )
    upper = finish(bpy.context.object, name + "_Upper", material, parent)
    bpy.ops.mesh.primitive_cone_add(
        vertices=6, radius1=0.0, radius2=radius, depth=height * .42,
        location=(x, y, z - height * .13),
    )
    lower = finish(bpy.context.object, name + "_Lower", material, parent)
    return upper, lower


def add_area_light(name, location, energy, colour, size, target):
    data = bpy.data.lights.new(name + "_Data", "AREA")
    data.energy = energy
    data.color = colour
    data.shape = "DISK"
    data.size = size
    light = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(light)
    light.location = location
    light.rotation_euler = (Vector(target) - light.location).to_track_quat("-Z", "Y").to_euler()


parent = bpy.data.objects.get(ENGINE_PARENT)
if parent is None:
    raise RuntimeError("Missing %s" % ENGINE_PARENT)

# Idempotently replace both the legacy flat halo and any previous celestial pass.
remove_tokens = (
    "TRAIN_Engine_CrownHalo",
    "TRAIN_Engine_HaloRay_",
    "TRAIN_Engine_CelestialHaloOuterPart_",
    "TRAIN_Engine_CelestialHaloInnerPart_",
)
for obj in list(bpy.data.objects):
    if any(token in obj.name for token in remove_tokens):
        bpy.data.objects.remove(obj, do_unlink=True)

gold = bpy.data.materials.get("Crown_AccentGold")
cyan = bpy.data.materials.get("Energy_Cyan")
purple = bpy.data.materials.get("Crystal_Purple")
if gold is None or cyan is None or purple is None:
    raise RuntimeError("The authored gold/cyan/purple train materials are missing")

rainbow_names = (
    "Engine_Rainbow_Red", "Engine_Rainbow_Orange", "Engine_Rainbow_Yellow",
    "Engine_Rainbow_Green", "Engine_Rainbow_Blue", "Engine_Rainbow_Indigo",
    "Engine_Rainbow_Violet",
)
rainbow = [bpy.data.materials.get(name) for name in rainbow_names]
if any(material is None for material in rainbow):
    raise RuntimeError("The authored seven-colour engine palette is incomplete")

torus("Engine_CelestialHaloOuterPart_Ring", (0, HALO_Y, 10.28), 2.78, .15, gold, parent)
for index in range(12):
    angle = math.tau * index / 12.0
    radial = Vector((math.cos(angle), math.sin(angle), 0.0))
    point = radial * 2.78 + Vector((0, HALO_Y, 10.37))
    crystal(
        "Engine_CelestialHaloOuterPart_Crystal_%02d" % index,
        point, .13, .48, purple if index % 2 else cyan, parent,
    )

torus("Engine_CelestialHaloInnerPart_Ring", (0, HALO_Y, 10.52), 1.82, .105, cyan, parent)
for index, material in enumerate(rainbow):
    angle = math.tau * index / 7.0 + math.radians(8.0)
    sphere(
        "Engine_CelestialHaloInnerPart_RainbowNode_%02d" % index,
        (math.cos(angle) * 1.82, HALO_Y + math.sin(angle) * 1.82, 10.52),
        .16, material, parent,
    )

bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)

# Add preview-only illumination; the runtime exporter removes RENDER_ objects.
for obj in list(bpy.data.objects):
    if obj.name.startswith("RENDER_CelestialHalo"):
        bpy.data.objects.remove(obj, do_unlink=True)
add_area_light("RENDER_CelestialHalo_Key", (9, -24, 18), 1350,
               (1.0, .76, .45), 7.0, (0, HALO_Y, 10.2))
add_area_light("RENDER_CelestialHalo_Fill", (-8, -14, 16), 950,
               (.35, .70, 1.0), 6.0, (0, HALO_Y, 10.2))

scene = bpy.context.scene
camera = scene.camera
camera.location = (10.8, -25.8, 15.0)
camera.rotation_euler = (Vector((0, HALO_Y, 9.65)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.lens = 58.0
scene.render.resolution_x = 1600
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.filepath = RENDER_PATH
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
print("CROWN_LINE_CELESTIAL_HALO: PASS render=%s" % RENDER_PATH)
