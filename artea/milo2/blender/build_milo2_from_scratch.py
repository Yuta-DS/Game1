"""Build Milo 2 from a blank Blender scene.

This is a clean-room character generator. It deliberately has no source-model
argument and no dependency on another character. The output is a smooth,
rigged, animated chibi feline matching milo2/reference/milo2_target.png.
"""

from pathlib import Path
import math

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
ASSET_DIR = ROOT / "milo2" / "assets"
ARTIFACT_DIR = ROOT / "milo2" / "artifacts"
BLEND_OUT = ASSET_DIR / "milo2_from_scratch.blend"
GLB_OUT = ASSET_DIR / "milo2_from_scratch.glb"
RENDER_OUT = ARTIFACT_DIR / "milo2_reference_render.png"

ASSET_DIR.mkdir(parents=True, exist_ok=True)
ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)

# The architectural guarantee requested by the user: a genuinely empty scene.
bpy.ops.wm.read_factory_settings(use_empty=True)


def rgba(hex_color):
    value = hex_color.lstrip("#")
    srgb = tuple(int(value[index:index + 2], 16) / 255.0 for index in (0, 2, 4))
    # Blender shader inputs are scene-linear. Converting here keeps the rendered
    # navy, burgundy, ivory, and gold faithful to the approved sRGB palette.
    linear = tuple(
        channel / 12.92 if channel <= 0.04045
        else ((channel + 0.055) / 1.055) ** 2.4
        for channel in srgb
    )
    return linear + (1.0,)


def material(name, color, roughness=0.62, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = rgba(color)
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = rgba(color)
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = metallic
    return mat


FUR = material("M2 Ivory Fur", "DED3B9", 0.88)
FUR_LIGHT = material("M2 Warm White Fur", "F8F4E8", 0.9)
INNER_EAR = material("M2 Inner Ear", "C58F83", 0.82)
NOSE = material("M2 Rose Nose", "A66F65", 0.72)
EYE_WHITE = material("M2 Eye Ivory", "D8D0B9", 0.5)
PUPIL = material("M2 Soft Black Pupil", "172022", 0.32)
COAT = material("M2 Deep Navy Coat", "193843", 0.8)
COAT_LIGHT = material("M2 Tailored Navy", "254B56", 0.78)
WAISTCOAT = material("M2 Burgundy Waistcoat", "6B2E4C", 0.72)
TROUSERS = material("M2 Charcoal Trousers", "222528", 0.9)
GOLD = material("M2 Antique Gold", "B98C3E", 0.34, 0.62)
LEATHER = material("M2 Brown Leather", "503429", 0.72)
BOOT = material("M2 Umber Boots", "4B4037", 0.86)
TAIL_STRIPE = material("M2 Tail Stripe", "8B877D", 0.9)

# One authoritative rounded coat profile drives the body shell, curved front
# quarters, lapels, piping, embroidery, and belt. Using the same surface model
# prevents the former flat decorative boards from floating off the torso sides.
COAT_PROFILE = [
    (0.60, 0.50, 0.29, 0, 0.02),
    (0.66, 0.56, 0.33, 0, 0.015),
    (0.78, 0.60, 0.35, 0, 0.01),
    (0.98, 0.62, 0.37, 0, 0.00),
    (1.24, 0.61, 0.37, 0, 0.00),
    (1.48, 0.57, 0.35, 0, 0.005),
    (1.68, 0.50, 0.31, 0, 0.01),
    (1.82, 0.42, 0.26, 0, 0.02),
    (1.86, 0.37, 0.23, 0, 0.02),
]

# The arm volume and every embroidered sleeve detail sample this same profile.
# Centers are authored for the left side and mirrored for the right side.
SLEEVE_PROFILE = [
    (0.68, 0.135, 0.145, 0.73, -0.020),
    (0.78, 0.145, 0.155, 0.73, -0.018),
    (0.90, 0.160, 0.170, 0.71, -0.010),
    (1.14, 0.185, 0.200, 0.68, -0.005),
    (1.40, 0.210, 0.225, 0.60, 0.000),
    (1.60, 0.200, 0.215, 0.52, 0.010),
    (1.72, 0.160, 0.175, 0.46, 0.015),
    (1.79, 0.080, 0.095, 0.425, 0.020),
]


def smooth_mesh(obj):
    if obj.type == "MESH":
        for polygon in obj.data.polygons:
            polygon.use_smooth = True


def apply_modifier(obj, modifier):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def bind(obj, bone_name):
    group = obj.vertex_groups.new(name=bone_name)
    group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    modifier = obj.modifiers.new("Milo2 Armature", "ARMATURE")
    modifier.object = RIG
    world_transform = obj.matrix_world.copy()
    obj.parent = RIG
    obj.matrix_world = world_transform
    obj["milo2_bone"] = bone_name
    MODEL_OBJECTS.append(obj)
    return obj


def blend_vertical_weights(obj, moving_bone, anchor_bone, start_z, end_z):
    """Keep a deforming garment root attached while its lower section moves.

    Vertices below start_z stay on moving_bone. Vertices above end_z stay on
    anchor_bone; the interval between them is a smooth linear shoulder blend.
    """
    moving = obj.vertex_groups.get(moving_bone)
    anchor = obj.vertex_groups.get(anchor_bone) or obj.vertex_groups.new(name=anchor_bone)
    span = max(end_z - start_z, 0.0001)
    for vertex in obj.data.vertices:
        anchor_weight = max(0.0, min(1.0, (vertex.co.z - start_z) / span))
        moving.add([vertex.index], 1.0 - anchor_weight, "REPLACE")
        anchor.add([vertex.index], anchor_weight, "REPLACE")
    obj["milo2_weight_blend"] = f"{moving_bone}->{anchor_bone}:{start_z:.2f}-{end_z:.2f}"
    return obj


def smoothstep(edge0, edge1, value):
    t = max(0.0, min(1.0, (value - edge0) / max(edge1 - edge0, 0.0001)))
    return t * t * (3.0 - 2.0 * t)


def blend_sleeve_weights(obj, upper_bone, lower_bone, wrist_bone):
    """Continuous chest -> upper arm -> forearm -> wrist weighting for one sleeve."""
    upper = obj.vertex_groups.get(upper_bone)
    chest = obj.vertex_groups.get("chest") or obj.vertex_groups.new(name="chest")
    lower = obj.vertex_groups.get(lower_bone) or obj.vertex_groups.new(name=lower_bone)
    wrist = obj.vertex_groups.get(wrist_bone) or obj.vertex_groups.new(name=wrist_bone)
    for vertex in obj.data.vertices:
        z = vertex.co.z
        chest_weight = smoothstep(1.42, 1.72, z)
        wrist_weight = 1.0 - smoothstep(0.70, 0.84, z)
        arm_weight = max(0.0, 1.0 - chest_weight - wrist_weight)
        lower_weight = arm_weight * (1.0 - smoothstep(1.05, 1.28, z))
        upper_weight = arm_weight - lower_weight
        total = max(chest_weight + upper_weight + lower_weight + wrist_weight, 0.0001)
        chest.add([vertex.index], chest_weight / total, "REPLACE")
        upper.add([vertex.index], upper_weight / total, "REPLACE")
        lower.add([vertex.index], lower_weight / total, "REPLACE")
        wrist.add([vertex.index], wrist_weight / total, "REPLACE")
    obj["milo2_weight_blend"] = f"chest->{upper_bone}->{lower_bone}->{wrist_bone}"
    return obj


def uv(name, location, scale, mat, bone, segments=40, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=rings, location=location
    )
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    smooth_mesh(obj)
    return bind(obj, bone)


def rounded_box(name, location, scale, mat, bone, bevel=0.12, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    modifier = obj.modifiers.new("Soft tailored corners", "BEVEL")
    modifier.width = bevel
    modifier.segments = 4
    apply_modifier(obj, modifier)
    obj.data.materials.append(mat)
    smooth_mesh(obj)
    return bind(obj, bone)


def curve_mesh(name, points, bevel, mat, bone, cyclic=False, resolution=4, radii=None, sharp=False):
    data = bpy.data.curves.new(name + "Curve", "CURVE")
    data.dimensions = "3D"
    data.resolution_u = resolution
    data.bevel_resolution = 4
    data.bevel_depth = bevel
    spline = data.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for index, (point, coordinate) in enumerate(zip(spline.bezier_points, points)):
        point.co = coordinate
        point.handle_left_type = "VECTOR" if sharp else "AUTO"
        point.handle_right_type = "VECTOR" if sharp else "AUTO"
        if radii is not None:
            point.radius = radii[index]
    spline.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.object
    obj.select_set(False)
    smooth_mesh(obj)
    return bind(obj, bone)


def moustache_leaf(name, outline_xz, mat, bone):
    """Create a smooth, shallow sculpted leaf from a closed X/Z outline."""
    data = bpy.data.curves.new(name + "Curve", "CURVE")
    data.dimensions = "2D"
    data.resolution_u = 16
    data.resolution_v = 8
    data.fill_mode = "BOTH"
    data.extrude = 0.028
    data.bevel_depth = 0.012
    data.bevel_resolution = 5
    spline = data.splines.new("BEZIER")
    spline.bezier_points.add(len(outline_xz) - 1)
    for index, (point, (x, z)) in enumerate(zip(spline.bezier_points, outline_xz)):
        point.co = (x, z, 0)
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
        if index == 6:  # Preserve the reference's crisp upswept outer tip.
            point.handle_left_type = "VECTOR"
            point.handle_right_type = "VECTOR"
    spline.use_cyclic_u = True
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = (0, -0.680, 0)
    obj.rotation_euler = (math.pi / 2, 0, 0)
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.object
    obj.select_set(False)
    smooth_mesh(obj)
    obj["milo2_moustache_shape"] = "closed rounded reference leaf with upswept tip"
    return bind(obj, bone)


def torus(name, location, major, minor, mat, bone, rotation=(math.pi / 2, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major, minor_radius=minor,
        major_segments=48, minor_segments=10,
        location=location, rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    smooth_mesh(obj)
    return bind(obj, bone)


def wedge(name, x_sign, outer=True):
    center_x = 0.46 * x_sign
    y_front = -0.30 if outer else -0.225
    y_back = -0.04 if outer else -0.185
    base_z = 2.62 if outer else 2.69
    tip_z = 3.13 if outer else 3.00
    half = 0.25 if outer else 0.105
    verts = [
        (center_x - half * x_sign, y_front, base_z),
        (center_x + half * x_sign, y_front, base_z + 0.03),
        (center_x + 0.08 * x_sign, y_front, tip_z),
        (center_x - half * x_sign, y_back, base_z),
        (center_x + half * x_sign, y_back, base_z + 0.03),
        (center_x + 0.08 * x_sign, y_back, tip_z),
    ]
    faces = [(0, 2, 1), (3, 4, 5), (0, 3, 5, 2), (1, 2, 5, 4), (0, 1, 4, 3)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(FUR if outer else INNER_EAR)
    bevel = obj.modifiers.new("Rounded ear edge", "BEVEL")
    bevel.width = 0.004 if outer else 0.003
    bevel.segments = 3
    apply_modifier(obj, bevel)
    smooth_mesh(obj)
    return bind(obj, "head")


def panel(name, points_xz, depth, mat, bone, y=-0.39, bevel=0.025):
    verts = [(x, y - depth, z) for x, z in points_xz] + [(x, y + depth, z) for x, z in points_xz]
    count = len(points_xz)
    faces = [tuple(range(count)), tuple(range(count, count * 2))[::-1]]
    for i in range(count):
        j = (i + 1) % count
        faces.append((i, j, count + j, count + i))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    modifier = obj.modifiers.new("Tailored edge", "BEVEL")
    modifier.width = bevel
    modifier.segments = 3
    apply_modifier(obj, modifier)
    smooth_mesh(obj)
    return bind(obj, bone)


def coat_ring_at(z):
    """Linearly sample the shared coat profile at a requested height."""
    if z <= COAT_PROFILE[0][0]:
        return COAT_PROFILE[0]
    if z >= COAT_PROFILE[-1][0]:
        return COAT_PROFILE[-1]
    for lower, upper in zip(COAT_PROFILE, COAT_PROFILE[1:]):
        if lower[0] <= z <= upper[0]:
            t = (z - lower[0]) / max(upper[0] - lower[0], 0.0001)
            return tuple(
                lower[index] + (upper[index] - lower[index]) * t
                for index in range(5)
            )
    return COAT_PROFILE[-1]


def coat_surface_y(x, z):
    _, radius_x, radius_y, center_x, center_y = coat_ring_at(z)
    normalized_x = max(-0.999, min(0.999, (x - center_x) / max(radius_x, 0.0001)))
    return center_y - radius_y * math.sqrt(max(0.0, 1.0 - normalized_x * normalized_x))


def coat_points(points_xz, lift=0.0):
    return [(x, coat_surface_y(x, z) - lift, z) for x, z in points_xz]


def sleeve_ring_at(z):
    """Linearly sample the continuous sleeve profile at a requested height."""
    if z <= SLEEVE_PROFILE[0][0]:
        return SLEEVE_PROFILE[0]
    if z >= SLEEVE_PROFILE[-1][0]:
        return SLEEVE_PROFILE[-1]
    for lower, upper in zip(SLEEVE_PROFILE, SLEEVE_PROFILE[1:]):
        if lower[0] <= z <= upper[0]:
            t = (z - lower[0]) / max(upper[0] - lower[0], 0.0001)
            return tuple(
                lower[index] + (upper[index] - lower[index]) * t
                for index in range(5)
            )
    return SLEEVE_PROFILE[-1]


def sleeve_front_point(side, x, z, embed=0.006):
    """Place thin decoration directly against the curved front sleeve shell."""
    _, radius_x, radius_y, center_x, center_y = sleeve_ring_at(z)
    normalized_x = max(-0.999, min(0.999, (x - center_x) / max(radius_x, 0.0001)))
    y = center_y - radius_y * math.sqrt(max(0.0, 1.0 - normalized_x * normalized_x))
    return (x * side, y - embed, z)


def conformed_coat_panel(name, points_xz, thickness, mat, bone, lift=0.008, bevel=0.012):
    """Create a thin panel whose every vertex follows the rounded coat shell."""
    front = [
        (x, coat_surface_y(x, z) - lift - thickness * 0.5, z)
        for x, z in points_xz
    ]
    back = [
        (x, coat_surface_y(x, z) - lift + thickness * 0.5, z)
        for x, z in points_xz
    ]
    verts = front + back
    count = len(points_xz)
    faces = [tuple(range(count)), tuple(range(count, count * 2))[::-1]]
    for index in range(count):
        following = (index + 1) % count
        faces.append((index, following, count + following, count + index))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    modifier = obj.modifiers.new("Conformed tailored edge", "BEVEL")
    modifier.width = bevel
    modifier.segments = 3
    apply_modifier(obj, modifier)
    smooth_mesh(obj)
    obj["milo2_attachment"] = "conformed to shared rounded coat profile"
    return bind(obj, bone)


def loft_volume(name, rings, mat, bone, segments=32):
    """Create a smooth tailored volume from z/x-radius/y-radius/x/y ring data."""
    verts = []
    for z, radius_x, radius_y, center_x, center_y in rings:
        for index in range(segments):
            angle = math.tau * index / segments
            verts.append((
                center_x + math.cos(angle) * radius_x,
                center_y + math.sin(angle) * radius_y,
                z,
            ))
    faces = []
    for ring_index in range(len(rings) - 1):
        start = ring_index * segments
        next_start = (ring_index + 1) * segments
        for index in range(segments):
            following = (index + 1) % segments
            faces.append((start + index, start + following,
                          next_start + following, next_start + index))
    faces.append(tuple(reversed(range(segments))))
    top_start = (len(rings) - 1) * segments
    faces.append(tuple(top_start + index for index in range(segments)))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    smooth_mesh(obj)
    return bind(obj, bone)


def continuous_tail(name, path, radii, materials, material_pattern, segments=20):
    """Build one connected, tapered, striped tail weighted across three bones."""
    verts = []
    for index, center_value in enumerate(path):
        center = Vector(center_value)
        if index == 0:
            tangent = (Vector(path[1]) - center).normalized()
        elif index == len(path) - 1:
            tangent = (center - Vector(path[index - 1])).normalized()
        else:
            tangent = (Vector(path[index + 1]) - Vector(path[index - 1])).normalized()
        frame_y = Vector((0, 1, 0))
        frame_z = tangent.cross(frame_y).normalized()
        for side in range(segments):
            angle = math.tau * side / segments
            offset = frame_y * math.cos(angle) + frame_z * math.sin(angle)
            verts.append(tuple(center + offset * radii[index]))
    faces = []
    face_materials = []
    for ring_index in range(len(path) - 1):
        start = ring_index * segments
        next_start = (ring_index + 1) * segments
        for side in range(segments):
            following = (side + 1) % segments
            faces.append((start + side, start + following,
                          next_start + following, next_start + side))
            face_materials.append(material_pattern[ring_index])
    faces.append(tuple(reversed(range(segments))))
    face_materials.append(material_pattern[0])
    top_start = (len(path) - 1) * segments
    faces.append(tuple(top_start + side for side in range(segments)))
    face_materials.append(material_pattern[-1])
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for mat in materials:
        obj.data.materials.append(mat)
    for polygon, material_index in zip(obj.data.polygons, face_materials):
        polygon.material_index = material_index
        polygon.use_smooth = True
    first_break = max(2, len(path) // 3)
    second_break = max(first_break + 1, (len(path) * 2) // 3)
    bone_ranges = (("tail.1", range(0, first_break)),
                   ("tail.2", range(first_break, second_break)),
                   ("tail.3", range(second_break, len(path))))
    for bone_name, ring_range in bone_ranges:
        group = obj.vertex_groups.new(name=bone_name)
        indices = [ring * segments + side for ring in ring_range for side in range(segments)]
        group.add(indices, 1.0, "REPLACE")
    modifier = obj.modifiers.new("Milo2 Armature", "ARMATURE")
    modifier.object = RIG
    world_transform = obj.matrix_world.copy()
    obj.parent = RIG
    obj.matrix_world = world_transform
    MODEL_OBJECTS.append(obj)
    return obj


def create_rig():
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    rig = bpy.context.object
    rig.name = "Milo2_Rig"
    armature = rig.data
    armature.name = "Milo2_Skeleton_41"
    # Remove Blender's placeholder and author a complete 41-bone hierarchy.
    armature.edit_bones.remove(armature.edit_bones[0])
    definitions = [
        ("root", (0, 0, 0.05), (0, 0, 0.22), None),
        ("hips", (0, 0, 0.55), (0, 0, 0.88), "root"),
        ("spine", (0, 0, 0.88), (0, 0, 1.18), "hips"),
        ("chest", (0, 0, 1.18), (0, 0, 1.72), "spine"),
        ("neck", (0, 0, 1.72), (0, 0, 1.78), "chest"),
        ("head", (0, 0, 1.72), (0, 0, 2.52), "chest"),
        ("upperarm.l", (0.48, 0, 1.55), (0.74, 0, 1.20), "chest"),
        ("lowerarm.l", (0.74, 0, 1.20), (0.78, 0, 0.86), "upperarm.l"),
        ("wrist.l", (0.78, 0, 0.86), (0.77, -0.02, 0.72), "lowerarm.l"),
        ("hand.l", (0.77, -0.02, 0.72), (0.77, -0.04, 0.54), "wrist.l"),
        ("upperarm.r", (-0.48, 0, 1.55), (-0.74, 0, 1.20), "chest"),
        ("lowerarm.r", (-0.74, 0, 1.20), (-0.78, 0, 0.86), "upperarm.r"),
        ("wrist.r", (-0.78, 0, 0.86), (-0.77, -0.02, 0.72), "lowerarm.r"),
        ("hand.r", (-0.77, -0.02, 0.72), (-0.77, -0.04, 0.54), "wrist.r"),
        ("upperleg.l", (0.28, 0, 0.72), (0.30, 0, 0.42), "hips"),
        ("lowerleg.l", (0.30, 0, 0.42), (0.31, -0.01, 0.20), "upperleg.l"),
        ("foot.l", (0.31, 0, 0.20), (0.31, -0.27, 0.12), "lowerleg.l"),
        ("toes.l", (0.31, -0.27, 0.12), (0.31, -0.43, 0.12), "foot.l"),
        ("upperleg.r", (-0.28, 0, 0.72), (-0.30, 0, 0.42), "hips"),
        ("lowerleg.r", (-0.30, 0, 0.42), (-0.31, -0.01, 0.20), "upperleg.r"),
        ("foot.r", (-0.31, 0, 0.20), (-0.31, -0.27, 0.12), "lowerleg.r"),
        ("toes.r", (-0.31, -0.27, 0.12), (-0.31, -0.43, 0.12), "foot.r"),
        ("tail.1", (0.28, 0.18, 0.72), (0.63, 0.22, 0.58), "hips"),
        ("tail.2", (0.63, 0.22, 0.58), (0.83, 0.18, 0.70), "tail.1"),
        ("tail.3", (0.83, 0.18, 0.70), (0.92, 0.12, 0.95), "tail.2"),
        ("ear.l", (0.34, 0, 2.55), (0.50, 0, 3.08), "head"),
        ("ear.r", (-0.34, 0, 2.55), (-0.50, 0, 3.08), "head"),
        ("brow.l", (0.17, -0.28, 2.51), (0.36, -0.33, 2.56), "head"),
        ("brow.r", (-0.17, -0.28, 2.51), (-0.36, -0.33, 2.56), "head"),
        ("jaw", (0, -0.30, 2.05), (0, -0.42, 1.91), "head"),
        ("moustache.l", (0.02, -0.43, 2.10), (0.48, -0.45, 2.00), "head"),
        ("moustache.r", (-0.02, -0.43, 2.10), (-0.48, -0.45, 2.00), "head"),
        ("coat.l", (0.12, -0.24, 1.55), (0.46, -0.30, 0.75), "chest"),
        ("coat.r", (-0.12, -0.24, 1.55), (-0.46, -0.30, 0.75), "chest"),
        ("coat.tail.l", (0.12, 0.24, 1.12), (0.43, 0.27, 0.62), "hips"),
        ("coat.tail.r", (-0.12, 0.24, 1.12), (-0.43, 0.27, 0.62), "hips"),
        ("finger.l", (0.77, -0.04, 0.65), (0.77, -0.16, 0.55), "hand.l"),
        ("finger.r", (-0.77, -0.04, 0.65), (-0.77, -0.16, 0.55), "hand.r"),
        ("glasses", (0, -0.28, 2.39), (0, -0.45, 2.39), "head"),
        ("waistcoat", (0, -0.26, 1.48), (0, -0.38, 0.83), "chest"),
        ("belt", (0, -0.30, 1.00), (0, -0.43, 1.00), "chest"),
    ]
    for name, head, tail, parent in definitions:
        bone = armature.edit_bones.new(name)
        bone.head = head
        bone.tail = tail
        if parent:
            bone.parent = armature.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.show_in_front = True
    rig.hide_render = True
    rig["milo2_origin"] = "blank_scene_clean_room"
    rig["milo2_bone_count"] = len(definitions)
    return rig


MODEL_OBJECTS = []
RIG = create_rig()
MODEL_OBJECTS.append(RIG)

# Body and clothing: smooth flared tailoring, directly joined to the head.
uv("M2_Body_Core", (0, 0.02, 1.13), (0.51, 0.32, 0.66), FUR, "chest")
loft_volume("M2_Coat_Body", COAT_PROFILE, COAT, "chest", 48)
conformed_coat_panel("M2_Waistcoat", [(-0.09, 1.72), (0.09, 1.72),
                         (0.16, 1.58), (0.17, 0.86), (0.10, 0.70),
                         (0, 0.61), (-0.10, 0.70), (-0.17, 0.86),
                         (-0.16, 1.58)],
      0.018, WAISTCOAT, "waistcoat", 0.018, 0.018)

# Curved front quarters restore the long tailored coat read without box objects.
conformed_coat_panel("M2_Coat_Left_Quarter", [
    (-0.50, 1.70), (-0.38, 1.66), (-0.27, 1.56), (-0.21, 1.42),
    (-0.18, 1.24), (-0.17, 1.02), (-0.18, 0.82), (-0.22, 0.70),
    (-0.31, 0.64), (-0.43, 0.62), (-0.53, 0.67), (-0.59, 0.80),
    (-0.61, 1.00), (-0.60, 1.24), (-0.56, 1.49),
], 0.020, COAT_LIGHT, "coat.r", 0.008, 0.016)
conformed_coat_panel("M2_Coat_Right_Quarter", [
    (0.50, 1.70), (0.38, 1.66), (0.27, 1.56), (0.21, 1.42),
    (0.18, 1.24), (0.17, 1.02), (0.18, 0.82), (0.22, 0.70),
    (0.31, 0.64), (0.43, 0.62), (0.53, 0.67), (0.59, 0.80),
    (0.61, 1.00), (0.60, 1.24), (0.56, 1.49),
], 0.020, COAT_LIGHT, "coat.l", 0.008, 0.016)

# Burgundy waistcoat closure and gold buttons.
for z in (1.48, 1.27, 1.06):
    for x in (-0.075, 0.075):
        button_y = coat_surface_y(x, z) - 0.045
        uv(f"M2_Waistcoat_Button_{x}_{z}", (x, button_y, z), (0.028, 0.012, 0.028), GOLD, "waistcoat", 24, 12)
    curve_mesh(f"M2_Button_Link_{z}", coat_points([
        (-0.043, z), (0.043, z),
    ], 0.045), 0.006, GOLD, "waistcoat")

# Lapels follow the coat curvature and ride the same side bones as their host
# quarters. Two non-overlapping collar leaves replace the former three-layer
# shirt/collar pile; the tapered waistcoat closes the neckline behind them.
conformed_coat_panel("M2_Lapel_L", [(0.045, 1.72), (0.34, 1.55), (0.19, 1.33)],
                     0.014, COAT_LIGHT, "coat.l", 0.035, 0.010)
conformed_coat_panel("M2_Lapel_R", [(-0.045, 1.72), (-0.34, 1.55), (-0.19, 1.33)],
                     0.014, COAT_LIGHT, "coat.r", 0.035, 0.010)
conformed_coat_panel("M2_Collar_L", [(0.0, 1.73), (-0.15, 1.67), (-0.060, 1.56)],
      0.008, FUR_LIGHT, "chest", 0.052, 0.003)
conformed_coat_panel("M2_Collar_R", [(0.0, 1.73), (0.15, 1.67), (0.060, 1.56)],
      0.008, FUR_LIGHT, "chest", 0.052, 0.003)
for side in (-1, 1):
    coat_bone = "coat.l" if side > 0 else "coat.r"
    curve_mesh(f"M2_Gold_Lapel_{side}", coat_points([
        (0.050 * side, 1.705), (0.20 * side, 1.64),
        (0.32 * side, 1.54), (0.25 * side, 1.42),
        (0.19 * side, 1.33),
    ], 0.040), 0.006, GOLD, coat_bone)
    curve_mesh(f"M2_Gold_Front_Edge_{side}", coat_points([
        (0.19 * side, 1.33), (0.18 * side, 1.02), (0.18 * side, 0.72),
    ], 0.024), 0.006, GOLD, coat_bone)
    curve_mesh(f"M2_Gold_Hem_{side}", coat_points([
        (0.18 * side, 0.70), (0.36 * side, 0.65), (0.56 * side, 0.70),
    ], 0.024), 0.006, GOLD, coat_bone)

# A curved leather belt samples the same shell instead of bridging it as a
# straight floating bar. Buckle and tongue overlap the belt at the centre.
curve_mesh("M2_Belt_Front", coat_points([
    (-0.60, 0.99), (-0.46, 0.99), (-0.25, 0.99), (0.0, 0.99),
    (0.25, 0.99), (0.46, 0.99), (0.60, 0.99),
], 0.022), 0.015, LEATHER, "belt")
_belt_center_y = coat_surface_y(0.0, 0.99) - 0.045
curve_mesh("M2_Belt_Buckle", [(-0.085, _belt_center_y, 1.028), (0.085, _belt_center_y, 1.028),
                               (0.085, _belt_center_y, 0.952), (-0.085, _belt_center_y, 0.952)],
           0.010, GOLD, "belt", True, 4)
rounded_box("M2_Belt_Tongue", (0, _belt_center_y + 0.004, 0.86), (0.043, 0.012, 0.13), LEATHER, "belt", 0.020)

# Medieval clover embroidery, restrained and readable at game distance.
for side in (-1, 1):
    for z in (1.16, 0.82):
        x = 0.43 * side
        coat_bone = "coat.l" if side > 0 else "coat.r"
        curve_mesh(f"M2_Clover_H_{side}_{z}", coat_points([
            (x - 0.035, z), (x + 0.035, z),
        ], 0.024), 0.006, GOLD, coat_bone)
        curve_mesh(f"M2_Clover_V_{side}_{z}", coat_points([
            (x, z - 0.035), (x, z + 0.035),
        ], 0.024), 0.006, GOLD, coat_bone)

# Legs and broad, grounded boots. The bevel is nearly the full half-height so
# the toe and heel read as one soft, rounded shoe instead of a softened cube.
for side, suffix in ((1, "l"), (-1, "r")):
    uv(f"M2_Trouser_{suffix}", (0.30 * side, 0.02, 0.49), (0.25, 0.27, 0.42), TROUSERS, f"upperleg.{suffix}")
    rounded_box(f"M2_Boot_{suffix}", (0.31 * side, -0.10, 0.21), (0.30, 0.37, 0.19), BOOT, f"foot.{suffix}", 0.175)
    curve_mesh(f"M2_Boot_Seam_{suffix}", [(0.05 * side, -0.44, 0.255), (0.31 * side, -0.49, 0.300), (0.57 * side, -0.44, 0.255)], 0.010, LEATHER, f"foot.{suffix}")

# Each sleeve is one uninterrupted shoulder-to-wrist volume. Its lower profile
# forms the fitted wrist naturally; there is no separate cuff mesh or blue pod.
# Hands hang as compact cat paws with their digit fan rotated 90 degrees away
# from the camera: the back of each paw is the dominant resting silhouette.
for side, suffix in ((1, "l"), (-1, "r")):
    upper = f"upperarm.{suffix}"
    lower = f"lowerarm.{suffix}"
    wrist = f"wrist.{suffix}"
    hand = f"hand.{suffix}"
    sleeve = loft_volume(f"M2_Sleeve_{suffix}", [
        (z, radius_x, radius_y, center_x * side, center_y)
        for z, radius_x, radius_y, center_x, center_y in SLEEVE_PROFILE
    ], COAT_LIGHT, upper, 36)
    blend_sleeve_weights(sleeve, upper, lower, wrist)
    # A fitted double wrist border finishes the coat without adding a separate
    # cuff volume. Both rings are thin piping and move with the wrist bone.
    torus(f"M2_Sleeve_Cuff_Piping_Lower_{suffix}", (0.73 * side, -0.02, 0.705), 0.140, 0.0055, GOLD, wrist, (0, 0, 0))
    torus(f"M2_Sleeve_Cuff_Piping_Upper_{suffix}", (0.73 * side, -0.018, 0.765), 0.145, 0.0045, GOLD, wrist, (0, 0, 0))

    # Two calm shoulder arcs follow the tailored shoulder cap. This replaces
    # the former competing chevrons and long dangling seam with one hierarchy.
    curve_mesh(f"M2_Sleeve_Shoulder_Piping_Outer_{suffix}", [
        sleeve_front_point(side, 0.435, 1.665),
        sleeve_front_point(side, 0.525, 1.700),
        sleeve_front_point(side, 0.625, 1.645),
        sleeve_front_point(side, 0.705, 1.555),
    ], 0.0065, GOLD, upper, False, 7)
    curve_mesh(f"M2_Sleeve_Shoulder_Piping_Inner_{suffix}", [
        sleeve_front_point(side, 0.465, 1.590),
        sleeve_front_point(side, 0.550, 1.625),
        sleeve_front_point(side, 0.645, 1.575),
        sleeve_front_point(side, 0.710, 1.505),
    ], 0.0045, GOLD, upper, False, 7)

    # One small medieval diamond-knot marks the forearm. Its closed outline is
    # sampled point-by-point from the sleeve, so no corner floats above the arm.
    curve_mesh(f"M2_Sleeve_Diamond_Knot_{suffix}", [
        sleeve_front_point(side, 0.680, 1.245),
        sleeve_front_point(side, 0.735, 1.180),
        sleeve_front_point(side, 0.680, 1.115),
        sleeve_front_point(side, 0.625, 1.180),
    ], 0.0055, GOLD, lower, True, 6, sharp=True)
    curve_mesh(f"M2_Sleeve_Diamond_Spine_{suffix}", [
        sleeve_front_point(side, 0.680, 1.215),
        sleeve_front_point(side, 0.680, 1.180),
        sleeve_front_point(side, 0.680, 1.145),
    ], 0.0035, GOLD, lower, False, 5)
    uv(f"M2_Palm_{suffix}", (0.73 * side, -0.035, 0.65), (0.175, 0.145, 0.18), FUR, hand, 40, 24)
    # The previous x-axis finger fan looked like a human hand pasted sideways.
    # This front-to-back fan is its requested 90-degree rotation and reads as a
    # single feline paw from the front while retaining deformable digits.
    finger_depths = (-0.105, -0.070, -0.035, 0.000)
    for index, y in enumerate(finger_depths):
        x = (0.735 + (index - 1.5) * 0.008) * side
        z = 0.582 + 0.005 * (1 - abs(index - 1.5))
        uv(f"M2_Finger_{suffix}_{index + 1}", (x, y, z), (0.050, 0.052, 0.066), FUR, hand, 32, 18)
    uv(f"M2_Thumb_{suffix}", (0.625 * side, -0.065, 0.665), (0.055, 0.058, 0.084), FUR, hand, 32, 18)

# Dense oval head gives the target's uninterrupted dome; muzzle, brows, ears,
# moustache and cheek tufts provide the non-spherical facial structure.
uv("M2_Head", (0, -0.015, 2.22), (0.76, 0.56, 0.64), FUR, "head", 72, 48)
for side, suffix in ((1, "L"), (-1, "R")):
    loft_volume(f"M2_Ear_{suffix}", [
        (2.57, 0.25, 0.19, 0.42 * side, -0.03),
        (2.70, 0.22, 0.16, 0.43 * side, -0.03),
        (2.88, 0.13, 0.095, 0.46 * side, -0.03),
        (3.07, 0.012, 0.016, 0.49 * side, -0.03),
    ], FUR, "head", 24)
    # A nested loft follows the outer ear's complete taper. Its root and rim
    # overlap the outer shell so the pink layer is fitted, not a floating badge.
    loft_volume(f"M2_Inner_Ear_{suffix}", [
        (2.64, 0.165, 0.020, 0.42 * side, -0.210),
        (2.73, 0.145, 0.020, 0.435 * side, -0.185),
        (2.88, 0.082, 0.016, 0.460 * side, -0.135),
        (3.015, 0.010, 0.008, 0.482 * side, -0.082),
    ], INNER_EAR, "head", 24)

# Layered cheek tufts create a feline side silhouette instead of a plain sphere.
for side, suffix in ((1, "L"), (-1, "R")):
    for index, (x, z, scale) in enumerate(((0.70, 2.18, 0.15), (0.76, 2.10, 0.12), (0.70, 2.02, 0.10))):
        uv(f"M2_Cheek_Tuft_{suffix}_{index}", (x * side, -0.20, z), (scale, 0.10, scale * 0.58), FUR_LIGHT, "head", 32, 18)

# Keep the expressive target eyes, but reduce their dominance so Milo shares the
# compact humanoid facial rhythm of the in-game Rogue rather than an insect mask.
for side, suffix in ((1, "L"), (-1, "R")):
    x = 0.27 * side
    uv(f"M2_Eye_{suffix}", (x, -0.548, 2.37), (0.195, 0.058, 0.235), EYE_WHITE, "head", 48, 28)
    uv(f"M2_Pupil_{suffix}", (x, -0.607, 2.37), (0.080, 0.026, 0.142), PUPIL, "head", 40, 24)
    curve_mesh(f"M2_Brow_{suffix}", [(0.14 * side, -0.602, 2.69), (0.27 * side, -0.625, 2.73), (0.40 * side, -0.602, 2.69)], 0.032, FUR_LIGHT, "head")

# Gold spectacles: separate rims, bridge, and temples, all attached to the face.
for side, suffix in ((1, "L"), (-1, "R")):
    torus(f"M2_Glasses_Rim_{suffix}", (0.27 * side, -0.624, 2.38), 0.232, 0.018, GOLD, "glasses")
    curve_mesh(f"M2_Glasses_Temple_{suffix}", [(0.48 * side, -0.60, 2.40), (0.70 * side, -0.41, 2.40)], 0.010, GOLD, "glasses")
curve_mesh("M2_Glasses_Bridge", [(-0.02, -0.645, 2.40), (0, -0.665, 2.43), (0.02, -0.645, 2.40)], 0.017, GOLD, "glasses")

# Small rose nose and a two-piece sculpted moustache rebuilt from the supplied
# reference: broad leaf-like lobes, deep lower bellies, and upswept pointed tips.
# The halves overlap beneath the nose so there is no center gap.
uv("M2_Nose", (0, -0.674, 2.13), (0.105, 0.060, 0.075), NOSE, "head", 40, 24)
for side, suffix in ((1, "L"), (-1, "R")):
    moustache_outline = [
        (-0.030 * side, 2.095),
        (0.055 * side, 2.175),
        (0.175 * side, 2.220),
        (0.300 * side, 2.205),
        (0.420 * side, 2.145),
        (0.535 * side, 2.080),
        (0.700 * side, 2.155),
        (0.640 * side, 2.045),
        (0.525 * side, 1.975),
        (0.380 * side, 1.925),
        (0.235 * side, 1.940),
        (0.105 * side, 2.005),
        (-0.010 * side, 2.060),
    ]
    moustache_leaf(
        f"M2_Moustache_Leaf_{suffix}", moustache_outline,
        FUR_LIGHT, f"moustache.{suffix.lower()}",
    )
    # Two recessed-looking layered strokes reproduce the carved fur channels
    # visible in the reference without cutting holes into the primary lobe.
    curve_mesh(f"M2_Moustache_Ridge_Lower_{suffix}", [
        (0.080 * side, -0.724, 2.075),
        (0.245 * side, -0.729, 1.990),
        (0.430 * side, -0.725, 1.985),
        (0.590 * side, -0.712, 2.070),
    ], 0.0080, FUR, f"moustache.{suffix.lower()}", False, 6, [0.35, 0.65, 0.55, 0.12])
    curve_mesh(f"M2_Moustache_Ridge_Upper_{suffix}", [
        (0.085 * side, -0.725, 2.125),
        (0.260 * side, -0.731, 2.060),
        (0.455 * side, -0.721, 2.075),
        (0.625 * side, -0.700, 2.135),
    ], 0.0060, FUR, f"moustache.{suffix.lower()}", False, 6, [0.30, 0.58, 0.46, 0.10])

# A single connected, curled and tapered tail; stripe materials do not split it.
continuous_tail("M2_Continuous_Tail", [
    (0.36, 0.30, 0.58), (0.53, 0.31, 0.51), (0.70, 0.31, 0.49),
    (0.84, 0.29, 0.53), (0.94, 0.26, 0.61), (0.98, 0.22, 0.70),
    (0.95, 0.17, 0.79), (0.87, 0.12, 0.86),
], [0.132, 0.131, 0.126, 0.118, 0.106, 0.088, 0.060, 0.025],
                [FUR, TAIL_STRIPE, FUR_LIGHT], [0, 0, 1, 1, 0, 2, 2], 24)


def unify_character_mesh():
    """Consolidate authored regions into one production skinned mesh.

    Head, face, torso, clothing, arms, paws, fingers, legs, boots and tail remain
    independently shapeable through their material indices and bone vertex groups.
    They are not separate scene objects in the final Blender/GLB delivery.
    """
    mesh_parts = [obj for obj in MODEL_OBJECTS if obj.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in mesh_parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = mesh_parts[0]
    bpy.ops.object.join()
    unified = bpy.context.object
    unified.name = "Milo2_Unified_Skinned_Character"

    # Every final surface is explicitly triangulated for predictable web/Godot
    # deformation. High-resolution source spheres and multi-segment bevels provide
    # the triangle density; smooth normals provide the soft reference finish.
    triangulate = unified.modifiers.new("Milo2 Final Triangulation", "TRIANGULATE")
    triangulate.quad_method = "BEAUTY"
    triangulate.ngon_method = "BEAUTY"
    apply_modifier(unified, triangulate)
    smooth_mesh(unified)

    unified["milo2_mesh_architecture"] = "one unified skinned mesh"
    unified["milo2_design_regions"] = (
        "head,face,torso,coat,arms,paws,fingers,legs,boots,tail"
    )
    unified["milo2_surface"] = "dense triangles with smooth normals"
    unified["milo2_source_part_count"] = len(mesh_parts)

    MODEL_OBJECTS[:] = [RIG, unified]
    return unified


UNIFIED_CHARACTER = unify_character_mesh()


def key_pose(action, frame, rotations=None, locations=None):
    RIG.animation_data.action = action
    rotations = rotations or {}
    locations = locations or {}
    for bone_name, degrees in rotations.items():
        pose_bone = RIG.pose.bones[bone_name]
        pose_bone.rotation_mode = "XYZ"
        pose_bone.rotation_euler = tuple(math.radians(value) for value in degrees)
        pose_bone.keyframe_insert("rotation_euler", frame=frame, group=bone_name)
    for bone_name, offset in locations.items():
        pose_bone = RIG.pose.bones[bone_name]
        pose_bone.location = offset
        pose_bone.keyframe_insert("location", frame=frame, group=bone_name)


def reset_pose():
    for pose_bone in RIG.pose.bones:
        pose_bone.rotation_mode = "XYZ"
        pose_bone.rotation_euler = (0, 0, 0)
        pose_bone.location = (0, 0, 0)


RIG.animation_data_create()

# Calm breathing, slight head thoughtfulness, and a slow tail counter-sway.
idle = bpy.data.actions.new("Milo2_Idle")
idle.use_fake_user = True
key_pose(idle, 1, {"head": (0, 0, -2), "tail.2": (0, 5, 0)}, {"hips": (0, 0, 0)})
key_pose(idle, 36, {"head": (1.5, 0, 2), "chest": (0.8, 0, 0), "tail.2": (0, -7, 0)}, {"hips": (0, 0, 0.018)})
key_pose(idle, 72, {"head": (0, 0, -2), "tail.2": (0, 5, 0)}, {"hips": (0, 0, 0)})

# Short-legged, planted biped walk with opposite arm swing and mild body bounce.
reset_pose()
walk = bpy.data.actions.new("Milo2_Walk")
walk.use_fake_user = True
key_pose(walk, 1, {"upperleg.l": (23, 0, 0), "upperleg.r": (-23, 0, 0), "upperarm.l": (-16, 0, 0), "upperarm.r": (16, 0, 0), "tail.1": (0, -6, 0)}, {"hips": (0, 0, 0)})
key_pose(walk, 12, {"upperleg.l": (0, 0, 0), "upperleg.r": (0, 0, 0), "lowerleg.l": (16, 0, 0), "lowerleg.r": (0, 0, 0), "upperarm.l": (0, 0, 0), "upperarm.r": (0, 0, 0)}, {"hips": (0, 0, 0.025)})
key_pose(walk, 24, {"upperleg.l": (-23, 0, 0), "upperleg.r": (23, 0, 0), "upperarm.l": (16, 0, 0), "upperarm.r": (-16, 0, 0), "tail.1": (0, 6, 0)}, {"hips": (0, 0, 0)})
key_pose(walk, 36, {"upperleg.l": (0, 0, 0), "upperleg.r": (0, 0, 0), "lowerleg.l": (0, 0, 0), "lowerleg.r": (16, 0, 0), "upperarm.l": (0, 0, 0), "upperarm.r": (0, 0, 0)}, {"hips": (0, 0, 0.025)})
key_pose(walk, 48, {"upperleg.l": (23, 0, 0), "upperleg.r": (-23, 0, 0), "upperarm.l": (-16, 0, 0), "upperarm.r": (16, 0, 0), "tail.1": (0, -6, 0)}, {"hips": (0, 0, 0)})

# Friendly wave: elbow bends naturally before the wrist swings.
reset_pose()
wave = bpy.data.actions.new("Milo2_Wave")
wave.use_fake_user = True
key_pose(wave, 1, {"upperarm.l": (0, 0, 0), "lowerarm.l": (0, 0, 0), "hand.l": (0, 0, 0), "head": (0, 0, 0)})
key_pose(wave, 14, {"upperarm.l": (0, 0, -95), "lowerarm.l": (75, -45, 120), "hand.l": (0, 0, -15), "head": (0, 0, -4)})
key_pose(wave, 25, {"upperarm.l": (0, 0, -95), "lowerarm.l": (75, -45, 120), "hand.l": (0, 0, 18), "head": (0, 0, -4)})
key_pose(wave, 36, {"upperarm.l": (0, 0, -95), "lowerarm.l": (75, -45, 120), "hand.l": (0, 0, -18), "head": (0, 0, -4)})
key_pose(wave, 52, {"upperarm.l": (0, 0, 0), "lowerarm.l": (0, 0, 0), "hand.l": (0, 0, 0), "head": (0, 0, 0)})

reset_pose()
RIG.animation_data.action = idle

# Quality metadata is preserved in both Blender and glTF custom properties.
RIG["milo2_required_animations"] = "Milo2_Idle,Milo2_Walk,Milo2_Wave"
RIG["milo2_reference"] = "milo2/reference/milo2_target.png"
RIG["milo2_no_original_dependency"] = True
RIG["milo2_delivery_mesh_count"] = 1
RIG["milo2_paw_finger_fan_rotation_degrees"] = 90
RIG["milo2_ear_inset"] = "nested fitted loft embedded in outer ear shell"
RIG["milo2_style_reference"] = "target Milo plus compact humanoid in-game NPC proportions"
RIG["milo2_garment_sync"] = "shoulder-root blended to chest; belt parented to chest; cuff trim closed and fitted"
RIG["milo2_arm_construction"] = "single continuous sleeve loft from shoulder to wrist; no separate cuff volume"
RIG["milo2_style_refinement"] = "reference-shaped sculpted moustache leaves; capsule-rounded boots; tailored shoulder piping, diamond-knot and double wrist border"

# Studio render environment.
bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, -0.01))
ground = bpy.context.object
ground.name = "Milo2_Render_Ground"
ground.data.materials.append(material("M2 Studio Ground", "17212B", 0.78))

world = bpy.data.worlds.new("Milo2 Studio World")
bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = rgba("071018")
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.22


def point_camera(camera, target):
    direction = Vector(target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


bpy.ops.object.camera_add(location=(2.15, -8.15, 3.05))
camera = bpy.context.object
camera.name = "Milo2_Reference_Camera"
camera.data.lens = 72
point_camera(camera, (0, 0, 1.55))
bpy.context.scene.camera = camera

for name, location, energy, size, color in (
    ("M2 Key", (-3.8, -4.5, 6.0), 800, 4.0, "FFE7C7"),
    ("M2 Fill", (4.0, -2.8, 3.4), 420, 3.5, "CBE4FF"),
    ("M2 Rim", (1.5, 3.8, 5.0), 780, 3.0, "FFF2D7"),
):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.name = name
    light.data.energy = energy
    light.data.shape = "DISK"
    light.data.size = size
    light.data.color = rgba(color)[:3]
    point_camera(light, (0, 0, 1.45))

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 800
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
scene.render.filepath = str(RENDER_OUT)
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.frame_set(1)

# Save the fully editable source before producing delivery outputs.
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUT))

# Export only the independent rig and character meshes; studio objects stay in .blend.
bpy.ops.object.select_all(action="DESELECT")
for obj in MODEL_OBJECTS:
    obj.select_set(True)
bpy.context.view_layer.objects.active = RIG
bpy.ops.export_scene.gltf(
    filepath=str(GLB_OUT),
    export_format="GLB",
    use_selection=True,
    export_animations=True,
    export_skins=True,
    export_morph=False,
    export_extras=True,
)

# Render after export with the same rest-pose composition used for comparison.
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.render.render(write_still=True)

mesh_count = sum(1 for obj in MODEL_OBJECTS if obj.type == "MESH")
triangle_count = sum(
    len(obj.data.loop_triangles) if obj.type == "MESH" else 0
    for obj in MODEL_OBJECTS
)
print(f"MILO2_BUILD: blank-scene independent build complete")
print(f"MILO2_BUILD: {len(RIG.data.bones)} bones, {mesh_count} unified skinned mesh")
print(f"MILO2_BUILD: {triangle_count} source triangles")
print(f"MILO2_BUILD: {BLEND_OUT}")
print(f"MILO2_BUILD: {GLB_OUT}")
print(f"MILO2_BUILD: {RENDER_OUT}")
