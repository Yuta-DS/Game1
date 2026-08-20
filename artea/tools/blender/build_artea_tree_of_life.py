"""Build the modular Artéa Tree of Life source asset and optimized game GLB.

Run from the Godot project directory:
    /Applications/Blender.app/Contents/MacOS/Blender --background --python \
        tools/blender/build_artea_tree_of_life.py

The .blend keeps hundreds of named Lego-like source modules. The exported GLB
joins those modules into a small number of material/system meshes for Godot.
"""

import json
import math
import os
import random

import bpy
from mathutils import Euler, Vector


PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSET_ROOT = os.path.join(PROJECT_ROOT, "assets3D", "tree_of_life")
SOURCE_DIR = os.path.join(ASSET_ROOT, "source")
GLB_DIR = os.path.join(ASSET_ROOT, "glb")
BLEND_PATH = os.path.join(SOURCE_DIR, "artea_tree_of_life.blend")
GLB_PATH = os.path.join(GLB_DIR, "artea_tree_of_life.glb")
MANIFEST_PATH = os.path.join(ASSET_ROOT, "tree_of_life_manifest.json")
MIN_EDITABLE_VERTICES = 100_000
PLAYER_CLEAR_PATH_M = 9.5
DESIGN_HEIGHT_M = 53.0
TREE_HEIGHT_WITHOUT_CROWN_M = 42.0
CANOPY_DIAMETER_M = 68.0
FOUNDATION_DEPTH_M = 14.0
RNG = random.Random(26032026)

for path in (SOURCE_DIR, GLB_DIR):
    os.makedirs(path, exist_ok=True)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # Explicit datablock cleanup is intentionally verbose. Mixed-type removal
    # through attribute probing is brittle across Blender releases.
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    for curve in list(bpy.data.curves):
        bpy.data.curves.remove(curve)
    for material in list(bpy.data.materials):
        bpy.data.materials.remove(material)
    for camera in list(bpy.data.cameras):
        bpy.data.cameras.remove(camera)
    for light in list(bpy.data.lights):
        bpy.data.lights.remove(light)


def new_collection(name, parent=None):
    collection = bpy.data.collections.new(name)
    (parent or bpy.context.scene.collection).children.link(collection)
    return collection


def move_to_collection(obj, collection):
    for existing in list(obj.users_collection):
        existing.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


def make_empty(name, collection, parent=None):
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.empty_display_type = 'CUBE'
    obj.empty_display_size = 0.55
    obj.parent = parent
    return obj


def make_material(name, color, metallic=0.0, roughness=0.65,
                  emission=None, emission_strength=0.0):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = color
    material.use_backface_culling = False
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Alpha"].default_value = color[3]
    if color[3] < 1.0 and hasattr(material, "surface_render_method"):
        material.surface_render_method = 'DITHERED'
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    material["artea_system"] = name.replace("MAT_", "").lower()
    return material


def create_materials():
    return {
        "bark_dark": make_material("MAT_LivingBark_Dark", (0.075, 0.045, 0.030, 1), roughness=0.94),
        "bark": make_material("MAT_LivingBark", (0.19, 0.105, 0.055, 1), roughness=0.88),
        "bark_light": make_material("MAT_LivingBark_Light", (0.32, 0.18, 0.085, 1), roughness=0.82),
        "black_tech": make_material("MAT_BlackBioTechSpine", (0.012, 0.020, 0.030, 1), metallic=0.72, roughness=0.24,
                                      emission=(0.005, 0.035, 0.055, 1), emission_strength=0.20),
        "brass": make_material("MAT_EngineeredBrass", (0.62, 0.35, 0.075, 1), metallic=0.82, roughness=0.28),
        "gold": make_material("MAT_WisdomGold", (0.95, 0.62, 0.12, 1), metallic=0.78, roughness=0.22,
                              emission=(0.55, 0.25, 0.025, 1), emission_strength=0.45),
        "inlay": make_material("MAT_GoldInlayStone", (0.72, 0.42, 0.08, 1), metallic=0.68, roughness=0.30,
                                emission=(0.30, 0.12, 0.01, 1), emission_strength=0.25),
        "cyan": make_material("MAT_CrystalSap_Cyan", (0.02, 0.24, 0.86, 1), metallic=0.12, roughness=0.18,
                              emission=(0.01, 0.78, 1.0, 1), emission_strength=3.0),
        "leaf_circuit": make_material("MAT_LeafCircuit_Cyan", (0.02, 0.24, 0.86, 1), metallic=0.16, roughness=0.26,
                                        emission=(0.015, 0.46, 0.62, 1), emission_strength=1.05),
        "crystal": make_material("MAT_HeartCrystal", (0.12, 0.34, 0.86, 1), metallic=0.14, roughness=0.1,
                                 emission=(0.08, 0.40, 0.92, 1), emission_strength=1.35),
        "crystal_violet": make_material("MAT_HeartCrystalInnerViolet", (0.42, 0.12, 0.82, 1), metallic=0.10, roughness=0.12,
                                        emission=(0.45, 0.10, 0.90, 1), emission_strength=1.65),
        "forest": make_material("MAT_Leaf_Forest", (0.07, 0.28, 0.12, 1), roughness=0.86),
        "moss": make_material("MAT_Leaf_Moss", (0.24, 0.43, 0.10, 1), roughness=0.9),
        "jade": make_material("MAT_Leaf_Jade", (0.08, 0.46, 0.29, 1), roughness=0.76),
        "sensor": make_material("MAT_Leaf_EmeraldSensor", (0.025, 0.40, 0.24, 1), metallic=0.16, roughness=0.40,
                                  emission=(0.01, 0.26, 0.16, 1), emission_strength=0.48),
        "violet": make_material("MAT_Leaf_VioletMagic", (0.35, 0.12, 0.62, 1), roughness=0.68,
                                emission=(0.30, 0.05, 0.62, 1), emission_strength=0.55),
        "lavender": make_material("MAT_Leaf_LavenderMagic", (0.56, 0.28, 0.78, 1), roughness=0.63,
                                  emission=(0.35, 0.10, 0.65, 1), emission_strength=0.4),
        "solar_glass": make_material("MAT_SolarGlassLeaf", (0.03, 0.52, 0.68, 0.62), metallic=0.30, roughness=0.16,
                                      emission=(0.02, 0.55, 0.74, 1), emission_strength=0.62),
        "stone": make_material("MAT_RootAnchorStone", (0.16, 0.19, 0.27, 1), metallic=0.28, roughness=0.76),
        "stone_dark": make_material("MAT_EngineeredFoundationDark", (0.065, 0.085, 0.13, 1), metallic=0.32, roughness=0.82),
        "moss_ground": make_material("MAT_LivingMossPocket", (0.10, 0.25, 0.08, 1), roughness=0.96),
    }


def tag(obj, export_group, module_type):
    obj["export_group"] = export_group
    obj["module_type"] = module_type
    obj["editable"] = True
    return obj


def add_frustum(collection, parent, name, p0, p1, r0, r1, sides, material,
                 export_group, module_type):
    p0 = Vector(p0)
    p1 = Vector(p1)
    direction = p1 - p0
    length = direction.length
    midpoint = (p0 + p1) * 0.5
    bpy.ops.mesh.primitive_cone_add(
        vertices=sides,
        radius1=r0,
        radius2=r1,
        depth=length,
        location=midpoint,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(direction.normalized())
    move_to_collection(obj, collection)
    obj.parent = parent
    obj.data.materials.append(material)
    return tag(obj, export_group, module_type)


def add_box(collection, parent, name, location, dimensions, rotation_z, material,
            export_group, module_type):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=(0, 0, rotation_z))
    obj = bpy.context.active_object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    move_to_collection(obj, collection)
    obj.parent = parent
    obj.data.materials.append(material)
    return tag(obj, export_group, module_type)


def add_cylinder_module(collection, parent, name, location, radius, depth,
                        material, export_group, module_type, vertices=48):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
    )
    obj = bpy.context.active_object
    obj.name = name
    move_to_collection(obj, collection)
    obj.parent = parent
    obj.data.materials.append(material)
    return tag(obj, export_group, module_type)


def add_segment_collar(collection, parent, name, p0, p1, radius, width,
                       material, export_group, module_type="structural_collar"):
    p0 = Vector(p0)
    p1 = Vector(p1)
    direction = (p1 - p0).normalized()
    midpoint = p0.lerp(p1, 0.5)
    return add_frustum(
        collection, parent, name,
        midpoint - direction * width * 0.5,
        midpoint + direction * width * 0.5,
        radius, radius, 12, material, export_group, module_type,
    )


def add_torus(collection, parent, name, location, major_radius, minor_radius,
              rotation, material, export_group, major_segments=24, minor_segments=8):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=major_segments,
        minor_segments=minor_segments,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.active_object
    obj.name = name
    move_to_collection(obj, collection)
    obj.parent = parent
    obj.data.materials.append(material)
    return tag(obj, export_group, "engineering_joint")


def add_crystal(collection, parent, name, location, radius, height, material,
                export_group="CrystalTechnology"):
    vertices = [(0, 0, height * 0.56), (0, 0, -height * 0.56)]
    for index in range(6):
        angle = math.tau * index / 6.0
        vertices.append((math.cos(angle) * radius, math.sin(angle) * radius, 0))
    faces = []
    for index in range(6):
        a = 2 + index
        b = 2 + (index + 1) % 6
        faces.append((0, a, b))
        faces.append((1, b, a))
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update(calc_edges=True)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.location = location
    obj.parent = parent
    obj.data.materials.append(material)
    return tag(obj, export_group, "crystal_module")


def add_star(collection, parent, name, location, outer_radius, inner_radius,
             depth, material):
    vertices = []
    faces = []
    points = 16
    for z in (-depth * 0.5, depth * 0.5):
        for index in range(points):
            angle = math.tau * index / points
            radius = outer_radius if index % 2 == 0 else inner_radius
            vertices.append((math.cos(angle) * radius, 0.0, z + math.sin(angle) * radius))
    for index in range(points):
        nxt = (index + 1) % points
        faces.append((index, nxt, points + nxt, points + index))
    faces.append(tuple(range(points - 1, -1, -1)))
    faces.append(tuple(points + index for index in range(points)))
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update(calc_edges=True)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.location = location
    obj.parent = parent
    obj.data.materials.append(material)
    return tag(obj, "WisdomStar", "wisdom_star")


def add_leaf_cluster(collection, parent, name, center, leaf_count, base_material,
                     vein_material, spread, scale_range, export_group,
                     flow_angle=None, leaf_materials=None, tech_material=None,
                     brass_material=None):
    """Build a dense fan of thick, serrated, crystal-powered leaf modules.

    Legacy clusters may still pass one material and random orientation. The v3
    canopy passes a material family and a branch flow angle, producing ordered
    overlapping fans instead of flat confetti. Black bio-tech stem contacts and
    cyan branching veins are authored into the same editable mesh so the leaf
    technology remains visible after the foliage systems are joined for Godot.
    """
    vertices = []
    faces = []
    material_indices = []
    center = Vector(center)
    family_materials = list(leaf_materials or [base_material])
    for material in family_materials:
        if material is None:
            raise RuntimeError(f"{name} contains an empty leaf material")
    vein_index = len(family_materials)
    tech_index = vein_index + 1 if tech_material is not None else None
    brass_index = vein_index + 2 if brass_material is not None else None
    ray_count = 11
    rank_count = max(1, math.ceil(leaf_count / ray_count))

    def add_ribbon(transform, origin, local_start, local_end, half_width, height,
                   material_index):
        direction = Vector(local_end) - Vector(local_start)
        tangent = Vector((-direction.y, direction.x, 0.0)).normalized() * half_width
        base = len(vertices)
        for point in (
            Vector(local_start) - tangent + Vector((0, 0, height)),
            Vector(local_start) + tangent + Vector((0, 0, height)),
            Vector(local_end) + tangent + Vector((0, 0, height)),
            Vector(local_end) - tangent + Vector((0, 0, height)),
        ):
            vertices.append(tuple(origin + transform @ point))
        faces.append((base, base + 1, base + 2, base + 3))
        material_indices.append(material_index)

    for leaf_index in range(leaf_count):
        if flow_angle is None:
            direction_angle = RNG.uniform(0, math.tau)
            radial = RNG.uniform(0.12, 1.0) * spread
            height_layer = RNG.uniform(-spread * 0.26, spread * 0.34)
        else:
            ray = leaf_index % ray_count
            rank = leaf_index // ray_count
            fan_t = (ray - (ray_count - 1) * 0.5) / ((ray_count - 1) * 0.5)
            direction_angle = flow_angle + fan_t * 1.12 + RNG.uniform(-0.055, 0.055)
            radial = spread * (0.22 + 0.76 * ((rank + 0.72) / (rank_count + 0.25)))
            radial *= 0.92 + 0.12 * math.cos(ray * 1.7)
            height_layer = (rank % 3 - 1) * 0.34 + math.cos(fan_t * math.pi) * 0.52
        offset = Vector((
            math.cos(direction_angle) * radial,
            math.sin(direction_angle) * radial,
            height_layer,
        ))
        yaw = direction_angle - math.pi * 0.5
        pitch = RNG.uniform(-0.18, 0.18)
        roll = RNG.uniform(-0.16, 0.16)
        length = RNG.uniform(*scale_range)
        family_index = leaf_index % len(family_materials)
        # Natural leaves are broad, rune leaves are spear-like, solar glass is
        # geometric, and sensor leaves are compact. The repeating family list
        # controls their relative frequency inside every powered fan.
        family_name = family_materials[family_index].name
        if "SolarGlass" in family_name:
            width_ratio = 0.54
        elif "VioletMagic" in family_name or "LavenderMagic" in family_name:
            width_ratio = 0.47
        elif "EmeraldSensor" in family_name:
            width_ratio = 0.42
            length *= 0.76
        else:
            width_ratio = 0.62
        width = length * width_ratio
        transform = Euler((pitch, roll, yaw), 'XYZ').to_matrix()
        base = len(vertices)
        # Eleven rows allow a visibly serrated silhouette while seven columns
        # preserve a readable low-poly crystal facet language.
        leaf_rows = 11
        leaf_columns = 7
        for row in range(leaf_rows):
            t = row / float(leaf_rows - 1)
            y = (t - 0.5) * length
            serration = 1.0 + math.sin(t * math.pi * 10.0 + leaf_index * 0.73) * 0.10
            width_profile = max(0.018, math.sin(t * math.pi) ** 0.58) * serration
            half_width = width * 0.5 * width_profile
            for column in range(leaf_columns):
                u = column / float(leaf_columns - 1) * 2.0 - 1.0
                x = u * half_width
                ridge = (1.0 - abs(u)) * width * 0.14
                z = ridge + math.sin(t * math.pi) * width * 0.10
                point = center + offset + transform @ Vector((x, y, z))
                vertices.append(tuple(point))
        for row in range(leaf_rows - 1):
            for column in range(leaf_columns - 1):
                i = base + row * leaf_columns + column
                faces.append((i, i + 1, i + leaf_columns + 1, i + leaf_columns))
                material_indices.append(family_index)

        # Black technology contact from stem into the organic leaf blade.
        if tech_index is not None:
            add_ribbon(
                transform, center + offset,
                (0, -length * 0.67, 0), (0, -length * 0.31, width * 0.08),
                max(0.025, width * 0.055), width * 0.11, tech_index,
            )
        if brass_index is not None:
            add_ribbon(
                transform, center + offset,
                (0, -length * 0.49, 0), (0, -length * 0.37, width * 0.07),
                max(0.035, width * 0.078), width * 0.13, brass_index,
            )

        # Crystal-sap midrib plus six side circuits; the branching pattern is
        # large enough to read from the game's third-person camera.
        add_ribbon(
            transform, center + offset,
            (0, -length * 0.38, width * 0.12), (0, length * 0.39, width * 0.10),
            max(0.018, width * 0.024), width * 0.15, vein_index,
        )
        for vein_step in range(3):
            t = 0.32 + vein_step * 0.18
            y = (t - 0.5) * length
            reach = width * (0.34 - vein_step * 0.055)
            for side in (-1, 1):
                add_ribbon(
                    transform, center + offset,
                    (0, y, width * 0.13),
                    (side * reach, y + length * 0.12, width * 0.075),
                    max(0.012, width * 0.014), width * 0.16, vein_index,
                )
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update(calc_edges=True)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = parent
    for material in family_materials:
        obj.data.materials.append(material)
    obj.data.materials.append(vein_material)
    if tech_material is not None:
        obj.data.materials.append(tech_material)
    if brass_material is not None:
        obj.data.materials.append(brass_material)
    for polygon, material_index in zip(obj.data.polygons, material_indices):
        polygon.material_index = material_index
    obj["leaf_module_count"] = leaf_count
    obj["leaf_family_count"] = len(family_materials)
    obj["powered_leaf_fan"] = flow_angle is not None
    return tag(obj, export_group, "crystal_powered_leaf_fan" if flow_angle is not None else "large_leaf_cluster")


def build_tree_legacy(materials):
    source_collection = new_collection("ARTEA_TREE_OF_LIFE_SOURCE")
    root = make_empty("ArteaTreeOfLife_SourceRoot", source_collection)
    root["design_height_m"] = 42.0
    root["design_canopy_diameter_m"] = 68.0
    root["player_clear_path_m"] = PLAYER_CLEAR_PATH_M
    root["design_language"] = "nature_magic_technology_engineering"

    system_specs = [
        ("01_LIVING_ROOTS", "Roots"),
        ("02_TRUNK_MODULES", "Trunk"),
        ("03_BRANCH_SYSTEM", "Branches"),
        ("04_FOLIAGE_NATURE", "FoliageNature"),
        ("05_FOLIAGE_MAGIC", "FoliageMagic"),
        ("06_CRYSTAL_SAP_TECH", "CrystalTechnology"),
        ("07_BRASS_ENGINEERING", "BrassEngineering"),
        ("08_WISDOM_STAR", "WisdomStar"),
        ("09_COLLISION_GUIDES", "CollisionGuides"),
    ]
    collections = {}
    parents = {}
    for collection_name, key in system_specs:
        collection = new_collection(collection_name, source_collection)
        collections[key] = collection
        parents[key] = make_empty(key, collection, root)

    # Root foundations deliberately leave the +/-Y centerline free: this is
    # the six-metre player path through the living arch.
    root_angles = [0, 32, 148, 180, 212, 328]
    trunk_anchors = []
    for root_index, degrees in enumerate(root_angles):
        angle = math.radians(degrees)
        # The nearest bark surfaces remain more than six metres apart at
        # player height; upper strands can then braid inward above the arch.
        inward = Vector((math.cos(angle) * 7.2, math.sin(angle) * 7.2, 2.0))
        points = [
            inward,
            Vector((math.cos(angle) * 9.0, math.sin(angle) * 9.0, 3.1)),
            Vector((math.cos(angle) * 13.5, math.sin(angle) * 13.5, 2.0)),
            Vector((math.cos(angle) * 19.5, math.sin(angle) * 19.5, 0.75)),
            Vector((math.cos(angle) * 23.0, math.sin(angle) * 23.0, 0.25)),
        ]
        radii = [2.6, 2.25, 1.55, 0.82, 0.24]
        for segment in range(len(points) - 1):
            add_frustum(
                collections["Roots"], parents["Roots"],
                f"Root_{root_index:02d}_Segment_{segment:02d}",
                points[segment], points[segment + 1], radii[segment], radii[segment + 1],
                10, materials["bark"] if segment < 2 else materials["bark_dark"],
                "Roots", "living_root_segment",
            )
            sap_start = Vector(points[segment]).lerp(Vector(points[segment + 1]), 0.08) + Vector((0, 0, radii[segment] * 0.72))
            sap_end = Vector(points[segment]).lerp(Vector(points[segment + 1]), 0.92) + Vector((0, 0, radii[segment + 1] * 0.72))
            add_frustum(
                collections["CrystalTechnology"], parents["CrystalTechnology"],
                f"RootSap_{root_index:02d}_{segment:02d}", sap_start, sap_end,
                0.13, 0.09, 6, materials["cyan"], "CrystalTechnology", "crystal_sap_conduit",
            )
        trunk_anchors.append(inward)
        add_torus(
            collections["BrassEngineering"], parents["BrassEngineering"],
            f"RootAnchorCollar_{root_index:02d}", points[1], 2.35, 0.22,
            (0, 0, angle), materials["brass"], "BrassEngineering",
        )

    # Six braided trunk strands create a tall open arch over the player route.
    trunk_tops = []
    for strand_index, anchor in enumerate(trunk_anchors):
        angle = math.radians(root_angles[strand_index])
        points = [
            anchor,
            Vector((math.cos(angle) * 7.0, math.sin(angle) * 7.0, 8.5)),
            Vector((math.cos(angle) * 4.0, math.sin(angle) * 4.0, 16.5)),
            Vector((math.cos(angle) * 2.9, math.sin(angle) * 2.9, 25.0)),
            Vector((math.cos(angle) * 2.0, math.sin(angle) * 2.0, 31.0)),
        ]
        radii = [2.4, 2.65, 2.15, 1.55, 1.05]
        for segment in range(len(points) - 1):
            add_frustum(
                collections["Trunk"], parents["Trunk"],
                f"TrunkStrand_{strand_index:02d}_{segment:02d}",
                points[segment], points[segment + 1], radii[segment], radii[segment + 1],
                11, materials["bark_light"] if strand_index % 3 == 0 else materials["bark"],
                "Trunk", "braided_trunk_segment",
            )
            # A slimmer luminous seam travels beside each structural strand.
            seam_offset = Vector((-math.sin(angle), math.cos(angle), 0)) * 0.52
            add_frustum(
                collections["CrystalTechnology"], parents["CrystalTechnology"],
                f"TrunkSap_{strand_index:02d}_{segment:02d}",
                points[segment] + seam_offset, points[segment + 1] + seam_offset,
                0.15, 0.11, 6, materials["cyan"], "CrystalTechnology", "crystal_sap_conduit",
            )
        trunk_tops.append(points[-1])

    # Crystal heart and protective living ribs.
    add_crystal(collections["CrystalTechnology"], parents["CrystalTechnology"],
                "WisdomHeartCrystal", (0, -0.25, 19.5), 2.4, 7.2, materials["crystal"])
    for rib_side in (-1, 1):
        for rib_index in range(3):
            x = rib_side * (3.1 + rib_index * 0.6)
            add_frustum(
                collections["Trunk"], parents["Trunk"], f"HeartRib_{rib_side}_{rib_index}",
                (x, -0.2, 15.2 + rib_index * 0.9),
                (rib_side * 2.2, -0.2, 23.2 - rib_index * 0.7),
                0.55, 0.32, 8, materials["bark_dark"], "Trunk", "heart_protection_rib",
            )

    # Primary and secondary branches are independent tapered Lego pieces.
    primary_ends = []
    for branch_index in range(18):
        angle = math.tau * branch_index / 18.0 + (branch_index % 2) * 0.07
        start = trunk_tops[branch_index % len(trunk_tops)] + Vector((0, 0, (branch_index % 3) * 0.45))
        radius = 15.0 + (branch_index % 4) * 2.7
        end = Vector((math.cos(angle) * radius, math.sin(angle) * radius,
                      34.0 + math.sin(branch_index * 1.17) * 2.3))
        middle_a = start.lerp(end, 0.34) + Vector((0, 0, 3.0))
        middle_b = start.lerp(end, 0.70) + Vector((0, 0, 1.5))
        points = [start, middle_a, middle_b, end]
        radii = [1.35, 1.08, 0.78, 0.48]
        for segment in range(3):
            add_frustum(
                collections["Branches"], parents["Branches"],
                f"PrimaryBranch_{branch_index:02d}_{segment:02d}",
                points[segment], points[segment + 1], radii[segment], radii[segment + 1],
                9, materials["black_tech"], "Branches", "black_biotech_primary_core",
            )
        add_torus(
            collections["BrassEngineering"], parents["BrassEngineering"],
            f"PrimaryJoint_{branch_index:02d}", middle_b, 0.92, 0.16,
            (RNG.uniform(-0.4, 0.4), RNG.uniform(-0.4, 0.4), angle),
            materials["brass"], "BrassEngineering",
        )
        primary_ends.append(end)

    for branch_index in range(36):
        source = primary_ends[branch_index % len(primary_ends)]
        base_angle = math.atan2(source.y, source.x)
        angle = base_angle + (-0.28 if branch_index % 2 == 0 else 0.28)
        distance = 8.0 + (branch_index % 5) * 1.2
        end = source + Vector((math.cos(angle) * distance, math.sin(angle) * distance,
                               2.0 + (branch_index % 3) * 0.7))
        middle = source.lerp(end, 0.55) + Vector((0, 0, 1.1))
        for segment, (p0, p1, r0, r1) in enumerate((
            (source, middle, 0.62, 0.42),
            (middle, end, 0.42, 0.18),
        )):
            add_frustum(
                collections["Branches"], parents["Branches"],
                f"SecondaryBranch_{branch_index:02d}_{segment:02d}",
                p0, p1, r0, r1, 8, materials["bark_dark"], "Branches", "secondary_branch_segment",
            )
        if branch_index % 2 == 0:
            add_torus(
                collections["BrassEngineering"], parents["BrassEngineering"],
                f"SecondaryJoint_{branch_index:02d}", middle, 0.52, 0.10,
                (RNG.uniform(-0.5, 0.5), RNG.uniform(-0.5, 0.5), angle),
                materials["brass"], "BrassEngineering", major_segments=20, minor_segments=6,
            )

    # Fifty-six large canopy clusters: predominantly natural green, with
    # violet magic woven through and cyan veins integrated into every leaf.
    leaf_palette = [
        materials["forest"], materials["moss"], materials["jade"],
        materials["forest"], materials["moss"], materials["violet"], materials["lavender"],
    ]
    cluster_specs = []
    for count, radius, z, spread in (
        (18, 28.5, 31.0, 6.5),
        (16, 21.5, 35.0, 6.2),
        (12, 14.5, 38.0, 5.7),
        (10, 7.5, 40.5, 5.0),
    ):
        for index in range(count):
            angle = math.tau * index / count + RNG.uniform(-0.10, 0.10)
            cluster_specs.append((
                Vector((math.cos(angle) * radius, math.sin(angle) * radius,
                        z + RNG.uniform(-2.0, 2.0))),
                spread,
            ))
    for cluster_index, (center, spread) in enumerate(cluster_specs):
        material = leaf_palette[cluster_index % len(leaf_palette)]
        is_magic = material in (materials["violet"], materials["lavender"])
        key = "FoliageMagic" if is_magic else "FoliageNature"
        add_leaf_cluster(
            collections[key], parents[key], f"LeafCluster_{cluster_index:03d}",
            center, 30, material, materials["cyan"], spread, (4.8, 8.6), key,
        )

    # Perimeter crystal seed pylons and orbiting motes.
    for pylon_index in range(12):
        angle = math.tau * pylon_index / 12.0
        location = Vector((math.cos(angle) * 25.5, math.sin(angle) * 25.5, 2.6))
        add_crystal(collections["CrystalTechnology"], parents["CrystalTechnology"],
                    f"CrystalPylon_{pylon_index:02d}", location, 0.72, 4.5, materials["cyan"])
        add_torus(
            collections["BrassEngineering"], parents["BrassEngineering"],
            f"PylonCollar_{pylon_index:02d}", location - Vector((0, 0, 1.8)),
            0.88, 0.16, (0, 0, 0), materials["brass"], "BrassEngineering",
            major_segments=20, minor_segments=6,
        )
    for mote_index in range(24):
        angle = math.tau * mote_index / 24.0
        radius = 27.0 + (mote_index % 4) * 2.3
        add_crystal(
            collections["CrystalTechnology"], parents["CrystalTechnology"],
            f"OrbitingSeed_{mote_index:02d}",
            (math.cos(angle) * radius, math.sin(angle) * radius,
             34.0 + math.sin(mote_index * 1.7) * 6.0),
            0.24 + (mote_index % 3) * 0.08, 1.0 + (mote_index % 2) * 0.5,
            materials["cyan"],
        )

    # Integrated Wisdom Star and concentric astronomical halo.
    add_star(collections["WisdomStar"], parents["WisdomStar"], "WisdomStar",
             (0, 0, 45.0), 3.1, 1.25, 0.55, materials["gold"])
    for halo_index, radius in enumerate((4.8, 6.2, 7.5)):
        add_torus(
            collections["WisdomStar"], parents["WisdomStar"],
            f"AstronomyHalo_{halo_index:02d}", (0, 0, 44.5 + halo_index * 0.45),
            radius, 0.12 if halo_index < 2 else 0.16,
            (0, 0, halo_index * 0.35), materials["gold"], "WisdomStar",
            major_segments=40, minor_segments=8,
        )

    # Source-only collision guides document the intended runtime proxy layout.
    # They remain hidden and are excluded from GLB export.
    for side in (-1, 1):
        guide = add_frustum(
            collections["CollisionGuides"], parents["CollisionGuides"],
            f"COLLISION_TrunkSide_{'L' if side < 0 else 'R'}",
            (side * 5.0, 0, 1.0), (side * 4.3, 0, 17.0),
            2.4, 2.4, 8, materials["stone"], "CollisionGuides", "collision_guide",
        )
        guide.hide_render = True
        guide.hide_viewport = True
    return root


def build_tree(materials):
    """Build the component-blueprint redesign as a dense modular source tree."""
    source_collection = new_collection("ARTEA_TREE_OF_LIFE_SOURCE_V2")
    root = make_empty("ArteaTreeOfLife_SourceRoot", source_collection)
    root["design_height_m"] = DESIGN_HEIGHT_M
    root["tree_height_without_crown_m"] = TREE_HEIGHT_WITHOUT_CROWN_M
    root["design_canopy_diameter_m"] = CANOPY_DIAMETER_M
    root["foundation_depth_m"] = FOUNDATION_DEPTH_M
    root["player_clear_path_m"] = PLAYER_CLEAR_PATH_M
    root["design_language"] = "nature_magic_technology_engineering"
    root["blueprint_revision"] = "crystal_powered_leaf_system_2026_08_16"
    root["foliage_revision"] = "dense_powered_branch_fans_v3"

    system_specs = [
        ("00_ENGINEERED_FOUNDATION", "Foundation"),
        ("01_LIVING_ROOTS", "Roots"),
        ("02_BRAIDED_TWIN_TRUNK", "Trunk"),
        ("03_BRANCH_SYSTEM", "Branches"),
        ("04_FOLIAGE_NATURE", "FoliageNature"),
        ("05_FOLIAGE_MAGIC", "FoliageMagic"),
        ("06_SOLAR_GLASS_FOLIAGE", "FoliageSolarGlass"),
        ("07_CRYSTAL_SAP_TECH", "CrystalTechnology"),
        ("08_BRASS_ENGINEERING", "BrassEngineering"),
        ("09_WISDOM_STAR", "WisdomStar"),
        ("10_COLLISION_GUIDES", "CollisionGuides"),
    ]
    collections = {}
    parents = {}
    for collection_name, key in system_specs:
        collection = new_collection(collection_name, source_collection)
        collections[key] = collection
        parents[key] = make_empty(key, collection, root)

    # Blueprint-authored 14 m foundation: compression plate, deep radial load
    # ribs, concentric stone walks, gold inlay, clear-path tiles and drainage.
    add_cylinder_module(
        collections["Foundation"], parents["Foundation"], "FoundationCompressionPlate",
        (0, 0, -0.75), 31.5, 1.5, materials["stone_dark"],
        "Foundation", "foundation_compression_plate", vertices=64,
    )
    add_torus(
        collections["Foundation"], parents["Foundation"], "FoundationLowerCompressionRing",
        (0, 0, -2.0), 23.5, 0.95, (0, 0, 0), materials["stone"],
        "Foundation", major_segments=64, minor_segments=10,
    )
    for rib_index in range(16):
        angle = math.tau * rib_index / 16.0
        add_frustum(
            collections["Foundation"], parents["Foundation"],
            f"FoundationLoadRib_{rib_index:02d}",
            (math.cos(angle) * 14.5, math.sin(angle) * 14.5, -FOUNDATION_DEPTH_M),
            (math.cos(angle) * 21.5, math.sin(angle) * 21.5, -1.2),
            1.15, 1.85, 8, materials["stone_dark"],
            "Foundation", "foundation_load_rib",
        )
    for tile_index in range(48):
        angle = math.tau * tile_index / 48.0
        add_box(
            collections["Foundation"], parents["Foundation"],
            f"OuterWalkwayTile_{tile_index:02d}",
            (math.cos(angle) * 28.0, math.sin(angle) * 28.0, 0.35),
            (4.5, 3.55, 0.65), angle, materials["stone"],
            "Foundation", "walkway_edge_tile",
        )
        add_box(
            collections["Foundation"], parents["Foundation"],
            f"GoldInlayTile_{tile_index:02d}",
            (math.cos(angle) * 25.7, math.sin(angle) * 25.7, 0.72),
            (3.25, 0.16, 0.10), angle, materials["inlay"],
            "Foundation", "gold_inlay_stone_tile",
        )
    for tile_index in range(36):
        angle = math.tau * tile_index / 36.0
        add_box(
            collections["Foundation"], parents["Foundation"],
            f"InnerWalkwayTile_{tile_index:02d}",
            (math.cos(angle) * 21.0, math.sin(angle) * 21.0, 0.25),
            (4.2, 3.45, 0.85), angle, materials["stone_dark"],
            "Foundation", "inner_walkway_tile",
        )
    for path_index, y in enumerate(range(-28, 29, 4)):
        add_box(
            collections["Foundation"], parents["Foundation"],
            f"ClearPathTile_{path_index:02d}", (0, float(y), 0.55),
            (PLAYER_CLEAR_PATH_M, 3.72, 0.22), 0.0, materials["stone"],
            "Foundation", "player_clear_path_tile",
        )
    for side in (-1, 1):
        for drain_index, y in enumerate((-24, -16, -8, 0, 8, 16, 24)):
            add_box(
                collections["Foundation"], parents["Foundation"],
                f"DrainCover_{'L' if side < 0 else 'R'}_{drain_index:02d}",
                (side * 5.75, y, 0.73), (1.05, 3.15, 0.16), 0.0,
                materials["cyan"], "Foundation", "drainage_service_channel_cover",
            )
    for rail_index in range(24):
        angle = math.tau * rail_index / 24.0
        next_angle = math.tau * (rail_index + 1) / 24.0
        post = Vector((math.cos(angle) * 30.1, math.sin(angle) * 30.1, 0.65))
        post_top = post + Vector((0, 0, 2.0))
        add_frustum(
            collections["BrassEngineering"], parents["BrassEngineering"],
            f"FoundationRailPost_{rail_index:02d}", post, post_top,
            0.16, 0.13, 8, materials["brass"],
            "BrassEngineering", "foundation_rail_post",
        )
        add_frustum(
            collections["BrassEngineering"], parents["BrassEngineering"],
            f"FoundationRailSpan_{rail_index:02d}",
            (math.cos(angle) * 30.1, math.sin(angle) * 30.1, 2.20),
            (math.cos(next_angle) * 30.1, math.sin(next_angle) * 30.1, 2.20),
            0.13, 0.13, 8, materials["brass"],
            "BrassEngineering", "foundation_rail_span",
        )

    # Twelve buttress roots grow outward from two dense trunk masses. Three
    # braided strands per root make the silhouette read as living architecture.
    root_angles_by_side = {
        -1: [100, 132, 164, 196, 228, 260],
        1: [-80, -48, -16, 16, 48, 80],
    }
    collision_root_proxies = []
    for side in (-1, 1):
        for local_index, degrees in enumerate(root_angles_by_side[side]):
            root_index = (0 if side < 0 else 6) + local_index
            angle = math.radians(degrees)
            direction = Vector((math.cos(angle), math.sin(angle), 0))
            perpendicular = Vector((-direction.y, direction.x, 0))
            start_center = Vector((side * 8.4, (local_index - 2.5) * 0.48, 0.35))
            centerline = [
                start_center,
                start_center + direction * 5.0 + perpendicular * math.sin(local_index * 0.9 + 0.7) * 0.55 + Vector((0, 0, 1.55)),
                start_center + direction * 10.5 + perpendicular * math.sin(local_index * 0.9 + 1.8) * 0.88 + Vector((0, 0, 1.05)),
                start_center + direction * 16.5 + perpendicular * math.sin(local_index * 0.9 + 3.0) * 0.72 + Vector((0, 0, 0.42)),
                start_center + direction * 22.0 + Vector((0, 0, -0.05)),
            ]
            strand_offsets = (-0.62, 0.0, 0.62)
            for strand_index, strand_offset in enumerate(strand_offsets):
                points = [
                    point + perpendicular * strand_offset * (1.0 - point_index * 0.12)
                    + Vector((0, 0, math.sin(point_index + strand_index) * 0.12))
                    for point_index, point in enumerate(centerline)
                ]
                radii = [1.38, 1.24, 0.92, 0.56, 0.22]
                for segment in range(4):
                    add_frustum(
                        collections["Roots"], parents["Roots"],
                        f"BraidedRoot_{root_index:02d}_Strand_{strand_index:02d}_Segment_{segment:02d}",
                        points[segment], points[segment + 1], radii[segment], radii[segment + 1],
                        9, materials["bark_light"] if strand_index == 1 else materials["bark"],
                        "Roots", "braided_living_root_segment",
                    )
                    if strand_index == 1:
                        sap_lift = Vector((0, 0, radii[segment] * 0.78))
                        add_frustum(
                            collections["CrystalTechnology"], parents["CrystalTechnology"],
                            f"RootSap_{root_index:02d}_{segment:02d}",
                            points[segment] + sap_lift, points[segment + 1] + sap_lift,
                            0.11, 0.07, 6, materials["cyan"],
                            "CrystalTechnology", "crystal_sap_conduit",
                        )
            add_segment_collar(
                collections["BrassEngineering"], parents["BrassEngineering"],
                f"SegmentedRootCollar_{root_index:02d}", centerline[0], centerline[1],
                1.55, 0.72, materials["brass"], "BrassEngineering", "root_collar_segment",
            )
            add_segment_collar(
                collections["BrassEngineering"], parents["BrassEngineering"],
                f"OuterRootArmorBand_{root_index:02d}", centerline[1], centerline[2],
                1.20, 0.48, materials["brass"], "BrassEngineering", "root_armor_band",
            )
            proxy_center = start_center + direction * 12.5
            collision_root_proxies.append({
                "name": f"LowRootProxy_{root_index:02d}",
                "position_blender_xy_m": [round(proxy_center.x, 3), round(proxy_center.y, 3)],
                "yaw_godot_deg": round(math.degrees(math.atan2(direction.x, -direction.y)), 3),
                "size_m": [3.3, 3.0, 16.0],
            })

    # Two thick masses, each made from eight individually editable strands,
    # form the gothic player arch and then knit together above the heart core.
    trunk_tops = []
    for side in (-1, 1):
        for strand_index in range(8):
            braid_angle = math.tau * strand_index / 8.0
            centers = [
                Vector((side * 8.4, 0, 0.55)),
                Vector((side * 8.65, 0, 6.5)),
                Vector((side * 7.8, 0, 13.5)),
                Vector((side * 6.25, 0, 21.0)),
                Vector((side * 3.85, 0, 28.2)),
                Vector((side * 1.70, 0, 32.2)),
            ]
            braid_scales = [1.0, 1.0, 0.86, 0.68, 0.42, 0.22]
            points = []
            for point_index, center in enumerate(centers):
                twist = braid_angle + point_index * 0.62 * side
                scale = braid_scales[point_index]
                points.append(center + Vector((
                    math.cos(twist) * 1.12 * scale,
                    math.sin(twist) * 1.36 * scale,
                    math.sin(twist * 2.0) * 0.10,
                )))
            radii = [1.64, 1.72, 1.58, 1.34, 1.02, 0.72]
            for segment in range(5):
                add_frustum(
                    collections["Trunk"], parents["Trunk"],
                    f"TwinTrunk_{'L' if side < 0 else 'R'}_Strand_{strand_index:02d}_Segment_{segment:02d}",
                    points[segment], points[segment + 1], radii[segment], radii[segment + 1],
                    10, materials["bark_light"] if strand_index % 3 == 0 else (
                        materials["bark_dark"] if strand_index % 2 else materials["bark"]),
                    "Trunk", "braided_twin_trunk_segment",
                )
                if strand_index % 2 == 0:
                    seam_side = Vector((0, -0.34 if side < 0 else 0.34, radii[segment] * 0.58))
                    add_frustum(
                        collections["CrystalTechnology"], parents["CrystalTechnology"],
                        f"TrunkSap_{'L' if side < 0 else 'R'}_{strand_index:02d}_{segment:02d}",
                        points[segment] + seam_side, points[segment + 1] + seam_side,
                        0.18, 0.11, 6, materials["cyan"],
                        "CrystalTechnology", "crystal_sap_conduit",
                    )
            if strand_index % 2 == 0:
                add_segment_collar(
                    collections["BrassEngineering"], parents["BrassEngineering"],
                    f"TrunkArmorCollar_{'L' if side < 0 else 'R'}_{strand_index:02d}",
                    points[1], points[2], 1.72, 0.62, materials["brass"],
                    "BrassEngineering", "trunk_armor_collar",
                )
            trunk_tops.append(points[-1])
    # Front-facing interlocking bark scales make the braid readable from the
    # entrance instead of collapsing into two smooth silhouettes.
    for side in (-1, 1):
        for plate_index in range(13):
            z = 3.2 + plate_index * 1.95
            t = min(1.0, z / 31.0)
            x = side * (8.55 * (1.0 - t) + 2.35 * t)
            y = -1.62 - (plate_index % 2) * 0.12
            add_box(
                collections["Trunk"], parents["Trunk"],
                f"BarkScalePlate_{'L' if side < 0 else 'R'}_{plate_index:02d}",
                (x, y, z), (2.65 - t * 0.75, 0.42, 1.28), 0.0,
                materials["bark_light"] if plate_index % 3 == 0 else materials["bark_dark"],
                "Trunk", "interlocking_bark_scale_plate",
            )
    for bridge_index in range(8):
        y = (bridge_index - 3.5) * 0.42
        peak_z = 33.8 + math.sin(bridge_index * 0.9) * 0.8
        add_frustum(
            collections["Trunk"], parents["Trunk"], f"CrownBridge_L_{bridge_index:02d}",
            (-2.1, y, 30.4), (0, y * 0.72, peak_z), 0.68, 0.48, 9,
            materials["bark_dark"], "Trunk", "crown_bridge_rib",
        )
        add_frustum(
            collections["Trunk"], parents["Trunk"], f"CrownBridge_R_{bridge_index:02d}",
            (0, y * 0.72, peak_z), (2.1, y, 30.4), 0.48, 0.68, 9,
            materials["bark_dark"], "Trunk", "crown_bridge_rib",
        )

    # Faceted heart core, three nested brass housing rings, vertical braces,
    # and a floor-level energy well centered beyond the walkable surface.
    add_crystal(
        collections["CrystalTechnology"], parents["CrystalTechnology"],
        "WisdomHeartCore", (0, -0.25, 20.0), 3.15, 8.4, materials["crystal"],
    )
    add_crystal(
        collections["CrystalTechnology"], parents["CrystalTechnology"],
        "WisdomHeartInnerFacet", (0, -0.55, 20.0), 1.72, 5.4, materials["crystal_violet"],
    )
    for facet_index in range(6):
        facet_angle = math.tau * facet_index / 6.0
        add_crystal(
            collections["CrystalTechnology"], parents["CrystalTechnology"],
            f"WisdomHeartOrbitFacet_{facet_index:02d}",
            (math.cos(facet_angle) * 2.25, -0.42, 20.0 + math.sin(facet_angle) * 2.9),
            0.46, 1.65, materials["crystal_violet"],
        )
    for ring_index, radius in enumerate((4.15, 4.75, 5.30)):
        add_torus(
            collections["BrassEngineering"], parents["BrassEngineering"],
            f"HeartHousingRing_{ring_index:02d}", (0, -0.15, 20.0), radius,
            0.22 if ring_index < 2 else 0.30, (math.radians(90), 0, 0),
            materials["gold"] if ring_index == 1 else materials["brass"],
            "BrassEngineering", major_segments=40, minor_segments=8,
        )
    for side in (-1, 1):
        for brace_index in range(3):
            add_frustum(
                collections["BrassEngineering"], parents["BrassEngineering"],
                f"HeartBrace_{'L' if side < 0 else 'R'}_{brace_index:02d}",
                (side * (4.6 + brace_index * 0.35), -0.10, 16.0 + brace_index * 1.0),
                (side * (3.4 + brace_index * 0.18), -0.10, 24.0 - brace_index * 0.8),
                0.34, 0.24, 8, materials["brass"],
                "BrassEngineering", "heart_housing_brace",
            )
    add_cylinder_module(
        collections["CrystalTechnology"], parents["CrystalTechnology"],
        "RootPoweredLightWell", (0, 3.4, 0.62), 1.75, 0.28, materials["cyan"],
        "CrystalTechnology", "root_powered_light_well", vertices=40,
    )
    for well_ring, radius in enumerate((2.0, 2.65, 3.25)):
        add_torus(
            collections["BrassEngineering"], parents["BrassEngineering"],
            f"LightWellRing_{well_ring:02d}", (0, 3.4, 0.56), radius, 0.10,
            (0, 0, 0), materials["brass"], "BrassEngineering",
            major_segments=32, minor_segments=6,
        )

    # Dense branch lattice with visible clamp modules and continuous sap paths.
    primary_ends = []
    for branch_index in range(28):
        angle = math.tau * branch_index / 28.0 + (branch_index % 3 - 1) * 0.035
        source_side = -1 if math.cos(angle) < 0 else 1
        start = Vector((source_side * 1.9, math.sin(angle) * 1.2, 31.0 + branch_index % 3 * 0.4))
        radius = 14.0 + (branch_index % 7) * 1.70
        end = Vector((math.cos(angle) * radius, math.sin(angle) * radius,
                      34.5 + math.sin(branch_index * 1.23) * 3.1))
        middle_a = start.lerp(end, 0.34) + Vector((0, 0, 3.4))
        middle_b = start.lerp(end, 0.70) + Vector((0, 0, 2.0))
        points = [start, middle_a, middle_b, end]
        radii = [1.22, 0.98, 0.68, 0.38]
        for segment in range(3):
            add_frustum(
                collections["Branches"], parents["Branches"],
                f"PrimaryBranch_{branch_index:02d}_{segment:02d}",
                points[segment], points[segment + 1], radii[segment], radii[segment + 1],
                9, materials["bark"], "Branches", "primary_branch_segment",
            )
            # A visible graphite bio-tech rail rides the living-wood branch.
            # It reads as engineered structure rather than another cyan vein.
            rail_start = points[segment] + Vector((0, 0, radii[segment] * 0.72))
            rail_end = points[segment + 1] + Vector((0, 0, radii[segment + 1] * 0.72))
            add_frustum(
                collections["Branches"], parents["Branches"],
                f"PrimaryLivingWoodWrap_{branch_index:02d}_{segment:02d}",
                rail_start, rail_end,
                max(0.12, radii[segment] * 0.24),
                max(0.08, radii[segment + 1] * 0.24),
                7, materials["bark_light"], "Branches", "living_wood_branch_wrap",
            )
        add_segment_collar(
            collections["BrassEngineering"], parents["BrassEngineering"],
            f"ArticulatedBranchJoint_{branch_index:02d}", middle_a, middle_b,
            0.98, 0.55, materials["brass"], "BrassEngineering", "branch_joint_clamp",
        )
        add_frustum(
            collections["CrystalTechnology"], parents["CrystalTechnology"],
            f"BranchSap_{branch_index:02d}", middle_a + Vector((0, 0, 0.66)),
            end + Vector((0, 0, 0.32)), 0.10, 0.055, 6, materials["cyan"],
            "CrystalTechnology", "branch_crystal_sap_conduit",
        )
        primary_ends.append(end)
    for branch_index in range(56):
        source = primary_ends[branch_index % len(primary_ends)]
        base_angle = math.atan2(source.y, source.x)
        angle = base_angle + (-0.23 if branch_index % 2 == 0 else 0.23)
        distance = 5.0 + (branch_index % 6) * 0.75
        end = source + Vector((math.cos(angle) * distance, math.sin(angle) * distance,
                               1.8 + (branch_index % 4) * 0.55))
        middle = source.lerp(end, 0.56) + Vector((0, 0, 0.9))
        for segment, (p0, p1, r0, r1) in enumerate((
            (source, middle, 0.52, 0.34),
            (middle, end, 0.34, 0.16),
        )):
            add_frustum(
                collections["Branches"], parents["Branches"],
                f"SecondaryBranch_{branch_index:02d}_{segment:02d}",
                p0, p1, r0, r1, 8, materials["black_tech"],
                "Branches", "black_biotech_secondary_core",
            )
            add_frustum(
                collections["Branches"], parents["Branches"],
                f"SecondaryLivingWoodFiber_{branch_index:02d}_{segment:02d}",
                p0 + Vector((0, 0, r0 * 0.68)),
                p1 + Vector((0, 0, r1 * 0.68)),
                max(0.075, r0 * 0.22), max(0.045, r1 * 0.22), 6,
                materials["bark"], "Branches", "living_wood_secondary_wrap",
            )

    # V3 crystal-powered canopy. Each ordered fan grows from a black bio-tech
    # spine, passes through a brass articulation collar, and receives cyan sap
    # from a local crystal reactor. Leaves are smaller and far more numerous
    # than v2, with nature, magic, solar science and sensor families deliberately
    # interleaved on every branch instead of segregated into flat color blobs.
    cluster_specs = []
    for count, radius, z, spread in (
        (28, 27.8, 30.8, 5.3),
        (24, 21.0, 35.0, 4.9),
        (20, 14.2, 39.2, 4.5),
        (16, 7.0, 43.1, 3.8),
    ):
        for index in range(count):
            angle = math.tau * index / count + RNG.uniform(-0.052, 0.052)
            cluster_specs.append((
                Vector((math.cos(angle) * radius, math.sin(angle) * radius,
                        z + RNG.uniform(-0.95, 0.95))),
                spread,
                angle,
            ))

    leaf_family_mix = [
        materials["forest"], materials["moss"], materials["jade"],
        materials["forest"], materials["moss"],
        materials["violet"], materials["lavender"],
        materials["solar_glass"], materials["sensor"],
    ]
    for cluster_index, (center, spread, angle) in enumerate(cluster_specs):
        if cluster_index % 9 == 0:
            key = "FoliageSolarGlass"
        elif cluster_index % 5 == 0 or cluster_index % 11 == 0:
            key = "FoliageMagic"
        else:
            key = "FoliageNature"

        radial = Vector((math.cos(angle), math.sin(angle), 0.0))
        spine_start = center - radial * (spread * 1.05) - Vector((0, 0, 0.85))
        spine_end = center + radial * (spread * 0.20) - Vector((0, 0, 0.16))
        add_frustum(
            collections["Branches"], parents["Branches"],
            f"LeafBioTechSpine_{cluster_index:03d}", spine_start, spine_end,
            0.34, 0.13, 7, materials["black_tech"],
            "Branches", "black_biotech_leaf_spine",
        )
        add_frustum(
            collections["CrystalTechnology"], parents["CrystalTechnology"],
            f"LeafEnergyBus_{cluster_index:03d}",
            spine_start + Vector((0, 0, 0.29)), spine_end + Vector((0, 0, 0.16)),
            0.052, 0.026, 6, materials["cyan"],
            "CrystalTechnology", "leaf_energy_bus",
        )
        add_segment_collar(
            collections["BrassEngineering"], parents["BrassEngineering"],
            f"LeafArticulationCollar_{cluster_index:03d}", spine_start, spine_end,
            0.43, 0.30, materials["brass"], "BrassEngineering", "leaf_articulation_collar",
        )
        if cluster_index % 2 == 0:
            node = add_crystal(
                collections["CrystalTechnology"], parents["CrystalTechnology"],
                f"LeafCrystalPowerNode_{cluster_index:03d}",
                spine_start.lerp(spine_end, 0.52) + Vector((0, 0, 0.58)),
                0.31 + (cluster_index % 4) * 0.025, 1.18,
                materials["crystal_violet"] if cluster_index % 6 == 0 else materials["cyan"],
            )
            node["module_type"] = "crystal_leaf_power_node"
        add_leaf_cluster(
            collections[key], parents[key], f"LayeredLeafCluster_{cluster_index:03d}",
            center, 56, leaf_family_mix[cluster_index % len(leaf_family_mix)],
            materials["leaf_circuit"], spread, (2.55, 4.65), key,
            flow_angle=angle,
            leaf_materials=leaf_family_mix,
            tech_material=materials["black_tech"],
            brass_material=materials["brass"],
        )

    # Twelve perimeter pylons with authored sockets and anchor plinths.
    for pylon_index in range(12):
        angle = math.tau * pylon_index / 12.0
        location = Vector((math.cos(angle) * 27.7, math.sin(angle) * 27.7, 2.25))
        add_cylinder_module(
            collections["Foundation"], parents["Foundation"],
            f"BeaconSocket_{pylon_index:02d}", location - Vector((0, 0, 1.55)),
            1.22, 1.25, materials["stone_dark"], "Foundation", "crystal_beacon_socket", 12,
        )
        add_crystal(
            collections["CrystalTechnology"], parents["CrystalTechnology"],
            f"CrystalPylon_{pylon_index:02d}", location, 0.78, 4.8, materials["cyan"],
        )
        add_torus(
            collections["BrassEngineering"], parents["BrassEngineering"],
            f"PylonCollar_{pylon_index:02d}", location - Vector((0, 0, 1.75)),
            0.94, 0.16, (0, 0, 0), materials["brass"], "BrassEngineering",
            major_segments=20, minor_segments=6,
        )
    for mote_index in range(20):
        angle = math.tau * mote_index / 20.0
        radius = 26.0 + (mote_index % 4) * 2.1
        add_crystal(
            collections["CrystalTechnology"], parents["CrystalTechnology"],
            f"OrbitingSeed_{mote_index:02d}",
            (math.cos(angle) * radius, math.sin(angle) * radius,
             34.0 + math.sin(mote_index * 1.7) * 5.2),
            0.24 + (mote_index % 3) * 0.07, 1.0 + (mote_index % 2) * 0.45,
            materials["cyan"],
        )

    # Structural crown mast and multi-axis astronomical halo support the star.
    add_frustum(
        collections["BrassEngineering"], parents["BrassEngineering"], "StructuralCrownMast",
        (0, 0, 36.0), (0, 0, 51.0), 0.72, 0.38, 12, materials["brass"],
        "BrassEngineering", "structural_crown_mast",
    )
    add_frustum(
        collections["CrystalTechnology"], parents["CrystalTechnology"], "CrownEnergySpine",
        (0, 0, 36.4), (0, 0, 51.2), 0.24, 0.14, 8, materials["cyan"],
        "CrystalTechnology", "crown_energy_spine",
    )
    for brace_index, angle in enumerate((0, math.pi * 0.5, math.pi, math.pi * 1.5)):
        add_frustum(
            collections["BrassEngineering"], parents["BrassEngineering"],
            f"CrownMastBrace_{brace_index:02d}",
            (math.cos(angle) * 3.0, math.sin(angle) * 3.0, 37.0),
            (0, 0, 47.0), 0.30, 0.18, 8, materials["brass"],
            "BrassEngineering", "crown_mast_brace",
        )
    add_star(
        collections["WisdomStar"], parents["WisdomStar"], "WisdomStarCore",
        (0, -0.15, 50.0), 3.0, 1.18, 0.52, materials["gold"],
    )
    top_star = add_star(
        collections["WisdomStar"], parents["WisdomStar"], "WisdomStarTopFacet",
        (0, 0, 50.0), 2.55, 1.0, 0.40, materials["gold"],
    )
    top_star.rotation_euler.x = math.radians(90)
    halo_specs = [
        (4.8, (0, 0, 0), 49.2),
        (6.1, (math.radians(90), 0, 0), 49.7),
        (7.3, (0, math.radians(90), 0), 50.2),
    ]
    for halo_index, (radius, rotation, z) in enumerate(halo_specs):
        add_torus(
            collections["WisdomStar"], parents["WisdomStar"],
            f"AstronomyHalo_{halo_index:02d}", (0, 0, z), radius,
            0.12 if halo_index < 2 else 0.16, rotation, materials["gold"],
            "WisdomStar", major_segments=48, minor_segments=8,
        )

    # Source-only guides and machine-readable collision layout keep Blender and
    # Godot aligned without importing dense foliage as collision geometry.
    trunk_collision_specs = [
        {"name": "TrunkPillarLeft", "x_m": -8.4, "radius_m": 3.25, "height_m": 27.0, "y_m": 13.5},
        {"name": "TrunkPillarRight", "x_m": 8.4, "radius_m": 3.25, "height_m": 27.0, "y_m": 13.5},
    ]
    root["collision_trunk_pillars_json"] = json.dumps(trunk_collision_specs)
    root["collision_root_proxies_json"] = json.dumps(collision_root_proxies)
    for spec in trunk_collision_specs:
        guide = add_frustum(
            collections["CollisionGuides"], parents["CollisionGuides"],
            f"COLLISION_{spec['name']}", (spec["x_m"], 0, 0.2),
            (spec["x_m"], 0, spec["height_m"]), spec["radius_m"], spec["radius_m"],
            10, materials["stone"], "CollisionGuides", "collision_guide",
        )
        guide.hide_render = True
        guide.hide_viewport = True
    return root


def source_mesh_objects(root):
    return [obj for obj in root.children_recursive if obj.type == 'MESH' and obj.get("export_group") != "CollisionGuides"]


def count_elements(objects):
    return {
        "vertices": sum(len(obj.data.vertices) for obj in objects),
        "edges": sum(len(obj.data.edges) for obj in objects),
        "faces": sum(len(obj.data.polygons) for obj in objects),
    }


def join_export_groups(source_objects):
    export_collection = new_collection("ARTEA_TREE_OF_LIFE_GAME_EXPORT")
    game_root = make_empty("ArteaTreeOfLifeModel", export_collection)
    game_root["source_editable_vertices_minimum"] = MIN_EDITABLE_VERTICES
    game_root["player_clear_path_m"] = PLAYER_CLEAR_PATH_M
    game_root["blueprint_revision"] = "component_sheets_2026_08_16"
    grouped = {}
    for source in source_objects:
        grouped.setdefault(source["export_group"], []).append(source)

    export_meshes = []
    for group_name in sorted(grouped):
        duplicates = []
        for source in grouped[group_name]:
            duplicate = source.copy()
            duplicate.data = source.data.copy()
            source_world = source.matrix_world.copy()
            duplicate.parent = None
            duplicate.matrix_world = source_world
            export_collection.objects.link(duplicate)
            duplicates.append(duplicate)
        bpy.ops.object.select_all(action='DESELECT')
        for duplicate in duplicates:
            duplicate.select_set(True)
        bpy.context.view_layer.objects.active = duplicates[0]
        # Joining keeps the active object's transform. Apply every duplicate's
        # world transform first so the optimized system mesh remains at an
        # identity transform instead of rotating/translating the whole tree by
        # whichever modular segment happened to be active.
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        bpy.ops.object.join()
        joined = bpy.context.active_object
        joined.name = group_name
        joined.data.name = f"{group_name}_GameMesh"
        joined.parent = game_root
        joined["system"] = group_name
        joined["source_module_count"] = len(grouped[group_name])
        export_meshes.append(joined)
    return game_root, export_meshes, grouped


def export_glb(game_root):
    bpy.ops.object.select_all(action='DESELECT')

    def select_recursive(obj):
        obj.select_set(True)
        for child in obj.children:
            select_recursive(child)

    select_recursive(game_root)
    bpy.context.view_layer.objects.active = game_root
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        use_selection=True,
        export_format='GLB',
        export_apply=True,
        export_yup=True,
        export_materials='EXPORT',
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_extras=True,
    )


def configure_scene():
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.length_unit = 'METERS'
    scene.unit_settings.scale_length = 1.0
    # Blender 5.2 exposes the Eevee Next renderer under the stable
    # BLENDER_EEVEE enum (the older *_NEXT identifier was removed).
    scene.render.engine = 'BLENDER_EEVEE'
    scene["asset_title"] = "ARTÉA TREE OF LIFE"
    scene["design_dimensions_m"] = (
        f"{DESIGN_HEIGHT_M:g}h x {CANOPY_DIAMETER_M:g} canopy x "
        f"{PLAYER_CLEAR_PATH_M:g} clear path x {FOUNDATION_DEPTH_M:g} foundation depth"
    )


def main():
    reset_scene()
    configure_scene()
    materials = create_materials()
    source_root = build_tree(materials)
    source_objects = source_mesh_objects(source_root)
    element_counts = count_elements(source_objects)
    editable_elements = sum(element_counts.values())
    if element_counts["vertices"] < MIN_EDITABLE_VERTICES:
        raise RuntimeError(
            f"Tree contains {element_counts['vertices']} editable vertices; "
            f"minimum is {MIN_EDITABLE_VERTICES}"
        )
    game_root, export_meshes, grouped = join_export_groups(source_objects)
    export_glb(game_root)

    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    manifest = {
        "asset": "artea_tree_of_life",
        "version": 3,
        "blueprint_revision": "crystal_powered_leaf_system_2026_08_16",
        "blueprint_references": [
            "design/tree_of_life/components/01_nature_living_root_architecture.png",
            "design/tree_of_life/components/02_magic_crystal_sap_energy.png",
            "design/tree_of_life/components/03_technology_engineered_growth.png",
            "design/tree_of_life/components/04_crystal_powered_leaf_system.png",
        ],
        "design": {
            "height_m": DESIGN_HEIGHT_M,
            "tree_height_without_crown_m": TREE_HEIGHT_WITHOUT_CROWN_M,
            "canopy_diameter_m": CANOPY_DIAMETER_M,
            "foundation_depth_m": FOUNDATION_DEPTH_M,
            "player_clear_path_m": PLAYER_CLEAR_PATH_M,
            "silhouette": "braided_twin_trunk_gothic_arch",
            "style": ["nature", "magic", "technology", "engineering"],
            "foliage_style": "dense_crystal_powered_branch_fans",
            "leaf_families": [
                "living_nature", "magic_rune", "solar_glass_science", "emerald_sensor"
            ],
        },
        "source": {
            "blend_path": os.path.relpath(BLEND_PATH, PROJECT_ROOT),
            "named_mesh_modules": len(source_objects),
            "editable_mesh_elements": editable_elements,
            **element_counts,
            "minimum_requested": MIN_EDITABLE_VERTICES,
            "requirement_definition": "distinct editable mesh vertices in the Blender source",
            "requirement_met": element_counts["vertices"] >= MIN_EDITABLE_VERTICES,
            "leaf_modules": sum(int(obj.get("leaf_module_count", 0)) for obj in source_objects),
            "leaf_power_nodes": sum(
                1 for obj in source_objects if obj.get("module_type") == "crystal_leaf_power_node"
            ),
            "leaf_tech_spines": sum(
                1 for obj in source_objects if obj.get("module_type") == "black_biotech_leaf_spine"
            ),
        },
        "game_export": {
            "glb_path": os.path.relpath(GLB_PATH, PROJECT_ROOT),
            "mesh_nodes": len(export_meshes),
            "source_modules_by_system": {key: len(value) for key, value in sorted(grouped.items())},
            "size_bytes": os.path.getsize(GLB_PATH),
        },
        "materials": sorted(material.name for material in materials.values()),
        "collision_policy": {
            "source_guides_only": True,
            "godot_uses_low_cost_authored_proxies": True,
            "canopy_collision": False,
            "clear_path_axis": "local Z / Blender Y",
            "scale_with_visual": True,
            "trunk_pillars": json.loads(source_root["collision_trunk_pillars_json"]),
            "root_proxies": json.loads(source_root["collision_root_proxies_json"]),
        },
    }
    with open(MANIFEST_PATH, "w", encoding="utf-8") as file:
        json.dump(manifest, file, indent=2)
    print(
        f"TREE_OF_LIFE_BUILD: PASS — {len(source_objects)} named modules, "
        f"{editable_elements} editable elements, {len(export_meshes)} game meshes"
    )
    print(f"TREE_OF_LIFE_BUILD: blend={BLEND_PATH}")
    print(f"TREE_OF_LIFE_BUILD: glb={GLB_PATH}")
    print(f"TREE_OF_LIFE_BUILD: manifest={MANIFEST_PATH}")


if __name__ == "__main__":
    main()
