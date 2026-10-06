"""Offline GLB geometry/skin/loop validation. No runtime dependencies."""
from pathlib import Path
import json,struct,math
OUT=Path(__file__).resolve().parent
data=(OUT/'milo_cast.glb').read_bytes();magic,version,total=struct.unpack_from('<III',data)
assert magic==0x46546c67 and version==2 and total==len(data)
length,kind=struct.unpack_from('<II',data,12);assert kind==0x4e4f534a
g=json.loads(data[20:20+length]);binary=data[28+length:]
fmt={5120:'b',5121:'B',5122:'h',5123:'H',5125:'I',5126:'f'};size={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def values(index):
    a=g['accessors'][index];v=g['bufferViews'][a['bufferView']];n=size[a['type']];form='<'+fmt[a['componentType']]*n;step=v.get('byteStride',struct.calcsize(form));start=v.get('byteOffset',0)+a.get('byteOffset',0)
    rows=[struct.unpack_from(form,binary,start+i*step) for i in range(a['count'])]
    if a.get('normalized'):
        divisor={5121:255,5123:65535}[a['componentType']];rows=[tuple(x/divisor for x in r) for r in rows]
    return rows
checks=[]
def check(name,result,**kw):checks.append(dict(name=name,passed=bool(result),**kw))
check('self_contained',all('uri' not in x for key in ['buffers','images'] for x in g.get(key,[])))
check('41_cast_bones',len(g['skins'])==1 and len(g['skins'][0]['joints'])==41)
bad=0;triangles=0;vertices=0;primitives=0
for mesh in g['meshes']:
    for p in mesh['primitives']:
        primitives+=1;positions=values(p['attributes']['POSITION']);vertices+=len(positions)
        bad+=sum(not all(math.isfinite(x) for x in row) for row in positions)
        weights=values(p['attributes']['WEIGHTS_0']);joints=values(p['attributes']['JOINTS_0'])
        bad+=sum(abs(sum(row)-1)>.0001 or min(row)<0 for row in weights)
        bad+=sum(any(j>=41 for j in row) for row in joints)
        indices=values(p['indices']);triangles+=len(indices)//3;bad+=sum(row[0]>=len(positions) for row in indices)
check('geometry_and_normalized_skin_weights',bad==0,bad_records=bad,vertices=vertices,triangles=triangles)
check('cast_scale_triangle_budget',triangles<=6500)
manifest=json.loads((OUT/'animation_manifest.json').read_text());animations=[]
check('expected_clips',set(a['name'] for a in g['animations'])==set(manifest))
for anim in g['animations']:
    name=anim['name'];finite=True;ordered=True;loop_error=0.;end=0.
    for channel in anim['channels']:
        sampler=anim['samplers'][channel['sampler']];times=[v[0] for v in values(sampler['input'])];outputs=values(sampler['output'])
        finite &= all(math.isfinite(x) for row in outputs for x in row);ordered &= times[0]>=0 and all(b>a for a,b in zip(times,times[1:]));end=max(end,times[-1])
        delta=max(abs(a-b) for a,b in zip(outputs[0],outputs[-1]))
        if channel['target']['path']=='rotation':delta=min(delta,max(abs(a+b) for a,b in zip(outputs[0],outputs[-1])))
        loop_error=max(loop_error,delta)
    check(name+'_tracks',finite and ordered and abs(end-manifest[name]['duration'])<.0001,duration=end)
    if manifest[name]['loop']:check(name+'_loop',loop_error<.0001,max_channel_delta=loop_error)
    animations.append({'name':name,'duration':end,'channels':len(anim['channels'])})
report={'passed':all(c['passed'] for c in checks),'checks':checks,'bytes':len(data),'meshes':len(g['meshes']),'material_primitives':primitives,'animations':animations,'limits':'Structural and loop checks only; not a Godot integration or full AnyCreature style/attack certification.'}
(OUT/'glb_validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
if not report['passed']:raise RuntimeError('Export validation failed')
