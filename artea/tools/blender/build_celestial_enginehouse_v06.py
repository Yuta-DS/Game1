"""Separate art redesign; reads v05 but never changes it or the live world.
Blender --background --python-exit-code 1 --python this_file -- --quick
--no-render / --render-only / --detail-only are optional.
"""
import bpy,bmesh,sys,math,json,hashlib
from pathlib import Path
from collections import Counter
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_mind_spark_celestial_1000 as b

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'assets3D/mind_spark/celestial_terrace_3000'
OUT=ROOT/'assets3D/mind_spark/celestial_enginehouse_v06'
SOURCE=BASE/'source/celestial_terrace_3000.blend'
TAU=math.tau
COUNTS={};CONNECTIONS=[]

def begin(label):
    global START,CURRENT
    START=len(b.PARTS);CURRENT=label

def end(n):
    new=b.PARTS[START:]
    assert len(new)==n,(CURRENT,len(new),n)
    for o in new:o['assembly']=CURRENT
    COUNTS[CURRENT]=n
    print('[ASSEMBLY]',CURRENT,n,flush=True)

def solid(label,vertices,faces,mat='v6_stone',bevel=.025):
    origin=sum((Vector(v) for v in vertices),Vector())/len(vertices)
    o=b.mesh(label,[Vector(v)-origin for v in vertices],faces,mat,bevel)
    o.location=origin
    # These closed convex prisms have a known outward orientation. Thin, tilted
    # bevels can confuse Blender's normal heuristic; orient the closed result.
    bm=bmesh.new();bm.from_mesh(o.data)
    if all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)<0:
        bmesh.ops.reverse_faces(bm,faces=list(bm.faces));bm.to_mesh(o.data);o.data.update()
    bm.free()
    return o

BOXF=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]

def band(label,front,depth,mat,bev=.015):
    n=len(front)
    vv=front+[(x,y+depth,z) for x,y,z in front]
    ff=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    ff += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return solid(label,vv,ff,mat,bev)

def arch_profile(cx,base=-5.2,spring=-3.45,r=2.56):
    return [(cx-r,base),(cx+r,base)]+[(cx+r*math.cos(k*math.pi/48),spring+r*math.sin(k*math.pi/48)) for k in range(49)]

def xz_prism(label,points,cy,depth,mat,bev=.018):
    o=b.prism(label,points,-depth/2,depth/2,mat,bev)
    o.rotation_euler.x=math.pi/2;o.location.y=cy
    return o

def ring(label,cx,y,z,r,width,depth,mat='gold'):
    return b.cylinder(label,(cx,y,z),r,depth,mat,inner=r-width,n=128,axis='Y',bev=.008)

def support_pos(x,t):
    return Vector((x*(1-.61*t**3),-6.20+3.35*t**3,-.72-9.13*t))

def support_size(t):return (1.22+.54*math.sin(math.pi*t)+.35*t,1.55+.35*math.sin(math.pi*t))

def supports():
    begin('Sculpted rock-rooted buttresses')
    for p,x in enumerate((-6.3,0,6.3),1):
        for j in range(6):
            t0=j/6;t1=(j+1)/6
            top=support_pos(x,t0);bottom=support_pos(x,t1)
            wt,dt=support_size(t0);wb,db=support_size(t1)
            vv=[(bottom.x+sx*wb/2,bottom.y+sy*db/2,bottom.z+.004) for sy in (-1,1) for sx in (-1,1)]
            vv += [(top.x+sx*wt/2,top.y+sy*dt/2,top.z-.004) for sy in (-1,1) for sx in (-1,1)]
            o=solid(f'Buttress{p}_load_stone{j+1}',vv,BOXF,bevel=.045)
            o['role']='Continuous dressed-stone rib: deck bearing to rock embedment'
            # Recessed pale bronze enamel shields follow each sloping course.
            top.z-=.16;bottom.z+=.16
            front=[(bottom.x,bottom.y-db/2-.008,bottom.z),
              (top.x+wt*.31,top.y-dt/2-.008,top.z),
              (top.x-wt*.31,top.y-dt/2-.008,top.z)]
            band(f'Buttress{p}_sculpted_inlay{j+1}',front,.045,'v6_inlay',.018)
            mid=(top+bottom)/2
            b.tube(f'Buttress{p}_gold_spine{j+1}',[(top.x,top.y-dt/2-.055,top.z),
                (mid.x,mid.y-(dt+db)/4-.075,mid.z),(bottom.x,bottom.y-db/2-.055,bottom.z)],.025,'gold')
            b.sphere(f'Buttress{p}_pearl_key{j+1}',(top.x,top.y-dt/2-.075,top.z-.12),(.12,.055,.18),'pearl',2)
        for k in range(3):
            b.box(f'Buttress{p}_capital{k+1}',(x,-6.20,-.70+k*.19),(1.40+k*.26,1.80+k*.18,.22),'v6_stone',.055)
        root=support_pos(x,1)
        b.box(f'Buttress{p}_rock_socket',root,(1.93,1.90,.48),'v6_stone',.09)
        for side in (-1,1):
            path=[]
            for k in range(19):
                t=k/18;v=support_pos(x,t);w,d=support_size(t)
                path.append((v.x+side*w*.43,v.y-d/2-.025,v.z))
            b.tube(f'Buttress{p}_swept_edge{side}',path,.032,'gold')
    end(90)

def canopies():
    begin('Deep carved arch canopies')
    for bay,cx in enumerate((-3.15,3.15),1):
        for j in range(16):
            a0=j*math.pi/16+.005;a1=(j+1)*math.pi/16-.005
            b.arch(f'Canopy{bay}_voussoir{j+1}',cx,-6.52,-3.45,2.56,3.02,a0,a1,1.40,'v6_stone',.035)
            b.arch(f'Canopy{bay}_inset{j+1}',cx,-7.235,-3.45,2.68,2.91,a0+.015,a1-.015,.035,'cream',.015)
            b.arch(f'Canopy{bay}_gold_reveal{j+1}',cx,-7.265,-3.45,2.625,2.652,a0,a1,.035,'gold',.007)
        for r in (2.55,3.02):b.arch(f'Canopy{bay}_continuous_moulding',cx,-7.24,-3.45,r,r+.045,depth=.09,mat='gold',bev=.014)
        # A tapered keystone rather than a rectangular plaque.
        pts=[(cx-.12,-1.24),(cx+.12,-1.24),(cx+.29,-.45),(cx-.29,-.45)]
        xz_prism(f'Canopy{bay}_keystone',pts,-7.34,.18,'v6_stone',.03)
        xz_prism(f'Canopy{bay}_keystone_inset',[(cx-.075,-1.14),(cx+.075,-1.14),(cx+.18,-.55),(cx-.18,-.55)],-7.445,.035,'gold',.01)
        for k in range(4):
            z=-1.10+k*.12
            b.rod(f'Canopy{bay}_palm_ray{k+1}',(cx,-7.48,z),(cx+(-1 if k%2 else 1)*.10,-7.48,z+.14),.014,'pearl',12)
    end(112)

def service_bays():
    begin('Recessed sealed service bays')
    for bay,cx in enumerate((-3.15,3.15),1):
        xz_prism(f'Bay{bay}_sealed_backwall',arch_profile(cx),-6.04,.22,'v6_shadow',.015)
        for side in (-1,1):
            for j in range(3):
                b.box(f'Bay{bay}_jamb_{side}_{j+1}',(cx+side*2.51,-6.37,-4.9+j*.54),(.22,1.12,.535),'v6_stone',.025)
        for j in range(6):
            b.arch(f'Bay{bay}_vault_lining{j+1}',cx,-6.27,-3.45,2.46,2.555,j*math.pi/6+.004,(j+1)*math.pi/6-.004,1.09,'cream',.018)
        for j in range(3):b.box(f'Bay{bay}_bearing_sill{j+1}',(cx-1.67+j*1.67,-6.25,-5.3),(1.66,1.72,.24),'v6_stone',.04)
        # Ten tailored lower-wall panels taper toward the mechanical focal point.
        for j in range(10):
            x0=cx-2.45+j*.49
            xz_prism(f'Bay{bay}_curved_plinth_tile{j+1}',[(x0,-5.16),(x0+.478,-5.16),
             (x0+.478,-4.63+.16*math.cos((j+.5)*math.pi/10)),(x0,-4.63+.16*math.cos(j*math.pi/10))],-6.20,.12,'cream',.025)
        for side in (-1,1):b.rod(f'Bay{bay}_jamb_reveal{side}',(cx+side*2.39,-6.97,-5.15),(cx+side*2.39,-6.97,-3.47),.025,'gold')
        b.box(f'Bay{bay}_service_hatch',(cx,-6.185,-4.72),(1.16,.12,.40),'v6_inlay',.055)
        b.box(f'Bay{bay}_hatch_handle',(cx,-6.285,-4.72),(.38,.09,.045),'gold',.02)
    end(60)

def regulator():
    begin('Sun condenser and pressure regulator')
    cx=3.15;cy=-6.43;cz=-3.0
    b.cylinder('Regulator_pressure_case',(cx,-6.23,cz),1.81,.34,'v6_shadow',n=128,axis='Y',bev=.05)
    b.cylinder('Regulator_recessed_face',(cx,-6.43,cz),1.64,.08,'v6_blue',n=128,axis='Y',bev=.02)
    b.sphere('Regulator_opal_lens',(cx,-6.63,cz),(.62,.28,.62),'v6_light',3)
    b.cylinder('Regulator_centre_bearing',(cx,-6.54,cz),.40,.14,'gold',n=96,axis='Y',bev=.02)
    for r,w,y,mat in ((1.91,.14,-6.44,'v6_stone'),(1.77,.065,-6.56,'gold'),(1.62,.035,-6.57,'gold')):
        ring('Regulator_halo',cx,y,cz,r,w,.14,mat)
    for j in range(12):
        a=j*TAU/12
        o=b.sector(f'Regulator_opal_sector{j+1}',.48,1.59,a+.055,a+TAU/12-.055,-.035,.035,'v6_energy',bev=.012,n=16)
        o.rotation_euler.x=math.pi/2;o.location=(cx,-6.51,cz)
        # Swept turbine petals give the object a distinctive radial silhouette.
        pts=[]
        for k in range(17):
            t=k/16;r=.46+1.10*t;da=.02+.32*t*t
            pts.append((r*math.cos(a+da),r*math.sin(a+da)))
        for k in range(16,-1,-1):
            t=k/16;r=.46+1.10*t;da=.02+.32*t*t+.065+.095*math.sin(math.pi*t)
            pts.append((r*math.cos(a+da),r*math.sin(a+da)))
        petal=xz_prism(f'Regulator_swept_blade{j+1}',pts,-6.64,.14,'gold',.018)
        petal.location.x=cx;petal.location.z=cz
        b.cylinder(f'Regulator_blade_bearing{j+1}',(cx+1.48*math.cos(a+.25),-6.68,cz+1.48*math.sin(a+.25)),.055,.075,'pearl',n=24,axis='Y',bev=.008)
        tick=b.box(f'Regulator_index_tooth{j+1}',(cx+1.85*math.cos(a),-6.55,cz+1.85*math.sin(a)),(.23,.14,.10),'gold',.025)
        tick.rotation_euler.y=-a
        b.cylinder(f'Regulator_case_fastener{j+1}',(cx+1.73*math.cos(a),-6.65,cz+1.73*math.sin(a)),.045,.065,'bronze',n=6,axis='Y',bev=.006)
    for j in range(8):
        a=j*TAU/8
        o=b.box(f'Regulator_compression_lug{j+1}',(cx+1.91*math.cos(a),-6.46,cz+1.91*math.sin(a)),(.28,.28,.13),'v6_stone',.035)
        o.rotation_euler.y=-a
    for r,w,y in ((.45,.04,-6.78),(.96,.026,-6.75),(1.38,.035,-6.73)):
        ring('Regulator_layered_annular_brace',cx,y,cz,r,w,.075,'pearl' if r>.5 else 'gold')
    for j,a in enumerate((.6,2.2)):
        b.rod(f'Regulator_indicator{j+1}',(cx,-6.79,cz),(cx+.28*math.cos(a),-6.79,cz+.28*math.sin(a)),.018,'v6_shadow',16)
    end(80)

def workshop():
    begin('Workshop heat exchanger and instrumentation')
    b.box('Heat_exchanger_frame',(-2.92,-6.23,-2.60),(2.15,.32,2.36),'gold',.12)
    b.box('Heat_exchanger_recess',(-2.92,-6.42,-2.60),(1.92,.07,2.13),'v6_shadow',.08)
    for j in range(12):b.box(f'Heat_exchanger_copper_louvre{j+1}',(-2.92,-6.50,-3.57+j*.176),(1.82,.18,.070),'copper',.025)
    for j in range(6):
        a=.25+j*(math.pi-.5)/5
        o=b.box(f'Workshop_arch_light{j+1}',(-3.15+2.15*math.cos(a),-6.40,-3.45+2.15*math.sin(a)),(.12,.13,.30),'v6_light',.04)
        o.rotation_euler.y=-a+math.pi/2
    for j in range(8):b.cylinder(f'Heat_exchanger_fixing{j+1}',(-2.92+(-1 if j<4 else 1)*1.015,-6.49,-3.45+(j%4)*.56),.039,.06,'bronze',n=6,axis='Y',bev=.005)
    for j in range(4):
        x=-4.67+j*.96;z=-4.65
        b.cylinder(f'Workshop_test_gauge{j+1}',(x,-6.45,z),.16,.16,'gold',n=48,axis='Y',bev=.015)
        b.cylinder(f'Workshop_test_dial{j+1}',(x,-6.55,z),.13,.025,'v6_blue',n=48,axis='Y',bev=.004)
        b.rod(f'Workshop_test_needle{j+1}',(x,-6.58,z),(x+.07,-6.58,z+.06),.007,'pearl',12)
    for j in range(6):
        x=-4.9+j*.65
        b.tube(f'Workshop_vertical_manifold{j+1}',[(x,-6.32,-4.50),(x,-6.32,-3.9),(x+.20,-6.32,-3.7)],.045,'copper')
    for z in (-3.75,-4.5):b.rod('Workshop_header_manifold',(-5.0,-6.32,z),(-1.35,-6.32,z),.073,'gold',32)
    end(48)

def pipes():
    begin('Connected supply and return network')
    supply=[(-4.76,-6.73,-2.02),(-4.76,-7.65,-1.62),(-3.70,-7.65,-.88),
      (-1.1,-7.65,-.88),(.55,-7.65,-.88),(2.45,-7.65,-.88),(3.15,-6.46,-1.1)]
    # Come forward of the right sill before descending; rise outside the
    # balcony's right edge and cross above its rail before returning inboard.
    ret=[(3.15,-6.43,-4.9),(3.15,-7.5,-4.9),(3.15,-7.5,-5.85),
      (.55,-7.5,-5.85),(.55,-7.5,-3.8),(-.58,-7.5,-3.8),(-.58,-6.6,-4.06)]
    for label,points,mat in (('Steam_supply',supply,'gold'),('Condensate_return',ret,'copper')):
        for j,(a,c) in enumerate(zip(points,points[1:])):
            # Each section has explicit mating end coordinates in the data.
            o=b.rod(f'{label}_section{j+1}',a,c,.092,mat,32)
            o['connection_start']=a;o['connection_end']=c
            direction=(Vector(c)-Vector(a)).normalized()
            for k,p in enumerate((a,c)):
                f=b.cylinder(f'{label}_union{j+1}_{k}',p,.14,.105,'gold',n=48,bev=.015)
                f.rotation_euler=direction.to_track_quat('Z','Y').to_euler()
        CONNECTIONS.append({'system':label,'points':points,'joined_section_count':6})
    for j,p in enumerate((supply[3],ret[3])):
        b.sphere(f'Network_valve_body{j+1}',p,(.34,.29,.34),'v6_stone',3)
        b.handwheel_structure(b.cylinder(f'Network_valve_wheel{j+1}',(p[0],p[1]-.23,p[2]),.28,.065,'gold',inner=.23,n=64,axis='Y',bev=.01))
    end(40)

def crown():
    begin('Deck bearing lintels and returns')
    for j in range(12):b.box(f'Deck_transfer_lintel{j+1}',(-6.47+j*1.176,-6.18,-.35),(1.17,1.58,.30),'v6_stone',.04)
    for side in (-1,1):
        for j in range(4):b.box(f'Cornice_corbelling_{side}_{j+1}',(side*(5.3+j*.39),-7.015,-.54),(.24,.24,.23),'cream',.04)
        for j in range(2):b.box(f'Corner_deck_return_{side}_{j+1}',(side*6.30,-5.30,-.35+j*.16),(1.65,2.32,.21),'v6_stone',.055)
    end(24)

def lamps():
    begin('Integrated service lighting')
    for j,x in enumerate((-5.89,-.45,.45,5.89),1):
        b.box(f'Service_sconce{j}_mount',(x,-7.01,-2.55),(.23,.17,.65),'gold',.04)
        b.sphere(f'Service_sconce{j}_opal',(x,-7.16,-2.50),(.18,.19,.43),'v6_light',3)
        for z in (-2.76,-2.25):b.box(f'Service_sconce{j}_hood',(x,-7.14,z),(.31,.30,.10),'v6_stone',.04)
    end(16)

def digest(o):
    h=hashlib.sha256()
    h.update(str(tuple(tuple(row) for row in o.matrix_world)).encode())
    for v in o.data.vertices:h.update(str(tuple(v.co)).encode())
    for f in o.data.polygons:h.update(str(tuple(f.vertices)).encode())
    return h.hexdigest()

def prepare():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    b.OUT=OUT
    original=sorted([o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith('CT3_')],key=lambda o:o['part_id'])
    old=[o for o in original if o['family']=='03_Civic_Facade']
    slots=[o['part_id'] for o in old]
    preserved={o.name:digest(o) for o in original if o not in old}
    b.PARTS[:]=[o for o in original if o not in old]
    for o in old:bpy.data.objects.remove(o,do_unlink=True)
    b.COLLECTIONS={k:bpy.data.collections[k] for k in b.ALLOC}
    b.ALLOC={
      '01_Rock_Anchors':360,'02_Civic_Deck':460,'03_Civic_Facade':470,'04_Railings_Lamps':430,
      '05_Access':160,'06_Steam_Machinery':290,'07_Maintenance_Balcony':140,'08_Basin':140,'09_Gardens':550}
    b.M={m.name.removeprefix('MSCT_'):m for m in bpy.data.materials if m.name.startswith('MSCT_')}
    for key,color,metal,rough,em in [('v6_stone','F1E4CA',0,.36,0),('v6_inlay','BAA985',.25,.4,0),
      ('v6_shadow','364C52',.35,.45,0),('v6_blue','79AAB2',.38,.22,0),('v6_light','E8DBC1',.10,.24,.35),
      ('v6_energy','72AEB2',.20,.25,.20)]:
        b.M[key]=b.make_material('MSCT_'+key,b.rgb(color),metal,rough,emission=b.rgb(color) if em else None,emission_strength=em)
    b.GROUP='03_Civic_Facade'
    return slots,preserved

def render():
    scene=bpy.context.scene
    scene.cycles.use_auto_tile=False;scene.cycles.samples=20 if '--quick' in sys.argv else 64
    views=[('01_hero',(-25,-37,19),(0,-.6,-3.8),70,(1600,1500)),
      ('02_enginehouse',(13,-25,3.3),(1.0,-6,-3.9),60,(1500,1300))]
    if '--detail-only' in sys.argv:views=views[1:]
    for name,loc,target,lens,size in views:
        cam=scene.camera;cam.data.type='PERSP';cam.data.lens=lens;cam.location=loc
        cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
        scene.render.resolution_x=size[0];scene.render.resolution_y=size[1]
        scene.render.filepath=str(OUT/'previews'/f'{name}.png')
        bpy.ops.render.render(write_still=True)
        print('[RENDER]',name,flush=True)

def main():
    for p in (OUT,OUT/'source',OUT/'previews'):p.mkdir(parents=True,exist_ok=True)
    (OUT/'.gdignore').touch()
    if '--render-only' in sys.argv:
        bpy.ops.wm.open_mainfile(filepath=str(OUT/'source/celestial_enginehouse_v06.blend'));render();return
    slots,preserved=prepare();start=len(b.PARTS)
    for fn in (supports,canopies,service_bays,regulator,workshop,pipes,crown,lamps):fn()
    new=b.PARTS[start:];assert len(new)==470
    for o,id in zip(new,slots):
        o['part_id']=id;o['revision']='Celestial Enginehouse v06';o['lod']='authoring_high'
        o.name=f'CE6_{id:04d}_'+o['design_part'];o.data.name=o.name+'_Editable_Triangles'
    b.PARTS.sort(key=lambda o:o['part_id'])
    bpy.context.view_layer.update()
    assert len(b.PARTS)==3000
    assert all(digest(o)==preserved[o.name] for o in b.PARTS if o.name in preserved)
    # Fail on source geometry defects before overwriting this separate revision.
    issues=[]
    for o in new:
        bm=bmesh.new();bm.from_mesh(o.data)
        if bm.calc_volume(signed=True)<=0:issues.append((o.name,'volume'))
        if any(not e.is_manifold for e in bm.edges):issues.append((o.name,'manifold'))
        if any(len(f.verts)!=3 or f.calc_area()<1e-12 for f in bm.faces):issues.append((o.name,'triangles'))
        bm.free()
    if issues:raise RuntimeError(json.dumps(issues))
    result=b.manifest();result.update(name='MineSpark Celestial Enginehouse',revision='v06',new_facade_assemblies=COUNTS,
      source_v05_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),preserved_geometry_objects=len(preserved))
    (OUT/'parts_manifest.json').write_text(json.dumps(result,indent=2))
    (OUT/'design_connections.json').write_text(json.dumps({'systems':CONNECTIONS,'scope':'Static visual routing; no fluid simulation'},indent=2))
    scene=bpy.context.scene;scene.view_settings.exposure=.35
    scene['design_scope']='v06 separate enginehouse redesign, same upper map footprint, static architectural fiction'
    for light in bpy.data.lights:
        if light.name=='Pearl_fill':light.energy=1900
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/celestial_enginehouse_v06.blend'),compress=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in b.PARTS:o.select_set(True)
    bpy.context.view_layer.objects.active=b.PARTS[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT/'celestial_enginehouse_v06.glb'),export_format='GLB',use_selection=True,
      export_extras=True,export_cameras=False,export_lights=False)
    print('[SAVED]',len(b.PARTS),result['triangles'],flush=True)
    if '--no-render' not in sys.argv:render()

if __name__=='__main__':main()
