"""Render the exported static GLB; no concept-image substitutions."""
from pathlib import Path
import bpy,math,sys
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
def load(x=0,angle=0):
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(OUT/'milo_likeness.glb'));new=set(bpy.data.objects)-before
    g=bpy.data.objects.new('Milo review orientation',None);scene.collection.objects.link(g)
    for o in new:
        if o.parent not in new:o.parent=g
    g.location.x=x;g.rotation_euler.z=angle;return g
group=load()
world=bpy.data.worlds.new('Navy reference studio');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.055,.075,.09,1);world.node_tree.nodes['Background'].inputs[1].default_value=.6;scene.world=world
for loc,power,size in [((-3,-4,5),340,4),((4,-2,3),115,4),((0,-4,1),85,4),((1,3,4),220,3)]:
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=size;aim(o,(0,0,1))
bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;m=bpy.data.materials.new('Navy ground');m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.004,.012,.023,1);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.93;floor.data.materials.append(m)
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO'
scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=64;scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.render.image_settings.file_format='JPEG';scene.render.image_settings.quality=96
modes=[sys.argv[-1]] if '--' in sys.argv else ['front','hero','side','back','face','paws','turnaround']
for mode in modes:
    group.rotation_euler.z=0;cam.location=(0,-8,1.70);target=(0,0,.95);cam.data.ortho_scale=2.14;size=(800,1000)
    if mode=='hero':cam.location=(3.2,-8,2.0)
    if mode=='side':group.rotation_euler.z=math.pi/2
    if mode=='back':group.rotation_euler.z=math.pi
    if mode=='face':cam.location=(.20,-8,1.75);target=(0,-.04,1.43);cam.data.ortho_scale=1.25;size=(900,900)
    if mode=='paws':cam.location=(2,-6,1.15);target=(.52,-.01,.48);cam.data.ortho_scale=.43;size=(700,700)
    if mode=='turnaround':
        group.location.x=-2.15;load(-.72,.52);load(.72,math.pi/2);load(2.15,math.pi)
        cam.location=(0,-10,1.85);target=(0,0,.95);cam.data.ortho_scale=6.4;size=(1600,600)
    aim(cam,target);scene.render.resolution_x,scene.render.resolution_y=size;scene.render.resolution_percentage=100;scene.render.filepath=str(OUT/(mode+'.jpg'));bpy.ops.render.render(write_still=True);print('SCULPT_RENDER',mode,flush=True)
