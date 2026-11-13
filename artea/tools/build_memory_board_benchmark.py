"""Build Island Two's editable, compact three-node Memory Board benchmark."""
import bpy
import json
import math
from pathlib import Path

BASE = Path(__file__).resolve().parents[1] / 'assets3D/mind_spark/quest_kit'
OUT = BASE / 'memory_board'
bpy.ops.wm.read_factory_settings(use_empty=True)
atlas = bpy.data.images.load(str(BASE / 'weight_prism/textures/quiet_surface_atlas.png'))
atlas.pack()
mats = []
for i, name in enumerate(('PearlStone', 'ChampagneBrass', 'TealEnamel', 'AquaLens')):
    m = bpy.data.materials.new(name); m.use_nodes = True
    shader = m.node_tree.nodes.get('Principled BSDF')
    tex = m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image = atlas
    m.node_tree.links.new(tex.outputs['Color'], shader.inputs['Base Color'])
    shader.inputs['Metallic'].default_value = (.02, .65, .12, 0)[i]
    shader.inputs['Roughness'].default_value = (.65, .45, .42, .3)[i]
    mats.append(m)

def finish(ob, name, mat, bevel=.025):
    ob.name = name
    ob.data.materials.append(mats[mat])
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = ob.modifiers.new('CraftedEdge', 'BEVEL'); mod.width = bevel; mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for uv in ob.data.uv_layers.active.data:
        uv.uv.x = (mat + .04 + uv.uv.x * .92) / 4
        uv.uv.y = .04 + uv.uv.y * .92
    return ob

def box(name, at, size, mat=0, bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    ob = bpy.context.object; ob.scale = size
    return finish(ob, name, mat, bevel)

def disc(name, at, radius, depth, mat=1):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=depth,
                                      location=at, rotation=(math.pi / 2, 0, 0))
    return finish(bpy.context.object, name, mat, .012)

box('SteppedFoot', (0, 0, .08), (1.95, .88, .16), bevel=.055)
box('LowerBrassReveal', (0, 0, .18), (1.80, .76, .06), 1)
for x in (-.63, .63):
    box('TaperedSupport', (x, .12, .45), (.23, .40, .52), bevel=.055)
box('ServiceCabinet', (0, .12, .43), (1.18, .39, .42), 2, .055)
box('DeskApron', (0, -.02, .69), (1.90, .81, .15), bevel=.045)
box('BoardHousing', (0, .08, 1.14), (1.88, .26, .88), bevel=.065)
box('BrassRecessFrame', (0, -.065, 1.16), (1.74, .055, .74), 1)
box('QuietSlate', (0, -.101, 1.16), (1.65, .035, .65), 2)
box('ReadingLedge', (0, -.26, .80), (1.77, .42, .09), bevel=.025)
for x in (-.81, .81):
    for z in (.85, 1.46):
        disc('FrameFastener', (x, -.105, z), .026, .025)

dynamic = []
for i, x in enumerate((-.53, 0, .53)):
    z = 1.18 + (.12 if i == 1 else 0)
    disc('SocketHousing', (x, -.14, z), .20, .10, 0)
    disc('SocketBearing', (x, -.20, z), .16, .04, 1)
    cap = disc('NodeCap%d' % i, (x, -.233, z), .127, .035, 3)
    dynamic.append(cap)
    # Numbering belongs to the cap, so it follows the depressed selection pose.
    for mark in range(i + 1):
        bar = box('TactileNumeral', (x + (mark-i/2)*.042, -.258, z), (.017, .015, .10), 2, .004)
        bpy.context.view_layer.update()
        matrix = bar.matrix_world.copy(); bar.parent = cap; bar.matrix_world = matrix
    box('NodeCaptionPlate', (x, -.13, .94), (.35, .04, .095), 0, .012)
for i, x in enumerate((-.265, .265)):
    box('ConnectionChannel', (x, -.13, 1.15), (.28, .035, .10), 1, .015)
    dynamic.append(box('Link%d' % i, (x, -.154, 1.15), (.23, .018, .043), 3, .008))
disc('ResetGrip', (-.66, -.40, .82), .067, .045, 2)
box('RewardCradle', (.66, -.29, .85), (.22, .19, .08), 1)
dynamic.append(disc('RewardSeal', (.66, -.35, .91), .065, .028, 3))

for folder in ('source', 'export', 'previews'):
    (OUT / folder).mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'source/memory_board.blend'))
source_count = sum(ob.type == 'MESH' for ob in bpy.context.scene.objects)
for cap in dynamic:
    if cap.children:
        bpy.ops.object.select_all(action='DESELECT')
        for child in list(cap.children): child.select_set(True)
        cap.select_set(True); bpy.context.view_layer.objects.active = cap
        bpy.ops.object.join()
# Keep fixed pieces in one multi-material assembly; caps, labels and links remain editable.
parts = [ob for ob in bpy.context.scene.objects if ob.type == 'MESH' and ob not in dynamic and ob.parent is None]
bpy.ops.object.select_all(action='DESELECT')
for ob in parts: ob.select_set(True)
bpy.context.view_layer.objects.active = parts[0]; bpy.ops.object.join(); parts[0].name = 'StaticBodyArt'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT / 'export/memory_board.glb'), export_format='GLB', use_selection=True)
triangles = 0
for ob in bpy.context.scene.objects:
    if ob.type == 'MESH':
        ob.data.calc_loop_triangles(); triangles += len(ob.data.loop_triangles)
(OUT / 'manifest.json').write_text(json.dumps({
    'revision': 'memory_board_01', 'triangles': triangles,
    'runtime_mesh_nodes': sum(ob.type == 'MESH' for ob in bpy.context.scene.objects),
    'editable_source_meshes': source_count, 'materials': 4, 'atlas_size': 1024,
    'dynamic_parts': [ob.name for ob in dynamic], 'dimensions_policy': 'preserve approximately two-metre station footprint'
}, indent=2))
