"""Structural validation only; artistic likeness requires the render comparison."""
from pathlib import Path
import json,math,struct
OUT=Path(__file__).resolve().parent
source=OUT.parent/'statue-face-paws/verify_export.py'
exec(compile(source.read_text().split("g,val,byte_count=")[0],str(source),'exec'))
g,val,size=read(OUT/'milo_reference.glb');old,ov,_=read(OUT.parent/'luxury-coat/milo_luxury_coat.glb');checks=[]
def check(name,ok,**data):checks.append(dict(name=name,passed=bool(ok),**data))
check('self_contained',all('uri' not in x for k in ('buffers','images') for x in g.get(k,[])))
check('original_41_bone_skin',len(g['skins'])==1 and len(g['skins'][0]['joints'])==41)
bad=0;tris=0
for mesh in g['meshes']:
    for p in mesh['primitives']:
        a=p['attributes'];pos=val(a['POSITION']);ws=val(a['WEIGHTS_0']);js=val(a['JOINTS_0']);idx=val(p['indices']);tris+=len(idx)//3
        bad+=sum(not all(math.isfinite(x) for x in r) for r in pos);bad+=sum(abs(sum(r)-1)>1e-4 or min(r)<0 for r in ws);bad+=sum(any(j>=41 for j in r) for r in js);bad+=sum(i[0]>=len(pos) for i in idx)
check('finite_geometry_valid_indices_normalized_weights',bad==0,bad_records=bad)
check('four_original_body_actions',{a['name'] for a in g['animations']}=={a['name'] for a in old['animations']})
for a in g['animations']:
    before=next(b for b in old['animations'] if b['name']==a['name']);oc={(old['nodes'][c['target']['node']]['name'],c['target']['path']):c for c in before['channels']};nc={(g['nodes'][c['target']['node']]['name'],c['target']['path']):c for c in a['channels']};same=oc.keys()==nc.keys()
    for key,c in nc.items():
        s=a['samplers'][c['sampler']];os=before['samplers'][oc[key]['sampler']];v=val(s['output']);v0=ov(os['output'])
        same &= val(s['input'])==ov(os['input']) and len(v)==len(v0) and all(abs(x-y)<1e-5 for r,t in zip(v,v0) for x,y in zip(r,t))
    check(a['name']+'_body_channels_preserved',same)
report={'passed':all(c['passed'] for c in checks),'checks':checks,'triangles':tris,'bytes':size,'meshes':len(g['meshes']),'limits':'Not an artistic-likeness verdict, gameplay test or full AnyCreature certification.'}
(OUT/'verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
if not report['passed']:raise RuntimeError('Reference export checks failed')
