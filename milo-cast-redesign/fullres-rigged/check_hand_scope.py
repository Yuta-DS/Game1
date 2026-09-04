"""Protect unchanged non-hand geometry across the hand-only revision."""
import struct,json,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent
def read(path):
    b=path.read_bytes();n=struct.unpack_from('<I',b,12)[0]
    return json.loads(b[20:20+n]),b[28+n:]
def geometry(path):
    doc,blob=read(path)
    def accessor(i):
        a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']]
        size={5120:1,5121:1,5122:2,5123:2,5125:4,5126:4}[a['componentType']]*{'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
        start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',size)
        return b''.join(blob[start+j*stride:start+j*stride+size] for j in range(a['count']))
    result={}
    for node in doc['nodes']:
        if 'mesh' not in node or node['name'].startswith(('Milo_Sculpt_Paw','Milo_Articulated_Paw')):continue
        primitives=doc['meshes'][node['mesh']]['primitives']
        result[node['name']]=[]
        for p in primitives:
            positions=list(struct.iter_unpack('<fff',accessor(p['attributes']['POSITION'])))
            positions=[tuple(round(v,7) for v in point) for point in positions]
            kind=doc['accessors'][p['indices']]['componentType']
            indices=[v[0] for v in struct.iter_unpack({5121:'<B',5123:'<H',5125:'<I'}[kind],accessor(p['indices']))]
            triangles=sorted(tuple(sorted(positions[j] for j in indices[i:i+3])) for i in range(0,len(indices),3))
            result[node['name']].append(hashlib.sha256(repr(triangles).encode()).hexdigest())
    return result
before=geometry(OUT/'hand-before/milo_fullres.glb');after=geometry(OUT/'milo_fullres.glb')
assert before==after,[n for n in before if before[n]!=after.get(n)]
report={'unchanged_non_hand_meshes':len(before),'triangle_geometry_identical_within_m':1e-7,'comparison':'Triangle positions canonicalized independently of export vertex/index ordering.','scope':'Paws, hand/digit rig and poses, cane-hold arm/accessory placement, local preview. No live game changes.'}
(OUT/'hand_scope_verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
