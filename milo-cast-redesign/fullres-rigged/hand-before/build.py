from pathlib import Path
import sys
OUT=Path(__file__).resolve().parent
for name in ('helpers.py','head.py','body.py','refine_body.py'):
    p=OUT/name;exec(compile(p.read_text(),str(p),'exec'))
meshes=[o for o in bpy.data.objects if o.type=='MESH']
for o in meshes:
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
    o['source_reference']='Full-resolution DOCX image7.png'
if '--rig' in sys.argv:
    p=OUT/'rig.py';exec(compile(p.read_text(),str(p),'exec'))
scene['scope']='Local asset development. Prior drafts and game assets preserved.'
scene['reference_likeness']='Requires visual review; no exact-match claim.'
ref=bpy.data.images.load(str(OUT.parent/'docx-source/word/media/image7.png'));ref.pack()
empty=bpy.data.objects.new('SOURCE_ARTWORK_REFERENCE',None);scene.collection.objects.link(empty);empty.empty_display_type='IMAGE';empty.data=ref;empty.empty_display_size=5;empty.location=(3,1,1);empty.rotation_euler=(math.pi/2,0,0);empty.hide_render=True
select(meshes[0])
for o in meshes:o.select_set(True)
if '--rig' in sys.argv:rig.select_set(True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'milo_fullres.blend'),compress=True)
opts=dict(filepath=str(OUT/'milo_fullres.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations='--rig' in sys.argv)
if '--rig' in sys.argv:opts.update(export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_frame_range=False,export_nla_strips=True)
bpy.ops.export_scene.gltf(**opts)
print('MILO_BUILD',len(meshes),'meshes',sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),'triangles',flush=True)
