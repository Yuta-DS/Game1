"""Local render/export helpers. Does not touch the game's assets."""
from pathlib import Path
import json, math, sys
import bpy
from mathutils import Vector
OUT=Path(__file__).resolve().parent

def load():
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'milo_quality_v2.blend'))
    return bpy.context.scene

def select_clip(name):
    rig=bpy.data.objects['MiloQualityRig']
    for owner,action_name in [(rig,name)]+[(o.data.shape_keys,name+'__'+o.name) for o in bpy.data.objects if o.type=='MESH' and o.data.shape_keys]:
        owner.animation_data_create()
        for tr in owner.animation_data.nla_tracks:tr.mute=True
        action=bpy.data.actions[action_name];owner.animation_data.action=action
        if action.slots:owner.animation_data.action_slot=action.slots[0]
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()

def aim(camera,target):camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()

def render_still(name,clip='Idle',frame=0,close=False,front=False,quality=False):
    scene=bpy.context.scene;select_clip(clip);scene.frame_set(frame)
    camera=scene.camera
    camera.location=(0,-6,2.15) if front else (2.8,-6.4,2.5)
    aim(camera,(0,0,1.07));camera.data.ortho_scale=2.6
    scene.render.resolution_x=960;scene.render.resolution_y=1200
    if close:
        camera.location=(.7,-6,2.2);aim(camera,(0,-.06,1.59));camera.data.ortho_scale=1.12
        scene.render.resolution_x=1200;scene.render.resolution_y=1200
    scene.render.engine='CYCLES' if quality else 'BLENDER_EEVEE'
    scene.cycles.samples=64;scene.cycles.use_denoising=True
    scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/name)
    bpy.ops.render.render(write_still=True)

def export():
    rig=bpy.data.objects['MiloQualityRig']
    # Optimize an in-memory export copy, preserving the native sculpt file.
    rig.data.pose_position='REST';bpy.context.view_layer.update()
    source=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==rig]
    before=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in source)
    groups={}
    for obj in source:
        if obj.data.shape_keys:continue
        tri=sum(len(p.vertices)-2 for p in obj.data.polygons)
        if tri>1500:
            bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
            mod=obj.modifiers.new('Runtime geometry reduction','DECIMATE')
            mod.ratio=.40 if obj.name=='Head' else .20 if obj.name.startswith(('CoatBody','Sleeve','Trouser')) else .35
            bpy.ops.object.modifier_move_up(modifier=mod.name);bpy.ops.object.modifier_apply(modifier=mod.name)
        groups.setdefault(obj.data.materials[0].name,[]).append(obj)
    for material,objects in groups.items():
        if len(objects)<2:continue
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
        bpy.context.object.name='Milo_'+material.replace(' ','_')
    remaining=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==rig]
    after=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in remaining)
    (OUT/'runtime_optimization.json').write_text(json.dumps({'native_triangles':before,'runtime_triangles':after,'native_meshes':len(source),'runtime_meshes':len(remaining),'note':'Native Blender sculpt unchanged. Procedural micro-bump stays in Blender; glTF uses PBR factors, vertex color and geometry.'},indent=2))
    rig.data.pose_position='POSE'
    select_clip('Idle')
    for o in bpy.context.scene.objects:o.select_set(o==rig or o.parent==rig)
    bpy.context.view_layer.objects.active=rig
    rig.animation_data.action=None
    for o in bpy.data.objects:
        if o.type=='MESH' and o.data.shape_keys:o.data.shape_keys.animation_data.action=None
    bpy.ops.export_scene.gltf(filepath=str(OUT/'milo_quality_v2.glb'),export_format='GLB',use_selection=True,
        export_animations=True,export_animation_mode='NLA_TRACKS',export_def_bones=True,
        export_frame_range=False,export_force_sampling=True,export_morph=True,
        export_morph_animation=True,export_extras=True,export_cameras=False,export_lights=False)
    print('EXPORT_OK',flush=True)

if __name__=='__main__':
    load();args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    if 'export' in args:export()
    elif 'final' in args:
        render_still('hero.png',frame=15,quality=True)
        render_still('face_closeup.png',frame=15,close=True,quality=True)
        render_still('front.png',front=True,quality=True)
    else:
        render_still('walk_draft.png','Walk_InPlace',18)
        render_still('welcome_draft.png','Welcome',48)
        render_still('face_draft.png',close=True)
