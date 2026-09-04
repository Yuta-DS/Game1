"""Actual game assets and both Milo exports under one neutral light setup."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector
OUT=Path(__file__).resolve().parent
ASSETS=OUT.parent.parent/'artea/assets3D/characters'
bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
items=[('Rogue',ASSETS/'Rogue.glb','Rogue_Head',.52),('Fox',ASSETS/'fox.glb','Hood',.48),
       ('Milo before',OUT/'head-style-before/milo_fullres.glb','Head_Cranium_AnyCreature',None),
       ('Milo revised',OUT/'milo_fullres.glb','Head_Cranium_AnyCreature',None)]
for index,(label,source,head_name,eye_fraction) in enumerate(items):
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(source));new=set(bpy.data.objects)-before
    for o in new:
        if o.name.startswith('Cane_'):o.hide_render=True
        if o.type=='ARMATURE':
            if o.animation_data:
                o.animation_data.action=None
                for tr in o.animation_data.nla_tracks:tr.mute=True
                idle=next((tr.strips[0] for tr in o.animation_data.nla_tracks if tr.name.startswith('Idle') and tr.strips),None)
                if idle:
                    o.animation_data.action=idle.action
                    if hasattr(idle,'action_slot'):o.animation_data.action_slot=idle.action_slot
    scene.frame_set(1);bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    head=next(o for o in new if o.type=='MESH' and o.name.startswith(head_name))
    evaluated=head.evaluated_get(dg)
    pts=[evaluated.matrix_world@v.co for v in evaluated.data.vertices]
    lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)));hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
    if eye_fraction is None:
        eyes=[o for o in new if o.name.startswith('Eye_')]
        ep=[o.evaluated_get(dg).matrix_world@v.co for o in eyes for v in o.evaluated_get(dg).data.vertices]
        eye_z=sum(p.z for p in ep)/len(ep)
    else:eye_z=hi.z-eye_fraction*(hi.z-lo.z)
    g=bpy.data.objects.new(label,None);scene.collection.objects.link(g)
    for o in new:
        if o.parent not in new:o.parent=g
    # Compare facial styling at equal head width, not at misleading weapon-
    # dependent character bounds. This sheet does not compare body scale.
    scale=.80/(hi.x-lo.x);g.scale=(scale,)*3
    x=(index-1.5)*1.08
    g.location=(x-(lo.x+hi.x)*.5*scale,0,1.3-eye_z*scale)
    bpy.ops.object.text_add(location=(x,-.65,.76),rotation=(math.pi/2,0,0))
    txt=bpy.context.object;txt.data.body=label;txt.data.align_x='CENTER';txt.data.size=.070
    m=bpy.data.materials.get('Caption') or bpy.data.materials.new('Caption');m.diffuse_color=(.8,.85,.9,1);txt.data.materials.append(m)
world=bpy.data.worlds.new('Neutral');world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.055,.075,.09,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.65;scene.world=world
for loc,power,size in [((-3,-5,6),650,6),((4,-3,3),220,5),((0,3,4),300,4)]:
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=size;aim(o,(0,0,1.3))
bpy.ops.object.camera_add(location=(0,-10,1.45));cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=4.4;aim(cam,(0,0,1.3))
scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=64
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.render.resolution_x=2000;scene.render.resolution_y=650;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='JPEG';scene.render.image_settings.quality=96
scene.render.filepath=str(OUT/'cast_eye_comparison.jpg');bpy.ops.render.render(write_still=True)
print('CAST_FACE_COMPARISON_RENDERED',flush=True)
