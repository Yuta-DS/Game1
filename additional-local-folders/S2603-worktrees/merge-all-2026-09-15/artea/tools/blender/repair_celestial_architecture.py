"""Focused visual-construction repair. Not a structural-engineering certificate.
--audit-only inspects the saved master; otherwise backs up, repairs and exports.
The full builder also calls repair() so the fix is reproducible.
"""
import sys, math, json, hashlib, shutil
from pathlib import Path
from collections import Counter
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_mind_spark_celestial_1000 as b

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets3D/mind_spark/celestial_terrace_3000'

def world_vertices(o):return [o.matrix_world@v.co for v in o.data.vertices]

def bounds(o):
    vv=world_vertices(o)
    return [[min(v[k] for v in vv),max(v[k] for v in vv)] for k in range(3)]

def core_bvh(parts):
    core=next(o for o in parts if o['design_part']=='Island_structural_rock_core')
    return BVHTree.FromPolygons(world_vertices(core),[list(p.vertices) for p in core.data.polygons],all_triangles=True)

def inside(tree,p):
    near,normal,_,_=tree.find_nearest(Vector(p))
    return near is not None and (Vector(p)-near).dot(normal)<-.001

def box_contact(a,c,tolerance=.025):
    return all(min(a[k][1],c[k][1])-max(a[k][0],c[k][0])>=-tolerance for k in range(3))

def audit(parts):
    bpy.context.view_layer.update();tree=core_bvh(parts)
    result={'scope':'Geometry and visual construction logic; no stress, load, or real-world safety certification',
            'part_count':len(parts),'pier_bearings':[]}
    for i,x in enumerate((-6.5,0,6.5),1):
        foot=next(o for o in parts if o['design_part']==f'Pier{i}_plinth_course1')
        courses=[o for o in parts if o['design_part'].startswith(f'Pier{i}_bearing_corbel_course')]
        original_contact=sum(inside(tree,p) for p in world_vertices(foot))
        bearing_contact=0;top_touch=False;chain_touch=False
        if courses:
            courses.sort(key=lambda o:o['design_part'])
            bearing_contact=sum(inside(tree,p) for p in world_vertices(courses[-1]))
            fb=bounds(foot);cb=bounds(courses[0])
            top_touch=box_contact(fb,cb)
            chain_touch=all(box_contact(bounds(courses[j]),bounds(courses[j+1])) and
                abs(bounds(courses[j])[2][0]-bounds(courses[j+1])[2][1])<.04 for j in range(len(courses)-1))
        result['pier_bearings'].append({'pier':i,'old_foot_vertices_inside_rock':original_contact,
            'support_courses':len(courses),'new_bearing_vertices_inside_rock':bearing_contact,
            'foot_to_corbel_contact':top_touch,'corbel_courses_connected':chain_touch})
    result['curved_ashlar_blocks']=sum(o['design_part'].startswith('Curved_ashlar_') for o in parts)
    result['intrados_lining_blocks']=sum(o['design_part'].startswith('Carved_intrados_') for o in parts)
    result['cornice_return_blocks']=sum(o['design_part'].startswith('Cornice_return_') for o in parts)
    result['old_repetitive_lower_rivets']=sum(o['design_part'].startswith('Lower_rib') for o in parts)
    deck=[o for o in parts if o['design_part'].startswith('Deck_cornice_')]
    deck_trees=[BVHTree.FromPolygons(world_vertices(o),[list(p.vertices) for p in o.data.polygons],all_triangles=True) for o in deck]
    result['cornice_returns']=[]
    for o in parts:
        if not o['design_part'].startswith('Cornice_return_'):continue
        pier=1 if '_left_' in o['design_part'] else 3
        capital=next(p for p in parts if p['design_part']==f'Pier{pier}_capital_course3')
        result['cornice_returns'].append({'part':o.name,
          'capital_contact_bounds':box_contact(bounds(o),bounds(capital)),
          'vertices_inside_deck':sum(any(inside(t,v) for t in deck_trees) for v in world_vertices(o))})
    webs=[o for o in parts if o['design_part'].startswith('Lower_iron_arch') and '_web' in o['design_part']]
    result['lower_arch_backing_depths_m']=[round(bounds(o)[1][1]-bounds(o)[1][0],5) for o in webs]
    return result

def repair(parts_module=b):
    global b
    b=parts_module
    if any(o['design_part'].startswith('Curved_ashlar_') for o in b.PARTS):return
    before=list(b.PARTS)
    old=[o for o in before if o['design_part'].startswith('Lower_rib') and '_rivet_' in o['design_part']]
    assert len(old)==120,('Expected 120 replaceable lower-arch rivets',len(old))
    slots=[(o,o.get('part_id',before.index(o)+1)) for o in old]
    b.PARTS[:]=[o for o in before if o not in old]
    b.GROUP='03_Civic_Facade';start=len(b.PARTS)
    # Four curved courses, ten staggered blocks per course, in each arch bay.
    # A genuine recessed masonry band replaces the raw rock between arch tiers.
    def upper(x):return -3.65+math.sqrt(max(0,2.43**2-x*x))-.009
    def lower(x):return -6.62+math.sqrt(max(0,3.105**2-x*x))+.009
    for bay,cx in enumerate((-3.25,3.25),1):
        for row in range(4):
            cuts=[-2.82]+[-2.82+j*.564+(.22 if row%2 else 0) for j in range(1,10)]+[2.82]
            for col in range(10):
                x0,x1=cuts[col]+.008,cuts[col+1]-.008
                xs=[x0+(x1-x0)*k/16 for k in range(17)]
                bottom=[(cx+x,lower(x)+(upper(x)-lower(x))*row/4+.008) for x in xs]
                top=[(cx+x,lower(x)+(upper(x)-lower(x))*(row+1)/4-.008) for x in reversed(xs)]
                ob=b.prism(f'Curved_ashlar_bay{bay}_course{row+1}_brick{col+1:02d}',bottom+top,-.60,.60,
                           'ivory' if (row+col)%5 else 'cream',.012)
                ob.rotation_euler.x=math.pi/2;ob.location.y=-5.90
                ob['construction_role']='Curved recessed ashlar backing between upper intrados and lower arch extrados'
        for j in range(6):
            b.arch(f'Carved_intrados_bay{bay}_brick{j+1}',cx,-5.89,-3.65,2.43,2.50,
                   j*math.pi/6+.002,(j+1)*math.pi/6-.002,1.26,'ivory',.010)
    # Four continuous stepped corbel stones transfer each pier foot into the
    # island's actual solid rock core. They are not freestanding ornaments.
    for pier,x in enumerate((-6.5,0,6.5),1):
        direction=-1 if x>0 else (1 if x<0 else 0)
        for j in range(4):
            ztop=-7.145-j*.62;zbottom=ztop-.62
            top=(x+direction*.85*j,-6.25+.72*j)
            bottom=(x+direction*.85*(j+1),-6.25+.72*(j+1))
            wt,dt=1.26+j*.14,1.60+j*.18
            wb,db=1.26+(j+1)*.14,1.60+(j+1)*.18
            vv=[(bottom[0]+sx*wb/2,bottom[1]+sy*db/2,zbottom) for sy in (-1,1) for sx in (-1,1)]
            vv += [(top[0]+sx*wt/2,top[1]+sy*dt/2,ztop) for sy in (-1,1) for sx in (-1,1)]
            # Work near the local origin. Blender's post-triangulation normal
            # recalculation inverted four translated/sheared solids when their
            # mesh coordinates included the world offset (isolated regression).
            origin=sum((Vector(v) for v in vv),Vector())/len(vv)
            ob=b.mesh(f'Pier{pier}_bearing_corbel_course{j+1}',[Vector(v)-origin for v in vv],
              [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],'ivory',.035)
            ob.location=origin
            ob['construction_role']='Continuous stepped bearing from pier plinth into rock core'
    for side,x in (('left',-6.5),('right',6.5)):
        for j,z in enumerate((-.44,-.215),1):
            ob=b.box(f'Cornice_return_{side}_course{j}',(x,-5.28,z),(1.20,1.82,.235),'ivory',.045)
            ob['construction_role']='Bonded return linking corner capital and curved deck shell'
    for bay,cx in enumerate((-3.25,3.25),1):
        for j in range(6):
            a=(j+1)*math.pi/7
            b.cylinder(f'Lower_arch_anchor_bay{bay}_{j+1}',(cx+2.84*math.cos(a),-6.54,-6.62+2.84*math.sin(a)),
                       .043,.05,'gold',n=12,axis='Y',bev=.006)
    replacements=b.PARTS[start:]
    assert len(replacements)==120
    # Preserve every unaffected ID; replacement names explicitly describe the
    # new construction roles instead of retaining misleading rivet names.
    mapping={}
    for new,(previous,part_id) in zip(replacements,slots):
        new['part_id']=part_id;new['replaces']=previous.name
        new['revision']='architecture_connection_audit'
        new['lod']='authoring_high'
        new.name=f'CT3_{part_id:04d}_'+new['design_part'];new.data.name=new.name+'_Editable_Triangles'
        mapping[previous.as_pointer()]=new
    ordered=[mapping.get(o.as_pointer(),o) for o in before]
    for previous,_ in slots:bpy.data.objects.remove(previous,do_unlink=True)
    b.PARTS[:]=ordered
    # The lower arch needs depth behind its metal facing to support masonry.
    for o in b.PARTS:
        if o['design_part'].startswith('Lower_iron_arch') and '_web' in o['design_part']:
            # Local Z is world depth because the arch is rotated about X.
            for v in o.data.vertices:v.co.z=.07+(v.co.z-.07)*(1.15/.14)
            o.data.materials[0]=b.M['ivory']
            o['construction_role']='Deep structural arch backing, with a restrained metal anchor facing'
            o.data.update()
    bpy.context.view_layer.update()
    assert len(b.PARTS)==3000
    return replacements

def connection_checks(result):
    checks=[{'name':'3000_parts_preserved','passed':result['part_count']==3000},
      {'name':'80_fitted_curved_ashlar_blocks','passed':result['curved_ashlar_blocks']==80},
      {'name':'12_curved_intrados_liners','passed':result['intrados_lining_blocks']==12},
      {'name':'4_cornice_return_stones','passed':result['cornice_return_blocks']==4},
      {'name':'old_lower_rivet_array_replaced','passed':result['old_repetitive_lower_rivets']==0}]
    for p in result['pier_bearings']:
        checks.append({'name':f"pier_{p['pier']}_continuous_bearing_into_rock",'passed':
          p['support_courses']==4 and p['new_bearing_vertices_inside_rock']>0 and
          p['foot_to_corbel_contact'] and p['corbel_courses_connected']})
    checks.append({'name':'cornice_returns_join_capitals_and_deck','passed':len(result['cornice_returns'])==4 and
      all(r['capital_contact_bounds'] and r['vertices_inside_deck']>0 for r in result['cornice_returns'])})
    checks.append({'name':'lower_arch_backing_has_masonry_depth','passed':len(result['lower_arch_backing_depths_m'])==40 and
      all(d>=1.14 for d in result['lower_arch_backing_depths_m'])})
    return checks

def hydrate():
    b.OUT=OUT
    b.PARTS[:]=sorted([o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith('CT3_')],key=lambda o:o['part_id'])
    b.COLLECTIONS={k:bpy.data.collections[k] for k in b.ALLOC}
    b.ALLOC=dict(Counter(o['family'] for o in b.PARTS))
    b.M={k:bpy.data.materials['MSCT_'+k] for k in ('ivory','cream','gold')}

def main():
    source=OUT/'source/celestial_terrace_3000.blend'
    backup=OUT/'source/before_architecture_audit.blend'
    selected=backup if '--from-backup' in sys.argv else source
    bpy.ops.wm.open_mainfile(filepath=str(selected));hydrate()
    if '--verify-saved' in sys.argv:
        before=json.loads((OUT/'architecture_audit_before.json').read_text())
        after=audit(b.PARTS);checks=connection_checks(after)
        result={'passed':all(c['passed'] for c in checks),'checks':checks,'before':before,'after':after,
                'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
        (OUT/'architecture_audit.json').write_text(json.dumps(result,indent=2))
        print('[ARCHITECTURE CHECKS]',json.dumps(result),flush=True)
        assert result['passed']
        return
    before=audit(b.PARTS)
    (OUT/'architecture_audit_before.json').write_text(json.dumps(before,indent=2))
    print('[AUDIT BEFORE]',json.dumps(before),flush=True)
    if '--audit-only' in sys.argv:return
    if shutil.disk_usage(OUT).free<45*1024*1024:raise RuntimeError('Less than 45 MiB free; source left unchanged')
    bpy.context.preferences.filepaths.save_version=0
    if not backup.exists():bpy.ops.wm.save_as_mainfile(filepath=str(backup),compress=True)
    repair()
    after=audit(b.PARTS);checks=connection_checks(after)
    result={'passed':all(c['passed'] for c in checks),'checks':checks,'before':before,'after':after}
    (OUT/'architecture_audit.json').write_text(json.dumps(result,indent=2))
    print('[AUDIT AFTER]',json.dumps(result),flush=True)
    assert result['passed'],'Connection audit failed; main source not overwritten'
    bpy.context.scene['architecture_audit']='Curved backing, bonded returns, and pier-to-core corbels; geometry-only review'
    bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
    manifest=b.manifest()
    manifest.update(revision='architecture_connection_audit',previous_version='../celestial_terrace_1000/',
      reference_review='Visual/manual comparison, not a numerical image-similarity certificate')
    (OUT/'parts_manifest.json').write_text(json.dumps(manifest,indent=2))
    bpy.ops.object.select_all(action='DESELECT')
    for o in b.PARTS:o.select_set(True)
    bpy.context.view_layer.objects.active=b.PARTS[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT/'celestial_terrace_3000.glb'),export_format='GLB',
       use_selection=True,export_extras=True,export_cameras=False,export_lights=False)
    print('[ARCHITECTURE REPAIR SAVED]',flush=True)

if __name__=='__main__':main()
