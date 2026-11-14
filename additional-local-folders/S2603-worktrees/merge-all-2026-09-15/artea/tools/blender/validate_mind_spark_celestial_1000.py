"""Validate the source and exported 1000-part celestial Blender asset."""
import bpy,bmesh,json,math,hashlib,struct
from pathlib import Path
from collections import Counter
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets3D/mind_spark/celestial_terrace_1000'
manifest=json.loads((OUT/'parts_manifest.json').read_text())
errors=[];checks=[]
def record(name,ok,detail=None):
    checks.append({'name':name,'passed':bool(ok),'detail':detail})
    if not ok:errors.append(name)
def inspect(objects,stage):
    nontri=[];degenerate=[];nonfinite=[];nonmanifold=[];volume=[];loose=[];missing_uv=[]
    for o in objects:
        if any(len(p.vertices)!=3 for p in o.data.polygons):nontri.append(o.name)
        if any(p.area<1e-12 for p in o.data.polygons):degenerate.append(o.name)
        if any(not math.isfinite(c) for v in o.data.vertices for c in v.co):nonfinite.append(o.name)
        if not o.data.uv_layers:missing_uv.append(o.name)
        bm=bmesh.new();bm.from_mesh(o.data)
        # GLTF duplicates vertices across normal/UV/material seams. Weld only a
        # disposable validation copy; the actual editable model remains intact.
        if stage=='export':
            bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
        if any(not e.is_manifold for e in bm.edges):nonmanifold.append(o.name)
        if any(not v.link_faces for v in bm.verts):loose.append(o.name)
        if bm.calc_volume(signed=True)<=0:volume.append(o.name)
        bm.free()
    record(stage+'_triangle_only',not nontri,nontri)
    record(stage+'_nonzero_triangle_area',not degenerate,degenerate)
    record(stage+'_finite_vertices',not nonfinite,nonfinite)
    record(stage+'_closed_mesh_islands',not nonmanifold,nonmanifold)
    record(stage+'_positive_volume',not volume,volume)
    record(stage+'_no_loose_vertices',not loose,loose)
    record(stage+'_editable_uvs_present',not missing_uv,missing_uv)

blend=OUT/'source/celestial_terrace_1000.blend'
glb=OUT/'celestial_terrace_1000.glb'
bpy.ops.wm.open_mainfile(filepath=str(blend))
objects=[o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith('CT_')]
record('exactly_1000_source_mesh_objects',len(objects)==1000,len(objects))
record('1000_independent_mesh_datablocks',len({o.data.as_pointer() for o in objects})==1000)
record('continuous_part_ids',sorted(o.get('part_id',0) for o in objects)==list(range(1,1001)))
record('family_allocation',dict(Counter(o['family'] for o in objects))==manifest['allocation'])
record('no_unapplied_modifiers',all(not o.modifiers for o in objects))
record('visible_editable_objects',all(not o.hide_render and not o.hide_viewport for o in objects))
record('material_slots_present',all(o.data.materials and o.data.materials[0] for o in objects))
record('source_triangle_count_matches_manifest',sum(len(o.data.polygons) for o in objects)==manifest['triangles'])
record('smooth_shaded_curved_parts',all(any(p.use_smooth for p in o.data.polygons) for o in objects if
    any(s in o.name.lower() for s in ('pipe','flywheel','bearing','curved_rail'))))
inspect(objects,'source')
reference={o.name: {'triangles':len(o.data.polygons),'world_vertices':len(o.data.vertices)} for o in objects}
data=glb.read_bytes()
record('glb_magic_and_length',data[:4]==b'glTF' and struct.unpack_from('<I',data,8)[0]==len(data))
jlen=struct.unpack_from('<I',data,12)[0];g=json.loads(data[20:20+jlen])
record('no_external_resources',all('uri' not in r or r['uri'].startswith('data:') for r in g.get('buffers',[])+g.get('images',[])))
record('1000_glb_meshes',len(g.get('meshes',[]))==1000,len(g.get('meshes',[])))
record('glb_triangle_primitives',all(p.get('mode',4)==4 for m in g['meshes'] for p in m['primitives']))
record('glb_normals_present',all('NORMAL' in p['attributes'] for m in g['meshes'] for p in m['primitives']))
record('no_exported_cameras_lights',not g.get('cameras') and 'KHR_lights_punctual' not in g.get('extensions',{}))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(glb))
exported=[o for o in bpy.data.objects if o.type=='MESH']
record('roundtrip_1000_mesh_objects',len(exported)==1000,len(exported))
record('roundtrip_names_preserved',{o.name for o in exported}==set(reference))
record('roundtrip_triangles_preserved',sum(len(o.data.polygons) for o in exported)==manifest['triangles'])
inspect(exported,'export')
report={'passed':not errors,'scope':'Editable Blender source and GLB geometry, not live gameplay or image similarity',
        'part_count':len(objects),'triangles':manifest['triangles'],'checks':checks,'failed_checks':errors,
        'sha256':{'blend':hashlib.sha256(blend.read_bytes()).hexdigest(),'glb':hashlib.sha256(data).hexdigest()},
        'not_verified':['Pixel-exact concept reconstruction','Live-map collision/route integration',
                        'Game or Web performance','Working mechanical/steam simulation','Creature identity/animation gates']}
(OUT/'validation_report.json').write_text(json.dumps(report,indent=2))
print('[CELESTIAL VALIDATION]',json.dumps({'passed':report['passed'],'checks':len(checks),'errors':errors,'triangles':report['triangles']}),flush=True)
if errors:raise RuntimeError('See validation_report.json')
