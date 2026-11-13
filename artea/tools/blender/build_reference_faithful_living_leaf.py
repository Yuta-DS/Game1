"""Build a reference-faithful, textured 2.5D Living Leaf Fan asset.

Run with:
  blender --background --python tools/blender/build_reference_faithful_living_leaf.py
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import bpy


PROJECT = Path(__file__).resolve().parents[2]
ASSET_ROOT = PROJECT / "assets3D/tree_of_life/leaves/reference_faithful"
TEXTURE_PATH = ASSET_ROOT / "textures/living_leaf_fan_reference_rgba.png"
BLEND_PATH = ASSET_ROOT / "source/living_leaf_fan_reference_faithful.blend"
GLB_PATH = ASSET_ROOT / "glb/living_leaf_fan_reference_faithful.glb"
MANIFEST_PATH = ASSET_ROOT / "living_leaf_fan_reference_faithful.json"
PREVIEW_PATH = PROJECT / "artifacts/tree_of_life_leaves/living_leaf_fan_reference_faithful.png"

# 181 x 111 = 20,091 independently controllable surface points.
GRID_X = 181
GRID_Y = 111
MODEL_WIDTH = 9.2
RELIEF_DEPTH = 0.18


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def srgb_luminance(r: float, g: float, b: float) -> float:
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def sample_rgba(pixels: list[float], image_width: int, image_height: int, u: float, v: float):
    px = min(image_width - 1, max(0, round(u * (image_width - 1))))
    py = min(image_height - 1, max(0, round(v * (image_height - 1))))
    index = (py * image_width + px) * 4
    return pixels[index], pixels[index + 1], pixels[index + 2], pixels[index + 3]


def create_relief(image: bpy.types.Image) -> bpy.types.Object:
    image_width, image_height = image.size
    aspect = image_height / image_width
    model_height = MODEL_WIDTH * aspect
    pixels = list(image.pixels[:])

    vertices = []
    uvs = []
    for row in range(GRID_Y):
        v = row / (GRID_Y - 1)
        for column in range(GRID_X):
            u = column / (GRID_X - 1)
            r, g, b, alpha = sample_rgba(pixels, image_width, image_height, u, v)
            luminance = srgb_luminance(r, g, b)
            # The painted highlights and veins gently lift from the leaf surface.
            # Transparent pixels remain at zero, so invisible background never affects relief.
            z = alpha * (0.035 + RELIEF_DEPTH * (0.22 + 0.78 * luminance))
            x = (u - 0.5) * MODEL_WIDTH
            y = (v - 0.5) * model_height
            vertices.append((x, y, z))
            uvs.append((u, v))

    faces = []
    for row in range(GRID_Y - 1):
        for column in range(GRID_X - 1):
            a = row * GRID_X + column
            b = a + 1
            d = (row + 1) * GRID_X + column
            c = d + 1
            faces.append((a, b, c, d))

    mesh = bpy.data.meshes.new("LivingLeafFanReferenceReliefMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()

    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon in mesh.polygons:
        for loop_index in polygon.loop_indices:
            vertex_index = mesh.loops[loop_index].vertex_index
            uv_layer.data[loop_index].uv = uvs[vertex_index]

    obj = bpy.data.objects.new("LivingLeafFanReferenceRelief", mesh)
    bpy.context.collection.objects.link(obj)
    obj["asset_name"] = "Living Leaf Fan"
    obj["construction"] = "reference-faithful 2.5D relief"
    obj["detail_points"] = len(vertices)
    obj["reference_texture"] = TEXTURE_PATH.name

    for polygon in mesh.polygons:
        polygon.use_smooth = True
    return obj


def create_material(image: bpy.types.Image) -> bpy.types.Material:
    material = bpy.data.materials.new("LivingLeafFanReferenceMaterial")
    material.use_nodes = True
    material.diffuse_color = (0.32, 0.45, 0.17, 1.0)
    material.use_backface_culling = False
    if hasattr(material, "surface_render_method"):
        material.surface_render_method = "DITHERED"
    elif hasattr(material, "blend_method"):
        material.blend_method = "BLEND"

    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (460, 0)
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    principled.location = (130, 0)
    principled.inputs["Roughness"].default_value = 0.52
    principled.inputs["Metallic"].default_value = 0.03
    principled.inputs["Alpha"].default_value = 1.0

    texture = nodes.new("ShaderNodeTexImage")
    texture.location = (-260, 40)
    texture.image = image
    texture.extension = "CLIP"
    texture.interpolation = "Linear"

    links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    links.new(texture.outputs["Alpha"], principled.inputs["Alpha"])
    links.new(principled.outputs["BSDF"], output.inputs["Surface"])
    return material


def create_preview_scene(leaf: bpy.types.Object, model_height: float) -> None:
    world = bpy.context.scene.world or bpy.data.worlds.new("LivingLeafWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.003, 0.012, 0.028, 1.0)
    background.inputs["Strength"].default_value = 0.18

    camera_data = bpy.data.cameras.new("LivingLeafPreviewCamera")
    camera = bpy.data.objects.new("LivingLeafPreviewCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (0, 0, 11.5)
    camera.rotation_euler = (0, 0, 0)
    camera.rotation_euler[0] = 0
    camera.rotation_euler[1] = 0
    camera.rotation_euler[2] = 0
    # Cameras look along local -Z by default.
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = max(MODEL_WIDTH * 1.08, model_height * 1.18)
    bpy.context.scene.camera = camera

    key_data = bpy.data.lights.new("SoftKey", type="AREA")
    key_data.energy = 650
    key_data.shape = "DISK"
    key_data.size = 7.0
    key = bpy.data.objects.new("SoftKey", key_data)
    bpy.context.collection.objects.link(key)
    key.location = (-2.5, 2.5, 6.0)

    fill_data = bpy.data.lights.new("CoolFill", type="AREA")
    fill_data.energy = 300
    fill_data.color = (0.35, 0.65, 1.0)
    fill_data.size = 6.0
    fill = bpy.data.objects.new("CoolFill", fill_data)
    bpy.context.collection.objects.link(fill)
    fill.location = (3.5, -2.0, 4.0)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW_PATH)
    scene.render.film_transparent = False
    scene.render.image_settings.color_mode = "RGBA"


def export_asset(leaf: bpy.types.Object) -> None:
    for path in (BLEND_PATH.parent, GLB_PATH.parent, PREVIEW_PATH.parent):
        path.mkdir(parents=True, exist_ok=True)

    bpy.context.view_layer.objects.active = leaf
    leaf.select_set(True)

    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))

    # Export only the textured relief; camera and preview lights stay in the .blend file.
    bpy.ops.object.select_all(action="DESELECT")
    leaf.select_set(True)
    bpy.context.view_layer.objects.active = leaf
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        use_selection=True,
        export_materials="EXPORT",
        export_yup=True,
    )

    bpy.context.scene.render.filepath = str(PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)


def main() -> None:
    clear_scene()
    image = bpy.data.images.load(str(TEXTURE_PATH), check_existing=True)
    image.colorspace_settings.name = "sRGB"
    leaf = create_relief(image)
    leaf.data.materials.append(create_material(image))

    image_width, image_height = image.size
    model_height = MODEL_WIDTH * image_height / image_width
    create_preview_scene(leaf, model_height)
    export_asset(leaf)

    manifest = {
        "asset": "Living Leaf Fan — Reference Faithful",
        "method": "dense 2.5D relief with RGBA reference albedo",
        "vertex_count": len(leaf.data.vertices),
        "face_count": len(leaf.data.polygons),
        "grid": [GRID_X, GRID_Y],
        "texture": str(TEXTURE_PATH.relative_to(PROJECT)),
        "blend": str(BLEND_PATH.relative_to(PROJECT)),
        "glb": str(GLB_PATH.relative_to(PROJECT)),
        "preview": str(PREVIEW_PATH.relative_to(PROJECT)),
        "notes": [
            "Transparent pixels are retained only as an invisible support grid.",
            "Leaflets, branch veins, highlights, outline, and brass connector are baked into the supplied RGBA albedo.",
            "Luminance-driven displacement adds shallow physical relief without changing the reference silhouette.",
        ],
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
