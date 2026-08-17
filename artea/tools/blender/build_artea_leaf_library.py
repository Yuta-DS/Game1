"""Build the standalone Artéa high-detail leaf library.

This script intentionally does not load or modify the Tree of Life. Each leaf
type is a self-contained Blender root with logical modules and at least 10,000
directly editable mesh vertices.
"""

import json
import math
import os

import bpy
from mathutils import Euler, Vector


PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LEAF_ROOT = os.path.join(PROJECT_ROOT, "assets3D", "tree_of_life", "leaves")
SOURCE_DIR = os.path.join(LEAF_ROOT, "source")
GLB_DIR = os.path.join(LEAF_ROOT, "glb")
INDIVIDUAL_GLB_DIR = os.path.join(GLB_DIR, "individual")
BLEND_PATH = os.path.join(SOURCE_DIR, "artea_leaf_library.blend")
GLB_PATH = os.path.join(GLB_DIR, "artea_leaf_library.glb")
MANIFEST_PATH = os.path.join(LEAF_ROOT, "leaf_library_manifest.json")
LIVING_ALBEDO_PATH = os.path.join(LEAF_ROOT, "textures", "living_leaf_olive_albedo.png")
LIVING_BRANCH_ALBEDO_PATH = os.path.join(LEAF_ROOT, "textures", "living_branch_teal_albedo.png")
MIN_VERTICES_PER_LEAF = 10_000

for path in (SOURCE_DIR, GLB_DIR, INDIVIDUAL_GLB_DIR):
    os.makedirs(path, exist_ok=True)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def new_collection(name, parent=None):
    collection = bpy.data.collections.new(name)
    (parent or bpy.context.scene.collection).children.link(collection)
    return collection


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
    return material


def create_materials():
    materials = {
        "forest_a": make_material("MAT_LeafLibrary_ForestA", (0.055, 0.15, 0.035, 1), roughness=0.84),
        "forest_b": make_material("MAT_LeafLibrary_ForestB", (0.12, 0.27, 0.065, 1), roughness=0.80),
        "forest_c": make_material("MAT_LeafLibrary_ForestC", (0.23, 0.35, 0.09, 1), roughness=0.77),
        "living_vein": make_material("MAT_LeafLibrary_LivingVein", (0.025, 0.24, 0.34, 1), metallic=0.10,
                                       roughness=0.28, emission=(0.01, 0.28, 0.40, 1), emission_strength=0.48),
        "violet_a": make_material("MAT_LeafLibrary_VioletA", (0.22, 0.07, 0.42, 1), roughness=0.56,
                                    emission=(0.24, 0.06, 0.45, 1), emission_strength=0.42),
        "violet_b": make_material("MAT_LeafLibrary_VioletB", (0.42, 0.16, 0.66, 1), roughness=0.52,
                                    emission=(0.34, 0.09, 0.58, 1), emission_strength=0.34),
        "violet_c": make_material("MAT_LeafLibrary_VioletC", (0.60, 0.31, 0.74, 1), roughness=0.48),
        "glass_a": make_material("MAT_LeafLibrary_SolarGlassA", (0.02, 0.42, 0.56, 0.62), metallic=0.30, roughness=0.13,
                                   emission=(0.01, 0.36, 0.50, 1), emission_strength=0.62),
        "glass_b": make_material("MAT_LeafLibrary_SolarGlassB", (0.05, 0.62, 0.74, 0.50), metallic=0.24, roughness=0.10,
                                   emission=(0.02, 0.46, 0.61, 1), emission_strength=0.54),
        "glass_c": make_material("MAT_LeafLibrary_SolarGlassC", (0.04, 0.24, 0.43, 0.72), metallic=0.34, roughness=0.16,
                                   emission=(0.01, 0.22, 0.37, 1), emission_strength=0.38),
        "emerald_a": make_material("MAT_LeafLibrary_EmeraldA", (0.02, 0.27, 0.18, 1), metallic=0.16, roughness=0.42,
                                     emission=(0.01, 0.20, 0.14, 1), emission_strength=0.28),
        "emerald_b": make_material("MAT_LeafLibrary_EmeraldB", (0.05, 0.46, 0.31, 1), metallic=0.12, roughness=0.38),
        "cyan": make_material("MAT_LeafLibrary_CrystalCircuit", (0.04, 0.73, 0.90, 1), metallic=0.15, roughness=0.16,
                               emission=(0.02, 0.76, 1.0, 1), emission_strength=2.2),
        "cyan_soft": make_material("MAT_LeafLibrary_CrystalCircuitSoft", (0.03, 0.38, 0.52, 1), metallic=0.12, roughness=0.22,
                                    emission=(0.02, 0.46, 0.62, 1), emission_strength=1.1),
        "gold": make_material("MAT_LeafLibrary_GoldOutline", (0.76, 0.52, 0.15, 1), metallic=0.78, roughness=0.22),
        "brass": make_material("MAT_LeafLibrary_BrassConnector", (0.48, 0.27, 0.07, 1), metallic=0.84, roughness=0.26),
        "black": make_material("MAT_LeafLibrary_BlackBioTech", (0.008, 0.018, 0.026, 1), metallic=0.70, roughness=0.22),
        "crystal": make_material("MAT_LeafLibrary_CrystalNode", (0.22, 0.66, 0.95, 1), metallic=0.12, roughness=0.10,
                                  emission=(0.12, 0.68, 1.0, 1), emission_strength=2.6),
    }
    if not os.path.exists(LIVING_ALBEDO_PATH):
        raise RuntimeError(f"Living Leaf albedo texture is missing: {LIVING_ALBEDO_PATH}")
    if not os.path.exists(LIVING_BRANCH_ALBEDO_PATH):
        raise RuntimeError(f"Living branch albedo texture is missing: {LIVING_BRANCH_ALBEDO_PATH}")
    living_albedo = bpy.data.images.load(LIVING_ALBEDO_PATH, check_existing=True)
    living_albedo.name = "TEX_LivingLeaf_OliveAlbedo"
    for key in ("forest_a", "forest_b", "forest_c"):
        material = materials[key]
        texture = material.node_tree.nodes.new("ShaderNodeTexImage")
        texture.name = "LivingLeaf_OliveAlbedo"
        texture.label = "Living Leaf Olive Albedo"
        texture.image = living_albedo
        texture.extension = 'REPEAT'
        texture.interpolation = 'Linear'
        bsdf = material.node_tree.nodes.get("Principled BSDF")
        material.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
        material["source_texture"] = os.path.relpath(LIVING_ALBEDO_PATH, PROJECT_ROOT)
    branch_albedo = bpy.data.images.load(LIVING_BRANCH_ALBEDO_PATH, check_existing=True)
    branch_albedo.name = "TEX_LivingBranch_TealAlbedo"
    branch_material = materials["living_vein"]
    branch_texture = branch_material.node_tree.nodes.new("ShaderNodeTexImage")
    branch_texture.name = "LivingBranch_TealAlbedo"
    branch_texture.label = "Living Branch Teal Albedo"
    branch_texture.image = branch_albedo
    branch_texture.extension = 'REPEAT'
    branch_texture.interpolation = 'Linear'
    branch_bsdf = branch_material.node_tree.nodes.get("Principled BSDF")
    branch_material.node_tree.links.new(branch_texture.outputs["Color"], branch_bsdf.inputs["Base Color"])
    branch_material["source_texture"] = os.path.relpath(LIVING_BRANCH_ALBEDO_PATH, PROJECT_ROOT)
    return materials


def make_empty(name, collection, leaf_type, position):
    root = bpy.data.objects.new(name, None)
    collection.objects.link(root)
    root.location = position
    root.empty_display_type = 'CUBE'
    root.empty_display_size = 0.35
    root["leaf_type"] = leaf_type
    root["standalone_leaf_asset"] = True
    return root


def tag(obj, leaf_type, module_type):
    obj["leaf_type"] = leaf_type
    obj["module_type"] = module_type
    obj["editable"] = True
    return obj


def profile_width(kind, t, row):
    if t <= 0.0 or t >= 1.0:
        return 0.018
    exponent = {
        "living_leaf_fan": 0.60,
        "magic_rune_leaf": 0.72,
        "solar_glass_science_leaf": 0.70,
        "emerald_sensor_leaf": 0.80,
    }.get(kind, 0.70)
    base = math.sin(t * math.pi) ** exponent
    # The reference has a small number of designed edge notches. Alternating
    # every topology row made the first draft read like a circular saw, so the
    # dense grid now supports a lower-frequency authored silhouette.
    teeth, amplitude = {
        "living_leaf_fan": (7, 0.13),
        "magic_rune_leaf": (8, 0.14),
        "solar_glass_science_leaf": (5, 0.050),
        "emerald_sensor_leaf": (3, 0.018),
    }.get(kind, (5, 0.04))
    phase = (t * teeth + 0.18) % 1.0
    triangular_tooth = 1.0 - 4.0 * abs(phase - 0.5)
    serration = 1.0 + amplitude * triangular_tooth
    return base * serration


def add_blade_mesh(collection, parent, leaf_type, name, blade_specs, rows, columns, materials,
                   auto_vein_count=0):
    vertices = []
    uv_coordinates = []
    faces = []
    material_indices = []
    boundaries = []
    midribs = []
    side_veins = []
    for blade_index, spec in enumerate(blade_specs):
        origin = Vector(spec["origin"])
        angle = spec.get("angle", 0.0)
        scale = spec.get("scale", 1.0)
        length = spec["length"] * scale
        width = spec["width"] * scale
        transform = Euler((0.0, 0.0, angle), 'XYZ').to_matrix()
        base = len(vertices)
        upper = []
        lower = []
        for row in range(rows + 1):
            t = row / float(rows)
            x = t * length
            half_width = profile_width(leaf_type, t, row) * width
            curve = math.sin(t * math.pi) * width * 0.075
            for column in range(columns + 1):
                u = column / float(columns) * 2.0 - 1.0
                ridge = (1.0 - abs(u)) * width * 0.13
                ripple = math.sin((row + column) * 0.47) * width * 0.006
                local = Vector((x, u * half_width, ridge + curve + ripple))
                vertices.append(tuple(origin + transform @ local))
                uv_coordinates.append((t, (u + 1.0) * 0.5))
            lower.append(origin + transform @ Vector((x, -half_width, width * 0.10 + curve)))
            upper.append(origin + transform @ Vector((x, half_width, width * 0.10 + curve)))
        for row in range(rows):
            for column in range(columns):
                i = base + row * (columns + 1) + column
                faces.append((i, i + columns + 1, i + columns + 2, i + 1))
                # Keep the dense editable grid, but group color into broad
                # low-poly facets so the surface does not read as a checker.
                # Keep the topology dense without exposing its rectangular
                # construction grid in the finished material. Each Lego-like
                # blade/panel reads as one authored surface.
                material_indices.append(blade_index % len(materials))
        boundaries.append((lower, upper))
        midribs.append((origin + transform @ Vector((-0.12, 0, width * 0.16)),
                        origin + transform @ Vector((length * 0.97, 0, width * 0.13))))
        for vein_index in range(auto_vein_count):
            t = 0.18 + vein_index * (0.64 / max(1, auto_vein_count - 1))
            row = min(rows - 1, int(round(t * rows)))
            end_t = min(0.94, t + 0.12)
            end_row = min(rows - 1, int(round(end_t * rows)))
            reach = profile_width(leaf_type, end_t, end_row) * width * 0.75
            for side in (-1, 1):
                start = origin + transform @ Vector((t * length, 0, width * 0.17))
                end = origin + transform @ Vector((end_t * length, side * reach, width * 0.14))
                side_veins.append((start, end))
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update(calc_edges=True)
    uv_layer = mesh.uv_layers.new(name="LivingLeafUV" if leaf_type == "living_leaf_fan" else "LeafUV")
    for polygon in mesh.polygons:
        for loop_index in polygon.loop_indices:
            vertex_index = mesh.loops[loop_index].vertex_index
            uv_layer.data[loop_index].uv = uv_coordinates[vertex_index]
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = parent
    for material in materials:
        obj.data.materials.append(material)
    for polygon, index in zip(obj.data.polygons, material_indices):
        polygon.material_index = index
    tag(obj, leaf_type, "blade_facets")
    return obj, boundaries, midribs, side_veins


def add_ribbon_network(collection, parent, leaf_type, name, segments, width, material, module_type):
    vertices = []
    faces = []
    for start, end in segments:
        start = Vector(start)
        end = Vector(end)
        direction = end - start
        tangent = Vector((-direction.y, direction.x, 0.0))
        if tangent.length_squared < 1e-8:
            tangent = Vector((0, 1, 0))
        tangent.normalize()
        tangent *= width
        lift = Vector((0, 0, width * 1.8))
        base = len(vertices)
        vertices.extend([
            tuple(start - tangent + lift), tuple(start + tangent + lift),
            tuple(end + tangent + lift), tuple(end - tangent + lift),
        ])
        faces.append((base, base + 1, base + 2, base + 3))
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update(calc_edges=True)
    uv_layer = mesh.uv_layers.new(name="RibbonUV")
    face_uvs = ((0.0, 0.0), (0.0, 1.0), (1.0, 1.0), (1.0, 0.0))
    for polygon in mesh.polygons:
        for corner, loop_index in enumerate(polygon.loop_indices):
            uv_layer.data[loop_index].uv = face_uvs[corner]
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = parent
    obj.data.materials.append(material)
    return tag(obj, leaf_type, module_type)


def add_frustum(collection, parent, leaf_type, name, p0, p1, radius, material, module_type, sides=12):
    p0 = Vector(p0)
    p1 = Vector(p1)
    direction = p1 - p0
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius, radius2=radius * 0.92,
                                    depth=direction.length, location=(p0 + p1) * 0.5)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(direction.normalized())
    for existing in list(obj.users_collection):
        existing.objects.unlink(obj)
    collection.objects.link(obj)
    obj.parent = parent
    obj.data.materials.append(material)
    return tag(obj, leaf_type, module_type)


def add_connector(collection, parent, leaf_type, origin, materials, scale=1.0):
    origin = Vector(origin)
    add_frustum(collection, parent, leaf_type, "BlackStemContact", origin + Vector((-0.45, 0, 0)),
                origin + Vector((0.25, 0, 0)), 0.12 * scale, materials["black"], "black_stem_contact", 10)
    add_frustum(collection, parent, leaf_type, "BrassConnectorCore", origin + Vector((-0.95, 0, 0)),
                origin + Vector((-0.40, 0, 0)), 0.19 * scale, materials["brass"], "brass_connector", 12)
    for index, x in enumerate((-0.83, -0.52)):
        add_frustum(collection, parent, leaf_type, f"ConnectorBand_{index:02d}",
                    origin + Vector((x - 0.055, 0, 0)), origin + Vector((x + 0.055, 0, 0)),
                    0.235 * scale, materials["gold"], "connector_band", 12)


def add_nodes(collection, parent, leaf_type, name, positions, radius, material, module_type):
    for index, position in enumerate(positions):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=radius, location=position)
        obj = bpy.context.active_object
        obj.name = f"{name}_{index:02d}"
        for existing in list(obj.users_collection):
            existing.objects.unlink(obj)
        collection.objects.link(obj)
        obj.parent = parent
        obj.data.materials.append(material)
        tag(obj, leaf_type, module_type)


def boundary_segments(boundaries):
    result = []
    for lower, upper in boundaries:
        for points in (lower, upper):
            result.extend((points[index], points[index + 1]) for index in range(len(points) - 1))
        result.append((lower[-1], upper[-1]))
    return result


def circle_segments(center, radius, steps=20):
    center = Vector(center)
    points = [center + Vector((math.cos(index * math.tau / steps) * radius,
                               math.sin(index * math.tau / steps) * radius, 0))
              for index in range(steps)]
    return [(points[index], points[(index + 1) % steps]) for index in range(steps)]


def elevate_segments(segments, amount):
    lift = Vector((0, 0, amount))
    return [(Vector(start) + lift, Vector(end) + lift) for start, end in segments]


def polyline_segments(points):
    points = [Vector(point) for point in points]
    return [(points[index], points[index + 1]) for index in range(len(points) - 1)]


def build_living_fan(collection, parent, materials):
    leaf_type = "living_leaf_fan"
    specs = []
    for origin, angle, scale in (
        ((0.55, 0.52, 0.08), 1.56, 0.88),
        ((0.76, 0.70, 0.11), 1.18, 0.98),
        ((1.16, 1.02, 0.18), 0.91, 1.05),
        ((1.38, 0.92, 0.16), 0.38, 1.04),
        ((1.34, 0.62, 0.14), 0.04, 1.10),
        ((1.05, 0.36, 0.09), -0.28, 1.02),
        ((0.70, 0.23, 0.05), -0.62, 0.88),
    ):
        specs.append({"origin": origin, "angle": angle, "scale": scale,
                      "length": 2.55, "width": 0.78})
    boundaries = []
    midribs = []
    side_veins = []
    # Each of the seven visible small leaves is its own editable Lego-like
    # blade object rather than being fused into one broad canopy mesh.
    forest_materials = [materials["forest_b"], materials["forest_a"], materials["forest_c"],
                        materials["forest_b"], materials["forest_c"], materials["forest_a"],
                        materials["forest_b"]]
    for leaflet_index, spec in enumerate(specs):
        _, leaflet_boundaries, leaflet_midribs, leaflet_side_veins = add_blade_mesh(
            collection, parent, leaf_type, f"LivingFan_Leaflet_{leaflet_index + 1:02d}",
            [spec], 38, 28,
            [forest_materials[leaflet_index]], auto_vein_count=4)
        boundaries.extend(leaflet_boundaries)
        midribs.extend(leaflet_midribs)
        side_veins.extend(leaflet_side_veins)
    add_ribbon_network(collection, parent, leaf_type, "LivingFan_GoldOutline",
                       boundary_segments(boundaries), 0.016, materials["gold"], "gold_outline")
    add_ribbon_network(collection, parent, leaf_type, "LivingFan_CrystalVeins",
                       elevate_segments(midribs + side_veins, 0.20),
                       0.016, materials["living_vein"], "crystal_veins")
    origins = [Vector(spec["origin"]) for spec in specs]
    # One swept trunk and six ordered lateral branches. Each branch terminates
    # at its own leaflet base, after which the leaflet's midrib continues it.
    petioles = []
    petioles.extend(polyline_segments([
        (0.06, 0.00, 0.20), (0.34, 0.25, 0.22), (0.62, 0.53, 0.24),
        (0.90, 0.78, 0.26), origins[2] + Vector((0, 0, 0.10)),
    ]))
    petioles.extend(polyline_segments([(0.30, 0.22, 0.22), (0.43, 0.39, 0.23), origins[0]]))
    petioles.extend(polyline_segments([(0.53, 0.46, 0.24), (0.64, 0.60, 0.25), origins[1]]))
    petioles.extend(polyline_segments([(0.78, 0.67, 0.26), (1.02, 0.79, 0.27), origins[3]]))
    petioles.extend(polyline_segments([(0.66, 0.51, 0.24), (0.98, 0.56, 0.25), origins[4]]))
    petioles.extend(polyline_segments([(0.47, 0.34, 0.23), (0.73, 0.34, 0.23), origins[5]]))
    petioles.extend(polyline_segments([(0.28, 0.19, 0.21), (0.48, 0.20, 0.21), origins[6]]))
    add_ribbon_network(collection, parent, leaf_type, "LivingFan_EnergyPetioles",
                       elevate_segments(petioles, 0.12), 0.024,
                       materials["living_vein"], "energy_petioles")
    add_connector(collection, parent, leaf_type, Vector((0, 0, 0)), materials, 1.05)


def build_magic_leaf(collection, parent, materials):
    leaf_type = "magic_rune_leaf"
    specs = [{"origin": (0, 0, 0), "angle": 0.0, "scale": 1.0, "length": 5.8, "width": 1.98}]
    _, boundaries, midribs, side_veins = add_blade_mesh(
        collection, parent, leaf_type, "MagicRune_BladeFacets", specs, 115, 85,
        [materials["violet_a"], materials["violet_b"], materials["violet_c"]],
        auto_vein_count=0)
    add_ribbon_network(collection, parent, leaf_type, "MagicRune_GoldOutline",
                       boundary_segments(boundaries), 0.026, materials["gold"], "gold_outline")
    magic_veins = [
        ((-0.10, 0.00, 0.20), (1.15, 0.05, 0.22)),
        ((1.15, 0.05, 0.22), (2.35, 0.28, 0.24)),
        ((2.35, 0.28, 0.24), (3.55, 0.48, 0.23)),
        ((3.55, 0.48, 0.23), (5.55, 0.12, 0.20)),
        ((0.72, 0.03, 0.22), (1.05, 1.10, 0.20)),
        ((0.82, 0.04, 0.22), (1.12, -1.05, 0.20)),
        ((1.55, 0.12, 0.23), (2.02, 1.38, 0.20)),
        ((1.65, 0.14, 0.23), (2.05, -1.38, 0.20)),
        ((2.55, 0.31, 0.23), (3.20, 1.45, 0.19)),
        ((2.62, 0.31, 0.23), (3.20, -1.22, 0.19)),
        ((3.65, 0.45, 0.22), (4.35, 1.10, 0.18)),
        ((3.72, 0.43, 0.22), (4.35, -0.90, 0.18)),
        ((1.05, 1.10, 0.20), (2.02, 1.38, 0.20)),
        ((1.12, -1.05, 0.20), (2.05, -1.38, 0.20)),
        ((2.02, 1.38, 0.20), (3.20, 1.45, 0.19)),
        ((2.05, -1.38, 0.20), (3.20, -1.22, 0.19)),
    ]
    add_ribbon_network(collection, parent, leaf_type, "MagicRune_CrystalVeins",
                       elevate_segments(magic_veins, 0.34),
                       0.034, materials["cyan"], "crystal_veins")
    rune_segments = [((1.38, 0.55, 0.25), (1.70, 0.78, 0.25)),
                     ((2.70, -0.62, 0.25), (3.05, -0.38, 0.25)),
                     ((4.05, 0.70, 0.24), (4.38, 0.48, 0.24))]
    add_ribbon_network(collection, parent, leaf_type, "MagicRune_GlyphStrokes",
                       elevate_segments(rune_segments, 0.32),
                       0.030, materials["cyan"], "magic_rune_glyphs")
    add_connector(collection, parent, leaf_type, Vector((0, 0, 0)), materials)


def build_solar_leaf(collection, parent, materials):
    leaf_type = "solar_glass_science_leaf"
    specs = [{"origin": (0, 0, 0), "angle": 0.0, "scale": 1.0, "length": 5.65, "width": 2.02}]
    _, boundaries, midribs, side_veins = add_blade_mesh(
        collection, parent, leaf_type, "SolarGlass_BladeCells", specs, 115, 85,
        [materials["glass_a"], materials["glass_b"], materials["glass_c"]],
        auto_vein_count=0)
    add_ribbon_network(collection, parent, leaf_type, "SolarGlass_GoldFrame",
                       boundary_segments(boundaries), 0.027, materials["gold"], "solar_glass_frame")
    solar_main = [((-0.10, 0.00, 0.20), (1.15, 0.10, 0.22)),
                  ((1.15, 0.10, 0.22), (2.25, 0.28, 0.24)),
                  ((2.25, 0.28, 0.24), (3.35, 0.44, 0.23)),
                  ((3.35, 0.44, 0.23), (4.45, 0.54, 0.21)),
                  ((4.45, 0.54, 0.21), (5.55, 0.10, 0.18))]
    add_ribbon_network(collection, parent, leaf_type, "SolarGlass_CrystalVeins",
                       elevate_segments(solar_main, 0.35),
                       0.042, materials["cyan"], "crystal_veins")
    science_links = [
        ((0.55, 0.02, 0.19), (0.85, 0.85, 0.18)), ((0.55, 0.02, 0.19), (0.72, -0.78, 0.18)),
        ((0.85, 0.85, 0.18), (1.55, 1.42, 0.17)), ((0.72, -0.78, 0.18), (1.45, -1.38, 0.17)),
        ((1.15, 0.10, 0.20), (1.70, 0.82, 0.19)), ((1.15, 0.10, 0.20), (1.62, -0.62, 0.19)),
        ((1.55, 1.42, 0.17), (2.52, 1.62, 0.16)), ((1.45, -1.38, 0.17), (2.42, -1.65, 0.16)),
        ((1.70, 0.82, 0.19), (2.52, 1.62, 0.16)), ((1.70, 0.82, 0.19), (2.25, 0.28, 0.20)),
        ((1.62, -0.62, 0.19), (2.42, -1.65, 0.16)), ((1.62, -0.62, 0.19), (2.25, 0.28, 0.20)),
        ((2.52, 1.62, 0.16), (3.45, 1.55, 0.16)), ((2.42, -1.65, 0.16), (3.42, -1.48, 0.16)),
        ((2.25, 0.28, 0.20), (2.95, 0.98, 0.18)), ((2.25, 0.28, 0.20), (2.92, -0.72, 0.18)),
        ((2.95, 0.98, 0.18), (3.45, 1.55, 0.16)), ((2.95, 0.98, 0.18), (3.35, 0.44, 0.20)),
        ((2.92, -0.72, 0.18), (3.42, -1.48, 0.16)), ((2.92, -0.72, 0.18), (3.35, 0.44, 0.20)),
        ((3.45, 1.55, 0.16), (4.35, 1.12, 0.16)), ((3.42, -1.48, 0.16), (4.32, -1.08, 0.16)),
        ((3.35, 0.44, 0.20), (3.95, 0.95, 0.18)), ((3.35, 0.44, 0.20), (3.92, -0.55, 0.18)),
        ((3.95, 0.95, 0.18), (4.35, 1.12, 0.16)), ((3.92, -0.55, 0.18), (4.32, -1.08, 0.16)),
        ((4.35, 1.12, 0.16), (5.05, 0.65, 0.15)), ((4.32, -1.08, 0.16), (5.05, -0.45, 0.15)),
        ((4.45, 0.54, 0.20), (5.05, 0.65, 0.15)), ((4.45, 0.54, 0.20), (5.05, -0.45, 0.15)),
    ]
    add_ribbon_network(collection, parent, leaf_type, "SolarGlass_ScienceNetwork",
                       elevate_segments(science_links, 0.35),
                       0.024, materials["cyan_soft"], "science_cell_network")
    add_connector(collection, parent, leaf_type, Vector((0, 0, 0)), materials)


def build_sensor_leaf(collection, parent, materials):
    leaf_type = "emerald_sensor_leaf"
    specs = [{"origin": (0, 0, 0), "angle": 0.0, "scale": 1.0, "length": 3.35, "width": 1.20}]
    _, boundaries, midribs, side_veins = add_blade_mesh(
        collection, parent, leaf_type, "EmeraldSensor_BladeFacets", specs, 100, 95,
        [materials["emerald_a"], materials["emerald_b"]], auto_vein_count=0)
    add_ribbon_network(collection, parent, leaf_type, "EmeraldSensor_GoldOutline",
                       boundary_segments(boundaries), 0.022, materials["gold"], "gold_outline")
    sensor_traces = [((-0.08, 0.00, 0.18), (1.00, 0.08, 0.21)),
                     ((1.00, 0.08, 0.21), (2.15, 0.46, 0.20)),
                     ((2.15, 0.46, 0.20), (3.20, 0.10, 0.17)),
                     ((0.82, 0.06, 0.20), (1.20, 0.72, 0.18)),
                     ((1.15, 0.12, 0.20), (1.55, -0.66, 0.18)),
                     ((2.05, 0.42, 0.20), (2.35, -0.36, 0.18))]
    glyph_center = (2.36, 0.46, 0.22)
    sensor_traces.extend(circle_segments(glyph_center, 0.24, 18))
    add_ribbon_network(collection, parent, leaf_type, "EmeraldSensor_CircuitTraces",
                       elevate_segments(sensor_traces, 0.22),
                       0.025, materials["cyan"], "sensor_circuits")
    nodes = [Vector((1.35, 0.50, 0.24)), Vector((1.72, -0.42, 0.22)),
             Vector((2.72, -0.20, 0.20))]
    add_nodes(collection, parent, leaf_type, "EmeraldSensorMark", nodes, 0.060,
              materials["crystal"], "emerald_sensor_mark")
    add_connector(collection, parent, leaf_type, Vector((0, 0, 0)), materials, 0.78)


def descendants(root):
    result = []
    pending = list(root.children)
    while pending:
        obj = pending.pop()
        result.append(obj)
        pending.extend(obj.children)
    return result


def leaf_counts(root):
    meshes = [obj for obj in descendants(root) if obj.type == 'MESH']
    return {
        "named_modules": len(meshes),
        "vertices": sum(len(obj.data.vertices) for obj in meshes),
        "edges": sum(len(obj.data.edges) for obj in meshes),
        "faces": sum(len(obj.data.polygons) for obj in meshes),
    }


def main():
    reset_scene()
    materials = create_materials()
    library = new_collection("ARTEA_STANDALONE_LEAF_LIBRARY")
    specs = [
        ("LivingLeafFan", "living_leaf_fan", (-5.8, 3.0, 0.0), build_living_fan),
        ("MagicRuneLeaf", "magic_rune_leaf", (2.8, 3.0, 0.0), build_magic_leaf),
        ("SolarGlassScienceLeaf", "solar_glass_science_leaf", (-4.8, -3.3, 0.0), build_solar_leaf),
        ("EmeraldSensorLeaf", "emerald_sensor_leaf", (3.6, -3.2, 0.0), build_sensor_leaf),
    ]
    roots = []
    manifest_leaves = {}
    for name, leaf_type, position, builder in specs:
        collection = new_collection(f"LEAF_{name}", library)
        root = make_empty(name, collection, leaf_type, position)
        builder(collection, root, materials)
        counts = leaf_counts(root)
        if counts["vertices"] < MIN_VERTICES_PER_LEAF:
            raise RuntimeError(
                f"{leaf_type} has {counts['vertices']} vertices; expected at least 10,000")
        root["editable_vertices"] = counts["vertices"]
        root["named_modules"] = counts["named_modules"]
        roots.append(root)
        manifest_leaves[leaf_type] = counts

    bpy.context.scene["asset_scope"] = "standalone_leaves_only"
    bpy.context.scene["reference_image"] = "codex-clipboard-86c29e54-72e3-43fd-b039-3cde5127183a.png"
    bpy.context.scene["minimum_editable_vertices_per_leaf"] = MIN_VERTICES_PER_LEAF
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)

    bpy.ops.object.select_all(action='DESELECT')
    for root in roots:
        root.select_set(True)
        for obj in descendants(root):
            obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format='GLB',
        use_selection=True,
        export_cameras=False,
        export_lights=False,
        export_apply=True,
    )
    individual_glbs = {}
    for root in roots:
        original_location = root.location.copy()
        root.location = (0, 0, 0)
        bpy.ops.object.select_all(action='DESELECT')
        root.select_set(True)
        for obj in descendants(root):
            obj.select_set(True)
        filename = f"{root.get('leaf_type')}.glb"
        filepath = os.path.join(INDIVIDUAL_GLB_DIR, filename)
        bpy.ops.export_scene.gltf(
            filepath=filepath,
            export_format='GLB',
            use_selection=True,
            export_cameras=False,
            export_lights=False,
            export_apply=True,
        )
        root.location = original_location
        individual_glbs[root.get("leaf_type")] = os.path.relpath(filepath, PROJECT_ROOT)
    manifest = {
        "asset": "artea_standalone_leaf_library",
        "version": 2,
        "design_revision": "reference_authored_organic_branch_maps",
        "scope": "leaves_only_no_tree_geometry",
        "reference_image": "codex-clipboard-86c29e54-72e3-43fd-b039-3cde5127183a.png",
        "minimum_editable_vertices_per_leaf": MIN_VERTICES_PER_LEAF,
        "source_blend": os.path.relpath(BLEND_PATH, PROJECT_ROOT),
        "game_glb": os.path.relpath(GLB_PATH, PROJECT_ROOT),
        "individual_game_glbs": individual_glbs,
        "textures": {
            "living_leaf_olive_albedo": os.path.relpath(LIVING_ALBEDO_PATH, PROJECT_ROOT),
            "living_branch_teal_albedo": os.path.relpath(LIVING_BRANCH_ALBEDO_PATH, PROJECT_ROOT),
        },
        "leaves": manifest_leaves,
        "materials": sorted(material.name for material in materials.values()),
        "tree_files_modified": False,
    }
    with open(MANIFEST_PATH, "w", encoding="utf-8") as file:
        json.dump(manifest, file, indent=2)
    print("ARTEA_LEAF_LIBRARY_BUILD: PASS")
    for leaf_type, counts in manifest_leaves.items():
        print(f"  {leaf_type}: {counts['vertices']} editable vertices, {counts['named_modules']} modules")
    print(f"  blend={BLEND_PATH}")
    print(f"  glb={GLB_PATH}")


if __name__ == "__main__":
    main()
