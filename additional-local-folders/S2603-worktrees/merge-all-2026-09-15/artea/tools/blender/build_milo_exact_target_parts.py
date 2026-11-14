"""Build Mayor Milo as individually inspectable, rigged target-matched parts.

The generated Blender file contains two reference-image empties:

* ``TARGET_CARD`` displays the opaque approved target beside the model.
* ``TARGET_OVERLAY`` displays the same target semi-transparently over Milo.

Toggle the overlay with the collection named ``00_TARGET_REFERENCE``.  Every
feature is a separate object, grouped by numbered collection, so eyes, ears,
nose, clothing, limbs and tail can be compared and adjusted independently.
"""

from __future__ import annotations

import math
import json
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree


ROOT = Path(__file__).resolve().parents[2]
SOURCE_RIG = ROOT / "assets3D/characters/Barbarian.glb"
REFERENCE_SHEET = ROOT / "artifacts/milo_reference_side_by_side.png"
REFERENCE_CROP = ROOT / "artifacts/milo_exact_target_crop.png"
OUTPUT_BLEND = ROOT / "assets3D/characters/milo_exact_target_parts.blend"
OUTPUT_GLB = ROOT / "assets3D/characters/milo_exact_target_parts.glb"
OUTPUT_RENDER = ROOT / "artifacts/milo_exact_target_parts_render.png"
OUTPUT_360_RENDERS = {
    "front": ROOT / "artifacts/milo_360_front.png",
    "right": ROOT / "artifacts/milo_360_right.png",
    "back": ROOT / "artifacts/milo_360_back.png",
    "left": ROOT / "artifacts/milo_360_left.png",
}
MEASUREMENT_SPEC = ROOT / "tools/blender/milo_measured_npc_spec.json"

# Pixel bounds of the left "EXACT TARGET" panel in the repository comparison.
TARGET_BOX_TOP_LEFT = (15, 80, 495, 840)
OVERLAY_OPACITY = 0.32
MEASUREMENTS = json.loads(MEASUREMENT_SPEC.read_text())


def crop_reference(source_path: Path, output_path: Path) -> bpy.types.Image:
    source = bpy.data.images.load(str(source_path), check_existing=False)
    width, height = source.size
    left, top, right, bottom = TARGET_BOX_TOP_LEFT
    left = max(0, min(left, width))
    right = max(left + 1, min(right, width))
    top = max(0, min(top, height))
    bottom = max(top + 1, min(bottom, height))
    crop_width = right - left
    crop_height = bottom - top
    source_bottom = height - bottom
    source_pixels = list(source.pixels[:])
    crop_pixels = [0.0] * (crop_width * crop_height * 4)
    for y in range(crop_height):
        source_start = ((source_bottom + y) * width + left) * 4
        target_start = y * crop_width * 4
        crop_pixels[target_start:target_start + crop_width * 4] = (
            source_pixels[source_start:source_start + crop_width * 4]
        )
    crop = bpy.data.images.new("MiloExactTarget", crop_width, crop_height)
    crop.pixels.foreach_set(crop_pixels)
    crop.filepath_raw = str(output_path)
    crop.file_format = "PNG"
    crop.save()
    return crop


def make_collection(name: str) -> bpy.types.Collection:
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def link_only(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    collection.objects.link(obj)


def material(name: str, hex_color: str, roughness: float = 0.58,
             metallic: float = 0.0) -> bpy.types.Material:
    rgb = tuple(int(hex_color[index:index + 2], 16) / 255 for index in (0, 2, 4))
    value = bpy.data.materials.new(name)
    value.diffuse_color = (*rgb, 1.0)
    value.use_nodes = True
    bsdf = value.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    # Preserve the soft painted style while retaining enough PBR range for
    # polished eyes, shoes and gold to catch readable highlights in Godot.
    # The former 0.30/0.45 clamps flattened those materials into the same dull
    # response as the coat fabric.
    finish_roughness = max(0.16, min(0.88, roughness))
    finish_metallic = max(0.0, min(0.72, metallic))
    bsdf.inputs["Roughness"].default_value = finish_roughness
    bsdf.inputs["Metallic"].default_value = finish_metallic
    # Blender's glTF exporter reads these material-level values when there are
    # no texture maps. Keep them synchronized with the preview shader so the
    # Godot GLB does not fall back to Blender's uniform 0.58 roughness.
    value.roughness = finish_roughness
    value.metallic = finish_metallic
    specular = bsdf.inputs.get("IOR Level")
    if specular is not None:
        specular.default_value = 0.34 if metallic < 0.1 else 0.48
    return value


def finish(obj: bpy.types.Object, name: str, mat: bpy.types.Material,
           bone: str, collection: bpy.types.Collection,
           smooth: bool = False) -> bpy.types.Object:
    obj.name = name
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if obj.type == "MESH":
        for polygon in obj.data.polygons:
            polygon.use_smooth = smooth
        obj.data.materials.append(mat)
        group = obj.vertex_groups.new(name=bone)
        group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    link_only(obj, collection)
    obj["milo_part"] = name
    obj["target_reference"] = str(REFERENCE_CROP)
    obj["style_language"] = "artea_soft_chibi_lowpoly"
    parts.append(obj)
    return obj


def sphere(name, location, scale, mat, bone, collection,
           segments=24, rings=16, rotation=(0, 0, 0)):
    segments = min(segments, 12)
    rings = min(rings, 7)
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=rings, location=location, rotation=rotation
    )
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat, bone, collection, smooth=True)


def clean_ellipsoid(name, location, scale, mat, bone, collection,
                    segments=24, rings=12):
    """Create a smooth single-shell ellipsoid for close facial features."""
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=rings, location=location
    )
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat, bone, collection, smooth=True)


def eye_cap(name, center, radii_xz, center_y, edge_y, mat, bone,
            collection, segments=24):
    """Create one domed front surface without concentric eyeball shells."""
    center_x, center_z = center
    radius_x, radius_z = radii_xz
    verts = [(center_x, center_y, center_z)]
    for index in range(segments):
        angle = 2.0 * math.pi * index / segments
        verts.append((center_x + radius_x * math.cos(angle), edge_y,
                      center_z + radius_z * math.sin(angle)))
    faces = []
    for index in range(segments):
        next_index = (index + 1) % segments
        faces.append((0, index + 1, next_index + 1))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return finish(obj, name, mat, bone, collection, smooth=True)


def torus(name, location, major, minor, mat, bone, collection,
          rotation=(math.pi / 2, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major, minor_radius=minor, major_segments=16,
        minor_segments=6, location=location, rotation=rotation
    )
    return finish(bpy.context.object, name, mat, bone, collection, smooth=True)


def cube(name, location, scale, mat, bone, collection, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=location)
    obj = bpy.context.object
    obj.scale = scale
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Target soft bevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return finish(obj, name, mat, bone, collection, smooth=True)


def domed_button(name, location, radius, depth, mat, bone, collection,
                 sides=8):
    """Create a tailored low-poly button, with a flat back and domed rim."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=sides, radius=radius, depth=depth, location=location,
        rotation=(math.pi / 2, 0, 0)
    )
    obj = bpy.context.object
    modifier = obj.modifiers.new("Button domed rim", "BEVEL")
    modifier.width = min(radius * 0.22, depth * 0.35)
    modifier.segments = 2
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return finish(obj, name, mat, bone, collection, smooth=True)


def prism(name, verts, faces, mat, bone, collection, bevel=0.0):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    if bevel:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        modifier = obj.modifiers.new("Target rounded edge", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return finish(obj, name, mat, bone, collection, smooth=False)


def panel(name, outline, y_front, thickness, mat, bone, collection, bevel=0.0):
    count = len(outline)
    verts = [(x, y_front, z) for x, z in outline]
    verts += [(x, y_front + thickness, z) for x, z in outline]
    faces = [tuple(range(count))[::-1], tuple(range(count, count * 2))]
    for index in range(count):
        next_index = (index + 1) % count
        faces.append((index, next_index, count + next_index, count + index))
    return prism(name, verts, faces, mat, bone, collection, bevel)


def surface_panel(name, front_outline, thickness, mat, bone, collection,
                  bevel=0.0):
    """Extrude a panel whose vertices follow a rounded host surface in depth."""
    count = len(front_outline)
    verts = list(front_outline)
    verts += [(x, y + thickness, z) for x, y, z in front_outline]
    faces = [tuple(range(count))[::-1], tuple(range(count, count * 2))]
    for index in range(count):
        next_index = (index + 1) % count
        faces.append((index, next_index, count + next_index, count + index))
    return prism(name, verts, faces, mat, bone, collection, bevel)


def vector_extruded_panel(name, front_outline, extrusion, mat, bone,
                          collection, bevel=0.0):
    """Extrude a fitted panel along an arbitrary vector (used at coat sides)."""
    count = len(front_outline)
    offset = Vector(extrusion)
    verts = list(front_outline)
    verts += [tuple(Vector(point) + offset) for point in front_outline]
    faces = [tuple(range(count))[::-1], tuple(range(count, count * 2))]
    for index in range(count):
        next_index = (index + 1) % count
        faces.append((index, next_index, count + next_index, count + index))
    return prism(name, verts, faces, mat, bone, collection, bevel)


def tapered_panel(name, front_outline, back_depths, mat, bone, collection,
                  bevel=0.0):
    """Extrude a panel with per-vertex depth so pointed forms taper in 3D."""
    count = len(front_outline)
    if count != len(back_depths):
        raise ValueError("tapered panel requires one depth per outline vertex")
    verts = list(front_outline)
    verts += [(x, y + depth, z)
              for (x, y, z), depth in zip(front_outline, back_depths)]
    faces = [tuple(range(count))[::-1], tuple(range(count, count * 2))]
    for index in range(count):
        next_index = (index + 1) % count
        faces.append((index, next_index, count + next_index, count + index))
    return prism(name, verts, faces, mat, bone, collection, bevel)


def sculpted_ear_shell(name, front_outline, back_depths, rear_ridges,
                       mat, bone, collection, bevel=0.0):
    """Create a closed ear with individually shaded rear shell facets."""
    count = len(front_outline)
    if count != 7 or count != len(back_depths) or len(rear_ridges) != 2:
        raise ValueError("ear shell requires seven outline and two ridge points")
    back_outline = [(x, y + depth, z)
                    for (x, y, z), depth in zip(front_outline, back_depths)]
    lower_ridge = count * 2
    upper_ridge = lower_ridge + 1
    verts = list(front_outline) + back_outline + list(rear_ridges)
    faces = [tuple(range(count))[::-1]]
    for index in range(count):
        next_index = (index + 1) % count
        faces.append((index, next_index, count + next_index, count + index))
    back = [count + index for index in range(count)]
    faces.extend([
        (back[0], back[1], lower_ridge),
        (back[1], back[2], lower_ridge),
        (back[2], upper_ridge, lower_ridge),
        (back[2], back[3], upper_ridge),
        (back[3], back[4], upper_ridge),
        (back[4], back[5], upper_ridge),
        (back[5], lower_ridge, upper_ridge),
        (back[5], back[6], lower_ridge),
        (back[6], back[0], lower_ridge),
    ])
    return prism(name, verts, faces, mat, bone, collection, bevel)


def surface_strip(name, top_row, bottom_row, thickness, mat, bone, collection,
                  bevel=0.0):
    """Build a segmented strip that follows each facet of a curved host."""
    count = len(top_row)
    if count != len(bottom_row):
        raise ValueError("surface strip rows must have equal vertex counts")
    top_back = [(x, y + thickness, z) for x, y, z in top_row]
    bottom_back = [(x, y + thickness, z) for x, y, z in bottom_row]
    verts = list(top_row) + list(bottom_row) + top_back + bottom_back
    top_front = 0
    bottom_front = count
    top_rear = count * 2
    bottom_rear = count * 3
    faces = []
    for index in range(count - 1):
        next_index = index + 1
        faces.append((top_front + index, top_front + next_index,
                      bottom_front + next_index, bottom_front + index))
        faces.append((top_rear + next_index, top_rear + index,
                      bottom_rear + index, bottom_rear + next_index))
        faces.append((top_front + index, top_rear + index,
                      top_rear + next_index, top_front + next_index))
        faces.append((bottom_front + next_index, bottom_rear + next_index,
                      bottom_rear + index, bottom_front + index))
    faces.append((top_front, bottom_front, bottom_rear, top_rear))
    last = count - 1
    faces.append((top_front + last, top_rear + last,
                  bottom_rear + last, bottom_front + last))
    return prism(name, verts, faces, mat, bone, collection, bevel)


def coat_bottom_trim(name, ring_spec, mat, bone, collection, segments=12,
                     inner_clearance=0.006, outer_clearance=0.012,
                     height=0.015):
    """Build one mitered 360-degree hem outside every coat-bottom facet."""
    z, radius_x, radius_y, center_y = ring_spec[:4]
    z_offsets = ring_spec[4] if len(ring_spec) > 4 else [0.0] * segments
    base_xy = [Vector((radius_x * math.cos(2.0 * math.pi * index / segments),
                       center_y + radius_y * math.sin(2.0 * math.pi * index / segments)))
               for index in range(segments)]

    def offset_polygon(clearance):
        offset = []
        for index, current in enumerate(base_xy):
            previous = base_xy[(index - 1) % segments]
            following = base_xy[(index + 1) % segments]
            incoming = (current - previous).normalized()
            outgoing = (following - current).normalized()
            incoming_normal = Vector((incoming.y, -incoming.x))
            outgoing_normal = Vector((outgoing.y, -outgoing.x))
            miter = (incoming_normal + outgoing_normal).normalized()
            miter_scale = clearance / max(miter.dot(outgoing_normal), 1e-6)
            offset.append(current + miter * miter_scale)
        return offset

    inner_xy = offset_polygon(inner_clearance)
    outer_xy = offset_polygon(outer_clearance)
    inner_bottom = [(point.x, point.y, z + z_offsets[index] - 0.001)
                    for index, point in enumerate(inner_xy)]
    inner_top = [(point.x, point.y, z + z_offsets[index] + height)
                 for index, point in enumerate(inner_xy)]
    outer_bottom = [(point.x, point.y, z + z_offsets[index] - 0.001)
                    for index, point in enumerate(outer_xy)]
    outer_top = [(point.x, point.y, z + z_offsets[index] + height)
                 for index, point in enumerate(outer_xy)]
    verts = inner_bottom + inner_top + outer_bottom + outer_top
    faces = []
    for index in range(segments):
        next_index = (index + 1) % segments
        inner_bottom_i = index
        inner_top_i = segments + index
        outer_bottom_i = segments * 2 + index
        outer_top_i = segments * 3 + index
        inner_bottom_next = next_index
        inner_top_next = segments + next_index
        outer_bottom_next = segments * 2 + next_index
        outer_top_next = segments * 3 + next_index
        faces.extend([
            (outer_bottom_i, outer_bottom_next,
             outer_top_next, outer_top_i),
            (inner_bottom_next, inner_bottom_i,
             inner_top_i, inner_top_next),
            (inner_top_i, outer_top_i, outer_top_next, inner_top_next),
            (inner_bottom_next, outer_bottom_next,
             outer_bottom_i, inner_bottom_i),
        ])
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj["minimum_coat_clearance"] = inner_clearance
    print(f"MILO_HEM_CLEARANCE: {name} {inner_clearance:.6f}")
    return finish(obj, name, mat, bone, collection, smooth=False)


def fitted_elliptical_cuff(name, center, inner_radii, outer_radii, z_range,
                           mat, bone, collection, segments=12,
                           sleeve_radii=(0.088, 0.102),
                           limb_axis=(0.0, 0.0, -1.0)):
    """Build a faceted cuff rail outside the elliptical sleeve/hand joint.

    A circular torus cuts through Milo's wider front-to-back sleeve profile.
    This closed elliptical rail follows that profile instead, with its inner
    wall kept outside the sleeve and paw envelope on every facet.
    """
    center_x, center_y = center
    inner_x, inner_y = inner_radii
    outer_x, outer_y = outer_radii
    z_bottom, z_top = z_range
    axis = Vector(limb_axis).normalized()
    depth_axis = Vector((0.0, 1.0, 0.0))
    profile_axis = depth_axis.cross(axis).normalized()
    center_point = Vector((center_x, center_y, (z_bottom + z_top) * 0.5))
    half_height = (z_top - z_bottom) * 0.5
    rings = []
    for radius_x, radius_y, longitudinal in (
            (inner_x, inner_y, -half_height),
            (inner_x, inner_y, half_height),
            (outer_x, outer_y, -half_height),
            (outer_x, outer_y, half_height)):
        ring_center = center_point + axis * longitudinal
        rings.append([
            tuple(ring_center
                  + profile_axis * radius_x
                  * math.cos(2.0 * math.pi * index / segments)
                  + depth_axis * radius_y
                  * math.sin(2.0 * math.pi * index / segments))
            for index in range(segments)
        ])
    verts = [vertex for ring in rings for vertex in ring]
    faces = []
    for index in range(segments):
        next_index = (index + 1) % segments
        inner_bottom = index
        inner_top = segments + index
        outer_bottom = segments * 2 + index
        outer_top = segments * 3 + index
        faces.extend([
            (outer_bottom, outer_bottom + (next_index - index),
             outer_top + (next_index - index), outer_top),
            (inner_bottom + (next_index - index), inner_bottom,
             inner_top, inner_top + (next_index - index)),
            (inner_top, outer_top,
             segments * 3 + next_index, segments + next_index),
            (next_index, segments * 2 + next_index,
             outer_bottom, inner_bottom),
        ])
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    sleeve_x, sleeve_y = sleeve_radii
    x_clearance = inner_x - sleeve_x
    front_clearance = (center_y - inner_y) - (-sleeve_y)
    rear_clearance = sleeve_y - (center_y + inner_y)
    minimum_clearance = min(x_clearance, abs(front_clearance),
                            abs(rear_clearance))
    if min(x_clearance, -front_clearance, -rear_clearance) < 0.0035:
        raise RuntimeError(f"{name} penetrates the sleeve envelope")
    obj["minimum_sleeve_clearance"] = minimum_clearance
    obj["fitted_to_elliptical_sleeve"] = True
    obj["aligned_to_wrist_axis"] = True
    print(f"MILO_CUFF_CLEARANCE: {name} {minimum_clearance:.6f}")
    return finish(obj, name, mat, bone, collection, smooth=False)


def tailored_coat_body(name, ring_specs, mat, bone, collection, segments=12):
    """Create one closed, tapered coat mesh that is also the torso body."""
    verts = []
    for ring_spec in ring_specs:
        z, radius_x, radius_y, center_y = ring_spec[:4]
        z_offsets = ring_spec[4] if len(ring_spec) > 4 else [0.0] * segments
        for index in range(segments):
            angle = (2.0 * math.pi * index) / segments
            verts.append((radius_x * math.cos(angle),
                          center_y + radius_y * math.sin(angle),
                          z + z_offsets[index]))
    faces = [tuple(range(segments))[::-1]]
    for ring_index in range(len(ring_specs) - 1):
        start = ring_index * segments
        next_start = start + segments
        for index in range(segments):
            next_index = (index + 1) % segments
            faces.append((start + index, start + next_index,
                          next_start + next_index, next_start + index))
    top_start = (len(ring_specs) - 1) * segments
    faces.append(tuple(range(top_start, top_start + segments)))
    return prism(name, verts, faces, mat, bone, collection, bevel=0.012)


def blend_coat_shoulders_into_armature(coat):
    """Let the coat crown follow each sleeve without turning it into a tube.

    The coat remains the torso mesh, but vertices near each armhole borrow a
    restrained amount of upper-arm motion. This is the cloth-equivalent of a
    sewn sleeve cap: the shoulder seam stays planted while the coat crown
    yields slightly when the arm swings.
    """
    chest = coat.vertex_groups.get("chest")
    if chest is None:
        raise RuntimeError("CoatBody lacks its chest binding")
    arm_groups = {
        -1: coat.vertex_groups.new(name="upperarm.r"),
        1: coat.vertex_groups.new(name="upperarm.l"),
    }
    maximum_arm_weight = 0.0
    influenced_vertices = 0
    for vertex in coat.data.vertices:
        side = -1 if vertex.co.x < 0.0 else 1
        height = max(0.0, min(1.0, (vertex.co.z - 0.955) / 0.225))
        lateral = max(0.0, min(1.0, (abs(vertex.co.x) - 0.205) / 0.135))
        height = height * height * (3.0 - 2.0 * height)
        lateral = lateral * lateral * (3.0 - 2.0 * lateral)
        arm_weight = 0.16 * height * lateral
        if arm_weight <= 1e-5:
            continue
        chest.add([vertex.index], 1.0 - arm_weight, "REPLACE")
        arm_groups[side].add([vertex.index], arm_weight, "REPLACE")
        maximum_arm_weight = max(maximum_arm_weight, arm_weight)
        influenced_vertices += 1
    coat["sewn_sleeve_cap_response"] = True
    coat["shoulder_arm_weight_max"] = maximum_arm_weight
    coat["shoulder_influenced_vertices"] = influenced_vertices
    return coat


def verify_coat_shoulder_response(coat):
    """Reject a rigid or over-flexible coat shoulder before export."""
    used = set()
    max_arm_weight = 0.0
    influenced = 0
    for vertex in coat.data.vertices:
        total = 0.0
        vertex_arm_weight = 0.0
        for assignment in vertex.groups:
            group_name = coat.vertex_groups[assignment.group].name
            used.add(group_name)
            total += assignment.weight
            if group_name.startswith("upperarm."):
                vertex_arm_weight += assignment.weight
        if abs(total - 1.0) > 1e-5:
            raise RuntimeError(
                f"CoatBody vertex {vertex.index} weight sum {total:.6f}"
            )
        if vertex_arm_weight > 1e-5:
            influenced += 1
            max_arm_weight = max(max_arm_weight, vertex_arm_weight)
    required = {"chest", "upperarm.r", "upperarm.l"}
    if not required.issubset(used) or influenced < 8:
        raise RuntimeError("CoatBody shoulders do not respond to both sleeves")
    if max_arm_weight < 0.12 or max_arm_weight > 0.17:
        raise RuntimeError(
            f"CoatBody shoulder response is out of range: {max_arm_weight:.3f}"
        )
    print(f"MILO_COAT_SHOULDER_RESPONSE: {influenced} vertices, "
          f"maximum upper-arm weight {max_arm_weight:.3f}")


def weighted_tapered_limb(name, rings, ring_weights, mat, collection,
                          segments=12, orient_to_path=False,
                          fixed_ring_count=0):
    """Create one connected tapered limb with smooth weights along its chain."""
    if len(rings) != len(ring_weights):
        raise ValueError("limb rings and weight rows must have equal length")
    verts = []
    depth_axis = Vector((0.0, 1.0, 0.0))
    centers = [Vector(ring[:3]) for ring in rings]
    for ring_index, (center_x, center_y, center_z,
                     radius_x, radius_y) in enumerate(rings):
        center = centers[ring_index]
        if orient_to_path:
            if ring_index == 0:
                tangent = centers[1] - center
            elif ring_index == len(centers) - 1:
                tangent = center - centers[ring_index - 1]
            else:
                tangent = centers[ring_index + 1] - centers[ring_index - 1]
            tangent.normalize()
            path_profile_axis = depth_axis.cross(tangent).normalized()
            if fixed_ring_count > 0:
                blend = min(1.0, ring_index / float(fixed_ring_count))
                blend = blend * blend * (3.0 - 2.0 * blend)
                profile_axis = Vector((1.0, 0.0, 0.0)).lerp(
                    path_profile_axis, blend).normalized()
            else:
                profile_axis = path_profile_axis
        else:
            profile_axis = Vector((1.0, 0.0, 0.0))
        for index in range(segments):
            angle = 2.0 * math.pi * index / segments
            vertex = center + profile_axis * radius_x * math.cos(angle) \
                + depth_axis * radius_y * math.sin(angle)
            verts.append(tuple(vertex))
    faces = [tuple(range(segments))[::-1]]
    for ring_index in range(len(rings) - 1):
        start = ring_index * segments
        next_start = start + segments
        for index in range(segments):
            next_index = (index + 1) % segments
            faces.append((start + index, start + next_index,
                          next_start + next_index, next_start + index))
    last_start = (len(rings) - 1) * segments
    faces.append(tuple(range(last_start, last_start + segments)))

    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    first_bone = ring_weights[0][0][0]
    finish(obj, name, mat, first_bone, collection, smooth=True)
    for group in list(obj.vertex_groups):
        obj.vertex_groups.remove(group)
    groups = {}
    for ring_index, weights in enumerate(ring_weights):
        indices = list(range(ring_index * segments,
                             (ring_index + 1) * segments))
        for bone_name, weight in weights:
            group = groups.get(bone_name)
            if group is None:
                group = obj.vertex_groups.new(name=bone_name)
                groups[bone_name] = group
            group.add(indices, weight, "REPLACE")
    if orient_to_path:
        obj["cross_sections_follow_limb_axis"] = True
        obj["fixed_socket_ring_count"] = fixed_ring_count
    return obj


def scale_limb_profile(rings, radius_scales, clearance_preservation):
    """Scale limb thickness while controlling its inner attachment edge.

    A blind radial scale pulls a large sleeve back through Milo's coat. For the
    free arm, the centerline moves outward by a matching portion of the radius
    increase, preserving the established torso clearance. The preservation
    amount then eases to zero at the wrist so the hand and cuff stay aligned.
    """
    if len(rings) != len(radius_scales) \
            or len(rings) != len(clearance_preservation):
        raise ValueError("limb scale profiles must match the ring count")
    scaled = []
    for ring, radius_scale, preserve in zip(
            rings, radius_scales, clearance_preservation):
        center_x, center_y, center_z, radius_x, radius_y = ring
        side = -1.0 if center_x < 0.0 else 1.0
        outward_shift = side * radius_x * (radius_scale - 1.0) * preserve
        scaled.append((center_x + outward_shift, center_y, center_z,
                       radius_x * radius_scale, radius_y * radius_scale))
    return scaled


def faceted_mitten_paw(name, center_x, center_z, side, style, mat, bone,
                       collection):
    """Sculpt one fused hand volume, then recess its front finger grooves.

    Metaballs create one watertight palm/thumb/finger skin. Boolean impressions
    are then carved only into its front surface, matching the reference's real
    sculpted separations without adding any visible or disconnected objects.
    """
    field = bpy.data.metaballs.new(name + "SculptField")
    field.resolution = 0.010
    field.render_resolution = 0.008
    field.threshold = 0.62
    field_obj = bpy.data.objects.new(name + "SculptField", field)
    bpy.context.scene.collection.objects.link(field_obj)

    def add_field(offset_x, offset_z, radius):
        element = field.elements.new()
        element.co = (center_x + offset_x * side, -0.040,
                      center_z + offset_z)
        element.radius = radius
        element.stiffness = 2.0

    # Four overlapping palm fields make a broad rounded box rather than a ball.
    for offset_x in (-0.032, 0.032):
        add_field(offset_x, 0.034, 0.084)
        add_field(offset_x, -0.026, 0.082)
    # Three lower fields form soft fingertip volumes in the same fused skin.
    finger_z = -0.066 if style == "relaxed" else -0.071
    add_field(-0.048, finger_z, 0.035)
    add_field(0.000, finger_z - 0.002, 0.037)
    add_field(0.048, finger_z, 0.035)
    # A short chain of small overlapping fields grows a low thumb pad directly
    # out of the palm. Keeping its root broad and its tip shallow prevents the
    # old marble-like thumb silhouette while preserving one watertight skin.
    add_field(-0.070, 0.022, 0.038)
    add_field(-0.090, 0.006, 0.034)
    add_field(-0.103, -0.012, 0.029)

    bpy.ops.object.select_all(action="DESELECT")
    field_obj.select_set(True)
    bpy.context.view_layer.objects.active = field_obj
    bpy.ops.object.convert(target="MESH")
    paw = bpy.context.object
    paw.data.name = name + "Mesh"
    # Fit the implicit surface to the measured front envelope and retain enough
    # depth for a soft dome. Metaball radii evaluate smaller than their nominal
    # field size at this threshold, so the fitted factors are deliberate.
    for vertex in paw.data.vertices:
        # Preserve the approved broad mitten envelope after replacing the old
        # protruding thumb mound with a low palm-grown pad.
        vertex.co.x = center_x + (vertex.co.x - center_x) * 1.23
        vertex.co.y = -0.040 + (vertex.co.y + 0.040) * 1.76
        vertex.co.z = center_z + (vertex.co.z - center_z) * 1.18
    paw.data.update()

    def carve_front_groove(cutter_name, location, scale, rotation=(0, 0, 0)):
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=16, ring_count=8, location=location, rotation=rotation)
        cutter = bpy.context.object
        cutter.name = cutter_name
        cutter.scale = scale
        bpy.context.view_layer.objects.active = cutter
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        modifier = paw.modifiers.new(cutter_name + "Difference", "BOOLEAN")
        modifier.operation = "DIFFERENCE"
        modifier.solver = "EXACT"
        modifier.object = cutter
        bpy.context.view_layer.objects.active = paw
        paw.select_set(True)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        bpy.data.objects.remove(cutter, do_unlink=True)

    # Two narrow bottom-up impressions separate three fingers. The relaxed
    # hand uses shallower grooves; the cane grip receives stronger definition.
    groove_depth = 0.032 if style == "relaxed" else 0.038
    groove_height = 0.025 if style == "relaxed" else 0.032
    for groove_x in (-0.026, 0.026):
        carve_front_groove(
            name + "FingerGroove", (center_x + groove_x * side, -0.122,
                                     center_z - 0.070),
            (0.006, groove_depth, groove_height))
    # A shallow angled crease suggests the thumb joint without cutting a deep
    # border that would make the pad read as a separate attached object.
    carve_front_groove(
        name + "ThumbGroove", (center_x - 0.084 * side, -0.116,
                                center_z + 0.004),
        (0.007, 0.029, 0.036),
        rotation=(0.0, math.radians(-6.0 * side), 0.0))

    # Reduce the implicit surface to the established soft low-poly density.
    decimate = paw.modifiers.new(name + "LowPoly", "DECIMATE")
    decimate.ratio = 0.34
    bpy.context.view_layer.objects.active = paw
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    paw.data.materials.clear()
    paw = finish(paw, name, mat, bone, collection, smooth=True)
    palm_angle = math.radians(90.0 * side)
    palm_cos = math.cos(palm_angle)
    palm_sin = math.sin(palm_angle)
    for vertex in paw.data.vertices:
        offset_x = vertex.co.x - center_x
        offset_y = vertex.co.y + 0.040
        vertex.co.x = center_x + palm_cos * offset_x - palm_sin * offset_y
        vertex.co.y = -0.040 + palm_sin * offset_x + palm_cos * offset_y
    paw.data.update()
    paw.shape_key_add(name="Basis", from_mix=False)
    curl_key = paw.shape_key_add(name="FingerCurl", from_mix=False)
    for vertex in curl_key.data:
        rotated_x = vertex.co.x - center_x
        rotated_y = vertex.co.y + 0.040
        original_x = palm_cos * rotated_x + palm_sin * rotated_y
        canonical_x = original_x * side
        lower_amount = max(0.0, min(1.0,
                           (center_z - 0.025 - vertex.co.z) / 0.078))
        if canonical_x > -0.100 and lower_amount > 0.0:
            original_delta_y = -0.026 * lower_amount
            vertex.co.x -= palm_sin * original_delta_y
            vertex.co.y += palm_cos * original_delta_y
            vertex.co.z += 0.036 * lower_amount
        elif canonical_x <= -0.075 and lower_amount > 0.0:
            # The low integrated thumb pad closes subtly with the finger row.
            original_delta_x = 0.010 * side * lower_amount
            vertex.co.x += palm_cos * original_delta_x
            vertex.co.y += palm_sin * original_delta_x
            vertex.co.z += 0.012 * lower_amount
    paw["milo_design_role"] = "%s unified sculpted hand" % style
    paw["continuous_hand_mesh"] = True
    paw["finger_lobe_count"] = 3
    paw["thumb_integrated"] = True
    paw["thumb_shape"] = "low_relief_palm_pad"
    paw["front_thumb_gap_depth"] = 0.012
    paw["front_thumb_gap_recess"] = 0.029
    paw["curl_shape_key"] = "FingerCurl"
    paw["sculpted_front_grooves"] = 3
    paw["palm_faces_side"] = True
    paw["palm_normal_x"] = side
    paw["finger_row_axis"] = "depth"
    paw["grip_axis_x"] = center_x + 0.010 * side
    return paw


def verify_unified_hand_fit(paw, style):
    """Prove the hand is one connected mesh with one whole-hand curl target."""
    adjacency = {vertex.index: set() for vertex in paw.data.vertices}
    for edge in paw.data.edges:
        a, b = edge.vertices
        adjacency[a].add(b)
        adjacency[b].add(a)
    visited = set()
    pending = [0]
    while pending:
        index = pending.pop()
        if index in visited:
            continue
        visited.add(index)
        pending.extend(adjacency[index] - visited)
    if len(visited) != len(paw.data.vertices):
        raise RuntimeError(f"{paw.name} contains disconnected finger pieces")
    if paw.data.shape_keys is None or "FingerCurl" not in paw.data.shape_keys.key_blocks:
        raise RuntimeError(f"{paw.name} lacks its unified finger curl deformation")
    gap_depth = float(paw.get("front_thumb_gap_depth", 0.0))
    if gap_depth < 0.008 or gap_depth > 0.016:
        raise RuntimeError(f"{paw.name} front thumb gap is not readable: {gap_depth}")
    gap_recess = float(paw.get("front_thumb_gap_recess", 0.0))
    if gap_recess < 0.024 or gap_recess > 0.034:
        raise RuntimeError(f"{paw.name} front thumb crease is not sculpted: {gap_recess}")
    if paw.get("thumb_shape", "") != "low_relief_palm_pad":
        raise RuntimeError(f"{paw.name} thumb is not integrated as a palm pad")
    if not paw.get("palm_faces_side", False) \
            or abs(float(paw.get("palm_normal_x", 0.0))) < 0.99:
        raise RuntimeError(f"{paw.name} palm does not face outward")
    verify_reference_hand_fit(paw, style)
    print(f"MILO_UNIFIED_HAND: {style} one connected object, "
          f"{len(paw.data.vertices)} vertices, thumb gap {gap_depth:.3f}, "
          f"recess {gap_recess:.3f}")


def horizontal_tapered_form(name, rings, mat, bone, collection,
                            segments=10, smooth=False):
    """Create a swept leaf form from elliptical Y/Z cross-sections."""
    verts = []
    for center_x, center_y, center_z, radius_y, radius_z in rings:
        for index in range(segments):
            angle = 2.0 * math.pi * index / segments
            verts.append((center_x,
                          center_y + radius_y * math.cos(angle),
                          center_z + radius_z * math.sin(angle)))
    faces = [tuple(range(segments))[::-1]]
    for ring_index in range(len(rings) - 1):
        start = ring_index * segments
        next_start = start + segments
        for index in range(segments):
            next_index = (index + 1) % segments
            faces.append((start + index, start + next_index,
                          next_start + next_index, next_start + index))
    last_start = (len(rings) - 1) * segments
    faces.append(tuple(range(last_start, last_start + segments)))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return finish(obj, name, mat, bone, collection, smooth=smooth)


def depth_tapered_form(name, rings, mat, bone, collection,
                       segments=10, smooth=False):
    """Create a swept fur/leaf form using elliptical X/Z cross-sections."""
    verts = []
    for center_x, center_y, center_z, radius_x, radius_z in rings:
        for index in range(segments):
            angle = 2.0 * math.pi * index / segments
            verts.append((center_x + radius_x * math.cos(angle),
                          center_y,
                          center_z + radius_z * math.sin(angle)))
    faces = [tuple(range(segments))[::-1]]
    for ring_index in range(len(rings) - 1):
        start = ring_index * segments
        next_start = start + segments
        for index in range(segments):
            next_index = (index + 1) % segments
            faces.append((start + index, start + next_index,
                          next_start + next_index, next_start + index))
    last_start = (len(rings) - 1) * segments
    faces.append(tuple(range(last_start, last_start + segments)))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return finish(obj, name, mat, bone, collection, smooth=smooth)


def head_back_point(x, z, clearance=0.0):
    """Sample Milo's rear head ellipsoid for blueprint-locked scalp plates."""
    center_y = -0.005
    center_z = 1.51
    radius_x = 0.46
    radius_y = 0.35
    radius_z = 0.43
    remaining = (1.0 - (x / radius_x) ** 2
                 - ((z - center_z) / radius_z) ** 2)
    if remaining < -1e-5:
        raise ValueError(f"rear-hair point falls outside head: {x}, {z}")
    return (x, center_y + radius_y * math.sqrt(max(0.0, remaining))
            + clearance, z)


def coat_ring_dimensions_at_z(z, ring_specs):
    """Interpolate the coat ring used by both geometry and fit validation."""
    lower = ring_specs[0]
    upper = ring_specs[-1]
    for index in range(len(ring_specs) - 1):
        if ring_specs[index][0] <= z <= ring_specs[index + 1][0]:
            lower = ring_specs[index]
            upper = ring_specs[index + 1]
            break
    span = max(upper[0] - lower[0], 1e-6)
    blend = max(0.0, min(1.0, (z - lower[0]) / span))
    radius_x = lower[1] + (upper[1] - lower[1]) * blend
    radius_y = lower[2] + (upper[2] - lower[2]) * blend
    center_y = lower[3] + (upper[3] - lower[3]) * blend
    return radius_x, radius_y, center_y


def faceted_coat_surface_y(x, z, ring_specs, rear=True, segments=12):
    """Return the exact front or rear Y of the low-poly coat at X/Z."""
    radius_x, radius_y, center_y = coat_ring_dimensions_at_z(z, ring_specs)

    surface_profile = []
    angle_start = 0.0 if rear else math.pi
    for index in range((segments // 2) + 1):
        angle = angle_start + math.pi * index / (segments // 2)
        surface_profile.append((radius_x * math.cos(angle),
                                center_y + radius_y * math.sin(angle)))
    surface_profile.sort(key=lambda point: point[0])
    for left, right in zip(surface_profile, surface_profile[1:]):
        if left[0] - 1e-6 <= x <= right[0] + 1e-6:
            amount = (x - left[0]) / max(right[0] - left[0], 1e-6)
            return left[1] + (right[1] - left[1]) * amount
    return center_y


def coat_facet_row(z, ring_specs, clearance, rear=True, segments=12,
                   first_index=1, last_index=5):
    """Sample a row on exact coat polygon boundaries, never across a facet."""
    radius_x, radius_y, center_y = coat_ring_dimensions_at_z(z, ring_specs)
    angle_start = 0.0 if rear else math.pi
    points = []
    for index in range(first_index, last_index + 1):
        angle = angle_start + math.pi * index / (segments // 2)
        direction = 1.0 if rear else -1.0
        points.append((radius_x * math.cos(angle),
                       center_y + radius_y * math.sin(angle)
                       + direction * clearance, z))
    points.sort(key=lambda point: point[0])
    return points


def verify_surface_clearance(host_name, detail_names, direction_xyz,
                             minimum=0.001):
    """Fail the build if a fitted detail touches or enters the coat."""
    host = bpy.data.objects[host_name]
    direction = Vector(direction_xyz)
    for detail_name in detail_names:
        detail = bpy.data.objects[detail_name]
        clearances = []
        for vertex in detail.data.vertices:
            hit, location, _normal, _face_index = host.ray_cast(
                vertex.co, direction, distance=1.0
            )
            if not hit:
                raise RuntimeError(f"{detail_name} does not project onto {host_name}")
            clearances.append((vertex.co - location).length)
        closest = min(clearances)
        if closest < minimum:
            raise RuntimeError(
                f"{detail_name} enters {host_name}: clearance {closest:.6f}"
            )
        print(f"MILO_SURFACE_CLEARANCE: {detail_name} {closest:.6f}")


def verify_faceted_coat_clearance(detail_names, ring_specs, rear,
                                  minimum=0.001):
    """Check vertices, edge midpoints and face centers against the coat skin."""
    for detail_name in detail_names:
        detail = bpy.data.objects[detail_name]
        samples = [detail.matrix_world @ vertex.co
                   for vertex in detail.data.vertices]
        for edge in detail.data.edges:
            edge_center = (detail.data.vertices[edge.vertices[0]].co
                           + detail.data.vertices[edge.vertices[1]].co) * 0.5
            samples.append(detail.matrix_world @ edge_center)
        for polygon in detail.data.polygons:
            center = Vector((0.0, 0.0, 0.0))
            for vertex_index in polygon.vertices:
                center += detail.data.vertices[vertex_index].co
            samples.append(detail.matrix_world
                           @ (center / max(len(polygon.vertices), 1)))

        closest = float("inf")
        closest_sample = None
        for sample in samples:
            coat_y = faceted_coat_surface_y(
                sample.x, sample.z, ring_specs, rear=rear)
            clearance = sample.y - coat_y if rear else coat_y - sample.y
            if clearance < closest:
                closest = clearance
                closest_sample = sample.copy()
        if closest < minimum:
            raise RuntimeError(
                f"{detail_name} crosses coat between vertices at "
                f"{tuple(round(value, 6) for value in closest_sample)}: "
                f"clearance {closest:.6f}"
            )
        print(f"MILO_FACET_CLEARANCE: {detail_name} {closest:.6f}")


def verify_limb_weights(detail_names, required_bones):
    """Ensure connected sleeve skins have complete normalized arm weights."""
    for detail_name in detail_names:
        detail = bpy.data.objects[detail_name]
        used_bones = set()
        for vertex in detail.data.vertices:
            total = 0.0
            for assignment in vertex.groups:
                total += assignment.weight
                used_bones.add(detail.vertex_groups[assignment.group].name)
            if abs(total - 1.0) > 1e-5:
                raise RuntimeError(
                    f"{detail_name} vertex {vertex.index} weight sum {total:.6f}"
                )
        expected = set(required_bones[detail_name])
        if not expected.issubset(used_bones):
            raise RuntimeError(f"{detail_name} missing arm-chain weights")
        print(f"MILO_LIMB_WEIGHTS: {detail_name} normalized across "
              f"{', '.join(sorted(used_bones))}")


def verify_shoulder_fit(detail_name, chest_bone, upperarm_bone,
                        coat_edge_x, coat_ring_specs, segments=12):
    """Prove the socket attaches, then clears the coat below the underarm."""
    detail = bpy.data.objects[detail_name]
    groups = {group.name: group.index for group in detail.vertex_groups}
    chest_group = groups[chest_bone]
    upperarm_group = groups[upperarm_bone]

    def weight(vertex, group_index):
        for assignment in vertex.groups:
            if assignment.group == group_index:
                return assignment.weight
        return 0.0

    top_ring = list(detail.data.vertices[:segments])
    blend_ring = list(detail.data.vertices[segments:segments * 2])
    inner_x = min(abs(vertex.co.x) for vertex in top_ring)
    outer_x = max(abs(vertex.co.x) for vertex in top_ring)
    if inner_x > coat_edge_x - 0.02 or outer_x < coat_edge_x + 0.02:
        raise RuntimeError(
            f"{detail_name} shoulder does not overlap coat edge {coat_edge_x:.4f}"
        )
    if any(weight(vertex, chest_group) < 0.83 or
           weight(vertex, upperarm_group) < 0.15
           for vertex in top_ring):
        raise RuntimeError(f"{detail_name} inner shoulder is not chest-anchored")
    if any(weight(vertex, chest_group) < 0.69 or
           weight(vertex, upperarm_group) < 0.29
           for vertex in blend_ring):
        raise RuntimeError(f"{detail_name} shoulder blend is incomplete")
    clearances = []
    # Rings zero through four form the attached shoulder socket. From ring five
    # downward, every sleeve cross-section must sit completely outside the coat.
    for ring_index in range(5, len(detail.data.vertices) // segments):
        ring = list(detail.data.vertices[
            ring_index * segments:(ring_index + 1) * segments])
        ring_z = sum(vertex.co.z for vertex in ring) / len(ring)
        sleeve_inner_x = min(abs(vertex.co.x) for vertex in ring)
        coat_radius_x, _coat_radius_y, _coat_center_y = \
            coat_ring_dimensions_at_z(ring_z, coat_ring_specs)
        clearances.append(sleeve_inner_x - coat_radius_x)
    if not clearances or min(clearances) < 0.003:
        raise RuntimeError(
            f"{detail_name} intersects coat below shoulder: "
            f"{min(clearances) if clearances else float('-inf'):.4f} m")
    print(f"MILO_SHOULDER_FIT: {detail_name} overlaps coat "
          f"{inner_x:.4f}..{outer_x:.4f} at edge {coat_edge_x:.4f}; "
          f"underarm clearance {min(clearances):.4f} m")


def verify_animated_underarm_clearance(armature, action, sleeve_names,
                                       socket_ring_count=5, segments=16,
                                       sample_count=16):
    """Reject skinned sleeve/coat intersections across the walking action."""
    scene = bpy.context.scene
    depsgraph = bpy.context.evaluated_depsgraph_get()
    start, end = action.frame_range

    def evaluated_tree(obj, first_vertex=0):
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        matrix = evaluated.matrix_world
        vertices = [matrix @ vertex.co for vertex in mesh.vertices]
        polygons = [tuple(polygon.vertices) for polygon in mesh.polygons
                    if all(index >= first_vertex for index in polygon.vertices)]
        tree = BVHTree.FromPolygons(vertices, polygons, all_triangles=False)
        evaluated.to_mesh_clear()
        return tree, vertices

    original_action = armature.animation_data.action
    original_frame = scene.frame_current
    armature.animation_data.action = action
    first_free_vertex = socket_ring_count * segments
    collision = None
    for sample_index in range(sample_count):
        amount = sample_index / max(sample_count - 1, 1)
        frame = start + (end - start) * amount
        frame_floor = math.floor(frame)
        scene.frame_set(frame_floor, subframe=frame - frame_floor)
        depsgraph.update()
        coat_tree, coat_vertices = evaluated_tree(bpy.data.objects["CoatBody"])
        for sleeve_name in sleeve_names:
            sleeve_tree, sleeve_vertices = evaluated_tree(
                bpy.data.objects[sleeve_name], first_free_vertex)
            if coat_tree.overlap(sleeve_tree):
                free_vertices = sleeve_vertices[first_free_vertex:]
                collision = (sleeve_name, frame,
                             min(abs(vertex.x) for vertex in free_vertices),
                             max(abs(vertex.x) for vertex in coat_vertices))
                break
        if collision is not None:
            break
    armature.animation_data.action = original_action
    scene.frame_set(original_frame)
    if collision is not None:
        raise RuntimeError(
            f"{collision[0]} intersects coat during walk at frame "
            f"{collision[1]:.2f}; sleeve inner x {collision[2]:.4f}, "
            f"coat outer x {collision[3]:.4f}")
    print("MILO_ANIMATED_UNDERARM_CLEARANCE: both sleeves clear coat "
          f"across {sample_count} walk-cycle samples")


def verify_cane_palm_clearance(paw_rings, cane_bottom, cane_top,
                               cane_radius, minimum=0.005):
    """Prove the cane stays beside the palm instead of crossing its mesh."""
    bottom = Vector(cane_bottom)
    top = Vector(cane_top)
    closest = float("inf")
    for center_x, _center_y, center_z, radius_x, _radius_y in paw_rings:
        height_t = (center_z - bottom.z) / (top.z - bottom.z)
        cane_x = bottom.x + (top.x - bottom.x) * height_t
        clearance = cane_x - cane_radius - (center_x + radius_x)
        closest = min(closest, clearance)
    if closest < minimum:
        raise RuntimeError(
            f"Mayor cane crosses right paw: clearance {closest:.6f}")
    print(f"MILO_CANE_PALM_CLEARANCE: {closest:.6f}")


def verify_cane_fist_alignment(paw, cane_top, maximum_offset=0.012):
    """Prove the cane terminates centrally inside the actual mitten mesh."""
    top = Vector(cane_top)
    bounds = [paw.matrix_world @ Vector(corner) for corner in paw.bound_box]
    minimum_z = min(point.z for point in bounds)
    maximum_z = max(point.z for point in bounds)
    if not minimum_z <= top.z <= maximum_z:
        raise RuntimeError("Mayor cane top does not terminate inside the fist")
    palm_x = float(paw.get("grip_axis_x",
                           (min(point.x for point in bounds)
                            + max(point.x for point in bounds)) * 0.5))
    offset = abs(top.x - palm_x)
    if offset > maximum_offset:
        raise RuntimeError(
            f"Mayor cane is not centered under fist: offset {offset:.6f}")
    print(f"MILO_CANE_FIST_ALIGNMENT: {offset:.6f}")


def verify_reference_hand_fit(paw, style):
    """Prove the unified sculpted hand keeps the blueprint proportions."""
    basis_vertices = paw.data.shape_keys.key_blocks["Basis"].data \
        if paw.data.shape_keys is not None else paw.data.vertices
    paw_bounds = [paw.matrix_world @ vertex.co for vertex in basis_vertices]
    paw_min = Vector((min(point.x for point in paw_bounds),
                      min(point.y for point in paw_bounds),
                      min(point.z for point in paw_bounds)))
    paw_max = Vector((max(point.x for point in paw_bounds),
                      max(point.y for point in paw_bounds),
                      max(point.z for point in paw_bounds)))
    size = paw_max - paw_min
    if (size.y < 0.24 or size.y > 0.28 or size.x < 0.16
            or size.x > 0.20 or size.z < 0.20 or size.z > 0.23):
        raise RuntimeError(
            f"{paw.name} lost the rounded reference proportions: {size}")
    print(f"MILO_REFERENCE_HAND_FIT: {style} size={size}")


def verify_trouser_continuity(trouser, boot, coat_bottom=0.240):
    """Prove each trouser leg bridges the coat hem and its matching boot."""
    trouser_bounds = [trouser.matrix_world @ Vector(corner)
                      for corner in trouser.bound_box]
    boot_bounds = [boot.matrix_world @ Vector(corner)
                   for corner in boot.bound_box]
    trouser_min_z = min(point.z for point in trouser_bounds)
    trouser_max_z = max(point.z for point in trouser_bounds)
    boot_max_z = max(point.z for point in boot_bounds)
    if trouser_min_z > boot_max_z + 0.004:
        raise RuntimeError(f"{trouser.name} floats above {boot.name}")
    if trouser_max_z < coat_bottom:
        raise RuntimeError(f"{trouser.name} does not reach the coat hem")
    trouser["continuous_from_coat_to_boot"] = True
    print(f"MILO_TROUSER_CONTINUITY: {trouser.name} "
          f"{trouser_min_z:.4f}..{trouser_max_z:.4f}, "
          f"boot top {boot_max_z:.4f}")


def tube(name, points, radius, mat, bone, collection, curved=False, radii=None):
    data = bpy.data.curves.new(name + "Curve", "CURVE")
    data.dimensions = "3D"
    data.bevel_depth = radius
    data.bevel_resolution = 1
    data.resolution_u = 2
    data.use_fill_caps = True
    if curved:
        spline = data.splines.new("BEZIER")
        spline.bezier_points.add(len(points) - 1)
        for index, (point, coordinate) in enumerate(zip(spline.bezier_points, points)):
            point.co = coordinate
            point.handle_left_type = "AUTO"
            point.handle_right_type = "AUTO"
            if radii is not None:
                point.radius = radii[index]
    else:
        spline = data.splines.new("POLY")
        spline.points.add(len(points) - 1)
        for point, coordinate in zip(spline.points, points):
            point.co = (*coordinate, 1.0)
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return finish(obj, name, mat, bone, collection, smooth=True)


def add_reference_empty(name, image, location, opacity, size):
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = "IMAGE"
    empty.data = image
    empty.empty_display_size = size
    empty.empty_image_depth = "FRONT"
    empty.color[3] = opacity
    empty.show_in_front = True
    empty.location = location
    empty.rotation_euler.x = math.pi / 2
    references.objects.link(empty)
    empty["usage"] = "Overlay this target on Milo while matching each named part"
    return empty


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def action_channelbag(action):
    """Return the Blender 5 layered-action channel bag used by this rig."""
    slot = action.slots[0]
    strip = action.layers[0].strips[0]
    return strip.channelbag(slot)


def replace_bone_rotation_keys(action, bone_name, samples):
    """Write a complete cyclic quaternion curve into an imported action copy."""
    path = f'pose.bones["{bone_name}"].rotation_quaternion'
    curves = {
        curve.array_index: curve
        for curve in action_channelbag(action).fcurves
        if curve.data_path == path
    }
    if len(curves) != 4:
        raise RuntimeError(f"Missing quaternion curves for {bone_name}")
    for component, curve in curves.items():
        curve.keyframe_points.clear()
        for frame, rotation in samples:
            point = curve.keyframe_points.insert(frame, rotation[component])
            point.interpolation = "BEZIER"
            point.handle_left_type = "AUTO_CLAMPED"
            point.handle_right_type = "AUTO_CLAMPED"
        curve.update()


def build_milo_walking_action(armature):
    """Author a Milo-proportioned full-body walk from the cast's source gait.

    The donor action already supplies convincing hips, legs and opposing step
    timing. Milo's much larger head and broad coat amplify its upper-body sway,
    so spine/chest rotations are softened and the head is stabilized in
    armature space with subtle step-timed life layered back in.
    """
    source = bpy.data.actions.get("Walking_A")
    if source is None:
        raise RuntimeError("Walking_A is missing from the donor rig")
    animation_data = armature.animation_data_create()
    animation_data.action = source
    if source.slots:
        animation_data.action_slot = source.slots[0]
    armature.data.pose_position = "POSE"
    start, end = source.frame_range
    sample_count = 33
    sample_times = [
        start + (end - start) * index / (sample_count - 1)
        for index in range(sample_count)
    ]
    neutral_arm_bones = (
        "upperarm.l", "lowerarm.l", "wrist.l", "hand.l",
        "upperarm.r", "lowerarm.r", "wrist.r", "hand.r",
    )
    rotations = {"spine": [], "chest": [], "head": [],
                 **{bone_name: [] for bone_name in neutral_arm_bones}}
    head_rest_rotation = armature.data.bones["head"].matrix_local.to_quaternion()

    for index, frame in enumerate(sample_times):
        frame_floor = math.floor(frame)
        bpy.context.scene.frame_set(frame_floor, subframe=frame - frame_floor)
        bpy.context.view_layer.update()

        # Preserve the donor's counter-rotation but reduce its amplitude for
        # Milo's short, wide silhouette. This keeps the coat weighted without
        # making the whole torso rock like one rigid mannequin block.
        for bone_name, strength in (("spine", 0.90), ("chest", 0.84)):
            pose_bone = armature.pose.bones[bone_name]
            location, rotation, scale = pose_bone.matrix_basis.decompose()
            softened = Quaternion().slerp(rotation, strength).normalized()
            pose_bone.matrix_basis = Matrix.LocRotScale(location, softened, scale)
            rotations[bone_name].append((frame, softened.copy()))
        bpy.context.view_layer.update()

        head = armature.pose.bones["head"]
        head_location, current_head_rotation, head_scale = head.matrix.decompose()
        phase = index / (sample_count - 1)
        # Stabilize enough to keep the eyes readable while retaining a restrained
        # amount of the donor's neck response. Milo's previous 70% lock read as a
        # floating mannequin head once the shoulders and cane became more active.
        stabilized = current_head_rotation.slerp(head_rest_rotation, 0.62)
        yaw = Quaternion(Vector((0.0, 0.0, 1.0)),
                         math.radians(1.35) * math.sin(phase * math.tau))
        nod = Quaternion(Vector((1.0, 0.0, 0.0)),
                         math.radians(1.05) * math.sin(phase * math.tau * 2.0))
        roll = Quaternion(Vector((0.0, 1.0, 0.0)),
                          math.radians(0.70) * math.sin(phase * math.tau + math.pi / 2.0))
        desired_head_rotation = (yaw @ nod @ roll @ stabilized).normalized()
        head.matrix = Matrix.LocRotScale(
            head_location, desired_head_rotation, head_scale)
        bpy.context.view_layer.update()
        rotations["head"].append(
            (frame, head.matrix_basis.to_quaternion().normalized()))
        # Milo's runtime anatomical IK authors both walking arm chains. Remove
        # the donor warrior's sideways shoulder fold from this base clip so it
        # cannot pull either sleeve through the broad mayoral coat before IK.
        for bone_name in neutral_arm_bones:
            arm_rotation = Quaternion()
            if bone_name == "upperarm.r":
                # Retain a restrained sagittal counter-swing in the exported
                # clip; runtime IK refines its wrist target and backward elbow.
                arm_rotation = Quaternion(
                    Vector((1.0, 0.0, 0.0)),
                    math.radians(8.5) * math.cos(phase * math.tau))
            rotations[bone_name].append((frame, arm_rotation))

    milo_action = source.copy()
    milo_action.name = "Milo_Walking"
    for bone_name, samples in rotations.items():
        replace_bone_rotation_keys(milo_action, bone_name, samples)
    animation_data.action = milo_action
    if milo_action.slots:
        animation_data.action_slot = milo_action.slots[0]
    bpy.context.scene.frame_set(int(start))
    bpy.context.view_layer.update()
    return milo_action


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE_RIG))
armature = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
armature.name = "MiloExactTargetRig"
for obj in list(bpy.context.scene.objects):
    if obj.type == "MESH":
        bpy.data.objects.remove(obj, do_unlink=True)

# Relax the donor warrior rig to the target's straight hanging arms.
bpy.context.view_layer.objects.active = armature
armature.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
for suffix, side in ((".l", 1.0), (".r", -1.0)):
    chain = {
        "upperarm": ((0.355 * side, 0.0, 1.12),
                     (0.545 * side, 0.0, 0.91)),
        "lowerarm": ((0.545 * side, 0.0, 0.91),
                     (0.575 * side, 0.0, 0.76)),
        "wrist": ((0.575 * side, 0.0, 0.76),
                  (0.585 * side, 0.0, 0.69)),
        "hand": ((0.585 * side, 0.0, 0.69),
                 (0.585 * side, -0.005, 0.55)),
    }
    for bone_name, (head, tail) in chain.items():
        bone = armature.data.edit_bones.get(bone_name + suffix)
        if bone:
            bone.use_connect = False
            bone.head = head
            bone.tail = tail
bpy.ops.object.mode_set(mode="OBJECT")
milo_walk_action = build_milo_walking_action(armature)

references = make_collection("00_TARGET_REFERENCE")
collections = {
    "head": make_collection("01_HEAD"),
    "ears": make_collection("02_EARS"),
    "eyes": make_collection("03_EYES_AND_GLASSES"),
    "face": make_collection("04_NOSE_MOUTH_MOUSTACHE"),
    "outfit": make_collection("05_OUTFIT"),
    "arms": make_collection("06_ARMS_AND_PAWS"),
    "legs": make_collection("07_LEGS_AND_BOOTS"),
    "tail": make_collection("08_TAIL"),
    "accessories": make_collection("09_MAYOR_ACCESSORIES"),
}
link_only(armature, make_collection("10_RIG"))
parts = []

# ARTÉA cat-statue palette: warm vanilla fur with caramel tabby points.  The
# moderately polished finish keeps the colour rich without making Milo look
# like bare metal under the game lights.
CREAM = material("Artea Statue Warm Cream Fur", "e2bd78", 0.44)
WHITE = material("Artea Statue Ivory Muzzle", "f3e1bd", 0.48)
PINK = material("Artea Statue Rose Nose", "d58d82", 0.36)
INNER_EAR = material("Artea Milo Soft Rose Inner Ear", "c98578", 0.46)
NAVY = material("Target Mayor Blue", "0e2942", 0.74)
NAVY_LIGHT = material("Target Mayor Lapel Blue", "0a2036", 0.72)
NAVY_PANEL = material("Target Mayor Tailored Panel Blue", "1b4564", 0.76)
NAVY_SEAM = material("Target Dark Navy Seam", "06111f", 0.82)
NAVY_POCKET = material("Target Dark Navy Pocket", "0a2137", 0.80)
PURPLE = material("Target Lavender", "2f6fa7", 0.64)
PURPLE_LIGHT = material("Target Lavender Highlight", "5797c7", 0.60)
PURPLE_SEAM = material("Target Lavender Seam", "1d476d", 0.70)
TEAL = material("Target Mint Piping", "6a98b1", 0.60)
GOLD = material("Target Gold", "d0a84b", 0.24, 0.62)
DARK = material("Target Trousers", "17354d", 0.74)
BROWN = material("Target Shoes", "6b5140", 0.68)
WOOD = material("Mayor Cane Dark Wood", "60351e", 0.48)
BLACK = material("Artea Milo Purple Pupil", "613f91", 0.18)
INNER_EYE = material("Artea Milo Deep Purple Iris", "2d194b", 0.14)
EYE_GLINT = material("Artea Milo Eye Catchlight", "fff8e8", 0.20)
EYE_WHITE = material("Artea Statue Warm Eye White", "f3ead9", 0.38)
MARKING = material("Artea Statue Caramel Fur Marking", "9f5425", 0.38)
MARKING_DARK = material("Artea Statue Deep Caramel Stripe", "703718", 0.42)
PAW_DETAIL = material("Artea Milo Recessed Paw Detail", "5b321f", 0.90)
MOUTH = material("Artea Milo Warm Mouth Shadow", "3e2631", 0.58)
TONGUE = material("Artea Milo Gentle Rose Tongue", "d98287", 0.48)

# 01 — head and side cheeks.
sphere("Head", (0, -0.005, 1.51), (0.46, 0.35, 0.43), CREAM, "head", collections["head"], 32, 20)
for side, label in ((-1, "L"), (1, "R")):
    # Shallow cheek-surface leaves: each inner/middle ring crosses the curved
    # head shell while the pointed X tip alone extends past the silhouette.
    # Keeping the Y radii small avoids a spear-like profile.
    horizontal_tapered_form(
        "CheekUpper_" + label,
        [(0.335 * side, -0.180, 1.330, 0.035, 0.012),
         (0.385 * side, -0.135, 1.360, 0.040, 0.050),
         (0.435 * side, -0.070, 1.390, 0.030, 0.040),
         (0.470 * side, -0.080, 1.405, 0.012, 0.012)],
        CREAM, "head", collections["head"], segments=8, smooth=False
    )
    horizontal_tapered_form(
        "CheekLower_" + label,
        [(0.350 * side, -0.145, 1.285, 0.035, 0.010),
         (0.390 * side, -0.080, 1.295, 0.030, 0.035),
         (0.455 * side, -0.075, 1.315, 0.012, 0.011)],
        WHITE, "head", collections["head"], segments=8, smooth=False
    )
prism("ForeheadMark",
      [(-0.070, -0.180, 1.895), (0.000, -0.186, 1.895),
       (0.070, -0.180, 1.895), (-0.035, -0.251, 1.825),
       (0.000, -0.253, 1.825), (0.035, -0.251, 1.825),
       (0.000, -0.296, 1.755)],
      [(0, 1, 4, 3), (1, 2, 5, 4), (3, 4, 6), (4, 5, 6)],
      MARKING, "head", collections["head"])

# The authoritative three-view blueprint shows three nested fur shingles laid
# directly over the REAR scalp. They must not rise over the forehead in front.
# Each outline follows the head ellipsoid, while its center V is lifted just
# enough to create the restrained three-tip profile seen from the side.
REAR_HAIR_SPECS = (
    ("RearHairLower", 0.003,
     [(-0.390, 1.600), (-0.195, 1.690), (0.000, 1.780),
      (0.195, 1.690), (0.390, 1.600)],
     [(-0.390, 1.530), (-0.195, 1.430), (0.000, 1.350),
      (0.195, 1.430), (0.390, 1.530)]),
    ("RearHairMiddle", 0.007,
     [(-0.345, 1.715), (-0.170, 1.800), (0.000, 1.885),
      (0.170, 1.800), (0.345, 1.715)],
     [(-0.345, 1.675), (-0.170, 1.625), (0.000, 1.565),
      (0.170, 1.625), (0.345, 1.675)]),
    ("RearHairUpper", 0.011,
     [(-0.275, 1.815), (-0.140, 1.885), (0.000, 1.935),
      (0.140, 1.885), (0.275, 1.815)],
     [(-0.275, 1.785), (-0.140, 1.755), (0.000, 1.730),
      (0.140, 1.755), (0.275, 1.785)]),
)
REAR_HAIR_PARTS = []
for hair_name, clearance, top_xz, bottom_xz in REAR_HAIR_SPECS:
    top_row = [head_back_point(x, z, clearance) for x, z in top_xz]
    bottom_row = []
    for index, (x, z) in enumerate(bottom_xz):
        center_tip_lift = 0.009 if index == len(bottom_xz) // 2 else 0.003
        bottom_row.append(head_back_point(x, z, clearance + center_tip_lift))
    hair_part = surface_strip(
        hair_name, top_row, bottom_row, 0.008, CREAM, "head",
        collections["head"], bevel=0.004)
    hair_part["milo_design_role"] = "blueprint rear scalp chevron"
    REAR_HAIR_PARTS.append(hair_part)

if len(REAR_HAIR_PARTS) != 3:
    raise RuntimeError("Milo blueprint requires exactly three rear hair layers")
for hair_part in REAR_HAIR_PARTS:
    if hair_part.vertex_groups.get("head") is None:
        raise RuntimeError(f"{hair_part.name} is not bound to Milo's head")
rear_hair_points = [hair_part.matrix_world @ vertex.co
                    for hair_part in REAR_HAIR_PARTS
                    for vertex in hair_part.data.vertices]
if min(point.y for point in rear_hair_points) < 0.0:
    raise RuntimeError("Milo's rear hair has crossed onto the front hemisphere")
if max(point.x for point in rear_hair_points) \
        - min(point.x for point in rear_hair_points) < 0.76:
    raise RuntimeError("Milo rear hair is too narrow for the blueprint back view")
if min(point.z for point in rear_hair_points) > 1.36:
    raise RuntimeError("Milo rear hair has lost the lowest blueprint chevron")
print("MILO_REAR_HAIR: three head-hugging back-only chevrons verified")

# 02 — outer and inner ears remain independent for silhouette matching. The
# outer shell is a true tapered wedge: its broad root is buried in the head,
# its front and back planes converge toward the tip, and its changing Y profile
# prevents the paper-thin vertical fin visible from the side.
for side, label in ((-1, "L"), (1, "R")):
    outer_outline = [
        (0.285 * side, 0.025, 1.52),
        (0.400 * side, -0.035, 1.70),
        (0.445 * side, -0.052, 1.87),
        (0.365 * side, -0.008, 2.065),
        (0.285 * side, 0.002, 1.985),
        (0.145 * side, 0.032, 1.72),
        (0.235 * side, 0.035, 1.53),
    ]
    # A deep root blends into the skull, while the back depth decreases toward
    # the tip. This removes the former rectangular side profile and gives the
    # pinna the gentle backward cup of a real cat ear.
    ear_depths = (0.105, 0.125, 0.108, 0.075, 0.088, 0.115, 0.105)
    rear_ridges = ((0.300 * side, 0.138, 1.705),
                   (0.345 * side, 0.112, 1.925))
    ear_outer = sculpted_ear_shell(
        "EarOuter_" + label, outer_outline, ear_depths, rear_ridges,
        MARKING, "head", collections["ears"], bevel=0.025)
    for polygon in ear_outer.data.polygons:
        polygon.use_smooth = True
    minimum_ear_depth = min(ear_depths)
    buried_root_depth = min(ear_depths[0], ear_depths[-1])
    if minimum_ear_depth < 0.070 or buried_root_depth < 0.095:
        raise RuntimeError(f"EarOuter_{label} is too thin from side/back")
    ear_outer["minimum_ear_depth"] = minimum_ear_depth
    ear_outer["buried_root_depth"] = buried_root_depth
    ear_outer["rounded_rear_shell"] = True
    ear_outer["rear_ridge_y"] = max(point[1] for point in rear_ridges)
    print(f"MILO_EAR_VOLUME: EarOuter_{label} tip "
          f"{ear_depths[3]:.6f} root {buried_root_depth:.6f}")
    # The pink face follows the sloping front plane and stays inside the cream
    # perimeter, leaving a consistent structural rim at every viewing angle.
    inner_surface = [
        (0.385 * side, -0.043, 1.745),
        (0.402 * side, -0.052, 1.845),
        (0.357 * side, -0.019, 2.015),
        (0.292 * side, -0.012, 1.950),
        (0.170 * side, 0.020, 1.745),
    ]
    surface_panel("EarInner_" + label, inner_surface, -0.007,
                  INNER_EAR, "head", collections["ears"], bevel=0.010)
    # One restrained curved fold gives the pinna readable depth without
    # copying realistic cartilage or adding noisy nested panels.
    ear_fold = tube(
        "EarInnerFold_" + label,
        [(0.375 * side, -0.066, 1.770),
         (0.350 * side, -0.050, 1.875),
         (0.305 * side, -0.027, 1.955)],
        0.006, CREAM, "head", collections["ears"], curved=True)
    ear_fold["milo_design_role"] = "soft inner-ear depth fold"

# 03 — layered, expressive eyes.  The broad lavender iris preserves the target
# design, while a deep inner pupil, small catchlight and separately rigged lid
# cards keep Milo from reading as a fixed prototype doll in motion.
for side, label in ((-1, "L"), (1, "R")):
    # Broad caramel eye masks reproduce the warm face points of the ARTÉA cat
    # statue.  They hug the head behind the eye shells instead of floating as
    # flat decals, and overlap slightly at the bridge to read as one marking.
    eye_cap("FaceMask_" + label, (0.145 * side, 1.515),
            (0.205, 0.235), -0.365, -0.343,
            MARKING, "head", collections["eyes"], 28)
    eye_cap("EyeWhite_" + label, (0.160 * side, 1.50),
            (0.102, 0.118), -0.382, -0.347,
            EYE_WHITE, "head", collections["eyes"], 24)
    clean_ellipsoid("Pupil_" + label, (0.160 * side, -0.389, 1.50),
                    (0.052, 0.011, 0.052), BLACK,
                    "head", collections["eyes"], 24, 16)
    clean_ellipsoid("IrisInner_" + label,
                    (0.160 * side, -0.402, 1.496),
                    (0.025, 0.007, 0.029), INNER_EYE,
                    "head", collections["eyes"], 20, 12)
    # Both highlights sit toward the same studio/world light direction instead
    # of mirroring, which makes the pair read as one focused gaze.
    clean_ellipsoid("EyeCatchlight_" + label,
                    (0.149 * side, -0.410, 1.516),
                    (0.009, 0.0035, 0.011), EYE_GLINT,
                    "head", collections["eyes"], 12, 8)

    eye_x = 0.160 * side
    # The relaxed lid is a curved bridge between the facial mask and eye dome.
    # Its upper ridge sits close to the face, the centre rolls forward over the
    # iris, and both corners taper back into the caramel marking. This removes
    # the separate flat-card silhouette while retaining the approved shape.
    relaxed_lid_surface = [
        (eye_x - 0.098, -0.382, 1.585),
        (eye_x, -0.370, 1.620),
        (eye_x + 0.098, -0.382, 1.585),
        (eye_x + 0.090, -0.401, 1.554),
        (eye_x, -0.412, 1.574),
        (eye_x - 0.090, -0.401, 1.554),
    ]
    half_lid_surface = [
        (eye_x - 0.098, -0.382, 1.585),
        (eye_x, -0.370, 1.620),
        (eye_x + 0.098, -0.382, 1.585),
        (eye_x + 0.095, -0.402, 1.495),
        (eye_x, -0.418, 1.485),
        (eye_x - 0.095, -0.402, 1.495),
    ]
    closed_lid_surface = [
        (eye_x - 0.098, -0.382, 1.585),
        (eye_x, -0.370, 1.620),
        (eye_x + 0.098, -0.382, 1.585),
        (eye_x + 0.092, -0.398, 1.420),
        (eye_x, -0.410, 1.390),
        (eye_x - 0.092, -0.398, 1.420),
    ]
    relaxed_lid_object = surface_panel(
        "EyelidRelaxed_" + label, relaxed_lid_surface, 0.003,
        MARKING, "head", collections["eyes"], bevel=0.004)
    half_lid_object = surface_panel(
        "EyelidHalf_" + label, half_lid_surface, 0.003,
        MARKING, "head", collections["eyes"], bevel=0.005)
    closed_lid_object = surface_panel(
        "EyelidClosed_" + label, closed_lid_surface, 0.003,
        MARKING, "head", collections["eyes"], bevel=0.005)
    for lid_object in (relaxed_lid_object, half_lid_object,
                       closed_lid_object):
        lid_depths = [vertex.co.y for vertex in lid_object.data.vertices]
        depth_curve = max(lid_depths) - min(lid_depths)
        if depth_curve < 0.020:
            raise RuntimeError(f"{lid_object.name} is too flat to follow the face")
        lid_object["face_conforming_depth_curve"] = depth_curve
    # These meshes must ship in the GLB for Godot's blink controller, but only
    # the relaxed upper lid belongs in the neutral Blender proof render.
    half_lid_object.hide_render = True
    closed_lid_object.hide_render = True
    glasses_center_y = -0.438
    glasses_minor_radius = 0.012
    torus("GlassesRing_" + label, (0.160 * side, glasses_center_y, 1.51),
          0.137, glasses_minor_radius, GOLD, "head", collections["eyes"])
    # Full temple arms make the spectacles believable in profile. They travel
    # back along the skull and terminate before the inner ear rather than
    # disappearing into the face mask.
    glasses_temple = tube(
        "GlassesTemple_" + label,
        [(0.292 * side, glasses_center_y, 1.525),
         (0.335 * side, -0.345, 1.535),
         (0.400 * side, -0.205, 1.565),
         (0.430 * side, -0.060, 1.610),
         (0.410 * side, 0.015, 1.585)],
        0.0045, GOLD, "head", collections["eyes"], curved=True)
    glasses_temple["milo_design_role"] = "profile spectacle temple"
    eyelid_front_y = -0.418
    glasses_back_y = glasses_center_y + glasses_minor_radius
    glasses_lid_clearance = eyelid_front_y - glasses_back_y
    if glasses_lid_clearance < 0.006:
        raise RuntimeError(
            f"GlassesRing_{label} is too close to the animated eyelid")
    glasses_temple["minimum_eyelid_clearance"] = glasses_lid_clearance
    print(f"MILO_GLASSES_CLEARANCE: {label} {glasses_lid_clearance:.6f}")
    # A single shallow brow-frame grows out of the caramel face mask and
    # overlaps the relaxed lid root.  The blueprint shows one soft eyebrow per
    # eye, so there is deliberately no second dark line floating above it.
    brow_frame_surface = [
        (0.050 * side, -0.360, 1.700),
        (0.175 * side, -0.350, 1.728),
        (0.285 * side, -0.362, 1.692),
        (0.270 * side, -0.382, 1.647),
        (0.170 * side, -0.388, 1.672),
        (0.060 * side, -0.374, 1.660),
    ]
    brow_frame = surface_panel(
        "BrowFrame_" + label, brow_frame_surface, 0.005,
        MARKING, "head", collections["eyes"], bevel=0.008)
    brow_frame["milo_design_role"] = "eyelid-to-face transition"
    print(f"MILO_EYE_ARCHITECTURE: {label} curved lids and brow frame verified")
tube("GlassesBridge", [(-0.035, -0.440, 1.515), (0, -0.443, 1.532),
                        (0.035, -0.440, 1.515)],
     0.010, GOLD, "head", collections["eyes"], curved=True)

# 04 — nose, muzzle, sculpted moustache lobes and mouth.
for side, label in ((-1, "L"), (1, "R")):
    sphere("Muzzle_" + label, (0.075 * side, -0.374, 1.35),
           (0.135, 0.066, 0.088), WHITE, "head", collections["face"], 26, 16)
    # A low-poly leaf lobe grows from beneath the cat nose, drops into a full
    # curved belly, then rises into the sharp outer curl seen in the reference.
    horizontal_tapered_form(
        "MoustachePad_" + label,
        [(0.004 * side, -0.465, 1.345, 0.022, 0.034),
         (0.055 * side, -0.470, 1.322, 0.035, 0.046),
         (0.120 * side, -0.474, 1.302, 0.044, 0.064),
         (0.190 * side, -0.468, 1.310, 0.042, 0.058),
         (0.230 * side, -0.452, 1.342, 0.030, 0.040),
         (0.265 * side, -0.440, 1.365, 0.020, 0.026),
         (0.295 * side, -0.430, 1.390, 0.008, 0.010)],
        WHITE, "head", collections["face"], segments=10, smooth=False
    )
# Compact rounded cat nose: broad bridge, pinched lower corners and a soft
# downward point.  The two nostrils are embedded in its front face.
panel("Nose", [(-0.065, 1.398), (-0.040, 1.420), (0.040, 1.420),
                (0.065, 1.398), (0.045, 1.365), (0.0, 1.342),
                (-0.045, 1.365)],
      -0.522, 0.034, PINK, "head", collections["face"], bevel=0.012)
for side, label in ((-1, "L"), (1, "R")):
    clean_ellipsoid("Nostril_" + label,
                    (0.028 * side, -0.526, 1.380),
                    (0.006, 0.003, 0.0045), BLACK,
                    "head", collections["face"], 12, 8)
# The lower muzzle is the permanent supporting socket for every speech state.
# It sits behind the moustache and visible mouth plates, so the animation reads
# as deformation within Milo's face rather than cards appearing in open space.
mouth_socket = clean_ellipsoid(
    "MouthSocket", (0.000, -0.455, 1.285), (0.100, 0.018, 0.055),
    WHITE, "head", collections["face"], 18, 12)
mouth_socket["milo_design_role"] = "layered lower muzzle speech socket"
mouth_closed = surface_panel(
    "Mouth",
    [(-0.043, -0.500, 1.270), (0.043, -0.500, 1.270),
     (0.043, -0.505, 1.220), (0.000, -0.512, 1.195),
     (-0.043, -0.505, 1.220)],
    0.005, PINK, "head", collections["face"], bevel=0.006)
mouth_closed["milo_design_role"] = "blueprint rose closed-mouth chin"
# Three separately rigged mouth cards give Godot a tiny, dependable viseme
# set without adding a fragile jaw bone to the donor skeleton.  Only `Mouth`
# is visible at rest; the runtime companion controller swaps in one of these
# dark cavities while Milo is presenting a line.
mouth_open_small = panel(
    "MouthOpenSmall", [(-0.038, 1.255), (0.0, 1.270),
                       (0.038, 1.255), (0.032, 1.218),
                       (0.0, 1.205), (-0.032, 1.218)],
    -0.509, 0.014, MOUTH, "head", collections["face"], bevel=0.006)
mouth_open_wide = panel(
    "MouthOpenWide", [(-0.052, 1.262), (0.0, 1.280),
                      (0.052, 1.262), (0.047, 1.195),
                      (0.0, 1.170), (-0.047, 1.195)],
    -0.511, 0.015, MOUTH, "head", collections["face"], bevel=0.007)
tongue_small = panel(
    "TongueSmall", [(-0.013, 1.233), (0.013, 1.233),
                    (0.011, 1.225), (0.000, 1.222), (-0.011, 1.225)],
    -0.526, 0.004, TONGUE, "head", collections["face"], bevel=0.004)
tongue_wide = panel(
    "TongueWide", [(-0.018, 1.217), (0.018, 1.217),
                   (0.015, 1.205), (0.000, 1.201), (-0.015, 1.205)],
    -0.529, 0.004, TONGUE, "head", collections["face"], bevel=0.005)
for hidden_speech_part in (mouth_open_small, mouth_open_wide,
                           tongue_small, tongue_wide):
    hidden_speech_part.hide_render = True
for speech_part in (mouth_closed, mouth_open_small, mouth_open_wide,
                    tongue_small, tongue_wide):
    if speech_part.vertex_groups.get("head") is None:
        raise RuntimeError(f"{speech_part.name} is not bound to Milo's head")
print("MILO_MOUTH_ARCHITECTURE: socket, three visemes and tongue inserts verified")

# 05 — the coat is Milo's torso, not a second shape placed over a body shell.
# Five tailored rings form one closed shoulder-to-boot mesh; every visible
# pocket, lapel, seam and trim piece below sits directly on this coat surface.
COAT_RING_SPECS = [
    # The bottom ring carries a real W-shaped front and rear tail split:
    # side corners sit slightly higher, quarter tails hang lowest, and both
    # center vents rise clear of the boots.
    (0.240, 0.390, 0.270, 0.015,
     [0.025, 0.015, 0.000, 0.055, 0.000, 0.015,
      0.025, 0.015, 0.000, 0.055, 0.000, 0.015]),
    (0.330, 0.410, 0.280, 0.015),
    (0.720, 0.420, 0.285, 0.015),
    (1.080, 0.405, 0.270, 0.015),
    (1.180, 0.330, 0.230, 0.015),
]
coat_body = tailored_coat_body("CoatBody", COAT_RING_SPECS,
                               NAVY, "chest", collections["outfit"])
blend_coat_shoulders_into_armature(coat_body)


def coat_front_point(x, z, clearance):
    """Place a tailoring point outside the exact faceted coat surface."""
    surface_y = faceted_coat_surface_y(
        x, z, COAT_RING_SPECS, rear=False
    )
    return (x, surface_y - clearance, z)


def coat_back_point(x, z, clearance):
    """Place a rear tailoring point outside the exact faceted coat surface."""
    surface_y = faceted_coat_surface_y(
        x, z, COAT_RING_SPECS, rear=True
    )
    return (x, surface_y + clearance, z)


# Layered open coat lapels sit behind the waistcoat, giving the long coat a
# tailored front instead of reading as one uninterrupted blue body shell.
for side, label in ((-1, "L"), (1, "R")):
    # A subtly lighter tailored quarter runs from the shoulder around the
    # pocket to the riding-tail point. This gives the dark coat the same
    # readable panel hierarchy as the approved four-view colour layout.
    surface_panel("FrontCoatPanel_" + label,
          [coat_front_point(0.215 * side, 0.800, 0.004),
           coat_front_point(0.300 * side, 1.020, 0.004),
           coat_front_point(0.390 * side, 0.930, 0.004),
           coat_front_point(0.395 * side, 0.360, 0.004),
           coat_front_point(0.230 * side, 0.320, 0.004),
           coat_front_point(0.040 * side, 0.390, 0.004),
           coat_front_point(0.040 * side, 0.580, 0.004),
           coat_front_point(0.230 * side, 0.680, 0.004)],
          0.002, NAVY_PANEL, "chest", collections["outfit"], bevel=0.0)
    surface_panel("CoatLapel_" + label,
          [coat_front_point(0.320 * side, 1.090, 0.007),
           coat_front_point(0.220 * side, 1.075, 0.007),
           coat_front_point(0.245 * side, 0.820, 0.007),
           coat_front_point(0.295 * side, 0.900, 0.007)],
          -0.005, NAVY_LIGHT, "chest", collections["outfit"], bevel=0.003)
    tube("GoldLapelEdge_" + label,
         [coat_front_point(0.225 * side, 1.060, 0.014),
          coat_front_point(0.247 * side, 0.825, 0.014)],
         0.005, GOLD, "chest", collections["outfit"])
    tube("TealCoatLapelPiping_" + label,
         [coat_front_point(0.315 * side, 1.085, 0.016),
          coat_front_point(0.245 * side, 1.065, 0.016),
          coat_front_point(0.252 * side, 0.840, 0.016)],
         0.0035, TEAL, "chest", collections["outfit"])
    # The outer gold edge continues down the entire front opening and turns
    # into the W-shaped hem instead of stopping halfway down the lapel.
    tube("GoldCoatFrontEdge_" + label,
         [coat_front_point(0.320 * side, 1.080, 0.018),
          coat_front_point(0.345 * side, 0.940, 0.018),
          coat_front_point(0.378 * side, 0.720, 0.018),
          coat_front_point(0.397 * side, 0.450, 0.018),
          coat_front_point(0.380 * side, 0.285, 0.018)],
         0.0045, GOLD, "chest", collections["outfit"], curved=True)
    tube("CoatDart_" + label,
         [coat_front_point(0.305 * side, 0.635, 0.007),
          coat_front_point(0.292 * side, 0.580, 0.007)],
         0.003, NAVY_SEAM, "chest", collections["outfit"])
    surface_panel("PocketFlap_" + label,
          [coat_front_point(0.195 * side, 0.545, 0.007),
           coat_front_point(0.350 * side, 0.558, 0.007),
           coat_front_point(0.340 * side, 0.505, 0.007),
           coat_front_point(0.205 * side, 0.495, 0.007)],
          -0.004, NAVY_POCKET, "chest", collections["outfit"], bevel=0.003)

# The waistcoat is a fitted shell, not a flat card. Its columns align with the
# same coat facets as the host, while the pointed lower row preserves the
# target silhouette.
waistcoat_x = (-0.230, -0.2025, 0.000, 0.2025, 0.230)
waistcoat_top = [coat_front_point(x, 1.075, 0.010) for x in waistcoat_x]
waistcoat_bottom_z = (0.675, 0.675, 0.590, 0.675, 0.675)
waistcoat_bottom = [coat_front_point(x, z, 0.010)
                    for x, z in zip(waistcoat_x, waistcoat_bottom_z)]
surface_strip("Waistcoat", waistcoat_top, waistcoat_bottom, 0.003,
              PURPLE, "chest", collections["outfit"], bevel=0.0)
for side, label in ((-1, "L"), (1, "R")):
    surface_panel("WaistcoatFacet_" + label,
          [coat_front_point(0.015 * side, 1.060, 0.013),
           coat_front_point(0.220 * side, 1.060, 0.013),
           coat_front_point(0.165 * side, 0.955, 0.013),
           coat_front_point(0.060 * side, 0.985, 0.013)],
          0.002, PURPLE_LIGHT, "chest", collections["outfit"], bevel=0.0)
    tube("LapelPiping_" + label,
         [coat_front_point(0.075 * side, 1.115, 0.024),
          coat_front_point(0.180 * side, 1.060, 0.024),
          coat_front_point(0.145 * side, 1.005, 0.024)],
         0.009, TEAL, "chest", collections["outfit"])
surface_panel("Collar_L",
      [coat_front_point(-0.185, 1.115, 0.016),
       coat_front_point(-0.015, 1.075, 0.016),
       coat_front_point(-0.105, 0.990, 0.016)],
      -0.004, TEAL, "chest", collections["outfit"], bevel=0.003)
surface_panel("Collar_R",
      [coat_front_point(0.185, 1.115, 0.016),
       coat_front_point(0.015, 1.075, 0.016),
       coat_front_point(0.105, 0.990, 0.016)],
      -0.004, TEAL, "chest", collections["outfit"], bevel=0.003)
surface_panel("Tie",
      [coat_front_point(-0.070, 1.070, 0.020),
       coat_front_point(0.070, 1.070, 0.020),
       coat_front_point(0.085, 0.985, 0.020),
       coat_front_point(0.000, 0.800, 0.020),
       coat_front_point(-0.085, 0.985, 0.020)],
      0.004, GOLD, "chest", collections["outfit"], bevel=0.0)
domed_button("Medallion", coat_front_point(0, 1.035, 0.031), 0.048, 0.024,
             GOLD, "chest", collections["outfit"], sides=12)
for row, z in enumerate((0.735, 0.875), 1):
    for side, label in ((-1, "L"), (1, "R")):
        domed_button(f"Button_{row}_{label}",
                     coat_front_point(0.135 * side, z, 0.018), 0.038, 0.020,
                     GOLD, "chest", collections["outfit"], sides=10)
tube("WaistcoatSeam", [coat_front_point(0, 0.625, 0.015),
                        coat_front_point(0, 0.930, 0.015)],
     0.004, PURPLE_SEAM, "chest", collections["outfit"])
# Fine gold details carry the mayor identity at gameplay distance without
# changing the target lavender/mint palette.
for side, label in ((-1, "L"), (1, "R")):
    tube("GoldWaistcoatEdge_" + label,
         [coat_front_point(0.225 * side, 1.045, 0.015),
          coat_front_point(0.225 * side, 0.685, 0.015),
          coat_front_point(0, 0.595, 0.015)],
         0.004, GOLD, "chest", collections["outfit"])
    surface_panel("GoldPocketTrim_" + label,
         [coat_front_point(0.195 * side, 0.537, 0.014),
          coat_front_point(0.350 * side, 0.550, 0.014),
          coat_front_point(0.350 * side, 0.566, 0.014),
          coat_front_point(0.195 * side, 0.555, 0.014)],
         0.002, GOLD, "chest", collections["outfit"], bevel=0.0)
cube("GoldTieClip", coat_front_point(0, 0.875, 0.023), (0.040, 0.004, 0.006),
     GOLD, "chest", collections["outfit"], bevel=0.004)
tube("MayoralWatchChain", [coat_front_point(0.035, 1.010, 0.026),
                            coat_front_point(0.075, 0.970, 0.026),
                            coat_front_point(0.110, 0.925, 0.026),
                            coat_front_point(0.135, 0.890, 0.026)],
     0.003, GOLD, "chest", collections["outfit"], curved=True)
coat_bottom_trim("GoldCoatHem360", COAT_RING_SPECS[0], GOLD,
                 "chest", collections["outfit"])
tube("FrontTailCenterSeam", [(0.000, -0.278, 0.585),
                              (0.000, -0.278, 0.300)],
     0.003, NAVY_SEAM, "chest", collections["outfit"])

# The blueprint uses a SHORT central back strap, not a full-width belt. It is
# sampled from the rear coat facets and carries only the two visible buttons.
back_belt_x = (-0.180, 0.000, 0.180)
back_belt_top = [coat_back_point(x, 0.845, 0.009) for x in back_belt_x]
back_belt_bottom = [coat_back_point(x, 0.765, 0.009) for x in back_belt_x]
surface_strip("BackWaistBelt", back_belt_top, back_belt_bottom, -0.003,
              NAVY_LIGHT, "chest", collections["outfit"], bevel=0.0)

# Two shallow rear quarters make the riding-tail construction legible from
# behind. They follow the host facets, stop clear of the center vent and share
# the chest bone, so they add tailoring depth without cloth simulation.
for side, label in ((-1, "L"), (1, "R")):
    rear_tail_x = [0.030 * side, 0.2025 * side,
                   0.350 * side, 0.405 * side]
    rear_tail_top = [coat_back_point(x, z, 0.012)
                     for x, z in zip(rear_tail_x,
                                     (0.590, 0.595, 0.600, 0.590))]
    rear_tail_bottom = [coat_back_point(x, z, 0.012)
                        for x, z in zip(rear_tail_x,
                                        (0.315, 0.275, 0.290, 0.325))]
    rear_tail = surface_strip(
        "RearCoatTail_" + label,
        rear_tail_top, rear_tail_bottom, 0.003,
        NAVY_PANEL, "chest", collections["outfit"], bevel=0.0)
    rear_tail["milo_design_role"] = "separate short split coat-tail quarter"

# The blueprint side view has an attached rear skirt flap, with a single gold
# lower/vent edge. These panels begin inside the coat-side envelope so their
# roots cannot float, then extend rearward as one restrained tailored layer.
for side, label in ((-1, "L"), (1, "R")):
    side_x = 0.402 * side
    side_tail_outline = [
        (side_x, 0.015, 0.900),
        (side_x, 0.225, 0.850),
        (side_x, 0.302, 0.355),
        (side_x, 0.235, 0.300),
        (side_x, 0.135, 0.505),
        (side_x, 0.020, 0.560),
    ]
    side_tail = vector_extruded_panel(
        "SideCoatTail_" + label, side_tail_outline,
        (0.010 * side, 0.0, 0.0), NAVY_PANEL, "chest",
        collections["outfit"], bevel=0.002)
    side_tail["milo_design_role"] = "attached blueprint side skirt flap"
    side_tail["root_embedded_in_coat"] = True
    root_radius_x, _root_radius_y, _root_center_y = \
        coat_ring_dimensions_at_z(0.900, COAT_RING_SPECS)
    root_overlap = root_radius_x - abs(side_x)
    if root_overlap < 0.005:
        raise RuntimeError(f"SideCoatTail_{label} is not anchored in CoatBody")
    side_tail["coat_root_overlap"] = root_overlap
    print(f"MILO_SIDE_COAT_ATTACHMENT: SideCoatTail_{label} "
          f"root overlap {root_overlap:.6f}")
    tube("GoldSideCoatTailEdge_" + label,
         [(0.414 * side, 0.302, 0.355),
          (0.414 * side, 0.235, 0.300),
          (0.414 * side, 0.135, 0.505)],
         0.004, GOLD, "chest", collections["outfit"], curved=True)
for side, label in ((-1, "L"), (1, "R")):
    button_x = 0.130 * side
    button_y = faceted_coat_surface_y(
        button_x, 0.805, COAT_RING_SPECS) + 0.025
    domed_button("BackBeltButton_" + label,
                 (button_x, button_y, 0.805), 0.025, 0.014,
                 GOLD, "chest", collections["outfit"], sides=10)
for side, label in ((-1, "L"), (1, "R")):
    tube("BackVentEdge_" + label,
         [(0.000, 0.312, 0.600), (0.020 * side, 0.311, 0.455),
          (0.040 * side, 0.306, 0.300)],
         0.003, NAVY_SEAM, "chest", collections["outfit"])
    tube("CoatSideSeam_" + label,
         [(0.405 * side, -0.115, 0.970),
          (0.414 * side, 0.000, 0.690),
          (0.405 * side, 0.115, 0.355)],
         0.003, NAVY_SEAM, "chest", collections["outfit"])
# 06/07 — each sleeve is one continuous tapered skin across the full arm
# chain. Dense, gradual rings around the anatomical elbow prevent linear skinning
# from turning a deep bend into one angular block joined to a thin forearm.
for side, suffix, label in ((-1, ".r", "L"), (1, ".l", "R")):
    sleeve_rings = [
        (0.330 * side, 0.000, 1.150, 0.075, 0.095),
        # The side-depth stays slightly flatter than the visible width. This
        # reads as tailored cloth over an arm instead of a padded round tube.
        (0.355 * side, 0.000, 1.125, 0.106, 0.103),
        (0.386 * side, 0.000, 1.105, 0.111, 0.107),
        (0.425 * side, 0.000, 1.080, 0.113, 0.109),
        (0.470 * side, 0.000, 1.040, 0.111, 0.107),
        (0.516 * side, 0.000, 0.985, 0.106, 0.103),
        (0.542 * side, 0.000, 0.950, 0.103, 0.099),
        (0.560 * side, 0.000, 0.925, 0.101, 0.096),
        (0.570 * side, 0.000, 0.910, 0.100, 0.094),
        (0.573 * side, 0.000, 0.895, 0.099, 0.093),
        (0.576 * side, 0.000, 0.870, 0.098, 0.093),
        (0.581 * side, 0.000, 0.835, 0.096, 0.094),
        (0.587 * side, 0.000, 0.790, 0.094, 0.095),
        (0.592 * side, 0.000, 0.750, 0.092, 0.095),
        (0.597 * side, 0.000, 0.720, 0.089, 0.093),
        (0.600 * side, 0.000, 0.690, 0.083, 0.091),
    ]
    if label == "R":
        # The cane shoulder needs a little more lateral room than the relaxed
        # arm. Fade the offset out through the elbow so the socket sits outside
        # the coat while the cuff and hand keep their authored cane alignment.
        shoulder_outward = (
            0.018, 0.020, 0.020, 0.018, 0.015, 0.011, 0.008, 0.005,
            0.003, 0.002, 0.001, 0.000, 0.000, 0.000, 0.000, 0.000,
        )
        # A very small cloth-volume correction around the bend removes the
        # pinched hourglass that made upper and lower sleeve read as separate
        # pieces. The long taper remains visible; this is not a global scale-up.
        bend_width = (
            0.000, 0.000, 0.001, 0.002, 0.003, 0.004, 0.005, 0.006,
            0.006, 0.006, 0.005, 0.004, 0.003, 0.002, 0.001, 0.000,
        )
        sleeve_rings = [
            (x + shoulder_outward[index] * side, y, z,
             radius_x + bend_width[index], radius_y + bend_width[index] * 0.55)
            for index, (x, y, z, radius_x, radius_y) in enumerate(sleeve_rings)
        ]
    sleeve = weighted_tapered_limb(
        "Sleeve_" + label,
        scale_limb_profile(
        # A tailored sleeve profile gives Milo a soft shoulder cap, a controlled
        # upper-arm taper, a small anatomical elbow and a clean forearm taper.
        # The gradual centerline avoids both the old segmented hinge and the
        # swollen S-shaped tube produced by over-preserving elbow volume.
        # The enlarged sleeve cap begins well inside the coat and matches the
        # coat shoulder's upper-arm influence at its boundary. This keeps the
        # two meshes visually fused throughout the swing instead of opening a
        # moving shoulder line.
        sleeve_rings,
        # Normal 1.0x sleeve size. The shared scaling path remains explicit so
        # later size changes cannot accidentally move the wrist or shoulder.
        (1.00, 1.00, 1.00, 1.00, 1.00,
         1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
         1.00, 1.00, 1.00),
        # No clearance compensation is needed at the normal profile size.
        (0.00, 0.00, 0.00, 0.00, 0.00,
         0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00,
         0.00, 0.00, 0.00)),
        [(("chest", 0.84), ("upperarm" + suffix, 0.16)),
         (("chest", 0.70), ("upperarm" + suffix, 0.30)),
         (("chest", 0.55), ("upperarm" + suffix, 0.45)),
         (("chest", 0.40), ("upperarm" + suffix, 0.60)),
         (("chest", 0.25), ("upperarm" + suffix, 0.75)),
         # A broad, monotonic elbow blend makes the whole cloth tube curve.
         # Keeping rigid upper/lower regions away from the joint prevents a
         # visible hinge between two otherwise smooth sleeve volumes.
         (("upperarm" + suffix, 0.95), ("lowerarm" + suffix, 0.05)),
         (("upperarm" + suffix, 0.86), ("lowerarm" + suffix, 0.14)),
         (("upperarm" + suffix, 0.74), ("lowerarm" + suffix, 0.26)),
         (("upperarm" + suffix, 0.62), ("lowerarm" + suffix, 0.38)),
         (("upperarm" + suffix, 0.50), ("lowerarm" + suffix, 0.50)),
         (("upperarm" + suffix, 0.38), ("lowerarm" + suffix, 0.62)),
         (("upperarm" + suffix, 0.26), ("lowerarm" + suffix, 0.74)),
         (("upperarm" + suffix, 0.10), ("lowerarm" + suffix, 0.85),
          ("wrist" + suffix, 0.05)),
         (("lowerarm" + suffix, 0.80), ("wrist" + suffix, 0.20)),
         (("lowerarm" + suffix, 0.55), ("wrist" + suffix, 0.45)),
         (("wrist" + suffix, 1.00),)],
        NAVY, collections["arms"], segments=16,
        orient_to_path=True, fixed_ring_count=5
    )
    sleeve["arm_size_scale"] = 1.00
    sleeve["smooth_wrist_scale_transition"] = True
    sleeve["cane_shoulder_outward_offset"] = 0.020 if label == "R" else 0.000
    sleeve["continuous_cane_arm_profile"] = label == "R"
    print(f"MILO_ARM_SIZE: Sleeve_{label} normal 1.00x profile")
    # One compact fitted cuff bridges sleeve to paw. Its narrow lower trim
    # overlaps the edge, so the pair reads as one tailored cuff instead of two
    # separated hoops or one oversized rectangular band in profile.
    fitted_elliptical_cuff(
        "Cuff_" + label, (0.599 * side, -0.006),
        (0.088, 0.101), (0.099, 0.112), (0.684, 0.700),
        GOLD, "wrist" + suffix, collections["arms"],
        sleeve_radii=(0.083, 0.091),
        limb_axis=(0.010 * side, 0.0, -0.070))
    fitted_elliptical_cuff(
        "CuffAccent_" + label, (0.599 * side, -0.006),
        (0.090, 0.105), (0.100, 0.115), (0.697, 0.707),
        GOLD, "wrist" + suffix, collections["arms"],
        sleeve_radii=(0.085, 0.095),
        limb_axis=(0.010 * side, 0.0, -0.070))
    # Target close-ups: the palm, three finger lobes and thumb are sculpted from
    # one continuous object. Finger definition comes from the silhouette and a
    # unified curl shape key, never from attached sphere objects.
    paw_center_x = 0.600 * side
    hand_style = "relaxed" if label == "L" else "cane_grip"
    paw = faceted_mitten_paw(
        "Paw_" + label, paw_center_x, 0.590, side, hand_style,
        MARKING, "hand" + suffix, collections["arms"])
    verify_unified_hand_fit(paw, hand_style)
    # Two full trouser legs continue from under the coat to the shoes. Their
    # inner edges leave a narrow intentional center split, not an empty broken
    # torso gap, and the deep navy matches the blueprint rather than charcoal.
    trouser = weighted_tapered_limb(
        "Trouser_" + label,
        [(0.150 * side, -0.002, 0.465, 0.140, 0.120),
         (0.150 * side, -0.002, 0.400, 0.145, 0.126),
         (0.150 * side, -0.002, 0.250, 0.142, 0.126),
         (0.150 * side, -0.002, 0.185, 0.132, 0.118)],
        [(('lowerleg' + suffix, 1.0),)] * 4,
        DARK, collections["legs"], segments=12)
    boot = sphere("Boot_" + label, (0.17 * side, -0.095, 0.105),
                  (0.170, 0.225, 0.085), BROWN, "foot" + suffix,
                  collections["legs"], 28, 17)
    verify_trouser_continuity(trouser, boot)
    sphere("Sole_" + label, (0.17 * side, -0.090, 0.058),
           (0.168, 0.210, 0.018), DARK, "foot" + suffix, collections["legs"], 26, 8)

# 08 — the authoritative front/side/back blueprint has a clean, tail-free rear
# coat silhouette. No tail mesh is generated.

# 09 — mayor's walking cane. The reference uses a closed mitten-like fist
# resting directly over the shaft. The cane terminates centrally inside the
# lower paw silhouette, a compact gold grip remains visible underneath, and
# shallow knuckle contours replace the former exposed wraparound finger bars.
CANE_BONE = "hand.l"
tube("MayorCaneShaft", [(0.665, -0.020, 0.100),
                        (0.610, -0.020, 0.545)],
     0.024, WOOD, CANE_BONE, collections["accessories"])
tube("MayorCaneLowerFerrule", [(0.668, -0.020, 0.055),
                               (0.660, -0.020, 0.145)],
     0.028, GOLD, CANE_BONE, collections["accessories"])
torus("MayorCaneLowerCollar", (0.660, -0.020, 0.145), 0.033, 0.008,
      GOLD, CANE_BONE, collections["accessories"], rotation=(0, 0, 0))
torus("MayorCaneUpperCollar", (0.614, -0.020, 0.478), 0.034, 0.009,
      GOLD, CANE_BONE, collections["accessories"], rotation=(0, 0, 0))
tube("MayorCaneHook",
     [(0.583, -0.020, 0.525), (0.610, -0.020, 0.540),
      (0.637, -0.020, 0.525)],
     0.015, GOLD, CANE_BONE, collections["accessories"], curved=True)
sphere("MayorCaneGroundTip", (0.668, -0.020, 0.045),
       (0.028, 0.028, 0.042), GOLD, CANE_BONE,
       collections["accessories"], 16, 10)
verify_cane_fist_alignment(
    bpy.data.objects["Paw_R"],
    (0.610, -0.020, 0.545))
# Regression proof for the fitted back tailoring. This runs on every rebuild,
# so later shape edits cannot silently reintroduce floating or intersecting
# belt and split-tail geometry.
verify_surface_clearance(
    "CoatBody", ("BackWaistBelt", "RearCoatTail_L", "RearCoatTail_R"),
    (0.0, -1.0, 0.0),
    minimum=0.001
)
verify_faceted_coat_clearance(
    ("BackWaistBelt", "BackBeltButton_L", "BackBeltButton_R", "RearCoatTail_L",
     "RearCoatTail_R"),
    COAT_RING_SPECS, rear=True, minimum=0.001
)
verify_surface_clearance(
    "CoatBody",
    ("FrontCoatPanel_L", "FrontCoatPanel_R",
     "CoatLapel_L", "CoatLapel_R", "PocketFlap_L", "PocketFlap_R",
     "Waistcoat", "WaistcoatFacet_L", "WaistcoatFacet_R",
     "Collar_L", "Collar_R", "Tie",
     "GoldPocketTrim_L", "GoldPocketTrim_R"),
    (0.0, 1.0, 0.0), minimum=0.001
)
verify_limb_weights(
    ("Sleeve_L", "Sleeve_R"),
    {
        "Sleeve_L": ("upperarm.r", "lowerarm.r", "wrist.r"),
        "Sleeve_R": ("upperarm.l", "lowerarm.l", "wrist.l"),
    },
)
verify_coat_shoulder_response(coat_body)
# The coat radius is 0.3525 m at z=1.150, interpolated between its top rings.
verify_shoulder_fit("Sleeve_L", "chest", "upperarm.r", 0.3525,
                    COAT_RING_SPECS, segments=16)
verify_shoulder_fit("Sleeve_R", "chest", "upperarm.l", 0.3525,
                    COAT_RING_SPECS, segments=16)

# Every part remains separate but follows its assigned donor-rig bone.
for part in parts:
    modifier = part.modifiers.new("MiloTargetRig", "ARMATURE")
    modifier.object = armature
    part.parent = armature

# The donor GLB opens with its warrior action evaluated, which folds both arm
# chains across the chest.  Milo's authored default is the measured relaxed
# rest pose; animations remain stored on the rig and are still exported.
armature.data.pose_position = "REST"

reference_image = crop_reference(REFERENCE_SHEET, REFERENCE_CROP)
card = add_reference_empty("TARGET_CARD", reference_image, (-1.30, 0.20, 1.05), 1.0, 2.05)
overlay = add_reference_empty("TARGET_OVERLAY", reference_image, (0, -0.58, 1.05), OVERLAY_OPACITY, 2.05)
overlay["toggle_hint"] = "Hide/show collection 00_TARGET_REFERENCE; adjust opacity in Object Data Properties"

# A neutral front render provides repeatable evidence; image empties are
# viewport-only and deliberately excluded from the GLB and render.
bpy.ops.object.camera_add(location=(0, -4.15, 1.03))
camera = bpy.context.object
camera.data.type = "PERSP"
camera.data.lens = 70
look_at(camera, (0, 0, 1.03))
bpy.context.scene.camera = camera
# A broad warm key, cool fill and two soft rims reproduce the gentle chibi
# presentation of the cast reference while preserving low-poly form. Large
# area lights create gradual shadows instead of hard plastic-looking bands.
for location, energy, size, color in (
        ((-3.2, -4.0, 5.2), 320, 3.8, (1.0, 0.88, 0.72)),
        ((3.0, -2.2, 3.2), 90, 3.2, (0.68, 0.84, 1.0)),
        ((3.2, 4.0, 4.1), 220, 3.5, (0.76, 0.88, 1.0)),
        ((-3.2, 2.5, 3.4), 70, 3.0, (1.0, 0.76, 0.60))):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.data.energy = energy
    light.data.size = size
    light.data.color = color
    look_at(light, (0, 0, 1.1))
world = bpy.data.worlds.new("MiloTargetWorld")
bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.22, 0.46, 0.62, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.24

# A matte receiving floor gives Milo a contact shadow and a believable sense
# of weight. It is a render-only studio object and is intentionally excluded
# from the selected GLB export below.
studio_floor_material = material("RENDER ONLY Studio Floor", "7899aa", 0.86)
bpy.ops.mesh.primitive_plane_add(size=12.0, location=(0.0, 0.0, -0.025))
studio_floor = bpy.context.object
studio_floor.name = "RENDER_ONLY_StudioFloor"
studio_floor.data.materials.append(studio_floor_material)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = MEASUREMENTS["reference_image"]["width_px"]
scene.render.resolution_y = MEASUREMENTS["reference_image"]["height_px"]
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUTPUT_RENDER)
scene.view_settings.look = "AgX - Medium High Contrast"
bpy.ops.render.render(write_still=True)

# Render proof from the four cardinal directions. These are generated from the
# same scene and camera settings, so front/right/back/left can be compared as a
# true 360-degree construction rather than separate concept images.
turntable_cameras = {
    "front": (0.0, -4.15, 1.03),
    "right": (4.15, 0.0, 1.03),
    "back": (0.0, 4.15, 1.03),
    "left": (-4.15, 0.0, 1.03),
}
for view_name, camera_location in turntable_cameras.items():
    camera.location = camera_location
    look_at(camera, (0, 0, 1.03))
    scene.render.filepath = str(OUTPUT_360_RENDERS[view_name])
    bpy.ops.render.render(write_still=True)
camera.location = turntable_cameras["front"]
look_at(camera, (0, 0, 1.03))
scene.render.filepath = str(OUTPUT_RENDER)

# Save the alignment workspace first, then export only rig plus model parts.
# Export from POSE, not REST: REST suppresses evaluated animation transforms and
# previously left Milo's embedded Walking_A with only three surviving tracks.
armature.data.pose_position = "POSE"
armature.animation_data.action = milo_walk_action
if milo_walk_action.slots:
    armature.animation_data.action_slot = milo_walk_action.slots[0]
bpy.context.scene.frame_set(0)
bpy.context.view_layer.update()
verify_animated_underarm_clearance(
    armature, milo_walk_action, ("Sleeve_L", "Sleeve_R"))
OUTPUT_BLEND.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
bpy.ops.object.select_all(action="DESELECT")
armature.select_set(True)
for part in parts:
    part.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT_GLB), export_format="GLB", use_selection=True,
    export_animations=True, export_animation_mode="ACTIONS",
    export_nla_strips=False, export_force_sampling=True,
    export_materials="EXPORT"
)
print(
    f"MILO_EXACT_PARTS_BUILD: {len(parts)} named parts -> {OUTPUT_GLB}\n"
    f"MILO_EXACT_PARTS_BLEND: target overlay workspace -> {OUTPUT_BLEND}\n"
    f"MILO_EXACT_PARTS_RENDER: {OUTPUT_RENDER}\n"
    f"MILO_360_RENDERS: {', '.join(str(path) for path in OUTPUT_360_RENDERS.values())}"
)
