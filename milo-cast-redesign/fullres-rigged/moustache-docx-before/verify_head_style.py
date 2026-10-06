"""Reimport the final GLB: face topology, eye style and actual blink frames."""
from pathlib import Path
import bpy,bmesh,math,json,hashlib
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'milo_fullres.glb'))
scene=bpy.context.scene
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
rig.animation_data.action=None
for tr in rig.animation_data.nla_tracks:tr.mute=True
for pb in rig.pose.bones:pb.matrix_basis.identity()
scene.frame_set(0);bpy.context.view_layer.update()
assert len(rig.data.bones)==61
meshes=[o for o in scene.objects if o.type=='MESH']
assert not any(o.name.startswith(('EyeGlint','EyeSocket','Glasses_InnerLip')) for o in meshes)
# The latest DOCX request explicitly restores two separate cream cheek tufts
# per side. Their attachment and closed topology are checked in verify_cat_paws.
core=bpy.data.objects['Head_Cranium_AnyCreature']
eyes=[bpy.data.objects['Eye_'+str(s)] for s in (-1,1)]
topology={}
for o in [core]+eyes:
    bm=bmesh.new();bm.from_mesh(o.data)
    bad=sum(not e.is_manifold for e in bm.edges)
    todo=set(bm.verts);components=0
    while todo:
        components+=1;stack=[todo.pop()]
        while stack:
            for e in stack.pop().link_edges:
                for v in e.verts:
                    if v in todo:todo.remove(v);stack.append(v)
    topology[o.name]={'nonmanifold_edges':bad,'connected_components':components,'triangles':len(o.data.polygons)}
    bm.free();assert bad==0 and components==1,(o.name,topology[o.name])
    assert all(p.use_smooth for p in o.data.polygons),o.name
for eye in eyes:
    assert len(eye.data.materials)==1
    assert eye.data.materials[0].name.startswith('Milo eyes - cast charcoal oval')
    extent=[max(v.co[i] for v in eye.data.vertices)-min(v.co[i] for v in eye.data.vertices) for i in (0,2)]
    assert .085<extent[0]<.10 and .12<extent[1]<.14,extent
    used={eye.vertex_groups[g.group].name for v in eye.data.vertices for g in v.groups if g.weight>1e-6}
    assert len(used)==1 and next(iter(used)).startswith('eye.'),used

# Measure blink in head-local coordinates, so body/neck movement cannot
# masquerade as an eyelid change. The simplified design still uses eye squash.
blink={}
for tr in rig.animation_data.nla_tracks:
    action=tr.strips[0].action;rig.animation_data.action=action
    if action.slots:rig.animation_data.action_slot=action.slots[0]
    ratios=[]
    for f in range(round(action.frame_range[0]),round(action.frame_range[1])+1):
        scene.frame_set(f);bpy.context.view_layer.update()
        for eye in eyes:
            assert all(math.isfinite(c) for v in eye.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices for c in v.co)
        ratios.append(min(rig.pose.bones['eye.'+s].scale.y for s in ('L','R')))
    assert min(ratios)<.35 and max(ratios)>.99,(tr.name,min(ratios))
    blink[tr.name]={'frames':len(ratios),'minimum_vertical_scale':min(ratios),'maximum_vertical_scale':max(ratios)}
report={'passed':True,'sha256':hashlib.sha256((OUT/'milo_fullres.glb').read_bytes()).hexdigest(),
        'topology':topology,'single_dark_material_per_eye':True,'iris_sclera_glint_socket_geometry_removed':True,
        'all_face_normals_smooth':True,'blink':blink,'limitations':'Eye-bone compression, not anatomically modeled eyelids. Visual style requires image review.'}
(OUT/'head_style_verification.json').write_text(json.dumps(report,indent=2));print('HEAD_STYLE_PASS',json.dumps(report),flush=True)

# Render open / peak blink / open-again from the final GLB, not the blend.
idle=next(t.strips[0].action for t in rig.animation_data.nla_tracks if t.name.startswith('Idle'))
rig.animation_data.action=idle
if idle.slots:rig.animation_data.action_slot=idle.slots[0]
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
world=bpy.data.worlds.new('Face animation studio');world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.055,.075,.09,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.65;scene.world=world
for loc,power,size in [((-3,-4,5),340,4),((4,-2,3),115,4),((0,-4,1),85,4)]:
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=size;aim(o,(0,0,1.3))
bpy.ops.object.camera_add(location=(.1,-8,1.6));scene.camera=bpy.context.object
scene.camera.data.type='ORTHO';scene.camera.data.ortho_scale=1.02;aim(scene.camera,(0,0,1.35))
scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=32
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.render.resolution_x=700;scene.render.resolution_y=700;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='JPEG';scene.render.image_settings.quality=95
for label,frame in [('open',0),('closing',60),('blink',61),('reopened',66)]:
    scene.frame_set(frame);scene.render.filepath=str(OUT/('face_'+label+'.jpg'));bpy.ops.render.render(write_still=True)
