"""Build Artéa's editable low-poly harbour, sailing boat, and sea-life set."""

from pathlib import Path
import math

import bpy
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parents[2]
ASSET_DIR = ROOT / "assets3D" / "coastal_harbour"
SOURCE_DIR = ASSET_DIR / "source"
ARTIFACT_DIR = ROOT / "artifacts" / "coastal_harbour_blender"


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        if collection.name != "Collection":
            bpy.data.collections.remove(collection)


def collection(name):
    result = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(result)
    return result


def material(name, color, metallic=0.0, roughness=0.72, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def move_to_collection(obj, target):
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    target.objects.link(obj)
    return obj


def cube(name, location, dimensions, mat, target, bevel=0.08):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Soft_Edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    obj.data.materials.append(mat)
    return move_to_collection(obj, target)


def cylinder(name, location, radius, depth, mat, target, vertices=10):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                        location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return move_to_collection(obj, target)


def ico(name, location, scale, mat, target, subdivisions=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1.0,
                                         location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    return move_to_collection(obj, target)


def cone(name, location, radius1, radius2, depth, mat, target, vertices=8):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2,
                                   depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return move_to_collection(obj, target)


def beam(name, start, end, radius, mat, target, vertices=8):
    start, end = Vector(start), Vector(end)
    delta = end - start
    obj = cylinder(name, (start + end) * 0.5, radius, delta.length, mat, target, vertices)
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return obj


def parent_root(name, location, target):
    root = bpy.data.objects.new(name, None)
    root.location = location
    target.objects.link(root)
    return root


def reparent(objects, root):
    bpy.context.view_layer.update()
    for obj in objects:
        obj.parent = root
        obj.matrix_parent_inverse = root.matrix_world.inverted()


def creature_eyes(name, location, scale, target, x=0.70, spread=0.39, height=0.20):
    parts = []
    for side in (-1, 1):
        pos = Vector(location) + Vector((x, side * spread, height)) * scale
        parts.append(ico(f"{name}_EyeWhite_{side}", pos,
                         (0.19 * scale, 0.10 * scale, 0.21 * scale),
                         bpy.data.materials["PearlSail"], target, 2))
        parts.append(ico(f"{name}_Pupil_{side}", pos + Vector((0.04, side * 0.075, 0)) * scale,
                         (0.105 * scale, 0.06 * scale, 0.13 * scale),
                         bpy.data.materials["CreatureInk"], target, 2))
    return parts


def village_building(target, root, filename, name, center, width, depth=None, front=None, solid=False, yaw=0):
    """Reuse village geometry and its atlas, preserving the original proportions."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets3D/houses/red" / filename))
    imported = list(set(bpy.data.objects) - before)
    bpy.context.view_layer.update()
    meshes = [o for o in imported if o.type == "MESH"]
    matrices = {o: Matrix.Rotation(yaw, 4, "Z") @ o.matrix_world for o in meshes}
    points = [matrices[o] @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    factor = width / max(hi.x - lo.x, hi.y - lo.y) if depth is None else min(width / (hi.x - lo.x), depth / (hi.y - lo.y))
    offset = Vector(center) - Vector(((hi.x + lo.x) / 2, (hi.y + lo.y) / 2, lo.z)) * factor
    if front is not None:
        offset.y = front - hi.y * factor
    # Bake import transforms into meshes, so there is one predictable game root.
    for obj in meshes:
        matrix = matrices[obj]
        obj.parent = None
        obj.matrix_world.identity()
        for vertex in obj.data.vertices:
            vertex.co = matrix @ vertex.co * factor + offset
        obj.name = name if len(meshes) == 1 else name + "_" + obj.name
        obj["village_source"] = filename
        if solid:
            obj["harbour_collision"] = True
        move_to_collection(obj, target)
        obj.parent = root
    for obj in imported:
        if obj.type != "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)
    return meshes


def village_house(target, root):
    # Home A's doorway already points inland (-Y); keep that frontage.
    meshes = village_building(target, root, "building_home_A_red.gltf", "VillageHarbourOffice_building_home_A_red",
                              (-3.6, -5.0, .61), 2.9)
    for mesh in meshes:
        mesh["front_direction"] = "village"
    root["style_reference"] = "Original New_Hub_World village kit and hexagons_castle atlas"


# Original broad-nib small-cap strokes; no system-font or runtime-font dependency.
# Rounded uncial bowls and modest flourishes keep the little labels readable.
PAINTED_GLYPHS = {
    "S": [[(.72,.85),(.55,.98),(.22,.91),(.12,.69),(.35,.53),(.63,.42),(.7,.2),(.48,.04),(.17,.11),(.08,.23)]],
    "E": [[(.68,.91),(.31,.98),(.15,.79),(.12,.3),(.22,.07),(.66,.1)],[(.13,.53),(.51,.55),(.62,.6)]],
    "A": [[(.04,.02),(.2,.48),(.43,.94),(.51,.99),(.63,.51),(.78,.04)],[(.18,.4),(.63,.43)],[(0,.04),(.19,.05)],[(.62,.04),(.84,.02)]],
    "F": [[(.17,.02),(.18,.93),(.46,.98),(.75,.88)],[(.17,.53),(.53,.55),(.63,.65)],[(.07,.04),(.32,.03)]],
    "O": [[(.4,.98),(.16,.85),(.07,.47),(.16,.13),(.42,.04),(.7,.24),(.75,.62),(.62,.91),(.4,.98)]],
    "D": [[(.18,.06),(.18,.93)],[(.1,.93),(.45,.95),(.72,.73),(.76,.39),(.56,.12),(.14,.06)]],
    "I": [[(.2,.95),(.22,.06)],[(.05,.96),(.4,.95)],[(.05,.05),(.42,.05)]],
    "H": [[(.13,.94),(.12,.06)],[(.69,.95),(.67,.07)],[(.13,.49),(.4,.56),(.68,.51)],[(.03,.94),(.23,.96)],[(.57,.06),(.79,.05)]],
    "C": [[(.72,.83),(.55,.98),(.21,.88),(.07,.53),(.16,.18),(.43,.04),(.69,.18)]],
    "R": [[(.15,.04),(.16,.94)],[(.13,.93),(.53,.96),(.72,.78),(.63,.57),(.18,.5)],[(.36,.51),(.57,.22),(.77,.05),(.84,.1)]],
    "B": [[(.15,.04),(.16,.95)],[(.14,.94),(.51,.94),(.67,.76),(.55,.56),(.17,.52)],[(.3,.52),(.63,.5),(.73,.26),(.55,.08),(.14,.06)]],
    "Y": [[(.07,.95),(.2,.7),(.4,.5),(.62,.77),(.73,.98)],[(.4,.51),(.38,.09),(.24,.02)]],
    "T": [[(.04,.86),(.11,.96),(.68,.95),(.77,.86)],[(.41,.95),(.39,.06),(.54,.03)]],
    "U": [[(.13,.95),(.13,.28),(.25,.07),(.51,.06),(.68,.28),(.69,.95)],[(.03,.95),(.24,.95)],[(.59,.95),(.80,.95)]],
}


def painted_lettering(name, text, pos, size, target, paint, faded):
    verts, faces, materials = [], [], []
    advances = [.53 if c.upper() == "I" else .87 for c in text]
    total = sum(advances)
    cursor = -total / 2
    for index, character in enumerate(text):
        height = 1.10 if index == 0 else .88 + .025 * math.sin(index * 2.7)
        tilt = .035 * math.sin(index * 1.8)
        baseline = -.46 + .025 * math.sin(index * 2.4)
        for stroke_index, path in enumerate(PAINTED_GLYPHS[character.upper()]):
            # Catmull-Rom centreline, then a variable-width nib, all flat paint.
            points = [Vector(p) for p in path]
            samples = []
            for j in range(len(points) - 1):
                a, b = points[max(0,j-1)], points[j]
                c, d = points[j+1], points[min(len(points)-1,j+2)]
                for k in range(5):
                    t = k / 5
                    samples.append(.5 * ((2*b) + (-a+c)*t + (2*a-5*b+4*c-d)*t*t + (-a+3*b-3*c+d)*t*t*t))
            samples.append(points[-1])
            start = len(verts)
            for j, point in enumerate(samples):
                tangent = samples[min(j+1,len(samples)-1)] - samples[max(0,j-1)]
                tangent.normalize()
                normal = Vector((-tangent.y, tangent.x))
                width = (.036 + .027 * abs(tangent.y)) * (1 + .07 * math.sin(j * 2.1 + index))
                for side in (-1, 1):
                    p = point + normal * width * side
                    verts.append(((cursor + p.x + tilt * p.y) * size,
                                  (baseline + p.y * height) * size, .001))
            for j in range(len(samples) - 1):
                faces.append((start+2*j, start+2*j+1, start+2*j+3, start+2*j+2))
                materials.append(1 if (index * 3 + stroke_index) % 9 == 6 else 0)
        cursor += advances[index]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(paint)
    mesh.materials.append(faded)
    for polygon, material_index in zip(mesh.polygons, materials):
        polygon.material_index = material_index
    obj = bpy.data.objects.new(name, mesh)
    target.objects.link(obj)
    obj.location = pos
    obj.rotation_euler = (math.pi / 2, 0, math.pi)
    obj["lettering_style"] = "original hand-painted broad-nib uncial strokes"
    obj["sign_text"] = text
    return obj


def build_seafood_shop(mats, target, root):
    """A stocked fishmonger beside the landing, entirely outside bridge traffic."""
    parts = []

    def box(name, pos, size, mat="wood", solid=False):
        obj = cube(name, pos, size, mats[mat], target, .035)
        if solid:
            obj["harbour_collision"] = True
        parts.append(obj)
        return obj

    paint = material("WarmOchreSignPaint", (.95, .79, .46), roughness=1.0)
    faded = material("WornOchreSignPaint", (.72, .55, .30), roughness=1.0)

    def sign(name, text, pos, size):
        parts.append(painted_lettering(name, text, pos, size, target, paint, faded))

    box("SeafoodShopPlatform", (8.5, -4.5, .38), (5.0, 5.4, .44), "dark_wood", True)
    box("ShopApproachFloor", (3.8875, -2.25, .38), (4.225, .9, .44), "dark_wood", True)
    for i in range(2):
        box(f"ShopApproachBoard_{i}", (3.8875, -2.475 + i * .45, .56),
            (4.225, .424, .08), "wood")
    for i in range(9):
        box(f"ShopDeckBoard_{i}", (8.5, -6.9 + i * .6, .56), (5.0, .57, .08),
            "wood_light" if i % 4 == 0 else "wood")
    for x in (6.0, 10.8):
        for y in (-6.95, -1.95):
            parts.append(cylinder(f"ShopFoundationPile_{x}_{y}", (x, y, -.4), .22, 1.9,
                                  mats["dark_wood"], target, 10))
    frontage_before = set(target.objects)
    # Original dormer, arched openings, timber framing and stone foundation.
    village_building(target, root, "building_home_B_red.gltf", "SeafoodShopBuilding",
                     (8.15, -5.25, .60), 4.1, depth=3.3, front=-3.6, solid=True, yaw=math.pi)
    box("ShopCounter", (8.65, -3.3, 1.26), (2.9, .85, .42), "wood_light", True)
    for x in (7.25, 10.05):
        box(f"CounterSupport_{x}", (x, -3.3, .93), (.18, .6, .66), "dark_wood", True)
    box("SeafoodShopSignboard", (8.65, -3.17, 2.32), (2.85, .16, .56), "dark_wood")
    for x in (7.3, 10.0):
        box(f"SignIronEndStrap_{x}", (x, -3.074, 2.32), (.07, .035, .49), "iron")
        for z in (2.15, 2.49):
            parts.append(ico(f"SignHandForgedRivet_{x}_{z}", (x, -3.045, z), (.035,.018,.035), mats["iron"], target, 1))
    # A fine ochre rule and painted end flourishes frame the freehand lettering.
    for z in (2.10, 2.54):
        mesh = bpy.data.meshes.new(f"PaintedSignBorder_{z}")
        mesh.from_pydata([(7.44,-3.088,z-.009), (9.86,-3.088,z-.009),
                          (9.86,-3.088,z+.009), (7.44,-3.088,z+.009)], [], [(0,1,2,3)])
        mesh.materials.append(paint)
        border = bpy.data.objects.new(f"PaintedSignBorder_{z}", mesh)
        target.objects.link(border)
        parts.append(border)
    for x in (7.42, 9.88):
        parts.append(beam(f"ShopSignBracket_{x}", (x, -3.8, 2.57), (x, -3.17, 2.57),
                          .055, mats["iron"], target))
        parts.append(beam(f"ShopSignHanger_{x}", (x, -3.17, 2.57), (x, -3.17, 2.32),
                          .025, mats["iron"], target))
    sign("SeafoodShopLettering", "Seafood", (8.65, -3.089, 2.30), .35)
    # Three labelled catch trays, with recognisable fish, crab and oysters.
    for i, label in enumerate(("FISH", "CRAB", "OYSTERS")):
        x = 7.72 + i * .92
        box(f"CatchTray_{label}", (x, -3.23, 1.51), (.82, .64, .12), "dark_wood")
        box(f"CatchTrayLiner_{label}", (x, -3.23, 1.58), (.73, .54, .035), "sail")
        box(f"CatchLabelBoard_{label}", (x, -2.865, 1.33), (.78, .045, .20), "dark_wood")
        sign(f"CatchLabel_{label}", label.title(), (x, -2.842, 1.33), min(.13, .66 / (.87 * len(label))))
    for i in range(3):
        fish = add_fish(f"ShopFishDisplay_{i}", (7.7, -3.42 + i * .18, 1.69), .23,
                        mats["silver_fish"] if i % 2 else mats["teal"], mats["sail"], target)
        fish.parent = root
    crab = add_crab("ShopCrabDisplay", (8.64, -3.25, 1.66), .25, mats, target)
    crab.parent = root
    for i in range(3):
        oyster = add_oyster(f"ShopOysterDisplay_{i}", (9.35 + i * .19, -3.25, 1.66), .17, mats, target)
        oyster.parent = root
    for x in (7.12, 9.22):
        box(f"ShopLanternFrame_{x}", (x, -3.4, 2.62), (.25, .26, .4), "iron")
        box(f"ShopLanternGlass_{x}", (x, -3.24, 2.64), (.18, .12, .24), "lamp_glass")
    # Turn the whole frontage inland, not just the house mesh. Moving it 1.25m
    # seaward leaves the customer aisle on the existing supported deck.
    frontage = set(target.objects) - frontage_before
    turn = (Matrix.Translation((8.15, -4.0, 0)) @ Matrix.Rotation(math.pi, 4, "Z")
            @ Matrix.Translation((-8.15, 5.25, 0)))
    bpy.context.view_layer.update()
    for obj in frontage:
        if obj.parent not in frontage:
            obj.matrix_world = turn @ obj.matrix_world
            obj["front_direction"] = "village"
    # Side storage, basket tubs and drying rack stay behind the customer aisle.
    for i, (x, y, z) in enumerate([(10.6, -6.25, .95), (10.6, -5.35, .95), (10.6, -6.25, 1.58)]):
        box(f"ShopStorageCrate_{i}", (x, y, z), (.68, .74, .65), "wood_light", True)
        parts.append(beam(f"ShopCrateBrace_{i}", (x - .26, y + .39, z - .23),
                          (x + .26, y + .39, z + .23), .05, mats["dark_wood"], target))
    for i, y in enumerate((-4.35, -3.35)):
        basket = cylinder(f"ShopBasket_{i}", (10.6, y, .83), .32, .46, mats["rope"], target, 12)
        basket["harbour_collision"] = True
        parts.append(basket)
        for z in (.65, .85, 1.06):
            bpy.ops.mesh.primitive_torus_add(major_radius=.31, minor_radius=.03,
                                           major_segments=12, minor_segments=5, location=(10.6, y, z))
            hoop = bpy.context.object
            hoop.name = f"BasketWeave_{i}_{z}"
            hoop.data.materials.append(mats["dark_wood"])
            parts.append(move_to_collection(hoop, target))
        for j in range(3):
            fish = add_fish(f"BasketCatch_{i}_{j}", (10.6, y - .15 + j * .15, 1.10), .17,
                            mats["silver_fish"], mats["sail"], target)
            fish.parent = root
    reparent(parts, root)


def build_harbour(mats):
    target = collection("HARBOUR_GAME_EXPORT")
    root = parent_root("ArteaHarbour", (0, 0, 0), target)
    parts = []
    # Broad, beveled pieces match the village kit's readable silhouette.
    for row in range(5):
        for col in range(6):
            parts.append(cube(f"LandingPlank_{row}_{col}",
                              (-5.0 + col * 2, -6.75 + row * 0.9, 0.44),
                              (1.96, 0.86, 0.32),
                              mats["wood"] if (col + row) % 3 else mats["wood_light"], target, 0.055))
    # One flush T-shaped deck: thinner boards over a continuous dark substrate.
    parts.append(cube("JettySubdeck", (0, 2.25, .36), (3.55, 10.8, .28), mats["dark_wood"], target, .015))
    parts.append(cube("BerthSubdeck", (4.0125, 6, .36), (4.475, 3.3, .28), mats["dark_wood"], target, .015))
    for index in range(18):
        parts.append(cube(f"JettyPlank_{index:02}", (0, -2.85 + index * .6, .51),
                          (3.55, .574, .18), mats["wood_light"] if index % 5 == 0 else mats["wood"],
                          target, .022))
    for index in range(6):
        parts.append(cube(f"BerthPlank_{index}", (4.0125, 4.625 + index * .55, .51),
                          (4.475, .524, .18), mats["wood"], target, .022))
    for x in (-1.3, 1.3):
        parts.append(cube(f"JettyUnderbeam_{x}", (x, 2.1, .05),
                          (.32, 10.1, .36), mats["dark_wood"], target, .035))
    # Fascia wraps the exposed perimeter, hiding beam ends and mismatched edges.
    for name, location, size in [
        ("Sea", (2.2375, 7.65, .29), (8.025, .16, .34)),
        ("East", (-1.775, 2.25, .29), (.16, 10.8, .34)),
        ("West", (1.775, .6, .29), (.16, 7.5, .34)),
        ("BerthShore", (4.0125, 4.35, .29), (4.475, .16, .34)),
        ("TowerJoin", (6.25, 6, .29), (.16, 3.3, .34)),
    ]:
        parts.append(cube(f"BridgeFascia_{name}", location, size, mats["wood_light"], target, .025))
    for index, (x, y) in enumerate([(-5.7, -6.9), (11.0, -6.9), (-5.7, -2.9),
                                    (5.7, -2.9), (-1.7, -2.7), (1.7, -2.7),
                                    (-1.7, .9), (1.7, .9), (-1.7, 7.55), (6.15, 7.55),
                                    (-1.7, 4.2), (1.7, 4.2)]):
        parts.append(cylinder(f"MooringPile_{index}", (x, y, -0.15), 0.24, 2.6,
                              mats["dark_wood"], target, 10))
        parts.append(cylinder(f"PileIronBand_{index}", (x, y, 0.84), 0.265, 0.20,
                              mats["iron"], target, 10))
        parts.append(cone(f"PileCap_{index}", (x, y, 1.21), 0.32, 0.24, 0.19,
                          mats["wood_light"], target, 10))
    for side, end in [(-1, 7.55), (1, 4.2)]:
        start = -2.7 if side == -1 else -1.5  # Opening into the seafood forecourt.
        for height, radius, mat in [(.92, .065, "iron"), (1.27, .085, "wood_light")]:
            parts.append(beam(f"JettyHandrail_{side}_{height}", (side * 1.7, start, height),
                              (side * 1.7, end, height), radius, mats[mat], target))
    village_house(target, root)
    # Village market red/cream stripes, sturdy posts, scalloped valance.
    for x in (2.5, 5.1):
        for y in (-5.7, -3.9):
            parts.append(cube(f"MarketPost_{x}_{y}", (x, y, 1.65), (0.19, 0.19, 2.1),
                              mats["dark_wood"], target, 0.035))
    for i in range(6):
        x = 2.55 + i * 0.5
        mat = mats["roof_red"] if i % 2 == 0 else mats["sail"]
        panel = cube(f"AwningStripe_{i}", (x, -4.85, 2.83), (0.5, 2.45, 0.14),
                     mat, target, 0.025)
        panel.rotation_euler.x = -0.13
        parts.append(panel)
        parts.append(cube(f"AwningValance_{i}", (x, -3.62, 2.48), (0.49, 0.12, 0.43),
                          mat, target, 0.10))
    parts.append(cube("FishMarketCounter", (3.8, -4.0, 1.12), (2.95, 0.86, 1.04),
                      mats["dark_wood"], target))
    parts.append(cube("CounterTop", (3.8, -4.0, 1.69), (3.1, 1.0, 0.15),
                      mats["wood_light"], target))
    for i in range(7):
        parts.append(cube(f"CounterSlat_{i}", (2.52 + i * 0.42, -3.53, 1.14),
                          (0.34, 0.11, 0.86), mats["wood"], target, 0.025))
    # Chunky visible catch on the counter, as on the village's market props.
    for i in range(3):
        fish = add_fish(f"MarketCatch_{i}", (3.0 + i * 0.73, -3.98, 1.9), 0.24,
                        mats["teal"], mats["sail"], target)
        fish.parent = root
    for x in (-1.2, 1.2):
        parts.append(cube(f"WelcomePost_{x}", (x, -5.9, 2.15), (0.22, 0.22, 3.1),
                          mats["dark_wood"], target))
    # The original landmark mesh has malformed, fused letters. Keep its warm
    # wood/cream style, but build the board and correctly spelled title cleanly.
    sign_wood = material("HarbourSignTimber", (1, 1, 1), roughness=.88)
    wood_image = sign_wood.node_tree.nodes.new("ShaderNodeTexImage")
    wood_image.image = bpy.data.images.load(str(ROOT / "meshy ai/Artéa_Signpost_1027230400_texture_0.jpg"), check_existing=True)
    sign_wood.node_tree.links.new(wood_image.outputs["Color"],
                                 sign_wood.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    board = cube("HarbourSign", (0, -5.86, 3.35), (2.9, .38, 1.5), sign_wood, target, .095)
    # Map an unlettered wood-grain patch of the existing atlas, never the baked
    # lettering. UV mapping keeps the source image untouched.
    for loop in board.data.loops:
        point = board.data.vertices[loop.vertex_index].co
        board.data.uv_layers.active.data[loop.index].uv = (
            .3203125 + (point.x / 2.9 + .5) * .0625,
            .6171875 + (point.z / 1.5 + .5) * .03125)
    board["style_reference"] = "Milo landmark timber and raised cream serif lettering"
    board["front_direction"] = "village"
    parts.append(board)
    # Use Artéa's authored display face—the same project font used for the
    # Milo landmark presentation—rather than a generic modern system serif.
    # Convert it to geometry now so Web exports do not need the font installed.
    bpy.ops.object.text_add()
    title = bpy.context.object
    title.name = "HarbourTitle"
    # Nautilus Pompilius has the Artéa brush forms but no precomposed é.
    # Build the base e from the font and its acute as matching raised geometry;
    # feeding é directly to Blender produces a visible missing-glyph square.
    title.data.body = "Artea"
    title.data.font = bpy.data.fonts.load(str(ROOT / "assets/Fonts/NewFont-Artea.otf"))
    title.data.align_x = "CENTER"
    title.data.align_y = "CENTER"
    title.data.space_character = 1.1
    title.data.extrude = .023
    title.data.bevel_depth = .004
    title.data.bevel_resolution = 2
    title.data.resolution_u = 16
    title.data.materials.append(mats["sail"])
    bpy.ops.object.convert(target="MESH")
    lo = Vector(tuple(min(v.co[i] for v in title.data.vertices) for i in range(3)))
    hi = Vector(tuple(max(v.co[i] for v in title.data.vertices) for i in range(3)))
    factor = min(2.44 / (hi.x - lo.x), .92 / (hi.y - lo.y))
    center = Vector(((hi.x + lo.x) / 2, (hi.y + lo.y) / 2, lo.z))
    for vertex in title.data.vertices:
        vertex.co = (vertex.co - center) * factor
    title.location = (0, -6.06, 3.35)
    title.rotation_euler = (math.pi / 2, 0, 0)
    title["sign_text"] = "Artéa"
    title["lettering_revision"] = 3
    title["lettering_style"] = "Milo landmark hand-painted medieval Artéa lettering"
    title["lettering_source"] = "res://assets/Fonts/NewFont-Artea.otf"
    title["style_reference"] = "Artéa sign beside the Milo statue"
    title["front_direction"] = "village"
    parts.append(move_to_collection(title, target))
    # Milo's landmark uses a small cream diamond above the accented letter,
    # not a detached modern slash. Reuse that exact visual punctuation.
    accent = cube("HarbourTitleAccent", (.46, -6.082, 3.65), (.17, .055, .17),
                  mats["sail"], target, .018)
    accent.rotation_euler.y = math.pi / 4
    accent["lettering_component"] = "Milo landmark diamond accent for Artéa"
    accent["lettering_source"] = "Artéa sign beside the Milo statue"
    accent["front_direction"] = "village"
    parts.append(accent)
    parts.append(cube("HarbourSubtitleBoard", (0, -5.94, 2.37), (2.7, .17, .38),
                      mats["dark_wood"], target, .055))
    subtitle = painted_lettering("HarbourSubtitle", "Harbour", (.18, -6.032, 2.37), .265,
                                 target, mats["sail"], mats["sail"])
    subtitle.rotation_euler = (math.pi / 2, 0, 0)
    subtitle["front_direction"] = "village"
    parts.append(subtitle)
    # Small inland-facing fish emblem identifies the waterfront at a glance.
    parts.append(ico("SignFishBody", (-1.0, -6.07, 2.37), (.18, .035, .08),
                     mats["sail"], target, 2))
    fin = cone("SignFishTail", (-1.2, -6.07, 2.37), .095, 0, .13,
               mats["sail"], target, 3)
    fin.rotation_euler.y = math.pi / 2
    parts.append(fin)
    # Keep the village-facing customer lane free as well as the boat route.
    for i, (x, y) in enumerate([(-4.6, -2.95), (5.4, -4.8), (10.6, -2.35)]):
        parts.append(ico(f"BarrelStaves_{i}", (x, y, 1.13), (0.49, 0.49, 0.59),
                         mats["wood"], target, 2))
        for h in (0.83, 1.43):
            parts.append(cylinder(f"BarrelHoop_{i}_{h}", (x, y, h), 0.45, 0.13,
                                  mats["iron"], target, 10))
        parts.append(cylinder(f"BarrelLid_{i}", (x, y, 1.63), 0.32, 0.10,
                              mats["wood_light"], target, 10))
    for i, (x, y) in enumerate([(-3.6, -2.9), (3.15, -5.6), (4.25, -5.6)]):
        parts.append(cube(f"CargoCrate_{i}", (x, y, 1.04), (0.83, 0.83, 0.86),
                          mats["wood_light"], target))
        parts.append(beam(f"CrateCrossBrace_{i}", (x - 0.33, y + 0.45, 0.74),
                          (x + 0.33, y + 0.45, 1.36), 0.065, mats["dark_wood"], target))
    for x, y in [(-1.7, 7.55), (6.15, 7.55)]:
        parts.append(cube(f"LanternFrame_{x}", (x, y, 1.56), (0.42, 0.42, 0.54),
                          mats["iron"], target, 0.05))
        parts.append(cube(f"LanternGlass_{x}", (x, y, 1.59), (0.44, 0.44, 0.31),
                          mats["lamp_glass"], target, 0.04))
        parts.append(cone(f"LanternRoof_{x}", (x, y, 1.94), 0.38, 0.06, 0.28,
                          mats["roof_red"], target, 4))
    for x, y in [(3.3, -5.0), (-5.35, -5.4)]:
        bpy.ops.mesh.primitive_torus_add(major_radius=0.30, minor_radius=0.075,
                                       major_segments=12, minor_segments=6, location=(x, y, 0.70))
        coil = bpy.context.object
        coil.name = f"MooringRopeCoil_{x}"
        coil.data.materials.append(mats["rope"])
        parts.append(move_to_collection(coil, target))
    for x in (2.7, 3.4):
        parts.append(beam(f"LadderRail_{x}", (x, 7.72, 0.7), (x, 7.72, -0.8),
                          0.085, mats["dark_wood"], target))
    for i in range(4):
        parts.append(beam(f"LadderRung_{i}", (2.7, 7.72, 0.45 - i * 0.32),
                          (3.4, 7.72, 0.45 - i * 0.32), 0.07, mats["wood_light"], target))
    # One shallow, full-frontage ramp: its toe is buried in the measured beach,
    # and its head meets the 0.60m deck exactly. The former narrow tilted box
    # left a 47cm step beside the house. Collision uses this same closed mesh.
    ramp_x0, ramp_x1 = -6.0, 11.0
    ramp_y0, ramp_y1 = -9.3, -7.18
    ramp_low, ramp_high = .34, .60
    def ramp_height(y):
        return ramp_low + (ramp_high - ramp_low) * (y - ramp_y0) / (ramp_y1 - ramp_y0)
    mesh = bpy.data.meshes.new("ShoreApron")
    mesh.from_pydata([
        (ramp_x0, ramp_y0, .08), (ramp_x1, ramp_y0, .08),
        (ramp_x1, ramp_y1, .08), (ramp_x0, ramp_y1, .08),
        (ramp_x0, ramp_y0, ramp_low), (ramp_x1, ramp_y0, ramp_low),
        (ramp_x1, ramp_y1, ramp_high), (ramp_x0, ramp_y1, ramp_high),
    ], [], [(0,3,2,1), (4,5,6,7), (0,1,5,4), (1,2,6,5), (2,3,7,6), (3,0,4,7)])
    mesh.materials.append(mats["dark_wood"])
    apron = bpy.data.objects.new("ShoreApron", mesh)
    target.objects.link(apron)
    apron["harbour_collision"] = True
    apron["access_style"] = "continuous village-side timber slope"
    parts.append(apron)
    # Inlaid plank faces share the slope; no raised nosings or collision seams.
    for row in range(5):
        y0 = ramp_y0 + (ramp_y1 - ramp_y0) * row / 5 + .012
        y1 = ramp_y0 + (ramp_y1 - ramp_y0) * (row + 1) / 5 - .012
        for col in range(9):
            x0 = ramp_x0 + (ramp_x1 - ramp_x0) * col / 9 + .013
            x1 = ramp_x0 + (ramp_x1 - ramp_x0) * (col + 1) / 9 - .013
            board_mesh = bpy.data.meshes.new(f"ShoreRampBoard_{row}_{col}")
            board_mesh.from_pydata([(x0,y0,ramp_height(y0)+.003), (x1,y0,ramp_height(y0)+.003),
                                    (x1,y1,ramp_height(y1)+.003), (x0,y1,ramp_height(y1)+.003)],
                                   [], [(0,1,2,3)])
            board_mesh.materials.append(mats["wood_light"] if (row + col) % 4 == 0 else mats["wood"])
            board = bpy.data.objects.new(board_mesh.name, board_mesh)
            target.objects.link(board)
            parts.append(board)
    # Flush border boards lead from shore to the tower without creating steps.
    for side in (-1, 1):
        trim_length = 10.8 if side == -1 else 7.5
        trim_center = 2.25 if side == -1 else .6
        parts.append(cube(f"JettyEdgeTrim_{side}", (side * 1.68, trim_center, .595),
                          (.14, trim_length, .025), mats["dark_wood"], target, .006))
        for y in (-2.7, -.9, .9, 2.7, 4.5, 6.3):
            parts.append(cylinder(f"DeckPeg_{side}_{y}", (side * 1.48, y, .611),
                                  .055, .023, mats["iron"], target, 8))
        for y in (-2.7, .9):
            parts.append(beam(f"JettyDiagonalBrace_{side}_{y}", (side * 1.7, y, -.9),
                              (side * 1.7, y + 2.4, .1), .13, mats["dark_wood"], target))
    for name, center, length, y in [("Shore", 4.0125, 4.475, 4.4), ("Sea", 2.2375, 8.025, 7.6)]:
        parts.append(cube(f"BerthBorder_{name}", (center, y, .595), (length, .10, .025),
                          mats["dark_wood"], target, .006))
    for x in (2.4, 5.6):
        parts.append(cube(f"BerthSupportBeam_{x}", (x, 6, .02), (.24, 3.0, .35), mats["dark_wood"], target, .025))
    # Fishing gear hangs below the deck, outside the walking corridor.
    for i, y in enumerate((.3, 2.0)):
        for z in (-.75, -.25):
            parts.append(cube(f"HangingFishTrapRim_{i}_{z}", (-2.2, y, z),
                              (.75, 1.0, .08), mats["dark_wood"], target, .025))
        for x in (-2.52, -2.3, -2.08, -1.88):
            for yy in (y - .44, y + .44):
                parts.append(beam(f"FishTrapSlat_{i}_{x}_{yy}", (x, yy, -.75),
                                  (x, yy, -.25), .035, mats["wood_light"], target, 6))
        parts.append(beam(f"FishTrapSuspension_{i}", (-1.7, y, .38),
                          (-2.2, y, -.23), .04, mats["rope"], target, 6))
    for i in range(12):
        a, b = math.tau * i / 12, math.tau * (i + 1) / 12
        parts.append(beam(f"MarketLifeRing_{i}",
                          (5.05 + math.cos(a) * .38, -3.46, 1.23 + math.sin(a) * .38),
                          (5.05 + math.cos(b) * .38, -3.46, 1.23 + math.sin(b) * .38),
                          .095, mats["roof_red"] if i // 3 % 2 else mats["sail"], target))
    # Visible obstacles participate in clearance instead of being ghost props.
    for obj in parts:
        if obj.name.startswith(("BarrelStaves", "CargoCrate", "MooringPile",
                                "WelcomePost", "MarketPost", "JettyHandrail")):
            obj["harbour_collision"] = True
    reparent(parts, root)
    build_seafood_shop(mats, target, root)
    return root, target


def hull_mesh(target, mats):
    # Closed, thick sided hull with an open cockpit, tapered bow and broad stern.
    outline = [(-1.05, -2.8), (1.05, -2.8), (1.52, -1.8), (1.65, 0),
               (1.3, 1.7), (0.62, 2.7), (0, 3.25), (-0.62, 2.7),
               (-1.3, 1.7), (-1.65, 0), (-1.52, -1.8)]
    count = len(outline)
    verts = []
    for shrink, height in [(0.55, -0.50), (1.0, 0.45), (1.0, 0.96),
                            (0.87, 0.96), (0.75, 0.23)]:
        verts += [(x * shrink, y * (0.88 if shrink == 0.55 else 1.0), height)
                  for x, y in outline]
    faces, indices = [], []
    for ring in range(4):
        for i in range(count):
            j = (i + 1) % count
            faces.append((ring * count + i, ring * count + j,
                          (ring + 1) * count + j, (ring + 1) * count + i))
            indices.append([0, 1, 2, 0][ring])
    faces += [tuple(reversed(range(count))), tuple(range(4 * count, 5 * count))]
    indices += [0, 0]
    mesh = bpy.data.meshes.new("VillageBoatHullMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("SailingHull", mesh)
    target.objects.link(obj)
    for mat in [mats["wood"], mats["sail"], mats["roof_red"]]:
        mesh.materials.append(mat)
    for face, index in zip(mesh.polygons, indices):
        face.material_index = index
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    bevel = obj.modifiers.new("ChunkyHullEdges", "BEVEL")
    bevel.width = 0.075
    bevel.segments = 2
    return obj


def triangular_sail(name, x, y, z, width, height, mat, target):
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata([(x, y, z), (x + width, y, z), (x, y, z + height)], [], [(0, 1, 2)])
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    target.objects.link(obj)
    obj.data.materials.append(mat)
    solidify = obj.modifiers.new("SailCloth", "SOLIDIFY")
    solidify.thickness = 0.045
    return obj


def build_boat(mats):
    target = collection("BOAT_GAME_EXPORT")
    root = parent_root("ArteaSailingBoat", (0, 0, 0), target)
    root["style_reference"] = "New_Hub_World red roofs, white plaster, warm timber"
    parts = [hull_mesh(target, mats)]
    # Broad deck boards, two seats and an accessible rear helm.
    for i, y in enumerate([-2.2, -1.65, -1.1, -0.55, 0, 0.55, 1.1, 1.65, 2.2]):
        width = 2.3 if y < 1.1 else 2.1 - (y - 1.1) * 1.15
        parts.append(cube(f"DeckBoard_{i}", (0, y, 0.46), (width, 0.52, 0.20),
                          mats["wood_light"] if i % 3 == 0 else mats["wood"], target, 0.025))
    for i, y in enumerate([-1.5, 1.1]):
        parts.append(cube(f"Bench_{i}", (0, y, 0.91), (2.25, 0.52, 0.22),
                          mats["wood_light"], target, 0.07))
    parts.append(cube("HelmConsole", (0, -2.2, 1.08), (0.75, 0.5, 0.8),
                      mats["dark_wood"], target))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.31, minor_radius=0.065,
                                   major_segments=10, minor_segments=6,
                                   location=(0, -1.96, 1.55), rotation=(math.pi / 2, 0, 0))
    wheel = bpy.context.object
    wheel.name = "HelmWheel"
    wheel.data.materials.append(mats["wood_light"])
    parts.append(move_to_collection(wheel, target))
    for i in range(6):
        a = math.tau * i / 6
        parts.append(beam(f"WheelSpoke_{i}", (0, -1.96, 1.55),
                          (math.cos(a) * 0.42, -1.96, 1.55 + math.sin(a) * 0.42),
                          0.045, mats["wood_light"], target, 6))
    parts.append(cylinder("Mast", (0, 0.35, 2.82), 0.16, 5.1,
                          mats["dark_wood"], target, 10))
    parts.append(beam("SailBoom", (-1.47, 0.35, 1.75), (1.47, 0.35, 1.75),
                      0.10, mats["wood"], target))
    # A full billowing sail with broad red stripes, not hairline model rigging.
    verts = []
    for row in range(5):
        t = row / 4
        halfwidth = 1.48 - t * 0.37
        for col in range(5):
            u = col / 4
            verts.append(((u * 2 - 1) * halfwidth,
                          0.35 + math.sin(u * math.pi) * math.sin(t * math.pi) * 0.42,
                          1.82 + t * 2.9))
    faces = [(r * 5 + c, r * 5 + c + 1, (r + 1) * 5 + c + 1, (r + 1) * 5 + c)
             for r in range(4) for c in range(4)]
    mesh = bpy.data.meshes.new("VillageStripedSailMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mats["sail"])
    mesh.materials.append(mats["roof_red"])
    for face in mesh.polygons:
        face.material_index = 1 if face.index // 4 in (0, 3) else 0
    sail = bpy.data.objects.new("VillageStripedSail", mesh)
    target.objects.link(sail)
    thick = sail.modifiers.new("TwoSidedCloth", "SOLIDIFY")
    thick.thickness = 0.055
    parts.append(sail)
    parts.append(beam("TopYard", (-1.23, 0.35, 4.77), (1.23, 0.35, 4.77),
                      0.10, mats["dark_wood"], target))
    parts.append(triangular_sail("RedMastPennant", 0, 0.35, 5.17, 0.72, 0.38,
                                mats["roof_red"], target))
    for side in (-1, 1):
        parts.append(beam(f"Rigging_{side}", (0, 0.35, 4.9),
                          (side * 1.35, -0.65, 0.96), 0.055, mats["rope"], target))
        for y in (-1.6, 0.55):
            parts.append(ico(f"Fender_{side}_{y}", (side * 1.53, y, 0.72),
                             (0.21, 0.25, 0.43), mats["sail"], target, 2))
        parts.append(beam(f"OarShaft_{side}", (side * 1.32, -2.2, 1.0),
                          (side * 1.39, 0.9, 1.0), 0.06, mats["dark_wood"], target))
        parts.append(cube(f"OarBlade_{side}", (side * 1.39, 1.08, 1.0),
                          (0.32, 0.7, 0.11), mats["wood_light"], target, 0.10))
    parts.append(cube("Rudder", (0, -2.91, -0.01), (0.19, 0.62, 1.18),
                      mats["roof_red"], target, 0.07))
    parts.append(beam("AnchorShank", (-1.0, 2.0, 0.82), (-1.0, 2.0, -0.28),
                      0.09, mats["iron"], target))
    parts.append(beam("AnchorCrossbar", (-1.3, 2.0, 0.53), (-0.7, 2.0, 0.53),
                      0.08, mats["iron"], target))
    for side in (-1, 1):
        parts.append(beam(f"AnchorHook_{side}", (-1.0, 2.0, -0.28),
                          (-1.0 + side * 0.35, 2.0, -0.1), 0.09, mats["iron"], target))
    # Layered gunwales and lower strakes keep the original hull silhouette.
    outline = [(-1.05, -2.8), (1.05, -2.8), (1.52, -1.8), (1.65, 0),
               (1.3, 1.7), (.62, 2.7), (0, 3.25), (-.62, 2.7),
               (-1.3, 1.7), (-1.65, 0), (-1.52, -1.8)]
    for i, (x, y) in enumerate(outline):
        nx, ny = outline[(i + 1) % len(outline)]
        for z, shrink, mat in [(1.00, 1.0, "wood_light"), (.39, 1.005, "dark_wood")]:
            parts.append(beam(f"HullStrake_{i}_{z}", (x * shrink, y, z),
                              (nx * shrink, ny, z), .075, mats[mat], target))
    for i, y in enumerate((1.78, 2.08, 2.38, 2.68, 2.94)):
        width = max(.3, (3.25 - y) * 1.45)
        parts.append(cube(f"RaisedForedeck_{i}", (0, y, .91), (width, .27, .14),
                          mats["wood_light"] if i % 2 else mats["wood"], target, .025))
    parts.append(cube("ForedeckHatch", (0, 2.05, 1.01), (.72, .66, .08), mats["dark_wood"], target, .035))
    for x in (-.25, .25):
        parts.append(cube(f"HatchHinge_{x}", (x, 2.30, 1.06), (.12, .22, .04), mats["iron"], target, .01))
    parts.append(beam("HatchHandle", (-.16, 1.9, 1.12), (.16, 1.9, 1.12), .035, mats["iron"], target))
    for i in range(3):
        bpy.ops.mesh.primitive_torus_add(major_radius=.17 + i * .04, minor_radius=.025,
                                       major_segments=16, minor_segments=6, location=(.72, 1.7, 1.02))
        coil = bpy.context.object
        coil.name = f"BoatRopeCoil_{i}"
        coil.data.materials.append(mats["rope"])
        parts.append(move_to_collection(coil, target))
    for x in (-.8, .8):
        parts.append(cube(f"SternCleatBase_{x}", (x, -2.45, 1.02), (.25, .25, .12), mats["iron"], target))
        parts.append(beam(f"SternCleatHorn_{x}", (x - .22, -2.45, 1.13),
                          (x + .22, -2.45, 1.13), .055, mats["iron"], target))
    # Fish emblem on both cloth faces echoes the harbour's original sign.
    for side, y in [("Front", .86), ("Back", .23)]:
        parts.append(ico(f"SailFishEmblem_{side}", (.05, y, 3.26), (.53, .035, .23), mats["roof_red"], target, 2))
        parts.append(triangular_sail(f"SailFishTail_{side}", -.48, y, 3.03, -.42, .46, mats["roof_red"], target))
        parts.append(ico(f"SailFishEye_{side}", (.33, y + (.04 if side == "Front" else -.04), 3.3),
                         (.055, .018, .055), mats["sail"], target, 1))
    parts.append(beam("SternLampPost", (.92, -2.55, .95), (.92, -2.55, 1.98), .06, mats["dark_wood"], target))
    parts.append(cube("SternLampGlass", (.92, -2.55, 1.85), (.22, .22, .3), mats["lamp_glass"], target, .025))
    parts.append(cone("SternLampRoof", (.92, -2.55, 2.07), .24, .03, .18, mats["roof_red"], target, 4))
    reparent(parts, root)
    return root, target


def add_fish(name, location, scale, body_mat, fin_mat, target):
    root = parent_root(name, location, target)
    body = ico(f"{name}_Body", location, (1.0 * scale, 0.45 * scale, 0.5 * scale),
               body_mat, target, 2)
    tail = cone(f"{name}_Tail", (location[0] - 1.05 * scale, location[1], location[2]),
                0.6 * scale, 0.0, 0.7 * scale, fin_mat, target, 3)
    tail.rotation_euler.y = math.radians(90)
    dorsal = ico(f"{name}_Dorsal", Vector(location) + Vector((-0.12, 0, 0.47)) * scale,
                 (0.36 * scale, 0.10 * scale, 0.22 * scale), fin_mat, target, 1)
    reparent([body, tail, dorsal] + creature_eyes(name, location, scale, target), root)
    return root


def add_long_fish(name, location, scale, body_mat, fin_mat, mats, target):
    root = parent_root(name, location, target)
    body = ico(f"{name}_LongBody", location, (1.45 * scale, 0.34 * scale, 0.38 * scale),
               body_mat, target, 2)
    nose = cone(f"{name}_Nose", Vector(location) + Vector((1.35 * scale, 0, 0)),
                0.34 * scale, 0.05 * scale, 0.62 * scale, body_mat, target, 10)
    nose.rotation_euler.y = math.radians(90)
    tail = cone(f"{name}_ForkedTail", Vector(location) + Vector((-1.48 * scale, 0, 0)),
                0.72 * scale, 0.0, 0.88 * scale, fin_mat, target, 4)
    tail.rotation_euler.y = math.radians(90)
    dorsal = cone(f"{name}_DorsalFin", Vector(location) + Vector((0, 0, 0.42 * scale)),
                  0.42 * scale, 0.0, 0.62 * scale, fin_mat, target, 3)
    dorsal.rotation_euler.x = math.radians(90)
    stripe = cube(f"{name}_SideStripe", Vector(location) + Vector((0.1 * scale, -0.34 * scale, 0)),
                  (1.9 * scale, 0.035, 0.08 * scale), mats["sail"], target, 0.015)
    eye = ico(f"{name}_Eye", Vector(location) + Vector((1.02 * scale, -0.31 * scale, 0.12 * scale)),
              (0.075, 0.045, 0.075), mats["ink"], target, 1)
    bpy.data.objects.remove(eye, do_unlink=True)
    reparent([body, nose, tail, dorsal, stripe] +
             creature_eyes(name, location, scale, target, 1.02, 0.30, 0.13), root)
    return root


def add_puffer(name, location, scale, mats, target):
    root = parent_root(name, location, target)
    body = ico(f"{name}_RoundBody", location, (0.72 * scale, 0.64 * scale, 0.64 * scale),
               mats["puffer_yellow"], target, 2)
    parts = [body]
    for index in range(7):
        angle = math.tau * index / 7.0
        start = Vector(location) + Vector((math.cos(angle) * 0.48 * scale,
                                           math.sin(angle) * 0.38 * scale, 0.1 * scale))
        end = start + Vector((math.cos(angle) * 0.26 * scale,
                              math.sin(angle) * 0.22 * scale, 0.12 * scale))
        parts.append(beam(f"{name}_SoftSpine_{index}", start, end, 0.06 * scale,
                          mats["coral_dark"], target, 5))
    for side in (-1, 1):
        parts.append(ico(f"{name}_Eye_{side}",
                         Vector(location) + Vector((0.45 * scale, side * 0.47 * scale, 0.18 * scale)),
                         (0.08, 0.055, 0.08), mats["ink"], target, 1))
    tail = cone(f"{name}_Tail", Vector(location) + Vector((-0.78 * scale, 0, 0)),
                0.40 * scale, 0.0, 0.48 * scale, mats["coral"], target, 3)
    tail.rotation_euler.y = math.radians(90)
    parts.append(tail)
    reparent(parts, root)
    return root


def add_ray(name, location, scale, mats, target):
    root = parent_root(name, location, target)
    mesh = bpy.data.meshes.new(f"{name}WingMesh")
    x, y, z = location
    mesh.from_pydata([(x + 0.9 * scale, y, z), (x, y - 1.5 * scale, z),
                      (x - 1.0 * scale, y, z), (x, y + 1.5 * scale, z),
                      (x, y, z + 0.18 * scale)], [],
                     [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4),
                      (1, 0, 3), (2, 1, 3)])
    mesh.update()
    wings = bpy.data.objects.new(f"{name}_DiamondWings", mesh)
    target.objects.link(wings)
    wings.data.materials.append(mats["ray_blue"])
    tail = beam(f"{name}_WhipTail", (x - 0.75 * scale, y, z),
                (x - 2.35 * scale, y, z - 0.08), 0.035 * scale,
                mats["ray_blue"], target, 7)
    eyes = [ico(f"{name}_Eye_{side}", (x + 0.42 * scale, y + side * 0.28 * scale,
                                        z + 0.20 * scale), (0.055, 0.045, 0.055),
                mats["ink"], target, 1) for side in (-1, 1)]
    reparent([wings, tail] + eyes, root)
    return root


def add_seahorse(name, location, scale, mats, target):
    root = parent_root(name, location, target)
    parts = []
    points = [Vector(location) + Vector((0, 0, i * 0.20 * scale)) for i in range(5)]
    points += [points[-1] + Vector((-0.10 * scale, 0, 0.17 * scale)),
               points[-1] + Vector((-0.26 * scale, 0, 0.25 * scale))]
    for index, point in enumerate(points):
        parts.append(ico(f"{name}_BodySegment_{index}", point,
                         (0.16 * scale * (1.0 - index * 0.045), 0.11 * scale,
                          0.18 * scale), mats["seahorse"] if index % 2 == 0
                         else mats["seahorse_light"], target, 1))
    head = ico(f"{name}_Head", points[-1] + Vector((0.04 * scale, 0, 0.15 * scale)),
               (0.24 * scale, 0.18 * scale, 0.23 * scale), mats["seahorse"], target, 1)
    snout = beam(f"{name}_Snout", points[-1] + Vector((0.13 * scale, 0, 0.16 * scale)),
                 points[-1] + Vector((0.48 * scale, 0, 0.16 * scale)), 0.055 * scale,
                 mats["seahorse_light"], target, 7)
    parts.extend([head, snout])
    reparent(parts, root)
    return root


def add_jellyfish(name, location, scale, mats, target):
    root = parent_root(name, location, target)
    bell = ico(f"{name}_Bell", location, (0.55 * scale, 0.55 * scale, 0.35 * scale),
               mats["jelly"], target, 2)
    parts = [bell]
    for index, offset in enumerate((-0.32, -0.1, 0.1, 0.32)):
        parts.append(beam(f"{name}_Tentacle_{index}",
                          Vector(location) + Vector((offset * scale, 0, -0.12 * scale)),
                          Vector(location) + Vector((offset * 0.55 * scale,
                                                     math.sin(index) * 0.14 * scale,
                                                     -1.0 * scale)),
                          0.035 * scale, mats["jelly_dark"], target, 6))
    reparent(parts, root)
    return root


def add_starfish(name, location, scale, mats, target):
    root = parent_root(name, location, target)
    parts = [ico(f"{name}_Centre", location, (0.22 * scale, 0.22 * scale, 0.10 * scale),
                 mats["starfish"], target, 1)]
    for index in range(5):
        angle = math.tau * index / 5.0
        end = Vector(location) + Vector((math.cos(angle) * 0.72 * scale,
                                         math.sin(angle) * 0.72 * scale, 0.02))
        parts.append(beam(f"{name}_Arm_{index}", location, end, 0.11 * scale,
                          mats["starfish"], target, 6))
    reparent(parts, root)
    return root


def add_turtle(name, location, scale, mats, target):
    root = parent_root(name, location, target)
    shell = ico(f"{name}_Shell", location, (0.72 * scale, 0.52 * scale, 0.30 * scale),
                mats["turtle_shell"], target, 2)
    head = ico(f"{name}_Head", Vector(location) + Vector((0.82 * scale, 0, 0.02)),
               (0.25 * scale, 0.20 * scale, 0.20 * scale), mats["turtle_skin"], target, 1)
    parts = [shell, head]
    for side in (-1, 1):
        for front in (-0.35, 0.38):
            flipper = ico(f"{name}_Flipper_{side}_{front}",
                          Vector(location) + Vector((front * scale, side * 0.62 * scale, -0.05)),
                          (0.30 * scale, 0.16 * scale, 0.07 * scale),
                          mats["turtle_skin"], target, 1)
            flipper.rotation_euler.z = side * math.radians(24)
            parts.append(flipper)
    reparent(parts, root)
    return root


def add_crab(name, location, scale, mats, target):
    root = parent_root(name, location, target)
    body = ico(f"{name}_Body", location, (0.75 * scale, 0.46 * scale, 0.25 * scale),
               mats["coral"], target, 2)
    parts = [body]
    for side in (-1, 1):
        for row in (-0.3, 0.0, 0.3):
            start = Vector(location) + Vector((0.45 * side * scale, row * scale, 0))
            end = start + Vector((0.75 * side * scale, row * 0.5 * scale, -0.12 * scale))
            parts.append(beam(f"{name}_Leg_{side}_{row}", start, end, 0.095 * scale,
                              mats["coral_dark"], target, 7))
        claw_loc = Vector(location) + Vector((1.05 * side * scale, 0.48 * scale, 0.06))
        parts.append(ico(f"{name}_Claw_{side}", claw_loc,
                         (0.30 * scale, 0.22 * scale, 0.16 * scale),
                         mats["coral"], target, 2))
        eye_pos = Vector(location) + Vector((side * 0.29, 0.30, 0.45)) * scale
        parts.append(beam(f"{name}_EyeStalk_{side}", eye_pos - Vector((0, 0, 0.2)) * scale,
                          eye_pos, 0.075 * scale, mats["coral_dark"], target))
        parts.append(ico(f"{name}_EyeWhite_{side}", eye_pos, (0.16 * scale,) * 3,
                         mats["sail"], target, 2))
        parts.append(ico(f"{name}_Pupil_{side}", eye_pos + Vector((0, 0.12, 0)) * scale,
                         (0.09 * scale, 0.065 * scale, 0.10 * scale), mats["ink"], target, 2))
    reparent(parts, root)
    return root


def add_shell(name, location, scale, mats, target):
    root = parent_root(name, location, target)
    parts = []
    for index in range(7):
        angle = math.radians(-63 + index * 21)
        offset = Vector((math.sin(angle) * 0.33, math.cos(angle) * 0.16, 0.12)) * scale
        rib = ico(f"{name}_Rib_{index}", Vector(location) + offset,
                  (0.20 * scale, 0.42 * scale, 0.09 * scale),
                  mats["shell"] if index % 2 == 0 else mats["pearl"], target, 1)
        rib.rotation_euler.z = -angle
        parts.append(rib)
    reparent(parts, root)
    return root


def add_oyster(name, location, scale, mats, target):
    root = parent_root(name, location, target)
    lower = ico(f"{name}_LowerShell", location, (0.75 * scale, 0.55 * scale, 0.12 * scale),
                mats["shell_dark"], target, 1)
    upper = ico(f"{name}_UpperShell", Vector(location) + Vector((0, 0.22, 0.38)) * scale,
                (0.75 * scale, 0.55 * scale, 0.12 * scale), mats["shell"], target, 1)
    upper.rotation_euler.x = math.radians(38)
    pearl = ico(f"{name}_Pearl", Vector(location) + Vector((0, 0.0, 0.22)) * scale,
                (0.18, 0.18, 0.18), mats["pearl"], target, 2)
    reparent([lower, upper, pearl], root)
    return root


def add_sea_mushrooms(name, location, scale, mats, target):
    root = parent_root(name, location, target)
    parts = []
    for index, offset in enumerate(((-0.45, 0, 0), (0, 0.18, 0), (0.42, -0.08, 0))):
        height = (0.58 + index * 0.18) * scale
        pos = Vector(location) + Vector(offset) * scale
        parts.append(cone(f"{name}_Stem_{index}", pos + Vector((0, 0, height * 0.5)),
                          0.12 * scale, 0.19 * scale, height, mats["mushroom_stem"], target, 8))
        parts.append(ico(f"{name}_Cap_{index}", pos + Vector((0, 0, height)),
                         (0.42 * scale, 0.42 * scale, 0.18 * scale),
                         mats["mushroom"], target, 1))
    reparent(parts, root)
    return root


def build_sea_life(mats):
    target = collection("SEA_LIFE_GAME_EXPORT")
    root = parent_root("ArteaCoastalSeaLife", (0, 0, 0), target)
    creatures = [
        # Medium reef fish with distinct colour blocking.
        add_fish("Fish_ReefBlue_01", (-5.8, 1.4, -0.50), 0.70,
                 mats["teal"], mats["gold"], target),
        add_fish("Fish_CoralAngel_02", (5.1, 2.7, -0.72), 0.62,
                 mats["coral_soft"], mats["navy"], target),
        add_fish("Fish_SunGold_03", (-3.7, 6.4, -0.88), 0.48,
                 mats["gold"], mats["sail_blue"], target),
        add_fish("Fish_PearlDamsel_04", (3.1, 7.2, -0.58), 0.38,
                 mats["pearl"], mats["coral"], target),
        # Large open-water silhouettes.
        add_long_fish("Fish_BluefinLarge_05", (-7.1, 4.4, -1.10), 0.96,
                      mats["navy"], mats["sail_blue"], mats, target),
        add_long_fish("Fish_SilverRunner_06", (6.8, 5.4, -0.92), 0.76,
                      mats["silver_fish"], mats["teal"], mats, target),
        add_ray("Fish_StoryRay_07", (6.4, -0.4, -0.95), 0.84, mats, target),
        add_puffer("Fish_Puffer_08", (-6.0, -1.1, -0.50), 0.72, mats, target),
        add_seahorse("Fish_Seahorse_09", (4.0, -2.8, -0.38), 0.86, mats, target),
        # A small schooling group gives the water density without visual noise.
        add_fish("Fish_School_10", (-1.9, 4.9, -0.48), 0.24,
                 mats["sail_blue"], mats["pearl"], target),
        add_fish("Fish_School_11", (-1.1, 5.3, -0.62), 0.20,
                 mats["sail_blue"], mats["pearl"], target),
        add_fish("Fish_School_12", (-0.35, 4.7, -0.54), 0.22,
                 mats["sail_blue"], mats["pearl"], target),
        add_fish("Fish_School_13", (0.45, 5.2, -0.68), 0.18,
                 mats["sail_blue"], mats["pearl"], target),
        add_fish("Fish_School_14", (1.15, 4.6, -0.52), 0.23,
                 mats["sail_blue"], mats["pearl"], target),
        add_fish("Fish_School_15", (1.85, 5.15, -0.63), 0.19,
                 mats["sail_blue"], mats["pearl"], target),
        # Shore and seabed life.
        add_crab("Crab_CoralLarge_01", (-5.1, -3.9, 0.05), 0.78, mats, target),
        add_crab("Crab_RockSmall_02", (5.4, -3.0, 0.0), 0.47, mats, target),
        add_crab("Crab_Tidepool_03", (2.8, -4.6, 0.0), 0.34, mats, target),
        add_shell("Shell_FanLarge_01", (-5.7, -2.0, 0.02), 0.95, mats, target),
        add_shell("Shell_FanSmall_02", (4.8, -4.6, 0.0), 0.58, mats, target),
        add_shell("Shell_PearlPink_03", (-2.6, -4.8, 0.0), 0.48, mats, target),
        add_oyster("Oyster_PearlLarge_01", (5.2, 0.2, -0.12), 0.78, mats, target),
        add_oyster("Oyster_PearlSmall_02", (-3.8, 0.0, -0.18), 0.48, mats, target),
        add_sea_mushrooms("Sea_Mushrooms_Tall_01", (-5.2, 5.5, -0.48), 0.78, mats, target),
        add_sea_mushrooms("Sea_Mushrooms_Small_02", (5.5, 6.7, -0.52), 0.48, mats, target),
        add_jellyfish("Jellyfish_Pink_01", (-6.7, 7.0, -0.18), 0.64, mats, target),
        add_jellyfish("Jellyfish_Blue_02", (7.0, 7.2, -0.30), 0.46, mats, target),
        add_starfish("Starfish_Orange_01", (-3.2, -3.4, 0.01), 0.62, mats, target),
        add_starfish("Starfish_Small_02", (3.8, -3.8, 0.01), 0.38, mats, target),
        add_turtle("Turtle_Young_01", (0.2, 7.7, -0.86), 0.72, mats, target),
    ]
    # Actual shallow-water layout: schools stay beside the jetty, never inside it.
    for i, creature in enumerate(creatures):
        prefix = creature.name.split("_")[0]
        kind = {"Fish": "fish", "Crab": "crabs", "Shell": "shells",
                "Oyster": "oysters", "Sea": "sea_mushrooms", "Jellyfish": "jellyfish",
                "Starfish": "starfish", "Turtle": "turtles"}[prefix]
        creature["creature_kind"] = kind
        if kind == "fish":
            creature.scale = Vector((0.65, 0.65, 0.65))
            creature.location.z = -0.36
            if "School" in creature.name:
                n = int(creature.name.rsplit("_", 1)[1]) - 10
                creature.location.x = -3.3 - (n % 3) * 0.75
                creature.location.y = 3.6 + (n // 3) * 1.1
            elif "Seahorse" in creature.name:
                creature.location.z = -0.42
        elif kind in ("jellyfish", "turtles"):
            creature.scale = Vector((0.65, 0.65, 0.65))
            creature.location.z = -0.35
        else:
            # Rock pools and shell beds: each animal is seated on a visible support.
            creature.location.z = -0.02 if kind == "crabs" else -0.23
            loc = creature.location.copy()
            base = ico(f"TidepoolRock_{i}", loc + Vector((0, 0, -0.30)),
                       (0.98, 0.78, 0.29), mats["rock"], target, 2)
            base.parent = root
    # A second small school away from the berth, adding life without deck clutter.
    for i in range(8):
        fish = add_fish(f"Fish_School_{16 + i:02}", (4.1 + (i % 4) * 0.65,
                        8.7 + (i // 4) * 0.85, -0.22), 0.19 + (i % 3) * 0.035,
                        mats["gold"] if i % 2 else mats["coral"], mats["sail"], target)
        fish["creature_kind"] = "fish"
        fish.location.z = -0.35
        fish.scale = Vector((0.8, 0.8, 0.8))
        creatures.append(fish)
    reparent(creatures, root)
    return root, target


def select_recursive(root):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root


def export(root, filepath):
    select_recursive(root)
    bpy.ops.export_scene.gltf(filepath=str(filepath), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_materials="EXPORT",
                              export_cameras=False, export_lights=False, export_animations=False,
                              export_extras=True)


def setup_preview(roots, mats):
    harbour, boat, life = roots
    harbour.location = (-8.0, 1.0, 0.0)
    boat.location = (2.2, 7.0, 0.6)
    life.location = (5.7, 0.0, 0.55)
    bpy.ops.mesh.primitive_plane_add(size=58, location=(0, 2, -0.5))
    ground = bpy.context.object
    ground.name = "PreviewWater"
    ground.data.materials.append(mats["preview_water"])
    camera_data = bpy.data.cameras.new("PreviewCamera")
    camera = bpy.data.objects.new("PreviewCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (24, -32, 26)
    camera.data.lens = 46
    camera.rotation_euler = ((Vector((0, 2.5, 0.8)) - camera.location)
                             .to_track_quat("-Z", "Y").to_euler())
    bpy.context.scene.camera = camera
    sun_data = bpy.data.lights.new("PreviewSun", "AREA")
    sun_data.energy = 2300
    sun_data.shape = "DISK"
    sun_data.size = 8
    sun = bpy.data.objects.new("PreviewSun", sun_data)
    sun.location = (-6, -8, 16)
    sun.rotation_euler = ((Vector((0, 2, 0)) - sun.location).to_track_quat("-Z", "Y").to_euler())
    bpy.context.collection.objects.link(sun)
    world = bpy.data.worlds.new("PreviewWorld")
    world.color = (0.35, 0.40, 0.48)
    bpy.context.scene.world = world
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 700
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(ARTIFACT_DIR / "coastal_harbour_preview.png")


def main():
    # Only this background build: avoid extra backup copies on the nearly full disk.
    bpy.context.preferences.filepaths.save_version = 0
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    reset_scene()
    mats = {
        "wood": material("HoneyWood", (0.48, 0.23, 0.095)),
        "wood_light": material("SunBleachedWood", (0.66, 0.36, 0.16)),
        "dark_wood": material("DarkWood", (0.27, 0.12, 0.065)),
        "rope": material("WarmRope", (0.55, 0.34, 0.14)),
        "gold": material("SunflowerYellow", (0.96, 0.62, 0.09), 0.0, 0.8),
        "iron": material("VillageIron", (0.19, 0.28, 0.34), 0.0, 0.8),
        "teal": material("ArteaTeal", (0.035, 0.48, 0.56), 0.05, 0.5),
        "navy": material("StorybookNavy", (0.025, 0.10, 0.19), 0.03, 0.58),
        "roof_red": material("VillageRoofRed", (0.78, 0.045, 0.065), 0.0, 0.85),
        "glass_blue": material("HarbourWindowBlue", (0.18, 0.56, 0.65), 0.12, 0.22),
        "lamp_glass": material("WarmOilLamp", (1.0, 0.48, 0.12), 0.0, 0.28, 0.7),
        "boat_teal": material("BoatDeepTeal", (0.018, 0.22, 0.31), 0.08, 0.42),
        "pearl": material("MoonPearl", (0.86, 0.86, 0.78), 0.12, 0.2),
        "sail": material("PearlSail", (0.91, 0.90, 0.81), 0.0, 0.85),
        "sail_blue": material("SeaBlueCanvas", (0.08, 0.40, 0.55), 0.0, 0.68),
        "coral": material("CoralPink", (0.88, 0.22, 0.20), 0.0, 0.62),
        "coral_soft": material("FadedCoral", (0.74, 0.25, 0.22), 0.0, 0.70),
        "coral_dark": material("CoralShadow", (0.48, 0.07, 0.08), 0.0, 0.7),
        "silver_fish": material("SilverFish", (0.48, 0.67, 0.67), 0.18, 0.28),
        "puffer_yellow": material("PufferYellow", (0.88, 0.60, 0.12), 0.0, 0.58),
        "ray_blue": material("RayBlue", (0.09, 0.28, 0.43), 0.04, 0.46),
        "seahorse": material("SeahorseOrange", (0.82, 0.31, 0.12), 0.0, 0.64),
        "seahorse_light": material("SeahorseLight", (0.96, 0.58, 0.22), 0.0, 0.64),
        "jelly": material("JellyPink", (0.72, 0.30, 0.58), 0.05, 0.30),
        "jelly_dark": material("JellyTentacle", (0.36, 0.13, 0.38), 0.0, 0.50),
        "starfish": material("StarfishOrange", (0.92, 0.30, 0.09), 0.0, 0.72),
        "turtle_shell": material("TurtleShell", (0.15, 0.34, 0.19), 0.0, 0.76),
        "turtle_skin": material("TurtleSkin", (0.30, 0.58, 0.40), 0.0, 0.72),
        "ink": material("CreatureInk", (0.008, 0.012, 0.015), 0.0, 0.45),
        "shell": material("ShellLilac", (0.72, 0.42, 0.68), 0.02, 0.42),
        "shell_dark": material("ShellShadow", (0.30, 0.14, 0.32), 0.0, 0.58),
        "mushroom": material("SeaMushroomCap", (0.73, 0.20, 0.34), 0.0, 0.85),
        "mushroom_stem": material("SeaMushroomStem", (0.79, 0.72, 0.53), 0.0, 0.85),
        "rock": material("CoastalRock", (0.28, 0.37, 0.36), 0.0, 0.95),
        "sand": material("CoastalSand", (0.75, 0.61, 0.31), 0.0, 0.95),
        "preview_water": material("PreviewWater", (0.015, 0.22, 0.34), 0.12, 0.18),
    }
    harbour, _ = build_harbour(mats)
    boat, _ = build_boat(mats)
    life, _ = build_sea_life(mats)
    export(harbour, ASSET_DIR / "artea_harbour.glb")
    export(boat, ASSET_DIR / "artea_sailing_boat.glb")
    export(life, ASSET_DIR / "artea_sea_life.glb")
    setup_preview((harbour, boat, life), mats)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_DIR / "coastal_harbour.blend"))
    bpy.ops.render.render(write_still=True)
    # A second angle shows the seafood counter rather than the shop's rear wall.
    camera = bpy.context.scene.camera
    camera.location = (8, -15, 10)
    camera.rotation_euler = ((Vector((-2, -3, 1.5)) - camera.location)
                             .to_track_quat("-Z", "Y").to_euler())
    camera.data.lens = 48
    light = bpy.data.objects["PreviewSun"]
    light.location = (3, -10, 14)
    light.rotation_euler = ((Vector((0, -2, 0)) - light.location)
                            .to_track_quat("-Z", "Y").to_euler())
    bpy.context.scene.render.filepath = str(ARTIFACT_DIR / "seafood_shop_preview.png")
    bpy.ops.render.render(write_still=True)
    camera.location = (-3.5, -12.0, 4.2)
    camera.rotation_euler = ((Vector((-.35, -5.161, 2.25)) - camera.location)
                             .to_track_quat("-Z", "Y").to_euler())
    camera.data.lens = 70
    bpy.context.scene.render.filepath = str(ARTIFACT_DIR / "seafood_sign_detail.png")
    bpy.ops.render.render(write_still=True)
    camera.location = (-7.7, -14, 5.2)
    camera.rotation_euler = ((Vector((-8, -4.9, 3.15)) - camera.location)
                             .to_track_quat("-Z", "Y").to_euler())
    camera.data.lens = 55
    bpy.context.scene.render.filepath = str(ARTIFACT_DIR / "harbour_milo_style_sign.png")
    bpy.ops.render.render(write_still=True)
    print("COASTAL_HARBOUR_BUILD: PASS — harbour, boat, and sea-life exports written")


if __name__ == "__main__":
    main()
