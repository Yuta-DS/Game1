"""Real GLB renders aligned with the supplied reference sheet."""
from pathlib import Path
import bpy,math,sys
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
def load(x=0,angle=0):
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(OUT/'milo_reference.glb'));new=set(bpy.data.objects)-before
    for o in new:
        if o.type=='ARMATURE' and o.animation_data:
            ad=o.animation_data
            for tr in ad.nla_tracks:
                tr.mute=True
                if tr.name=='Idle':ad.action=tr.strips[0].action;ad.action_slot=tr.strips[0].action_slot
    g=bpy.data.objects.new('Review character',None);scene.collection.objects.link(g)
    for o in new:
        if o.parent not in new:o.parent=g
    g.location.x=x;g.rotation_euler.z=angle;return g
group=load();scene.frame_set(0)
world=bpy.data.worlds.new('Reference navy studio');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.06,.09,.12,1);world.node_tree.nodes['Background'].inputs[1].default_value=.55;scene.world=world
for loc,power,size in [((-3,-4,6),460,5),((4,-2,4),160,4),((1,4,5),300,4),((0,-4,1.0),180,4)]:
    bpy.ops.object.light_add(type='AREA',location=loc);bpy.context.object.data.energy=power;bpy.context.object.data.size=size;aim(bpy.context.object,(0,0,1.15))
bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;m=bpy.data.materials.new('Dark blue ground');m.use_nodes=True;m.diffuse_color=(.006,.014,.024,1);m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=m.diffuse_color;m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.95;floor.data.materials.append(m)
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO'
scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=48;scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.render.image_settings.file_format='JPEG';scene.render.image_settings.quality=96
modes=[sys.argv[-1]] if '--' in sys.argv else ['front','hero','side','back','face','paws','turnaround']
for mode in modes:
    group.rotation_euler.z=0;cam.location=(0,-7,1.95);target=(0,0,.94);cam.data.ortho_scale=2.22;size=(800,1000)
    if mode=='hero':cam.location=(3.4,-7,2.40)
    if mode=='side':group.rotation_euler.z=math.pi/2
    if mode=='back':group.rotation_euler.z=math.pi
    if mode=='face':cam.location=(.3,-7,1.92);target=(0,-.05,1.44);cam.data.ortho_scale=1.23;size=(900,900)
    if mode=='paws':cam.location=(2,-5,1.4);target=(.46,-.015,.57);cam.data.ortho_scale=.49;size=(750,750)
    if mode=='turnaround':
        group.location.x=-2.10;load(-.70,.55);load(.70,math.pi/2);load(2.10,math.pi);scene.frame_set(0);cam.location=(0,-10,2.1);target=(0,0,.94);cam.data.ortho_scale=6.2;size=(1600,600)
    aim(cam,target);scene.render.resolution_x,scene.render.resolution_y=size;scene.render.resolution_percentage=100;scene.render.filepath=str(OUT/(mode+'.jpg'));bpy.ops.render.render(write_still=True);print('REFERENCE_RENDER',mode,flush=True)
