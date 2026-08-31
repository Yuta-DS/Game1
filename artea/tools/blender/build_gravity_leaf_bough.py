"""Build an elongated, gravity-shaped four-family foliage bough.

The asset is intentionally standalone.  It uses the reference-faithful leaf
reliefs but places each leaf by its brass stem socket, not by its object origin.
The hierarchy is main bough -> lateral branch -> leaf-bearing twig -> leaf.
"""

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

ROOT = PROJECT / "assets3D/tree_of_life/gravity_leaf_bough"
BLEND_PATH = ROOT / "source/gravity_leaf_bough.blend"
GLB_PATH = ROOT / "glb/gravity_leaf_bough.glb"
MANIFEST_PATH = ROOT / "gravity_leaf_bough_manifest.json"
ARTIFACT_ROOT = PROJECT / "artifacts/tree_of_life_gravity_bough"
SIDE_PATH = ARTIFACT_ROOT / "gravity_leaf_bough_side.png"
TOP_PATH = ARTIFACT_ROOT / "gravity_leaf_bough_top.png"
SOCKET_PATH = ARTIFACT_ROOT / "gravity_leaf_bough_socket_closeup.png"
ATTACHMENT_PATH = ARTIFACT_ROOT / "gravity_leaf_bough_attachment_proof.png"


# Local coordinates of the visible brass stem connector in each reference
# relief.  These offsets are the essential correction to the previous model:
# the object origins sit near the image centres, not at the attachment sockets.
LEAF_SOCKET_LOCAL = (
    Vector((-2.37, -1.66, 0.20)),
    Vector((-3.38, -1.96, 0.20)),
    Vector((-3.47, -2.63, 0.21)),
    Vector((-1.21, -1.38, 0.20)),
)
LEAF_SCALE = (0.42, 0.39, 0.38, 0.31)


def catmull_rom(points, samples_per_span=5):
    """Return a smooth polyline through authored control points."""
    control = [Vector(point) for point in points]
    padded = [control[0], *control, control[-1]]
    result = []
    for span in range(1, len(padded) - 2):
        p0, p1, p2, p3 = padded[span - 1:span + 3]
        for step in range(samples_per_span):
            t = step / samples_per_span
            t2, t3 = t * t, t * t * t
            point = 0.5 * ((2.0 * p1) + (-p0 + p2) * t
                + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
                + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
            result.append(tuple(point))
    result.append(tuple(control[-1]))
    return tuple(result)


def point_on_polyline(path, t):
    vectors = [Vector(point) for point in path]
    lengths = [(vectors[i + 1] - vectors[i]).length for i in range(len(vectors) - 1)]
    wanted = max(0.0, min(1.0, t)) * sum(lengths)
    walked = 0.0
    for index, length in enumerate(lengths):
        if walked + length >= wanted or index == len(lengths) - 1:
            local = 0.0 if length == 0.0 else (wanted - walked) / length
            return vectors[index].lerp(vectors[index + 1], local), (
                vectors[index + 1] - vectors[index]).normalized()
        walked += length
    return vectors[-1], (vectors[-1] - vectors[-2]).normalized()


def wrapped_fiber_path(path, radii, phase, turns, clearance=1.04):
    """Return a strand spiralling over a tapered branch surface."""
    points = [Vector(point) for point in path]
    wrapped = []
    for index, point in enumerate(points):
        before = points[max(0, index - 1)]
        after = points[min(len(points) - 1, index + 1)]
        tangent = (after - before).normalized()
        side = tangent.cross(Vector((0.0, 0.0, 1.0)))
        if side.length_squared < 0.0001:
            side = Vector((0.0, 1.0, 0.0))
        side.normalize()
        up = side.cross(tangent).normalized()
        angle = phase + math.tau * turns * index / max(1, len(points) - 1)
        offset = (side * math.cos(angle) + up * math.sin(angle)) * radii[index] * clearance
        wrapped.append(tuple(point + offset))
    return tuple(wrapped)


def leaf_matrix(socket_world, family, scale, azimuth, pitch, roll):
    """Transform a relief so its visible connector lands on socket_world."""
    socket = LEAF_SOCKET_LOCAL[family]
    # Source blade direction, measured from brass connector toward blade mass.
    source_angle = math.atan2(-socket.y, -socket.x)
    rotation = Matrix.Rotation(azimuth - source_angle, 4, "Z")
    rotation = rotation @ Matrix.Rotation(pitch, 4, "Y")
    rotation = rotation @ Matrix.Rotation(roll, 4, "X")
    scaling = Matrix.Diagonal((scale, scale, scale, 1.0))
    return (Matrix.Translation(socket_world) @ rotation @ scaling
        @ Matrix.Translation(-socket))


def add_camera(name, location, target, ortho_scale):
    data = bpy.data.cameras.new(name)
    data.type = "ORTHO"
    data.ortho_scale = ortho_scale
    camera = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(camera)
    camera.location = location
    camera.rotation_euler = ((Vector(target) - camera.location)
        .to_track_quat("-Z", "Y").to_euler())
    return camera


def main():
    canopy.clear_scene()
    main_collection = bpy.data.collections.new("01_Main_Load_Bearing_Bough")
    lateral_collection = bpy.data.collections.new("02_Alternating_Laterals")
    twig_collection = bpy.data.collections.new("03_Leaf_Bearing_Twigs")
    leaf_collection = bpy.data.collections.new("04_Socket_Attached_Leaves")
    main_fiber_collection = bpy.data.collections.new("05_Biofiber_Main_Braid")
    distribution_collection = bpy.data.collections.new("06_Biofiber_Distribution_Network")
    energy_node_collection = bpy.data.collections.new("07_Leaf_Energy_Transfer_Nodes")
    for collection in (main_collection, lateral_collection, twig_collection, leaf_collection,
            main_fiber_collection, distribution_collection, energy_node_collection):
        bpy.context.scene.collection.children.link(collection)

    wood = canopy.material("MAT_GravityBoughLivingWood", (0.20, 0.060, 0.016, 1),
        0.12, 0.46, (0.08, 0.012, 0.002), 0.10)
    twig_wood = canopy.material("MAT_GravityBoughTwigWood", (0.27, 0.085, 0.022, 1),
        0.10, 0.50, (0.06, 0.010, 0.002), 0.08)
    cyan = canopy.material("MAT_GravityBoughCyanSap", (0.01, 0.22, 0.34, 1),
        0.12, 0.18, (0.03, 0.82, 1.0), 5.5)
    fiber_cyan = canopy.material("MAT_BiofiberOpticFlow", (0.002, 0.16, 0.30, 1),
        0.10, 0.12, (0.005, 0.46, 1.0), 3.6)
    pulse_cyan = canopy.material("MAT_BiofiberEnergyPulse", (0.04, 0.42, 0.82, 1),
        0.06, 0.08, (0.02, 0.62, 1.0), 6.5)
    brass = canopy.material("MAT_GravityBoughBrass", (0.66, 0.30, 0.052, 1), 0.82, 0.22)

    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.075)
    energy_node_template = bpy.context.object
    energy_node_template.name = "BiofiberEnergyNodeTemplate"
    energy_node_template.data.materials.append(pulse_cyan)
    for collection in list(energy_node_template.users_collection):
        collection.objects.unlink(energy_node_template)
    energy_node_collection.objects.link(energy_node_template)
    energy_node_template.hide_render = True
    energy_node_template.hide_viewport = True

    # A long tapered cantilever: the proximal section rises slightly, then the
    # increasing distal load creates progressively stronger downward curvature.
    controls = (
        (-18.0, 0.0, 1.0), (-14.0, 0.1, 2.0), (-9.0, -0.2, 2.6),
        (-3.0, 0.3, 2.7), (3.0, -0.2, 2.2), (9.0, 0.25, 1.2),
        (14.0, -0.1, -0.5), (18.0, 0.0, -2.8),
    )
    main_path = catmull_rom(controls, 5)
    main_radii = tuple(1.22 * (1.0 - 0.78 * i / (len(main_path) - 1))
        for i in range(len(main_path)))
    export_objects = [canopy.make_tube("GravityBough_Main_LoadBearing", main_path,
        main_radii, 12, wood, main_collection)]
    sap_path = tuple((x, y - 0.04, z + main_radii[i] * 0.76)
        for i, (x, y, z) in enumerate(main_path))
    export_objects.append(canopy.make_tube("GravityBough_Main_CyanSap", sap_path,
        tuple(max(0.035, radius * 0.10) for radius in main_radii), 7, cyan, main_collection))

    # Three luminous strands form a loose braided biofiber sheath.  The braid
    # remains outside the bark and visibly feeds every lateral junction.
    main_biofiber_count = 0
    for strand_index, phase in enumerate((0.0, math.tau / 3.0, 2.0 * math.tau / 3.0)):
        fiber_path = wrapped_fiber_path(main_path, main_radii, phase, 3.25)
        export_objects.append(canopy.make_tube(
            f"Biofiber_MainBraid_{strand_index:02d}", fiber_path,
            tuple(0.052 - 0.016 * i / (len(fiber_path) - 1) for i in range(len(fiber_path))),
            6, fiber_cyan, main_fiber_collection))
        main_biofiber_count += 1

    # Bright travelling-charge markers make the intended energy direction
    # readable even before a Godot scrolling/pulse shader is added.
    main_pulse_count = 0
    for pulse_index in range(24):
        pulse_position, _ = point_on_polyline(sap_path, (pulse_index + 0.5) / 24.0)
        pulse = energy_node_template.copy()
        pulse.data = energy_node_template.data
        pulse.name = f"Biofiber_MainFlowPulse_{pulse_index:02d}"
        pulse.location = pulse_position
        pulse.scale = Vector((1.55, 1.55, 1.55))
        pulse.hide_render = False
        pulse.hide_viewport = False
        main_fiber_collection.objects.link(pulse)
        export_objects.append(pulse)
        main_pulse_count += 1

    for rank, t in enumerate((0.15, 0.31, 0.48, 0.65, 0.80)):
        position, tangent = point_on_polyline(main_path, t)
        export_objects.append(canopy.add_collar(f"GravityBough_LoadCollar_{rank:02d}",
            position, tangent, main_radii[min(int(t * len(main_radii)), len(main_radii) - 1)] * 1.04,
            brass, main_collection))

    templates = [canopy.append_leaf_template(source, leaf_collection)
        for source in canopy.LEAF_SOURCES]
    leaf_counts = {source.slug: 0 for source in canopy.LEAF_SOURCES}
    socket_errors = []
    leaf_index = 0
    lateral_count = 0
    twig_count = 0
    lateral_fiber_count = 0
    twig_fiber_count = 0
    leaf_energy_node_count = 0
    attachment_detail_objects = []
    attachment_detail_center = Vector((0.0, 0.0, 0.0))

    # Alternating lateral ranks avoid the rejected circular/radial rosette.
    # Proximal laterals are longer and stronger; distal laterals become shorter.
    # Populate the complete bough, beginning immediately beyond the root socket
    # and continuing to the terminal tip.  Twenty-seven alternating laterals
    # give the dense interleaved coverage requested without radial clustering.
    lateral_total = 27
    for rank in range(lateral_total):
        t = 0.035 + rank * (0.91 / (lateral_total - 1))
        anchor, tangent = point_on_polyline(main_path, t)
        side = -1.0 if rank % 2 == 0 else 1.0
        reach = 7.1 - 2.5 * t + 0.55 * math.sin(rank * 1.41)
        lateral_dir = Vector((0.28 + 0.12 * math.cos(rank), side, 0.0)).normalized()
        bend = 0.42 + 1.65 * t
        lateral_controls = (
            tuple(anchor),
            tuple(anchor + lateral_dir * reach * 0.48 + Vector((0, 0, 0.48 - bend * 0.22))),
            tuple(anchor + lateral_dir * reach + Vector((1.1, 0, -bend))),
        )
        lateral_path = catmull_rom(lateral_controls, 6)
        base_radius = 0.48 * (1.0 - 0.38 * t)
        lateral_radii = tuple(base_radius * (1.0 - 0.78 * i / (len(lateral_path) - 1))
            for i in range(len(lateral_path)))
        lateral_wood = canopy.make_tube(f"GravityBough_Lateral_{rank:02d}",
            lateral_path, lateral_radii, 9, twig_wood, lateral_collection)
        export_objects.append(lateral_wood)
        if rank == 10:
            attachment_detail_objects.append(lateral_wood)
        lateral_count += 1

        channel_path = tuple((x, y, z + lateral_radii[i] * 0.74)
            for i, (x, y, z) in enumerate(lateral_path))
        export_objects.append(canopy.make_tube(f"GravityBough_LateralSap_{rank:02d}",
            channel_path, tuple(max(0.013, r * 0.12) for r in lateral_radii),
            6, cyan, lateral_collection))

        # Paired surface fibers split power from the main braid into the
        # lateral. Their phase offset reads as a double helix around the wood.
        for fiber_index, phase in enumerate((0.25, math.pi + 0.25)):
            lateral_fiber_path = wrapped_fiber_path(
                lateral_path, lateral_radii, phase + rank * 0.31, 1.35, 1.06)
            export_objects.append(canopy.make_tube(
                f"Biofiber_Lateral_{rank:02d}_{fiber_index:02d}", lateral_fiber_path,
                tuple(max(0.014, 0.027 - 0.010 * i / (len(lateral_fiber_path) - 1))
                    for i in range(len(lateral_fiber_path))),
                5, fiber_cyan, distribution_collection))
            lateral_fiber_count += 1

        # Three leaf-bearing twig orders per lateral.  The last one continues
        # the parent direction, while the others alternate toward available light.
        for twig_rank, twig_t in enumerate((0.24, 0.38, 0.52, 0.66, 0.80, 0.94)):
            twig_anchor, twig_tangent = point_on_polyline(lateral_path, twig_t)
            fork = -1.0 if (rank + twig_rank) % 2 == 0 else 1.0
            across = Vector((-twig_tangent.y, twig_tangent.x, 0.0)).normalized()
            twig_direction = (twig_tangent + across * fork * (0.30 if twig_rank < 2 else 0.12)
                + Vector((0.0, 0.0, -0.12 - 0.16 * t))).normalized()
            twig_length = 2.6 - 0.45 * t - 0.22 * twig_rank
            twig_end = twig_anchor + twig_direction * twig_length
            twig_end.z -= 0.18 + 0.28 * t
            twig_middle = twig_anchor.lerp(twig_end, 0.52) + Vector((0, 0, 0.16))
            twig_path = catmull_rom((tuple(twig_anchor), tuple(twig_middle), tuple(twig_end)), 5)
            twig_radii = tuple(0.16 * (1.0 - 0.72 * i / (len(twig_path) - 1))
                for i in range(len(twig_path)))
            leaf_twig = canopy.make_tube(
                f"GravityBough_LeafTwig_{rank:02d}_{twig_rank:02d}", twig_path,
                twig_radii, 7, twig_wood, twig_collection)
            export_objects.append(leaf_twig)
            if rank == 10 and twig_rank == 3:
                attachment_detail_objects.append(leaf_twig)
                attachment_detail_center = Vector(twig_path[len(twig_path) // 2])
            twig_fiber_path = wrapped_fiber_path(
                twig_path, twig_radii, 0.5 + twig_rank * 0.72, 0.72, 1.08)
            export_objects.append(canopy.make_tube(
                f"Biofiber_LeafTwig_{rank:02d}_{twig_rank:02d}", twig_fiber_path,
                tuple(0.014 - 0.004 * i / (len(twig_fiber_path) - 1)
                    for i in range(len(twig_fiber_path))),
                5, fiber_cyan, distribution_collection))
            twig_fiber_count += 1
            twig_count += 1

            # Eight alternating bases fill every twig from base to terminal bud.
            # With 27 laterals and six twigs per lateral this produces exactly
            # 1,296 socket-connected compound leaves (four times revision two).
            for leaf_rank, leaf_t in enumerate(
                    (0.17, 0.28, 0.39, 0.50, 0.61, 0.72, 0.83, 0.94)):
                socket_world, leaf_tangent = point_on_polyline(twig_path, leaf_t)
                leaf_side = -1.0 if leaf_rank % 2 == 0 else 1.0
                fan = Vector((-leaf_tangent.y, leaf_tangent.x, 0.0)).normalized()
                is_terminal = leaf_rank >= 6
                desired = (leaf_tangent * (1.04 if is_terminal else 0.72)
                    + fan * leaf_side * (0.26 if is_terminal else 0.68)
                    + Vector((0, 0, -0.10 - 0.25 * t))).normalized()
                family = canopy.LEAF_FAMILY_PATTERN[leaf_index % len(canopy.LEAF_FAMILY_PATTERN)]
                leaf = templates[family].copy()
                leaf.data = templates[family].data
                leaf.hide_render = False
                leaf.hide_viewport = False
                leaf.name = (f"GravityBough_SocketLeaf_{canopy.LEAF_SOURCES[family].slug}_"
                    f"{leaf_index:03d}")
                scale = LEAF_SCALE[family] * (1.05 - 0.22 * t)
                azimuth = math.atan2(desired.y, desired.x)
                pitch = math.radians(7.0 + 19.0 * t + 1.45 * leaf_rank)
                roll = math.radians(leaf_side * (5.0 + 3.0 * math.sin(rank)))
                leaf.matrix_world = leaf_matrix(socket_world, family, scale, azimuth, pitch, roll)
                leaf_collection.objects.link(leaf)
                export_objects.append(leaf)
                if rank == 10 and twig_rank == 3:
                    attachment_detail_objects.append(leaf)
                transformed_socket = leaf.matrix_world @ LEAF_SOCKET_LOCAL[family]
                socket_errors.append((transformed_socket - socket_world).length)
                energy_node = energy_node_template.copy()
                energy_node.data = energy_node_template.data
                energy_node.name = f"Biofiber_LeafTransferNode_{leaf_index:04d}"
                energy_node.location = socket_world
                energy_node.scale = Vector((0.82, 0.82, 0.82))
                energy_node.hide_render = False
                energy_node.hide_viewport = False
                energy_node_collection.objects.link(energy_node)
                export_objects.append(energy_node)
                leaf_energy_node_count += 1
                leaf_counts[canopy.LEAF_SOURCES[family].slug] += 1
                leaf_index += 1

    for template in templates:
        bpy.data.objects.remove(template, do_unlink=True)
    bpy.data.objects.remove(energy_node_template, do_unlink=True)

    world = bpy.context.scene.world or bpy.data.worlds.new("GravityBoughWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.0015, 0.007, 0.020, 1)
    background.inputs["Strength"].default_value = 0.58
    for name, location, energy, color, size in (
        ("GravityBoughKey", (-8, -24, 30), 3200, (1.0, 0.78, 0.52), 20),
        ("GravityBoughCyanFill", (18, 16, 18), 2300, (0.16, 0.62, 1.0), 16),
        ("GravityBoughRim", (5, 2, 30), 1800, (0.42, 0.76, 1.0), 12),
    ):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.color, data.size = energy, color, size
        light = bpy.data.objects.new(name, data)
        bpy.context.scene.collection.objects.link(light)
        light.location = location

    side_camera = add_camera("GravityBoughSideCamera", (0, -48, 15), (0, 0, 0), 44)
    top_camera = add_camera("GravityBoughTopCamera", (0, 0, 52), (0, 0, 0), 44)
    socket_camera = add_camera("GravityBoughSocketCamera", (-5.5, -12, 8), (-5.5, 0, 1.7), 12)
    attachment_camera = add_camera("GravityBoughAttachmentCamera",
        tuple(attachment_detail_center + Vector((0.0, -14.0, 4.0))),
        tuple(attachment_detail_center), 10)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.look = "AgX - Medium High Contrast"

    for path in (BLEND_PATH.parent, GLB_PATH.parent, ARTIFACT_ROOT):
        path.mkdir(parents=True, exist_ok=True)
    scene["asset_name"] = "Gravity-Shaped Four-Family Leaf Bough"
    scene["attachment_hierarchy"] = "main_bough/lateral/leaf_twig/brass_leaf_socket"
    scene["design_rule"] = "tapered cantilever with alternating branch order and distal sag"
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))

    bpy.ops.object.select_all(action="DESELECT")
    for obj in export_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = export_objects[0]
    bpy.ops.export_scene.gltf(filepath=str(GLB_PATH), export_format="GLB",
        use_selection=True, export_materials="EXPORT", export_yup=True)

    for camera, path in ((side_camera, SIDE_PATH), (top_camera, TOP_PATH),
            (socket_camera, SOCKET_PATH)):
        scene.camera = camera
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)

    # Prove one complete biological connection without the visual ambiguity of
    # the full canopy: parent lateral -> curved twig -> eight brass-socket leaves.
    # Visibility is restored immediately so the saved source and GLB stay whole.
    previous_visibility = {obj: obj.hide_render for obj in export_objects}
    detail_set = set(attachment_detail_objects)
    for obj in export_objects:
        obj.hide_render = obj not in detail_set
    scene.camera = attachment_camera
    scene.render.filepath = str(ATTACHMENT_PATH)
    bpy.ops.render.render(write_still=True)
    for obj, hidden in previous_visibility.items():
        obj.hide_render = hidden

    manifest = {
        "asset": "gravity_leaf_bough",
        "main_boughs": 1,
        "alternating_laterals": lateral_count,
        "leaf_bearing_twigs": twig_count,
        "socket_attached_compound_leaves": leaf_index,
        "leaf_counts": leaf_counts,
        "biofiber_main_braid_strands": main_biofiber_count,
        "biofiber_main_flow_pulses": main_pulse_count,
        "biofiber_lateral_strands": lateral_fiber_count,
        "biofiber_leaf_twig_conduits": twig_fiber_count,
        "biofiber_leaf_transfer_nodes": leaf_energy_node_count,
        "godot_animation_ready_material": "MAT_BiofiberOpticFlow",
        "maximum_socket_error_m": max(socket_errors),
        "average_socket_error_m": sum(socket_errors) / len(socket_errors),
        "layout": "elongated_plagiotropic_bough_with_distal_gravity_sag",
        "source_blend": str(BLEND_PATH.relative_to(PROJECT)),
        "game_glb": str(GLB_PATH.relative_to(PROJECT)),
        "side_preview": str(SIDE_PATH.relative_to(PROJECT)),
        "top_preview": str(TOP_PATH.relative_to(PROJECT)),
        "socket_closeup": str(SOCKET_PATH.relative_to(PROJECT)),
        "attachment_proof": str(ATTACHMENT_PATH.relative_to(PROJECT)),
        "attachment_proof_leaf_count": 8,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
