"""Rebuild the supplied Milo reference as an isolated local review asset."""
from pathlib import Path
OUT=Path(__file__).resolve().parent
for module in ('model_helpers.py','build_head.py','build_body.py'):
    path=OUT/module;exec(compile(path.read_text(),str(path),'exec'))
main_names={'Milo_Reference_Head','Milo_Reference_Face_Details','Milo_Reference_Coat_and_Suit','Milo_Reference_Sleeve_l','Milo_Reference_Sleeve_r','Milo_Reference_Paw_l','Milo_Reference_Paw_r','Milo_Reference_Boot_l','Milo_Reference_Boot_r','Milo_Reference_Curved_Tail'}
extras=[o for o in bpy.data.objects if o.type=='MESH' and o.name not in main_names]
if extras:join_objects(extras,'Milo_Reference_Limb_Details')
# Narrow the rig's arm stance, retaining the reference's head/coat width.
# Scaling the rig and skin together keeps cuff/paw attachments coherent in motion.
arm_stance=.81
for name in ('Milo_Reference_Head','Milo_Reference_Face_Details','Milo_Reference_Coat_and_Suit'):
    for v in bpy.data.objects[name].data.vertices:v.co.x/=arm_stance
rig.scale.x*=arm_stance
# Shorten coat/limbs by 18%; retain the head's dimensions and collar contact.
body_height=.82
for name in ('Milo_Reference_Head','Milo_Reference_Face_Details'):
    for v in bpy.data.objects[name].data.vertices:v.co.z=(v.co.z-1.20*(1-body_height))/body_height
rig.scale.z*=body_height
rig['visual_target']='User supplied reference-turnaround.png and reference-sheet.png'
rig['local_review_only']=True;rig['construction']='AnyCreature head study; reconstructed Blender reference geometry'
scene.frame_set(0);bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'milo_reference.blend'))
ad.action=None;bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    if o.type in ('MESH','ARMATURE'):o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'milo_reference.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,export_skins=True,export_yup=True,export_all_vertex_colors=False)
meshes=[o for o in bpy.data.objects if o.type=='MESH'];report={'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),'meshes':len(meshes),'bones':len(rig.data.bones),'actions':list(clips),'visual_review':'pending','scope':'Separate reference-model rebuild; not integrated into game'}
(OUT/'build_report.json').write_text(json.dumps(report,indent=2));print('REFERENCE_BUILD_DONE',report,flush=True)
