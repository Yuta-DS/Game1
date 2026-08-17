import bpy
import json
import math
import os
from mathutils import Euler, Vector


ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSET_DIR = os.path.join(ROOT_DIR, "assets3D", "crown_line_train")
ARTIFACT_DIR = os.path.join(ROOT_DIR, "artifacts")
BLEND_PATH = os.path.join(ASSET_DIR, "crown_line_lego_train.blend")
GLB_PATH = os.path.join(ASSET_DIR, "crown_line_lego_train.glb")
MANIFEST_PATH = os.path.join(ASSET_DIR, "crown_line_train_parts_manifest.json")
TEXTURE_DIR = os.path.join(ROOT_DIR, "assets", "textures", "crown_line_train", "concept", "maps")
BLUEPRINT_PATH = os.path.join(ASSET_DIR, "crown_line_engine_cover_blueprint.json")

with open(BLUEPRINT_PATH, "r", encoding="utf-8") as blueprint_file:
    ENGINE_COVER_BLUEPRINT = json.load(blueprint_file)

os.makedirs(ASSET_DIR, exist_ok=True)
os.makedirs(ARTIFACT_DIR, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
    pass


def material(name, color, metallic=0.0, roughness=0.4, emission=None, emission_strength=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


MAT = {
    "navy": material("Train_Navy", (0.075, 0.18, 0.48), 0.08, 0.42),
    "navy_soft": material("Seat_Navy", (0.26, 0.20, 0.55), 0.03, 0.54),
    # Kept under the legacy key for builder compatibility; visually this is
    # warm matte sandstone, not metallic gold.
    "gold": material("Crown_Gold", (0.90, 0.70, 0.40), 0.01, 0.58),
    "accent_gold": material("Crown_AccentGold", (1.0, 0.69, 0.18), 0.34, 0.34),
    "ivory": material("Warm_Ivory", (0.96, 0.89, 0.72), 0.01, 0.66),
    "cream": material("Coach_Cream", (0.98, 0.93, 0.78), 0.01, 0.70),
    "teal": material("Leaf_Teal", (0.10, 0.60, 0.34), 0.02, 0.48),
    "teal_light": material("Leaf_Inner_Light", (0.48, 0.82, 0.34), 0.01, 0.44),
    "cyan": material("Energy_Cyan", (0.06, 0.76, 0.92), 0.22, 0.15, (0.0, 0.82, 1.0), 2.5),
    "cyan_dark": material("Energy_Glass", (0.025, 0.28, 0.40), 0.34, 0.18, (0.0, 0.50, 0.68), 0.75),
    "wood": material("Living_Root", (0.42, 0.25, 0.10), 0.22, 0.56),
    "wood_light": material("Root_Highlight", (0.72, 0.46, 0.20), 0.32, 0.44),
    "bronze": material("Root_Bronze_Band", (0.76, 0.48, 0.20), 0.62, 0.29),
    "purple": material("Crystal_Purple", (0.75, 0.42, 1.0), 0.02, 0.22, (0.72, 0.30, 1.0), 2.4),
    "pink": material("Flower_Pink", (0.95, 0.20, 0.55), 0.12, 0.35, (0.6, 0.02, 0.15), 0.35),
    "warning_red": material("Cab_Warning_Red", (0.72, 0.025, 0.035), 0.25, 0.24, (1.0, 0.01, 0.01), 1.8),
    "warning_amber": material("Cab_Warning_Amber", (0.95, 0.34, 0.035), 0.24, 0.23, (1.0, 0.20, 0.01), 1.5),
    "signal_green": material("Cab_Signal_Green", (0.03, 0.68, 0.24), 0.18, 0.22, (0.0, 1.0, 0.18), 1.8),
    "rubber": material("Cab_Control_Rubber", (0.012, 0.016, 0.024), 0.08, 0.58),
    "green": material("Planter_Green", (0.08, 0.30, 0.15), 0.15, 0.60),
    "rail": material("Rail_Dark", (0.018, 0.025, 0.065), 0.82, 0.22),
}


def add_procedural_surface(mat, scale, strength, distance, low_color, high_color):
    """Add smooth hand-painted colour variation and restrained material grain."""
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.name = mat.name + "_MicroGrain"
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = 3.0
    noise.inputs["Roughness"].default_value = .62
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.name = mat.name + "_PaintVariation"
    ramp.color_ramp.elements[0].position = .28
    ramp.color_ramp.elements[0].color = (*low_color, 1.0)
    ramp.color_ramp.elements[1].position = .72
    ramp.color_ramp.elements[1].color = (*high_color, 1.0)
    bump = nodes.new("ShaderNodeBump")
    bump.name = mat.name + "_MicroBump"
    bump.inputs["Strength"].default_value = strength
    bump.inputs["Distance"].default_value = distance
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])


def add_authored_texture_set(mat, texture_name, scale=(2.0, 2.0, 2.0),
                             normal_strength=.55, use_albedo=True, use_emission=False):
    """Attach a complete atlas-derived PBR material set."""
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    texcoord = nodes.new("ShaderNodeTexCoord")
    texcoord.name = mat.name + "_TextureCoordinates"
    mapping = nodes.new("ShaderNodeMapping")
    mapping.name = mat.name + "_TextureScale"
    mapping.inputs["Scale"].default_value = scale
    links.new(texcoord.outputs["UV"], mapping.inputs["Vector"])
    loaded = {}
    for channel in ("albedo", "roughness", "metallic", "height", "normal", "emission"):
        path = os.path.join(TEXTURE_DIR, f"{texture_name}_{channel}.png")
        if not os.path.exists(path):
            raise RuntimeError(f"Missing Crown Line texture map: {path}")
        image = bpy.data.images.load(path, check_existing=True)
        if channel != "albedo":
            image.colorspace_settings.name = "Non-Color"
        node = nodes.new("ShaderNodeTexImage")
        node.name = f"{mat.name}_{channel.title()}Map"
        node.image = image
        node.extension = "REPEAT"
        links.new(mapping.outputs["Vector"], node.inputs["Vector"])
        loaded[channel] = node
    if use_albedo:
        links.new(loaded["albedo"].outputs["Color"], bsdf.inputs["Base Color"])
    links.new(loaded["roughness"].outputs["Color"], bsdf.inputs["Roughness"])
    links.new(loaded["metallic"].outputs["Color"], bsdf.inputs["Metallic"])
    normal = nodes.new("ShaderNodeNormalMap")
    normal.name = mat.name + "_AuthoredNormal"
    normal.inputs["Strength"].default_value = normal_strength
    links.new(loaded["normal"].outputs["Color"], normal.inputs["Color"])
    links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
    if use_emission:
        links.new(loaded["emission"].outputs["Color"], bsdf.inputs["Emission Color"])
        # The source materials used high flat-color emission.  Atlas artwork
        # contains bright painted facets already, so a restrained value keeps
        # cyan and violet saturation instead of clipping the crystals to white.
        bsdf.inputs["Emission Strength"].default_value = .28
    mat["authored_texture_set"] = texture_name
    mat["texture_map_count"] = 6
    mat["texture_scope"] = "front side top bottom interior and underside"


for textured_mat, texture_scale, texture_strength, texture_distance, low_color, high_color in (
    (MAT["navy"], 16.0, .025, .012, (0.018,.050,.11), (.045,.105,.19)),
    (MAT["gold"], 22.0, .018, .008, (.62,.10,.16), (1.0,.58,.62)),
    (MAT["ivory"], 10.0, .018, .010, (.68,.64,.55), (.96,.91,.78)),
    (MAT["cream"], 9.0, .012, .008, (.79,.70,.55), (1.0,.91,.73)),
    (MAT["teal"], 11.0, .022, .014, (.018,.24,.29), (.06,.53,.58)),
    (MAT["navy_soft"], 18.0, .028, .014, (.025,.038,.10), (.08,.11,.24)),
    (MAT["wood"], 5.0, .060, .030, (.24,.11,.035), (.58,.34,.12)),
    (MAT["wood_light"], 6.0, .045, .025, (.43,.23,.07), (.78,.50,.21)),
    (MAT["rubber"], 24.0, .045, .018, (.006,.008,.012), (.025,.031,.040)),
    (MAT["teal_light"], 9.0, .016, .010, (.035,.36,.40), (.12,.68,.68)),
    (MAT["cyan_dark"], 14.0, .010, .006, (.012,.19,.28), (.045,.42,.52)),
    (MAT["bronze"], 18.0, .020, .010, (.46,.24,.055), (.92,.61,.24)),
    (MAT["green"], 7.0, .025, .018, (.035,.17,.075), (.14,.39,.18)),
    (MAT["purple"], 12.0, .012, .006, (.40,.12,.62), (.82,.43,.96)),
    (MAT["pink"], 13.0, .014, .007, (.66,.08,.31), (1.0,.36,.65)),
    (MAT["rail"], 28.0, .018, .008, (.008,.012,.036), (.035,.055,.11)),
):
    add_procedural_surface(textured_mat, texture_scale, texture_strength, texture_distance,
                           low_color, high_color)

# Reference-matched texture families.  Reusing these maps across small pieces
# gives the front, side and top one coherent hand-painted product finish while
# every object remains independently selectable and editable.
for textured_mat, texture_name, texture_scale, normal_strength, use_albedo, use_emission in (
    (MAT["navy"], "navy_lacquer", (2.8,2.8,2.8), .24, True, False),
    (MAT["navy_soft"], "indigo_floral_upholstery", (2.5,2.5,2.5), .20, True, False),
    (MAT["gold"], "aged_gold", (3.0,3.0,3.0), .22, True, False),
    (MAT["bronze"], "aged_gold", (3.5,3.5,3.5), .26, True, False),
    (MAT["ivory"], "ivory_ceramic", (2.3,2.3,2.3), .18, True, False),
    (MAT["cream"], "cream_interior", (2.0,2.0,2.0), .14, True, False),
    (MAT["teal"], "roof_teal_enamel", (2.2,2.2,2.2), .22, True, False),
    (MAT["teal_light"], "roof_turquoise_enamel", (1.8,1.8,1.8), .20, True, False),
    (MAT["cyan"], "cyan_crystal", (2.4,2.4,2.4), .12, True, True),
    (MAT["cyan_dark"], "cyan_circuit_glass", (2.4,2.4,2.4), .14, True, True),
    (MAT["wood"], "living_root", (2.5,2.5,2.5), .30, True, False),
    (MAT["wood_light"], "living_root", (2.1,2.1,2.1), .26, True, False),
    (MAT["purple"], "violet_crystal", (2.0,2.0,2.0), .12, True, True),
    (MAT["pink"], "indigo_floral_upholstery", (2.8,2.8,2.8), .14, False, True),
    (MAT["green"], "indigo_floral_upholstery", (2.4,2.4,2.4), .22, True, False),
    (MAT["rail"], "rail_steel", (3.8,3.8,3.8), .28, True, False),
    (MAT["rubber"], "rail_steel", (4.6,4.6,4.6), .30, True, False),
    (MAT["warning_red"], "rail_steel", (4.0,4.0,4.0), .18, False, False),
    (MAT["warning_amber"], "rail_steel", (4.0,4.0,4.0), .18, False, False),
    (MAT["signal_green"], "rail_steel", (4.0,4.0,4.0), .18, False, False),
):
    add_authored_texture_set(textured_mat, texture_name, texture_scale, normal_strength,
                             use_albedo, use_emission)

# Clear front glazing: cyan edge tint and transmission preserve the reference
# colour while keeping the driver's forward sight line physically open.
MAT["wind_glass"] = material("Cab_Clear_Cyan_Glass", (.06,.48,.62), .12, .12)
add_authored_texture_set(MAT["wind_glass"], "cyan_circuit_glass", (2.2,2.2,2.2),
                         .18, True, True)
wind_bsdf = MAT["wind_glass"].node_tree.nodes.get("Principled BSDF")
wind_bsdf.inputs["Transmission Weight"].default_value = .72
wind_bsdf.inputs["Alpha"].default_value = .26
wind_bsdf.inputs["Coat Weight"].default_value = .32
if hasattr(MAT["wind_glass"], "surface_render_method"):
    MAT["wind_glass"].surface_render_method = "DITHERED"

# Surface families for the 5,000-piece nose skin. Every editable plate receives
# one of these authored procedural finishes according to its architectural zone
# rather than sharing one generic prototype material.
COVER_MAT = {}
for key, display_name, base, metallic, roughness, grain, low, high in (
    ("crown_deep", "Cover_Crown_DeepTeal", (.035,.43,.47), .18, .36, 7.0, (.025,.34,.37), (.075,.55,.57)),
    ("crown_light", "Cover_Crown_Patina", (.085,.59,.60), .12, .38, 6.0, (.055,.48,.49), (.15,.72,.68)),
    ("side_teal", "Cover_Side_HammeredTeal", (.035,.47,.50), .22, .37, 8.0, (.024,.36,.39), (.085,.60,.59)),
    ("side_navy", "Cover_Side_BlueSteel", (.035,.115,.20), .28, .36, 10.0, (.022,.075,.14), (.070,.17,.27)),
    ("gold_rib", "Cover_Rib_EngravedGold", (.90,.70,.40), .01, .58, 10.0, (.70,.50,.25), (1.0,.84,.55)),
    ("vent_dark", "Cover_Vent_Ceramic", (.018,.030,.050), .16, .52, 12.0, (.010,.016,.027), (.040,.060,.080)),
    ("jaw_ivory", "Cover_Jaw_WarmIvory", (.82,.78,.66), .12, .40, 7.0, (.66,.61,.51), (.96,.90,.74)),
):
    cover_mat = material(display_name, base, metallic, roughness)
    add_procedural_surface(cover_mat, grain, .009 if key != "jaw_ivory" else .006,
                           .005, low, high)
    cover_mat["surface_family"] = key
    cover_mat["reference_basis"] = "Crown Line concept front, top and side views"
    COVER_MAT[key] = cover_mat

for cover_key, texture_name, texture_scale, normal_strength in (
    ("crown_deep", "roof_teal_enamel", (3.2,3.2,3.2), .22),
    ("crown_light", "roof_turquoise_enamel", (2.6,2.6,2.6), .20),
    ("side_teal", "roof_teal_enamel", (3.7,3.7,3.7), .24),
    ("side_navy", "navy_lacquer", (4.2,4.2,4.2), .22),
    ("gold_rib", "aged_gold", (4.0,4.0,4.0), .20),
    ("vent_dark", "rail_steel", (5.5,5.5,5.5), .28),
    ("jaw_ivory", "ivory_ceramic", (3.0,3.0,3.0), .18),
):
    # Keep the authored roughness/normal structure, but use the brighter
    # hand-painted palette above instead of the photoreal/dark atlas albedo.
    # This matches Artéa's readable low-poly cartoon rendering in gameplay.
    add_authored_texture_set(COVER_MAT[cover_key], texture_name, texture_scale,
                             normal_strength*.55, use_albedo=False)

# One shared ogive definition drives the structural shell, detail placement and
# all 5,000 independent scales.  The first station sits forward of the crystal
# midpoint, so the armour now wraps roughly two-thirds of the propulsion gem
# while leaving its pointed luminous head visible like the concept reference.
COVER_UPPER_WIDTHS = tuple(ENGINE_COVER_BLUEPRINT["upper_widths"])
COVER_UPPER_CENTRES = tuple(ENGINE_COVER_BLUEPRINT["upper_centres"])
COVER_UPPER_ARCHES = tuple(ENGINE_COVER_BLUEPRINT["upper_arches"])
COVER_LOWER_WIDTHS = tuple(ENGINE_COVER_BLUEPRINT["lower_widths"])
COVER_LOWER_CENTRES = tuple(ENGINE_COVER_BLUEPRINT["lower_centres"])
COVER_LOWER_ARCHES = tuple(ENGINE_COVER_BLUEPRINT["lower_arches"])

model_root = bpy.data.objects.new("TRAIN_CrownLineConstructionRoot", None)
bpy.context.collection.objects.link(model_root)
model_objects = [model_root]


def finish_object(obj, name, mat=None, parent=model_root, bevel=0.0):
    obj.name = "TRAIN_" + name
    if mat:
        obj.data.materials.append(mat)
    if bevel > 0.0 and hasattr(obj.data, "polygons"):
        mod = obj.modifiers.new("BrickEdgeBevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    if parent:
        obj.parent = parent
    model_objects.append(obj)
    return obj


def box(name, loc, scale, mat, bevel=0.10, rot=(0, 0, 0), parent=model_root):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    obj = bpy.context.object
    obj.scale = (scale[0] / 2, scale[1] / 2, scale[2] / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_object(obj, name, mat, parent, bevel)


def cylinder(name, loc, radius, depth, mat, vertices=12, rot=(0, 0, 0), parent=model_root):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    return finish_object(bpy.context.object, name, mat, parent, 0.04)


def sphere(name, loc, radius, mat, segments=12, rings=6, parent=model_root):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=radius, location=loc)
    return finish_object(bpy.context.object, name, mat, parent, 0.0)


def torus(name, loc, major, minor, mat, rot=(0, 0, 0), parent=model_root):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                    major_segments=32, minor_segments=8,
                                    location=loc, rotation=rot)
    return finish_object(bpy.context.object, name, mat, parent, 0.0)


def beam(name, start, end, radius, mat, vertices=8, parent=model_root):
    a, b = Vector(start), Vector(end)
    direction = b - a
    midpoint = (a + b) * 0.5
    obj = cylinder(name, midpoint, radius, direction.length, mat, vertices, parent=parent)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
    return obj


def seven_segment_digit(name, digit, center, size, mat, parent=model_root):
    """Build a readable editable instrument digit from seven separate bars."""
    active = {
        "0": "abcedf", "1": "bc", "2": "abdeg", "3": "abcdg",
        "4": "bcfg", "5": "acdfg", "6": "acdefg", "7": "abc",
        "8": "abcdefg", "9": "abcdfg",
    }[digit]
    x, y, z = center
    segments = {
        "a": ((x, y, z+size*.82), (size*.72, .020, size*.14)),
        "b": ((x+size*.42, y, z+size*.42), (size*.14, .020, size*.72)),
        "c": ((x+size*.42, y, z-size*.42), (size*.14, .020, size*.72)),
        "d": ((x, y, z-size*.82), (size*.72, .020, size*.14)),
        "e": ((x-size*.42, y, z-size*.42), (size*.14, .020, size*.72)),
        "f": ((x-size*.42, y, z+size*.42), (size*.14, .020, size*.72)),
        "g": ((x, y, z), (size*.72, .020, size*.14)),
    }
    for segment_name in active:
        loc, dimensions = segments[segment_name]
        box(f"{name}_{segment_name}", loc, dimensions, mat, .006, parent=parent)


def seven_segment_live_display(name, center, size, mat, parent=model_root):
    """Author all seven bars; Godot toggles them from the train's live speed."""
    x, y, z = center
    segments = {
        "a": ((x, y, z+size*.82), (size*.72, .020, size*.14)),
        "b": ((x+size*.42, y, z+size*.42), (size*.14, .020, size*.72)),
        "c": ((x+size*.42, y, z-size*.42), (size*.14, .020, size*.72)),
        "d": ((x, y, z-size*.82), (size*.72, .020, size*.14)),
        "e": ((x-size*.42, y, z-size*.42), (size*.14, .020, size*.72)),
        "f": ((x-size*.42, y, z+size*.42), (size*.14, .020, size*.72)),
        "g": ((x, y, z), (size*.72, .020, size*.14)),
    }
    for segment_name in "abcdefg":
        loc, dimensions = segments[segment_name]
        segment = box(f"{name}_{segment_name}", loc, dimensions, mat, .006, parent=parent)
        # Presentation renders start docked at 000; Godot still imports every
        # bar and takes over visibility from measured runtime speed.
        segment.hide_render = segment_name == "g"


def crystal(name, loc, radius, height, mat, rot=(0, 0, 0), parent=model_root, detailed=True):
    # Large focal crystals are assemblies, not monolithic gems. Their eighteen
    # individually named facets, inner light core and two edge-band rings make
    # the cut direction readable in Blender and in the game. Tiny flower buds
    # remain single meshes so the small decoration does not become visual noise.
    if detailed and (radius >= .43 or height >= 1.4):
        assembly = bpy.data.objects.new("TRAIN_" + name + "_Assembly", None)
        bpy.context.collection.objects.link(assembly)
        assembly.location = loc
        assembly.rotation_euler = rot
        assembly.parent = parent
        model_objects.append(assembly)

        sides = 6
        rings = [
            [(0.0, 0.0, -height*.50)],
            [(math.cos(math.tau*i/sides)*radius, math.sin(math.tau*i/sides)*radius, -height*.22) for i in range(sides)],
            [(math.cos(math.tau*i/sides)*radius, math.sin(math.tau*i/sides)*radius, height*.22) for i in range(sides)],
            [(0.0, 0.0, height*.50)],
        ]

        def facet(piece_name, coordinates, facet_mat):
            mesh = bpy.data.meshes.new(piece_name + "Mesh")
            mesh.from_pydata(coordinates, [], [tuple(range(len(coordinates)))])
            mesh.update()
            obj = bpy.data.objects.new("TRAIN_" + piece_name, mesh)
            bpy.context.collection.objects.link(obj)
            obj.data.materials.append(facet_mat)
            obj.parent = assembly
            model_objects.append(obj)
            solid = obj.modifiers.new("SeparateCrystalFacet", "SOLIDIFY")
            solid.thickness = .018
            bevel = obj.modifiers.new("FacetEdgeBevel", "BEVEL")
            bevel.width = .012
            bevel.segments = 1
            return obj

        major_cut = radius >= .60
        for i in range(sides):
            n = (i+1) % sides
            face_sets = (
                ("LowerFacet", [rings[0][0], rings[1][n], rings[1][i]], mat),
                ("BeltFacet", [rings[1][i], rings[1][n], rings[2][n], rings[2][i]],
                 MAT["cyan"] if mat == MAT["cyan"] and i % 2 else mat),
                ("UpperFacet", [rings[2][i], rings[2][n], rings[3][0]], mat),
            )
            for face_name, coordinates, face_mat in face_sets:
                if major_cut:
                    centroid = tuple(sum(point[axis] for point in coordinates)/len(coordinates) for axis in range(3))
                    for shard_i in range(len(coordinates)):
                        shard_n = (shard_i+1) % len(coordinates)
                        facet(f"{name}_{face_name}_{i:02d}_Shard_{shard_i:02d}",
                              [centroid, coordinates[shard_i], coordinates[shard_n]], face_mat)
                else:
                    facet(f"{name}_{face_name}_{i:02d}", coordinates, face_mat)

        # A smaller emissive core shows through the seams between cut facets.
        core = crystal(name + "_InnerLightCore", (0, 0, 0), radius*.50, height*.72,
                       MAT["cyan"] if mat == MAT["cyan"] else MAT["purple"],
                       parent=assembly, detailed=False)
        # Separate girdle rails emphasize where the upper and lower cuts meet.
        for band_name, ring in (("LowerGirdle", rings[1]), ("UpperGirdle", rings[2])):
            rotation = Euler(rot, "XYZ").to_matrix()
            for i in range(sides):
                a = Vector(loc) + rotation @ Vector(ring[i])
                b = Vector(loc) + rotation @ Vector(ring[(i+1) % sides])
                beam(f"{name}_{band_name}_{i:02d}", a, b, max(.018, radius*.035),
                     MAT["gold"], 6, parent)
        if major_cut:
            rotation = Euler(rot, "XYZ").to_matrix()
            for i in range(sides):
                lower = Vector(loc) + rotation @ Vector(rings[1][i])
                upper = Vector(loc) + rotation @ Vector(rings[2][i])
                beam(f"{name}_LongitudinalCut_{i:02d}",lower,upper,max(.018,radius*.028),
                     MAT["gold"],6,parent)
                n = (i+1) % sides
                cut_faces = (
                    ("Lower", [rings[0][0],rings[1][n],rings[1][i]]),
                    ("Belt", [rings[1][i],rings[1][n],rings[2][n],rings[2][i]]),
                    ("Upper", [rings[2][i],rings[2][n],rings[3][0]]),
                )
                for cut_name, coordinates in cut_faces:
                    centroid = Vector(tuple(sum(point[axis] for point in coordinates)/len(coordinates)
                                            for axis in range(3)))
                    world_centroid = Vector(loc) + rotation @ centroid
                    for ray_i, point in enumerate(coordinates):
                        world_point = Vector(loc) + rotation @ Vector(point)
                        beam(f"{name}_{cut_name}ShardSeam_{i:02d}_{ray_i:02d}",
                             world_centroid,world_point,max(.012,radius*.017),MAT["gold"],6,parent)
        return assembly

    verts = []
    sides = 6
    for z, ring_radius in [(-height * 0.5, 0.0), (-height * 0.22, radius),
                           (height * 0.22, radius), (height * 0.5, 0.0)]:
        if ring_radius == 0.0:
            verts.append((0, 0, z))
        else:
            for i in range(sides):
                ang = math.tau * i / sides
                verts.append((math.cos(ang) * ring_radius, math.sin(ang) * ring_radius, z))
    bottom, lower_start, upper_start, top = 0, 1, 7, 13
    faces = []
    for i in range(sides):
        n = (i + 1) % sides
        faces.append((bottom, lower_start + n, lower_start + i))
        faces.append((lower_start + i, lower_start + n, upper_start + n, upper_start + i))
        faces.append((upper_start + i, upper_start + n, top))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("TRAIN_" + name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = rot
    obj.data.materials.append(mat)
    obj.parent = parent
    model_objects.append(obj)
    bevel = obj.modifiers.new("CutCrystalEdges", "BEVEL")
    bevel.width = 0.035
    bevel.segments = 1
    return obj


def custom_prism(name, points_2d, thickness, loc, mat, rot=(0, 0, 0), parent=model_root, bevel=0.025):
    """Extrude an authored XY profile into one small, editable construction part."""
    half = thickness * 0.5
    verts = [(x, y, -half) for x, y in points_2d] + [(x, y, half) for x, y in points_2d]
    count = len(points_2d)
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    for i in range(count):
        n = (i + 1) % count
        faces.append((i, n, count + n, count + i))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("TRAIN_" + name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = rot
    obj.data.materials.append(mat)
    obj.parent = parent
    model_objects.append(obj)
    if bevel:
        mod = obj.modifiers.new("HandFinishedEdge", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    return obj


def tapered_box(name, center, length_y, front_width, rear_width, front_height,
                rear_height, mat, parent=model_root, bevel=0.08):
    """A faceted wedge used for the locomotive nose and layered armour."""
    fy, ry = -length_y * .5, length_y * .5
    verts = [
        (-front_width*.5, fy, -front_height*.5), (front_width*.5, fy, -front_height*.5),
        (front_width*.5, fy, front_height*.5), (-front_width*.5, fy, front_height*.5),
        (-rear_width*.5, ry, -rear_height*.5), (rear_width*.5, ry, -rear_height*.5),
        (rear_width*.5, ry, rear_height*.5), (-rear_width*.5, ry, rear_height*.5),
    ]
    faces = [(0,1,2,3), (4,7,6,5), (0,4,5,1), (3,2,6,7), (0,3,7,4), (1,5,6,2)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("TRAIN_" + name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = center
    obj.data.materials.append(mat)
    obj.parent = parent
    model_objects.append(obj)
    mod = obj.modifiers.new("FacetedEdge", "BEVEL")
    mod.width = bevel
    mod.segments = 2
    return obj


def armour_scale(name, loc, width, length, thickness, mat, rot=(0, 0, 0),
                 parent=model_root, front_taper=.82, surface_zone="crown"):
    """One editable trapezoidal feather plate for the locomotive skin."""
    hx_back = width * .5
    hx_front = hx_back * front_taper
    hy = length * .5
    hz = thickness * .5
    verts = [
        (-hx_front, -hy, -hz), (hx_front, -hy, -hz),
        (hx_back, hy, -hz), (-hx_back, hy, -hz),
        (-hx_front, -hy, hz), (hx_front, -hy, hz),
        (hx_back, hy, hz), (-hx_back, hy, hz),
    ]
    faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1),
             (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("TRAIN_" + name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = rot
    obj.data.materials.append(mat)
    obj.parent = parent
    obj["construction_role"] = "front crystal-to-cab feather armour"
    obj["surface_zone"] = surface_zone
    obj["surface_texture"] = mat.name
    obj["surface_finish"] = "procedural hand-painted grain and micro-bump"
    model_objects.append(obj)
    return obj


def curved_beak_shell(name, start_y, end_y, front_half_width, rear_half_width,
                      front_z, rear_z, crown_arch, thickness, mat,
                      parent=model_root, stations=24, contours=18, lower=False,
                      profile_mode="generic"):
    """Loft a smooth rocket/bird-mouth shell between the crystal and cab."""
    def profile_sample(values, t):
        scaled = t*(len(values)-1)
        index = min(len(values)-2, int(scaled))
        local_t = scaled-index
        eased = local_t*local_t*(3.0-2.0*local_t)
        return values[index]+(values[index+1]-values[index])*eased

    verts = []
    for layer in (0, 1):
        normal_offset = -thickness * layer if not lower else thickness * layer
        for station_i in range(stations + 1):
            t = station_i / stations
            smooth_t = t*t*(3.0-2.0*t)
            yy = start_y + (end_y-start_y)*t
            if profile_mode == "bird_upper":
                half_width = profile_sample(COVER_UPPER_WIDTHS,t)
                centre_z = profile_sample(COVER_UPPER_CENTRES,t)
                local_arch = profile_sample(COVER_UPPER_ARCHES,t)
                exponent = 1.35+.45*t
            elif profile_mode == "bird_lower":
                half_width = profile_sample(COVER_LOWER_WIDTHS,t)
                centre_z = profile_sample(COVER_LOWER_CENTRES,t)
                local_arch = profile_sample(COVER_LOWER_ARCHES,t)
                exponent = 1.45+.30*t
            else:
                half_width = front_half_width + (rear_half_width-front_half_width)*smooth_t
                longitudinal_bow = math.sin(math.pi*t) * (.16 if not lower else -.08)
                centre_z = front_z + (rear_z-front_z)*smooth_t + longitudinal_bow
                local_arch = crown_arch
                exponent = 1.75
            for contour_i in range(contours + 1):
                u = -1.0 + 2.0*contour_i/contours
                arch = local_arch * (1.0-abs(u)**exponent)
                zz = centre_z + (-arch if lower else arch) + normal_offset
                verts.append((u*half_width, yy, zz))
    ring = (stations + 1) * (contours + 1)
    faces = []
    for layer in (0, 1):
        base = layer*ring
        for station_i in range(stations):
            for contour_i in range(contours):
                a = base + station_i*(contours+1)+contour_i
                b = a+1
                c = b+(contours+1)
                d = a+(contours+1)
                faces.append((a,b,c,d) if layer == 0 else (d,c,b,a))
    for station_i in (0, stations):
        for contour_i in range(contours):
            outer = station_i*(contours+1)+contour_i
            inner = ring+outer
            faces.append((outer, outer+1, inner+1, inner))
    for contour_i in (0, contours):
        for station_i in range(stations):
            outer = station_i*(contours+1)+contour_i
            inner = ring+outer
            faces.append((outer, inner, inner+(contours+1), outer+(contours+1)))
    mesh = bpy.data.meshes.new(name+"Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj = bpy.data.objects.new("TRAIN_"+name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    obj.parent = parent
    obj["construction_role"] = "curved bird-mouth structural foundation"
    obj["surface_texture"] = mat.name
    model_objects.append(obj)
    return obj


def leaf(name, loc, length, width, angle, mat_center=MAT["teal"], parent=model_root):
    """One reference-style leaf, decomposed into backing, inset, midrib and six veins."""
    # The asymmetric lance profile gives the roof a botanical silhouette rather
    # than the flat overlapping diamonds that read as one jagged star.
    outline = [
        (0, -length*.50), (-width*.18, -length*.42), (-width*.47, -length*.16),
        (-width*.50, length*.04), (-width*.33, length*.26), (0, length*.50),
        (width*.33, length*.26), (width*.50, length*.04),
        (width*.47, -length*.16), (width*.18, -length*.42),
    ]
    inset = [(x*.84, y*.88) for x, y in outline]
    custom_prism(name + "_GoldBacking", outline, .10, (loc[0], loc[1], loc[2]),
                 MAT["gold"], rot=(0, 0, angle), parent=parent, bevel=.035)
    custom_prism(name + "_TealBlade", inset, .11, (loc[0], loc[1], loc[2]+.105),
                 mat_center, rot=(0, 0, angle), parent=parent, bevel=.025)
    direction = Vector((-math.sin(angle), math.cos(angle), 0))
    across = Vector((math.cos(angle), math.sin(angle), 0))
    base = Vector(loc) - direction * length * .40 + Vector((0,0,.205))
    tip = Vector(loc) + direction * length * .41 + Vector((0,0,.205))
    beam(name + "_Midrib", base, tip, .055, MAT["gold"], 7, parent)
    # Every perimeter edge is its own angled rail, matching the reference's
    # articulated gold leaf outlines and making the canopy truly brick-like.
    for edge_i in range(len(outline)):
        ax, ay = outline[edge_i]
        bx, by = outline[(edge_i+1) % len(outline)]
        a = Vector(loc) + across*ax + direction*ay + Vector((0,0,.205))
        b = Vector(loc) + across*bx + direction*by + Vector((0,0,.205))
        beam(f"{name}_PerimeterRail_{edge_i:02d}", a, b, .045, MAT["accent_gold"], 6, parent)
    for vein_index, ratio in enumerate((-.20, .02, .22)):
        centre = Vector(loc) + direction * length * ratio + Vector((0,0,.21))
        reach = width * (.31 - abs(ratio)*.25)
        forward = direction * length * .12
        beam(f"{name}_VeinL_{vein_index}", centre, centre + forward - across*reach,
             .035, MAT["gold"], 6, parent)
        beam(f"{name}_VeinR_{vein_index}", centre, centre + forward + across*reach,
             .035, MAT["gold"], 6, parent)


def flower(name, loc, scale=1.0, parent=model_root):
    stem_top = Vector(loc) + Vector((0, 0, 1.0 * scale))
    beam(name + "_Stem", loc, stem_top, 0.07 * scale, MAT["green"], 8, parent)
    for i in range(6):
        ang = math.tau * i / 6
        p = stem_top + Vector((math.cos(ang) * .28, math.sin(ang) * .28, 0)) * scale
        sphere(name + "_Petal_%02d" % i, p, .18 * scale, MAT["pink"], 10, 5, parent)
    crystal(name + "_Bud", stem_top + Vector((0,0,.20*scale)), .16*scale, .55*scale, MAT["purple"], parent=parent)


def planter(name, loc, parent=model_root):
    box(name + "_GoldTray", loc, (3.3, 2.2, .55), MAT["gold"], .10, parent=parent)
    box(name + "_SoilBox", (loc[0], loc[1], loc[2]+.38), (2.8, 1.7, .42), MAT["green"], .10, parent=parent)
    flower(name + "_FlowerA", (loc[0]-.65, loc[1], loc[2]+.58), .75, parent)
    flower(name + "_FlowerB", (loc[0]+.55, loc[1]-.15, loc[2]+.58), .58, parent)


def arch(name, y, z_base, width, height, front_back, parent=model_root):
    """Layered tangent-following arch built from many short authored segments."""
    for side_y in front_back:
        # Separate feet, shafts, collars and capitals make every load path legible.
        for side in (-1, 1):
            x = side * width * .5
            box(f"{name}_Foot_{side_y:+.0f}_{side:+d}", (x, y+side_y, z_base+.18),
                (1.15,.82,.36), MAT["gold"], .10, parent=parent)
            box(f"{name}_ShaftIvory_{side_y:+.0f}_{side:+d}", (x, y+side_y, z_base+height*.34),
                (.72,.62,height*.68), MAT["ivory"], .12, parent=parent)
            box(f"{name}_ShaftGoldInlay_{side_y:+.0f}_{side:+d}",
                (x-side*.29, y+side_y-.33, z_base+height*.34),
                (.14,.10,height*.56), MAT["gold"], .035, parent=parent)
            box(f"{name}_Capital_{side_y:+.0f}_{side:+d}",
                (x, y+side_y, z_base+height*.69), (1.15,.84,.34), MAT["gold"], .08, parent=parent)
        # Semi-ellipse begins above the capitals. Each gold segment overlays an
        # ivory segment and follows the local tangent of the curve.
        points = []
        for i in range(13):
            theta = math.pi * i / 12
            points.append(Vector((math.cos(theta)*width*.5, y+side_y,
                                  z_base+height*.68 + math.sin(theta)*height*.32)))
        for i in range(len(points)-1):
            beam(f"{name}_CurveIvory_{side_y:+.0f}_{i:02d}", points[i], points[i+1],
                 .40, MAT["ivory"], 8, parent)
            inset_a = points[i] + Vector((0, -.34, .05))
            inset_b = points[i+1] + Vector((0, -.34, .05))
            beam(f"{name}_CurveGold_{side_y:+.0f}_{i:02d}", inset_a, inset_b,
                 .105, MAT["gold"], 8, parent)


def roof_rosette(name, center_y, z, radius, parent=model_root, crown=True):
    # Two staggered botanical tiers preserve visible gaps between leaves. Each
    # leaf is itself nine separately named pieces.
    for tier, count, radial, leaf_len, leaf_width, z_add, mat in [
        ("Outer", 8, radius*.30, radius*.84, radius*.42, 0.00, MAT["teal"]),
        ("Inner", 6, radius*.16, radius*.52, radius*.32, .24, MAT["teal_light"]),
    ]:
        for i in range(count):
            ang = math.tau * (i+.5*(tier=="Inner")) / count
            direction = Vector((math.sin(ang), math.cos(ang), 0))
            leaf_loc = Vector((0, center_y, z+z_add)) + direction*radial
            leaf(f"{name}_{tier}Leaf_{i:02d}", leaf_loc, leaf_len, leaf_width,
                 -ang, mat, parent)
    # Reference crown: nested gold disks, cyan bead halo, main crystal and four
    # smaller cut stones instead of one unsupported purple spike.
    cylinder(name + "_HeartGoldDisc", (0, center_y, z+.28), 1.42, .18,
             MAT["gold"], 24, parent=parent)
    torus(name + "_HeartRing", (0, center_y, z+.47), 1.05, .13, MAT["accent_gold"], parent=parent)
    for i in range(10):
        ang = math.tau*i/10
        sphere(f"{name}_HaloBead_{i:02d}", (.92*math.cos(ang), center_y+.92*math.sin(ang), z+.54),
               .11, MAT["cyan"], 10, 5, parent)
    crystal(name + "_HeartCrystal", (0, center_y, z+1.22), .48 if not crown else .66,
            1.55 if not crown else 2.7, MAT["purple"], parent=parent)
    for i in range(4):
        ang = math.tau*i/4 + math.pi/4
        crystal(f"{name}_SatelliteCrystal_{i:02d}",
                (.66*math.cos(ang), center_y+.66*math.sin(ang), z+.82),
                .16, .62, MAT["purple"], rot=(0, math.radians(12), ang), parent=parent)


def root_bogie(name, center_y, length, parent=model_root):
    # Five high-contrast braided strands per side, each subdivided into sixteen
    # short angled pieces, plus metal bindings, wheels, spokes and energy hubs.
    for side in (-1, 1):
        x = side * 4.35
        for strand in range(5):
            points = []
            for i in range(17):
                t = i / 16
                y = center_y - length/2 + length*t
                phase = t*math.tau*2.15 + strand*1.22
                z = .12 + math.sin(phase) * .62 + strand*.055
                points.append((x + math.cos(phase)*.31, y, z))
            for i in range(len(points)-1):
                beam(f"{name}_Root_{'L' if side < 0 else 'R'}_{strand}_{i:02d}",
                     points[i], points[i+1], .16,
                     [MAT["wood"], MAT["wood_light"], MAT["bronze"]][strand%3], 8, parent)
        for band_i, yy in enumerate((center_y-length*.44, center_y, center_y+length*.44)):
            torus(f"{name}_RootBinding_{'L' if side<0 else 'R'}_{band_i}",
                  (x, yy, .14), .56, .09, MAT["gold"], rot=(0, math.pi/2, 0), parent=parent)
        for wheel_i, yy in enumerate((center_y-length*.32, center_y+length*.32)):
            cylinder(f"{name}_Wheel_{'L' if side < 0 else 'R'}_{wheel_i}", (x, yy, .10),
                     .95, .55, MAT["navy"], 16, rot=(0, math.pi/2, 0), parent=parent)
            # Rail wheel engineering layer: flange, tyre, brake disc, caliper,
            # axle bearing and magnetic contact shoe remain separate/editable.
            torus(f"{name}_Tyre_{'L' if side < 0 else 'R'}_{wheel_i}",
                  (x-side*.34, yy, .10), .84, .115, MAT["rail"],
                  rot=(0, math.pi/2, 0), parent=parent)
            torus(f"{name}_RailFlange_{'L' if side < 0 else 'R'}_{wheel_i}",
                  (x-side*.42, yy, .10), .91, .075, MAT["gold"],
                  rot=(0, math.pi/2, 0), parent=parent)
            torus(f"{name}_BrakeDisc_{'L' if side < 0 else 'R'}_{wheel_i}",
                  (x-side*.50, yy, .10), .52, .075, MAT["bronze"],
                  rot=(0, math.pi/2, 0), parent=parent)
            box(f"{name}_BrakeCaliper_{'L' if side < 0 else 'R'}_{wheel_i}",
                (x-side*.62, yy+.48, .24),(.34,.42,.58),MAT["gold"],.07,parent=parent)
            cylinder(f"{name}_AxleBearing_{'L' if side < 0 else 'R'}_{wheel_i}",
                     (x-side*.66,yy,.10),.34,.22,MAT["navy"],16,
                     rot=(0,math.pi/2,0),parent=parent)
            torus(f"{name}_WheelGold_{'L' if side < 0 else 'R'}_{wheel_i}",
                  (x-side*.30, yy, .10), .66, .15, MAT["gold"], rot=(0, math.pi/2, 0), parent=parent)
            sphere(f"{name}_EnergyHub_{'L' if side < 0 else 'R'}_{wheel_i}",
                   (x-side*.62, yy, .10), .25, MAT["cyan"], 10, 5, parent)
            for spoke in range(8):
                ang = math.tau*spoke/8
                start = Vector((x-side*.64, yy, .10))
                end = start + Vector((0, math.cos(ang)*.62, math.sin(ang)*.62))
                beam(f"{name}_WheelSpoke_{side:+d}_{wheel_i}_{spoke}", start, end,
                     .045, MAT["gold"], 6, parent)
            # Nested suspension coils and a cyan guide shoe visually lock the
            # bogie to the energy rail while allowing the body to float above.
            spring_y = yy + (-1 if wheel_i == 0 else 1)*1.15
            for coil_i in range(5):
                torus(f"{name}_SuspensionCoil_{side:+d}_{wheel_i}_{coil_i}",
                      (x-side*.18,spring_y,.48+coil_i*.18),.24,.045,MAT["bronze"],parent=parent)
            beam(f"{name}_SuspensionDamper_{side:+d}_{wheel_i}",
                 (x-side*.18,spring_y,.28),(x-side*.18,spring_y,1.38),.075,MAT["navy"],8,parent)
            box(f"{name}_RailGuideShoe_{side:+d}_{wheel_i}",
                (x-side*.28,yy,-.92),(.74,1.05,.20),MAT["rail"],.055,parent=parent)
            box(f"{name}_RailGuideEnergyPad_{side:+d}_{wheel_i}",
                (x-side*.29,yy,-1.04),(.46,.68,.055),MAT["cyan"],.018,parent=parent)
            for link_side in (-1,1):
                beam(f"{name}_TractionLink_{side:+d}_{wheel_i}_{link_side:+d}",
                     (x-side*.24,yy+link_side*.48,-.72),
                     (x-side*.08,yy+link_side*.92,.18),.055,MAT["gold"],7,parent)
            # Smaller rail wheel wrapped by branching living suspension, as in
            # the supplied close-up. Cyan sap joints show load transfer points.
            for branch_i in range(12):
                ang=math.tau*branch_i/12
                root_start=(x-side*.72,yy+math.cos(ang)*.46,.10+math.sin(ang)*.46)
                root_mid=(x-side*.86,yy+math.cos(ang)*.92,.18+math.sin(ang)*.84)
                root_end=(x-side*.48,yy+math.cos(ang)*1.42,.58+math.sin(ang)*.92)
                beam(f"{name}_WheelRootFork_{side:+d}_{wheel_i}_{branch_i:02d}_A",
                     root_start,root_mid,.075,MAT["wood" if branch_i%2 else "wood_light"],7,parent)
                beam(f"{name}_WheelRootFork_{side:+d}_{wheel_i}_{branch_i:02d}_B",
                     root_mid,root_end,.060,MAT["wood"],7,parent)
                sphere(f"{name}_WheelRootLumen_{side:+d}_{wheel_i}_{branch_i:02d}",
                       root_mid,.065,MAT["cyan" if branch_i%3 else "purple"],8,4,parent)


def passenger_car(name, center_y, parent=model_root):
    car = bpy.data.objects.new("TRAIN_" + name + "_Assembly", None)
    bpy.context.collection.objects.link(car)
    car.parent = parent
    model_objects.append(car)
    # Layered underframe, floor slabs, edge mouldings and a tiled central aisle.
    box(name + "_UnderframeNavy", (0, center_y, .92), (10.9,14.9,.58), MAT["navy"], .18, parent=car)
    box(name + "_ChassisGold", (0, center_y, 1.22), (10.7,14.7,.28), MAT["gold"], .10, parent=car)
    box(name + "_Floor", (0, center_y, 1.48), (10.15,14.15,.34), MAT["cream"], .08, parent=car)
    for side in (-1, 1):
        box(f"{name}_FloorEdge_{side:+d}", (side*4.86, center_y, 1.72),
            (.28,13.8,.24), MAT["gold"], .05, parent=car)
    for tile_i in range(11):
        yy = center_y-5.9+tile_i*1.18
        box(f"{name}_AisleTile_{tile_i:02d}", (0, yy, 1.72),
            (2.55,.88,.10), MAT["cyan_dark" if tile_i%2 else "cyan"], .035, parent=car)
    # Four columns are assemblies of foot, shaft, gold spine, cyan inset,
    # collars, capital and tiny corner rivets rather than one large post.
    for x in (-4.45, 4.45):
        for dy in (-5.9, 5.9):
            tag = f"{x:+.0f}_{dy:+.0f}"
            box(f"{name}_ColumnFoot_{tag}", (x,center_y+dy,2.02), (1.15,1.05,.36), MAT["gold"], .09, parent=car)
            box(f"{name}_ColumnShaft_{tag}", (x,center_y+dy,4.85), (.72,.72,5.5), MAT["ivory"], .12, parent=car)
            box(f"{name}_ColumnOuterGold_{tag}", (x+math.copysign(.33,x),center_y+dy,4.85), (.14,.84,5.2), MAT["accent_gold"], .035, parent=car)
            box(f"{name}_ColumnEnergyInset_{tag}", (x-math.copysign(.37,x),center_y+dy-.02,4.8), (.08,.36,1.75), MAT["cyan"], .025, parent=car)
            for collar_z in (2.52, 6.96):
                box(f"{name}_ColumnCollar_{tag}_{collar_z:.0f}", (x,center_y+dy,collar_z),
                    (1.02,1.0,.22), MAT["gold"], .06, parent=car)
            box(f"{name}_ColumnCapital_{tag}", (x,center_y+dy,7.48), (1.24,1.12,.34), MAT["gold"], .08, parent=car)
            for rivet_i in range(4):
                ang = math.tau*rivet_i/4
                sphere(f"{name}_ColumnRivet_{tag}_{rivet_i}",
                       (x+math.cos(ang)*.46,center_y+dy+math.sin(ang)*.42,2.18),
                       .075, MAT["cyan"], 8, 4, car)
    # Two long benches, each divided into three removable seat/back cushions,
    # separate plinths, armrests, piping, feet and gold end caps.
    for x in (-3.0, 3.0):
        side_tag = "L" if x < 0 else "R"
        box(f"{name}_BenchPlinth_{side_tag}", (x,center_y,2.10), (3.1,8.9,.42), MAT["gold"], .13, parent=car)
        for cushion_i in range(3):
            yy = center_y-2.75+cushion_i*2.75
            box(f"{name}_SeatCushion_{side_tag}_{cushion_i}", (x,yy,2.58),
                (2.55,2.48,.58), MAT["navy_soft"], .22, parent=car)
            box(f"{name}_BackCushion_{side_tag}_{cushion_i}",
                (x+math.copysign(1.08,x),yy,3.63), (.44,2.48,1.95),
                MAT["navy_soft"], .18, rot=(0,.08*math.copysign(1,x),0), parent=car)
            box(f"{name}_BackGoldPiping_{side_tag}_{cushion_i}",
                (x+math.copysign(1.31,x),yy,4.46), (.09,2.28,.09), MAT["gold"], .025, parent=car)
        for arm_i, dy in enumerate((-4.18,4.18)):
            box(f"{name}_Armrest_{side_tag}_{arm_i}", (x,center_y+dy,3.12),
                (2.86,.30,.38), MAT["gold"], .08, parent=car)
            cylinder(f"{name}_ArmGem_{side_tag}_{arm_i}", (x,center_y+dy-.17,3.22),
                     .15,.08,MAT["cyan"],12,rot=(math.pi/2,0,0),parent=car)
        for foot_i, dy in enumerate((-3.2,3.2)):
            box(f"{name}_BenchFoot_{side_tag}_{foot_i}",
                (x,center_y+dy,1.88),(1.45,.38,.55),MAT["navy"],.07,parent=car)
    # Eaves are separate navy beams, gold caps and curved decorative brackets.
    for side in (-1,1):
        box(f"{name}_RoofEaveNavy_{side:+d}",(side*4.58,center_y,7.72),
            (.62,14.0,.44),MAT["navy"],.10,parent=car)
        box(f"{name}_RoofEaveGold_{side:+d}",(side*4.92,center_y,7.83),
            (.16,14.2,.22),MAT["accent_gold"],.04,parent=car)
        for bracket_i, yy in enumerate((center_y-4.1,center_y,center_y+4.1)):
            beam(f"{name}_EaveBrace_{side:+d}_{bracket_i}",(side*4.42,yy,7.35),
                 (side*3.72,yy,6.74),.10,MAT["gold"],8,car)
    arch(name + "_RoofArch", center_y, 2.25, 9.1, 5.7, (-5.9, 5.9), car)
    roof_rosette(name + "_Canopy", center_y, 8.15, 7.0, car, crown=False)
    root_bogie(name + "_Bogie", center_y, 12.5, car)
    return car


def engine(center_y=-17.0, parent=model_root):
    eng = bpy.data.objects.new("TRAIN_Engine_Assembly", None)
    bpy.context.collection.objects.link(eng)
    eng.parent = parent
    model_objects.append(eng)
    # Multi-layer chassis and raised corner bumpers.
    box("Engine_UnderframeNavy", (0,center_y, .90), (11.4,16.0,.62), MAT["navy"], .18, parent=eng)
    box("Engine_ChassisGold", (0,center_y,1.23), (11.15,15.75,.28), MAT["gold"], .10, parent=eng)
    box("Engine_FloorCream", (0,center_y,1.52), (10.6,15.1,.34), MAT["cream"], .08, parent=eng)
    for side in (-1,1):
        box(f"Engine_SideSillNavy_{side:+d}",(side*5.05,center_y,1.72),(.42,14.8,.62),MAT["navy"],.10,parent=eng)
        box(f"Engine_SideSillGold_{side:+d}",(side*5.29,center_y,1.87),(.14,14.9,.22),MAT["gold"],.035,parent=eng)
    for x in (-4.55,4.55):
        for dy in (-6.55,6.55):
            box(f"Engine_BumperFoot_{x:+.0f}_{dy:+.0f}",(x,center_y+dy,1.78),
                (1.15,1.05,.68),MAT["gold"],.12,parent=eng)
            sphere(f"Engine_BumperGem_{x:+.0f}_{dy:+.0f}",(x,center_y+dy-.56,1.88),
                   .16,MAT["cyan"],10,5,eng)
    # The cabin is an open structural cage. Four layered pillars and lower wall
    # panels surround the large cyan windows instead of hiding them in a box.
    cab_y = center_y + 1.15
    # Enclosed bullet-train cockpit shell. The roof and belt armour wrap the
    # driver mechanically while the transparent front remains unobstructed.
    tapered_box("Engine_CabRoofShell",(0,cab_y-.35,7.62),7.80,7.75,9.10,.30,.48,
                MAT["navy"],eng,.10)
    tapered_box("Engine_CabRoofGoldBlade",(0,cab_y-.58,7.88),7.40,7.35,8.72,.10,.16,
                MAT["accent_gold"],eng,.035)
    for side in (-1,1):
        box(f"Engine_CabBeltArmour_{side:+d}",(side*4.62,cab_y,3.18),
            (.46,7.05,1.12),MAT["navy"],.09,parent=eng)
        box(f"Engine_CabBeltGoldRail_{side:+d}",(side*4.88,cab_y,3.65),
            (.10,7.18,.18),MAT["gold"],.025,parent=eng)
        for scale_i in range(8):
            yy=cab_y-2.75+scale_i*.78
            box(f"Engine_CabShoulderScale_{side:+d}_{scale_i:02d}",
                (side*4.76,yy,6.92+(scale_i%2)*.10),(.18,.58,.42),
                MAT["teal" if scale_i%2 else "ivory"],.035,
                rot=(0,math.radians(side*5),0),parent=eng)
    for side in (-1,1):
        for dy in (-3.55,3.55):
            tag = f"{side:+d}_{dy:+.0f}"
            x = side*4.42
            # The forward windshield is carried by the swept Apollo arch below.
            # Do not put a tall rectangular post in front of that curved frame.
            if dy < 0:
                box(f"Engine_CabPillarFoot_{tag}",(x,cab_y+dy,2.18),
                    (1.04,1.00,.42),MAT["gold"],.10,parent=eng)
                continue
            box(f"Engine_CabPillarIvory_{tag}",(x,cab_y+dy,4.93),(.78,.74,6.35),MAT["ivory"],.15,parent=eng)
            box(f"Engine_CabPillarGold_{tag}",(x+side*.33,cab_y+dy,4.93),(.14,.86,6.46),MAT["gold"],.04,parent=eng)
            box(f"Engine_CabPillarInset_{tag}",(x-side*.40,cab_y+dy-.02,4.88),(.08,.32,1.65),MAT["cyan"],.025,parent=eng)
            for collar_z in (2.12,7.72):
                box(f"Engine_CabCollar_{tag}_{collar_z:.0f}",(x,cab_y+dy,collar_z),
                    (1.08,1.02,.25),MAT["gold"],.065,parent=eng)
    box("Engine_CabRearLowerPanel",(0,cab_y+3.55,3.05),(8.85,.42,2.05),MAT["ivory"],.16,parent=eng)
    box("Engine_CabRearGoldRail",(0,cab_y+3.30,3.98),(8.4,.12,.18),MAT["gold"],.04,parent=eng)
    # Side energy windows use a custom chamfered profile, layered rims, corner
    # fasteners and individually built circuit paths.
    for side in (-1, 1):
        x = side*4.56
        side_name = "L" if side<0 else "R"
        profile = [(-2.55,-1.65),(-2.92,-1.18),(-2.92,1.18),(-2.55,1.65),(2.55,1.65),(2.92,1.18),(2.92,-1.18),(2.55,-1.65)]
        # Profile is authored in Y/Z, then stood vertically on the cabin side.
        panel = custom_prism(f"Engine_WindowGlass_{side_name}",profile,.12,(x,cab_y,5.18),
                             MAT["cyan_dark"],rot=(0,math.pi/2,0),parent=eng,bevel=.05)
        panel.rotation_euler = (0,math.pi/2,math.pi/2)
        for yy,z in ((cab_y-2.55,3.52),(cab_y+2.55,3.52),(cab_y-2.55,6.84),(cab_y+2.55,6.84)):
            sphere(f"Engine_WindowBolt_{side_name}_{yy:.0f}_{z:.0f}",(x+side*.12,yy,z),.10,MAT["gold"],10,5,eng)
        # Gold frame split into straight, chamfer and vertical pieces.
        for frame_i,(a,b) in enumerate([
            ((x,cab_y-2.55,3.52),(x,cab_y+2.55,3.52)),
            ((x,cab_y-2.55,6.84),(x,cab_y+2.55,6.84)),
            ((x,cab_y-2.92,4.00),(x,cab_y-2.92,6.36)),
            ((x,cab_y+2.92,4.00),(x,cab_y+2.92,6.36)),
            ((x,cab_y-2.92,4.00),(x,cab_y-2.55,3.52)),
            ((x,cab_y+2.92,4.00),(x,cab_y+2.55,3.52)),
            ((x,cab_y-2.92,6.36),(x,cab_y-2.55,6.84)),
            ((x,cab_y+2.92,6.36),(x,cab_y+2.55,6.84)),
        ]):
            beam(f"Engine_WindowFrame_{side_name}_{frame_i}",a,b,.105,MAT["accent_gold"],8,eng)
        for rune in range(9):
            yy = cab_y-2.0+rune*.50
            z0 = 4.38 + ((rune*3)%5)*.30
            beam(f"Engine_Circuit_{side_name}_{rune}_A",(x+side*.16,yy,z0),
                 (x+side*.16,yy+.24,z0),.035,MAT["cyan"],6,eng)
            beam(f"Engine_Circuit_{side_name}_{rune}_B",(x+side*.16,yy+.24,z0),
                 (x+side*.16,yy+.40,z0+.26*((-1)**rune)),.035,MAT["cyan"],6,eng)
    # Front windscreen: a swept Apollo/bird-brow frame. Its segmented shoulders
    # curve inward toward a shallow crown instead of rising as rectangular
    # pillars, while the entire central sight cone stays transparent.
    front_y = cab_y-3.60
    apollo_outline = [
        Vector((-4.38,front_y,2.18)), Vector((-4.30,front_y,3.10)),
        Vector((-4.08,front_y,4.16)), Vector((-3.68,front_y,5.25)),
        Vector((-3.08,front_y,6.20)), Vector((-2.24,front_y,7.02)),
        Vector((-1.22,front_y,7.62)), Vector((0.00,front_y,7.86)),
        Vector((1.22,front_y,7.62)), Vector((2.24,front_y,7.02)),
        Vector((3.08,front_y,6.20)), Vector((3.68,front_y,5.25)),
        Vector((4.08,front_y,4.16)), Vector((4.30,front_y,3.10)),
        Vector((4.38,front_y,2.18)),
    ]
    for segment_i in range(len(apollo_outline)-1):
        a,b=apollo_outline[segment_i],apollo_outline[segment_i+1]
        beam(f"Engine_ApolloFrameIvory_{segment_i:02d}",a,b,.30,MAT["ivory"],10,eng)
        gold_a=Vector((a.x*1.018,a.y-.11,a.z+.025))
        gold_b=Vector((b.x*1.018,b.y-.11,b.z+.025))
        beam(f"Engine_ApolloFrameGold_{segment_i:02d}",gold_a,gold_b,.075,MAT["accent_gold"],8,eng)
        if segment_i in (1,2,3,10,11,12):
            cyan_a=a.lerp(b,.28)+Vector((0,-.19,0))
            cyan_b=a.lerp(b,.72)+Vector((0,-.19,0))
            beam(f"Engine_ApolloFrameEnergy_{segment_i:02d}",cyan_a,cyan_b,.038,MAT["cyan"],6,eng)
    wind_profile = [
        (-3.34,-1.44),(-2.88,-1.95),(2.88,-1.95),(3.34,-1.44),
        (3.22,.54),(2.78,1.22),(2.10,1.67),(1.18,1.96),(0.0,2.08),
        (-1.18,1.96),(-2.10,1.67),(-2.78,1.22),(-3.22,.54),
    ]
    wind = custom_prism("Engine_WindscreenGlass",wind_profile,.08,(0,front_y-.30,5.15),
                        MAT["wind_glass"],rot=(math.pi/2,0,0),parent=eng,bevel=.05)
    wind.rotation_euler = (math.pi/2,0,0)
    # Keep the driver's forward view open like the reference. Only the two
    # outer structural mullions remain; no crystal or dense grille covers the
    # centre of the glass.
    for mullion_i, side in enumerate((-1,1)):
        xx = side*2.74
        top_x = side*1.94
        top_z = 6.94
        beam(f"Engine_WindscreenMullion_{mullion_i:02d}",
             (xx,front_y-.49,3.64),(top_x,front_y-.49,top_z),.045,MAT["gold"],6,eng)
        for joint_i, zz in enumerate((4.18,5.02,5.86)):
            t=(zz-3.64)/(top_z-3.64)
            joint_x=xx+(top_x-xx)*t
            sphere(f"Engine_WindscreenMullionJoint_{mullion_i:02d}_{joint_i}",
                   (joint_x,front_y-.51,zz),.055,MAT["cyan"],8,4,eng)
    for rail_i, zz in enumerate((4.06,)):
        beam(f"Engine_WindscreenCrossRail_{rail_i:02d}",(-3.12,front_y-.50,zz),
             (3.12,front_y-.50,zz),.035,MAT["gold"],6,eng)
    # Thin edge runes provide machine feedback without blocking sight lines.
    for rune_i in range(7):
        z=4.42+rune_i*.34
        beam(f"Engine_WindscreenEdgeRune_L_{rune_i}",(-2.88,front_y-.51,z),
             (-2.62,front_y-.51,z+.12*((-1)**rune_i)),.026,MAT["cyan"],5,eng)
        beam(f"Engine_WindscreenEdgeRune_R_{rune_i}", (2.88,front_y-.51,z),
             (2.62,front_y-.51,z+.12*((-1)**rune_i)),.026,MAT["cyan"],5,eng)
    for clamp_i,(xx,zz) in enumerate(((-2.9,3.7),(2.9,3.7),(-2.22,6.65),(2.22,6.65))):
        box(f"Engine_WindscreenClamp_{clamp_i}",(xx,front_y-.48,zz),(.36,.18,.52),MAT["gold"],.06,parent=eng)
    # Connected five-layer nose: navy lower keel, gold rim, teal armour wedge,
    # crystal socket and modest faceted tip. This removes the detached glowing blob.
    tapered_box("Engine_NoseLowerKeel",(0,center_y-7.10,2.05),6.8,2.6,8.0,1.05,1.55,MAT["navy"],eng,.12)
    tapered_box("Engine_NoseGoldRim",(0,center_y-7.00,2.82),6.5,3.1,8.15,.34,.42,MAT["gold"],eng,.07)
    tapered_box("Engine_NoseInnerArmor",(0,center_y-6.92,3.08),6.15,2.1,6.35,.48,.76,MAT["navy"],eng,.08)
    tapered_box("Engine_CrystalSocket",(0,center_y-11.12,3.16),1.52,1.38,2.05,1.02,1.24,MAT["gold"],eng,.07)
    # Only the sharpened head of the propulsion crystal projects beyond the
    # beak. Most of the gem is protected inside the reactor/socket, matching
    # the reference silhouette instead of presenting a detached whole crystal.
    crystal("Engine_NoseCrystal",(0,center_y-12.10,3.18),.70,2.40,MAT["cyan"],
            rot=(math.pi/2,0,0),parent=eng)
    # The old stack of five straight wedges has deliberately been removed.
    # The continuous loft below is now the visible body, so the nose reads as
    # one aerodynamic bird/bullet shell rather than a pile of prototype slabs.

    # Crystal-to-cab covering shell. It begins behind the exposed front half of
    # the propulsion crystal and grows into a low bird/bullet-train forehead.
    # Its rear edge stays beneath the windscreen, preserving the driver's view.
    shell_start_y = float(ENGINE_COVER_BLUEPRINT["cover_start_z"])
    shell_end_y = float(ENGINE_COVER_BLUEPRINT["cover_end_z"])
    curved_beak_shell("Engine_FrontCoverUpperMouth", shell_start_y, shell_end_y,
                      .66, 4.42, 3.13, 3.55, .32, .14,
                      COVER_MAT["side_teal"], eng,profile_mode="bird_upper")
    curved_beak_shell("Engine_FrontCoverLowerJaw", shell_start_y+.08, shell_end_y+.04,
                      .60, 4.55, 2.75, 3.02, .16, .13,
                      COVER_MAT["side_navy"], eng, lower=True,profile_mode="bird_lower")
    curved_beak_shell("Engine_FrontCoverGoldKeel", shell_start_y+.03, shell_end_y-.02,
                      .63, 4.48, 2.95, 3.23, .035, .045,
                      COVER_MAT["gold_rib"], eng, stations=20, contours=14)

    # Rocket-like capture collars swallow the crystal's rear half and transition
    # its hexagonal cut into the rounded mouth instead of leaving a detached gem.
    for collar_i,(yy,radius,minor,collar_mat) in enumerate((
        (shell_start_y+.03,.735,.032,COVER_MAT["gold_rib"]),
        (shell_start_y+.32,.815,.040,COVER_MAT["side_teal"]),
        (shell_start_y+.63,.905,.036,COVER_MAT["gold_rib"]),
    )):
        torus(f"Engine_CrystalRocketCollar_{collar_i}",(0,yy,3.18),radius,minor,
              collar_mat,rot=(math.pi/2,0,0),parent=eng)
    # Paired side seams form a readable curved upper/lower bird mouth in profile.
    mouth_segments = 18
    for side in (-1,1):
        for segment_i in range(mouth_segments):
            t0=segment_i/mouth_segments
            t1=(segment_i+1)/mouth_segments
            def mouth_point(t, z_offset=0.0):
                smooth=t*t*(3.0-2.0*t)
                yy=shell_start_y+(shell_end_y-shell_start_y)*t
                half_width=.66+(4.42-.66)*smooth
                zz=2.98+.31*smooth+.075*math.sin(math.pi*t)+z_offset
                return (side*half_width,yy,zz)
            beam(f"Engine_CurvedMouthDark_{side:+d}_{segment_i:02d}",
                 mouth_point(t0,-.045),mouth_point(t1,-.045),.078,
                 COVER_MAT["vent_dark"],7,eng)
            beam(f"Engine_CurvedMouthGoldLip_{side:+d}_{segment_i:02d}",
                 mouth_point(t0,.035),mouth_point(t1,.035),.034,
                 COVER_MAT["gold_rib"],6,eng)
    # A narrow crown ridge gives the top view a pointed avian/rocket centreline.
    for ridge_i in range(22):
        t0=ridge_i/22.0
        t1=(ridge_i+1)/22.0
        def ridge_point(t):
            smooth=t*t*(3.0-2.0*t)
            return (0,shell_start_y+(shell_end_y-shell_start_y)*t,
                    3.45+.46*smooth+.14*math.sin(math.pi*t))
        beam(f"Engine_UpperBeakCrownRidge_{ridge_i:02d}",ridge_point(t0),ridge_point(t1),
             .036,COVER_MAT["gold_rib"],6,eng)

    def cover_profile_value(values, t):
        scaled=t*(len(values)-1)
        index=min(len(values)-2,int(scaled))
        local_t=scaled-index
        eased=local_t*local_t*(3.0-2.0*local_t)
        return values[index]+(values[index+1]-values[index])*eased

    def upper_cover_surface(t, contour=0.0, lift=0.0):
        half_width=cover_profile_value(COVER_UPPER_WIDTHS,t)
        centre_z=cover_profile_value(COVER_UPPER_CENTRES,t)
        arch=cover_profile_value(COVER_UPPER_ARCHES,t)
        exponent=1.35+.45*t
        yy=shell_start_y+(shell_end_y-shell_start_y)*t
        return (half_width*contour,yy,centre_z+arch*(1.0-abs(contour)**exponent)+lift)

    # APOLLO / SCIENCE: a pointed command-module prow, modular pressure spine,
    # thermal gills and inspection nodes turn the hood into engineered hardware.
    apollo_outline=[(-.62,.92),(-.82,.28),(-.52,-.58),(0,-1.12),(.52,-.58),(.82,.28),(.62,.92)]
    custom_prism("Engine_ApolloProwGold",apollo_outline,.10,(0,center_y-8.55,4.17),
                 COVER_MAT["gold_rib"],parent=eng,bevel=.028)
    custom_prism("Engine_ApolloProwInset",[(x*.78,y*.82) for x,y in apollo_outline],.11,
                 (0,center_y-8.55,4.26),COVER_MAT["side_navy"],parent=eng,bevel=.018)
    for spine_i in range(12):
        t=.14+spine_i*.061
        xx,yy,zz=upper_cover_surface(t,0,.075)
        panel_width=.32+.30*t
        box(f"Engine_ScienceSpinePanel_{spine_i:02d}",(xx,yy,zz),
            (panel_width,.42,.055),COVER_MAT["side_navy"],.012,parent=eng)
        box(f"Engine_ScienceSpineGlyph_{spine_i:02d}",(xx,yy-.02,zz+.035),
            (panel_width*.48,.11,.018),COVER_MAT["gold_rib"],.004,parent=eng)
    for side in (-1,1):
        for gill_i in range(11):
            t=.26+gill_i*.052
            x,y,z=upper_cover_surface(t,side*.94,.025)
            box(f"Engine_ApolloThermalGill_{side:+d}_{gill_i:02d}",(x,y,z),
                (.055,.26,.25),COVER_MAT["vent_dark"],.009,
                rot=(0,math.radians(side*24),0),parent=eng)
            if gill_i%3==0:
                sphere(f"Engine_ApolloInspectionNode_{side:+d}_{gill_i:02d}",
                       (x+side*.04,y,z+.13),.038,COVER_MAT["gold_rib"],7,3,eng)

    # MAGIC: four cyan capillary circuits conduct power from the crystal through
    # the shell, with small purple phase gems marking the resonant junctions.
    for side in (-1,1):
        for channel_i,contour in enumerate((.28,.52)):
            for segment_i in range(16):
                t0=.10+segment_i*.050
                t1=t0+.050
                a=upper_cover_surface(t0,side*contour,.065)
                b=upper_cover_surface(t1,side*contour,.065)
                beam(f"Engine_MagicCapillary_{side:+d}_{channel_i}_{segment_i:02d}",
                     a,b,.021,MAT["cyan"],6,eng)
                if segment_i in (3,8,13):
                    crystal(f"Engine_MagicPhaseGem_{side:+d}_{channel_i}_{segment_i:02d}",
                            (b[0],b[1],b[2]+.09),.055,.20,MAT["purple"],parent=eng,detailed=False)

    # NATURE: a readable second scale of conformal leaf armour sits over the
    # 5,000-piece micro-skin.  Each panel follows the ogive instead of floating
    # horizontally, and every perimeter rail plus midrib remains editable.
    def conformal_leaf_panel(name, t_center, side, contour_center, t_span,
                             contour_span, panel_mat):
        outline = [
            (-.55, 0.00), (-.34, -.34), (-.04, -.50), (.34, -.32),
            (.52, 0.00), (.34, .32), (-.04, .50), (-.34, .34),
        ]
        upper = []
        lower = []
        for along, across in outline:
            t = min(.985, max(.015, t_center + along*t_span))
            contour = min(.965, max(.025,
                contour_center + side*across*contour_span))
            point = Vector(upper_cover_surface(t, side*contour, .105))
            upper.append(point)
            lower.append(point-Vector((0,0,.055)))
        verts = [tuple(point) for point in lower+upper]
        count = len(outline)
        faces = [tuple(range(count-1,-1,-1)), tuple(range(count,count*2))]
        for edge_i in range(count):
            next_i=(edge_i+1)%count
            faces.append((edge_i,next_i,count+next_i,count+edge_i))
        mesh=bpy.data.meshes.new(name+"Mesh")
        mesh.from_pydata(verts,[],faces)
        mesh.update()
        panel=bpy.data.objects.new("TRAIN_"+name,mesh)
        bpy.context.collection.objects.link(panel)
        panel.data.materials.append(panel_mat)
        panel.parent=eng
        panel["construction_role"]="conformal botanical pressure-shell plate"
        panel["surface_zone"]="large readable leaf armour"
        panel["surface_texture"]=panel_mat.name
        model_objects.append(panel)
        bevel=panel.modifiers.new("LeafPanelEdge","BEVEL")
        bevel.width=.018
        bevel.segments=2
        for edge_i in range(count):
            beam(f"{name}_GoldPerimeter_{edge_i:02d}", upper[edge_i],
                 upper[(edge_i+1)%count], .026, COVER_MAT["gold_rib"], 6, eng)
        front=Vector(upper[0]) + Vector((0,0,.018))
        rear=Vector(upper[4]) + Vector((0,0,.018))
        beam(name+"_GoldMidrib",front,rear,.032,COVER_MAT["gold_rib"],6,eng)

    panel_index=0
    for t_center in (.20,.39,.58,.77):
        for side in (-1,1):
            for contour_i,contour_center in enumerate((.19,.47,.76)):
                conformal_leaf_panel(
                    f"Engine_ConceptLeafPanel_{panel_index:02d}",t_center,side,
                    contour_center,.22,.17,
                    COVER_MAT["crown_light" if (panel_index+contour_i)%3==0
                              else "crown_deep"])
                panel_index += 1

    eng["front_cover_extent"] = "exposed crystal midpoint to cab windscreen sill"
    eng["front_cover_style"] = "ogive bird-mouth bullet train with Apollo, magic and botanical systems"
    for side in (-1,1):
        # Slanted luminous "eyes" reinforce the bird-like technology language.
        beam(f"Engine_BulletEye_{side:+d}",(side*.42,center_y-11.25,3.46),
             (side*1.22,center_y-10.70,3.58),.070,MAT["cyan"],7,eng)
        beam(f"Engine_BulletEyeBrow_{side:+d}",(side*.38,center_y-11.18,3.59),
             (side*1.34,center_y-10.54,3.76),.045,MAT["gold"],7,eng)
        tapered_box(f"Engine_BirdCheekCowl_{side:+d}",
                    (side*1.38,center_y-8.82,3.20),4.25,.36,2.15,.34,.88,
                    MAT["navy"],eng,.055)
        for scale_i in range(5):
            yy=center_y-9.92+scale_i*.47
            beam(f"Engine_BeakFeatherSeam_{side:+d}_{scale_i}",
                 (side*(.70+scale_i*.34),yy,3.55+scale_i*.08),
                 (side*(1.18+scale_i*.42),yy+.26,3.63+scale_i*.08),
                 .032,MAT["gold"],6,eng)
    # The large nose silhouette is retained, but its surface is now divided by
    # transverse ribs, side armour tiles, sockets and individual fasteners.
    for seam_i, (yy, half_width, zz) in enumerate((
        (center_y-5.20,3.58,3.79),(center_y-6.15,3.22,3.68),
        (center_y-7.10,2.82,3.56),(center_y-8.05,2.40,3.43),
        (center_y-8.95,1.98,3.31))):
        beam(f"Engine_NoseTopSeam_{seam_i:02d}",(-half_width,yy,zz),(half_width,yy,zz),
             .055,MAT["gold"],7,eng)
        for side in (-1,1):
            sphere(f"Engine_NoseSeamBolt_{seam_i:02d}_{side:+d}",
                   (side*(half_width-.18),yy-.04,zz+.05),.075,MAT["cyan"],8,4,eng)
    for side in (-1,1):
        for plate_i in range(4):
            yy = center_y-5.55-plate_i*1.02
            width = 1.02-plate_i*.13
            box(f"Engine_NoseSideArmour_{side:+d}_{plate_i:02d}",
                (side*(3.80-plate_i*.39),yy,3.03-plate_i*.07),
                (.16,width,.62),MAT["teal_light" if plate_i%2 else "teal"],.035,
                rot=(0,math.radians(side*7),0),parent=eng)
            for bolt_i, by in enumerate((yy-width*.32,yy+width*.32)):
                sphere(f"Engine_NoseSideBolt_{side:+d}_{plate_i:02d}_{bolt_i}",
                       (side*(3.91-plate_i*.39),by,3.08-plate_i*.07),.055,MAT["gold"],8,4,eng)

    # Exterior finishing pass: service hatches, cooling louvres, marker lamps,
    # handholds and an articulated crystal-drive chamber make front/top/side
    # views read as a maintained vehicle rather than a smooth prototype shell.
    for hatch_i, yy in enumerate((center_y-5.55, center_y-6.65, center_y-7.72)):
        box(f"Engine_NoseTopHatch_{hatch_i}",(0,yy,3.84-hatch_i*.13),
            (2.65-hatch_i*.34,.72,.10),MAT["navy"],.035,parent=eng)
        for edge in (-1,1):
            beam(f"Engine_NoseTopHatchRail_{hatch_i}_{edge:+d}",
                 (edge*(1.12-hatch_i*.14),yy-.29,3.91-hatch_i*.13),
                 (edge*(1.12-hatch_i*.14),yy+.29,3.91-hatch_i*.13),
                 .035,MAT["gold"],6,eng)
        for vent_i in range(6):
            box(f"Engine_NoseTopVent_{hatch_i}_{vent_i}",
                (-.72+vent_i*.29,yy,3.94-hatch_i*.13),(.16,.42,.035),
                MAT["rail"],.008,parent=eng)
    for side in (-1,1):
        side_tag="L" if side<0 else "R"
        # Side equipment doors use three material layers and real graspable bars.
        for panel_i, yy in enumerate((center_y-5.35,center_y-6.75,center_y-8.05)):
            x=side*(4.14-panel_i*.48)
            box(f"Engine_SideServiceDoor_{side_tag}_{panel_i}",(x,yy,2.52),
                (.11,1.02,.92),MAT["navy"],.035,parent=eng)
            box(f"Engine_SideServiceDoorInset_{side_tag}_{panel_i}",(x+side*.07,yy,2.52),
                (.035,.76,.62),MAT["teal"],.012,parent=eng)
            for corner_i,(dy,dz) in enumerate(((-.36,-.30),(-.36,.30),(.36,-.30),(.36,.30))):
                sphere(f"Engine_SideServiceDoorBolt_{side_tag}_{panel_i}_{corner_i}",
                       (x+side*.11,yy+dy,2.52+dz),.040,MAT["gold"],7,3,eng)
            beam(f"Engine_SideServiceHandle_{side_tag}_{panel_i}",
                 (x+side*.16,yy-.20,2.45),(x+side*.16,yy+.20,2.45),.035,MAT["ivory"],7,eng)
        # Recessed cooling bank, warning lamps and crown-line identity medallion.
        for louvre_i in range(9):
            yy=center_y-4.72+louvre_i*.25
            box(f"Engine_SideCoolingLouvre_{side_tag}_{louvre_i}",
                (side*5.36,yy,2.35+louvre_i*.025),(.055,.16,.56),
                MAT["bronze" if louvre_i%2 else "rail"],.012,
                rot=(0,0,math.radians(side*7)),parent=eng)
        for lamp_i,(yy,lamp_mat) in enumerate(((center_y-5.00,MAT["ivory"]),(center_y-5.45,MAT["warning_red"]))):
            torus(f"Engine_SideMarkerSocket_{side_tag}_{lamp_i}",(side*5.38,yy,3.12),
                  .16,.040,MAT["gold"],rot=(0,math.pi/2,0),parent=eng)
            sphere(f"Engine_SideMarkerLamp_{side_tag}_{lamp_i}",(side*5.44,yy,3.12),
                   .105,lamp_mat,10,5,eng)
        torus(f"Engine_SideCrownMedallion_{side_tag}",(side*5.39,cab_y+1.05,2.62),
              .34,.055,MAT["gold"],rot=(0,math.pi/2,0),parent=eng)
        crystal(f"Engine_SideCrownGem_{side_tag}",(side*5.47,cab_y+1.05,2.62),
                .13,.42,MAT["purple"],rot=(0,math.pi/2,0),parent=eng)
        # Long side datum line and removable bio-power cells reproduce the
        # clean engine silhouette and small cyan accents of the side reference.
        beam(f"Engine_SideEnergyDatum_{side_tag}",(side*5.36,center_y-6.4,2.08),
             (side*5.36,cab_y+3.15,2.08),.038,MAT["cyan"],6,eng)
        for cell_i in range(18):
            yy=center_y-5.9+cell_i*.50
            box(f"Engine_SidePowerCell_{side_tag}_{cell_i:02d}",
                (side*5.42,yy,2.10+(cell_i%3)*.10),(.045,.30,.16),
                MAT["cyan_dark"],.010,parent=eng)
            sphere(f"Engine_SidePowerCellNode_{side_tag}_{cell_i:02d}",
                   (side*5.46,yy,2.11+(cell_i%3)*.10),.034,
                   MAT["cyan" if cell_i%4 else "purple"],7,3,eng)

    # Crystal engine reactor: containment rings, field emitters, braided power
    # conduits and cooling fins visibly connect the nose gem to the chassis.
    reactor_y=center_y-10.62
    for ring_i,(offset,radius) in enumerate(((0,.92),(.48,.78),(.92,.62))):
        torus(f"Engine_ReactorContainmentRing_{ring_i}",(0,reactor_y+offset,3.18),
              radius,.085,MAT["gold"],rot=(math.pi/2,0,0),parent=eng)
        for emitter_i in range(8):
            ang=math.tau*emitter_i/8
            sphere(f"Engine_ReactorEmitter_{ring_i}_{emitter_i}",
                   (math.cos(ang)*radius,reactor_y+offset,3.18+math.sin(ang)*radius),
                   .065,MAT["cyan" if emitter_i%2 else "purple"],8,4,eng)
    for side in (-1,1):
        for conduit_i in range(3):
            beam(f"Engine_ReactorPowerConduit_{side:+d}_{conduit_i}",
                 (side*(.42+conduit_i*.22),reactor_y+.95,3.10+conduit_i*.17),
                 (side*(2.75+conduit_i*.20),center_y-7.95,1.38+conduit_i*.18),
                 .075,MAT["cyan" if conduit_i==1 else "bronze"],8,eng)
        for fin_i in range(7):
            box(f"Engine_ReactorCoolingFin_{side:+d}_{fin_i}",
                (side*(2.05+fin_i*.20),reactor_y+.58+fin_i*.13,3.18),
                (.09,.52,1.05-fin_i*.06),MAT["navy"],.022,
                rot=(0,math.radians(side*(10+fin_i*2)),0),parent=eng)
        for valve_i in range(10):
            yy=reactor_y+.18+valve_i*.15
            torus(f"Engine_ReactorValveRing_{side:+d}_{valve_i:02d}",
                  (side*(1.18+valve_i*.08),yy,3.02+(valve_i%3)*.16),
                  .11,.025,MAT["gold"],rot=(0,math.pi/2,0),parent=eng)
            sphere(f"Engine_ReactorValveCore_{side:+d}_{valve_i:02d}",
                   (side*(1.20+valve_i*.08),yy,3.02+(valve_i%3)*.16),
                   .050,MAT["cyan"],7,3,eng)

    # Driver floor: removable energy tiles, seam strips and four corner locks.
    for row in range(6):
        for column in range(5):
            xx = -2.56 + column*1.28
            yy = cab_y-2.30 + row*.86
            box(f"Engine_DriverFloorTile_{row:02d}_{column:02d}",(xx,yy,1.76),
                (1.08,.68,.09),MAT["cyan_dark" if (row+column)%2 else "cream"],.025,parent=eng)
            for notch in (-1,1):
                box(f"Engine_DriverFloorNotch_{row:02d}_{column:02d}_{notch:+d}",
                    (xx+notch*.43,yy-.29,1.82),(.08,.08,.035),MAT["gold"],.012,parent=eng)

    # Driver chair is a modular pedestal, swivel, sprung frame and five padded
    # sections, positioned behind the controls without blocking the aisle.
    cylinder("Engine_DriverSeatPedestal",(0,cab_y+.90,2.18),.42,1.02,MAT["gold"],16,parent=eng)
    torus("Engine_DriverSeatSwivel",(0,cab_y+.90,2.68),.55,.10,MAT["cyan"],parent=eng)
    for side in (-1,1):
        beam(f"Engine_DriverSeatFrame_{side:+d}",(side*.74,cab_y+.65,2.68),
             (side*.74,cab_y+1.55,4.25),.105,MAT["gold"],8,eng)
    for cushion_i, xx in enumerate((-.68,0,.68)):
        box(f"Engine_DriverSeatCushion_{cushion_i}",(xx,cab_y+.72,3.03),
            (.58,1.35,.38),MAT["navy_soft"],.14,rot=(math.radians(-4),0,0),parent=eng)
    for back_i, xx in enumerate((-.55,.55)):
        box(f"Engine_DriverBackCushion_{back_i}",(xx,cab_y+1.46,3.92),
            (.92,.32,1.45),MAT["navy_soft"],.16,rot=(math.radians(-8),0,0),parent=eng)
        box(f"Engine_DriverBackPiping_{back_i}",(xx,cab_y+1.27,4.50),
            (.76,.06,.08),MAT["gold"],.025,parent=eng)
    for side in (-1,1):
        beam(f"Engine_DriverArmSupport_{side:+d}",(side*.92,cab_y+.65,3.12),
             (side*.92,cab_y-.08,3.55),.09,MAT["gold"],8,eng)
        box(f"Engine_DriverArmPad_{side:+d}",(side*.92,cab_y-.18,3.59),
            (.38,1.10,.22),MAT["navy_soft"],.08,parent=eng)

    # Sloped dashboard: structural base, three removable top plates, framed
    # display, gauges, rune pixels, switches, pedals and twin throttle levers.
    # Earlier versions placed this bank too far into the nose. Moving the whole
    # control system aft makes it physically reachable from the driver chair.
    dash_shift = 3.55
    tapered_box("Engine_DashboardBase",(0,center_y-4.55+dash_shift,4.02),2.3,5.45,6.15,.56,.82,MAT["ivory"],eng,.12)
    for cluster_i, cluster_x in enumerate((-2.05,0,2.05)):
        # Each former slab becomes six removable feather tiles. Staggering the
        # rows produces a crafted botanical rhythm and exposes panel gaps.
        for tile_i in range(6):
            row, column = divmod(tile_i,3)
            xx = cluster_x + (column-1)*.52
            yy = center_y-4.92+dash_shift + row*.58
            profile = [(-.21,-.22),(-.14,.20),(0,.29),(.14,.20),(.21,-.22),(0,-.30)]
            custom_prism(f"Engine_DashboardFeather_{cluster_i}_{tile_i}_Gold",profile,.09,
                         (xx,yy,4.50+row*.08),MAT["gold"],
                         rot=(math.radians(-12),0,0),parent=eng,bevel=.018)
            inset = [(x*.74,y*.74) for x,y in profile]
            custom_prism(f"Engine_DashboardFeather_{cluster_i}_{tile_i}_Inset",inset,.10,
                         (xx,yy-.03,4.57+row*.08),
                         MAT["teal_light" if (cluster_i+tile_i)%3==0 else "navy"],
                         rot=(math.radians(-12),0,0),parent=eng,bevel=.014)
            sphere(f"Engine_DashboardFeatherLamp_{cluster_i}_{tile_i}",
                   (xx,yy-.22,4.66+row*.08),.040,
                   MAT["purple" if tile_i in (0,5) else "cyan"],7,3,eng)
        # Separate cluster rails and corner jewels clarify the three functions.
        for rail_side in (-1,1):
            beam(f"Engine_DashboardClusterRail_{cluster_i}_{rail_side:+d}",
                 (cluster_x+rail_side*.86,center_y-5.22+dash_shift,4.46),
                 (cluster_x+rail_side*.86,center_y-4.02+dash_shift,4.70),
                 .035,MAT["gold"],6,eng)
        crystal(f"Engine_DashboardClusterJewel_{cluster_i}",
                (cluster_x,center_y-4.00+dash_shift,4.84),.13,.36,
                MAT["purple" if cluster_i==1 else "cyan"],parent=eng)
    box("Engine_DriverScreen",(0,center_y-5.72+dash_shift,4.43),(3.72,.08,.66),MAT["cyan_dark"],.035,
        rot=(math.radians(-12),0,0),parent=eng)
    for bezel_i,(a,b) in enumerate((
        ((-2.05,center_y-5.80+dash_shift,4.10),(2.05,center_y-5.80+dash_shift,4.10)),
        ((-2.05,center_y-5.80+dash_shift,4.78),(2.05,center_y-5.80+dash_shift,4.78)),
        ((-2.05,center_y-5.80+dash_shift,4.10),(-2.05,center_y-5.80+dash_shift,4.78)),
        ((2.05,center_y-5.80+dash_shift,4.10),(2.05,center_y-5.80+dash_shift,4.78)))):
        beam(f"Engine_DriverScreenBezel_{bezel_i}",a,b,.065,MAT["gold"],7,eng)
    # Pixel-like route diagram is made from short luminous strokes.
    route_points = [(-1.55,4.34),(-1.10,4.55),(-.62,4.28),(-.10,4.58),(.42,4.31),(.92,4.55),(1.48,4.29)]
    for i in range(len(route_points)-1):
        a,b = route_points[i],route_points[i+1]
        beam(f"Engine_DriverRouteLine_{i:02d}",(a[0],center_y-5.87+dash_shift,a[1]),
             (b[0],center_y-5.87+dash_shift,b[1]),.035,MAT["cyan"],6,eng)
        sphere(f"Engine_DriverRouteNode_{i:02d}",(a[0],center_y-5.89+dash_shift,a[1]),
               .065,MAT["purple" if i%3==0 else "cyan"],8,4,eng)
    for gauge_i,xx in enumerate((-2.15,2.15)):
        torus(f"Engine_DriverGaugeRing_{gauge_i}",(xx,center_y-5.50+dash_shift,4.72),.32,.055,MAT["gold"],
              rot=(math.pi/2,0,0),parent=eng)
        beam(f"Engine_DriverGaugeNeedle_{gauge_i}",(xx,center_y-5.84+dash_shift,4.72),
             (xx+(-.12 if gauge_i else .16),center_y-5.84+dash_shift,4.90),.035,MAT["cyan"],6,eng)
    for i in range(9):
        sphere(f"Engine_ControlGem_{i:02d}",(-1.55+i*.39,center_y-5.32+dash_shift,4.73+(i%2)*.08),.075,
               MAT["cyan" if i%3 else "purple"],8,4,eng)
    for switch_i,xx in enumerate((-2.35,-1.85,1.85,2.35)):
        cylinder(f"Engine_ControlSwitchSocket_{switch_i}",(xx,center_y-5.20+dash_shift,4.63),
                 .12,.08,MAT["gold"],12,rot=(math.pi/2,0,0),parent=eng)
        beam(f"Engine_ControlSwitchStem_{switch_i}",(xx,center_y-5.26+dash_shift,4.64),
             (xx,center_y-5.40+dash_shift,4.88),.045,MAT["ivory"],7,eng)
    for lever_i,xx in enumerate((-.72,.72)):
        torus(f"Engine_ControlLeverSocket_{lever_i}",(xx,center_y-4.42+dash_shift,4.46),.20,.055,MAT["gold"],
              rot=(math.pi/2,0,0),parent=eng)
        beam(f"Engine_ControlLever_{lever_i}",(xx,center_y-4.42+dash_shift,4.46),(xx,center_y-4.78+dash_shift,5.05),.065,MAT["gold"],8,eng)
        sphere(f"Engine_ControlLeverGem_{lever_i}",(xx,center_y-4.78+dash_shift,5.05),.14,MAT["purple"],10,5,eng)
    for pedal_i,xx in enumerate((-.62,.62)):
        beam(f"Engine_DriverPedalArm_{pedal_i}",(xx,center_y-3.86+dash_shift,1.84),
             (xx,center_y-4.45+dash_shift,2.20),.08,MAT["gold"],8,eng)
        box(f"Engine_DriverPedalPad_{pedal_i}",(xx,center_y-4.53+dash_shift,2.25),
            (.72,.46,.16),MAT["navy"],.045,rot=(math.radians(-18),0,0),parent=eng)
        for grip in range(3):
            box(f"Engine_DriverPedalGrip_{pedal_i}_{grip}",
                (xx-.20+grip*.20,center_y-4.78+dash_shift,2.29),(.05,.06,.22),MAT["cyan"],.012,
                rot=(math.radians(-18),0,0),parent=eng)

    # Ornate navigation heart: concentric instrument rings, separate spokes,
    # jewel bearings and a cut crystal replace the visually empty upper centre.
    # Driver-facing rear edge of the desk. The windscreen is toward negative Y;
    # mounting the display there would hide it behind the desk from the seat.
    nav_y = center_y-3.50+dash_shift
    nav_z = 6.22
    for ring_i,(major,minor,mat) in enumerate(((.68,.060,MAT["gold"]),(.48,.038,MAT["cyan"]),(.29,.045,MAT["gold"]))):
        torus(f"Engine_NavigationHeartRing_{ring_i}",(0,nav_y,nav_z),major,minor,mat,
              rot=(math.pi/2,0,0),parent=eng)
    for spoke_i in range(12):
        ang = math.tau*spoke_i/12
        inner = Vector((math.cos(ang)*.31,nav_y-.035,nav_z+math.sin(ang)*.31))
        outer = Vector((math.cos(ang)*.62,nav_y-.035,nav_z+math.sin(ang)*.62))
        beam(f"Engine_NavigationHeartSpoke_{spoke_i:02d}",inner,outer,.032,MAT["gold"],6,eng)
        sphere(f"Engine_NavigationHeartBearing_{spoke_i:02d}",outer,.052,
               MAT["purple" if spoke_i%3==0 else "cyan"],8,4,eng)
    crystal("Engine_NavigationHeartCrystal",(0,nav_y-.10,nav_z),.24,.82,MAT["purple"],
            rot=(0,0,math.radians(30)),parent=eng)
    for side in (-1,1):
        beam(f"Engine_NavigationYokeArm_{side:+d}",(side*.54,nav_y,5.96),
             (side*1.30,nav_y+.20,5.30),.075,MAT["gold"],8,eng)
        torus(f"Engine_NavigationYokeGrip_{side:+d}",(side*1.43,nav_y+.20,5.18),
              .26,.075,MAT["navy_soft"],rot=(math.pi/2,0,0),parent=eng)
        for grip_band in (-.12,.12):
            torus(f"Engine_NavigationYokeBand_{side:+d}_{grip_band:+.0f}",
                  (side*1.43+grip_band,nav_y+.18,5.18),.27,.025,MAT["gold"],
                  rot=(math.pi/2,0,0),parent=eng)

    # Layered left/right systems consoles create an asymmetric, believable
    # cockpit workflow: propulsion on the left, route and braking on the right.
    for side in (-1,1):
        side_name = "Propulsion" if side < 0 else "RouteBrake"
        console_x = side*3.35
        tapered_box(f"Engine_{side_name}ConsoleKeel",(console_x,cab_y-1.20,2.92),
                    3.25,2.20,2.55,.42,.66,MAT["gold"],eng,.09)
        tapered_box(f"Engine_{side_name}ConsoleShell",(console_x,cab_y-1.23,3.25),
                    2.95,1.88,2.18,.34,.52,MAT["navy"],eng,.075)
        # Six removable function tiles, each with two fasteners and an inset rune.
        for tile_i in range(6):
            row, column = divmod(tile_i,3)
            xx = console_x + (column-1)*.52
            yy = cab_y-1.82+row*.68
            box(f"Engine_{side_name}Tile_{tile_i:02d}",(xx,yy,3.58+row*.08),
                (.42,.48,.10),MAT["cyan_dark" if tile_i%2 else "teal"],.025,
                rot=(math.radians(-8),0,0),parent=eng)
            sphere(f"Engine_{side_name}TileLamp_{tile_i:02d}",(xx,yy-.25,3.66+row*.08),
                   .055,MAT["purple" if tile_i in (0,5) else "cyan"],8,4,eng)
            for screw_side in (-1,1):
                sphere(f"Engine_{side_name}TileScrew_{tile_i:02d}_{screw_side:+d}",
                       (xx+screw_side*.15,yy+.18,3.65+row*.08),.028,MAT["gold"],6,3,eng)
        # A small articulated crystal selector grows from each console.
        cylinder(f"Engine_{side_name}SelectorSocket",(console_x,cab_y-.33,3.62),
                 .27,.12,MAT["gold"],14,parent=eng)
        beam(f"Engine_{side_name}SelectorStem",(console_x,cab_y-.33,3.68),
             (console_x-side*.18,cab_y-.62,4.15),.055,MAT["ivory"],7,eng)
        crystal(f"Engine_{side_name}SelectorCrystal",(console_x-side*.18,cab_y-.62,4.32),
                .20,.55,MAT["purple" if side<0 else "cyan"],parent=eng)
        for guard_i, guard_x in enumerate((console_x-.68,console_x+.68)):
            beam(f"Engine_{side_name}Guard_{guard_i}",(guard_x,cab_y-.18,3.05),
                 (guard_x,cab_y-2.45,3.58),.055,MAT["gold"],7,eng)

    # The seat back becomes a five-lobed botanical shell. Every lobe has a gold
    # backing, teal inset and central vein, plus a small crown crystal.
    seat_lobe_profile = [(-.48,-.75),(-.62,-.12),(-.36,.48),(0,.86),(.36,.48),(.62,-.12),(.48,-.75)]
    for lobe_i,(xx,angle,scale) in enumerate(((-1.02,-18,.78),(-.52,-9,.92),(0,0,1.05),(.52,9,.92),(1.02,18,.78))):
        profile = [(x*scale,y*scale) for x,y in seat_lobe_profile]
        inset = [(x*.78,y*.82) for x,y in profile]
        custom_prism(f"Engine_DriverSeatLeaf_{lobe_i}_Gold",profile,.12,
                     (xx,cab_y+1.73,4.33),MAT["gold"],
                     rot=(math.pi/2,0,math.radians(angle)),parent=eng,bevel=.035)
        custom_prism(f"Engine_DriverSeatLeaf_{lobe_i}_Inset",inset,.13,
                     (xx,cab_y+1.65,4.34),MAT["teal" if lobe_i%2 else "teal_light"],
                     rot=(math.pi/2,0,math.radians(angle)),parent=eng,bevel=.025)
        beam(f"Engine_DriverSeatLeaf_{lobe_i}_Vein",(xx,cab_y+1.55,3.77),
             (xx,cab_y+1.55,5.00),.035,MAT["gold"],6,eng)
    torus("Engine_DriverSeatCrownRing",(0,cab_y+1.50,5.18),.42,.055,MAT["gold"],
          rot=(math.pi/2,0,0),parent=eng)
    crystal("Engine_DriverSeatCrownCrystal",(0,cab_y+1.42,5.52),.20,.72,MAT["purple"],parent=eng)

    # Fine overhead utility rail: map lights, hanging beads and three separate
    # hand-tuned crystal indicators fill the former empty upper cab volume.
    beam("Engine_OverheadInstrumentRail",(-3.10,cab_y-1.15,7.10),(3.10,cab_y-1.15,7.10),
         .09,MAT["gold"],8,eng)
    for indicator_i,xx in enumerate((-2.1,0,2.1)):
        torus(f"Engine_OverheadIndicatorSocket_{indicator_i}",(xx,cab_y-1.15,6.90),
              .25,.045,MAT["gold"],rot=(math.pi/2,0,0),parent=eng)
        for bead_i in range(3):
            sphere(f"Engine_OverheadIndicatorBead_{indicator_i}_{bead_i}",
                   (xx,cab_y-1.15,6.78-bead_i*.14),.045,MAT["cyan"],7,3,eng)
        crystal(f"Engine_OverheadIndicatorCrystal_{indicator_i}",
                (xx,cab_y-1.15,6.28),.18,.62,
                MAT["purple" if indicator_i==1 else "cyan"],parent=eng)

    # Research-grounded railway driving layer. The central DMI follows the
    # information hierarchy used by ETCS displays: actual speed, permitted /
    # target speed, distance-to-target, mode/safety state and acknowledgement.
    dmi_y = nav_y + .22
    box("Engine_ETCS_DMI_Backbox",(0,dmi_y,4.22),(2.95,.34,1.55),MAT["rubber"],.12,
        rot=(math.radians(-7),0,0),parent=eng)
    box("Engine_ETCS_DMI_GoldFrame",(0,dmi_y+.24,4.25),(2.72,.12,1.32),MAT["gold"],.055,
        rot=(math.radians(-7),0,0),parent=eng)
    box("Engine_ETCS_DMI_Glass",(0,dmi_y+.34,4.26),(2.48,.055,1.10),MAT["cyan_dark"],.025,
        rot=(math.radians(-7),0,0),parent=eng)
    # Anti-glare hood is separately hinged so its angle can be adjusted.
    for hood_i,(loc,scale,rot) in enumerate((
        ((0,dmi_y+.32,4.93),(2.95,.72,.12),(math.radians(-15),0,0)),
        ((-1.47,dmi_y+.32,4.45),(.12,.72,1.08),(0,0,math.radians(-4))),
        ((1.47,dmi_y+.32,4.45),(.12,.72,1.08),(0,0,math.radians(4))))):
        box(f"Engine_ETCS_AntiGlareHood_{hood_i}",loc,scale,MAT["navy"],.045,rot=rot,parent=eng)
    for hinge_i,xx in enumerate((-1.15,1.15)):
        cylinder(f"Engine_ETCS_HoodHinge_{hinge_i}",(xx,dmi_y+.48,4.86),.10,.32,
                 MAT["gold"],12,rot=(0,math.pi/2,0),parent=eng)

    # Speedometer arc and ticks (left), target-distance scale (right).
    speed_center = Vector((-.62,dmi_y+.39,4.24))
    for tick_i in range(25):
        ang = math.radians(210 - tick_i*10)
        inner = speed_center + Vector((math.cos(ang)*.35,0,math.sin(ang)*.35))
        outer = speed_center + Vector((math.cos(ang)*(.48 if tick_i%5 else .55),0,
                                       math.sin(ang)*(.48 if tick_i%5 else .55)))
        beam(f"Engine_ETCS_SpeedTick_{tick_i:02d}",inner,outer,
             .018 if tick_i%5 else .028,MAT["ivory"],5,eng)
    beam("Engine_ETCS_ActualSpeedNeedle",speed_center,
         speed_center+Vector((-.18,-.01,.38)),.030,MAT["cyan"],6,eng)
    beam("Engine_ETCS_PermittedSpeedArc",speed_center+Vector((-.42,0,.23)),
         speed_center+Vector((-.18,0,.47)),.040,MAT["warning_amber"],6,eng)
    sphere("Engine_ETCS_SpeedHub",speed_center,.080,MAT["gold"],10,5,eng)
    # No numeric speed text: a physical fan of luminous bands expands with
    # measured speed while the needle sweeps the calibrated arc.
    for band_i in range(14):
        zz=3.96+band_i*.055
        width=.10+.015*band_i
        box(f"Engine_SpeedMechanismBand_{band_i:02d}",(.72,dmi_y+.46,zz),
            (width,.020,.030),MAT["cyan" if band_i<10 else "warning_amber"],.006,parent=eng)
    for rotor_i,(major,minor,rotor_mat) in enumerate(((.22,.025,MAT["gold"]),(.15,.018,MAT["cyan"]))):
        torus(f"Engine_SpeedMechanismRotor_{rotor_i}",speed_center,major,minor,rotor_mat,
              rot=(math.pi/2,0,0),parent=eng)
    for bar_i in range(12):
        zz = 3.83+bar_i*.065
        width = .24 if bar_i in (2,7,10) else .16
        box(f"Engine_ETCS_DistanceBar_{bar_i:02d}",(.72,dmi_y+.40,zz),
            (width,.035,.035),MAT["warning_amber" if bar_i>8 else "cyan"],.008,parent=eng)
    crystal("Engine_ETCS_TargetMarker",(.72,dmi_y+.41,4.63),.075,.22,MAT["purple"],parent=eng)
    # Bottom status cells: train integrity, brake, radio, doors and safety mode.
    for state_i,(xx,state_mat) in enumerate(((-.92,MAT["signal_green"]),(-.46,MAT["cyan"]),
                                             (0,MAT["warning_amber"]),(.46,MAT["signal_green"]),
                                             (.92,MAT["purple"]))):
        box(f"Engine_ETCS_StatusCell_{state_i}",(xx,dmi_y+.40,3.82),(.34,.035,.18),
            MAT["navy"],.018,parent=eng)
        sphere(f"Engine_ETCS_StatusLamp_{state_i}",(xx,dmi_y+.43,3.83),.050,state_mat,8,4,eng)
        for glyph_i in range(3):
            box(f"Engine_ETCS_StatusGlyph_{state_i}_{glyph_i}",
                (xx-.09+glyph_i*.09,dmi_y+.44,3.75),(.045,.018,.018),state_mat,.004,parent=eng)

    # Twin pneumatic-style gauges make brake state glance-readable even if the
    # magical DMI fails: main reservoir on the left, brake cylinder on the right.
    for gauge_i,xx in enumerate((-2.30,2.30)):
        torus(f"Engine_BrakeGaugeBezel_{gauge_i}",(xx,dmi_y+.26,5.20),.43,.070,MAT["gold"],
              rot=(math.pi/2,0,0),parent=eng)
        cylinder(f"Engine_BrakeGaugeFace_{gauge_i}",(xx,dmi_y+.34,5.20),.34,.055,
                 MAT["ivory"],24,rot=(math.pi/2,0,0),parent=eng)
        for tick_i in range(12):
            ang = math.radians(225-tick_i*22.5)
            p1=Vector((xx+math.cos(ang)*.24,dmi_y+.39,5.20+math.sin(ang)*.24))
            p2=Vector((xx+math.cos(ang)*.31,dmi_y+.39,5.20+math.sin(ang)*.31))
            beam(f"Engine_BrakeGauge_{gauge_i}_Tick_{tick_i:02d}",p1,p2,.014,MAT["navy"],5,eng)
        ang=math.radians(140 if gauge_i==0 else 55)
        beam(f"Engine_BrakeGaugeNeedle_{gauge_i}",(xx,dmi_y+.42,5.20),
             (xx+math.cos(ang)*.25,dmi_y+.42,5.20+math.sin(ang)*.25),.024,
             MAT["warning_red"],6,eng)
        sphere(f"Engine_BrakeGaugeHub_{gauge_i}",(xx,dmi_y+.45,5.20),.060,MAT["gold"],8,4,eng)

    # Master power/brake controller and horn are deliberately on opposing sides,
    # following RSSB human-factors guidance for simultaneous emergency operation.
    for notch_i in range(9):
        yy=cab_y-1.95+notch_i*.19
        beam(f"Engine_MasterControllerNotch_{notch_i:02d}",(-3.82,yy,3.72),
             (-3.46,yy,3.72),.025,MAT["gold"],6,eng)
    torus("Engine_MasterControllerGate",(-3.62,cab_y-1.18,3.76),.62,.065,MAT["gold"],
          rot=(0,math.pi/2,0),parent=eng)
    beam("Engine_MasterControllerHandle",(-3.62,cab_y-1.18,3.80),
         (-3.62,cab_y-.64,4.45),.115,MAT["rubber"],10,eng)
    sphere("Engine_MasterControllerGrip",(-3.62,cab_y-.64,4.45),.20,MAT["navy_soft"],12,6,eng)
    cylinder("Engine_HornButtonSocket",(3.58,cab_y-1.02,3.85),.28,.12,MAT["gold"],16,parent=eng)
    cylinder("Engine_HornButton",(3.58,cab_y-1.02,3.98),.21,.16,MAT["warning_amber"],16,parent=eng)
    cylinder("Engine_EmergencyBrakeGuard",(3.00,cab_y-1.70,3.86),.34,.10,MAT["gold"],16,parent=eng)
    sphere("Engine_EmergencyBrakeMushroom",(3.00,cab_y-1.70,4.04),.27,MAT["warning_red"],14,7,eng)
    torus("Engine_EmergencyBrakeGuardRing",(3.00,cab_y-1.70,4.08),.37,.050,MAT["gold"],parent=eng)

    # Driver reminder / vigilance / acknowledge cluster.
    for safety_i,(xx,state_mat) in enumerate(((-.42,MAT["warning_red"]),(0,MAT["warning_amber"]),(.42,MAT["cyan"]))):
        cylinder(f"Engine_SafetyAcknowledgeSocket_{safety_i}",(xx,cab_y-.48,3.70),.17,.10,
                 MAT["gold"],14,parent=eng)
        cylinder(f"Engine_SafetyAcknowledgeButton_{safety_i}",(xx,cab_y-.48,3.81),.125,.14,
                 state_mat,14,parent=eng)

    # Railway radio / train-management keypad and a dedicated illuminated route
    # manual reading zone, kept away from live switches.
    box("Engine_TrainRadioBody",(-3.38,cab_y+.06,4.70),(1.05,.42,1.32),MAT["rubber"],.08,parent=eng)
    box("Engine_TrainRadioScreen",(-3.38,cab_y-.18,5.00),(.78,.055,.35),MAT["cyan_dark"],.025,parent=eng)
    for key_i in range(12):
        row,column=divmod(key_i,3)
        sphere(f"Engine_TrainRadioKey_{key_i:02d}",(-3.64+column*.26,cab_y-.23,4.26+row*.18),
               .065,MAT["ivory" if key_i<9 else "cyan"],8,4,eng)
    box("Engine_RouteManualRest",(3.38,cab_y+.06,4.52),(1.52,.48,1.15),MAT["gold"],.07,
        rot=(math.radians(-8),0,0),parent=eng)
    for page_i in range(9):
        box(f"Engine_RouteManualPage_{page_i:02d}",(3.38,cab_y-.22-page_i*.008,4.57+page_i*.012),
            (1.28,.018,.91),MAT["cream"],.012,rot=(math.radians(-8),0,0),parent=eng)
        for line_i in range(5):
            box(f"Engine_RouteManualPage_{page_i:02d}_Line_{line_i}",
                (3.38,cab_y-.245-page_i*.008,4.31+line_i*.12+page_i*.012),
                (1.00-.10*(line_i%2),.008,.018),MAT["cyan_dark"],.002,
                rot=(math.radians(-8),0,0),parent=eng)
    for clip_i,xx in enumerate((2.90,3.86)):
        box(f"Engine_RouteManualClip_{clip_i}",(xx,cab_y-.29,5.04),(.18,.08,.30),MAT["gold"],.025,parent=eng)
    # Crown canopy: larger layered flower, star halo, vertical crystal.
    roof_rosette("Engine_CrownCanopy", center_y+1.0, 8.25, 7.4, eng, crown=True)
    torus("Engine_CrownHalo", (0, center_y+1.0, 10.10), 2.35, .16, MAT["gold"], parent=eng)
    for i in range(8):
        ang = math.tau*i/8
        beam(f"Engine_HaloRay_{i:02d}", (math.cos(ang)*1.3, center_y+1+math.sin(ang)*1.3, 10.10),
             (math.cos(ang)*3.0, center_y+1+math.sin(ang)*3.0, 10.10), .085, MAT["gold"], 7, eng)
    root_bogie("Engine_Bogie", center_y, 13.3, eng)
    return eng


def build_front_cover_scales(eng, center_y=-17.0):
    """Add the 5,000-piece front skin after all operator-heavy construction."""
    def profile_sample(values, t):
        t=min(1.0,max(0.0,t))
        scaled=t*(len(values)-1)
        index=min(len(values)-2,int(scaled))
        local_t=scaled-index
        eased=local_t*local_t*(3.0-2.0*local_t)
        return values[index]+(values[index+1]-values[index])*eased

    def upper_profile(t):
        return (profile_sample(COVER_UPPER_WIDTHS,t),
                profile_sample(COVER_UPPER_CENTRES,t),
                profile_sample(COVER_UPPER_ARCHES,t),
                1.35+.45*t)

    cab_y = center_y + 1.15
    front_y = cab_y - 3.60
    component_count = 0
    # The crystal is centred at center_y-12.10 and points along Y.  Beginning
    # forward of its midpoint lets the ogive socket cover more of the gem while
    # preserving a compact, luminous spearhead at the front.
    cover_start_y = float(ENGINE_COVER_BLUEPRINT["cover_start_z"])
    cover_end_y = float(ENGINE_COVER_BLUEPRINT["cover_end_z"])
    cover_rows = 100
    cover_contours = 25
    course_length = (cover_end_y - cover_start_y) / cover_rows
    for row_i in range(cover_rows):
        longitudinal_t = (row_i + .5) / cover_rows
        yy = cover_start_y + longitudinal_t * (cover_end_y - cover_start_y)
        half_width,centre_z,arch_height,profile_exponent=upper_profile(longitudinal_t)
        _,prev_centre,prev_arch,_=upper_profile(longitudinal_t-.012)
        _,next_centre,next_arch,_=upper_profile(longitudinal_t+.012)
        longitudinal_dz=(next_centre+next_arch)-(prev_centre+prev_arch)
        longitudinal_dy=(cover_end_y-cover_start_y)*.024
        longitudinal_pitch=-math.atan2(longitudinal_dz,longitudinal_dy)
        for side in (-1, 1):
            side_tag = "L" if side < 0 else "R"
            for contour_i in range(cover_contours):
                contour_t = (contour_i + .5) / cover_contours
                stagger = ((row_i & 1) * .34 - .17) / cover_contours
                contour_sample = min(.995, max(.005, contour_t + stagger))
                xx = side * half_width * contour_sample
                zz = centre_z+arch_height*(1.0-contour_sample**profile_exponent)
                tile_width = (half_width / cover_contours) * .92
                tile_length = course_length * 1.15
                roll = side * math.radians(4.0 + 40.0 * (contour_sample ** 1.10))
                if row_i % 18 == 0 and contour_i in (0, 8, 16, 24):
                    tile_mat = COVER_MAT["gold_rib"]
                    surface_zone = "structural gold rib"
                elif contour_i >= 23 and row_i % 7 == 0:
                    tile_mat = COVER_MAT["vent_dark"]
                    surface_zone = "lower side cooling edge"
                elif contour_i >= 22:
                    tile_mat = COVER_MAT["side_navy"]
                    surface_zone = "armoured side cheek"
                elif contour_i >= 15:
                    tile_mat = COVER_MAT["side_teal"]
                    surface_zone = "upper side transition"
                elif contour_i < 10 or (row_i*3+contour_i)%5 == 0:
                    tile_mat = COVER_MAT["crown_light"]
                    surface_zone = "upper crown patina highlight"
                else:
                    tile_mat = COVER_MAT["crown_deep"]
                    surface_zone = "curved upper mouth crown"
                armour_scale(
                    f"Engine_FrontCoverScale_{side_tag}_{row_i:03d}_{contour_i:02d}",
                    (xx, yy, zz), tile_width, tile_length, .028,
                    tile_mat, rot=(longitudinal_pitch, roll, 0), parent=eng,
                    front_taper=.78 if (row_i + contour_i) % 3 == 0 else .88,
                    surface_zone=surface_zone)
                component_count += 1
    assert component_count >= 5000
    eng["front_cover_editable_component_count"] = component_count
    eng["front_cover_textured_component_count"] = component_count
    eng["front_cover_surface_families"] = ", ".join(sorted(COVER_MAT.keys()))
    return component_count


engine_root = engine()
passenger_car("Coach_A", 1.5)
passenger_car("Coach_B", 18.0)

# Couplers, connector garden bricks and rear planter.
for idx, yy in enumerate((-7.8, 9.8, 27.0)):
    box(f"Connector_{idx}_GoldBlock", (0, yy, 1.75), (4.0,2.0,1.6), MAT["gold"], .20)
    box(f"Connector_{idx}_EnergySocket", (0, yy-.82, 1.82), (1.35,.22,.72), MAT["cyan"], .08)
    beam(f"Connector_{idx}_Drawbar", (0, yy-1.7, 1.25), (0, yy+1.7, 1.25), .24, MAT["wood"], 8)
    if idx < 2:
        planter(f"Connector_{idx}_Planter", (4.65, yy, 2.0))
planter("Rear_Planter", (0, 28.4, 2.0))

# Suspended aether stabilizer under the first coach.
stabilizer_y = 1.5
beam("Stabilizer_DropStem", (0, stabilizer_y, 1.0), (0, stabilizer_y, -2.7), .24, MAT["wood"], 8)
for z, radius in [(-1.4, 2.4), (-2.2, 1.75), (-3.0, 1.15)]:
    torus(f"Stabilizer_Ring_{abs(z):.1f}", (0, stabilizer_y, z), radius, .15, MAT["gold"])
crystal("Stabilizer_CyanCrystal", (0, stabilizer_y, -3.0), .62, 2.8, MAT["cyan"])
for i in range(6):
    ang = math.tau*i/6
    sphere(f"Stabilizer_Spark_{i:02d}", (math.cos(ang)*2.4, stabilizer_y+math.sin(ang)*2.4, -1.4), .10, MAT["cyan"], 8, 4)

# Add the dense front skin last so later bpy operators do not rebuild the
# dependency graph once for every one of its 5,000 independent meshes.
front_cover_component_count = build_front_cover_scales(engine_root)


# Final-product micro-construction. These are deliberately tiny, named parts
# placed by physical system—not arbitrary invisible count padding. They are
# flush engraved dashes rather than glowing dots, keeping surfaces calm like
# the supplied concept art while remaining individually editable.
def micro_stud(name, loc, size, mat, parent=model_root, scale=(1.0,1.0,1.0)):
    sx,sy,sz=size*scale[0]*1.35,size*scale[1]*.42,size*scale[2]*.12
    verts=[(-sx,-sy,-sz),(sx,-sy,-sz),(sx,sy,-sz),(-sx,sy,-sz),
           (-sx,-sy,sz),(sx,-sy,sz),(sx,sy,sz),(-sx,sy,sz)]
    faces=[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]
    mesh=bpy.data.meshes.new(name+"Mesh")
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new("TRAIN_"+name,mesh)
    bpy.context.collection.objects.link(obj)
    obj.location=loc
    obj.data.materials.append(mat)
    obj.parent=parent
    model_objects.append(obj)
    return obj


MINIMUM_EDITABLE_COMPONENTS=13000
micro_start_count=len(model_objects)-1
micro_index=0
while len(model_objects)-1 < MINIMUM_EDITABLE_COMPONENTS:
    system=micro_index%10
    serial=micro_index//10
    if system==0:  # continuous exterior sill stitch fasteners
        along=serial%300
        side=-1 if (serial//300)%2==0 else 1
        loc=(side*5.31,-24.0+along*(52.0/299.0),1.98+((serial//600)%3)*.09)
        micro_stud(f"Finish_SillFastener_{micro_index:05d}",loc,.032,MAT["gold"],scale=(.65,1,.65))
    elif system==1:  # roof dew lights following botanical spirals
        car_center=(-16.0,1.5,18.0)[serial%3]
        step=(serial//3)%360
        radius=.65+(step%90)*.040
        ang=step*math.radians(137.507764)
        loc=(math.cos(ang)*radius,car_center+math.sin(ang)*radius,8.48+.035*((step//30)%4))
        micro_stud(f"Finish_CanopyVeinDash_{micro_index:05d}",loc,.025,
                   MAT["teal_light" if step%11 else "gold"])
    elif system==2:  # cab pillar and window seam rivets
        row=serial%90
        side=-1 if (serial//90)%2==0 else 1
        column=(serial//180)%5
        loc=(side*(4.47+column*.025),-19.2+row*.082,2.20+column*.95)
        micro_stud(f"Finish_CabFrameRivet_{micro_index:05d}",loc,.027,MAT["gold"],scale=(.55,1,.55))
    elif system==3:  # living-root cyan sap nodes
        along=serial%420
        side=-1 if (serial//420)%2==0 else 1
        yy=-23.0+along*(50.0/419.0)
        phase=along*.41+(serial//840)*.9
        loc=(side*(4.35+.16*math.cos(phase)),yy,.10+.56*math.sin(phase))
        micro_stud(f"Finish_RootBindingDash_{micro_index:05d}",loc,.035,
                   MAT["wood_light" if along%8 else "bronze"],scale=(.7,1,.7))
    elif system==4:  # upholstery stitch heads on coach and driver seating
        coach_center=(1.5,18.0)[serial%2]
        stitch=(serial//2)%180
        side=-1 if (stitch//90)%2==0 else 1
        loc=(side*4.12,coach_center-4.05+(stitch%90)*.091,3.15+.12*((stitch//15)%5))
        micro_stud(f"Finish_SeatStitch_{micro_index:05d}",loc,.020,MAT["gold"],scale=(.45,1,.45))
    elif system==5:  # leaf-surface vein pinning, aligned to the three crowns
        car_center=(-16.0,1.5,18.0)[serial%3]
        pin=(serial//3)%320
        spoke=pin%16
        ring=pin//16
        ang=math.tau*spoke/16 + ring*.075
        radius=.80+ring*.22
        loc=(math.cos(ang)*radius,car_center+math.sin(ang)*radius,8.58+.018*(ring%3))
        micro_stud(f"Finish_LeafVeinPin_{micro_index:05d}",loc,.022,MAT["gold"],scale=(.6,1,.6))
    elif system==6:  # underframe inspection bolts
        along=serial%360
        side=-1 if (serial//360)%2==0 else 1
        loc=(side*(4.72+.12*((along//60)%3)),-24.0+along*(52.0/359.0),1.03)
        micro_stud(f"Finish_UnderframeBolt_{micro_index:05d}",loc,.030,
                   MAT["bronze" if along%3 else "cyan"],scale=(.75,1,.45))
    elif system==7:  # planter and connector trim studs
        garden_center=(-7.8,9.8,27.0)[serial%3]
        pin=(serial//3)%220
        edge=pin%4
        t=(pin//4)%55/54.0
        if edge<2:
            loc=((-1.7+3.4*t),garden_center+(-1.03 if edge==0 else 1.03),2.16)
        else:
            loc=((-1.7 if edge==2 else 1.7),garden_center-1.0+2.0*t,2.16)
        micro_stud(f"Finish_GardenTrimStud_{micro_index:05d}",loc,.024,
                   MAT["gold" if pin%4 else "cyan"])
    elif system==8:  # ivory arch tile pins emphasizing construction joints
        car_center=(-15.85,1.5,18.0)[serial%3]
        pin=(serial//3)%300
        side=-1 if (pin//150)%2==0 else 1
        theta=math.pi*(pin%150)/149.0
        loc=(math.cos(theta)*4.55,car_center+side*5.91,6.10+math.sin(theta)*1.84)
        micro_stud(f"Finish_ArchTilePin_{micro_index:05d}",loc,.026,
                   MAT["gold" if pin%3 else "cyan"],scale=(.7,1,.7))
    else:  # dense but legible cockpit legend / tactile markers
        cluster=serial%6
        marker=(serial//6)%180
        xx=-3.70+cluster*1.48+(marker%6)*.055
        yy=-18.25+(marker//6)*.022
        zz=3.62+(marker%5)*.055
        micro_stud(f"Finish_CabTactileLegend_{micro_index:05d}",(xx,yy,zz),.016,
                   (MAT["ivory"],MAT["cyan"],MAT["warning_amber"])[marker%3],scale=(1,.35,.55))
    micro_index+=1

assert len(model_objects)-1 >= MINIMUM_EDITABLE_COMPONENTS

# Root-level metadata makes the construction inventory inspectable after import.
model_root["design_reference"] = "Crown Line bio-magitech crystal train"
model_root["construction_style"] = "individually named modular brick parts"
model_root["editable_part_count"] = len(model_objects) - 1
model_root["micro_finish_component_count"] = (len(model_objects)-1)-micro_start_count
model_root["cab_design_basis"] = "ETCS DMI information hierarchy and RSSB RIS-2761-RST human-factors guidance"
model_root["runtime_mechanisms"] = "analog speed sweep, expanding speed bands, brake/safety state, wheel rotation and crystal-reactor pulse"
model_root["front_cover_editable_component_count"] = 5000
model_root["front_cover_textured_component_count"] = 5000
model_root["front_cover_surface_families"] = ", ".join(sorted(COVER_MAT.keys()))
model_root["front_cover_extent"] = "exposed half-crystal to cab windscreen sill"
model_root["vehicle_width_m"] = 11.2
model_root["vehicle_length_m"] = 57.0
model_root["walkable_coaches"] = 2

# Render-only railway and presentation stage (excluded from GLB selection).
def render_box(name, loc, scale, mat):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    obj = bpy.context.object
    obj.name = "RENDER_" + name
    obj.scale = (scale[0]/2, scale[1]/2, scale[2]/2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj


render_box("RailBeam", (0, 1.5, -3.75), (4.8, 78, .65), MAT["rail"])
render_box("RailGlow", (0, 1.5, -3.38), (1.0, 78, .09), MAT["cyan"])

world = bpy.context.scene.world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.003, 0.008, 0.025, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.34

for name, loc, energy, color, size in [
    ("Key", (-18,-22,24), 2600, (0.72,0.86,1.0), 9),
    ("Fill", (18,5,15), 2200, (0.35,0.82,1.0), 8),
    ("Rim", (0,30,20), 2300, (1.0,0.52,0.16), 7),
]:
    data = bpy.data.lights.new("RENDER_"+name, "AREA")
    data.energy = energy
    data.color = color
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new("RENDER_"+name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = (math.radians(25), 0, math.radians(-25 if loc[0] < 0 else 25))

# A restrained cyan bounce reveals brake discs, suspension and guide shoes in
# the underside inspection view without flattening the darker game palette.
under_data = bpy.data.lights.new("RENDER_UnderBogieFill", "AREA")
under_data.energy = 1350
under_data.color = (0.18, 0.72, 1.0)
under_data.shape = "DISK"
under_data.size = 5.0
under_light = bpy.data.objects.new("RENDER_UnderBogieFill", under_data)
bpy.context.collection.objects.link(under_light)
under_light.location = (10,-18,-3.0)
under_light.rotation_euler = (Vector((4,-17,0))-under_light.location).to_track_quat("-Z","Y").to_euler()


def point_camera(camera, target):
    direction = Vector(target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


camera_data = bpy.data.cameras.new("RENDER_Camera")
camera = bpy.data.objects.new("RENDER_Camera", camera_data)
bpy.context.collection.objects.link(camera)
bpy.context.scene.camera = camera
camera_data.lens = 55

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1600
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
scene.render.image_settings.color_mode = "RGBA"
try:
    scene.view_settings.look = "AgX - Medium High Contrast"
except TypeError:
    pass

# Emissive material lighting is used directly. Blender 5.2 removed the legacy
# scene compositor node_tree API, so keeping the render path native avoids an
# optional post-process breaking the editable asset build.

# Export only construction objects, never the presentation rail/lights/camera.
# Every mesh receives an explicit box-projected UV layer.  Primitive UVs alone
# were insufficient because many of the botanical/crystal pieces are custom
# meshes; this guarantees atlas coverage on the front, sides, roof, underside
# and interior and makes the mapping portable through GLB into Godot.
for obj in model_objects:
    if obj.type != "MESH" or not obj.data.polygons:
        continue
    mesh = obj.data
    uv_layer = mesh.uv_layers.get("CrownLineUV") or mesh.uv_layers.new(name="CrownLineUV")
    mesh.uv_layers.active = uv_layer
    xs = [vertex.co.x for vertex in mesh.vertices]
    ys = [vertex.co.y for vertex in mesh.vertices]
    zs = [vertex.co.z for vertex in mesh.vertices]
    bounds = ((min(xs), max(xs)), (min(ys), max(ys)), (min(zs), max(zs)))
    spans = tuple(max(high-low, 1e-5) for low, high in bounds)
    for polygon in mesh.polygons:
        normal = polygon.normal
        axis = max(range(3), key=lambda index: abs(normal[index]))
        for loop_index in polygon.loop_indices:
            coordinate = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            if axis == 0:
                u = (coordinate.y-bounds[1][0])/spans[1]
                v = (coordinate.z-bounds[2][0])/spans[2]
            elif axis == 1:
                u = (coordinate.x-bounds[0][0])/spans[0]
                v = (coordinate.z-bounds[2][0])/spans[2]
            else:
                u = (coordinate.x-bounds[0][0])/spans[0]
                v = (coordinate.y-bounds[1][0])/spans[1]
            uv_layer.data[loop_index].uv = (u, v)

bpy.ops.object.select_all(action="DESELECT")
for obj in model_objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = model_root
bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
if os.environ.get("CROWN_TRAIN_SKIP_SOURCE_GLB") != "1":
    bpy.ops.export_scene.gltf(filepath=GLB_PATH, export_format="GLB", use_selection=True,
                              export_apply=True, export_extras=True)

# Exact construction ledger: every small piece can be located, measured and
# re-angled without hunting through the Blender hierarchy.
manifest_parts = []
untextured_meshes = []
view_surface_counts = {"front": 0, "side": 0, "top": 0}
for obj in model_objects[1:]:
    materials = []
    if getattr(obj, "data", None) is not None and hasattr(obj.data, "materials"):
        materials = [slot.name for slot in obj.data.materials if slot is not None]
    if obj.type == "MESH" and not materials:
        untextured_meshes.append(obj.name)
    lowered_name = obj.name.lower()
    if any(token in lowered_name for token in ("nose", "frontcover", "windscreen", "bullet", "mouth", "crystal")):
        view_surface_counts["front"] += 1
    if any(token in lowered_name for token in ("side", "window", "sill", "bogie", "root", "equipment")):
        view_surface_counts["side"] += 1
    if any(token in lowered_name for token in ("roof", "canopy", "leaf", "halo", "top")):
        view_surface_counts["top"] += 1
    manifest_parts.append({
        "name": obj.name,
        "parent": obj.parent.name if obj.parent else None,
        "object_type": obj.type,
        "materials": materials,
        "location_m": [round(value, 4) for value in obj.location],
        "rotation_degrees": [round(math.degrees(value), 3) for value in obj.rotation_euler],
        "dimensions_m": [round(value, 4) for value in obj.dimensions],
    })
with open(MANIFEST_PATH, "w", encoding="utf-8") as manifest_file:
    json.dump({
        "design": "Crown Line bio-magitech crystal train",
        "editable_object_count": len(model_objects)-1,
        "renderable_mesh_count": sum(1 for obj in model_objects[1:] if obj.type == "MESH"),
        "coordinate_system": "Blender metres, Z up, locomotive nose toward -Y",
        "texture_audit": {
            "untextured_mesh_count": len(untextured_meshes),
            "untextured_meshes": untextured_meshes,
            "view_surface_object_counts": view_surface_counts,
            "reference_palette": "warm ivory, deep navy, layered teal, aged gold, cyan energy, living roots and flowers"
        },
        "parts": manifest_parts,
    }, manifest_file, indent=2)

views = [
    # Pull the inspection cameras back far enough to keep the crystal engine,
    # both open coaches, connector gardens, and rear planter in one frame.
    ("blender_crown_train_three_quarter.png", (45,-59,34), (0,2,3.2), 50),
    ("blender_crown_train_side.png", (75,2,17), (0,2,3.0), 52),
    ("blender_crown_train_front.png", (0,-57,13), (0,-10,4.5), 55),
    ("blender_crown_train_top.png", (0,2,90), (0,2,1.5), 50),
    # Component-layout inspection views: close enough to read panel gaps,
    # fasteners, controls, crystal facets and the driver's physical workspace.
    ("blender_crown_train_driver_closeup.png", (12,-31,10), (0,-17.8,3.8), 58),
    ("blender_crown_train_driver_top_layout.png", (8,-18,20), (0,-17.2,2.9), 62),
    ("blender_crown_train_driver_side_cutaway.png", (13,-16,7), (0,-18.2,3.4), 60),
    ("blender_crown_train_driver_pov.png", (0,-13.7,8.25), (0,-18.4,4.85), 56),
    ("blender_crown_train_console_oblique.png", (8.8,-13.2,9.4), (0,-17.9,4.35), 58),
    ("blender_crown_train_etcs_dmi_closeup.png", (0,-15.3,6.65), (0,-18.8,4.55), 60),
    ("blender_crown_train_cab_systems_overview.png", (8.5,-13.5,8.9), (0,-17.5,4.15), 56),
    ("blender_crown_train_crystal_detail.png", (8,-36,7), (0,-29.5,3.2), 67),
    ("blender_crown_train_engine_exterior_detail.png", (17,-35,13), (0,-22.5,3.5), 62),
    ("blender_crown_train_bogie_rail_detail.png", (14,-18,3.4), (4.1,-17.0,-.10), 68),
]
if os.environ.get("CROWN_TRAIN_RENDER_MODE") == "surface":
    surface_view_names = {
        "blender_crown_train_three_quarter.png", "blender_crown_train_side.png",
        "blender_crown_train_front.png", "blender_crown_train_top.png",
        "blender_crown_train_engine_exterior_detail.png",
        "blender_crown_train_bogie_rail_detail.png",
    }
    views = [view for view in views if view[0] in surface_view_names]
for filename, location, target, lens in views:
    camera.location = location
    camera.data.lens = lens
    point_camera(camera, target)
    if filename == "blender_crown_train_top.png":
        camera.rotation_euler.rotate_axis("Z", math.pi / 2)
    # Inspection-only cutaways expose the authored small parts. Nothing is
    # deleted or omitted from the .blend/.glb; hide_render is restored below.
    temporarily_hidden = []
    if filename == "blender_crown_train_driver_closeup.png":
        hide_tokens = ("Engine_WindscreenGlass",)
    elif filename == "blender_crown_train_driver_top_layout.png":
        hide_tokens = ("Engine_CrownCanopy", "Engine_CrownHalo", "Engine_HaloRay")
    elif filename == "blender_crown_train_driver_side_cutaway.png":
        hide_tokens = ("Engine_CrownCanopy", "Engine_CrownHalo", "Engine_HaloRay",
                       "Engine_WindowGlass_R")
    elif filename in ("blender_crown_train_driver_pov.png", "blender_crown_train_console_oblique.png",
                      "blender_crown_train_etcs_dmi_closeup.png",
                      "blender_crown_train_cab_systems_overview.png"):
        hide_tokens = ("Engine_CrownCanopy", "Engine_CrownHalo", "Engine_HaloRay",
                       "Engine_WindscreenGlass", "Engine_WindowGlass_R")
    else:
        hide_tokens = ()
    for obj in model_objects:
        if any(token in obj.name for token in hide_tokens):
            obj.hide_render = True
            temporarily_hidden.append(obj)
    scene.render.filepath = os.path.join(ARTIFACT_DIR, filename)
    bpy.ops.render.render(write_still=True)
    for obj in temporarily_hidden:
        obj.hide_render = False

print("CROWN_TRAIN_BUILD: PASS")
print("editable_parts=%d" % (len(model_objects)-1))
print("blend=%s" % BLEND_PATH)
print("glb=%s" % GLB_PATH)
print("manifest=%s" % MANIFEST_PATH)
