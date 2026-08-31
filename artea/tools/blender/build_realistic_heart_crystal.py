"""Author the production Tree-of-Life heart crystal in Blender.

The asset is deliberately separate from the trunk GLB so Godot can rotate the
gem without rotating its fixed gold setting. It uses real closed geometry,
front/rear cut planes, a thick girdle, alternating sapphire facets and an
internal luminous diamond core.
"""

import json
import math
import os

import bpy
from mathutils import Vector


PROJECT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSET_ROOT = os.path.join(PROJECT, "assets3D", "tree_of_life", "heart_crystal")
SOURCE_PATH = os.path.join(ASSET_ROOT, "source", "realistic_heart_crystal.blend")
GLB_PATH = os.path.join(ASSET_ROOT, "glb", "realistic_heart_crystal.glb")
RENDER_PATH = os.path.join(ASSET_ROOT, "renders", "realistic_heart_crystal.png")
MANIFEST_PATH = os.path.join(ASSET_ROOT, "realistic_heart_crystal_manifest.json")

WIDTH = 16.13
HEIGHT = 26.0
DEPTH = 5.18


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for blocks in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras,
                   bpy.data.lights, bpy.data.curves):
        for block in list(blocks):
            if block.users == 0:
                blocks.remove(block)


def material(name, colour, metallic, roughness, emission=None,
             emission_strength=0.0, transmission=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*colour[:3], alpha)
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*colour[:3], 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    transmission_input = shader.inputs.get("Transmission Weight") or shader.inputs.get("Transmission")
    if transmission_input is not None:
        transmission_input.default_value = transmission
    ior_input = shader.inputs.get("IOR")
    if ior_input is not None:
        ior_input.default_value = 1.46
    if emission is not None:
        emission_input = shader.inputs.get("Emission Color") or shader.inputs.get("Emission")
        strength_input = shader.inputs.get("Emission Strength")
        if emission_input is not None:
            emission_input.default_value = (*emission[:3], 1.0)
        if strength_input is not None:
            strength_input.default_value = emission_strength
    if alpha < 1.0:
        shader.inputs["Alpha"].default_value = alpha
        mat.surface_render_method = "DITHERED"
        mat.use_transparency_overlap = False
    return mat


def heart_outline():
    half = WIDTH * 0.5
    return [
        (0.0, HEIGHT * 0.43),
        (-half * 0.30, HEIGHT * 0.50),
        (-half * 0.78, HEIGHT * 0.44),
        (-half, HEIGHT * 0.20),
        (-half * 0.86, -HEIGHT * 0.08),
        (-half * 0.48, -HEIGHT * 0.31),
        (0.0, -HEIGHT * 0.56),
        (half * 0.48, -HEIGHT * 0.31),
        (half * 0.86, -HEIGHT * 0.08),
        (half, HEIGHT * 0.20),
        (half * 0.78, HEIGHT * 0.44),
        (half * 0.30, HEIGHT * 0.50),
    ]


def build_shell(materials):
    outline = heart_outline()
    front_apex = 0
    rear_apex = 1
    vertices = [(0.0, -DEPTH * 0.52, -HEIGHT * 0.01),
                (0.0, DEPTH * 0.52, -HEIGHT * 0.01)]
    front_ring = []
    rear_ring = []
    for x, z in outline:
        front_ring.append(len(vertices))
        vertices.append((x, -DEPTH * 0.18, z))
        rear_ring.append(len(vertices))
        vertices.append((x, DEPTH * 0.18, z))

    faces = []
    face_materials = []
    count = len(outline)
    for index in range(count):
        nxt = (index + 1) % count
        faces.append((front_apex, front_ring[index], front_ring[nxt]))
        face_materials.append(index % 4)
        faces.append((rear_apex, rear_ring[nxt], rear_ring[index]))
        face_materials.append((index + 2) % 4)
        faces.append((front_ring[index], rear_ring[index], rear_ring[nxt], front_ring[nxt]))
        face_materials.append(4 + index % 2)

    mesh = bpy.data.meshes.new("RealisticHeartDiamondShellMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.clear()
    for mat in materials:
        mesh.materials.append(mat)
    for polygon, material_index in zip(mesh.polygons, face_materials):
        polygon.material_index = material_index
        polygon.use_smooth = False
    mesh.update()
    obj = bpy.data.objects.new("RealisticHeartDiamondShell", mesh)
    bpy.context.collection.objects.link(obj)
    obj["crystal_shape"] = "blender_cut_heart_diamond"
    obj["triangular_shell_facets"] = 24
    obj["girdle_facets"] = 12
    obj["closed_manifold"] = True
    obj["runtime_role"] = "rotating_outer_crystal"
    bevel = obj.modifiers.new("MicroBevelCutEdges", "BEVEL")
    bevel.width = 0.055
    bevel.segments = 2
    bevel.affect = "EDGES"
    return obj


def build_inner_core(materials):
    radius_x = WIDTH * 0.22
    radius_z = HEIGHT * 0.30
    radius_y = DEPTH * 0.30
    vertices = [
        (0, 0, radius_z), (0, 0, -radius_z),
        (radius_x, 0, 0), (-radius_x, 0, 0),
        (0, radius_y, 0), (0, -radius_y, 0),
    ]
    faces = [
        (0, 4, 2), (0, 3, 4), (0, 5, 3), (0, 2, 5),
        (1, 2, 4), (1, 4, 3), (1, 3, 5), (1, 5, 2),
    ]
    mesh = bpy.data.meshes.new("LuminousInnerDiamondCoreMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(materials[0])
    mesh.materials.append(materials[1])
    for index, polygon in enumerate(mesh.polygons):
        polygon.material_index = index % 2
    mesh.update()
    obj = bpy.data.objects.new("LuminousInnerDiamondCore", mesh)
    bpy.context.collection.objects.link(obj)
    obj["internal_refraction_core"] = True
    obj["facets"] = 8
    return obj


def build_inclusions(materials):
    objects = []
    # Six narrow internal shards add believable depth as the shell rotates.
    for index in range(6):
        angle = math.tau * index / 6.0
        radius = WIDTH * (0.10 + 0.025 * (index % 2))
        x = math.cos(angle) * radius
        z = math.sin(angle) * HEIGHT * 0.12
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0,
                                             location=(x, 0.0, z))
        shard = bpy.context.object
        shard.name = f"InternalCrystalInclusion_{index + 1:02d}"
        shard.scale = (0.34, 0.16, 1.15 + 0.15 * (index % 3))
        shard.rotation_euler[1] = angle * 0.35
        shard.data.materials.append(materials[index % len(materials)])
        shard["internal_inclusion"] = True
        objects.append(shard)
    return objects


def aim_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def setup_render(asset_objects):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 960
    scene.render.resolution_y = 1120
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.003, 0.008, 0.025)

    bpy.ops.object.camera_add(location=(0.0, -52.0, 1.2))
    camera = bpy.context.object
    camera.name = "CrystalPreviewCamera"
    camera.data.lens = 66
    aim_at(camera, (0.0, 0.0, 0.0))
    scene.camera = camera

    for name, location, colour, energy, size in [
        ("SapphireKey", (-14.0, -18.0, 18.0), (0.35, 0.68, 1.0), 1600.0, 8.0),
        ("CoolRim", (15.0, 3.0, 8.0), (0.15, 0.75, 1.0), 1300.0, 7.0),
        ("VioletFill", (-8.0, 5.0, -10.0), (0.45, 0.22, 1.0), 900.0, 6.0),
    ]:
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.name = name
        light.data.color = colour
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size
        aim_at(light, (0.0, 0.0, 0.0))

    scene.render.filepath = RENDER_PATH
    bpy.ops.render.render(write_still=True)
    # Restore selection for GLB export; camera and lights are intentionally out.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in asset_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = asset_objects[0]


def main():
    for directory in (os.path.dirname(SOURCE_PATH), os.path.dirname(GLB_PATH),
                      os.path.dirname(RENDER_PATH)):
        os.makedirs(directory, exist_ok=True)
    reset_scene()

    shell_materials = [
        material("CrystalFacet_SapphireDeep", (0.018, 0.10, 0.50), 0.08, 0.08,
                 (0.01, 0.10, 0.58), 0.30, 0.05, 0.98),
        material("CrystalFacet_Sapphire", (0.035, 0.32, 0.92), 0.06, 0.055,
                 (0.02, 0.28, 0.92), 0.55, 0.06, 0.98),
        material("CrystalFacet_Azure", (0.05, 0.42, 0.92), 0.04, 0.045,
                 (0.04, 0.38, 0.88), 0.45, 0.07, 0.98),
        material("CrystalFacet_VioletBlue", (0.18, 0.16, 0.82), 0.06, 0.065,
                 (0.18, 0.08, 0.78), 0.38, 0.05, 0.98),
        material("CrystalGirdle_Dark", (0.015, 0.08, 0.30), 0.12, 0.10,
                 (0.01, 0.09, 0.34), 0.18, 0.02, 1.0),
        material("CrystalGirdle_Bright", (0.05, 0.30, 0.72), 0.08, 0.08,
                 (0.03, 0.30, 0.72), 0.30, 0.03, 1.0),
    ]
    core_materials = [
        material("CrystalCore_Ice", (0.42, 0.88, 1.0), 0.0, 0.035,
                 (0.34, 0.86, 1.0), 3.2, 0.20, 0.78),
        material("CrystalCore_Violet", (0.46, 0.18, 1.0), 0.0, 0.05,
                 (0.50, 0.12, 1.0), 2.8, 0.18, 0.80),
    ]
    inclusion_materials = [
        material("Inclusion_Ice", (0.65, 0.95, 1.0), 0.0, 0.02,
                 (0.35, 0.90, 1.0), 1.4, 0.20, 0.62),
        material("Inclusion_Violet", (0.62, 0.30, 1.0), 0.0, 0.04,
                 (0.45, 0.18, 1.0), 1.2, 0.18, 0.64),
    ]

    shell = build_shell(shell_materials)
    core = build_inner_core(core_materials)
    inclusions = build_inclusions(inclusion_materials)
    asset_objects = [shell, core] + inclusions
    for obj in asset_objects:
        obj["asset"] = "tree_of_life_realistic_heart_crystal"
        obj["blender_authored"] = True

    setup_render(asset_objects)
    bpy.ops.wm.save_as_mainfile(filepath=SOURCE_PATH)
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        use_selection=True,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_extras=True,
    )

    triangles = sum(len(obj.data.loop_triangles) for obj in asset_objects
                    if obj.type == "MESH")
    manifest = {
        "asset": "tree_of_life_realistic_heart_crystal",
        "version": 1,
        "source_blend": "assets3D/tree_of_life/heart_crystal/source/realistic_heart_crystal.blend",
        "runtime_glb": "assets3D/tree_of_life/heart_crystal/glb/realistic_heart_crystal.glb",
        "preview": "assets3D/tree_of_life/heart_crystal/renders/realistic_heart_crystal.png",
        "dimensions_metres": {"width": WIDTH, "height": HEIGHT, "depth": DEPTH},
        "outer_triangular_facets": 24,
        "girdle_facets": 12,
        "internal_core_facets": 8,
        "internal_inclusions": 6,
        "mesh_objects": len(asset_objects),
        "triangles": triangles,
        "runtime_animation": "Godot rotates complete Blender asset about local Y",
    }
    with open(MANIFEST_PATH, "w", encoding="utf-8") as stream:
        json.dump(manifest, stream, indent=2)
        stream.write("\n")
    print("REALISTIC_HEART_CRYSTAL: PASS", json.dumps(manifest, sort_keys=True))


if __name__ == "__main__":
    main()
