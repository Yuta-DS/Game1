"""Geometry, preservation, and bounded architectural relationship checks."""
import bpy,bmesh,json,math,hashlib,struct,sys
from pathlib import Path
from collections import Counter
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).resolve().parent))
from build_celestial_enginehouse_v06 import OUT,SOURCE,digest

checks=[]
def check(name,ok,detail=None):checks.append({'name':name,'passed':bool(ok),'detail':detail})
def parts():return [o for o in bpy.data.objects if o.type=='MESH' and o.get('part_id')]
def world(o):return [o.matrix_world@v.co for v in o.data.vertices]
def bbox(o):
    vv=world(o)
    return [(min(v[i] for v in vv),max(v[i] for v in vv)) for i in range(3)]
def contact(a,b):return all(min(a[k][1],b[k][1])-max(a[k][0],b[k][0])>=-.025 for k in range(3))
def tree(o):return BVHTree.FromPolygons(world(o),[list(p.vertices) for p in o.data.polygons],all_triangles=True)
def inside(t,v):
    near,n,_,_=t.find_nearest(v)
    return near is not None and (v-near).dot(n)<-.001
def ray_inside(t,p):
    direction=Vector((.371,.529,.763)).normalized();cursor=p.copy();hits=0
    for _ in range(128):
        hit,_,_,_=t.ray_cast(cursor,direction)
        if hit is None:return hits%2==1
        hits+=1;cursor=hit+direction*1e-5
    raise RuntimeError('Unresolved inside/outside ray test')
def inspect(objects,stage):
    errors={k:[] for k in ('finite_vertices','triangle_faces','positive_area','closed_mesh','outward_volume','uvs','no_loose_vertices')}
    for o in objects:
        if any(not math.isfinite(c) for v in o.data.vertices for c in v.co):errors['finite_vertices'].append(o.name)
        if any(len(p.vertices)!=3 for p in o.data.polygons):errors['triangle_faces'].append(o.name)
        if any(p.area<=1e-12 for p in o.data.polygons):errors['positive_area'].append(o.name)
        if not o.data.uv_layers:errors['uvs'].append(o.name)
        bm=bmesh.new();bm.from_mesh(o.data)
        if stage=='export':bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
        if any(not e.is_manifold for e in bm.edges):errors['closed_mesh'].append(o.name)
        if bm.calc_volume(signed=True)<=0:errors['outward_volume'].append(o.name)
        if any(not v.link_faces for v in bm.verts):errors['no_loose_vertices'].append(o.name)
        bm.free()
    for k,v in errors.items():check(stage+'_'+k,not v,v)

manifest=json.loads((OUT/'parts_manifest.json').read_text())
blend=OUT/'source/celestial_enginehouse_v06.blend';glb=OUT/'celestial_enginehouse_v06.glb'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
original={o.name:digest(o) for o in parts() if o['family']!='03_Civic_Facade'}
check('v05_source_unchanged',hashlib.sha256(SOURCE.read_bytes()).hexdigest()==manifest['source_v05_sha256'])
bpy.ops.wm.open_mainfile(filepath=str(blend));objects=parts();lookup={o['design_part']:o for o in objects}
check('exactly_3000_editable_parts',len(objects)==3000,len(objects))
check('independent_mesh_datablocks',len({o.data.as_pointer() for o in objects})==3000)
check('continuous_part_ids',sorted(o['part_id'] for o in objects)==list(range(1,3001)))
check('family_counts_preserved',dict(Counter(o['family'] for o in objects))==manifest['allocation'])
unchanged=[o for o in objects if o.name in original and digest(o)==original[o.name]]
check('2530_other_objects_geometry_unchanged',len(unchanged)==2530,len(unchanged))
check('deck_access_basin_gardens_geometry_unchanged',all(digest(o)==original[o.name] for o in objects if o['family'] in
  ('02_Civic_Deck','05_Access','08_Basin','09_Gardens')))
check('no_unapplied_modifiers',all(not o.modifiers for o in objects))
check('materials_and_visibility',all(o.data.materials and not o.hide_render and not o.hide_viewport for o in objects))
check('source_triangle_count',sum(len(o.data.polygons) for o in objects)==manifest['triangles'],manifest['triangles'])
core=tree(lookup['Island_structural_rock_core'])
for p in range(1,4):
    chain=[lookup[f'Buttress{p}_load_stone{j}'] for j in range(1,7)]
    socket=lookup[f'Buttress{p}_rock_socket']
    evidence={'root_vertices_inside_rock':sum(inside(core,v) for v in world(socket)),
      'lowest_stone_vertices_inside_rock':sum(inside(core,v) for v in world(chain[-1])),
      'course_bounds_connected':all(contact(bbox(a),bbox(b)) for a,b in zip(chain,chain[1:])),
      'capital_contact':contact(bbox(chain[0]),bbox(lookup[f'Buttress{p}_capital1']))}
    check(f'buttress_{p}_modeled_bearing_chain',evidence['root_vertices_inside_rock']>0 and evidence['lowest_stone_vertices_inside_rock']>0 and
      evidence['course_bounds_connected'] and evidence['capital_contact'],evidence)
for label in ('Steam_supply','Condensate_return'):
    route=[lookup[f'{label}_section{j}'] for j in range(1,7)]
    gap=max((Vector(a['connection_end'])-Vector(b['connection_start'])).length for a,b in zip(route,route[1:]))
    check(label+'_mating_section_endpoints',gap<1e-6,{'maximum_gap_m':gap})
obstacles=[o for o in objects if o['design_part'].startswith(('Bay1_bearing_sill','Bay2_bearing_sill',
  'Canopy1_keystone','Canopy2_keystone')) or o['design_part']=='Balcony_structural_slab']
obstacle_trees=[(o.name,tree(o),bbox(o)) for o in obstacles]
intersections=[]
for label in ('Steam_supply','Condensate_return'):
    for j in range(1,7):
        o=lookup[f'{label}_section{j}'];a=Vector(o['connection_start']);c=Vector(o['connection_end'])
        for k in range(61):
            p=a.lerp(c,k/60)
            for name,t,bb in obstacle_trees:
                if any(p[i]<bb[i][0]-.095 or p[i]>bb[i][1]+.095 for i in range(3)):continue
                near,normal,_,dist=t.find_nearest(p)
                if near is not None and (dist<.095 or ray_inside(t,p)):
                    intersections.append([o.name,name]);break
check('pipe_clearance_from_sills_floor_and_keystones',not intersections,intersections[:12])
check('regulator_present_with_80_parts',sum(o.get('assembly')=='Sun condenser and pressure regulator' for o in objects)==80)
check('two_sealed_bays_not_fake_walkthroughs',all(f'Bay{j}_sealed_backwall' in lookup for j in (1,2)))
inspect(objects,'source')
names={o.name for o in objects}
data=glb.read_bytes();check('glb_header_length',data[:4]==b'glTF' and struct.unpack_from('<I',data,8)[0]==len(data))
g=json.loads(data[20:20+struct.unpack_from('<I',data,12)[0]])
check('self_contained_glb',all('uri' not in x or x['uri'].startswith('data:') for x in g.get('buffers',[])+g.get('images',[])))
check('3000_exported_meshes',len(g.get('meshes',[]))==3000)
check('glb_normals_and_triangles',all('NORMAL' in p['attributes'] and p.get('mode',4)==4 for m in g['meshes'] for p in m['primitives']))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(glb))
exported=[o for o in bpy.data.objects if o.type=='MESH']
check('roundtrip_names_and_count',len(exported)==3000 and {o.name for o in exported}==names)
check('roundtrip_triangles',sum(len(o.data.polygons) for o in exported)==manifest['triangles'])
inspect(exported,'export')
result={'passed':all(c['passed'] for c in checks),'checks':checks,'triangles':manifest['triangles'],'part_count':3000,
  'sha256':{'blend':hashlib.sha256(blend.read_bytes()).hexdigest(),'glb':hashlib.sha256(data).hexdigest()},
  'limits':['Bounding contact and nearest-surface tests are not structural engineering or full-face bearing certification',
    'Static pipes and valves, not simulated steam or playable quest','Visual composition reviewed manually, not pixel-exact image matching',
    'No collision, navigation, Web performance or gameplay integration']}
(OUT/'validation_report.json').write_text(json.dumps(result,indent=2))
print('[V06 VALIDATION]',json.dumps({'passed':result['passed'],'checks':len(checks),'failures':[c for c in checks if not c['passed']]}),flush=True)
if not result['passed']:raise RuntimeError('See validation_report.json')
