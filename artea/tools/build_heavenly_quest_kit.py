"""Build the remaining Island One instruments in an isolated Blender process.

Uses the benchmark's packed texture palette; no external generation service.
Fixed parts consolidate per material; operating parts retain authored pivots.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

BASE = Path(__file__).resolve().parents[1] / 'assets3D/mind_spark/quest_kit'
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
atlas = bpy.data.images.load(str(BASE/'weight_prism/textures/quiet_surface_atlas.png'))
atlas.pack()
mats = []
for i, name in enumerate(('PearlStone', 'ChampagneBrass', 'TealEnamel', 'AquaLens')):
    m = bpy.data.materials.new(name); m.use_nodes = True
    node = m.node_tree.nodes.get('Principled BSDF')
    tex = m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image = atlas
    m.node_tree.links.new(tex.outputs['Color'], node.inputs['Base Color'])
    node.inputs['Metallic'].default_value = (.02, .65, .12, 0)[i]
    node.inputs['Roughness'].default_value = (.65, .36, .40, .23)[i]
    mats.append(m)

def group(name, at=(0,0,0)):
    ob = bpy.data.objects.new(name, None); scene.collection.objects.link(ob)
    ob.location = at
    return ob

def finish(ob, name, mat, parent, bevel=.04):
    ob.name = name; ob.data.materials.append(mats[mat])
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = ob.modifiers.new('CraftedEdge', 'BEVEL'); mod.width = bevel; mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if ob.data.uv_layers:
        for uv in ob.data.uv_layers.active.data:
            uv.uv.x = (mat+.04+uv.uv.x*.92)/4
            uv.uv.y = .04+uv.uv.y*.92
    bpy.context.view_layer.update()
    world = ob.matrix_world.copy(); ob.parent = parent; ob.matrix_world = world
    return ob

def box(name, at, size, mat=0, parent=None, bevel=.07):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    ob=bpy.context.object; ob.scale=size
    return finish(ob,name,mat,parent or fixed,bevel)

def cyl(name, at, radius, depth, mat=1, parent=None, front=False, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=at)
    ob=bpy.context.object
    if front: ob.rotation_euler.x=math.pi/2
    return finish(ob,name,mat,parent or fixed,.025)

def rod(name,a,b,r=.055,mat=1,parent=None):
    d=Vector(b)-Vector(a)
    ob=cyl(name,(Vector(a)+Vector(b))/2,r,d.length,mat,parent,vertices=8)
    ob.rotation_mode='QUATERNION'; ob.rotation_quaternion=d.to_track_quat('Z','Y')
    return ob

def ring(name,at,r,wire=.08,mat=1,parent=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=r,minor_radius=wire,
        major_segments=24,minor_segments=6,location=at,rotation=(math.pi/2,0,0))
    return finish(bpy.context.object,name,mat,parent or fixed,0)

def pivot(name,at):
    ob=group(name,at); ob.parent=root; bpy.context.view_layer.update(); return ob

def plinth(width=4.4):
    box('Foot', (0,0,.18),(width,2.65,.36),bevel=.13)
    box('BrassReveal',(0,0,.43),(width-.3,2.35,.14),1)
    box('PorcelainHousing',(0,0,1.13),(width-.8,1.95,1.22),bevel=.19)
    box('ServiceInset',(0,-.99,1.16),(width-1.5,.07,.65),2)
    box('Cornice',(0,0,1.84),(width-.5,2.2,.2))
    for x in (-width/2+.6,width/2-.6):
        cyl('AccessFastener',(x,-1.04,1.16),.055,.06,front=True,vertices=6)
    cyl('StateLensBezel',(0,-1.04,1.18),.21,.09,front=True)
    cyl('StateLens',(0,-1.1,1.18),.14,.055,3,root,front=True)

def lens(name,x,z,r=.50, parent=None):
    cyl(name+'Housing',(x,0,z),r+.14,.34,0,parent,True)
    ring(name+'Rim',(x,-.21,z),r,.065,1,parent)
    cyl(name+'Optic',(x,-.22,z),r-.07,.06,3,parent,True)

def wheel(radius=1, teeth=8):
    box('WheelSupport',(0,.26,2.76),(.8,.8,1.7),bevel=.12)
    cyl('Bearing',(0,-.12,3.46),.34,.5,front=True)
    p=pivot('Mechanism',(0,-.43,3.46))
    ring('Grip',(0,-.43,3.46),radius,.10,1,p)
    for i in range(teeth):
        a=i*math.tau/teeth; x=math.sin(a)*radius; z=3.46+math.cos(a)*radius
        rod('Spoke',(0,-.43,3.46),(x,-.43,z),.045,1,p)
        cyl('IvoryDetent',(x,-.44,z),.11,.20,0,p,True,8)
    box('FixedIndex',(0,-.55,3.46+radius+.25),(.2,.15,.24),2)
    cyl('HubCap',(0,-.57,3.46),.23,.18,2,p,True)
    rod('MovingIndex',(0,-.59,3.46),(0,-.59,3.46+radius*.78),.065,2,p)
    return p

def build(asset):
    global root,fixed
    root=group('QuestInstrument'); fixed=group('StaticBodyArt'); fixed.parent=root
    plinth(5.4 if asset in ('analysis_console','echo_question') else 4.4)
    if asset=='colour_prism':
        box('OpticalSpine',(0,.3,2.9),(.7,.7,2),bevel=.13)
        p=pivot('Mechanism',(0,0,3.65))
        for i in range(3):
            a=i*math.tau/3; x=math.sin(a)*1.0; z=3.65+math.cos(a)*1.0
            rod('LensArm',(0,0,3.65),(x,0,z),.1,1,p)
            lens('Lens%d'%i,x,z,.47,p)
        cyl('MixerHub',(0,-.25,3.65),.23,.2,1,p,True)
        box('OpticalBed',(0,-.6,2.2),(2.8,.75,.28),2)
    elif asset=='rhythm_prism':
        box('ResonatorCase',(0,.25,2.4),(3.4,1.1,.85),bevel=.18)
        for i in range(5):
            x=(i-2)*.52; h=.9+i*.20
            box('ToneBar%d'%i,(x,-.4,2.75+h/2),(.36,.24,h),1)
            cyl('BarPin',(x,-.54,2.9),.055,.08,2,front=True)
        p=pivot('Mechanism',(0,-.76,2.73))
        rod('MalletStem',(0,-.76,2.73),(0,-.76,3.5),.06,1,p)
        cyl('MalletHead',(0,-.76,3.55),.20,.25,0,p,True)
        for i in range(3): cyl('CountMark',((i-1)*.6,-.37,2.0),.09,.06,2)
    elif asset in ('west_regulator','east_regulator'):
        cyl('PressureVessel',(.7,.18,3.07),.65,2.1,0)
        for z in (2.08,4.10): cyl('VesselCollar',(.7,.18,z),.73,.16)
        box('SightGlass',(.7,-.49,3.09),(.3,.07,1.3),2)
        p=pivot('Mechanism',(.7,-.54,2.6))
        box('FluidIndicator',(.7,-.54,2.6),(.20,.04,.2),3,p)
        for z in (2.55,2.85,3.15,3.45,3.75): box('PressureTick',(1,-.5,z),(.16,.04,.025),1)
        side=-1 if asset=='west_regulator' else 1
        rod('ReturnPipe',(-1.2,.25,1.95),(-1.2,.25,4.3),.10)
        rod('ReturnHeader',(-1.2,.25,4.3),(.7,.25,4.3),.10)
        p=pivot('Valve',(-.9,-.55,2.73))
        rod('ValveSpindle',(-.9,-.55,2.73),(-.9,.25,2.73),.075)
        rod('ValveFeed',(-1.2,.25,2.73),(.7,.25,2.73),.09)
        ring('Handwheel',(-.9,-.55,2.73),.52,.075,1,p)
        for a in (0,math.pi/2,math.pi,3*math.pi/2):
            rod('ValveSpoke',(-.9,-.55,2.73),(-.9+math.sin(a)*.52,-.55,2.73+math.cos(a)*.52),.035,1,p)
        rod('FlowShaft',(.7,-.58,3.7),(.7,-.58,3.7+side*.25),.035)
        for dx in (-.12,.12): rod('FlowArrow',(.7,-.58,3.7+side*.25),(.7+dx,-.58,3.7+side*.1),.035)
    elif asset in ('outer_ring','middle_ring','inner_ring'):
        wheel({'outer_ring':1.25,'middle_ring':1.04,'inner_ring':.82}[asset])
    elif asset in ('analysis_console','echo_question') or asset.startswith('echo_signal'):
        count=4 if asset=='echo_question' else 3
        box('ReadingDesk',(0,.05,2.5),(4.5 if count==4 or asset=='analysis_console' else 3.5,.66,1.05),bevel=.16)
        for i in range(count):
            x=(i-(count-1)/2)*.86
            box('CardSocket',(x,-.35,2.7),(.76,.12,1.2),1)
            p=pivot('Card%d'%i,(x,-.45,2.7))
            box('PorcelainCard',(x,-.45,2.7),(.64,.10,1.04),0,p)
            box('CardEnamelHeader',(x,-.51,3.0),(.45,.03,.18),2,p)
            for j in range(i+1): box('TactileMark',(x-.18+j*.10,-.51,2.57),(.055,.025,.2),1,p,.01)
        if asset=='analysis_console':
            rod('ComparisonArm',(1.7,.1,1.94),(1.7,.1,4.0),.09)
            rod('ComparisonCrossbar',(1.7,.1,4),(.1,.1,4),.09)
            lens('ComparisonLens',0,3.8,.37)
        else:
            p=pivot('Mechanism',(0,-.8,2.04))
            box('SelectorHandle',(0,-.8,2.04),(.48,.35,.18),2,p)
    elif asset=='confirm':
        box('LeverStand',(-.8,0,2.5),(.7,.85,1.1),bevel=.13)
        p=pivot('Mechanism',(-.8,-.35,2.7))
        rod('SendLever',(-.8,-.35,2.7),(-.8,-.35,3.6),.09,1,p)
        box('SendGrip',(-.8,-.35,3.6),(.75,.28,.24),2,p)
        for x in (-1.45,-.15): rod('LeverGuard',(x,.1,2),(x,.1,3.8),.07)
        rod('GuardHeader',(-1.45,.1,3.8),(-.15,.1,3.8),.07)
        cyl('PrismSocket',(.8,0,2.2),.62,.45)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.50,location=(.8,0,2.9))
        finish(bpy.context.object,'SignalCrystal',3,fixed,0)
        rod('OutputPipe',(.8,.65,2.15),(.8,.65,.55),.10)
    elif asset=='echo_collector':
        cyl('Reservoir',(0,0,2.9),.65,1.75,0)
        for z in (2.06,3.73): cyl('ReservoirBand',(0,0,z),.73,.14)
        for i in range(3):
            x=(i-1)*1.2; z=4.3-abs(i-1)*.35
            rod('IntakeTube',(x,.2,z),(x,.2,3.8),.09)
            rod('ConvergingTube',(x,.2,3.8),(0,.2,3.3),.09)
            bpy.ops.mesh.primitive_cone_add(vertices=16,radius1=.18,radius2=.53,depth=.68,location=(x,-.22,z),rotation=(math.pi/2,0,0))
            finish(bpy.context.object,'ReceivingHorn',1,fixed)
            cyl('HornInset',(x,-.57,z),.43,.04,2,front=True)
            p=pivot('Charge%d'%i,(0,-.66,2.35+i*.43))
            box('ChargeWindow',(0,-.66,2.35+i*.43),(.40,.045,.24),3,p)
    elif asset=='echo_beacon':
        cyl('ChargeColumn',(0,0,2.55),.65,1.2,0)
        cyl('CrystalCradle',(0,0,3.2),.83,.22)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.75,location=(0,0,4))
        ob=bpy.context.object; ob.scale=(.8,.8,1.45)
        p=pivot('Mechanism',(0,0,4)); finish(ob,'WisdomCrystal',3,p,0)
        for x in (-.93,.93):
            rod('CradleArm',(x,0,2.0),(x,0,4.25),.075)
            rod('CradleShoulder',(x,0,2),(x*.4,0,1.95),.075)
        rod('OutputMast',(0,.6,2),(0,.6,5),.07)
        cyl('MastFinial',(0,.6,5),.16,.16,0)
    bpy.context.view_layer.update()
    return root

ids=['colour_prism','rhythm_prism','analysis_console','west_regulator','east_regulator',
     'outer_ring','middle_ring','inner_ring','confirm','echo_collector',
     'echo_signal_1','echo_signal_2','echo_signal_3','echo_question','echo_beacon']
records=[]
for asset in ids:
    for ob in list(scene.objects): bpy.data.objects.remove(ob,do_unlink=True)
    root=build(asset)
    out=BASE/asset
    for folder in ('source','export','previews'): (out/folder).mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'source'/f'{asset}.blend'))
    source_parts=sum(ob.type=='MESH' for ob in scene.objects)
    for parent in [ob for ob in scene.objects if ob.type=='EMPTY']:
        parts=[ob for ob in parent.children if ob.type=='MESH' and ob.name!='StateLens']
        if len(parts)>1:
            bpy.ops.object.select_all(action='DESELECT')
            for ob in parts: ob.select_set(True)
            bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join()
            parts[0].name=parent.name+'Mesh'
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(out/'export'/f'{asset}.glb'),export_format='GLB',use_selection=True,export_apply=True)
    tris=0; meshes=0
    for ob in scene.objects:
        if ob.type=='MESH':
            ob.data.calc_loop_triangles(); tris+=len(ob.data.loop_triangles); meshes+=1
    rec={'id':asset,'revision':'heavenly_kit_02','triangles':tris,'runtime_mesh_nodes':meshes,
         'editable_source_meshes':source_parts,'materials':4,'atlas_size':1024,
         'moving_groups':[ob.name for ob in scene.objects if ob.type=='EMPTY' and ob not in (root,fixed)]}
    (out/'manifest.json').write_text(json.dumps(rec,indent=2)); records.append(rec)
(BASE/'heavenly_kit_manifest.json').write_text(json.dumps(records,indent=2))
# A single contact sheet renders the actual exports, not generated concept art.
for ob in list(scene.objects): bpy.data.objects.remove(ob,do_unlink=True)
for i,asset in enumerate(ids):
    before=set(scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(BASE/asset/'export'/f'{asset}.glb'))
    for ob in set(scene.objects)-before:
        if ob.parent is None: ob.location += Vector(((i%5-2)*6.5,(i//5)*8,0))
scene.render.engine='CYCLES'; scene.cycles.samples=24
scene.render.resolution_x=1800; scene.render.resolution_y=1100; scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Studio'); scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.5,.6,.68,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
for at,power in [((0,-12,20),6000),((12,10,20),7000)]:
    data=bpy.data.lights.new('Softbox','AREA'); data.energy=power; data.size=20
    ob=bpy.data.objects.new('Softbox',data); scene.collection.objects.link(ob); ob.location=at
    ob.rotation_euler=(Vector((0,8,2))-ob.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('KitReview'); cam=bpy.data.objects.new('KitReview',data)
scene.collection.objects.link(cam); cam.location=(12,-32,30)
cam.rotation_euler=(Vector((0,8,2))-cam.location).to_track_quat('-Z','Y').to_euler()
data.type='ORTHO'; data.ortho_scale=38; scene.camera=cam
scene.render.filepath=str(BASE/'heavenly_kit_contact_sheet.png')
bpy.ops.render.render(write_still=True)
print('HEAVENLY_KIT_COMPLETE',sum(r['triangles'] for r in records),len(records))
