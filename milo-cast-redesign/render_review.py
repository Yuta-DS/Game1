from pathlib import Path
import bpy,math,sys
from mathutils import Vector
OUT=Path(__file__).resolve().parent;ASSETS=OUT.parent/'artea/assets3D/characters'
bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
def load(path,label,x,scale=1):
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path));new=set(bpy.data.objects)-before
    for o in list(new):
        if o.type=='MESH' and (not len(o.data.materials) or any(s in o.name for s in ('Crossbow','Knife','Throwable','Spell','Book','Staff','Axe','Shield','Sword'))):new.remove(o);bpy.data.objects.remove(o,do_unlink=True)
    for o in new:
        if o.type=='ARMATURE' and o.animation_data:
            ad=o.animation_data
            for tr in ad.nla_tracks:
                tr.mute=True
                if tr.name=='Idle':ad.action=tr.strips[0].action;ad.action_slot=tr.strips[0].action_slot
    group=bpy.data.objects.new(label,None);scene.collection.objects.link(group)
    for o in new:
        if o.parent not in new:o.parent=group
    group.location.x=x;group.scale=(scale,)*3
    return group,new
mode=sys.argv[-1] if '--' in sys.argv else 'lineup'
if mode=='lineup':
    load(ASSETS/'Rogue.glb','Rogue',-2.7);load(ASSETS/'Mage.glb','Mage',-1.35);load(OUT/'milo_cast.glb','Milo',0);load(ASSETS/'Barbarian.glb','Barbarian',1.35);load(ASSETS/'fox.glb','Fox',2.7,1.5)
    camera=(2,-13,5);target=(0,0,1.1);ortho=7.2;size=(1800,850)
else:
    load(OUT/'milo_cast.glb','Milo',0);camera=(2.3,-6,3.3) if mode=='hero' else (0,-6,2.7);target=(0,0,1.1) if mode=='hero' else (0,-.05,1.69);ortho=2.65 if mode=='hero' else 1.25;size=(950,1050)
scene.frame_set(0)
world=bpy.data.worlds.new('Cast neutral ambient');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.38,.42,.48,1);world.node_tree.nodes['Background'].inputs[1].default_value=.7;scene.world=world
bpy.ops.object.light_add(type='AREA',location=(-3,-5,7));bpy.context.object.data.energy=700;bpy.context.object.data.size=7;aim(bpy.context.object,(0,0,1))
bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;m=bpy.data.materials.new('Neutral ground');m.diffuse_color=(.26,.29,.32,1);floor.data.materials.append(m)
bpy.ops.object.camera_add(location=camera);scene.camera=bpy.context.object;scene.camera.data.type='ORTHO';scene.camera.data.ortho_scale=ortho;aim(scene.camera,target)
scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=24;scene.render.resolution_x,scene.render.resolution_y=size;scene.render.resolution_percentage=100;scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/(mode+'.png'));bpy.ops.render.render(write_still=True)
print('REVIEW_RENDER',mode,flush=True)
