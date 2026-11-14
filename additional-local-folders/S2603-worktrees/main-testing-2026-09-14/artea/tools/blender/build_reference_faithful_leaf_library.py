"""Build all four reference-faithful leaf relief assets and a combined library.

Run with:
  blender --background --python tools/blender/build_reference_faithful_leaf_library.py
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

import bpy


PROJECT = Path(__file__).resolve().parents[2]
ROOT = PROJECT / "assets3D/tree_of_life/leaves/reference_faithful"
ARTIFACTS = PROJECT / "artifacts/tree_of_life_leaves/reference_faithful"
GRID_X = 181
GRID_Y = 111
RELIEF_DEPTH = 0.18


@dataclass(frozen=True)
class LeafSpec:
    slug: str
    display_name: str
    object_name: str
    texture_name: str
    width: float
    roughness: float
    metallic: float
    combined_y: float


LEAVES = (
    LeafSpec("living_leaf_fan", "Living Leaf Fan", "LivingLeafFanReferenceRelief", "living_leaf_fan_reference_rgba.png", 9.2, 0.52, 0.03, 6.2),
    LeafSpec("magic_rune_leaf", "Magic Rune Leaf", "MagicRuneLeafReferenceRelief", "magic_rune_leaf_reference_rgba.png", 8.6, 0.38, 0.07, 2.0),
    LeafSpec("solar_glass_science_leaf", "Solar-Glass Science Leaf", "SolarGlassScienceLeafReferenceRelief", "solar_glass_science_leaf_reference_rgba.png", 8.8, 0.22, 0.10, -2.2),
    LeafSpec("emerald_sensor_leaf", "Emerald Sensor Leaf", "EmeraldSensorLeafReferenceRelief", "emerald_sensor_leaf_reference_rgba.png", 5.1, 0.30, 0.12, -6.1),
)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(collection):
            if block.users == 0:
                collection.remove(block)


def sample(pixels, width: int, height: int, u: float, v: float):
    x = min(width - 1, max(0, round(u * (width - 1))))
    y = min(height - 1, max(0, round(v * (height - 1))))
    index = (y * width + x) * 4
    return pixels[index], pixels[index + 1], pixels[index + 2], pixels[index + 3]


def create_material(spec: LeafSpec, image: bpy.types.Image) -> bpy.types.Material:
    material = bpy.data.materials.new(f"{spec.object_name}Material")
    material.use_nodes = True
    material.use_backface_culling = False
    if hasattr(material, "surface_render_method"):
        material.surface_render_method = "DITHERED"
    elif hasattr(material, "blend_method"):
        material.blend_method = "BLEND"

    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (450, 0)
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    shader.location = (120, 0)
    shader.inputs["Roughness"].default_value = spec.roughness
    shader.inputs["Metallic"].default_value = spec.metallic
    texture = nodes.new("ShaderNodeTexImage")
    texture.location = (-260, 20)
    texture.image = image
    texture.extension = "CLIP"
    texture.interpolation = "Linear"
    links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    links.new(texture.outputs["Alpha"], shader.inputs["Alpha"])
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    return material


def create_leaf(spec: LeafSpec) -> bpy.types.Object:
    texture_path = ROOT / "textures" / spec.texture_name
    image = bpy.data.images.load(str(texture_path), check_existing=True)
    image.colorspace_settings.name = "sRGB"
    image_width, image_height = image.size
    height = spec.width * image_height / image_width
    pixels = list(image.pixels[:])

    vertices = []
    coordinates = []
    for row in range(GRID_Y):
        v = row / (GRID_Y - 1)
        for column in range(GRID_X):
            u = column / (GRID_X - 1)
            r, g, b, alpha = sample(pixels, image_width, image_height, u, v)
            luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
            z = alpha * (0.035 + RELIEF_DEPTH * (0.20 + 0.80 * luminance))
            vertices.append(((u - 0.5) * spec.width, (v - 0.5) * height, z))
            coordinates.append((u, v))

    faces = []
    for row in range(GRID_Y - 1):
        for column in range(GRID_X - 1):
            a = row * GRID_X + column
            faces.append((a, a + 1, a + GRID_X + 1, a + GRID_X))

    mesh = bpy.data.meshes.new(f"{spec.object_name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon in mesh.polygons:
        polygon.use_smooth = True
        for loop_index in polygon.loop_indices:
            uv_layer.data[loop_index].uv = coordinates[mesh.loops[loop_index].vertex_index]

    leaf = bpy.data.objects.new(spec.object_name, mesh)
    bpy.context.collection.objects.link(leaf)
    leaf.data.materials.append(create_material(spec, image))
    leaf["asset_name"] = spec.display_name
    leaf["construction"] = "reference-faithful 2.5D relief"
    leaf["detail_points"] = len(vertices)
    leaf["reference_texture"] = spec.texture_name
    return leaf


def add_presentation_camera(ortho_scale: float, resolution_x: int, resolution_y: int) -> None:
    world = bpy.context.scene.world or bpy.data.worlds.new("ReferenceFaithfulLeafWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.002, 0.010, 0.025, 1.0)
    background.inputs["Strength"].default_value = 0.22

    camera_data = bpy.data.cameras.new("ReferenceFaithfulCamera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = ortho_scale
    camera = bpy.data.objects.new("ReferenceFaithfulCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (0.0, 0.0, 12.0)
    bpy.context.scene.camera = camera

    key_data = bpy.data.lights.new("ReferenceFaithfulKey", "AREA")
    key_data.energy = 580
    key_data.size = 7.0
    key = bpy.data.objects.new("ReferenceFaithfulKey", key_data)
    bpy.context.collection.objects.link(key)
    key.location = (-3.0, 3.0, 6.0)

    fill_data = bpy.data.lights.new("ReferenceFaithfulFill", "AREA")
    fill_data.energy = 240
    fill_data.color = (0.28, 0.62, 1.0)
    fill_data.size = 6.0
    fill = bpy.data.objects.new("ReferenceFaithfulFill", fill_data)
    bpy.context.collection.objects.link(fill)
    fill.location = (3.0, -2.0, 5.0)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = resolution_x
    scene.render.resolution_y = resolution_y
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"


def export_selected(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_materials="EXPORT",
        export_yup=True,
    )


def build_individual(spec: LeafSpec) -> dict:
    clear_scene()
    leaf = create_leaf(spec)
    add_presentation_camera(max(spec.width * 1.12, 6.0), 1400, 1000)
    source_path = ROOT / "source" / f"{spec.slug}_reference_faithful.blend"
    glb_path = ROOT / "glb" / f"{spec.slug}_reference_faithful.glb"
    preview_path = ARTIFACTS / f"{spec.slug}.png"
    source_path.parent.mkdir(parents=True, exist_ok=True)
    preview_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(source_path))
    bpy.ops.object.select_all(action="DESELECT")
    leaf.select_set(True)
    bpy.context.view_layer.objects.active = leaf
    export_selected(glb_path)
    bpy.context.scene.render.filepath = str(preview_path)
    bpy.ops.render.render(write_still=True)
    return {
        "name": spec.display_name,
        "object": spec.object_name,
        "vertices": len(leaf.data.vertices),
        "faces": len(leaf.data.polygons),
        "texture": str((ROOT / "textures" / spec.texture_name).relative_to(PROJECT)),
        "blend": str(source_path.relative_to(PROJECT)),
        "glb": str(glb_path.relative_to(PROJECT)),
        "preview": str(preview_path.relative_to(PROJECT)),
    }


def build_combined() -> dict:
    clear_scene()
    leaves = []
    for spec in LEAVES:
        leaf = create_leaf(spec)
        leaf.location.y = spec.combined_y
        leaves.append(leaf)
    add_presentation_camera(18.0, 1100, 1700)

    blend_path = ROOT / "source/reference_faithful_leaf_library.blend"
    glb_path = ROOT / "glb/reference_faithful_leaf_library.glb"
    preview_path = ARTIFACTS / "reference_faithful_leaf_library.png"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    bpy.ops.object.select_all(action="DESELECT")
    for leaf in leaves:
        leaf.select_set(True)
    bpy.context.view_layer.objects.active = leaves[0]
    export_selected(glb_path)
    bpy.context.scene.render.filepath = str(preview_path)
    bpy.ops.render.render(write_still=True)
    return {
        "blend": str(blend_path.relative_to(PROJECT)),
        "glb": str(glb_path.relative_to(PROJECT)),
        "preview": str(preview_path.relative_to(PROJECT)),
        "objects": [leaf.name for leaf in leaves],
        "total_vertices": sum(len(leaf.data.vertices) for leaf in leaves),
    }


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    individual = {spec.slug: build_individual(spec) for spec in LEAVES}
    combined = build_combined()
    manifest = {
        "asset": "Reference-Faithful Leaf Library",
        "method": "four dense 2.5D relief meshes with generated RGBA reference albedos",
        "grid_per_leaf": [GRID_X, GRID_Y],
        "minimum_detail_points_per_leaf": GRID_X * GRID_Y,
        "leaves": individual,
        "combined": combined,
        "collision_included": False,
    }
    manifest_path = ROOT / "reference_faithful_leaf_library.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
