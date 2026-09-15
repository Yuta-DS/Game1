from pathlib import Path
OUT=Path(__file__).resolve().parent
for name in ('helpers.py','head.py','body.py'):
    p=OUT/name;exec(compile(p.read_text(),str(p),'exec'))
meshes=[o for o in bpy.data.objects if o.type=='MESH']
for o in meshes:o['reference']='User supplied reference-turnaround.png';o['stage']='Static likeness sculpt; not rigged'
scene['approval']='Pending user likeness approval; not an exact-match claim'
scene['scope']='Separate local sculpt. Prior drafts and game assets unchanged.'
# Reference empties assist manual front/side inspection in the editable scene.
ref=bpy.data.images.load(str(OUT.parent/'reference-match/reference-turnaround.png'));ref.pack()
empty=bpy.data.objects.new('SUPPLIED_REFERENCE_DO_NOT_RENDER',None);scene.collection.objects.link(empty);empty.empty_display_type='IMAGE';empty.data=ref;empty.empty_display_size=5.48;empty.location=(3,1,1);empty.rotation_euler=(math.pi/2,0,0);empty.hide_render=True
for o in meshes:o.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'milo_likeness.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'milo_likeness.glb'),export_format='GLB',use_selection=True,export_animations=False,export_yup=True)
report={'meshes':len(meshes),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),'rigged':False,'animations':[],'visual_approval':'pending','geometry_origin':'AnyCreature cranium study; connected Blender sculpt and tailored geometry'}
(OUT/'build_report.json').write_text(json.dumps(report,indent=2));print('SCULPT_BUILD',report,flush=True)
