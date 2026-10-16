"""Replace only v06's 80-part circular regulator with a twin-vessel condenser.
Separate output; --quick, --no-render, --render-only and --detail-only supported.
"""
import bpy,bmesh,sys,math,json,hashlib
from pathlib import Path
from collections import Counter
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_celestial_enginehouse_v06 as v6
b=v6.b
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'assets3D/mind_spark/celestial_enginehouse_v06'
OUT=ROOT/'assets3D/mind_spark/celestial_condenser_v07'
SOURCE=BASE/'source/celestial_enginehouse_v06.blend'
ASSEMBLY='Twin-vessel steam condenser'
INLET=(3.15,-6.46,-1.1)
OUTLET=(3.15,-6.43,-4.9)

def machine():
    start=len(b.PARTS)
    # Nine load-bearing skid/frame pieces; base bears on the existing sill.
    b.box('Condenser_mounting_skid',(3.15,-6.70,-5.08),(3.05,.80,.20),'v6_stone',.055)
    b.box('Condenser_skid_front_trim',(3.15,-7.09,-5.01),(2.97,.065,.08),'gold',.018)
    for x in (2.35,3.95):
        for dx in (-.23,.23):b.box('Condenser_vessel_foot',(x+dx,-6.67,-4.76),(.24,.52,.46),'pearl',.04)
    for x in (1.83,4.47):b.box('Condenser_rear_frame_standard',(x,-6.37,-3.28),(.15,.14,3.40),'gold',.035)
    b.box('Condenser_rear_frame_header',(3.15,-6.37,-1.58),(2.80,.18,.16),'gold',.035)
    # Paired domed pressure vessels: no circular front face or dial hands.
    for i,x in enumerate((2.35,3.95),1):
        mat='pearl' if i==1 else 'copper'
        b.cylinder(f'Condenser_vessel{i}_shell',(x,-6.65,-3.20),.39,2.50,mat,n=96,bev=.03)
        for z in (-1.94,-4.44):b.sphere(f'Condenser_vessel{i}_dished_end',(x,-6.65,z),(.78,.78,.40),mat,3)
        for z in (-1.99,-4.40):b.cylinder(f'Condenser_vessel{i}_end_flange',(x,-6.65,z),.435,.10,'gold',n=96,bev=.018)
        for z in (-2.30,-3.20,-4.08):b.cylinder(f'Condenser_vessel{i}_reinforcement_band',(x,-6.65,z),.416,.075,'gold',n=96,bev=.015)
        b.box(f'Condenser_vessel{i}_level_frame',(x,-7.055,-3.14),(.25,.085,1.20),'gold',.065)
        b.box(f'Condenser_vessel{i}_level_glass',(x,-7.105,-3.14),(.13,.034,1.00),'v6_energy',.025)
        b.cylinder(f'Condenser_vessel{i}_relief_neck',(x,-6.65,-1.62),.075,.29,'copper',n=40,bev=.012)
        b.cylinder(f'Condenser_vessel{i}_relief_cap',(x,-6.65,-1.46),.14,.075,'gold',n=48,bev=.018)
        for j in range(4):
            a=math.pi/4+j*math.pi/2
            b.rod(f'Condenser_vessel{i}_jacket_rib{j+1}',(x+.391*math.cos(a),-6.65+.391*math.sin(a),-4.32),
              (x+.391*math.cos(a),-6.65+.391*math.sin(a),-2.05),.021,'gold',16)
        for dx in (-.23,.23):b.cylinder(f'Condenser_vessel{i}_foot_bolt',(x+dx,-6.91,-4.62),.045,.055,'bronze',n=6,bev=.008)
    # Fifteen exchanger pieces form a narrow, deeply finned central tower.
    b.box('Condenser_heat_exchanger_core',(3.15,-6.62,-3.21),(.60,.33,2.40),'v6_blue',.055)
    for j in range(14):b.box(f'Condenser_cooling_fin{j+1:02d}',(3.15,-6.67,-4.29+j*.17),(.72,.63,.045),'copper',.014)
    paths=[('Condenser_inlet', [INLET,(3.15,-6.46,-1.35),(3.15,-6.46,-1.63)]),
      ('Condenser_inlet_left',[(3.15,-6.46,-1.63),(2.55,-6.46,-1.63),(2.35,-6.65,-1.76)]),
      ('Condenser_inlet_right',[(3.15,-6.46,-1.63),(3.75,-6.46,-1.63),(3.95,-6.65,-1.76)]),
      ('Condenser_return_left',[(2.35,-6.65,-4.60),(2.35,-6.55,-4.80),(3.15,-6.43,-4.80)]),
      ('Condenser_return_right',[(3.95,-6.65,-4.60),(3.95,-6.55,-4.80),(3.15,-6.43,-4.80)]),
      ('Condenser_outlet',[(3.15,-6.43,-4.80),OUTLET])]
    for label,path in paths:
        o=b.tube(label,path,.087,'gold' if 'inlet' in label else 'copper')
        o['connection_start']=path[0];o['connection_end']=path[-1]
    # Flanges at each external port and each vessel's supply/return interface.
    for j,p in enumerate((INLET,OUTLET,(2.35,-6.65,-1.76),(3.95,-6.65,-1.76),(2.35,-6.65,-4.60),(3.95,-6.65,-4.60))):
        b.cylinder(f'Condenser_port_flange{j+1}',p,.15,.070,'gold',n=48,bev=.012)
    for i,x in enumerate((2.35,3.95),1):
        b.box(f'Condenser_valve_body{i}',(x,-7.04,-3.94),(.19,.16,.20),'pearl',.04)
        lever=b.box(f'Condenser_valve_lever{i}',(x+.075,-7.18,-3.82),(.07,.08,.34),'gold',.028)
        lever.rotation_euler.y=.48 if i==1 else -.48
    for x in (1.83,4.47):
        for z in (-4.90,-1.59):b.cylinder('Condenser_frame_anchor',(x,-6.475,z),.052,.055,'bronze',n=6,axis='Y',bev=.008)
    new=b.PARTS[start:]
    assert len(new)==80,len(new)
    for o in new:o['assembly']=ASSEMBLY
    return new

def main():
    for p in (OUT,OUT/'source',OUT/'previews'):p.mkdir(parents=True,exist_ok=True)
    (OUT/'.gdignore').touch()
    v6.OUT=OUT
    if '--render-only' in sys.argv:
        bpy.ops.wm.open_mainfile(filepath=str(OUT/'source/celestial_condenser_v07.blend'))
        v6.render();return
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    original=sorted([o for o in bpy.data.objects if o.type=='MESH' and o.get('part_id')],key=lambda o:o['part_id'])
    removed=[o for o in original if o.get('assembly')=='Sun condenser and pressure regulator']
    assert len(removed)==80
    slots=[(o['part_id'],o.name) for o in removed]
    retained=[o for o in original if o not in removed]
    preserved={o.name:v6.digest(o) for o in retained}
    b.PARTS[:]=retained;b.OUT=OUT
    b.ALLOC=dict(Counter(o['family'] for o in original))
    b.COLLECTIONS={k:bpy.data.collections[k] for k in b.ALLOC}
    b.M={m.name.removeprefix('MSCT_'):m for m in bpy.data.materials if m.name.startswith('MSCT_')}
    b.GROUP='03_Civic_Facade'
    for o in removed:bpy.data.objects.remove(o,do_unlink=True)
    new=machine()
    for o,(id,previous) in zip(new,slots):
        o['part_id']=id;o['replaces']=previous;o['revision']='v07 condenser replacement';o['lod']='authoring_high'
        o.name=f'CC7_{id:04d}_'+o['design_part'];o.data.name=o.name+'_Editable_Triangles'
    b.PARTS.sort(key=lambda o:o['part_id'])
    bpy.context.view_layer.update()
    assert len(b.PARTS)==3000
    assert all(v6.digest(o)==preserved[o.name] for o in retained)
    failures=[]
    for o in new:
        bm=bmesh.new();bm.from_mesh(o.data)
        if bm.calc_volume(signed=True)<=0 or any(not e.is_manifold for e in bm.edges):failures.append(o.name)
        if any(len(f.verts)!=3 or f.calc_area()<=1e-12 for f in bm.faces):failures.append(o.name)
        bm.free()
    assert not failures,failures
    manifest=b.manifest();manifest.update(name='MineSpark Twin-vessel Condenser',revision='v07',replacement_parts=80,
      preserved_geometry_objects=2920,source_v06_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
      inlet=INLET,outlet=OUTLET,scope='Separate static machine replacement; architecture and live world unchanged')
    (OUT/'parts_manifest.json').write_text(json.dumps(manifest,indent=2))
    bpy.context.scene['design_scope']='v07 replaces the clock-like assembly with a static twin-vessel condenser'
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/celestial_condenser_v07.blend'),compress=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in b.PARTS:o.select_set(True)
    bpy.context.view_layer.objects.active=b.PARTS[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT/'celestial_condenser_v07.glb'),export_format='GLB',use_selection=True,
      export_extras=True,export_cameras=False,export_lights=False)
    print('[V07 SAVED]',len(b.PARTS),manifest['triangles'],flush=True)
    if '--no-render' not in sys.argv:v6.render()

if __name__=='__main__':main()
