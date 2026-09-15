"""Neutral review from the exported GLB; shared cast-loading helper only."""
from pathlib import Path
import bpy,sys
from mathutils import Vector
OUT=Path(__file__).resolve().parent
helpers=OUT.parent/'statue-face-paws/render_review.py'
exec(compile(helpers.read_text().split('mode=sys.argv')[0],str(helpers),'exec'))
mode=sys.argv[-1] if '--' in sys.argv else 'hero'
load(OUT/'milo_natural_face_grip.glb','Milo',0)
camera=(2.3,-6,3.1);target=(0,0,1.05);ortho=2.5;size=(850,1000)
if mode=='face':camera=(.4,-6,2.05);target=(0,-.03,1.67);ortho=1.08;size=(900,900)
if mode=='face_side':camera=(4,-6,2.4);target=(0,-.03,1.67);ortho=1.08;size=(900,900)
if mode=='paw_left':camera=(1.4,-4,1.2);target=(.56,-.015,.71);ortho=.45;size=(750,750)
if mode=='paw_right':camera=(-1.5,-4,1.15);target=(-.565,-.12,.724);ortho=.52;size=(750,750)
if mode=='grip_side':camera=(-3,-1.2,1.3);target=(-.565,-.12,.724);ortho=.52;size=(750,750)
if mode=='lineup':
    load(ASSETS/'Rogue.glb','Rogue',-2.7);load(ASSETS/'Mage.glb','Mage',-1.35);load(ASSETS/'Barbarian.glb','Barbarian',1.35);load(ASSETS/'fox.glb','Fox',2.7,1.5)
    camera=(2,-13,5);target=(0,0,1.1);ortho=7.2;size=(1600,760)
scene.frame_set(0)
world=bpy.data.worlds.new('Neutral ambient');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.38,.42,.48,1);world.node_tree.nodes['Background'].inputs[1].default_value=.7;scene.world=world
bpy.ops.object.light_add(type='AREA',location=(-3,-5,7));bpy.context.object.data.energy=700;bpy.context.object.data.size=7;aim(bpy.context.object,(0,0,1))
bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;m=bpy.data.materials.new('Neutral ground');m.diffuse_color=(.26,.29,.32,1);floor.data.materials.append(m)
bpy.ops.object.camera_add(location=camera);scene.camera=bpy.context.object;scene.camera.data.type='ORTHO';scene.camera.data.ortho_scale=ortho;aim(scene.camera,target)
scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=48;scene.render.resolution_x,scene.render.resolution_y=size;scene.render.resolution_percentage=100;scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.render.image_settings.file_format='JPEG';scene.render.image_settings.quality=97;scene.render.filepath=str(OUT/(mode+'.jpg'));bpy.ops.render.render(write_still=True)
print('NATURAL_FACE_GRIP_RENDER',mode,flush=True)
