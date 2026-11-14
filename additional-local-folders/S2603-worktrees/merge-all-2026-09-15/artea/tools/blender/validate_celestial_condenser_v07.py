"""Source/export checks and scoped condenser preservation/fit checks."""
import bpy,bmesh,json,math,sys,struct,hashlib
from pathlib import Path
from collections import Counter
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from build_celestial_condenser_v07 import OUT,SOURCE,ASSEMBLY
from build_celestial_enginehouse_v06 import digest

checks=[]
def check(name,ok,detail=None):checks.append({'name':name,'passed':bool(ok),'detail':detail})
def parts():return [o for o in bpy.data.objects if o.type=='MESH' and o.get('part_id')]
def bounds(o):
    vv=[o.matrix_world@v.co for v in o.data.vertices]
    return [(min(v[i] for v in vv),max(v[i] for v in vv)) for i in range(3)]
def contact(a,c):return all(min(a[i][1],c[i][1])-max(a[i][0],c[i][0])>=-.025 for i in range(3))
def inspect(objects,stage):
    errors={k:[] for k in ('triangles','nonzero_area','finite_coordinates','closed_mesh','positive_volume','uvs','no_loose_vertices')}
    for o in objects:
        if any(len(p.vertices)!=3 for p in o.data.polygons):errors['triangles'].append(o.name)
        if any(p.area<=1e-12 for p in o.data.polygons):errors['nonzero_area'].append(o.name)
        if any(not math.isfinite(c) for v in o.data.vertices for c in v.co):errors['finite_coordinates'].append(o.name)
        if not o.data.uv_layers:errors['uvs'].append(o.name)
        bm=bmesh.new();bm.from_mesh(o.data)
        if stage=='export':bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
        if any(not e.is_manifold for e in bm.edges):errors['closed_mesh'].append(o.name)
        if bm.calc_volume(signed=True)<=0:errors['positive_volume'].append(o.name)
        if any(not v.link_faces for v in bm.verts):errors['no_loose_vertices'].append(o.name)
        bm.free()
    for k,v in errors.items():check(stage+'_'+k,not v,v)

manifest=json.loads((OUT/'parts_manifest.json').read_text())
blend=OUT/'source/celestial_condenser_v07.blend';glb=OUT/'celestial_condenser_v07.glb'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
reference={o.name:digest(o) for o in parts() if o.get('assembly')!='Sun condenser and pressure regulator'}
check('v06_source_unchanged',hashlib.sha256(SOURCE.read_bytes()).hexdigest()==manifest['source_v06_sha256'])
bpy.ops.wm.open_mainfile(filepath=str(blend));objects=parts();lookup={o['design_part']:o for o in objects}
check('3000_independent_mesh_objects',len(objects)==3000 and len({o.data.as_pointer() for o in objects})==3000)
check('part_ids_preserved',sorted(o['part_id'] for o in objects)==list(range(1,3001)))
check('same_nine_family_counts',dict(Counter(o['family'] for o in objects))==manifest['allocation'])
check('2920_surrounding_objects_unchanged',sum(o.name in reference and digest(o)==reference[o.name] for o in objects)==2920)
check('materials_visibility_and_applied_modifiers',all(o.data.materials and not o.modifiers and not o.hide_render and not o.hide_viewport for o in objects))
machine=[o for o in objects if o.get('assembly')==ASSEMBLY]
check('80_editable_machine_parts',len(machine)==80,len(machine))
check('clock_assembly_removed',not any(o.get('assembly')=='Sun condenser and pressure regulator' or o['design_part'].startswith('Regulator_') for o in objects))
check('no_dial_hands_in_replacement',not any(any(s in o['design_part'].lower() for s in ('indicator','dial','clock','annular','halo')) for o in machine))
skid=bounds(lookup['Condenser_mounting_skid'])
sills=[bounds(o) for o in objects if o['design_part'].startswith('Bay2_bearing_sill')]
check('mounting_skid_bears_on_sill',any(contact(skid,s) and abs(skid[2][0]-s[2][1])<.025 for s in sills))
feet=[o for o in machine if o['design_part']=='Condenser_vessel_foot']
check('four_feet_contact_skid',len(feet)==4 and all(contact(bounds(o),skid) for o in feet))
check('two_pressure_vessels',all(f'Condenser_vessel{i}_shell' in lookup for i in (1,2)))
check('14_cooling_fins',sum(o['design_part'].startswith('Condenser_cooling_fin') for o in machine)==14)
# Check the new assembly's vertices against the available arch envelope.
outside=[]
for o in machine:
    for vertex in o.data.vertices:
        p=o.matrix_world@vertex.co;x=p.x-3.15
        if p.z>-3.45 and math.hypot(x,p.z+3.45)>2.46+.015:
            outside.append(o.name);break
check('machine_fits_inside_arch_curve',not outside,outside)
check('machine_clears_sealed_backwall',all(bounds(o)[1][1]<-6.18 for o in machine))
check('inlet_matches_existing_supply',Vector(lookup['Condenser_inlet']['connection_start']).__sub__(Vector(lookup['Steam_supply_section6']['connection_end'])).length<1e-6)
check('outlet_matches_existing_return',Vector(lookup['Condenser_outlet']['connection_end']).__sub__(Vector(lookup['Condensate_return_section1']['connection_start'])).length<1e-6)
check('source_triangle_count',sum(len(o.data.polygons) for o in objects)==manifest['triangles'],manifest['triangles'])
inspect(objects,'source');names={o.name for o in objects}
data=glb.read_bytes();check('glb_header_and_length',data[:4]==b'glTF' and struct.unpack_from('<I',data,8)[0]==len(data))
g=json.loads(data[20:20+struct.unpack_from('<I',data,12)[0]])
check('self_contained_export',all('uri' not in x or x['uri'].startswith('data:') for x in g.get('buffers',[])+g.get('images',[])))
check('glb_mesh_count_normals_triangles',len(g['meshes'])==3000 and all(p.get('mode',4)==4 and 'NORMAL' in p['attributes'] for m in g['meshes'] for p in m['primitives']))
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(glb))
exported=[o for o in bpy.data.objects if o.type=='MESH']
check('roundtrip_names_count_triangles',len(exported)==3000 and {o.name for o in exported}==names and sum(len(o.data.polygons) for o in exported)==manifest['triangles'])
inspect(exported,'export')
report={'passed':all(c['passed'] for c in checks),'part_count':3000,'replacement_parts':80,'triangles':manifest['triangles'],
  'checks':checks,'sha256':{'blend':hashlib.sha256(blend.read_bytes()).hexdigest(),'glb':hashlib.sha256(data).hexdigest()},
  'limits':['Static art, not thermodynamic or structural engineering validation','No animation or live gameplay integration','Fit checks are targeted, not an exhaustive collision audit']}
(OUT/'validation_report.json').write_text(json.dumps(report,indent=2))
print('[V07 VALIDATION]',json.dumps({'passed':report['passed'],'checks':len(checks),'failed':[c for c in checks if not c['passed']]}),flush=True)
if not report['passed']:raise RuntimeError('See validation_report.json')
