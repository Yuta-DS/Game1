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
from mathutils import Vector


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
                           sleeve_radii=(0.088, 0.102)):
    """Build a faceted cuff rail outside the elliptical sleeve/hand joint.

    A circular torus cuts through Milo's wider front-to-back sleeve profile.
    This closed elliptical rail follows that profile instead, with its inner
    wall kept outside the sleeve and paw envelope on every facet.
    """
    center_x, center_y = center
    inner_x, inner_y = inner_radii
    outer_x, outer_y = outer_radii
    z_bottom, z_top = z_range
    rings = []
    for radius_x, radius_y, z in (
            (inner_x, inner_y, z_bottom),
            (inner_x, inner_y, z_top),
            (outer_x, outer_y, z_bottom),
            (outer_x, outer_y, z_top)):
        rings.append([
            (center_x + radius_x * math.cos(2.0 * math.pi * index / segments),
             center_y + radius_y * math.sin(2.0 * math.pi * index / segments),
             z)
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


def weighted_tapered_limb(name, rings, ring_weights, mat, collection,
                          segments=12):
    """Create one connected tapered limb with smooth weights along its chain."""
    if len(rings) != len(ring_weights):
        raise ValueError("limb rings and weight rows must have equal length")
    verts = []
    for center_x, center_y, center_z, radius_x, radius_y in rings:
        for index in range(segments):
            angle = 2.0 * math.pi * index / segments
            verts.append((center_x + radius_x * math.cos(angle),
                          center_y + radius_y * math.sin(angle), center_z))
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
    return obj


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
                        coat_edge_x, segments=12):
    """Prove the sleeve socket overlaps and stays anchored to the coat."""
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
    if any(weight(vertex, chest_group) < 0.79 for vertex in top_ring):
        raise RuntimeError(f"{detail_name} inner shoulder is not chest-anchored")
    if any(weight(vertex, chest_group) < 0.34 or
           weight(vertex, upperarm_group) < 0.64
           for vertex in blend_ring):
        raise RuntimeError(f"{detail_name} shoulder blend is incomplete")
    print(f"MILO_SHOULDER_FIT: {detail_name} overlaps coat "
          f"{inner_x:.4f}..{outer_x:.4f} at edge {coat_edge_x:.4f}")


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


def verify_cane_fist_alignment(paw_rings, cane_top, maximum_offset=0.010):
    """Prove the cane terminates centrally inside the closed fist silhouette."""
    top = Vector(cane_top)
    lower_ring = None
    upper_ring = None
    for first, second in zip(paw_rings, paw_rings[1:]):
        if first[2] >= top.z >= second[2]:
            upper_ring, lower_ring = first, second
            break
    if lower_ring is None or upper_ring is None:
        raise RuntimeError("Mayor cane top does not terminate inside the fist")
    height_t = ((top.z - lower_ring[2]) /
                (upper_ring[2] - lower_ring[2]))
    palm_x = lower_ring[0] + (upper_ring[0] - lower_ring[0]) * height_t
    offset = abs(top.x - palm_x)
    if offset > maximum_offset:
        raise RuntimeError(
            f"Mayor cane is not centered under fist: offset {offset:.6f}")
    print(f"MILO_CANE_FIST_ALIGNMENT: {offset:.6f}")


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
                     (0.405 * side, 0.0, 0.91)),
        "lowerarm": ((0.405 * side, 0.0, 0.91),
                     (0.435 * side, 0.0, 0.76)),
        "wrist": ((0.435 * side, 0.0, 0.76),
                  (0.440 * side, 0.0, 0.69)),
        "hand": ((0.440 * side, 0.0, 0.69),
                 (0.440 * side, -0.005, 0.55)),
    }
    for bone_name, (head, tail) in chain.items():
        bone = armature.data.edit_bones.get(bone_name + suffix)
        if bone:
            bone.use_connect = False
            bone.head = head
            bone.tail = tail
bpy.ops.object.mode_set(mode="OBJECT")

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
INNER_EAR = material("Artea Statue Amber Inner Ear", "c77735", 0.40)
NAVY = material("Target Mayor Blue", "08182c", 0.74)
NAVY_LIGHT = material("Target Mayor Lapel Blue", "061322", 0.72)
NAVY_PANEL = material("Target Mayor Tailored Panel Blue", "102943", 0.76)
NAVY_SEAM = material("Target Dark Navy Seam", "030b16", 0.82)
NAVY_POCKET = material("Target Dark Navy Pocket", "071a2d", 0.80)
PURPLE = material("Target Lavender", "2f6fa7", 0.64)
PURPLE_LIGHT = material("Target Lavender Highlight", "5797c7", 0.60)
PURPLE_SEAM = material("Target Lavender Seam", "1d476d", 0.70)
TEAL = material("Target Mint Piping", "45b6c4", 0.50)
GOLD = material("Target Gold", "d0a84b", 0.24, 0.62)
DARK = material("Target Trousers", "30363d", 0.70)
BROWN = material("Target Shoes", "604a3b", 0.40)
WOOD = material("Mayor Cane Dark Wood", "60351e", 0.48)
BLACK = material("Artea Milo Purple Pupil", "613f91", 0.18)
EYE_WHITE = material("Artea Statue Warm Eye White", "eee5d2", 0.46)
MARKING = material("Artea Statue Caramel Fur Marking", "9f5425", 0.38)
MARKING_DARK = material("Artea Statue Deep Caramel Stripe", "703718", 0.42)
MOUTH = material("Target Mouth", "574e48", 0.64)

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

# 03 — one clean eyeball shell and one dark pupil per side. The separate white
# pupil highlights were removed to match the requested clean eye treatment.
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
    torus("GlassesRing_" + label, (0.160 * side, -0.421, 1.51),
          0.137, 0.012, GOLD, "head", collections["eyes"])
    brow = [(0.055 * side, 1.700), (0.175 * side, 1.720),
            (0.275 * side, 1.690), (0.265 * side, 1.650),
            (0.170 * side, 1.675), (0.065 * side, 1.660)]
    panel("Brow_" + label, brow, -0.405, 0.012, WHITE, "head", collections["eyes"])
tube("GlassesBridge", [(-0.035, -0.423, 1.515), (0, -0.426, 1.532),
                        (0.035, -0.423, 1.515)],
     0.010, GOLD, "head", collections["eyes"], curved=True)

# 04 — nose, muzzle, sculpted moustache lobes and mouth.
for side, label in ((-1, "L"), (1, "R")):
    sphere("Muzzle_" + label, (0.090 * side, -0.374, 1.35),
           (0.158, 0.072, 0.100), WHITE, "head", collections["face"], 26, 16)
    # A low-poly leaf lobe grows from beneath the cat nose, drops into a full
    # curved belly, then rises into the sharp outer curl seen in the reference.
    horizontal_tapered_form(
        "MoustachePad_" + label,
        [(0.004 * side, -0.465, 1.345, 0.022, 0.034),
         (0.070 * side, -0.470, 1.320, 0.044, 0.060),
         (0.150 * side, -0.474, 1.292, 0.054, 0.082),
         (0.230 * side, -0.468, 1.302, 0.052, 0.076),
         (0.300 * side, -0.452, 1.340, 0.038, 0.052),
         (0.355 * side, -0.430, 1.395, 0.010, 0.012)],
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
panel("Mouth", [(-0.040, 1.245), (0, 1.268),
                 (0.040, 1.245), (0, 1.225)],
      -0.506, 0.012, MOUTH, "head", collections["face"], bevel=0.005)

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
tailored_coat_body("CoatBody", COAT_RING_SPECS,
                   NAVY, "chest", collections["outfit"])


def coat_front_point(x, z, clearance):
    """Place a tailoring point outside the exact faceted coat surface."""
    surface_y = faceted_coat_surface_y(
        x, z, COAT_RING_SPECS, rear=False
    )
    return (x, surface_y - clearance, z)


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
          0.003, NAVY_LIGHT, "chest", collections["outfit"], bevel=0.0)
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
          0.002, NAVY_POCKET, "chest", collections["outfit"], bevel=0.0)

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
      0.003, TEAL, "chest", collections["outfit"], bevel=0.0)
surface_panel("Collar_R",
      [coat_front_point(0.185, 1.115, 0.016),
       coat_front_point(0.015, 1.075, 0.016),
       coat_front_point(0.105, 0.990, 0.016)],
      0.003, TEAL, "chest", collections["outfit"], bevel=0.0)
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

# The coat is authored all the way around rather than being a decorated front
# shell. A shallow back yoke, fitted rear quarters, split riding vent and side
# seams make every turntable angle intentional while staying attached to the
# same chest bone as the front tailoring.
# Columns land on the coat's rear facet boundaries. Both rows are sampled
# from the exact coat profile, then lifted by a controlled tailoring clearance;
# the thin rear wall remains above the host instead of entering it.
yoke_x = (-0.320, -0.2025, 0.000, 0.2025, 0.320)
yoke_top_z = (1.070, 1.090, 1.100, 1.090, 1.070)
yoke_bottom_z = (0.955, 0.938, 0.900, 0.938, 0.955)
yoke_clearance = 0.009
yoke_top = [(x, faceted_coat_surface_y(x, z, COAT_RING_SPECS) + yoke_clearance, z)
            for x, z in zip(yoke_x, yoke_top_z)]
yoke_bottom = [(x, faceted_coat_surface_y(x, z, COAT_RING_SPECS) + yoke_clearance, z)
               for x, z in zip(yoke_x, yoke_bottom_z)]
surface_strip("BackYoke", yoke_top, yoke_bottom, -0.003,
              NAVY_LIGHT, "chest", collections["outfit"], bevel=0.0)

# Cyan piping traces the upper collar line while the gold strip below anchors
# it to the mayoral palette. Both strips follow the rear facets exactly.
teal_yoke_top = [(x, y + 0.006, z + 0.002) for x, y, z in yoke_top]
teal_yoke_bottom = [(x, y + 0.006, z - 0.009) for x, y, z in yoke_top]
surface_strip("TealBackYokeEdge", teal_yoke_top, teal_yoke_bottom, -0.0015,
              TEAL, "chest", collections["outfit"], bevel=0.0)

# Tailored flat piping follows the yoke plane. Unlike a circular tube, its
# rear face cannot dip through the garment when the coat changes angle.
gold_bottom = [(x, y + 0.003, z + 0.001) for x, y, z in yoke_bottom]
gold_top = []
for top, bottom in zip(yoke_top, yoke_bottom):
    gold_top.append((bottom[0], bottom[1] + 0.003,
                     bottom[2] + min(0.014, (top[2] - bottom[2]) * 0.12)))
surface_strip("GoldBackYokeEdge", gold_top, gold_bottom, -0.0015,
              GOLD, "chest", collections["outfit"], bevel=0.0)

# Rear waist belt and paired gold buttons complete the same colour layout from
# behind. The belt is sampled from the coat surface, so it remains embedded in
# the curved torso rather than floating as a flat bar.
back_belt_top = coat_facet_row(0.675, COAT_RING_SPECS, 0.009, rear=True)
back_belt_bottom = coat_facet_row(0.600, COAT_RING_SPECS, 0.009, rear=True)
surface_strip("BackWaistBelt", back_belt_top, back_belt_bottom, -0.003,
              NAVY_LIGHT, "chest", collections["outfit"], bevel=0.0)
back_belt_gold_top_upper = [(x, y + 0.004, z + 0.002)
                            for x, y, z in back_belt_top]
back_belt_gold_top_lower = [(x, y + 0.004, z - 0.008)
                            for x, y, z in back_belt_top]
surface_strip("GoldBackBeltEdgeTop", back_belt_gold_top_upper,
              back_belt_gold_top_lower, -0.0015, GOLD, "chest",
              collections["outfit"], bevel=0.0)
back_belt_gold_bottom_upper = [(x, y + 0.004, z + 0.008)
                               for x, y, z in back_belt_bottom]
back_belt_gold_bottom_lower = [(x, y + 0.004, z - 0.002)
                               for x, y, z in back_belt_bottom]
surface_strip("GoldBackBeltEdgeBottom", back_belt_gold_bottom_upper,
              back_belt_gold_bottom_lower, -0.0015, GOLD, "chest",
              collections["outfit"], bevel=0.0)
for side, label in ((-1, "L"), (1, "R")):
    button_x = 0.130 * side
    button_y = faceted_coat_surface_y(
        button_x, 0.638, COAT_RING_SPECS) + 0.025
    domed_button("BackBeltButton_" + label,
                 (button_x, button_y, 0.638), 0.025, 0.014,
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
tube("BackCenterSeam", [(0.000, 0.314, 0.895), (0.000, 0.314, 0.600)],
     0.003, NAVY_SEAM, "chest", collections["outfit"])

# 06/07 — each sleeve is one continuous tapered skin across the full arm
# chain. The blended elbow/wrist rings keep the silhouette connected during
# animation instead of moving three rigid boxes independently.
for side, suffix, label in ((-1, ".r", "L"), (1, ".l", "R")):
    weighted_tapered_limb(
        "Sleeve_" + label,
        [(0.325 * side, 0.000, 1.150, 0.055, 0.080),
         (0.350 * side, 0.000, 1.125, 0.095, 0.115),
         (0.385 * side, 0.000, 1.040, 0.122, 0.130),
         (0.410 * side, 0.000, 0.900, 0.112, 0.122),
         (0.430 * side, 0.000, 0.770, 0.098, 0.112),
         (0.440 * side, 0.000, 0.690, 0.088, 0.102)],
        [(("chest", 0.80), ("upperarm" + suffix, 0.20)),
         (("chest", 0.35), ("upperarm" + suffix, 0.65)),
         (("upperarm" + suffix, 0.95), ("lowerarm" + suffix, 0.05)),
         (("upperarm" + suffix, 0.45), ("lowerarm" + suffix, 0.55)),
         (("lowerarm" + suffix, 0.80), ("wrist" + suffix, 0.20)),
         (("wrist" + suffix, 1.00),)],
        NAVY_PANEL, collections["arms"]
    )
    # The wrist is elliptical, so circular toruses visibly sank into both the
    # sleeve and paw. These two tailored rails follow the actual cuff profile,
    # sit just outside its surface and remain rigidly attached to the wrist.
    fitted_elliptical_cuff(
        "Cuff_" + label, (0.439 * side, -0.006),
        (0.094, 0.114), (0.103, 0.123), (0.683, 0.697),
        GOLD, "wrist" + suffix, collections["arms"],
        sleeve_radii=(0.089, 0.103))
    fitted_elliptical_cuff(
        "CuffAccent_" + label, (0.436 * side, -0.006),
        (0.097, 0.118), (0.104, 0.125), (0.714, 0.722),
        GOLD, "wrist" + suffix, collections["arms"],
        sleeve_radii=(0.092, 0.106))
    paw_rings = (
        [(0.440 * side, -0.015, 0.700, 0.072, 0.085),
         (0.440 * side, -0.015, 0.665, 0.095, 0.105),
         (0.440 * side, -0.015, 0.600, 0.105, 0.110),
         (0.440 * side, -0.015, 0.535, 0.088, 0.092),
         (0.440 * side, -0.015, 0.490, 0.040, 0.050)]
        if label == "L" else
        [(0.440, -0.015, 0.700, 0.072, 0.085),
         (0.447, -0.015, 0.665, 0.088, 0.102),
         (0.456, -0.015, 0.610, 0.100, 0.110),
         (0.465, -0.015, 0.555, 0.093, 0.100),
         (0.475, -0.015, 0.500, 0.045, 0.055)])
    weighted_tapered_limb(
        "Paw_" + label, paw_rings,
        [(("hand" + suffix, 1.0),)] * 5,
        MARKING, collections["arms"]
    )
    if label == "L":
        sphere("PawThumb_L", (0.370 * side, -0.095, 0.610),
               (0.042, 0.048, 0.056), MARKING,
               "hand" + suffix, collections["arms"], 16, 10)
    sphere("Trouser_" + label, (0.16 * side, -0.002, 0.290),
           (0.090, 0.100, 0.075), DARK, "lowerleg" + suffix, collections["legs"])
    sphere("Boot_" + label, (0.17 * side, -0.095, 0.140),
           (0.170, 0.225, 0.120), BROWN, "foot" + suffix, collections["legs"], 28, 17)
    sphere("Sole_" + label, (0.17 * side, -0.090, 0.058),
           (0.168, 0.210, 0.018), DARK, "foot" + suffix, collections["legs"], 26, 8)

# 08 — the animal tail exits through the center-back coat vent shown in the
# approved placement crop, then sweeps toward Milo's right side.
tube("Tail", [(0.00, 0.16, 0.52), (0.00, 0.315, 0.52),
              (0.16, 0.32, 0.54), (0.36, 0.29, 0.60),
              (0.52, 0.25, 0.68), (0.58, 0.21, 0.78),
              (0.54, 0.18, 0.87)], 0.060, MARKING, "hips", collections["tail"],
     curved=True, radii=(1.50, 1.38, 1.28, 1.15, 1.02, 0.88, 0.72))
# 09 — mayor's walking cane. The reference uses a closed mitten-like fist
# resting directly over the shaft. The cane terminates centrally inside the
# lower paw silhouette, a compact gold grip remains visible underneath, and
# shallow knuckle contours replace the former exposed wraparound finger bars.
CANE_BONE = "hand.l"
tube("MayorCaneShaft", [(0.520, -0.020, 0.100),
                        (0.465, -0.020, 0.545)],
     0.024, WOOD, CANE_BONE, collections["accessories"])
tube("MayorCaneLowerFerrule", [(0.523, -0.020, 0.055),
                               (0.515, -0.020, 0.145)],
     0.028, GOLD, CANE_BONE, collections["accessories"])
torus("MayorCaneLowerCollar", (0.515, -0.020, 0.145), 0.033, 0.008,
      GOLD, CANE_BONE, collections["accessories"], rotation=(0, 0, 0))
torus("MayorCaneUpperCollar", (0.469, -0.020, 0.478), 0.034, 0.009,
      GOLD, CANE_BONE, collections["accessories"], rotation=(0, 0, 0))
tube("MayorCaneHook",
     [(0.438, -0.020, 0.525), (0.465, -0.020, 0.540),
      (0.492, -0.020, 0.525)],
     0.015, GOLD, CANE_BONE, collections["accessories"], curved=True)
sphere("MayorCaneGroundTip", (0.523, -0.020, 0.045),
       (0.028, 0.028, 0.042), GOLD, CANE_BONE,
       collections["accessories"], 16, 10)
# The thumb leans diagonally into the grip. The paw surface stays clean: the
# former etched finger/crease curves read as scars in close views.
sphere("PawThumb_R", (0.445, -0.127, 0.575),
       (0.032, 0.020, 0.052), MARKING, CANE_BONE,
       collections["arms"], 16, 10,
       rotation=(0, math.radians(-40), 0))
verify_cane_fist_alignment(
    [(0.440, -0.015, 0.700, 0.072, 0.085),
     (0.447, -0.015, 0.665, 0.088, 0.102),
     (0.456, -0.015, 0.610, 0.100, 0.110),
     (0.465, -0.015, 0.555, 0.093, 0.100),
     (0.475, -0.015, 0.500, 0.045, 0.055)],
    (0.465, -0.020, 0.545))
sphere("TailTip", (0.54, 0.18, 0.87), (0.062, 0.062, 0.067),
       MARKING_DARK, "hips", collections["tail"], 14, 8)

# Regression proof for the fitted back tailoring. This runs on every rebuild,
# so later shape edits cannot silently reintroduce floating or intersecting
# yoke geometry.
verify_surface_clearance(
    "CoatBody", ("BackYoke", "TealBackYokeEdge", "GoldBackYokeEdge",
                 "BackWaistBelt", "GoldBackBeltEdgeTop",
                 "GoldBackBeltEdgeBottom"), (0.0, -1.0, 0.0),
    minimum=0.001
)
verify_faceted_coat_clearance(
    ("BackYoke", "TealBackYokeEdge", "GoldBackYokeEdge",
     "BackWaistBelt", "GoldBackBeltEdgeTop", "GoldBackBeltEdgeBottom",
     "BackBeltButton_L", "BackBeltButton_R"),
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
# The coat radius is 0.3525 m at z=1.150, interpolated between its top rings.
verify_shoulder_fit("Sleeve_L", "chest", "upperarm.r", 0.3525)
verify_shoulder_fit("Sleeve_R", "chest", "upperarm.l", 0.3525)

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
OUTPUT_BLEND.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
bpy.ops.object.select_all(action="DESELECT")
armature.select_set(True)
for part in parts:
    part.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT_GLB), export_format="GLB", use_selection=True,
    export_animations=True, export_nla_strips=True, export_materials="EXPORT"
)
print(
    f"MILO_EXACT_PARTS_BUILD: {len(parts)} named parts -> {OUTPUT_GLB}\n"
    f"MILO_EXACT_PARTS_BLEND: target overlay workspace -> {OUTPUT_BLEND}\n"
    f"MILO_EXACT_PARTS_RENDER: {OUTPUT_RENDER}\n"
    f"MILO_360_RENDERS: {', '.join(str(path) for path in OUTPUT_360_RENDERS.values())}"
)
