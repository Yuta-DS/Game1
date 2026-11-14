"""Replace the clipping steam piston/rod assembly in the authored train."""

import math
import os

import bpy
from mathutils import Vector


PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND_PATH = os.path.join(
    PROJECT_DIR, "assets3D", "crown_line_train", "crown_line_lego_train.blend"
)
RENDER_PATH = os.path.join(
    PROJECT_DIR, "artifacts", "blender_crown_train_clearance_linkage.png"
)
BOILER_Y = -22.55


def finish(obj, name, material, parent):
    obj.name = "TRAIN_" + name
    obj.data.name = obj.name + "_Mesh"
    obj.data.materials.clear()
    obj.data.materials.append(material)
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world
    return obj


def cylinder(name, location, radius, depth, material, parent, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=18, radius=radius, depth=depth, location=location, rotation=rotation
    )
    return finish(bpy.context.object, name, material, parent)


def torus(name, location, major, minor, material, parent, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major, minor_radius=minor, major_segments=36,
        minor_segments=8, location=location, rotation=rotation,
    )
    return finish(bpy.context.object, name, material, parent)


def beam(name, start, end, radius, material, parent):
    start = Vector(start)
    end = Vector(end)
    direction = end - start
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=10, radius=radius, depth=direction.length,
        location=(start + end) * .5,
    )
    obj = bpy.context.object
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return finish(obj, name, material, parent)


def world_aabb(obj):
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return (
        Vector((min(point.x for point in corners), min(point.y for point in corners),
                min(point.z for point in corners))),
        Vector((max(point.x for point in corners), max(point.y for point in corners),
                max(point.z for point in corners))),
    )


def assert_clear(first, second, minimum_gap=.10):
    first_min, first_max = world_aabb(first)
    second_min, second_max = world_aabb(second)
    axis_gaps = (
        max(second_min.x - first_max.x, first_min.x - second_max.x),
        max(second_min.y - first_max.y, first_min.y - second_max.y),
        max(second_min.z - first_max.z, first_min.z - second_max.z),
    )
    clearance = max(axis_gaps)
    if clearance < minimum_gap:
        raise RuntimeError("%s overlaps %s (clearance %.3f)" %
                           (first.name, second.name, clearance))
    return clearance


parent = bpy.data.objects.get("TRAIN_Engine_Assembly")
if parent is None:
    raise RuntimeError("Missing TRAIN_Engine_Assembly")

for obj in list(bpy.data.objects):
    if any(token in obj.name for token in (
        "TRAIN_Engine_SteamPistonCylinder_",
        "TRAIN_Engine_SteamPistonCollar_",
        "TRAIN_Engine_SteamConnectingRod_",
        "TRAIN_Engine_SteamCrankPin_",
    )):
        bpy.data.objects.remove(obj, do_unlink=True)

bronze = bpy.data.materials.get("Root_Bronze_Band")
gold = bpy.data.materials.get("Crown_AccentGold")
cyan = bpy.data.materials.get("Energy_Cyan")
if bronze is None or gold is None or cyan is None:
    raise RuntimeError("Required bronze, gold, or cyan linkage material is missing")

clearances = []
for side in (-1, 1):
    side_tag = "L" if side < 0 else "R"
    linkage_x = side * (5.47 + .56)
    piston = cylinder(
        "Engine_SteamPistonCylinder_" + side_tag,
        (linkage_x, BOILER_Y - 3.25, 2.00), .26, 1.00, bronze, parent,
        (math.pi / 2, 0, 0),
    )
    torus(
        "Engine_SteamPistonCollar_" + side_tag,
        (linkage_x, BOILER_Y - 2.73, 2.00), .31, .060, gold, parent,
        (math.pi / 2, 0, 0),
    )
    rod = beam(
        "Engine_SteamConnectingRod_" + side_tag,
        (linkage_x, BOILER_Y - 2.72, 2.00),
        (linkage_x, BOILER_Y - 1.90, 2.25), .080, gold, parent,
    )
    cylinder(
        "Engine_SteamCrankPin_" + side_tag,
        (linkage_x, BOILER_Y - 1.90, 2.25), .18, .18, cyan, parent,
        (0, math.pi / 2, 0),
    )
    gear = bpy.data.objects.get("TRAIN_Engine_SteamDriveGear_%s_0" % side_tag)
    if gear is None:
        raise RuntimeError("Missing drive gear on side %s" % side_tag)
    clearances.extend((assert_clear(piston, gear), assert_clear(rod, gear)))

bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)

scene = bpy.context.scene
camera = scene.camera
camera.location = (14.2, -23.65, 3.8)
camera.rotation_euler = (Vector((5.35, -24.15, 2.8)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.lens = 58.0
scene.render.resolution_x = 1200
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.filepath = RENDER_PATH
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
print("CROWN_LINE_STEAM_LINKAGE_CLEARANCE: PASS minimum_gap=%.3f render=%s" %
      (min(clearances), RENDER_PATH))
