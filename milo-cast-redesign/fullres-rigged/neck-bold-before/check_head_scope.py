"""Read-only GLB comparison: all non-face geometry, materials and motion."""
import struct,json,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent
HEAD_PREFIXES=('Head_','Cheek_','Ear','Eye','Brow_','Glasses_','Moustache_')
def is_head(n):return n.startswith(HEAD_PREFIXES) or n in ('Chin','Mouth','Nose')
def extract(path):
    raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+n]);blob=raw[28+n:]
    def acc(i):
        a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']]
        fmt={5120:'b',5121:'B',5122:'h',5123:'H',5125:'I',5126:'f'}[a['componentType']]
        count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
        fmt='<'+fmt*count;size=struct.calcsize(fmt);stride=v.get('byteStride',size)
        start=v.get('byteOffset',0)+a.get('byteOffset',0)
        return [struct.unpack_from(fmt,blob,start+j*stride) for j in range(a['count'])]
    meshes={}
    for node in doc['nodes']:
        if 'mesh' not in node or is_head(node['name']):continue
        entries=[]
        for p in doc['meshes'][node['mesh']]['primitives']:
            pts=[tuple(round(x,7) for x in v) for v in acc(p['attributes']['POSITION'])]
            inds=[v[0] for v in acc(p['indices'])]
            tris=sorted(tuple(sorted(pts[k] for k in inds[j:j+3])) for j in range(0,len(inds),3))
            m=doc['materials'][p['material']]
            entries.append((hashlib.sha256(repr(tris).encode()).hexdigest(),m))
        meshes[node['name']]=entries
    anim={}
    for a in doc['animations']:
        channels={}
        for c in a['channels']:
            target=c['target'];name=doc['nodes'][target['node']]['name']
            if name in ('eye.L','eye.R'):continue
            s=a['samplers'][c['sampler']]
            data=(acc(s['input']),acc(s['output']),s.get('interpolation','LINEAR'))
            channels[(name,target['path'])]=data
        anim[a['name']]=channels
    return meshes,anim,hashlib.sha256(raw).hexdigest()
before,old_motion,old_hash=extract(OUT/'head-style-before/milo_fullres.glb')
after,new_motion,new_hash=extract(OUT/'milo_fullres.glb')
assert before==after,[n for n in before if before[n]!=after.get(n)]
assert old_motion==new_motion,'Non-eye animation changed'
assert {'Milo_Articulated_Paw.L','Milo_Articulated_Paw.R'}<=set(before)
report={'passed':True,'sha256':new_hash,'baseline_sha256':old_hash,
        'unchanged_non_head_meshes':len(before),'geometry_tolerance_m':1e-7,
        'non_head_materials_unchanged':True,'non_eye_animation_channels_exactly_unchanged':True,
        'clips_compared':len(old_motion),'protected_meshes':sorted(before),
        'scope':'Head geometry, eyes, spectacles, muzzle and ear shapes; eye rest pivots only. No live-game writes.'}
(OUT/'head_scope_verification.json').write_text(json.dumps(report,indent=2))
print('HEAD_SCOPE_PASS',json.dumps({k:v for k,v in report.items() if k!='protected_meshes'}))
