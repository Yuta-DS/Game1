"""Build the screenshot-matched Mind Spark floating platform (Component 01 V2).

The hierarchy is deliberately Lego-like:
  complete platform -> 16 sector / 8 crystal assemblies -> semantic chunks
  -> 3,000 disconnected, individually selectable micro-pieces.

Run:
    blender --background --python tools/blender/build_mind_spark_station_component_01_reference_v2.py
"""

from __future__ import annotations

import json
import math
import os
from collections import OrderedDict

import bpy
from mathutils import Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "artifacts", "blender_mind_spark_station_components")
BLEND_PATH = os.path.join(
    ROOT, "assets3D", "mind_spark", "station_components", "blend",
    "01_floating_platform_reference_match_v2.blend",
)
ASSEMBLED_PATH = os.path.join(OUT_DIR, "01_reference_match_v2_assembled.png")
UNDERSIDE_PATH = os.path.join(OUT_DIR, "01_reference_match_v2_underside.png")
EXPLODED_PATH = os.path.join(OUT_DIR, "01_reference_match_v2_exploded.png")
MANIFEST_PATH = os.path.join(OUT_DIR, "01_reference_match_v2_manifest.json")
TEXTURE_DIR = os.path.join(ROOT, "assets", "textures", "mind_spark", "station_components", "v2")
TEXTURES = {
    "deck": os.path.join(TEXTURE_DIR, "deck_painted_alloy_v2.png"),
    "underside": os.path.join(TEXTURE_DIR, "underside_charcoal_tech_v2.png"),
    "crystal": os.path.join(TEXTURE_DIR, "crystal_cyan_facets_v2.png"),
    "gold": os.path.join(TEXTURE_DIR, "ring_gold_inlay_v2.png"),
    "cyan": os.path.join(TEXTURE_DIR, "ring_cyan_energy_v2.png"),
}

COMPONENT_ID = "01_floating_platform_reference_match_v2"
SECTOR_COUNT = 16
CRYSTAL_COUNT = 8
DIAMETER = 10.0
HEIGHT = 1.2

COUNTS = OrderedDict(
    deck_surface=1024,
    outer_rim=512,
    underside_frame=512,
    ring_systems=512,
    crystal_assemblies=256,
    connectors=64,
    floating_island_bottom=120,
)
EXPECTED_TOTAL = sum(COUNTS.values())

PALETTE = OrderedDict(
    soft_grey="#667083",
    soft_grey_light="#858EA0",
    charcoal="#151C2B",
    deep_structure="#0B1220",
    cyan="#00B2C7",
    cyan_light="#73E9F5",
    wisdom_gold="#FFD968",
    silver_blue="#B8D9DF",
    violet="#7458BE",
)


def hex_rgba(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4)) + (1.0,)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def textured_material(name, hex_value, metallic, roughness, emission=0.0,
                      texture_scale=7.0, bump_strength=0.055,
                      texture_path=None, use_image_color=True):
    """Stylized painted-metal shader with very restrained surface variation."""
    color = hex_rgba(hex_value)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = color
    mat["palette_hex"] = hex_value
    mat["texture_style"] = "subtle procedural painted metal"
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = bump_strength
    bump.inputs["Distance"].default_value = 0.035
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emission
    if texture_path and os.path.exists(texture_path):
        texcoord = nodes.new("ShaderNodeTexCoord")
        mapping = nodes.new("ShaderNodeMapping")
        image = nodes.new("ShaderNodeTexImage")
        image.image = bpy.data.images.load(texture_path, check_existing=True)
        image.projection = "BOX"
        image.projection_blend = 0.16
        mapping.inputs["Scale"].default_value = (texture_scale, texture_scale, texture_scale)
        links.new(texcoord.outputs["Generated"], mapping.inputs["Vector"])
        links.new(mapping.outputs["Vector"], image.inputs["Vector"])
        links.new(image.outputs["Color"], bump.inputs["Height"])
        if use_image_color:
            links.new(image.outputs["Color"], bsdf.inputs["Base Color"])
            if emission:
                links.new(image.outputs["Color"], bsdf.inputs["Emission Color"])
        mat["texture_image"] = os.path.relpath(texture_path, ROOT)
    else:
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = texture_scale
        noise.inputs["Detail"].default_value = 2.0
        noise.inputs["Roughness"].default_value = 0.55
        links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def create_materials():
    return {
        "deck": textured_material("MSK_V2_PaintedDeck", PALETTE["soft_grey"], 0.38, 0.55,
                                  texture_scale=1.6, texture_path=TEXTURES["deck"]),
        "deck_light": textured_material("MSK_V2_DeckEdge", PALETTE["soft_grey_light"], 0.42, 0.48,
                                        texture_scale=1.35, texture_path=TEXTURES["deck"]),
        "charcoal": textured_material("MSK_V2_CharcoalMetal", PALETTE["charcoal"], 0.62, 0.40,
                                      texture_scale=1.2, texture_path=TEXTURES["underside"]),
        "deep": textured_material("MSK_V2_DeepStructure", PALETTE["deep_structure"], 0.58, 0.50,
                                  texture_scale=1.0, texture_path=TEXTURES["underside"]),
        "cyan": textured_material("MSK_V2_CyanEnergy", PALETTE["cyan"], 0.20, 0.20, 2.0, 1.1, 0.02,
                                  TEXTURES["cyan"], False),
        "cyan_light": textured_material("MSK_V2_CrystalLight", PALETTE["cyan_light"], 0.08, 0.15, 2.4, 1.4, 0.018,
                                        TEXTURES["crystal"], True),
        "gold": textured_material("MSK_V2_WisdomGold", PALETTE["wisdom_gold"], 0.72, 0.30, 0.22, 1.1, 0.025,
                                  TEXTURES["gold"], False),
        "silver": textured_material("MSK_V2_SilverBlue", PALETTE["silver_blue"], 0.66, 0.34,
                                    texture_scale=1.15, texture_path=TEXTURES["underside"],
                                    use_image_color=False),
        "violet": textured_material("MSK_V2_VioletCrystal", PALETTE["violet"], 0.12, 0.18, 1.2, 1.4, 0.018,
                                    TEXTURES["crystal"], True),
    }


class PieceMesh:
    """One responsive mesh object containing disconnected editable islands."""

    def __init__(self, name):
        self.name = name
        self.vertices = []
        self.faces = []
        self.piece_ids = []
        self.material_ids = []
        self.count = 0

    def add_piece(self, vertices, faces, material_index=0):
        offset = len(self.vertices)
        self.vertices.extend(vertices)
        if isinstance(material_index, int):
            face_materials = [material_index] * len(faces)
        else:
            face_materials = list(material_index)
            if len(face_materials) != len(faces):
                raise ValueError(
                    f"{self.name}: expected {len(faces)} face material indices, "
                    f"received {len(face_materials)}"
                )
        for face, face_material in zip(faces, face_materials):
            self.faces.append(tuple(offset + index for index in face))
            self.piece_ids.append(self.count)
            self.material_ids.append(face_material)
        self.count += 1

    @staticmethod
    def surface_materials(material_index, side_count=4):
        """Expand (bottom, top, sides) into one material index per face."""
        if isinstance(material_index, int):
            return material_index
        bottom, top, sides = material_index
        return [bottom, top] + [sides] * side_count

    def wedge(self, r0, r1, a0, a1, z0, z1, material_index=0):
        verts = []
        for z in (z0, z1):
            verts.extend([
                (r0 * math.cos(a0), r0 * math.sin(a0), z),
                (r1 * math.cos(a0), r1 * math.sin(a0), z),
                (r1 * math.cos(a1), r1 * math.sin(a1), z),
                (r0 * math.cos(a1), r0 * math.sin(a1), z),
            ])
        self.add_piece(
            verts,
            ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)),
            self.surface_materials(material_index),
        )

    def sloped_wedge(self, r0, r1, a0, a1, inner_z, outer_z, thickness,
                     material_index=0):
        """Faceted radial plate descending toward the floating-island core."""
        verts = [
            (r0 * math.cos(a0), r0 * math.sin(a0), inner_z - thickness),
            (r1 * math.cos(a0), r1 * math.sin(a0), outer_z - thickness),
            (r1 * math.cos(a1), r1 * math.sin(a1), outer_z - thickness),
            (r0 * math.cos(a1), r0 * math.sin(a1), inner_z - thickness),
            (r0 * math.cos(a0), r0 * math.sin(a0), inner_z),
            (r1 * math.cos(a0), r1 * math.sin(a0), outer_z),
            (r1 * math.cos(a1), r1 * math.sin(a1), outer_z),
            (r0 * math.cos(a1), r0 * math.sin(a1), inner_z),
        ]
        self.add_piece(
            verts,
            ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)),
            self.surface_materials(material_index),
        )

    def box(self, center, size, angle=0.0, material_index=0):
        cx, cy, cz = center
        sx, sy, sz = (value * 0.5 for value in size)
        ca, sa = math.cos(angle), math.sin(angle)
        verts = []
        for x, y, z in (
            (-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
            (-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz),
        ):
            verts.append((cx + x * ca - y * sa, cy + x * sa + y * ca, cz + z))
        self.add_piece(
            verts,
            ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)),
            self.surface_materials(material_index),
        )

    def frustum(self, center, radius0, radius1, z0, z1, sides=4,
                angle=0.0, material_index=0):
        cx, cy = center
        verts = []
        for z, radius in ((z0, radius0), (z1, radius1)):
            for index in range(sides):
                a = angle + math.tau * index / sides
                verts.append((cx + radius * math.cos(a), cy + radius * math.sin(a), z))
        faces = [tuple(reversed(range(sides))), tuple(range(sides, sides * 2))]
        for index in range(sides):
            nxt = (index + 1) % sides
            faces.append((index, nxt, sides + nxt, sides + index))
        self.add_piece(verts, faces, self.surface_materials(material_index, sides))

    def finish(self, collection, parent, materials, material_keys, semantic, big_component):
        mesh = bpy.data.meshes.new(f"{self.name}_Mesh")
        mesh.from_pydata(self.vertices, [], self.faces)
        for key in material_keys:
            mesh.materials.append(materials[key])
        for polygon, material_id in zip(mesh.polygons, self.material_ids):
            polygon.material_index = material_id
            polygon.use_smooth = False
        attr = mesh.attributes.new("piece_id", type="INT", domain="FACE")
        for value, piece_id in zip(attr.data, self.piece_ids):
            value.value = piece_id
        mesh.update()
        obj = bpy.data.objects.new(self.name, mesh)
        collection.objects.link(obj)
        obj.parent = parent
        obj["assembly_level_1"] = "complete_floating_platform"
        obj["assembly_level_2"] = big_component
        obj["assembly_level_3"] = semantic
        obj["editable_micro_piece_count"] = self.count
        obj["edit_instruction"] = "Edit Mode: hover a piece and press L (Select Linked)"
        obj["surface_texture_policy"] = "face-level: bottom, top and edge materials assigned independently"
        return obj


def new_empty(name, collection, parent=None):
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.parent = parent
    obj.empty_display_type = "CUBE"
    obj.empty_display_size = 0.22
    return obj


def sector_bounds(index):
    step = math.tau / SECTOR_COUNT
    gap = step * 0.018
    return index * step + gap, (index + 1) * step - gap


def sub_bounds(a0, a1, index, count):
    step = (a1 - a0) / count
    return a0 + index * step, a0 + (index + 1) * step


def build_sector(index, collection, root, materials):
    number = index + 1
    sector = new_empty(f"SECTOR_{number:02d}_BIG_COMPONENT", collection, root)
    sector["large_component"] = "radial wedge module"
    a0, a1 = sector_bounds(index)
    amid = (a0 + a1) * 0.5
    objects = []

    # 64 top micro-plates: visually continuous inside one clearly separated wedge.
    build = PieceMesh(f"S{number:02d}_A_DECK_64")
    for radial in range(8):
        r0 = 0.03 + radial * (4.65 / 8)
        r1 = 0.03 + (radial + 1) * (4.65 / 8)
        for angular in range(8):
            sa0, sa1 = sub_bounds(a0, a1, angular, 8)
            top_material = 2 if radial == 7 else 1
            build.wedge(r0, r1, sa0, sa1, 0.88, 1.12, (0, top_material, top_material))
    objects.append(build.finish(collection, sector, materials, ("charcoal", "deck", "deck_light"),
                                "top deck micro-plates", sector.name))

    # 32 wall pieces: four stacked courses, eight cells wide.
    build = PieceMesh(f"S{number:02d}_B_OUTER_RIM_32")
    for layer in range(4):
        z0 = 0.22 + layer * 0.165
        for angular in range(8):
            sa0, sa1 = sub_bounds(a0, a1, angular, 8)
            build.wedge(4.66, 5.0, sa0, sa1, z0, z0 + 0.16, (0, 1, 0))
    objects.append(build.finish(collection, sector, materials, ("charcoal", "deck"),
                                "segmented outer wall", sector.name))

    # 32 underside floor/frame pieces.
    build = PieceMesh(f"S{number:02d}_C_UNDERFRAME_32")
    for radial in range(4):
        r0 = 1.05 + radial * 0.89
        r1 = r0 + 0.88
        for angular in range(8):
            sa0, sa1 = sub_bounds(a0, a1, angular, 8)
            build.wedge(r0, r1, sa0, sa1, 0.05, 0.20, (0, 1, 0))
    objects.append(build.finish(collection, sector, materials, ("deep", "charcoal"),
                                "underside metal frame", sector.name))

    # 32 ring-system pieces: gold, cyan, outer cyan nodes and dark channels.
    build = PieceMesh(f"S{number:02d}_D_RING_SYSTEM_32")
    for angular in range(8):
        sa0, sa1 = sub_bounds(a0, a1, angular, 8)
        build.wedge(3.72, 3.77, sa0, sa1, 1.125, 1.155, 0)
        build.wedge(1.04, 1.12, sa0, sa1, 1.128, 1.162, 1)
        build.wedge(4.82, 4.88, sa0, sa1, 0.72, 0.77, 1 if angular in (1, 6) else 2)
        build.wedge(3.65, 3.84, sa0, sa1, 1.115, 1.126, 2)
    objects.append(build.finish(collection, sector, materials, ("gold", "cyan", "charcoal"),
                                "recessed guidance and energy rings", sector.name))

    # Four chunky underside connectors per wedge.
    build = PieceMesh(f"S{number:02d}_E_CONNECTORS_04")
    for slot, radius in enumerate((2.15, 3.05, 4.20, 4.62)):
        z = -0.01 if slot < 2 else 0.03
        build.box((radius * math.cos(amid), radius * math.sin(amid), z),
                  (0.62, 0.22, 0.34), amid, (0, 1, 0))
    objects.append(build.finish(collection, sector, materials, ("charcoal", "silver"),
                                "snap connectors and support brackets", sector.name))
    return sector, objects


def build_crystal(index, collection, root, materials):
    number = index + 1
    angle = math.tau * index / CRYSTAL_COUNT + math.pi / 8
    center = (3.72 * math.cos(angle), 3.72 * math.sin(angle))
    bay = new_empty(f"CRYSTAL_BAY_{number:02d}_BIG_COMPONENT", collection, root)
    bay["large_component"] = "levitation crystal and metal mount"

    # Sixteen stacked faceted cells make one long crystal.
    build = PieceMesh(f"C{number:02d}_A_CRYSTAL_CELLS_16")
    for cell in range(16):
        t0 = cell / 16
        t1 = (cell + 1) / 16
        z_top = 0.13 - 2.15 * t0
        z_bottom = 0.13 - 2.15 * t1
        radius_top = 0.38 * (1.0 - t0) + 0.025
        radius_bottom = 0.38 * (1.0 - t1) + 0.025
        build.frustum(center, radius_bottom, radius_top, z_bottom, z_top, 4,
                      angle + math.pi / 4, 1 if index % 4 == 3 else 0)
    crystal_obj = build.finish(collection, bay, materials, ("cyan_light", "violet"),
                               "faceted luminous crystal cells", bay.name)

    # Sixteen dark/silver mount pieces hold the crystal beneath the rim.
    build = PieceMesh(f"C{number:02d}_B_MOUNT_PIECES_16")
    for piece in range(16):
        local_angle = angle + (piece - 7.5) * 0.012
        radius = 3.70 + (0.16 if piece % 2 else -0.10)
        build.box((radius * math.cos(local_angle), radius * math.sin(local_angle), 0.18),
                  (0.30, 0.095, 0.22), local_angle, (0, 1, 0))
    mount_obj = build.finish(collection, bay, materials, ("charcoal", "silver"),
                             "crystal suspension mount", bay.name)
    return bay, [crystal_obj, mount_obj]


def build_floating_bottom(collection, root, materials):
    """Build a tapered, visibly floating island underside from 120 pieces."""
    bottom = new_empty("FLOATING_ISLAND_BOTTOM_BIG_COMPONENT", collection, root)
    bottom["large_component"] = "tapered levitation island underside"
    objects = []

    # Thirty-two faceted skirt plates descend from the platform rim toward the core.
    build = PieceMesh("B01_SLOPED_ISLAND_PLATES_32")
    for sector in range(SECTOR_COUNT):
        a0, a1 = sector_bounds(sector)
        build.sloped_wedge(2.35, 4.58, a0, a1, -0.72, 0.08, 0.16, (0, 1, 0))
        build.sloped_wedge(0.72, 2.35, a0, a1, -1.22, -0.72, 0.16, (0, 1, 0))
    objects.append(build.finish(collection, bottom, materials, ("deep", "charcoal"),
                                "tapered floating-island skirt plates", bottom.name))

    # Sixteen cyan seams run down the skirt and visually explain levitation.
    build = PieceMesh("B02_CYAN_ENERGY_VEINS_16")
    for sector in range(SECTOR_COUNT):
        mid = math.tau * (sector + 0.5) / SECTOR_COUNT
        half = 0.012
        build.sloped_wedge(0.76, 4.42, mid - half, mid + half, -1.18, 0.10, 0.035, 0)
    objects.append(build.finish(collection, bottom, materials, ("cyan",),
                                "cyan levitation veins", bottom.name))

    # Sixteen metal socket jaws, two around each large hanging crystal.
    build = PieceMesh("B03_CRYSTAL_SOCKET_JAWS_16")
    for bay in range(CRYSTAL_COUNT):
        angle = math.tau * bay / CRYSTAL_COUNT + math.pi / 8
        for side in (-1, 1):
            local = angle + side * 0.055
            radius = 3.72
            build.box((radius * math.cos(local), radius * math.sin(local), -0.12),
                      (0.48, 0.18, 0.42), local, (0, 1, 0))
    objects.append(build.finish(collection, bottom, materials, ("charcoal", "silver"),
                                "crystal socket jaws", bottom.name))

    # Twenty-four perimeter stabilizer fins give the bottom a designed silhouette.
    build = PieceMesh("B04_PERIMETER_STABILIZER_FINS_24")
    for index in range(24):
        angle = math.tau * (index + 0.5) / 24
        radius = 4.34
        build.box((radius * math.cos(angle), radius * math.sin(angle), -0.40),
                  (0.52, 0.12, 0.72), angle, (0, 1, 0))
    objects.append(build.finish(collection, bottom, materials, ("charcoal", "silver"),
                                "perimeter stabilizer fins", bottom.name))

    # Thirty-two stacked cells form the central levitation core and bottom point.
    build = PieceMesh("B05_CENTRAL_LEVITATION_CORE_32")
    for cell in range(32):
        t0 = cell / 32
        t1 = (cell + 1) / 32
        z0 = -0.82 - 1.72 * t1
        z1 = -0.82 - 1.72 * t0
        radius0 = 0.72 * (1.0 - t1) + 0.055
        radius1 = 0.72 * (1.0 - t0) + 0.055
        build.frustum((0, 0), radius0, radius1, z0, z1, 8, math.pi / 8,
                      0 if cell % 4 else 1)
    objects.append(build.finish(collection, bottom, materials, ("cyan_light", "gold"),
                                "central levitation core cells", bottom.name))
    return bottom, objects


def build_component(materials, sector_collection, crystal_collection, bottom_collection, root):
    sector_roots, crystal_roots, objects = [], [], []
    for index in range(SECTOR_COUNT):
        sector, made = build_sector(index, sector_collection, root, materials)
        sector_roots.append(sector)
        objects.extend(made)
    for index in range(CRYSTAL_COUNT):
        crystal, made = build_crystal(index, crystal_collection, root, materials)
        crystal_roots.append(crystal)
        objects.extend(made)
    bottom_root, made = build_floating_bottom(bottom_collection, root, materials)
    objects.extend(made)
    return sector_roots, crystal_roots, bottom_root, objects


def add_render_rig(materials, collection):
    world = bpy.data.worlds.new("MindSparkReferenceWorld")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.003, 0.010, 0.026, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.18
    bpy.context.scene.world = world

    bpy.ops.mesh.primitive_plane_add(size=38, location=(0, 0, -2.62))
    floor = bpy.context.object
    floor.name = "RENDER_ONLY_ShadowFloor"
    for old in list(floor.users_collection):
        old.objects.unlink(floor)
    collection.objects.link(floor)
    floor.data.materials.append(materials["deep"])

    def light(name, location, energy, size, color):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.shape = "DISK"
        data.size = size
        data.color = color
        obj = bpy.data.objects.new(name, data)
        collection.objects.link(obj)
        obj.location = location
        obj.rotation_euler = ((Vector((0, 0, 0.2)) - obj.location).to_track_quat("-Z", "Y").to_euler())

    light("Key_SoftBlue", (6.0, -7.0, 8.5), 760, 5.5, (0.82, 0.91, 1.0))
    light("Fill_Cyan", (-5.5, -1.5, 4.5), 280, 4.0, (0.20, 0.64, 0.82))
    light("Rim_Cool", (1.5, 6.0, 4.0), 360, 3.5, (0.35, 0.62, 1.0))
    light("Gold_Glow", (-2.0, 0.5, 2.2), 90, 2.0, (1.0, 0.70, 0.30))
    light("Underside_CyanGlow", (0.0, -2.5, -2.25), 420, 3.2, (0.12, 0.72, 1.0))
    light("Underside_SoftFill", (-5.0, -3.5, -1.15), 260, 4.0, (0.36, 0.55, 0.82))

    camera_data = bpy.data.cameras.new("Component01V2Camera")
    camera = bpy.data.objects.new("Component01V2Camera", camera_data)
    collection.objects.link(camera)
    camera.location = (10.2, -13.0, 8.5)
    camera.rotation_euler = ((Vector((0, 0, 0.18)) - camera.location).to_track_quat("-Z", "Y").to_euler())
    camera_data.lens = 55
    bpy.context.scene.camera = camera
    return camera


def set_exploded(sectors, crystals, bottom, enabled):
    for index, sector in enumerate(sectors):
        if enabled:
            angle = math.tau * index / SECTOR_COUNT + math.pi / SECTOR_COUNT
            sector.location = (0.85 * math.cos(angle), 0.85 * math.sin(angle), 0.18 + 0.06 * (index % 2))
        else:
            sector.location = (0, 0, 0)
    for index, crystal in enumerate(crystals):
        if enabled:
            angle = math.tau * index / CRYSTAL_COUNT + math.pi / 8
            crystal.location = (0.45 * math.cos(angle), 0.45 * math.sin(angle), -0.50)
        else:
            crystal.location = (0, 0, 0)
    bottom.location = (0, 0, -1.05) if enabled else (0, 0, 0)


def configure_render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1200
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.look = "AgX - Medium High Contrast"


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def validate(objects):
    totals = OrderedDict((key, 0) for key in COUNTS)
    object_details = []
    semantic_map = {
        "top deck micro-plates": "deck_surface",
        "segmented outer wall": "outer_rim",
        "underside metal frame": "underside_frame",
        "recessed guidance and energy rings": "ring_systems",
        "faceted luminous crystal cells": "crystal_assemblies",
        "crystal suspension mount": "crystal_assemblies",
        "snap connectors and support brackets": "connectors",
        "tapered floating-island skirt plates": "floating_island_bottom",
        "cyan levitation veins": "floating_island_bottom",
        "crystal socket jaws": "floating_island_bottom",
        "perimeter stabilizer fins": "floating_island_bottom",
        "central levitation core cells": "floating_island_bottom",
    }
    for obj in objects:
        count = int(obj["editable_micro_piece_count"])
        semantic = obj["assembly_level_3"]
        totals[semantic_map[semantic]] += count
        attr = obj.data.attributes.get("piece_id")
        if not attr or len({item.value for item in attr.data}) != count:
            raise RuntimeError(f"{obj.name}: invalid piece_id attribute")
        face_material_counts = OrderedDict()
        for polygon in obj.data.polygons:
            material = obj.data.materials[polygon.material_index]
            if not material.get("texture_image"):
                raise RuntimeError(f"{obj.name}: material {material.name} has no applied texture image")
            face_material_counts[material.name] = face_material_counts.get(material.name, 0) + 1
        object_details.append({
            "object": obj.name,
            "big_component": obj["assembly_level_2"],
            "chunk": semantic,
            "editable_micro_pieces": count,
            "surface_material_faces": face_material_counts,
            "surface_texture_policy": obj["surface_texture_policy"],
        })
    if totals != COUNTS:
        raise RuntimeError(f"piece totals mismatch: {totals} != {COUNTS}")
    if sum(totals.values()) != EXPECTED_TOTAL:
        raise RuntimeError("unexpected total")
    return totals, object_details


def main():
    os.makedirs(os.path.dirname(BLEND_PATH), exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    reset_scene()
    materials = create_materials()

    main_collection = bpy.data.collections.new("01_REFERENCE_MATCH_V2")
    sectors_collection = bpy.data.collections.new("01A_DECK_SECTOR_ASSEMBLIES")
    crystals_collection = bpy.data.collections.new("01B_CRYSTAL_SUSPENSION_ASSEMBLIES")
    bottom_collection = bpy.data.collections.new("01C_FLOATING_ISLAND_BOTTOM_ASSEMBLY")
    render_collection = bpy.data.collections.new("01D_RENDER_RIG")
    bpy.context.scene.collection.children.link(main_collection)
    main_collection.children.link(sectors_collection)
    main_collection.children.link(crystals_collection)
    main_collection.children.link(bottom_collection)
    main_collection.children.link(render_collection)

    root = new_empty("MSK_01_REFERENCE_MATCH_V2_ROOT", main_collection)
    root.empty_display_type = "CIRCLE"
    root.empty_display_size = 5.0
    root["component_id"] = COMPONENT_ID
    root["reference"] = "Screenshot 2026-08-16 at 1.01.52 pm"
    root["diameter_m"] = DIAMETER
    root["height_m"] = HEIGHT
    root["editable_micro_piece_count"] = EXPECTED_TOTAL

    sectors, crystals, bottom, objects = build_component(
        materials, sectors_collection, crystals_collection, bottom_collection, root
    )
    totals, details = validate(objects)

    camera = add_render_rig(materials, render_collection)
    configure_render()
    set_exploded(sectors, crystals, bottom, False)
    render(ASSEMBLED_PATH)
    camera.location = (9.2, -11.8, 1.0)
    camera.rotation_euler = ((Vector((0, 0, -0.72)) - camera.location).to_track_quat("-Z", "Y").to_euler())
    render(UNDERSIDE_PATH)
    set_exploded(sectors, crystals, bottom, True)
    camera.location = (11.2, -14.2, 9.6)
    camera.rotation_euler = ((Vector((0, 0, -0.25)) - camera.location).to_track_quat("-Z", "Y").to_euler())
    render(EXPLODED_PATH)

    set_exploded(sectors, crystals, bottom, False)
    camera.location = (10.2, -13.0, 8.5)
    camera.rotation_euler = ((Vector((0, 0, 0.18)) - camera.location).to_track_quat("-Z", "Y").to_euler())

    readme = bpy.data.texts.new("README_COMPONENT_01_V2")
    readme.write(
        "MIND SPARK COMPONENT 01 — REFERENCE MATCH V2\n\n"
        "Hierarchy: complete platform > 16 sectors, 8 crystal bays and floating bottom > semantic chunks > micro-pieces.\n"
        "Select a semantic mesh, enter Edit Mode, hover one piece, and press L to select it.\n"
        "Every face carries a stable integer piece_id attribute.\n"
        "Five screenshot-derived PNG textures are applied to the deck, underside, crystals and both rings, and packed into this .blend.\n"
    )
    bpy.context.scene["editable_micro_piece_count"] = EXPECTED_TOTAL
    bpy.context.scene["reference_match"] = True
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH, compress=True)

    manifest = {
        "component_id": COMPONENT_ID,
        "reference_image": "Screenshot 2026-08-16 at 1.01.52 pm",
        "blender_version": bpy.app.version_string,
        "dimensions_m": {"diameter": DIAMETER, "height": HEIGHT},
        "hierarchy": {
            "complete_assembly": 1,
            "large_deck_sectors": SECTOR_COUNT,
            "large_crystal_bays": CRYSTAL_COUNT,
            "large_floating_bottom_assemblies": 1,
            "semantic_chunk_objects": len(objects),
            "editable_micro_pieces": EXPECTED_TOTAL,
        },
        "piece_counts": totals,
        "objects": details,
        "materials": {
            key: {"name": material.name, "palette_hex": material.get("palette_hex"),
                  "texture_style": material.get("texture_style"),
                  "texture_image": material.get("texture_image")}
            for key, material in materials.items()
        },
        "texture_assets": {key: os.path.relpath(path, ROOT) for key, path in TEXTURES.items()},
        "surface_application": {
            "verified": True,
            "policy": "every editable piece face resolves to a packed image-textured material; top, bottom and edges are assigned independently",
        },
        "outputs": {
            "blend": os.path.relpath(BLEND_PATH, ROOT),
            "assembled_render": os.path.relpath(ASSEMBLED_PATH, ROOT),
            "underside_render": os.path.relpath(UNDERSIDE_PATH, ROOT),
            "exploded_render": os.path.relpath(EXPLODED_PATH, ROOT),
            "manifest": os.path.relpath(MANIFEST_PATH, ROOT),
        },
    }
    with open(MANIFEST_PATH, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)

    print(f"MSK_COMPONENT_01_V2: pieces={EXPECTED_TOTAL}")
    print(f"MSK_COMPONENT_01_V2: blend={BLEND_PATH}")
    print(f"MSK_COMPONENT_01_V2: assembled={ASSEMBLED_PATH}")
    print(f"MSK_COMPONENT_01_V2: underside={UNDERSIDE_PATH}")
    print(f"MSK_COMPONENT_01_V2: exploded={EXPLODED_PATH}")
    print(f"MSK_COMPONENT_01_V2: manifest={MANIFEST_PATH}")


if __name__ == "__main__":
    main()
