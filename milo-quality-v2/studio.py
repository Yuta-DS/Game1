from pathlib import Path
import bpy
from mathutils import Vector
OUT=Path(__file__).resolve().parent

def look(obj,point):obj.rotation_euler=(Vector(point)-obj.location).to_track_quat('-Z','Y').to_euler()

def setup():
    scene=bpy.context.scene
    world=bpy.data.worlds.new('Milo photographic studio');world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.17,.20,.26,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.3;scene.world=world
    for name,pos,power,size,color in [('Warm softbox',(-3,-4,5),550,4,(1,.86,.70)),('Cool fill',(3,-2,3),260,3,(.75,.84,1)),('Warm rim',(1.5,3,4),650,3,(1,.82,.65)),('Face catchlight',(-.2,-4,2.2),70,1.5,(1,.96,.9))]:
        bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.name=name;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.data.color=color;look(o,(0,0,1))
    m=bpy.data.materials.new('Studio slate');m.diffuse_color=(.095,.117,.15,1);m.use_nodes=True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=m.diffuse_color
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,0));floor=bpy.context.object;floor.name='STUDIO_floor';floor.data.materials.append(m)
    bpy.ops.object.camera_add(location=(2.8,-6.4,2.5));camera=bpy.context.object;camera.name='Milo portrait';camera.data.type='ORTHO';camera.data.ortho_scale=2.6;look(camera,(0,0,1.07));scene.camera=camera
    scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
    scene.render.resolution_x=960;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
    scene.render.film_transparent=False
    return scene

if __name__=='__main__':
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'milo_quality_model.blend'))
    scene=setup();scene.render.engine='BLENDER_EEVEE'
    scene.render.filepath=str(OUT/'design_draft.png');bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'milo_quality_studio.blend'))
