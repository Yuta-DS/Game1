"""Read-only cast inspection; writes only the isolated redesign folder."""
from pathlib import Path
import json,math
import bpy
from mathutils import Vector
OUT=Path(__file__).resolve().parent
ASSETS=OUT.parent/'artea/assets3D/characters'
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene;report={}
def aim(obj,target):obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
def import_cast(path,label,x):
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path));new=set(bpy.data.objects)-before
    for obj in new:
        if obj.type=='ARMATURE' and obj.animation_data:
            ad=obj.animation_data
            for tr in ad.nla_tracks:
                tr.mute=True
                if tr.name=='Idle':
                    ad.action=tr.strips[0].action
                    if hasattr(tr.strips[0],'action_slot'):ad.action_slot=tr.strips[0].action_slot
    scene.frame_set(1);bpy.context.view_layer.update()
    meshes=[o for o in new if o.type=='MESH' and len(o.data.materials)]
    dg=bpy.context.evaluated_depsgraph_get()
    pts=[o.matrix_world@Vector(p) for o in meshes for p in o.evaluated_get(dg).bound_box]
    lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)));hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
    rig=next((o for o in new if o.type=='ARMATURE'),None)
    report[label]={'path':str(path),'bounds':[list(lo),list(hi)],'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),'materials':list(set(m.name for o in meshes for m in o.data.materials)),'bones':[{ 'name':b.name,'head':list(b.head_local),'tail':list(b.tail_local)} for b in rig.data.bones] if rig else [],'objects':[{ 'name':o.name,'vertices':len(o.data.vertices),'materials':[m.name for m in o.data.materials]} for o in meshes]}
    group=bpy.data.objects.new(label,None);scene.collection.objects.link(group)
    for obj in new:
        if obj.parent not in new:obj.parent=group
    scale=1.9/(hi.z-lo.z);group.scale=(scale,)*3;group.location=(x,-(lo.y+hi.y)*.5*scale,-lo.z*scale)
    bpy.ops.object.text_add(location=(x,-.5,.025));txt=bpy.context.object;txt.data.body=label;txt.data.align_x='CENTER';txt.data.size=.15;txt.rotation_euler=(math.radians(90),0,0)

for label,path,x in [('Rogue',ASSETS/'Rogue.glb',-3.1),('Mage',ASSETS/'Mage.glb',-1.55),('Barbarian',ASSETS/'Barbarian.glb',0),('Fox',ASSETS/'fox.glb',1.55),('Previous Milo',OUT.parent/'milo-quality-v2/milo_quality_v2.glb',3.1)]:import_cast(path,label,x)
world=bpy.data.worlds.new('Neutral daylight');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.38,.42,.48,1);world.node_tree.nodes['Background'].inputs[1].default_value=.7;scene.world=world
bpy.ops.object.light_add(type='AREA',location=(-3,-5,7));bpy.context.object.data.energy=850;bpy.context.object.data.size=7;aim(bpy.context.object,(0,0,1))
bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;mat=bpy.data.materials.new('Matte neutral');mat.diffuse_color=(.19,.22,.25,1);floor.data.materials.append(mat)
bpy.ops.object.camera_add(location=(2,-12,4.1));scene.camera=bpy.context.object;scene.camera.data.type='ORTHO';scene.camera.data.ortho_scale=8.2;aim(scene.camera,(0,0,1))
scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=32;scene.render.resolution_x=1800;scene.render.resolution_y=700;scene.render.resolution_percentage=100;scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/'cast_reference.png');bpy.ops.render.render(write_still=True)
(OUT/'cast_inventory.json').write_text(json.dumps(report,indent=2))
print('CAST_INSPECTION_DONE',flush=True)
