"""Authored test-line apparatus on the shared heavenly research-bay shell."""
import bpy, math, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets3D/mind_spark/unfinished_light/tester_bay'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets3D/mind_spark/unfinished_light/inspection_bay/inspection_bay.blend'))
bpy.context.preferences.filepaths.save_version=0
OUT.mkdir(parents=True,exist_ok=True)
keep=('ContinuousBase','BaseReveal','StorageCase','Drawer','RecessedPull','CabinetFoot','WorkingTop','FrontBrassEdge','WorkSurface')
for ob in list(bpy.context.scene.objects):
    if ob.get('assembly')!='Pavilion' and not ob.name.startswith(keep): bpy.data.objects.remove(ob,do_unlink=True)
MATS=[bpy.data.materials[n] for n in ['IvoryCeramic','BrushedBrass','DeepTealEnamel','OpalGlass']]
def finish(ob,name,mat,group):
    ob.name=name; ob['assembly']=group; ob.data.materials.append(MATS[mat])
    bpy.context.view_layer.objects.active=ob
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel=ob.modifiers.new('Crafted edges','BEVEL'); bevel.width=.02; bevel.segments=2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for uv in ob.data.uv_layers.active.data:
        uv.uv.x=(mat+.04+uv.uv.x*.92)/4; uv.uv.y=.04+uv.uv.y*.92
    return ob
def box(name,at,size,mat=0,group='Cabinet'):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at); ob=bpy.context.object; ob.scale=size
    return finish(ob,name,mat,group)
def cyl(name,at,radius,depth,mat=1,group='Cabinet',front=False):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=radius,depth=depth,location=at,rotation=(math.pi/2,0,0) if front else (0,0,0))
    return finish(bpy.context.object,name,mat,group)
box('ApparatusBack',(0,.7,2.28),(4.8,.16,1.8),0)
box('EnamelTestPanel',(0,.60,2.28),(4.55,.06,1.57),2)
# Left: visible cooling reservoir and front sight gauge with scale marks.
cyl('Reservoir',(-1.63,.22,2.04),.32,1.18,2)
for z in [1.47,2.63]: cyl('ReservoirCap',(-1.63,.22,z),.37,.12)
box('SightRecess',(-1.63,-.12,2.07),(.20,.08,.89),1)
box('SightColumn',(-1.63,-.17,2.07),(.10,.045,.80),3,'FlowColumn')
for i in range(6): box('FlowGraduation',(-1.43,-.13,1.68+i*.15),(.1,.03,.018),0)
# Connected test manifold and bypass, with compression flanges and fasteners.
for z in [1.48,2.57]:
    ob=cyl('CrossManifold',(0,.35,z),.065,3.2); ob.rotation_euler.y=math.pi/2
    for x in [-1.12,.05,1.1]:
        ob=cyl('CompressionCoupling',(x,.35,z),.115,.13); ob.rotation_euler.y=math.pi/2
for x in [-.72,.52]: cyl('BypassRiser',(x,.35,2.03),.06,1.10)
cyl('ValveFeed',(-.72,.17,1.80),.06,.42,1,front=True)
cyl('ValveHousing',(-.72,-.04,1.80),.21,.20,1,front=True)
cyl('ValveStem',(-.72,-.25,1.80),.065,.25,1,front=True)
bpy.ops.mesh.primitive_torus_add(major_radius=.27,minor_radius=.033,major_segments=32,minor_segments=8,location=(-.72,-.42,1.80),rotation=(math.pi/2,0,0))
finish(bpy.context.object,'BypassHandwheel',1,'ValveWheel')
for angle in [0,math.pi/2]:
    ob=box('WheelSpoke',(-.72,-.42,1.80),(.50,.045,.04),1,'ValveWheel'); ob.rotation_euler.y=angle
# Right: a real framed aperture, guide rails and vertically translating shutter.
box('ApertureRecess',(1.48,.47,2.08),(1.04,.08,1.1),2)
for x in [1.0,1.96]: box('ShutterGuide',(x,.35,2.34),(.09,.16,1.62),1)
for z in [1.53,3.1]: box('GuideCrosshead',(1.48,.35,z),(1.18,.22,.13),0)
box('ShutterBlade',(1.48,.12,2.08),(.80,.08,1.01),1,'Shutter')
for i in range(5): box('BladeRib',(1.48,.065,1.70+i*.18),(.73,.035,.045),0,'Shutter')
box('ShutterLiftStem',(1.48,.12,2.73),(.075,.09,.30),1,'Shutter')
box('ApertureLight',(1.48,.39,2.08),(.72,.03,.88),3)
for x in [-2.17,2.17]:
    for z in [1.62,2.91]: cyl('PanelBolt',(x,.54,z),.04,.04,1,front=True)
box('ModelSelectorSeat',(0,-.64,1.42),(.95,.38,.12),0)
cyl('ModelSelector',(0,-.64,1.53),.21,.10,2,'Selector')
box('SelectorPointer',(0,-.79,1.59),(.04,.14,.035),1,'Selector')
for i in range(3): box('ModelIndex',((i-1)*.3,-.88,1.40),(.16,.11,.04),1)
source_parts=len([o for o in bpy.context.scene.objects if o.type=='MESH'])
# All plumbing/header solids near the shutter stay behind its swept depth.
assert .35-.115 > .12+.045
assert .35-.22/2 > .12+.045
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'tester_bay.blend'))
groups={}
for ob in list(bpy.context.scene.objects):
    if ob.type=='MESH': groups.setdefault(ob['assembly'],[]).append(ob)
origins={'FlowColumn':(-1.63,-.17,1.67),'ValveWheel':(-.72,-.42,1.80),'Shutter':(1.48,.12,2.08),'Selector':(0,-.64,1.53)}
for name,parts in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts: ob.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    if len(parts)>1: bpy.ops.object.join()
    ob=parts[0]; ob.name=name; bpy.context.scene.cursor.location=origins.get(name,(0,0,0))
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    mod=ob.modifiers.new('ExportTriangles','TRIANGULATE'); bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/'tester_bay.glb'),export_format='GLB',use_selection=True,export_apply=True)
(OUT/'manifest.json').write_text(json.dumps({'source_parts':source_parts,'runtime_meshes':len(groups),'triangles':sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH'),'moving_parts':list(origins)},indent=2))
print('TESTER_BAY_BUILD',source_parts,len(groups))
