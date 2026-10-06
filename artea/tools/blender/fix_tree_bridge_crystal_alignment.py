"""Align the layered portal crystals to their supporting gold boughs."""

from __future__ import annotations

import math
import os

import bpy
from mathutils import Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLEND_PATH = os.path.join(
    ROOT, "assets3D", "tree_processional_bridge", "blend",
    "tree_processional_bridge.blend")
GLB_PATH = os.path.join(
    ROOT, "assets3D", "tree_processional_bridge", "glb",
    "tree_processional_bridge.glb")
RENDER_PATH = os.path.join(
    ROOT, "artifacts", "tree_processional_bridge_crystal_alignment.png")

PORTAL_Y = (107.28, 223.50, 339.72)
LAYER_Y_OFFSET = {
    "PortalBoughCrystal": -1.93,
}
CRYSTAL_SPECS = (
    ((-19.0, 15.2), (-8.0, 20.0), 0.40),
    ((-19.0, 15.2), (-8.0, 20.0), 0.78),
    ((-8.0, 20.0), (0.0, 22.0), 0.25),
    ((19.0, 15.2), (8.0, 20.0), 0.40),
    ((19.0, 15.2), (8.0, 20.0), 0.78),
    ((8.0, 20.0), (0.0, 22.0), 0.25),
)


def align_crystals() -> None:
    for portal_index, portal_y in enumerate(PORTAL_Y):
        for crystal_index, (start, finish, progress) in enumerate(CRYSTAL_SPECS):
            start_x, start_z = start
            finish_x, finish_z = finish
            x = start_x + (finish_x - start_x) * progress
            z = start_z + (finish_z - start_z) * progress
            tangent_angle = math.atan2(finish_x - start_x,
                                       finish_z - start_z)
            # The ornament grows normal to its bough. Keep every crystal on a
            # given side leaning in the same direction instead of alternating.
            crystal_angle = tangent_angle - math.copysign(
                math.pi * 0.5, tangent_angle)
            for family, y_offset in LAYER_Y_OFFSET.items():
                crystal = bpy.data.objects.get(
                    f"{family}_{portal_index}_{crystal_index}")
                if crystal is None:
                    raise RuntimeError(
                        f"Missing {family}_{portal_index}_{crystal_index}")
                crystal.location = (x, portal_y + y_offset, z)
                crystal.rotation_euler = (0.0, crystal_angle, 0.0)


def verify_crystals() -> int:
    checked = 0
    for portal_index, portal_y in enumerate(PORTAL_Y):
        for crystal_index, (start, finish, progress) in enumerate(CRYSTAL_SPECS):
            start_x, start_z = start
            finish_x, finish_z = finish
            expected = Vector((
                start_x + (finish_x - start_x) * progress,
                portal_y + LAYER_Y_OFFSET["PortalBoughCrystal"],
                start_z + (finish_z - start_z) * progress,
            ))
            crystal = bpy.data.objects[
                f"PortalBoughCrystal_{portal_index}_{crystal_index}"]
            if (crystal.location - expected).length > 0.0001:
                raise RuntimeError(f"Off-bough crystal: {crystal.name}")
            tangent = Vector((finish_x - start_x, 0.0,
                              finish_z - start_z)).normalized()
            long_axis = crystal.rotation_euler.to_matrix() @ Vector((0, 0, 1))
            if abs(tangent.dot(long_axis)) > 0.0001:
                raise RuntimeError(f"Crystal is not bough-normal: {crystal.name}")
            checked += 1
    return checked


def rebuild_portal_runtime_mesh() -> None:
    editable = bpy.data.collections["TREE_BRIDGE_EDITABLE_COMPONENTS"]
    runtime = bpy.data.collections["TREE_BRIDGE_GAME_EXPORT"]
    root = bpy.data.objects["TreeProcessionalBridge"]
    previous = bpy.data.objects.get("PortalGold")
    if previous is not None:
        bpy.data.objects.remove(previous, do_unlink=True)

    copies = []
    for source in editable.objects:
        if source.type != "MESH" or source.get("semantic_group") != "PORTAL_GOLD":
            continue
        duplicate = source.copy()
        duplicate.data = source.data.copy()
        runtime.objects.link(duplicate)
        # Editable components live below semantic hierarchy parents. Preserve the
        # evaluated world transform before joining them into the flat runtime mesh;
        # retaining their parent-local coordinates here applies the portal offset a
        # second time when the result is parented to the export root.
        world_matrix = source.matrix_world.copy()
        duplicate.parent = None
        duplicate.matrix_world = world_matrix
        copies.append(duplicate)
    if not copies:
        raise RuntimeError("No PORTAL_GOLD source components found")

    bpy.ops.object.select_all(action="DESELECT")
    for duplicate in copies:
        duplicate.select_set(True)
    bpy.context.view_layer.objects.active = copies[0]
    bpy.ops.object.join()
    joined = copies[0]
    joined.name = "PortalGold"
    joined["semantic_group"] = "PORTAL_GOLD"
    joined_world = joined.matrix_world.copy()
    joined.parent = root
    joined.matrix_world = joined_world


def export_runtime_glb() -> None:
    runtime = bpy.data.collections["TREE_BRIDGE_GAME_EXPORT"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in runtime.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = bpy.data.objects["TreeProcessionalBridge"]
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )


def point_camera(camera, target) -> None:
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat(
        "-Z", "Y").to_euler()


def render_alignment_preview() -> None:
    os.makedirs(os.path.dirname(RENDER_PATH), exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 760
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("CrystalAlignmentWorld")
    scene.world.color = (0.22, 0.42, 0.58)

    camera_data = bpy.data.cameras.new("CrystalAlignmentCamera")
    camera = bpy.data.objects.new("CrystalAlignmentCamera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = (43.0, 79.0, 30.0)
    camera_data.lens = 58.0
    point_camera(camera, (0.0, PORTAL_Y[0], 18.3))
    scene.camera = camera

    sun_data = bpy.data.lights.new("CrystalAlignmentSun", "SUN")
    sun_data.energy = 2.0
    sun = bpy.data.objects.new("CrystalAlignmentSun", sun_data)
    scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(28), math.radians(-22),
                          math.radians(-32))

    area_data = bpy.data.lights.new("CrystalAlignmentFill", "AREA")
    area_data.energy = 1300.0
    area_data.shape = "DISK"
    area_data.size = 18.0
    area = bpy.data.objects.new("CrystalAlignmentFill", area_data)
    scene.collection.objects.link(area)
    area.location = (-18.0, 89.0, 32.0)
    point_camera(area, (0.0, PORTAL_Y[0], 18.0))

    scene.render.filepath = RENDER_PATH
    bpy.ops.render.render(write_still=True)


def main() -> None:
    align_crystals()
    checked = verify_crystals()
    rebuild_portal_runtime_mesh()
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    export_runtime_glb()
    render_alignment_preview()
    print("TREE_BRIDGE_CRYSTAL_ALIGNMENT: PASS")
    print(f"TREE_BRIDGE_CRYSTAL_ALIGNMENT: checked={checked}")
    print(f"TREE_BRIDGE_CRYSTAL_ALIGNMENT: blend={BLEND_PATH}")
    print(f"TREE_BRIDGE_CRYSTAL_ALIGNMENT: glb={GLB_PATH}")
    print(f"TREE_BRIDGE_CRYSTAL_ALIGNMENT: render={RENDER_PATH}")


main()
