"""Renders a premium studio overview sheet of all 12 Mind Spark quest objects.

Imports every GLB, keeps LOD0 geometry only (LOD1/LOD2/UCX are stripped),
arranges the 12 hero props in a 4x3 grid with three-point lighting per cell,
readable "01".."12" number labels, and a dark navy studio background, then
renders a single overview image.

Run headlessly:
    /Applications/Blender.app/Contents/MacOS/Blender --background --python \
        tools/blender/render_mind_spark_quest_objects.py

Output:
    artifacts/blender_mind_spark_quest_objects/overview.png
"""

import json
import math
import os

import bpy
import mathutils

Vector = mathutils.Vector

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GLB_DIR = os.path.join(REPO_ROOT, "assets3D", "mind_spark", "quest_objects", "glb")
OUT_DIR = os.path.join(REPO_ROOT, "artifacts", "blender_mind_spark_quest_objects")
OUT_PATH = os.path.join(OUT_DIR, "overview.png")
BUILD_REPORT_PATH = os.path.join(os.path.dirname(__file__), "mind_spark_quest_objects_report.json")

os.makedirs(OUT_DIR, exist_ok=True)

REPRESENTATIVE_STATE = "active"


def _load_state_parts_by_object():
    """Reads the build script's own report for the authoritative mapping of
    which mesh names belong to which of {inactive, active, completed} per
    object, since state-part names don't follow one consistent suffix
    (e.g. "Door" is inactive, "CentralSpark" is completed)."""
    with open(BUILD_REPORT_PATH) as f:
        report = json.load(f)
    return {o["object_id"]: o["state_parts"] for o in report["objects"]}


STATE_PARTS_BY_OBJECT = _load_state_parts_by_object()

OBJECT_IDS = [
    "thought_spark_socket",
    "evidence_scanner",
    "perspective_lens",
    "memory_constellation_board",
    "logic_gate_arch",
    "truth_bridge_tile",
    "focus_bell_beacon",
    "warden_anchor",
    "calm_rain_basin",
    "identity_reflection_mirror",
    "checkpoint_server_root",
    "clear_path_projector",
]

GRID_COLS = 4
GRID_ROWS = 3
CELL_SIZE = 3.6
NAVY_BG = (0.035, 0.045, 0.075)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for coll in list(bpy.data.collections):
        bpy.data.collections.remove(coll)


def _prune_collision_mesh(lod0):
    """UCX_ collision boxes are wireframe-only in the editor (display_type is
    a viewport-only flag, not exported to glTF), so on import they show up as
    solid, unlit white boxes that occlude the actual hero geometry. Strip
    them before rendering."""
    for mesh in _collect_meshes(lod0):
        if mesh.name.startswith("UCX_"):
            _delete_recursive(mesh)


def _prune_state_variants(lod0, obj_id):
    """Each quest object's LOD0 subtree carries every inactive/active/completed
    state-swap part simultaneously (they're just hidden/shown at runtime by
    quest_object_base.gd). Rendering all three at once is what made every prop
    read as an overlapping, illegible blob, so keep only one representative
    state's parts (per the build report's authoritative state_parts manifest)
    and delete every other state's geometry outright."""
    state_parts = STATE_PARTS_BY_OBJECT[obj_id]
    names_to_remove = set()
    for state, names in state_parts.items():
        if state != REPRESENTATIVE_STATE:
            names_to_remove.update(names)
    for mesh in _collect_meshes(lod0):
        if mesh.name in names_to_remove:
            _delete_recursive(mesh)


def import_lod0_only(obj_id, cell_center):
    """Imports one GLB, deletes everything except the LOD0 subtree (and, within
    LOD0, every state variant but one representative state), and
    repositions/rescales the surviving hero geometry to fit inside one grid
    cell centered at cell_center."""
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=os.path.join(GLB_DIR, f"{obj_id}.glb"))
    imported = [bpy.data.objects[n] for n in bpy.data.objects.keys() if n not in before]

    roots = [o for o in imported if o.parent is None and o.type == 'EMPTY']
    if len(roots) != 1:
        raise RuntimeError(f"[{obj_id}] expected 1 root empty on import, found {len(roots)}")
    root = roots[0]

    lod0 = None
    for child in list(root.children):
        if child.name.startswith("LOD0"):
            lod0 = child
        else:
            _delete_recursive(child)

    if lod0 is None:
        raise RuntimeError(f"[{obj_id}] LOD0 node not found after import")

    _prune_collision_mesh(lod0)
    _prune_state_variants(lod0, obj_id)

    # Compute world-space bounds of the surviving LOD0 meshes so we can fit
    # them into the cell regardless of each prop's native scale.
    meshes = _collect_meshes(lod0)
    bounds_min = [math.inf, math.inf, math.inf]
    bounds_max = [-math.inf, -math.inf, -math.inf]
    for m in meshes:
        for corner in m.bound_box:
            world_corner = m.matrix_world @ Vector(corner)
            for i in range(3):
                bounds_min[i] = min(bounds_min[i], world_corner[i])
                bounds_max[i] = max(bounds_max[i], world_corner[i])

    size = [bounds_max[i] - bounds_min[i] for i in range(3)]
    max_dim = max(size) if max(size) > 0 else 1.0
    fit_scale = (CELL_SIZE * 0.62) / max_dim
    center = [(bounds_min[i] + bounds_max[i]) / 2.0 for i in range(3)]

    root.scale = (fit_scale, fit_scale, fit_scale)
    root.location = (
        cell_center[0] - center[0] * fit_scale,
        cell_center[1] - center[1] * fit_scale,
        -bounds_min[2] * fit_scale,
    )
    root.name = f"{obj_id}_root"
    return root


def _collect_meshes(obj):
    result = []
    for child in obj.children:
        if child.type == 'MESH':
            result.append(child)
        result.extend(_collect_meshes(child))
    return result


def _delete_recursive(obj):
    for child in list(obj.children):
        _delete_recursive(child)
    bpy.data.objects.remove(obj, do_unlink=True)


def add_label(text, cell_center, index):
    bpy.ops.object.text_add(location=(cell_center[0], cell_center[1] - CELL_SIZE * 0.56, 0.02))
    txt_obj = bpy.context.active_object
    txt_obj.data.body = f"{index:02d}"
    txt_obj.data.size = 0.5
    txt_obj.data.extrude = 0.015
    txt_obj.data.align_x = 'CENTER'
    txt_obj.rotation_euler = (math.radians(90), 0, 0)
    txt_obj.name = f"Label_{text}"

    mat = bpy.data.materials.new(f"MAT_Label_{text}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
    bsdf.inputs["Emission Color"].default_value = (0.85, 0.92, 1.0, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 2.4
    txt_obj.data.materials.append(mat)
    return txt_obj


def add_studio_backdrop():
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, 0, 0))
    floor = bpy.context.active_object
    floor.name = "StudioFloor"
    span_x = GRID_COLS * CELL_SIZE + 4.0
    span_y = GRID_ROWS * CELL_SIZE + 4.0
    floor.scale = (span_x, span_y, 1.0)

    mat = bpy.data.materials.new("MAT_StudioBackdrop")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*NAVY_BG, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Metallic"].default_value = 0.0
    floor.data.materials.append(mat)
    return floor


def add_three_point_lighting(target_center, extent):
    # Area-light irradiance falls off with distance^2 and scales with light
    # size, so energy is tuned for this specific rig geometry (lights placed
    # a few multiples of `extent` away) rather than scaled linearly with
    # `extent`, which previously produced massively overexposed, blown-out
    # white surfaces.
    key = _add_area_light("KeyLight", loc=(target_center[0] + extent * 0.55,
                                            target_center[1] - extent * 1.1,
                                            extent * 0.75),
                           energy=extent * 18, size=extent * 0.5, color=(1.0, 0.98, 0.94))
    fill = _add_area_light("FillLight", loc=(target_center[0] - extent * 0.7,
                                              target_center[1] - extent * 0.85,
                                              extent * 0.45),
                            energy=extent * 8, size=extent * 0.55, color=(0.72, 0.85, 1.0))
    rim = _add_area_light("RimLight", loc=(target_center[0],
                                            target_center[1] + extent * 0.9,
                                            extent * 0.7),
                           energy=extent * 12, size=extent * 0.4, color=(0.55, 0.85, 1.0))
    for light in (key, fill, rim):
        _point_at(light, target_center)
    return key, fill, rim


def _add_area_light(name, loc, energy, size, color):
    light_data = bpy.data.lights.new(name, type='AREA')
    light_data.energy = energy
    light_data.size = size
    light_data.color = color
    light_obj = bpy.data.objects.new(name, light_data)
    bpy.context.scene.collection.objects.link(light_obj)
    light_obj.location = loc
    return light_obj


def _point_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()


def add_camera(target_center, grid_span_x, grid_span_y, resolution):
    cam_data = bpy.data.cameras.new("OverviewCamera")
    cam_data.lens = 32
    # sensor_fit defaults to AUTO, which for a landscape render (width >
    # height, as here) maps sensor_width to the horizontal FOV and derives
    # the vertical FOV from the render aspect ratio. The previous version of
    # this function derived the vertical FOV straight from sensor_height as
    # though sensor_fit were VERTICAL, which understated it for this
    # landscape resolution and undershot the framing distance -- that
    # silently cropped the top rows of the grid out of frame.
    cam_data.sensor_fit = 'HORIZONTAL'
    cam_obj = bpy.data.objects.new("OverviewCamera", cam_data)
    bpy.context.scene.collection.objects.link(cam_obj)

    aspect = resolution[0] / resolution[1]
    half_fov_h = math.atan((cam_data.sensor_width / 2.0) / cam_data.lens)
    half_fov_v = math.atan(math.tan(half_fov_h) / aspect)

    # Add generous margin for the label row and camera elevation angle so the
    # full 4x3 grid plus its "01".."12" labels stays inside frame. The
    # elevated, angled camera's line-of-sight distance to the ground plane is
    # longer than a straight-on shot at the same height above the target, so
    # the raw tan(fov)-derived distance is inflated by 1/cos(elevation) to
    # compensate.
    margin = 1.04
    elevation_angle = math.radians(38)
    elevation_factor = 1.0 / math.cos(elevation_angle)
    needed_dist_for_height = (grid_span_y / 2.0 * margin) / math.tan(half_fov_v) * elevation_factor
    needed_dist_for_width = (grid_span_x / 2.0 * margin) / math.tan(half_fov_h) * elevation_factor
    distance = max(needed_dist_for_height, needed_dist_for_width)

    cam_obj.location = (
        target_center[0],
        target_center[1] - distance * math.cos(elevation_angle),
        distance * math.sin(elevation_angle),
    )
    _point_at(cam_obj, (target_center[0], target_center[1], 0.0))
    bpy.context.scene.camera = cam_obj
    return cam_obj


def configure_render(engine='BLENDER_EEVEE', samples=64, resolution=(2400, 1800)):
    scene = bpy.context.scene
    scene.render.engine = engine
    if engine == 'CYCLES':
        scene.cycles.samples = samples
        scene.cycles.use_denoising = True
        try:
            scene.cycles.device = 'GPU'
        except Exception:
            pass
    else:
        scene.eevee.taa_render_samples = samples
    scene.render.resolution_x = resolution[0]
    scene.render.resolution_y = resolution[1]
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = 'PNG'
    scene.view_settings.view_transform = 'AgX'
    scene.view_settings.look = 'AgX - Medium High Contrast'
    scene.view_settings.exposure = -1.0


def main():
    reset_scene()
    add_studio_backdrop()

    cell_centers = []
    for row in range(GRID_ROWS):
        for col in range(GRID_COLS):
            x = (col - (GRID_COLS - 1) / 2.0) * CELL_SIZE
            y = (row - (GRID_ROWS - 1) / 2.0) * CELL_SIZE
            cell_centers.append((x, -y))

    for i, obj_id in enumerate(OBJECT_IDS):
        center = cell_centers[i]
        import_lod0_only(obj_id, center)
        add_label(obj_id, center, i + 1)
        print(f"[render] placed {obj_id} at cell {i + 1:02d} {center}")

    resolution = (2400, 1800)
    grid_span_x = GRID_COLS * CELL_SIZE
    grid_span_y = GRID_ROWS * CELL_SIZE
    grid_extent = max(grid_span_x, grid_span_y)
    add_three_point_lighting((0, 0, CELL_SIZE * 0.4), grid_extent)
    add_camera((0, 0, 0), grid_span_x, grid_span_y, resolution)

    world = bpy.data.worlds.new("StudioWorld")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (*NAVY_BG, 1.0)
    bg.inputs["Strength"].default_value = 0.6
    bpy.context.scene.world = world

    configure_render(engine='BLENDER_EEVEE', samples=64, resolution=resolution)

    bpy.context.scene.render.filepath = OUT_PATH
    bpy.ops.render.render(write_still=True)
    print(f"[render] wrote {OUT_PATH}")


if __name__ == "__main__":
    main()
