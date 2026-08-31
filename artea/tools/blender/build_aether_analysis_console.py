import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def material(name, colour, metallic, roughness, emission=None):
    value = bpy.data.materials.new(name)
    value.diffuse_color = (*colour, 1.0)
    value.use_nodes = True
    shader = value.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*colour, 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    if emission:
        shader.inputs["Emission Color"].default_value = (*emission, 1.0)
        shader.inputs["Emission Strength"].default_value = 2.8
    return value


def finish(obj, mat, parent, bevel=0.06):
    obj.data.materials.append(mat)
    obj.parent = parent
    for face in obj.data.polygons:
        face.use_smooth = True
    if bevel:
        mod = obj.modifiers.new("ArchitecturalEdge", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    tri = obj.modifiers.new("GameTriangulation", "TRIANGULATE")
    tri.keep_custom_normals = True
    return obj


def cylinder(name, radius, depth, z, mat, parent, vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=(0, 0, z))
    obj = bpy.context.object
    obj.name = name
    return finish(obj, mat, parent)


def torus(name, major, minor, location, rotation, mat, parent):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major, minor_radius=minor, major_segments=40, minor_segments=10,
        location=location, rotation=rotation
    )
    obj = bpy.context.object
    obj.name = name
    return finish(obj, mat, parent, 0.025)


def cube(name, location, scale, mat, parent, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, mat, parent, min(scale) * 0.16)


def main():
    if "--" not in sys.argv or len(sys.argv[sys.argv.index("--") + 1:]) != 2:
        raise SystemExit("Expected OUTPUT.glb PREVIEW.png")
    output, preview = [Path(v).resolve() for v in sys.argv[sys.argv.index("--") + 1:]]
    output.parent.mkdir(parents=True, exist_ok=True)
    preview.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)

    ivory = material("SanctumIvory", (0.92, 0.84, 0.68), 0.16, 0.38)
    brass = material("AstralBrass", (0.70, 0.44, 0.12), 0.88, 0.22)
    teal = material("AetherTeal", (0.15, 0.62, 0.62), 0.32, 0.20, (0.18, 0.78, 0.80))
    lavender = material("InsightLavender", (0.48, 0.31, 0.72), 0.18, 0.30, (0.58, 0.38, 0.88))
    gold = material("WisdomGold", (0.93, 0.66, 0.20), 0.78, 0.18, (1.0, 0.65, 0.16))

    root = bpy.data.objects.new("AetherAnalysisConsole", None)
    bpy.context.collection.objects.link(root)
    cylinder("ConsoleFoundation", 2.35, 0.45, 0.225, ivory, root, 40)
    cylinder("ConsoleGiltDrum", 1.92, 0.42, 0.65, brass, root, 40)
    cylinder("ConsoleIvoryCrown", 1.62, 0.30, 1.00, ivory, root, 40)
    torus("ConsoleBoundary", 1.74, 0.12, (0, 0, 1.15), (0, 0, 0), gold, root)

    rotor = bpy.data.objects.new("AnalysisRotor", None)
    bpy.context.collection.objects.link(rotor)
    rotor.parent = root
    rotor.location = (0, 0, 2.35)
    torus("AnalysisMeridianA", 1.05, 0.07, (0, 0, 0), (math.pi / 2, 0, 0), brass, rotor)
    torus("AnalysisMeridianB", 0.86, 0.055, (0, 0, 0), (0, math.pi / 2, math.pi / 5), teal, rotor)
    torus("AnalysisMeridianC", 0.68, 0.045, (0, 0, 0), (math.pi / 3, 0, math.pi / 2), lavender, rotor)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=0.48, location=(0, 0, 0))
    core = bpy.context.object
    core.name = "AnalysisHeartLens"
    finish(core, teal, rotor, 0)

    for index, (angle, mat) in enumerate(((0, teal), (2 * math.pi / 3, lavender), (4 * math.pi / 3, gold))):
        x, y = math.sin(angle) * 1.38, math.cos(angle) * 1.38
        socket = cylinder(f"EvidenceSocket_{index + 1}", 0.28, 0.34, 1.34, brass, root, 20)
        socket.location.x = x
        socket.location.y = y
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.18, location=(x, y, 1.62))
        lamp = bpy.context.object
        lamp.name = f"EvidenceLamp_{index + 1}"
        finish(lamp, mat, root, 0)

    for index in range(12):
        angle = 2 * math.pi * index / 12
        cube(
            f"ReasoningTooth_{index + 1:02d}",
            (math.sin(angle) * 1.86, math.cos(angle) * 1.86, 1.07),
            (0.13, 0.25, 0.12), brass, root, (0, 0, -angle)
        )

    bpy.ops.export_scene.gltf(
        filepath=str(output), export_format="GLB", export_animations=False,
        export_apply=False, export_yup=True
    )

    bpy.ops.object.camera_add(location=(5.4, -6.8, 4.8))
    camera = bpy.context.object
    camera.data.lens = 58
    camera.rotation_euler = (Vector((0, 0, 1.35)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera
    bpy.ops.object.light_add(type="AREA", location=(4, -4, 7))
    bpy.context.object.data.energy = 1100
    bpy.context.object.data.size = 5
    bpy.ops.object.light_add(type="AREA", location=(-4, -2, 3))
    bpy.context.object.data.energy = 650
    bpy.context.object.data.color = (0.25, 0.72, 0.82)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(preview)
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.render.render(write_still=True)
    print(f"AETHER_ANALYSIS_CONSOLE: PASS -> {output}")


if __name__ == "__main__":
    main()
