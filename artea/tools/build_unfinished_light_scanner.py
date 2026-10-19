"""Production inspection bay: editable Blender source and semantic GLB meshes.
Run in a separate background Blender process. Never touches an open user scene.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets3D/mind_spark/unfinished_light/inspection_bay'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
OUT.mkdir(parents=True, exist_ok=True)
atlas = bpy.data.images.load(str(ROOT/'assets3D/mind_spark/quest_kit/weight_prism/textures/quiet_surface_atlas.png'))
atlas.pack()
MATS = []
for i, name in enumerate(['IvoryCeramic', 'BrushedBrass', 'DeepTealEnamel', 'OpalGlass']):
    mat = bpy.data.materials.new(name); mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    tex = mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image = atlas
    mat.node_tree.links.new(tex.outputs['Color'], shader.inputs['Base Color'])
    shader.inputs['Metallic'].default_value = [0, .72, .08, .08][i]
    shader.inputs['Roughness'].default_value = [.76, .43, .52, .3][i]
    MATS.append(mat)

def finish(ob, name, mat=0, bevel=.025, group='Cabinet'):
    ob.name = name; ob['assembly'] = group
    ob.data.materials.append(MATS[mat])
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod=ob.modifiers.new('Crafted bevel','BEVEL'); mod.width=bevel; mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if ob.data.uv_layers.active:
        for uv in ob.data.uv_layers.active.data:
            uv.uv.x=(mat+.04+uv.uv.x*.92)/4
            uv.uv.y=.04+uv.uv.y*.92
    return ob

def box(name, at, size, mat=0, bevel=.025, group='Cabinet'):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at)
    ob=bpy.context.object; ob.scale=size
    return finish(ob,name,mat,bevel,group)

def cylinder(name, at, radius, length, mat=1, front=False, group='Cabinet'):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=radius,depth=length,
        location=at,rotation=(math.pi/2,0,0) if front else (0,0,0))
    return finish(bpy.context.object,name,mat,.008,group)

def pipe(name, start, end, radius=.035, mat=1, group='Cabinet'):
    delta=Vector(end)-Vector(start)
    ob=cylinder(name,(Vector(start)+Vector(end))*.5,radius,delta.length,mat,False,group)
    ob.rotation_euler=delta.to_track_quat('Z','Y').to_euler()
    return ob

def ring(name, at, radius, mat=1, group='Cabinet'):
    bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,
        major_radius=radius,minor_radius=.032,location=at,rotation=(math.pi/2,0,0))
    return finish(bpy.context.object,name,mat,0,group)

# Grounded workbench, recessed cabinet doors, trim and accessible front apron.
box('ContinuousBase',(0,0,.09),(5.4,1.9,.18),0,.065)
box('BaseReveal',(0,0,.20),(5.15,1.72,.06),1,.012)
for side in [-1,1]:
    x=side*1.86
    box('StorageCase',(x,.12,.69),(1.12,1.32,.92),2,.05)
    for z in [.4,.73,1.03]:
        box('Drawer',(x,-.567,z),(.98,.08,.24),0)
        box('RecessedPull',(x,-.62,z),(.32,.04,.045),1,.01)
    box('CabinetFoot',(x,0,.28),(1.24,1.47,.11),0)
box('WorkingTop',(0,0,1.24),(5.4,1.86,.18),0,.055)
box('FrontBrassEdge',(0,-.94,1.25),(5.12,.045,.045),1,.008)
box('WorkSurface',(0,-.05,1.34),(4.95,1.46,.035),2,.01)
box('ServiceBack',(0,.71,1.93),(5.0,.17,1.2),0,.06)
box('DarkInstrumentRecess',(0,.595,1.94),(4.72,.055,1.0),2,.012)
for side in [-1,1]:
    for z in [1.53,2.36]: cylinder('PanelScrew',(side*2.29,.54,z),.04,.025,1,True)

# Three deliberately different evidence modules on one shared bench.
for i,x in enumerate([-1.55,0,1.55]):
    box('ReadoutBezel%d'%i,(x,.47,2.0),(1.34,.18,.8),1,.045)
    box('ReadoutFace%d'%i,(x,.362,2.0),(1.2,.045,.65),2,.015)
    box('CaptionPlaque%d'%i,(x,-.79,1.37),(1.2,.16,.045),0,.02)
    cylinder('ControlBearing%d'%i,(x,-.44,1.42),.17,.10,1)
    # One separate semantic node per rotating control; origin set to its bearing.
    ob=cylinder('Control%d'%i,(x,-.44,1.52),.13,.10,2,False,'Control%d'%i)
    box('ControlPointer%d'%i,(x,-.53,1.58),(.04,.11,.018),0,.006,'Control%d'%i)
    for tick in range(4):
        a=tick*math.pi/2
        box('Detent%d_%d'%(i,tick),(x+math.sin(a)*.24,-.44+math.cos(a)*.24,1.4),(.04,.04,.025),1,.004)
    cylinder('SavedRecess%d'%i,(x+.49,-.48,1.4),.085,.055,1)
    cylinder('SavedLamp%d'%i,(x+.49,-.48,1.45),.06,.05,3,False,'SavedLamp%d'%i)

# Optic cradle and recorder spool; the valve manifold is physically connected.
for side in [-1,1]:
    pipe('LensRail',(-2.03+side*.03,.03,1.39),(-1.1+side*.03,.03,1.39),.025)
ring('LensCarriage',(-1.55,.02,1.62),.22,1,'FocusCarriage')
cylinder('LensGlass',(-1.55,.012,1.62),.18,.018,3,True,'FocusCarriage')
cylinder('RecorderDrum',(0,.05,1.55),.22,.35,1,False,'RecorderDrum')
for x in [1.24,1.83]:
    pipe('CoolingRiser',(x,.08,1.37),(x,.08,1.7),.045)
pipe('CoolingCrossPipe',(1.24,.08,1.69),(1.83,.08,1.69),.045)
ring('ValveWheel',(1.55,-.02,1.71),.18,1,'ValveWheel')
for side in [-1,1]: pipe('ValveSpoke',(1.55,-.02,1.71),(1.55+side*.15,-.02,1.71),.018,1,'ValveWheel')

# A complete open-front pavilion bay: columns, capitals, ribs, roof and cornice.
for side in [-1,1]:
    for y in [-.9,2.0]:
        x=side*3.55
        box('PierFoot',(x,y,.2),(.8,.8,.4),0,.05,'Pavilion')
        box('PierShaft',(x,y,2.57),(.37,.37,4.35),0,.03,'Pavilion')
        box('PierInlay',(x,y-.2,2.6),(.06,.025,3.7),1,.006,'Pavilion')
        box('Capital',(x,y,4.79),(.65,.65,.2),0,.03,'Pavilion')
    box('ServiceShelf',(side*3.3,1.0,1.15),(.85,1.2,.14),0,.035,'Pavilion')
for y in [-.9,2.0]:
    for seg in range(16):
        a=math.pi*seg/16; b=math.pi*(seg+1)/16
        pipe('ArchRib',(math.cos(a)*3.55,y,4.85+math.sin(a)*1.05),
             (math.cos(b)*3.55,y,4.85+math.sin(b)*1.05),.09,1,'Pavilion')
    box('Cornice',(0,y,4.84),(7.45,.36,.18),0,.04,'Pavilion')
for i in range(9):
    x=-3.45+i*.8625; z=4.85+math.sqrt(max(0,1-(x/3.55)**2))*1.05
    pipe('RoofPurlin',(x,-.9,z),(x,2,z),.045,1,'Pavilion')
# Opaque pale roof sections keep browser overdraw low, with narrow glazed gaps.
for i in range(8):
    x=-3.0+i*.857; z=4.85+math.sqrt(max(0,1-(x/3.55)**2))*1.05
    ob=box('RoofCoffer',(x,.55,z),(.78,2.86,.055),0,.012,'Pavilion')
    ob.rotation_euler.y=math.atan2(x,math.sqrt(max(.1,3.55**2-x*x)))*.32
box('NameFrieze',(0,-1.0,4.58),(4.4,.10,.38),2,.04,'Pavilion')

source_parts=len([o for o in bpy.context.scene.objects if o.type=='MESH'])
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'inspection_bay.blend'))
groups={}
for ob in list(bpy.context.scene.objects):
    if ob.type=='MESH': groups.setdefault(ob['assembly'],[]).append(ob)
for name,parts in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts: ob.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join()
    ob=parts[0]; ob.name=name
    bpy.context.scene.cursor.location=(0,0,0)
    if name.startswith('Control'):
        i=int(name[-1]); bpy.context.scene.cursor.location=([-1.55,0,1.55][i],-.44,1.52)
    elif name=='ValveWheel': bpy.context.scene.cursor.location=(1.55,-.02,1.71)
    elif name=='RecorderDrum': bpy.context.scene.cursor.location=(0,.05,1.55)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    mod=ob.modifiers.new('ExportTriangles','TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/'inspection_bay.glb'),export_format='GLB',use_selection=True,export_apply=True)
triangles=sum(len(ob.data.polygons) for ob in bpy.context.scene.objects if ob.type=='MESH')
(OUT/'manifest.json').write_text(json.dumps({'source_parts':source_parts,'runtime_meshes':len(groups),
    'triangles':triangles,'materials':4,'moving_parts':[n for n in groups if n not in ['Cabinet','Pavilion']],
    'bench_dimensions':[5.4,1.9,2.54],'source':'inspection_bay.blend'},indent=2))
print('INSPECTION_BAY_BUILD',source_parts,len(groups),triangles)
