"""Build Mind Spark station component 01: floating platform foundation.

Blender 5.2 headless usage:
    blender --background --python tools/blender/build_mind_spark_station_component_01.py

The source keeps 10,240 independently selectable disconnected mesh islands.
Each semantic system is one mesh object for a responsive Outliner; inside Edit
Mode every Lego-like micro-piece is isolated and carries a stable ``piece_id``
face attribute.
"""

from __future__ import annotations

import json
import math
import os
from collections import OrderedDict

import bpy
from mathutils import Vector


PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLEND_PATH = os.path.join(
    PROJECT_ROOT,
    "assets3D/mind_spark/station_components/blend/01_floating_platform_foundation.blend",
)
ARTIFACT_DIR = os.path.join(PROJECT_ROOT, "artifacts/blender_mind_spark_station_components")
ASSEMBLED_PATH = os.path.join(ARTIFACT_DIR, "01_floating_platform_assembled.png")
EXPLODED_PATH = os.path.join(ARTIFACT_DIR, "01_floating_platform_exploded.png")
MANIFEST_PATH = os.path.join(ARTIFACT_DIR, "01_manifest.json")

COMPONENT_ID = "01_floating_platform_foundation"
MIN_EDITABLE_ISLANDS = 10_000
DESIGN_DIAMETER_M = 10.0
DESIGN_PLATFORM_HEIGHT_M = 1.2
RNG_SEED = 260301

# Canonical Mind Spark palette from the project design document. Values are
# converted from sRGB hex by Blender when displayed through Filmic/AgX.
PALETTE = OrderedDict(
    midnight_blue=("#143343", (0x14 / 255, 0x33 / 255, 0x43 / 255, 1.0)),
    cyan=("#00B2C7", (0x00 / 255, 0xB2 / 255, 0xC7 / 255, 1.0)),
    ice_white=("#EBF9FB", (0xEB / 255, 0xF9 / 255, 0xFB / 255, 1.0)),
    violet=("#7458BE", (0x74 / 255, 0x58 / 255, 0xBE / 255, 1.0)),
    lavender=("#DED3FA", (0xDE / 255, 0xD3 / 255, 0xFA / 255, 1.0)),
    emerald=("#2F9F7D", (0x2F / 255, 0x9F / 255, 0x7D / 255, 1.0)),
    wisdom_gold=("#FFD968", (0xFF / 255, 0xD9 / 255, 0x68 / 255, 1.0)),
    silver_blue=("#B8D9DF", (0xB8 / 255, 0xD9 / 255, 0xDF / 255, 1.0)),
)

GROUP_COUNTS = OrderedDict(
    deck_tiles=4096,
    rim_armor_blocks=1280,
    underside_plates=1536,
    radial_rib_blocks=768,
    levitation_crystal_cells=512,
    structural_fasteners=1536,
    circuit_inlay_cells=512,
)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_material(name, palette_key, metallic, roughness, emission_strength=0.0):
    _, color = PALETTE[palette_key]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = color
    mat["palette_key"] = palette_key
    mat["palette_hex"] = PALETTE[palette_key][0]
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission_strength:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def make_custom_material(name, color, metallic, roughness, emission_strength=0.0):
    """Create a blueprint-derived neutral used by the screenshot's soft grey shell."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color, 1.0)
    mat["palette_key"] = "blueprint_derived_neutral"
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission_strength:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def create_materials():
    return {
        "midnight": make_material("MSK_MidnightStructure", "midnight_blue", 0.62, 0.34),
        "charcoal": make_custom_material("MSK_CharcoalFoundation", (0.055, 0.075, 0.12), 0.54, 0.46),
        "deck": make_custom_material("MSK_SoftGreyDeck", (0.32, 0.37, 0.47), 0.42, 0.48),
        "deck_light": make_custom_material("MSK_SoftGreyDeckHighlight", (0.49, 0.55, 0.66), 0.38, 0.42),
        "cyan": make_material("MSK_CyanCircuit", "cyan", 0.28, 0.22, 1.75),
        "ice": make_material("MSK_IceClarity", "ice_white", 0.22, 0.26, 0.22),
        "violet": make_material("MSK_VioletThought", "violet", 0.20, 0.16, 1.8),
        "lavender": make_material("MSK_LavenderCrystal", "lavender", 0.12, 0.12, 1.25),
        "emerald": make_material("MSK_EmeraldLife", "emerald", 0.24, 0.32, 0.35),
        "gold": make_material("MSK_WisdomGold", "wisdom_gold", 0.78, 0.20, 0.55),
        "silver": make_material("MSK_SilverBlueArchitecture", "silver_blue", 0.68, 0.27),
    }


class IslandMeshBuilder:
    """Accumulates primitives with no shared vertices between pieces."""

    def __init__(self, name):
        self.name = name
        self.vertices = []
        self.faces = []
        self.face_piece_ids = []
        self.face_material_ids = []
        self.piece_count = 0

    def _piece(self, vertices, faces, material_index):
        offset = len(self.vertices)
        piece_id = self.piece_count
        self.vertices.extend(vertices)
        for face in faces:
            self.faces.append(tuple(offset + index for index in face))
            self.face_piece_ids.append(piece_id)
            self.face_material_ids.append(material_index)
        self.piece_count += 1

    def box(self, center, size, angle=0.0, material_index=0):
        cx, cy, cz = center
        sx, sy, sz = (v * 0.5 for v in size)
        ca, sa = math.cos(angle), math.sin(angle)
        verts = []
        for x, y, z in (
            (-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
            (-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz),
        ):
            verts.append((cx + x * ca - y * sa, cy + x * sa + y * ca, cz + z))
        self._piece(
            verts,
            ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)),
            material_index,
        )

    def wedge(self, r0, r1, a0, a1, z0, z1, material_index=0, center=(0.0, 0.0)):
        cx, cy = center
        verts = [
            (cx + r0 * math.cos(a0), cy + r0 * math.sin(a0), z0),
            (cx + r1 * math.cos(a0), cy + r1 * math.sin(a0), z0),
            (cx + r1 * math.cos(a1), cy + r1 * math.sin(a1), z0),
            (cx + r0 * math.cos(a1), cy + r0 * math.sin(a1), z0),
            (cx + r0 * math.cos(a0), cy + r0 * math.sin(a0), z1),
            (cx + r1 * math.cos(a0), cy + r1 * math.sin(a0), z1),
            (cx + r1 * math.cos(a1), cy + r1 * math.sin(a1), z1),
            (cx + r0 * math.cos(a1), cy + r0 * math.sin(a1), z1),
        ]
        self._piece(
            verts,
            ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)),
            material_index,
        )

    def frustum(self, center, radius0, radius1, z0, z1, sides=4, angle=0.0, material_index=0):
        cx, cy = center
        verts = []
        for z, radius in ((z0, radius0), (z1, radius1)):
            for side in range(sides):
                a = angle + math.tau * side / sides
                verts.append((cx + radius * math.cos(a), cy + radius * math.sin(a), z))
        faces = [tuple(reversed(range(sides))), tuple(range(sides, sides * 2))]
        for side in range(sides):
            nxt = (side + 1) % sides
            faces.append((side, nxt, sides + nxt, sides + side))
        self._piece(verts, faces, material_index)

    def finish(self, collection, root, materials, material_keys):
        mesh = bpy.data.meshes.new(f"{self.name}_Mesh")
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.materials.clear()
        for key in material_keys:
            mesh.materials.append(materials[key])
        for polygon, material_index in zip(mesh.polygons, self.face_material_ids):
            polygon.material_index = material_index
            polygon.use_smooth = False
        attr = mesh.attributes.new("piece_id", type="INT", domain="FACE")
        for value, piece_id in zip(attr.data, self.face_piece_ids):
            value.value = piece_id
        mesh.update()
        obj = bpy.data.objects.new(self.name, mesh)
        collection.objects.link(obj)
        obj.parent = root
        obj["component_id"] = COMPONENT_ID
        obj["semantic_group"] = self.name
        obj["editable"] = True
        obj["edit_mode_selection"] = "Select Linked (L) selects one disconnected micro-piece"
        obj["editable_island_count"] = self.piece_count
        return obj


def angle_cell(index, count, inset=0.08):
    step = math.tau / count
    return index * step + step * inset, (index + 1) * step - step * inset


def build_component(materials, collection, root):
    built = OrderedDict()

    # 64 radial rings x 64 sectors. The gaps are almost closed so the assembled
    # component reads as the screenshot's broad calm floor rather than a dense
    # circuit board. The pieces remain disconnected and individually editable.
    b = IslandMeshBuilder("01A_DeckTiles")
    radial_count = angular_count = 64
    inner, outer = 0.05, 4.64
    radial_step = (outer - inner) / radial_count
    for radial in range(radial_count):
        r0 = inner + radial * radial_step + 0.0005
        r1 = inner + (radial + 1) * radial_step - 0.0005
        for angular in range(angular_count):
            a0, a1 = angle_cell(angular, angular_count, 0.001)
            material_index = 1 if radial in (62, 63) else 0
            b.wedge(r0, r1, a0, a1, 0.82, 1.18, material_index)
    built["deck_tiles"] = b.finish(collection, root, materials, ("deck", "deck_light", "ice"))

    # Ten stacked armor courses around the outside circumference.
    b = IslandMeshBuilder("01B_RimArmorBlocks")
    for layer in range(10):
        for angular in range(128):
            a0, a1 = angle_cell(angular, 128, 0.002)
            mat = 1 if layer in (2, 7) else 0
            z0 = 0.06 + layer * 0.074
            b.wedge(4.67, 5.0, a0, a1, z0, z0 + 0.064, mat)
    built["rim_armor_blocks"] = b.finish(collection, root, materials, ("charcoal", "deck", "cyan"))

    # Sixteen radial courses under the deck, ninety-six cells per course.
    b = IslandMeshBuilder("01C_UndersidePlates")
    for radial in range(16):
        r0 = 0.92 + radial * (3.68 / 16) + 0.012
        r1 = 0.92 + (radial + 1) * (3.68 / 16) - 0.012
        for angular in range(96):
            a0, a1 = angle_cell(angular, 96, 0.002)
            b.wedge(r0, r1, a0, a1, 0.12, 0.25, 0)
    built["underside_plates"] = b.finish(collection, root, materials, ("charcoal", "deck"))

    # Ninety-six radial ribs, each split into eight replaceable blocks.
    b = IslandMeshBuilder("01D_RadialRibBlocks")
    for ray in range(96):
        angle = math.tau * ray / 96
        for segment in range(8):
            radius = 1.0 + segment * 0.46 + 0.21
            b.box(
                (radius * math.cos(angle), radius * math.sin(angle), 0.34),
                (0.40, 0.065, 0.22), angle, 1 if segment in (0, 7) else 0,
            )
    built["radial_rib_blocks"] = b.finish(collection, root, materials, ("silver", "gold"))

    # Eight downward crystal anchors, each made from sixty-four isolated cells.
    b = IslandMeshBuilder("01E_LevitationCrystalCells")
    for crystal in range(8):
        angle = math.tau * crystal / 8 + math.pi / 8
        center = (3.62 * math.cos(angle), 3.62 * math.sin(angle))
        for cell in range(64):
            t0, t1 = cell / 64, (cell + 0.86) / 64
            z0, z1 = 0.03 - 2.25 * t0, 0.03 - 2.25 * t1
            # Broad at the shoulder and tapering to a sharp crystalline tip.
            r0 = 0.24 * (1.0 - t0) + 0.014
            r1 = 0.24 * (1.0 - t1) + 0.014
            b.frustum(center, r0, r1, z1, z0, 4, angle + math.pi / 4, crystal % 3)
    built["levitation_crystal_cells"] = b.finish(
        collection, root, materials, ("cyan", "violet", "lavender")
    )

    # Three concentric fastening runs; each stud is four disconnected collars.
    b = IslandMeshBuilder("01F_StructuralFasteners")
    for ring_index, radius in enumerate((1.10, 2.85, 4.48)):
        for angular in range(128):
            angle = math.tau * angular / 128
            center = (radius * math.cos(angle), radius * math.sin(angle))
            for layer in range(4):
                z0 = 1.185 + layer * 0.018
                b.frustum(center, 0.036, 0.036, z0, z0 + 0.012, 6, angle, (ring_index + layer) % 2)
    built["structural_fasteners"] = b.finish(collection, root, materials, ("gold", "silver"))

    # Four luminous circuit rings split into 128 individually editable cells.
    b = IslandMeshBuilder("01G_CircuitInlayCells")
    for ring_index, radius in enumerate((0.91, 2.18, 3.48, 4.22)):
        for angular in range(128):
            a0, a1 = angle_cell(angular, 128, 0.16)
            b.wedge(radius - 0.026, radius + 0.026, a0, a1, 1.187, 1.213,
                    1 if ring_index == 3 and angular % 8 == 0 else 0)
    built["circuit_inlay_cells"] = b.finish(collection, root, materials, ("cyan", "gold"))

    return built


def add_game_surface(materials, collection, root):
    """Add the low-poly game-facing shell seen in the supplied screenshot.

    The 10,240 micro-parts remain the construction source. This shell gives the
    assembled view the simple, readable in-game silhouette; it is hidden for
    the exploded construction render.
    """
    created = []

    def cylinder(name, radius, depth, z, material, vertices=32):
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=(0, 0, z))
        obj = bpy.context.object
        obj.name = name
        for old in list(obj.users_collection):
            old.objects.unlink(obj)
        collection.objects.link(obj)
        obj.parent = root
        obj.data.materials.append(materials[material])
        bevel = obj.modifiers.new("Soft game bevel", "BEVEL")
        bevel.width = 0.045
        bevel.segments = 2
        created.append(obj)
        return obj

    def torus(name, radius, tube, z, material, major_segments=64):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=radius, minor_radius=tube, major_segments=major_segments,
            minor_segments=8, location=(0, 0, z)
        )
        obj = bpy.context.object
        obj.name = name
        for old in list(obj.users_collection):
            old.objects.unlink(obj)
        collection.objects.link(obj)
        obj.parent = root
        obj.data.materials.append(materials[material])
        created.append(obj)
        return obj

    # Broad readable layers: faceted charcoal underside, soft grey rim and a
    # closed calm deck. These proportions deliberately match the screenshot.
    cylinder("01H_Game_Underside", 4.80, 0.72, 0.48, "charcoal", 32)
    cylinder("01H_Game_OuterRim", 5.00, 0.50, 0.83, "deck", 32)
    cylinder("01H_Game_Deck", 4.72, 0.20, 1.13, "deck_light", 48)
    cylinder("01H_Game_CentreSocket", 0.90, 0.045, 1.255, "deck", 32)

    # One gold wayfinding ring and one cyan centre socket: restrained accents,
    # not a stack of bright concentric circuitry.
    torus("01H_Game_GoldGuidanceRing", 4.18, 0.035, 1.255, "gold")
    torus("01H_Game_CyanCentreRing", 1.08, 0.045, 1.258, "cyan")
    torus("01H_Game_CyanRimLight", 4.88, 0.025, 0.70, "cyan")

    # Eight large low-poly levitation crystals, matching the reference rather
    # than showing hundreds of luminous crystal cells in the hero view.
    for index in range(8):
        angle = math.tau * index / 8 + math.pi / 8
        x, y = 3.62 * math.cos(angle), 3.62 * math.sin(angle)
        bpy.ops.mesh.primitive_cone_add(
            vertices=4, radius1=0.30, radius2=0.10, depth=1.25,
            location=(x, y, -0.34), rotation=(0, 0, angle + math.pi / 4)
        )
        crystal = bpy.context.object
        crystal.name = f"01H_Game_HangingCrystal_{index + 1:02d}"
        for old in list(crystal.users_collection):
            old.objects.unlink(crystal)
        collection.objects.link(crystal)
        crystal.parent = root
        crystal.data.materials.append(materials["cyan"] if index % 2 == 0 else materials["lavender"])
        created.append(crystal)

    return created


def add_render_rig(materials):
    world = bpy.data.worlds.new("MindSparkBlueprintWorld")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.002, 0.008, 0.020, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.16
    bpy.context.scene.world = world

    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, -2.28))
    floor = bpy.context.object
    floor.name = "RENDER_ONLY_ShadowPlane"
    floor.data.materials.append(materials["midnight"])
    floor["render_only"] = True

    def area(name, location, energy, size, color):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.shape = "DISK"
        data.size = size
        data.color = color
        obj = bpy.data.objects.new(name, data)
        bpy.context.scene.collection.objects.link(obj)
        obj.location = location
        obj.rotation_euler = ((Vector((0, 0, 0.25)) - obj.location).to_track_quat("-Z", "Y").to_euler())
        obj["render_only"] = True
        return obj

    area("RENDER_ONLY_Key", (6.5, -7.5, 9.0), 720, 6.5, (0.84, 0.92, 1.0))
    area("RENDER_ONLY_Fill", (-6.0, -2.0, 5.0), 260, 5.0, (0.24, 0.63, 0.82))
    area("RENDER_ONLY_Rim", (1.5, 6.5, 4.8), 380, 4.5, (0.28, 0.72, 0.92))
    area("RENDER_ONLY_GoldBounce", (-2.0, 1.5, 0.8), 105, 3.0, (1.0, 0.62, 0.18))

    camera_data = bpy.data.cameras.new("Component01Camera")
    camera = bpy.data.objects.new("Component01Camera", camera_data)
    bpy.context.scene.collection.objects.link(camera)
    camera.location = (8.6, -10.8, 7.2)
    camera.rotation_euler = ((Vector((0, 0, 0.15)) - camera.location).to_track_quat("-Z", "Y").to_euler())
    camera_data.lens = 54
    camera["render_only"] = True
    bpy.context.scene.camera = camera
    return camera, floor


def configure_render():
    scene = bpy.context.scene
    # Blender 5.2 exposes Eevee under the stable BLENDER_EEVEE identifier.
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1200
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = False
    scene.render.image_settings.color_depth = "8"
    scene.render.resolution_percentage = 100
    scene.render.use_file_extension = True
    scene.view_settings.look = "AgX - Medium High Contrast"


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def set_exploded(objects, exploded):
    offsets = {
        "deck_tiles": (0.0, 0.0, 1.8),
        "rim_armor_blocks": (0.0, 0.0, 0.72),
        "underside_plates": (0.0, 0.0, -0.48),
        "radial_rib_blocks": (0.0, 0.0, -1.18),
        "levitation_crystal_cells": (0.0, 0.0, -2.05),
        "structural_fasteners": (0.0, 0.0, 2.65),
        "circuit_inlay_cells": (0.0, 0.0, 3.35),
    }
    for group, obj in objects.items():
        obj.location = offsets[group] if exploded else (0.0, 0.0, 0.0)


def validate(objects):
    errors = []
    total = 0
    details = OrderedDict()
    for group, expected in GROUP_COUNTS.items():
        obj = objects[group]
        mesh = obj.data
        attr = mesh.attributes.get("piece_id")
        actual_ids = {entry.value for entry in attr.data} if attr else set()
        actual = len(actual_ids)
        total += actual
        if actual != expected:
            errors.append(f"{group}: expected {expected} islands, found {actual}")
        if len(mesh.vertices) != len(set(range(len(mesh.vertices)))):
            errors.append(f"{group}: invalid vertex indexing")
        details[group] = {
            "object": obj.name,
            "editable_disconnected_islands": actual,
            "vertices": len(mesh.vertices),
            "edges": len(mesh.edges),
            "faces": len(mesh.polygons),
            "materials": [mat.name for mat in mesh.materials],
        }
    if total < MIN_EDITABLE_ISLANDS:
        errors.append(f"total editable islands {total} below minimum {MIN_EDITABLE_ISLANDS}")
    if errors:
        raise RuntimeError("; ".join(errors))
    return total, details


def main():
    os.makedirs(os.path.dirname(BLEND_PATH), exist_ok=True)
    os.makedirs(ARTIFACT_DIR, exist_ok=True)
    reset_scene()
    materials = create_materials()

    collection = bpy.data.collections.new("01_FLOATING_PLATFORM_FOUNDATION")
    bpy.context.scene.collection.children.link(collection)
    micro_collection = bpy.data.collections.new("01A_10K_EDITABLE_MICRO_COMPONENTS")
    hero_collection = bpy.data.collections.new("01B_GAME_SURFACE_ASSEMBLED")
    collection.children.link(micro_collection)
    collection.children.link(hero_collection)
    root = bpy.data.objects.new("MSK_01_FloatingPlatformFoundation_ROOT", None)
    collection.objects.link(root)
    root.empty_display_type = "CIRCLE"
    root.empty_display_size = 5.0
    root["component_id"] = COMPONENT_ID
    root["blueprint_panel"] = "01"
    root["design_diameter_m"] = DESIGN_DIAMETER_M
    root["design_platform_height_m"] = DESIGN_PLATFORM_HEIGHT_M
    root["minimum_editable_islands"] = MIN_EDITABLE_ISLANDS
    root["requirement_definition"] = "disconnected mesh islands selectable with Select Linked in Edit Mode"

    objects = build_component(materials, micro_collection, root)
    hero_objects = add_game_surface(materials, hero_collection, root)
    total, details = validate(objects)
    root["editable_disconnected_island_count"] = total

    camera, _floor = add_render_rig(materials)
    configure_render()

    # Hero render: show the simple game shell and keep the 10k construction
    # islands available but out of the final silhouette.
    micro_collection.hide_render = True
    hero_collection.hide_render = False
    set_exploded(objects, False)
    camera.location = (8.6, -10.8, 7.2)
    camera.rotation_euler = ((Vector((0, 0, 0.15)) - camera.location).to_track_quat("-Z", "Y").to_euler())
    render(ASSEMBLED_PATH)

    # Construction render: reveal the selectable Lego-like source islands.
    micro_collection.hide_render = False
    hero_collection.hide_render = True
    set_exploded(objects, True)
    camera.location = (12.8, -16.0, 11.6)
    camera.rotation_euler = ((Vector((0, 0, 0.45)) - camera.location).to_track_quat("-Z", "Y").to_euler())
    render(EXPLODED_PATH)

    # The editable source opens in its useful assembled state.
    set_exploded(objects, False)
    micro_collection.hide_render = True
    micro_collection.hide_viewport = True
    hero_collection.hide_render = False
    hero_collection.hide_viewport = False
    camera.location = (8.6, -10.8, 7.2)
    camera.rotation_euler = ((Vector((0, 0, 0.15)) - camera.location).to_track_quat("-Z", "Y").to_euler())
    bpy.context.scene["component_id"] = COMPONENT_ID
    bpy.context.scene["editable_disconnected_island_count"] = total
    bpy.context.scene["editing_help"] = (
        "Unhide 01A_10K_EDITABLE_MICRO_COMPONENTS, enter Edit Mode, hover a piece and press L. "
        "01B_GAME_SURFACE_ASSEMBLED is the screenshot-matched game shell."
    )
    readme = bpy.data.texts.new("README_COMPONENT_01")
    readme.write(
        "MIND SPARK COMPONENT 01\n\n"
        "The file opens with the screenshot-matched low-poly game shell visible.\n"
        "To edit the 10,240 Lego-like source pieces:\n"
        "1. Unhide collection 01A_10K_EDITABLE_MICRO_COMPONENTS.\n"
        "2. Select one of its seven semantic mesh objects and enter Edit Mode.\n"
        "3. Hover a piece and press L (Select Linked) to select that piece.\n"
        "4. Hide 01B_GAME_SURFACE_ASSEMBLED when inspecting or exploding the source.\n"
    )
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH, compress=True)

    manifest = {
        "component_id": COMPONENT_ID,
        "blueprint_panel": 1,
        "blender_version": bpy.app.version_string,
        "deterministic_seed": RNG_SEED,
        "dimensions_m": {"diameter": DESIGN_DIAMETER_M, "platform_height": DESIGN_PLATFORM_HEIGHT_M},
        "editability": {
            "definition": "disconnected mesh islands; hover and press L in Edit Mode to select one piece",
            "minimum_requested": MIN_EDITABLE_ISLANDS,
            "actual": total,
            "requirement_met": total >= MIN_EDITABLE_ISLANDS,
            "semantic_mesh_objects": len(objects),
        },
        "semantic_groups": details,
        "palette": {key: value[0] for key, value in PALETTE.items()},
        "outputs": {
            "blend": os.path.relpath(BLEND_PATH, PROJECT_ROOT),
            "assembled_render": os.path.relpath(ASSEMBLED_PATH, PROJECT_ROOT),
            "exploded_render": os.path.relpath(EXPLODED_PATH, PROJECT_ROOT),
            "manifest": os.path.relpath(MANIFEST_PATH, PROJECT_ROOT),
        },
        "render": {
            "engine": bpy.context.scene.render.engine,
            "resolution": [bpy.context.scene.render.resolution_x, bpy.context.scene.render.resolution_y],
            "look": bpy.context.scene.view_settings.look,
            "shadow_lights": ["RENDER_ONLY_Key", "RENDER_ONLY_Fill", "RENDER_ONLY_Rim", "RENDER_ONLY_GoldBounce"],
        },
        "game_surface": {
            "collection": hero_collection.name,
            "objects": [obj.name for obj in hero_objects],
            "visual_target": "supplied Mind Spark station screenshot",
            "style": "broad soft-grey plates, restrained cyan light, one gold guidance ring, faceted underside crystals",
        },
    }
    with open(MANIFEST_PATH, "w", encoding="utf-8") as file:
        json.dump(manifest, file, indent=2)

    print(f"MSK_COMPONENT_01_BUILD: editable_islands={total}")
    print(f"MSK_COMPONENT_01_BUILD: blend={BLEND_PATH}")
    print(f"MSK_COMPONENT_01_BUILD: assembled={ASSEMBLED_PATH}")
    print(f"MSK_COMPONENT_01_BUILD: exploded={EXPLODED_PATH}")
    print(f"MSK_COMPONENT_01_BUILD: manifest={MANIFEST_PATH}")


if __name__ == "__main__":
    main()
