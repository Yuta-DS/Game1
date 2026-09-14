"""Reuse the authored research-bay shell; create a distinct mechanical recorder.
Run in a separate background Blender process, never the user's open scene.
"""
import bpy, math, json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets3D/mind_spark/unfinished_light/recorder_bay'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets3D/mind_spark/unfinished_light/inspection_bay/inspection_bay.blend'))
bpy.context.preferences.filepaths.save_version = 0
OUT.mkdir(parents=True, exist_ok=True)
keep = ('ContinuousBase','BaseReveal','StorageCase','Drawer','RecessedPull',
        'CabinetFoot','WorkingTop','FrontBrassEdge','WorkSurface')
for ob in list(bpy.context.scene.objects):
    if ob.get('assembly') != 'Pavilion' and not ob.name.startswith(keep):
        bpy.data.objects.remove(ob, do_unlink=True)
MATS = [bpy.data.materials[n] for n in ['IvoryCeramic','BrushedBrass','DeepTealEnamel','OpalGlass']]
def finish(ob, name, mat, group, bevel=.02):
    ob.name=name; ob['assembly']=group; ob.data.materials.append(MATS[mat])
    bpy.context.view_layer.objects.active=ob
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod=ob.modifiers.new('Crafted bevel','BEVEL'); mod.width=bevel; mod.segments=2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for uv in ob.data.uv_layers.active.data:
        uv.uv.x=(mat+.04+uv.uv.x*.92)/4; uv.uv.y=.04+uv.uv.y*.92
    return ob
def box(name, at, size, mat=0, group='Cabinet'):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at)
    ob=bpy.context.object; ob.scale=size
    return finish(ob,name,mat,group)
def cyl(name, at, radius, depth, mat=1, group='Cabinet', axis='X'):
    rotation=(0,math.pi/2,0) if axis=='X' else (0,0,0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=radius,depth=depth,location=at,rotation=rotation)
    return finish(bpy.context.object,name,mat,group,.008)

# A horizontal record drum on visible bearings, not another three-dial console.
box('RecorderBed',(0,.33,1.44),(4.8,.95,.18),2)
for x in [-2.22,2.22]:
    box('BearingFoot',(x,.4,1.58),(.45,.72,.14),1)
    box('BearingStand',(x,.4,1.89),(.30,.44,.55),0)
    cyl('BearingCap',(x,.4,2.10),.25,.38)
cyl('RecordDrum',(0,.4,2.10),.42,4.1,0,'Drum')
for x in [-2.05,2.05]: cyl('DrumFlange',(x,.4,2.10),.48,.10,1,'Drum')
for j in range(16):
    angle=j*math.tau/16
    ob=box('DrumRegister',(0,.4+math.sin(angle)*.425,2.10+math.cos(angle)*.425),(3.9,.022,.016),1,'Drum')
    ob.rotation_euler.x=-angle
for x in [-2.02,2.02]:
    cyl('StripGuide',(x,-.14,1.69),.13,.10,1)
box('TileRail',(0,-.2,1.71),(4.30,.16,.12),1)
box('TileTrack',(0,-.34,1.72),(4.30,.13,.06),2)
for i,x in enumerate([-1.4,0,1.4]):
    group='EventTile%d'%i
    box('EventTileFrame',(x,-.40,1.93),(1.21,.13,.52),1,group)
    box('EventTileFace',(x,-.48,1.93),(1.09,.04,.40),2,group)
    for dx in [-.49,.49]: box('TileLatch',(x+dx,-.52,1.92),(.06,.035,.12),0,group)
    box('TileTab',(x,-.38,2.23),(.35,.13,.09),0,group)
# Protected pointer carriage translates across the three strip slots.
box('PointerRail',(0,.02,2.79),(4.45,.10,.10),1)
box('ReplayPointer',(0,-.03,2.65),(.07,.08,.27),1,'Pointer')
box('PointerFlag',(0,-.03,2.81),(.26,.11,.12),0,'Pointer')
for x in [-2.15,2.15]: box('PointerSupport',(x,.1,2.47),(.09,.13,.63),1)
box('LeverSocket',(2.25,-.59,1.43),(.35,.30,.16),1)
box('ReplayLever',(2.25,-.59,1.67),(.06,.07,.45),1,'ReplayLever')
cyl('LeverGrip',(2.25,-.59,1.91),.10,.27,2,'ReplayLever')
box('ReplayLabel',(1.98,-.84,1.4),(.80,.18,.035),0)
box('ReplayOutput',(0,.66,3.05),(3.9,.12,.44),2)
source_parts=len([o for o in bpy.context.scene.objects if o.type=='MESH'])
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'recorder_bay.blend'))
groups={}
for ob in list(bpy.context.scene.objects):
    if ob.type=='MESH': groups.setdefault(ob['assembly'],[]).append(ob)
origins={'Drum':(0,.4,2.10),'Pointer':(0,-.03,2.65),'ReplayLever':(2.25,-.59,1.43)}
for i in range(3): origins['EventTile%d'%i]=([-1.4,0,1.4][i],-.4,1.93)
for name,parts in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts: ob.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    if len(parts)>1: bpy.ops.object.join()
    ob=parts[0]; ob.name=name
    bpy.context.scene.cursor.location=origins.get(name,(0,0,0))
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    mod=ob.modifiers.new('ExportTriangles','TRIANGULATE'); bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/'recorder_bay.glb'),export_format='GLB',use_selection=True,export_apply=True)
triangles=sum(len(ob.data.polygons) for ob in bpy.context.scene.objects if ob.type=='MESH')
(OUT/'manifest.json').write_text(json.dumps({'source_parts':source_parts,'runtime_meshes':len(groups),'triangles':triangles,
    'materials':4,'moving_parts':list(origins),'source':'recorder_bay.blend','shell_source':'inspection_bay.blend'},indent=2))
print('RECORDER_BAY_BUILD',source_parts,len(groups),triangles)
