"""Editable low-poly quest family using the approved memory-board atlas.
Run with Blender --background --python. Existing assets are not overwritten.
"""
import bpy, math, json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets3D/mind_spark/quest_kit/memory_style_family'
SLUGS = ['thought_spark_socket','evidence_scanner','perspective_lens',
         'logic_gate_arch','truth_bridge_tile','focus_bell_beacon','warden_anchor',
         'calm_rain_basin','identity_reflection_mirror','checkpoint_server_root','clear_path_projector']
REPORT = []

def finish(ob, name, mat=0, bevel=.025):
    ob.name = name
    ob.data.materials.append(MATS[mat])
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
    ob=bpy.context.object; ob.scale=size
    return finish(ob,name,mat,bevel)

def disc(name,at,radius,depth,mat=1,front=True):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=radius,depth=depth,
        location=at,rotation=(math.pi/2,0,0) if front else (0,0,0))
    return finish(bpy.context.object,name,mat,.012)

def ring(name,at,radius,minor=.04,mat=1,front=True):
    bpy.ops.mesh.primitive_torus_add(major_segments=20,minor_segments=6,
        major_radius=radius,minor_radius=minor,location=at,
        rotation=(math.pi/2,0,0) if front else (0,0,0))
    return finish(bpy.context.object,name,mat,0)

def crystal(name,at,radius=.16):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=radius,location=at)
    return finish(bpy.context.object,name,3,0)

def base(flat=False):
    box('SteppedFoot',(0,0,.08),(1.95,.95,.16),bevel=.055)
    box('BrassReveal',(0,0,.18),(1.80,.83,.06),1)
    if not flat:
        box('TealCabinet',(0,.08,.44),(1.2,.47,.48),2,.05)
        for x in [-.67,.67]: box('IvorySupport',(x,.08,.44),(.22,.49,.48),0,.04)
        box('ReadingLedge',(0,-.02,.72),(1.9,.87,.16),0,.045)
        box('ApronInlay',(0,-.459,.70),(1.70,.012,.035),1,.004)
        for x in [-.42,0,.42]:
            box('CabinetFlute',(x,-.166,.43),(.018,.018,.30),1,.004)

def panel(z=1.22):
    box('IvoryHousing',(0,.11,z),(1.8,.30,.91),0,.06)
    box('BrassFrame',(0,-.06,z),(1.67,.055,.78),1)
    box('TealRecess',(0,-.10,z),(1.56,.035,.67),2)
    for x in [-.74,.74]:
        for dz in [-.29,.29]: disc('Fastener',(x,-.133,z+dz),.025,.018,1)

for slug in SLUGS:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    atlas=bpy.data.images.load(str(ROOT/'assets3D/mind_spark/quest_kit/weight_prism/textures/quiet_surface_atlas.png'))
    atlas.pack(); MATS=[]
    for i,name in enumerate(['PearlStone','ChampagneBrass','TealEnamel','AquaLens']):
        m=bpy.data.materials.new(name); m.use_nodes=True
        shader=m.node_tree.nodes.get('Principled BSDF')
        tex=m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=atlas
        m.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
        shader.inputs['Metallic'].default_value=[.02,.65,.12,0][i]
        shader.inputs['Roughness'].default_value=[.65,.45,.42,.30][i]
        MATS.append(m)
    moving=[]
    flat=slug in ['logic_gate_arch','truth_bridge_tile','calm_rain_basin']
    base(flat)
    if slug=='evidence_scanner':
        panel()
        for x in [-.47,0,.47]:
            box('DocumentPlate',(x,-.16,1.18),(.36,.08,.47),0)
            for z in [1.07,1.17,1.27]: box('InscribedLine',(x,-.21,z),(.23,.01,.013),2,.002)
        moving.append(box('Mechanism',(0,-.255,1.18),(1.43,.025,.055),3,.008))
    elif slug=='thought_spark_socket':
        for i,x in enumerate([-.53,0,.53]):
            disc('Receiver',(x,-.32,.87),.18,.13,0,False)
            ring('Bearing',(x,-.32,.95),.14,.035,1,False)
            disc('EmptySocket',(x,-.32,.94),.11,.025,2,False)
            moving.append(crystal('Charge%d'%i,(x,-.32,1.08),.13))
        panel(1.42)
        for x in [-.55,.55]: box('Channel',(x,-.14,1.42),(.055,.04,.48),1)
    elif slug in ['perspective_lens','identity_reflection_mirror']:
        for x in [-.64,.64]: box('LensSupport',(x,.06,1.1),(.13,.19,.68),0)
        ring('IvoryOpticFrame',(0,0,1.47),.58,.075,0)
        ring('BrassOpticFrame',(0,-.07,1.47),.49,.035,1)
        moving.append(disc('Mechanism',(0,-.075,1.47),.45,.06,3))
        if slug=='perspective_lens':
            for x in [-.28,0,.28]:
                part=box('OpticGuide',(x,-.115,1.47),(.012,.01,.54),2,.002)
                bpy.context.view_layer.update()
                matrix=part.matrix_world.copy(); part.parent=moving[0]; part.matrix_world=matrix
        else:
            box('ReflectiveInlay',(-.16,-.116,1.51),(.035,.012,.47),0,.005)
    elif slug=='logic_gate_arch':
        for x in [-.82,.82]:
            box('GatePier',(x,0,1.75),(.28,.56,3.05),0,.055)
            box('FlutedGold',(x,-.294,1.75),(.055,.018,2.57),1,.005)
            box('Capital',(x,0,3.33),(.40,.64,.17),0)
        box('Lintel',(0,0,3.5),(2.12,.67,.20),0,.055)
        box('Cornice',(0,0,3.65),(2.28,.76,.10),1)
        moving.append(box('Mechanism',(0,0,.8),(1.28,.12,1.35),2,.035))
        for x in [-.45,0,.45]:
            part=box('DoorGoldFlute',(x,-.076,.8),(.025,.028,1.15),1,.005)
            matrix=part.matrix_world.copy(); part.parent=moving[0]; part.matrix_world=matrix
    elif slug=='truth_bridge_tile':
        box('IvoryTile',(0,0,.27),(1.86,.90,.12),0,.045)
        box('TealTile',(0,0,.34),(1.63,.70,.04),2)
        for x in [-.55,0,.55]: box('CircuitRail',(x,0,.375),(.025,.54,.018),1,.004)
        moving.append(box('Mechanism',(0,0,.39),(1.50,.025,.025),3,.004))
    elif slug=='focus_bell_beacon':
        for x in [-.56,.56]: box('BellPillar',(x,.06,1.29),(.13,.20,1.03),0)
        box('BellLintel',(0,.06,1.85),(1.37,.29,.13),0)
        box('BellSuspension',(0,0,1.77),(.06,.06,.18),1,.008)
        bpy.ops.mesh.primitive_cone_add(vertices=16,radius1=.36,radius2=.14,depth=.49,location=(0,0,1.48))
        finish(bpy.context.object,'Bell',1)
        ring('BellLip',(0,0,1.22),.36,.035,1,False)
        moving.append(crystal('Mechanism',(0,0,1.24),.09))
    elif slug=='warden_anchor':
        panel(1.34)
        moving.append(disc('Mechanism',(0,-.22,1.34),.48,.16,1))
        disc('ShieldInset',(0,-.31,1.34),.37,.04,2)
        moving.append(crystal('Reward',(0,-.39,1.34),.23))
    elif slug=='calm_rain_basin':
        disc('BasinBody',(0,0,.43),.77,.45,0,False)
        ring('GoldRim',(0,0,.67),.68,.055,1,False)
        disc('BasinInterior',(0,0,.65),.62,.025,2,False)
        moving.append(disc('Mechanism',(0,0,.68),.58,.018,3,False))
        for x in [-.83,.83]: box('BasinPier',(x,0,.52),(.16,.27,.56),0)
    elif slug=='checkpoint_server_root':
        panel(1.32)
        for z in [1.05,1.30,1.55]:
            box('ArchiveDrawer',(0,-.16,z),(1.33,.14,.18),0)
            box('DrawerHandle',(0,-.25,z),(.29,.055,.04),1,.006)
        moving.append(box('Mechanism',(0,-.12,1.78),(.63,.08,.055),3,.01))
    elif slug=='clear_path_projector':
        disc('Turntable',(0,0,.85),.48,.10,1,False)
        box('ProjectorHousing',(0,.07,1.12),(.78,.60,.47),0,.07)
        ring('ProjectorBarrel',(0,-.31,1.13),.26,.065,1)
        moving.append(disc('Mechanism',(0,-.34,1.13),.19,.045,3))
        for x in [-.24,0,.24]: box('Vent',(x,.08,1.37),(.035,.29,.02),2,.004)
    # Common labelled indicator bar, with discrete states readable without bloom.
    if not flat:
        box('ActionCaptionPlate',(0,-.474,.63),(1.10,.035,.10),0,.012)
    indicator_z = .13 if flat else .76
    staged = slug in ['thought_spark_socket','evidence_scanner','perspective_lens','logic_gate_arch']
    positions = [-.10,.10] if slug == 'logic_gate_arch' else ([-.19,0,.19] if staged else [0])
    for i,x in enumerate(positions):
        box('IndicatorRecess',(x,-.49,indicator_z),(.14,.035,.07),2,.01)
        moving.append(box('Status%d'%i,(x,-.515,indicator_z),(.10,.016,.04),3,.008))
    output=OUT/slug
    (output/'source').mkdir(parents=True,exist_ok=True)
    (output/'export').mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output/'source'/f'{slug}.blend'))
    source_count=sum(ob.type=='MESH' for ob in bpy.context.scene.objects)
    for parent in moving:
        if parent.children:
            bpy.ops.object.select_all(action='DESELECT')
            for child in list(parent.children): child.select_set(True)
            parent.select_set(True); bpy.context.view_layer.objects.active=parent; bpy.ops.object.join()
    static=[ob for ob in bpy.context.scene.objects if ob.type=='MESH' and ob not in moving]
    bpy.ops.object.select_all(action='DESELECT')
    for ob in static: ob.select_set(True)
    bpy.context.view_layer.objects.active=static[0]; bpy.ops.object.join(); static[0].name='StaticBodyArt'
    for ob in bpy.context.scene.objects:
        if ob.type=='MESH':
            mod=ob.modifiers.new('ExportTriangles','TRIANGULATE')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(output/'export'/f'{slug}.glb'),export_format='GLB',use_selection=True,export_apply=True)
    triangles=0
    for ob in bpy.context.scene.objects:
        if ob.type=='MESH': ob.data.calc_loop_triangles(); triangles+=len(ob.data.loop_triangles)
    REPORT.append({'asset':slug,'source_meshes':source_count,'runtime_meshes':1+len(moving),'triangles':triangles,'dynamic_parts':[ob.name for ob in moving]})
(OUT/'manifest.json').write_text(json.dumps({'style':'memory-board-family-v1','materials':4,'assets':REPORT},indent=2))
