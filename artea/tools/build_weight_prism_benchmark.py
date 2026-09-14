"""Build an isolated Mind Spark reference instrument; run with Blender --background."""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector
import numpy as np

OUT = Path(__file__).resolve().parents[1] / 'assets3D/mind_spark/quest_kit/weight_prism'
for folder in ('source', 'export', 'previews', 'textures'):
    (OUT / folder).mkdir(parents=True, exist_ok=True)
# This script is used in a new background process, never the user's open scene.
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
root = bpy.data.objects.new('WeightPrismArt', None)
scene.collection.objects.link(root)
palette = [(0.93, .88, .77), (.76, .59, .32), (.15, .37, .39), (.52, .78, .69)]
image = bpy.data.images.new('MindSpark_QuietSurfaceAtlas', width=1024, height=1024)
pixels = np.ones((1024, 1024, 4), dtype=np.float32)
rng = np.random.default_rng(42)
for i, colour in enumerate(palette):
    noise = rng.uniform(-.012, .012, (1024, 256, 1))
    gradient = np.linspace(.97, 1.025, 1024)[:, None, None]
    pixels[:, i*256:(i+1)*256, :3] = np.clip(np.array(colour)*gradient+noise, 0, 1)
image.pixels.foreach_set(pixels.ravel())
image.filepath_raw = str(OUT / 'textures/quiet_surface_atlas.png')
image.file_format = 'PNG'
image.save()
materials = []
for i, name in enumerate(('PearlStone', 'ChampagneBrass', 'TealEnamel', 'AquaLens')):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    tex = m.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = image
    m.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Metallic'].default_value = (0.02, .65, .12, .0)[i]
    bsdf.inputs['Roughness'].default_value = (.65, .36, .40, .23)[i]
    materials.append(m)

fixed = []
def finish(obj, name, material=0, parent=root, bevel=0.04):
    obj.name = name
    obj.data.materials.append(materials[material])
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new('CraftedEdge', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if obj.data.uv_layers:
        for loop in obj.data.uv_layers.active.data:
            loop.uv.x = (material + .04 + loop.uv.x * .92) / 4
            loop.uv.y = .04 + loop.uv.y * .92
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world
    if parent == root and name != 'StateLens':
        fixed.append(obj)
    return obj

def box(name, at, size, material=0, parent=root, bevel=.06):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    ob = bpy.context.object
    ob.scale = size
    return finish(ob, name, material, parent, bevel)

def cylinder(name, at, radius, depth, material=1, parent=root, front=False, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=at)
    ob = bpy.context.object
    if front:
        ob.rotation_euler.x = math.pi / 2
    return finish(ob, name, material, parent, .025)

def rod(name, a, b, radius=.045, material=1, parent=root):
    direction = Vector(b)-Vector(a)
    ob = cylinder(name, (Vector(a)+Vector(b))/2, radius, direction.length, material, parent)
    ob.rotation_mode = 'QUATERNION'
    ob.rotation_quaternion = direction.to_track_quat('Z', 'Y')
    return ob

def group(name, at, parent=root):
    ob = bpy.data.objects.new(name, None)
    scene.collection.objects.link(ob)
    ob.parent = parent
    ob.location = at
    return ob

box('BroadPlinth', (0,0,.20), (5.8,2.65,.40), bevel=.14)
box('InsetPlinth', (0,0,.49), (5.25,2.20,.24), 1, bevel=.09)
box('SculptedHousing', (0,0,1.23), (3.7,1.78,1.28), bevel=.24)
box('EnamelServiceInset', (0,-.905,1.25), (2.8,.10,.72), 2)
box('ServicePanelInner', (0,-.97,1.25), (2.48,.07,.48), 0, bevel=.045)
for x in (-1.02,1.02):
    cylinder('ServiceFastener', (x,-1.03,1.25), .07,.09,1,front=True,vertices=6)
box('TopCornice', (0,0,1.96), (4.12,2.06,.22), 0)
box('CorniceReveal', (0,0,2.10), (3.85,1.84,.08), 1, bevel=.02)
box('FulcrumPillar', (0,.16,3.60), (.76,.82,3.0), 0, bevel=.12)
box('PillarTealInlay', (0,-.28,3.62), (.25,.06,2.22), 2, bevel=.025)
box('BearingCapital', (0,.08,5.11), (1.25,1.16,.35), 0)
cylinder('VisiblePivotBearing', (0,-.40,5.38), .40,.56,1,front=True)
cylinder('PivotPorcelainCap', (0,-.71,5.38), .27,.09,0,front=True)

beam = group('BalanceBeam', (0,0,5.38))
# Geometry is authored in world coordinates, then parented preserving position.
box('BalanceArm', (0,0,5.38), (4.70,.32,.25), 1, beam)
box('BalanceArmInlay', (0,-.18,5.38), (3.90,.045,.065), 2, beam, .012)
for side in (-1,1):
    x = side*2.14
    hanger = group('ChamberLeft' if side < 0 else 'ChamberRight', (x,0,0), beam)
    bpy.context.view_layer.update()
    for y in (-.31,.31):
        rod('SuspensionRod', (x,y,5.35), (x,y,4.18), .045, 1, hanger)
    cylinder('ChamberCrown', (x,0,4.13), .62,.14,1,hanger)
    cylinder('PorcelainChamber', (x,0,3.56), .56,1.0,0,hanger)
    cylinder('ChamberFoot', (x,0,3.03), .64,.14,1,hanger)
    box('EnamelSightWindow', (x,-.54,3.57), (.32,.065,.65), 2,hanger,.04)
    for z in (3.32,3.55,3.78):
        box('SightScale', (x+.22,-.55,z), (.13,.05,.024), 1,hanger,.005)
    for angle in (0,math.pi/2,math.pi,3*math.pi/2):
        rod('ChamberBinding', (x+math.cos(angle)*.57,math.sin(angle)*.57,3.12),
            (x+math.cos(angle)*.57,math.sin(angle)*.57,4.05), .025,1,hanger)

slider = group('Counterweight', (0,-.23,0), beam)
bpy.context.view_layer.update()
box('CounterweightBlock', (0,-.23,5.38), (.40,.53,.50),2,slider)

# The front control has a reachable lever and three explicit stops.
box('SelectorBed', (0,-.55,2.27), (2.9,.63,.17), 2)
for x in (-.84,0,.84):
    cylinder('SelectorStop', (x,-.55,2.40), .13,.06,1)
selector = group('OperatingGrip', (0,-.55,2.48))
box('GripStem', (0,-.55,2.63), (.15,.15,.35),1,selector)
box('GripHandle', (0,-.55,2.86), (.58,.26,.20),2,selector)
# Output lens set into the central support.
cylinder('OutputLensFrame', (0,-.41,4.58), .21,.15,1,front=True)
cylinder('StateLens', (0,-.50,4.58), .14,.07,3,front=True)

for side in (-1,1):
    x = side*1.32
    rod('ReturnRiser', (x,.64,.66),(x,.64,2.46),.07)
    rod('ReturnHeader',(x,.64,2.46),(side*.38,.64,2.46),.07)
    for z in (.80,2.31):
        cylinder('PipeCollar',(x,.64,z),.12,.12)

bpy.context.view_layer.update()
# Save editable source before consolidation. No background stage in this file.
image.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/weight_prism.blend'))
# Join only fixed geometry; moving assemblies retain their pivots.
bpy.ops.object.select_all(action='DESELECT')
for ob in fixed:
    ob.select_set(True)
bpy.context.view_layer.objects.active = fixed[0]
bpy.ops.object.join()
fixed[0].name = 'StaticBodyArt'
for parent in (beam, slider, selector, bpy.data.objects['ChamberLeft'], bpy.data.objects['ChamberRight']):
    parts = [ob for ob in parent.children if ob.type == 'MESH']
    if len(parts) > 1:
        bpy.ops.object.select_all(action='DESELECT')
        for ob in parts:
            ob.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
        parts[0].name = parent.name + 'Art'
for ob in scene.objects:
    ob.select_set(ob.type in ('MESH','EMPTY'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'export/weight_prism.glb'),
    export_format='GLB', use_selection=True, export_apply=True)
tris = 0
meshes = 0
for ob in scene.objects:
    if ob.type == 'MESH':
        ob.data.calc_loop_triangles()
        tris += len(ob.data.loop_triangles)
        meshes += 1
(OUT/'manifest.json').write_text(json.dumps({'revision':'weight_benchmark_01',
    'triangles':tris,'runtime_mesh_nodes':meshes,'materials':4,'atlas_size':1024,
    'source':'source/weight_prism.blend','export':'export/weight_prism.glb',
    'moving_groups':['BalanceBeam','ChamberLeft','ChamberRight','Counterweight','OperatingGrip'],
    'status':'benchmark awaiting in-game review'},indent=2))

scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.render.resolution_x=1200
scene.render.resolution_y=1200
scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('WarmStudio')
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.63,.72,.80,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.55
for name,at,power,size in [('Key',(-4,-7,10),1500,7),('Fill',(6,-2,7),900,6),('Rim',(1,5,9),1800,5)]:
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size
    ob=bpy.data.objects.new(name,data); scene.collection.objects.link(ob); ob.location=at
    ob.rotation_euler=(Vector((0,0,3))-ob.location).to_track_quat('-Z','Y').to_euler()
camera_data=bpy.data.cameras.new('InspectionCamera')
camera=bpy.data.objects.new('InspectionCamera',camera_data)
scene.collection.objects.link(camera); scene.camera=camera
camera_data.type='ORTHO'; camera_data.ortho_scale=8.6
for name,at in [('front',(0,-14,7)),('three_quarter',(9,-15,9)),('rear',(9,15,8))]:
    camera.location=at
    camera.rotation_euler=(Vector((0,0,2.8))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/f'previews/{name}.png')
    bpy.ops.render.render(write_still=True)
print('WEIGHT_BENCHMARK_BUILD_COMPLETE',tris,meshes)
