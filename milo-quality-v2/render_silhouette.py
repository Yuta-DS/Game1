from pathlib import Path
import sys,bpy
OUT=Path(__file__).resolve().parent;sys.path.insert(0,str(OUT))
from review import load,select_clip,aim
scene=load();select_clip('Idle');scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=16
scene.render.resolution_x=512;scene.render.resolution_y=512
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(1,1,1,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=1
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
mat=bpy.data.materials.new('Silhouette black');mat.use_nodes=True
mat.node_tree.nodes.clear();out=mat.node_tree.nodes.new('ShaderNodeOutputMaterial');em=mat.node_tree.nodes.new('ShaderNodeEmission');em.inputs['Color'].default_value=(0,0,0,1);mat.node_tree.links.new(em.outputs[0],out.inputs[0])
bpy.context.view_layer.material_override=mat
bpy.data.objects['STUDIO_floor'].hide_render=True
folder=OUT/'silhouettes';folder.mkdir(exist_ok=True)
for slug,pos in [('front',(0,-6,1.07)),('side',(6,0,1.07)),('threequarter',(3,-6,2))]:
    scene.camera.location=pos;aim(scene.camera,(0,0,1.07));scene.camera.data.ortho_scale=2.5
    scene.render.filepath=str(folder/(slug+'.png'));bpy.ops.render.render(write_still=True)
