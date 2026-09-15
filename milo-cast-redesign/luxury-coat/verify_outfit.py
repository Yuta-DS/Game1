"""Verify new skin/geometry and preservation of original face and animation."""
from pathlib import Path
import json,struct,math
OUT=Path(__file__).resolve().parent
def read(path):
    data=path.read_bytes();magic,version,total=struct.unpack_from('<III',data);assert magic==0x46546c67 and version==2 and total==len(data)
    length=struct.unpack_from('<I',data,12)[0];g=json.loads(data[20:20+length]);binary=data[28+length:]
    def values(index):
        a=g['accessors'][index];v=g['bufferViews'][a['bufferView']];n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];form='<'+{5121:'B',5123:'H',5125:'I',5126:'f'}[a['componentType']]*n;step=v.get('byteStride',struct.calcsize(form));offset=v.get('byteOffset',0)+a.get('byteOffset',0)
        result=[struct.unpack_from(form,binary,offset+i*step) for i in range(a['count'])]
        if a.get('normalized'):result=[tuple(x/{5121:255,5123:65535}[a['componentType']] for x in r) for r in result]
        return result
    return g,values,len(data)
g,val,byte_count=read(OUT/'milo_luxury_coat.glb');src,sv,_=read(OUT.parent/'milo_cast.glb');checks=[]
def check(name,passed,**info):checks.append(dict(name=name,passed=bool(passed),**info))
check('self_contained',all('uri' not in x for key in ('buffers','images') for x in g.get(key,[])))
check('41_bone_skin',len(g['skins'])==1 and len(g['skins'][0]['joints'])==41)
bad=0;triangles=0
for m in g['meshes']:
    for p in m['primitives']:
        a=p['attributes'];pos=val(a['POSITION']);weights=val(a['WEIGHTS_0']);joints=val(a['JOINTS_0']);indices=val(p['indices']);triangles+=len(indices)//3
        bad+=sum(not all(math.isfinite(x) for x in r) for r in pos);bad+=sum(abs(sum(r)-1)>.0001 or min(r)<0 for r in weights);bad+=sum(any(j>=41 for j in r) for r in joints);bad+=sum(i[0]>=len(pos) for i in indices)
check('finite_geometry_and_normalized_weights',bad==0,bad_records=bad)
check('low_poly_costume_budget',triangles<=7500,triangles=triangles)
def head_positions(doc,reader):
    node=next(n for n in doc['nodes'] if n.get('name')=='Milo_Head_and_Identity');mesh=doc['meshes'][node['mesh']]
    return sorted(p for primitive in mesh['primitives'] for p in reader(primitive['attributes']['POSITION']))
check('face_identity_geometry_unchanged',head_positions(g,val)==head_positions(src,sv))
check('four_existing_actions_preserved',set(a['name'] for a in g['animations'])==set(a['name'] for a in src['animations']))
clips=[]
for a in g['animations']:
    old=next(x for x in src['animations'] if x['name']==a['name']);same=True;loop_delta=0;duration=0
    old_channels={(src['nodes'][c['target']['node']]['name'],c['target']['path']):c for c in old['channels']}
    for c in a['channels']:
        key=(g['nodes'][c['target']['node']]['name'],c['target']['path']);oc=old_channels[key];s=a['samplers'][c['sampler']];os=old['samplers'][oc['sampler']];times=val(s['input']);values=val(s['output']);before=sv(os['output'])
        same &= len(values)==len(before) and val(s['input'])==sv(os['input']) and all(abs(x-y)<.00001 for r,t in zip(values,before) for x,y in zip(r,t))
        delta=max(abs(x-y) for x,y in zip(values[0],values[-1]))
        if key[1]=='rotation':delta=min(delta,max(abs(x+y) for x,y in zip(values[0],values[-1])))
        loop_delta=max(loop_delta,delta);duration=max(duration,times[-1][0])
    check(a['name']+'_motion_preserved',same)
    if a['name']!='Guide':check(a['name']+'_loop',loop_delta<.0001,max_delta=loop_delta)
    clips.append({'name':a['name'],'duration':duration})
report={'passed':all(c['passed'] for c in checks),'checks':checks,'bytes':byte_count,'meshes':len(g['meshes']),'clips':clips,'limits':'Structural and animation-preservation checks; not a Godot or full AnyCreature certification.'}
(OUT/'verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
if not report['passed']:raise RuntimeError('Wardrobe verification failed')
