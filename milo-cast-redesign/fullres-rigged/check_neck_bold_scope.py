"""Compare exported geometry, skinning, materials and every animation channel."""
from pathlib import Path
import json, struct, hashlib
OUT=Path(__file__).resolve().parent
def allowed(name):return name.startswith('Moustache_') or name in ('Chin','Mouth','Neck_Transition')
def extract(path):
    raw=path.read_bytes();size=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+size]);blob=raw[28+size:]
    def acc(i):
        a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']]
        fmt={5120:'b',5121:'B',5122:'h',5123:'H',5125:'I',5126:'f'}[a['componentType']]
        count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
        fmt='<'+fmt*count;stride=v.get('byteStride',struct.calcsize(fmt))
        start=v.get('byteOffset',0)+a.get('byteOffset',0)
        return [struct.unpack_from(fmt,blob,start+j*stride) for j in range(a['count'])]
    nodes=doc['nodes'];meshes={};rests={};motion={}
    parents={child:n['name'] for n in nodes for child in n.get('children',[])}
    for i,node in enumerate(nodes):
        name=node['name']
        if allowed(name):continue
        rests[name]={k:node[k] for k in ('translation','rotation','scale','matrix') if k in node}
        rests[name]['parent']=parents.get(i)
        if 'mesh' not in node:continue
        entries=[]
        joints=[nodes[j]['name'] for j in doc['skins'][node['skin']]['joints']] if 'skin' in node else []
        for p in doc['meshes'][node['mesh']]['primitives']:
            attrs={key:acc(index) for key,index in p['attributes'].items()}
            verts=[]
            for j in range(len(attrs['POSITION'])):
                values=[]
                for key in sorted(attrs):
                    if key.startswith(('JOINTS','WEIGHTS')):continue
                    values.append((key,tuple(round(x,7) for x in attrs[key][j])))
                if joints:
                    weights={}
                    for key in attrs:
                        if not key.startswith('JOINTS_'):continue
                        for b,w in zip(attrs[key][j],attrs[key.replace('JOINTS','WEIGHTS')][j]):
                            if w>1e-7:weights[joints[b]]=round(w,7)
                    values.append(('skin',tuple(sorted(weights.items()))))
                verts.append(tuple(values))
            indices=[v[0] for v in acc(p['indices'])]
            # Triangle order may change; its winding, attributes and skin may not.
            tris=[]
            for k in range(0,len(indices),3):
                tri=tuple(verts[j] for j in indices[k:k+3])
                tris.append(min(tri,tri[1:]+tri[:1],tri[2:]+tri[:2]))
            entries.append((hashlib.sha256(repr(sorted(tris)).encode()).hexdigest(),doc['materials'][p['material']]))
        meshes[name]=entries
    for a in doc['animations']:
        channels={}
        for c in a['channels']:
            target=c['target'];s=a['samplers'][c['sampler']]
            channels[(nodes[target['node']]['name'],target['path'])]=(acc(s['input']),acc(s['output']),s.get('interpolation','LINEAR'))
        motion[a['name']]=channels
    binds={}
    for skin in doc['skins']:
        for j,m in zip(skin['joints'],acc(skin['inverseBindMatrices'])):binds[nodes[j]['name']]=m
    return meshes,rests,motion,binds,hashlib.sha256(raw).hexdigest()
before=extract(OUT/'neck-bold-before/milo_fullres.glb');after=extract(OUT/'milo_fullres.glb')
assert before[0]==after[0],('Protected meshes changed',[n for n in before[0] if before[0][n]!=after[0].get(n)])
assert before[1]==after[1],'Protected node transforms or parents changed'
assert before[2]==after[2],'Animation channels changed'
assert before[3]==after[3],'Inverse bind matrices changed'
result={'passed':True,'sha256':after[4],'baseline_sha256':before[4],
        'protected_meshes':sorted(before[0]),'protected_mesh_count':len(before[0]),
        'all_vertex_attributes_skinning_materials_unchanged':True,'geometry_tolerance_m':1e-7,
        'all_animations_exactly_unchanged':True,'clips':len(before[2]),'bones':len(before[3]),
        'all_rest_transforms_exactly_unchanged':True,
        'scope':'Only central moustache, chin, mouth attachment and added neck transition; skull, eyes, cheek fur, paws, outfit, all bones and all animation channels protected.'}
(OUT/'neck_bold_scope_verification.json').write_text(json.dumps(result,indent=2))
print('NECK_BOLD_SCOPE_PASS',json.dumps({k:v for k,v in result.items() if k!='protected_meshes'}))
