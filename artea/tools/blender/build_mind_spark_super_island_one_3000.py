"""Build the fused Sun Gate + Verdant Engine Garden as 3,000 editable parts.

The .blend keeps every named component independently editable. The game GLB
joins those parts into role batches, preserving the exact visible geometry at a
browser-safe draw-call count. Coordinates are authored around the fused-pair
centre; Godot places the module at the World One pair midpoint.
"""
import csv
import json
import math
from collections import Counter
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets3D/mind_spark/super_island_one_3000"
SOURCE = OUT / "source/super_island_one_3000.blend"
GLB = OUT / "super_island_one.glb"
BOM = OUT / "bom/super_island_one_parts.csv"

TARGETS = {
    "01_Deck_Paving": 600,
    "02_Rim_Retaining": 240,
    "03_Faceted_Keel": 500,
    "04_Lift_Machinery": 480,
    "05_Aether_Conservatory": 380,
    "06_Verdant_Crown_Garden": 420,
    "07_Rails_Lanterns": 280,
    "08_Gameplay_Fittings": 100,
}

PARTS = []
MATERIALS = {}


def material(name, color, metallic=0.0, roughness=0.55, emission=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.metallic = metallic
    mat.roughness = roughness
    # Use explicit Principled nodes for deterministic glTF colour/metal export.
    # Blender viewport diffuse colours alone can import as near-white in Godot.
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    if emission:
        shader.inputs["Emission Color"].default_value = (*emission, 1.0)
        shader.inputs["Emission Strength"].default_value = 1.8
    return mat


def setup_materials():
    MATERIALS.update({
        "ivory": material("MSI1 Warm Ivory Ceramic", (0.86, 0.80, 0.68), 0.08, 0.62),
        "ivory_light": material("MSI1 Heavenly Ivory", (0.98, 0.93, 0.82), 0.04, 0.48),
        "brass": material("MSI1 Champagne Brass", (0.55, 0.34, 0.12), 0.78, 0.28),
        "copper": material("MSI1 Warm Copper", (0.47, 0.20, 0.10), 0.72, 0.34),
        "teal": material("MSI1 Teal Enamel", (0.03, 0.27, 0.30), 0.48, 0.25),
        "glass": material("MSI1 Aether Glass", (0.18, 0.62, 0.65), 0.18, 0.16, (0.22, 0.75, 0.78)),
        "rock": material("MSI1 Ivory Keel Stone", (0.38, 0.37, 0.33), 0.02, 0.92),
        "rock_dark": material("MSI1 Keel Shadow", (0.16, 0.18, 0.17), 0.10, 0.86),
        "soil": material("MSI1 Garden Soil", (0.10, 0.075, 0.045), 0.0, 0.96),
        "bark": material("MSI1 Crown Root Bark", (0.23, 0.11, 0.055), 0.05, 0.88),
        "leaf": material("MSI1 Pale Gold Leaf", (0.72, 0.62, 0.32), 0.12, 0.62, (0.36, 0.25, 0.08)),
        "energy": material("MSI1 Rootflow Energy", (0.04, 0.55, 0.50), 0.22, 0.20, (0.04, 0.82, 0.72)),
    })


def register(obj, category, role, assembly, material_key):
    if len(PARTS) >= 3000:
        raise RuntimeError("part budget exceeded")
    index = len(PARTS) + 1
    part_id = f"MSI1-P{index:04d}"
    obj.name = f"{part_id}_{obj.name[:42]}"
    obj["part_id"] = part_id
    obj["category"] = category
    obj["role"] = role
    obj["assembly"] = assembly
    obj["editable_component"] = True
    obj.data.materials.append(MATERIALS[material_key])
    PARTS.append(obj)
    return obj


def box(name, location, size, category, role, assembly, mat="ivory", rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (size[0] * 0.5, size[1] * 0.5, size[2] * 0.5)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new("Small architectural edge", "BEVEL")
    bevel.width = min(size) * 0.08
    bevel.segments = 1
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return register(obj, category, role, assembly, mat)


def cylinder(name, location, radius, depth, vertices, category, role, assembly, mat="brass", rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                       location=location, rotation=rotation)
    return register(bpy.context.object, category, role, assembly, mat)


def torus(name, location, major, minor, category, role, assembly, mat="brass", rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                    major_segments=24, minor_segments=6,
                                    location=location, rotation=rotation)
    return register(bpy.context.object, category, role, assembly, mat)


def beam(name, start, finish, radius, category, role, assembly, mat="brass", vertices=8):
    a, b = Vector(start), Vector(finish)
    direction = b - a
    obj = cylinder(name, (a + b) * 0.5, radius, direction.length, vertices,
                   category, role, assembly, mat)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(direction.normalized())
    return obj


def wedge(name, center, inner, outer, a0, a1, height, category, assembly, mat="ivory"):
    z0, z1 = -height, 0.0
    verts = [
        (center[0] + math.cos(a0) * inner, center[1] + math.sin(a0) * inner, z0),
        (center[0] + math.cos(a1) * inner, center[1] + math.sin(a1) * inner, z0),
        (center[0] + math.cos(a1) * outer, center[1] + math.sin(a1) * outer, z0),
        (center[0] + math.cos(a0) * outer, center[1] + math.sin(a0) * outer, z0),
        (center[0] + math.cos(a0) * inner, center[1] + math.sin(a0) * inner, z1),
        (center[0] + math.cos(a1) * inner, center[1] + math.sin(a1) * inner, z1),
        (center[0] + math.cos(a1) * outer, center[1] + math.sin(a1) * outer, z1),
        (center[0] + math.cos(a0) * outer, center[1] + math.sin(a0) * outer, z1),
    ]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return register(obj, category, "Deck", assembly, mat)


def triangle(name, a, b, c, category, role, assembly, mat="glass"):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata([a, b, c], [], [(0, 1, 2)])
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return register(obj, category, role, assembly, mat)


def build_decks():
    category = "01_Deck_Paving"
    lobes = [((-95.0, -42.5), 123.0), ((95.0, 42.5), 150.0)]
    for lobe_index, (center, radius) in enumerate(lobes):
        for ring_index in range(12):
            inner = radius * ring_index / 12.0
            outer = radius * (ring_index + 1) / 12.0
            for sector in range(24):
                a0 = math.tau * sector / 24.0
                a1 = math.tau * (sector + 1) / 24.0
                wedge(f"Lobe{lobe_index+1}_Paving_{ring_index:02d}_{sector:02d}", center,
                      inner, outer, a0, a1, 1.2, category,
                      f"Legacy district {lobe_index+1} radial paving",
                      "ivory_light" if (ring_index + sector) % 4 else "ivory")
    # Twenty-four transverse saddle courses complete the exact 600-piece deck.
    angle = math.atan2(85.0, 190.0)
    for index in range(24):
        along = -76.0 + index * (152.0 / 23.0)
        x = along * math.cos(angle)
        y = along * math.sin(angle)
        box(f"RootflowPromenadeCourse_{index+1:02d}", (x, y, -0.58),
            (7.2, 78.0, 1.16), category, "Deck", "Fused Rootflow Promenade",
            "ivory_light" if index % 2 else "ivory", rotation=(0, 0, angle))


def build_rim():
    category = "02_Rim_Retaining"
    for lobe_index, (center, radius) in enumerate([((-95.0, -42.5), 125.0), ((95.0, 42.5), 152.0)]):
        for index in range(96):
            angle = math.tau * index / 96.0
            at = (center[0] + math.cos(angle) * radius,
                  center[1] + math.sin(angle) * radius, -3.0)
            box(f"Lobe{lobe_index+1}_RetainingBlock_{index+1:03d}", at,
                (9.0, 4.2, 6.0), category, "Architecture",
                f"Lobe {lobe_index+1} curved retaining band", "ivory",
                rotation=(0, 0, angle))
    for side in (-1, 1):
        for index in range(24):
            y = -70.0 + index * 6.0
            box(f"PromenadeRetaining_{'L' if side < 0 else 'R'}_{index+1:02d}",
                (side * 41.0, y * 0.45, -4.2), (5.5, 7.0, 8.4), category,
                "Architecture", "Shared saddle retaining wall", "ivory")


def build_keel():
    category = "03_Faceted_Keel"
    centers = [(-95.0, -42.5), (95.0, 42.5)]
    for lobe_index, center in enumerate(centers):
        for index in range(220):
            angle = math.tau * index / 55.0 + (index // 55) * 0.09
            band = index // 55
            radius = (112.0 if lobe_index == 0 else 138.0) * (1.0 - band * 0.16)
            depth = 12.0 + band * 16.0 + (index % 5) * 2.0
            at = (center[0] + math.cos(angle) * radius * (0.76 - band * 0.08),
                  center[1] + math.sin(angle) * radius * (0.76 - band * 0.08), -depth)
            cylinder(f"Lobe{lobe_index+1}_KeelFacet_{index+1:03d}", at,
                     3.0 + (index % 4) * 0.7, 14.0 + band * 7.0, 5,
                     category, "Rock", f"Lobe {lobe_index+1} faceted load keel",
                     "rock" if index % 3 else "rock_dark",
                     rotation=(0.18 * math.sin(angle), 0.18 * math.cos(angle), angle))
    for index in range(60):
        phase = index / 59.0
        x = -72.0 + phase * 144.0
        y = math.sin(phase * math.pi) * 9.0
        z = -26.0 - math.sin(phase * math.pi) * 52.0
        cylinder(f"SharedKeelSpineFacet_{index+1:02d}", (x, y, z),
                 4.2 + (index % 3), 18.0, 6, category, "Rock",
                 "Triangulated shared keel spine", "rock" if index % 2 else "rock_dark",
                 rotation=(0.25, phase * 0.8, 0.0))


def build_machinery():
    category = "04_Lift_Machinery"
    for assembly_index in range(40):
        lobe_index = 0 if assembly_index < 20 else 1
        lobe_center = Vector((-95.0, -42.5)) if lobe_index == 0 else Vector((95.0, 42.5))
        local_index = assembly_index % 20
        angle = math.tau * local_index / 20.0 + lobe_index * 0.08
        radius = 116.0 if lobe_index == 0 else 142.0
        outward = Vector((math.cos(angle), math.sin(angle)))
        tangent = Vector((-math.sin(angle), math.cos(angle)))
        engine_center = lobe_center + outward * radius
        center_x, center_y = engine_center.x, engine_center.y
        z = -16.0 - (local_index % 3) * 4.0
        assembly = f"Foundation lift engine {assembly_index+1:02d}"
        cylinder(f"PressureVessel_{assembly_index+1:02d}", (center_x, center_y, z),
                 6.8, 24.0, 16, category, "Machinery", assembly,
                 "teal" if assembly_index % 2 else "copper")
        for collar in range(3):
            torus(f"VesselCollar_{assembly_index+1:02d}_{collar+1}",
                  (center_x, center_y, z - 8.0 + collar * 8.0), 6.8, 0.78,
                  category, "Machinery", assembly, "brass")
        flywheel = engine_center + outward * 8.5
        torus(f"Flywheel_{assembly_index+1:02d}", (flywheel.x, flywheel.y, z),
              9.0, 1.05, category, "Machinery", assembly, "brass",
              rotation=(math.pi * 0.5, 0, angle))
        cylinder(f"FlywheelHub_{assembly_index+1:02d}", (flywheel.x, flywheel.y, z),
                 2.4, 3.4, 12, category, "Machinery", assembly, "teal",
                 rotation=(math.pi * 0.5, 0, angle))
        for pipe_index in range(3):
            pipe_base = engine_center + tangent * ((pipe_index - 1) * 2.8)
            beam(f"LiftPipe_{assembly_index+1:02d}_{pipe_index+1}",
                 (pipe_base.x, pipe_base.y, z + 7),
                 (pipe_base.x - outward.x * 4.0, pipe_base.y - outward.y * 4.0, -5), 0.72,
                 category, "Machinery", assembly,
                 "copper" if pipe_index != 1 else "energy", 8)
        for foot in (-1, 1):
            foot_at = engine_center + tangent * foot * 4.0
            box(f"EngineFoot_{assembly_index+1:02d}_{foot:+d}",
                (foot_at.x, foot_at.y, z - 13.0), (4.0, 4.8, 3.4),
                category, "Machinery", assembly, "ivory")
        plaque_at = engine_center + outward * 7.2
        box(f"ServicePlaque_{assembly_index+1:02d}",
            (plaque_at.x, plaque_at.y, z), (7.2, 0.8, 10.0), category,
            "Machinery", assembly, "brass", rotation=(0, 0, angle))


def build_conservatory():
    category = "05_Aether_Conservatory"
    origin = (-95.0, -42.5, 0.0)
    # 144 independent triangular roof panes.
    for bay in range(6):
        y0 = origin[1] - 43.0 + bay * (86.0 / 6.0)
        y1 = origin[1] - 43.0 + (bay + 1) * (86.0 / 6.0)
        for arc in range(12):
            a0 = math.pi - math.pi * arc / 12.0
            a1 = math.pi - math.pi * (arc + 1) / 12.0
            p00 = (origin[0] + math.cos(a0) * 31.0, y0, 17.0 + math.sin(a0) * 19.0)
            p01 = (origin[0] + math.cos(a1) * 31.0, y0, 17.0 + math.sin(a1) * 19.0)
            p10 = (origin[0] + math.cos(a0) * 31.0, y1, 17.0 + math.sin(a0) * 19.0)
            p11 = (origin[0] + math.cos(a1) * 31.0, y1, 17.0 + math.sin(a1) * 19.0)
            triangle(f"CanopyPane_{bay:02d}_{arc:02d}_A", p00, p10, p11,
                     category, "Glass", "Triangulated aether canopy", "glass")
            triangle(f"CanopyPane_{bay:02d}_{arc:02d}_B", p00, p11, p01,
                     category, "Glass", "Triangulated aether canopy", "glass")
    # Fill the remaining 236 structural parts with ribs, columns and compass fittings.
    while sum(1 for p in PARTS if p["category"] == category) < TARGETS[category]:
        local_index = sum(1 for p in PARTS if p["category"] == category)
        mode = local_index % 4
        angle = math.tau * local_index / 236.0
        if mode == 0:
            beam(f"CanopyRib_{local_index:03d}",
                 (origin[0] + math.cos(angle) * 34, origin[1] - 44, 2),
                 (origin[0] + math.cos(angle) * 34, origin[1] + 44, 20 + abs(math.sin(angle)) * 16),
                 0.42, category, "Architecture", "Conservatory ribs", "brass")
        elif mode == 1:
            cylinder(f"ConservatoryColumn_{local_index:03d}",
                     (origin[0] + math.cos(angle) * 38, origin[1] + math.sin(angle) * 38, 8),
                     0.9, 16.0, 12, category, "Architecture", "Open civic colonnade", "ivory_light")
        elif mode == 2:
            torus(f"CompassBearing_{local_index:03d}",
                  (origin[0], origin[1], 1.2 + (local_index % 5) * 0.12),
                  12.0 + (local_index % 6) * 2.0, 0.22, category,
                  "GameplayArchitecture", "Aether Compass floor mechanism", "brass")
        else:
            box(f"CompassRunePlaque_{local_index:03d}",
                (origin[0] + math.cos(angle) * 24, origin[1] + math.sin(angle) * 24, 1.5),
                (2.2, 1.2, 0.35), category, "GameplayArchitecture",
                "Aether Compass bearing runes", "teal", rotation=(0, 0, angle))


def build_garden():
    category = "06_Verdant_Crown_Garden"
    origin = Vector((95.0, 42.5, 0.0))
    # Twelve root paths, ten editable segments each.
    for root_index in range(12):
        angle = math.tau * root_index / 12.0
        previous = origin + Vector((math.cos(angle) * 6, math.sin(angle) * 6, 1.0))
        for segment in range(10):
            progress = (segment + 1) / 10.0
            bend = angle + math.sin(segment * 0.9 + root_index) * 0.13
            finish = origin + Vector((math.cos(bend) * 58 * progress,
                                      math.sin(bend) * 58 * progress,
                                      1.0 + math.sin(progress * math.pi) * 3.5))
            beam(f"CrownRoot_{root_index+1:02d}_{segment+1:02d}", previous, finish,
                 2.4 * (1.0 - progress * 0.68), category, "Nature",
                 f"Living root path {root_index+1:02d}", "bark", 8)
            previous = finish
    # Eighty trunk/branch segments.
    for index in range(80):
        branch = index % 10
        tier = index // 10
        angle = math.tau * branch / 10.0 + tier * 0.08
        start = origin + Vector((math.cos(angle) * tier * 1.6,
                                 math.sin(angle) * tier * 1.6, 3.0 + tier * 6.0))
        finish = start + Vector((math.cos(angle) * (5.0 + tier),
                                 math.sin(angle) * (5.0 + tier), 6.0))
        beam(f"CrownBranch_{index+1:03d}", start, finish, 1.7 - tier * 0.12,
             category, "Nature", "Crownroot living tree", "bark", 8)
    # One hundred and sixty pale-gold leaf facets.
    for index in range(160):
        angle = math.tau * index / 40.0
        tier = index // 40
        radius = 18.0 + tier * 8.0
        at = origin + Vector((math.cos(angle) * radius, math.sin(angle) * radius,
                              42.0 + tier * 6.0 + math.sin(index * 1.7) * 3.0))
        cylinder(f"CrownLeafFacet_{index+1:03d}", at, 1.8 + index % 3 * 0.4,
                 5.0, 5, category, "Nature", "Luminous crown canopy", "leaf",
                 rotation=(0.6, angle, 0.2))
    # Sixty planter/soil pieces complete the garden count.
    for index in range(60):
        angle = math.tau * index / 60.0
        radius = 70.0 + (index % 3) * 6.0
        mat = "soil" if index % 2 else "ivory"
        box(f"GardenPlanterModule_{index+1:02d}",
            (origin.x + math.cos(angle) * radius,
             origin.y + math.sin(angle) * radius, 1.5),
            (8.5, 6.0, 3.0), category, "Nature",
            "Circular contemplative garden", mat, rotation=(0, 0, angle))


def build_rails():
    category = "07_Rails_Lanterns"
    for index in range(140):
        angle = math.tau * index / 140.0
        radius = 150.0 if index % 2 else 126.0
        center = Vector((95.0, 42.5, 0.0)) if index % 2 else Vector((-95.0, -42.5, 0.0))
        at = center + Vector((math.cos(angle) * radius, math.sin(angle) * radius, 5.0))
        cylinder(f"BalustradePost_{index+1:03d}", at, 0.65, 9.0, 10,
                 category, "Railing", "Perimeter safety balustrade", "ivory_light")
    for index in range(100):
        angle = math.tau * index / 100.0
        radius = 148.0 if index % 2 else 124.0
        center = Vector((95.0, 42.5, 0.0)) if index % 2 else Vector((-95.0, -42.5, 0.0))
        start = center + Vector((math.cos(angle) * radius, math.sin(angle) * radius, 8.0))
        next_angle = angle + math.tau / 100.0
        finish = center + Vector((math.cos(next_angle) * radius, math.sin(next_angle) * radius, 8.0))
        beam(f"BalustradeTopRail_{index+1:03d}", start, finish, 0.55,
             category, "Railing", "Curved brass safety rail", "brass", 8)
    for index in range(40):
        angle = math.tau * index / 40.0
        center = Vector((-95.0, -42.5, 0.0)) if index < 20 else Vector((95.0, 42.5, 0.0))
        radius = 116.0 if index < 20 else 139.0
        at = center + Vector((math.cos(angle) * radius, math.sin(angle) * radius, 12.0))
        cylinder(f"AetherLantern_{index+1:02d}", at, 1.2, 5.0, 10,
                 category, "Railing", "Warm route lanterns", "glass")


def build_gameplay_fittings():
    category = "08_Gameplay_Fittings"
    for index in range(100):
        angle = math.tau * index / 100.0
        if index < 36:
            center, radius, mat, assembly = Vector((-95.0, -42.5, 0.0)), 38.0, "teal", "Compass interaction clearance"
        elif index < 68:
            center, radius, mat, assembly = Vector((95.0, 42.5, 0.0)), 62.0, "energy", "Thought Spark rootflow route"
        else:
            center, radius, mat, assembly = Vector((0.0, 0.0, 0.0)), 34.0, "brass", "Internal promenade wayfinding"
        at = center + Vector((math.cos(angle) * radius, math.sin(angle) * radius, 1.8))
        box(f"GameplayWayfindingInlay_{index+1:03d}", at, (3.2, 1.2, 0.34),
            category, "Gameplay", assembly, mat, rotation=(0, 0, angle))


def export_runtime():
    export_collection = bpy.data.collections.new("MSI1_Runtime_Batches")
    bpy.context.scene.collection.children.link(export_collection)
    runtime = []
    for role in sorted(set(str(obj["role"]) for obj in PARTS)):
        members = [obj for obj in PARTS if obj["role"] == role]
        copies = []
        for obj in members:
            copy = obj.copy()
            copy.data = obj.data.copy()
            export_collection.objects.link(copy)
            copies.append(copy)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in copies:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = copies[0]
        bpy.ops.object.join()
        merged = bpy.context.object
        merged.name = "MSI1_Runtime_" + role.replace(" ", "_")
        merged["runtime_role"] = role
        merged["source_part_count"] = len(members)
        runtime.append(merged)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in runtime:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(GLB), export_format="GLB", use_selection=True,
                              export_extras=True, export_cameras=False, export_lights=False)
    return runtime


def write_bom():
    rows = []
    for obj in PARTS:
        rows.append({
            "part_id": obj["part_id"], "name": obj.name,
            "category": obj["category"], "role": obj["role"],
            "assembly": obj["assembly"], "triangles": len(obj.data.polygons),
        })
    with BOM.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for folder in [OUT, OUT / "source", OUT / "bom"]:
        folder.mkdir(parents=True, exist_ok=True)
    setup_materials()
    build_decks()
    build_rim()
    build_keel()
    build_machinery()
    build_conservatory()
    build_garden()
    build_rails()
    build_gameplay_fittings()
    counts = Counter(str(obj["category"]) for obj in PARTS)
    assert len(PARTS) == 3000, len(PARTS)
    assert dict(counts) == TARGETS, (counts, TARGETS)
    write_bom()
    bpy.context.scene["asset_id"] = "mind_spark_super_island_one"
    bpy.context.scene["editable_part_count"] = 3000
    bpy.context.scene["legacy_district_pair"] = "01_world_gate_landing+02_living_network_forest"
    bpy.context.scene["gameplay_preserved"] = True
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE), compress=True)
    runtime = export_runtime()
    manifest = {
        "asset_id": "mind_spark_super_island_one",
        "revision": "v21_fused_3000",
        "editable_parts": len(PARTS),
        "runtime_batches": len(runtime),
        "category_counts": dict(counts),
        "legacy_districts": ["01_world_gate_landing", "02_living_network_forest"],
        "mini_game_support": ["aether_compass", "checkpoint_roots", "thought_sparks", "spark_socket"],
        "source": str(SOURCE.relative_to(ROOT)),
        "runtime_glb": str(GLB.relative_to(ROOT)),
        "bom": str(BOM.relative_to(ROOT)),
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("MSI1_BUILD_PASS", json.dumps(manifest), flush=True)


if __name__ == "__main__":
    main()
