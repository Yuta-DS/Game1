"""Apply the Torch Spark PBR texture set and export the editable game asset.

Run with Blender, not the system Python interpreter.
"""

from __future__ import annotations

import json
from pathlib import Path

import bpy


PROJECT = Path("/Users/davidsovann/S2603/artea")
TEXTURE_DIR = PROJECT / "assets/textures/mind_spark/quest_objects/torch_spark_socket"
MANIFEST = TEXTURE_DIR / "texture_manifest.json"
INPUT_GLB = Path("/private/tmp/thought_spark_socket_pretexture.glb")
OUTPUT_GLB = PROJECT / "assets3D/mind_spark/quest_objects/glb/thought_spark_socket.glb"
OUTPUT_BLEND = Path("/Users/davidsovann/GAME/Crystal_Star_Pedestal/crystal_star_pedestal_textured_master.blend")

EMISSION_STRENGTH = {
    "Cyan_Energy": 1.25,
    "Violet_Energy": 1.35,
    "White_Star_Glow": 1.8,
    "Blue_Crystal": 0.12,
    "Blue_Crystal_Outline": 0.4,
    "Lavender_Crystal": 0.16,
    "Crown_Crystal": 0.18,
    "Violet_Crystal_Outline": 0.45,
    "Orb_Glass": 0.08,
}

CRYSTAL_SETTINGS = {
    "Blue_Crystal": (0.08, 0.98),
    "Lavender_Crystal": (0.10, 0.97),
    "Crown_Crystal": (0.12, 0.98),
    "Orb_Glass": (0.35, 0.78),
}

METALLIC = {
    "Stone_Dark": 0.18,
    "Stone_Mid": 0.24,
    "Stone_Edge": 0.55,
    "Gunmetal": 0.88,
    "Silver_Edge": 0.92,
}


def load_image(path: Path, non_color: bool = False) -> bpy.types.Image:
    image = bpy.data.images.load(str(path), check_existing=True)
    image.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    return image


def texture_node(nodes: bpy.types.Nodes, name: str, image: bpy.types.Image) -> bpy.types.ShaderNodeTexImage:
    node = nodes.new("ShaderNodeTexImage")
    node.name = name
    node.label = name
    node.image = image
    node.interpolation = "Linear"
    node.extension = "REPEAT"
    return node


def apply_material(material_name: str, surface_name: str) -> None:
    material = bpy.data.materials.get(material_name)
    if material is None:
        raise RuntimeError(f"Missing material {material_name}")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    for node in list(nodes):
        if node.type != "OUTPUT_MATERIAL":
            nodes.remove(node)
    output = next((node for node in nodes if node.type == "OUTPUT_MATERIAL"), None)
    if output is None:
        output = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (240, 40)
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])

    base = texture_node(nodes, "PBR Base Color", load_image(TEXTURE_DIR / f"{surface_name}_basecolor.png"))
    base.location = (-620, 180)
    roughness = texture_node(nodes, "PBR Roughness", load_image(TEXTURE_DIR / f"{surface_name}_roughness.png", True))
    roughness.location = (-620, -40)
    normal_texture = texture_node(nodes, "PBR Normal", load_image(TEXTURE_DIR / f"{surface_name}_normal.png", True))
    normal_texture.location = (-620, -260)
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.location = (-160, -250)
    normal_map.inputs["Strength"].default_value = 0.85

    links.new(base.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(roughness.outputs["Color"], bsdf.inputs["Roughness"])
    links.new(normal_texture.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])

    bsdf.inputs["Metallic"].default_value = METALLIC.get(material_name, 0.06)
    if material_name in EMISSION_STRENGTH:
        links.new(base.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = EMISSION_STRENGTH[material_name]
    if material_name in CRYSTAL_SETTINGS:
        transmission, alpha = CRYSTAL_SETTINGS[material_name]
        bsdf.inputs["Transmission Weight"].default_value = transmission
        bsdf.inputs["Alpha"].default_value = alpha
        bsdf.inputs["IOR"].default_value = 1.46
        material.diffuse_color[3] = alpha
        material.surface_render_method = "DITHERED"

    material["torch_spark_texture_surface"] = surface_name
    material["pbr_texture_resolution"] = 1024


def ensure_uvs() -> tuple[int, int]:
    unwrapped = 0
    normalized = 0
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or len(obj.data.polygons) == 0:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(
            angle_limit=1.15192,
            island_margin=0.025,
            area_weight=0.5,
            correct_aspect=True,
            scale_to_bounds=True,
        )
        bpy.ops.object.mode_set(mode="OBJECT")
        obj.select_set(False)
        unwrapped += 1
        uv_data = obj.data.uv_layers.active.data
        if uv_data:
            min_u = min(loop.uv.x for loop in uv_data)
            max_u = max(loop.uv.x for loop in uv_data)
            min_v = min(loop.uv.y for loop in uv_data)
            max_v = max(loop.uv.y for loop in uv_data)
            width = max_u - min_u
            height = max_v - min_v
            if width > 1e-8 and height > 1e-8:
                for loop in uv_data:
                    loop.uv.x = (loop.uv.x - min_u) / width
                    loop.uv.y = (loop.uv.y - min_v) / height
                normalized += 1
        obj["editable_component"] = True
    return unwrapped, normalized


def assign_crown_crystal_material() -> int:
    """Give the authored orb-crown crystal bodies their dedicated texture set."""
    material = bpy.data.materials.get("Crown_Crystal")
    if material is None:
        material = bpy.data.materials.new("Crown_Crystal")
    assigned = 0
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        authored_name = f"{obj.name} {obj.data.name}"
        if "Orb_Crown_" not in authored_name or "Facet_Outline" in authored_name:
            continue
        obj.data.materials.clear()
        obj.data.materials.append(material)
        for polygon in obj.data.polygons:
            polygon.material_index = 0
        assigned += 1
    if assigned == 0:
        raise RuntimeError("No orb-crown crystal bodies found for Crown_Crystal")
    return assigned


def main() -> None:
    if not INPUT_GLB.exists():
        raise RuntimeError(f"Missing pre-texture GLB backup: {INPUT_GLB}")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(INPUT_GLB))
    manifest = json.loads(MANIFEST.read_text())
    crown_components = assign_crown_crystal_material()
    for material_name, surface_name in manifest["material_textures"].items():
        apply_material(material_name, surface_name)
    unwrapped, normalized = ensure_uvs()

    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT_GLB),
        export_format="GLB",
        export_materials="EXPORT",
        export_yup=True,
        export_apply=True,
        export_cameras=False,
        export_lights=False,
    )
    mesh_count = sum(1 for obj in bpy.context.scene.objects if obj.type == "MESH")
    print(
        f"TORCH_SPARK_TEXTURE_EXPORT: {mesh_count} editable meshes, "
        f"{unwrapped} UV sets created, {normalized} UV sets normalized"
    )
    print(f"TORCH_SPARK_TEXTURE_EXPORT: Crown_Crystal assigned to {crown_components} components")
    print(f"TORCH_SPARK_TEXTURE_EXPORT: wrote {OUTPUT_GLB}")
    print(f"TORCH_SPARK_TEXTURE_EXPORT: wrote {OUTPUT_BLEND}")


if __name__ == "__main__":
    main()
