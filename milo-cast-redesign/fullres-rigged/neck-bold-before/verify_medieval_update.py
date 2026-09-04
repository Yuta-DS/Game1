"""Check requested dimensions, actual extra geometry, garment replacement."""
import bpy,json,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent
def measure(path):
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(path))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');result={}
    for side in ('L','R'):
        inv=rig.data.bones['hand.'+side].matrix_local.inverted()
        middle=inv@rig.data.bones['finger1.'+side].head_local
        a=inv@rig.data.bones['finger0.'+side].head_local;b=inv@rig.data.bones['finger2.'+side].head_local
        obj=bpy.data.objects['Milo_Articulated_Paw.'+side]
        result[side]={'palm_length_m':middle.y,'knuckle_span_m':abs(b.x-a.x),
            'triangles':sum(len(p.vertices)-2 for p in obj.data.polygons),
            'smooth_faces':sum(p.use_smooth for p in obj.data.polygons),'faces':len(obj.data.polygons)}
    return result
before=measure(OUT/'medieval-before/milo_fullres.glb');after=measure(OUT/'milo_fullres.glb')
ratios={}
for side in ('L','R'):
    ratios[side]={key:after[side][key]/before[side][key] for key in ('palm_length_m','knuckle_span_m','triangles')}
    assert abs(ratios[side]['palm_length_m']-2)<.0001,ratios
    assert abs(ratios[side]['knuckle_span_m']-2)<.0001,ratios
    assert 3.95<ratios[side]['triangles']<4.05,ratios
    assert after[side]['smooth_faces']==after[side]['faces']
required=['Milo_Medieval_Surcoat','Milo_Medieval_Shoulder_Mantle','Milo_Medieval_High_Collar','Milo_Medieval_Burgundy_Doublet','Milo_Medieval_Leather_Belt','Milo_Medieval_Belt_Buckle']
assert all(bpy.data.objects.get(n) for n in required)
assert not any(o.name.startswith(('Milo_Notched_Lapel','Milo_Cravat','Milo_Gold_Tie','Milo_Narrow_Purple','Milo_Coat_Welt')) for o in bpy.data.objects)
report={'sha256':hashlib.sha256((OUT/'milo_fullres.glb').read_bytes()).hexdigest(),'before':before,'after':after,'ratios':ratios,'required_garments':required,'modern_lapels_tie_removed':True,'passed':True}
(OUT/'medieval_update_verification.json').write_text(json.dumps(report,indent=2))
print('MEDIEVAL_UPDATE_PASS',json.dumps(report),flush=True)
