"""Reference-led 3,000-part revision; the 1,000-part source remains unchanged.
Run with Blender --background --python-exit-code 1 --python this_file.py.
Options after --: --no-render, --render-only, --quick, --hero-only.
"""
import sys, math, json, random, csv
from pathlib import Path
from collections import Counter
import bpy, bmesh
from mathutils import Vector, Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_mind_spark_celestial_1000 as b
from repair_celestial_architecture import repair, audit, connection_checks

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets3D/mind_spark/celestial_terrace_3000'
TARGET=dict(zip(b.ALLOC,[360,460,470,430,160,290,140,140,550]))
TAU=math.tau
R=random.Random(831003)
QUICK='--quick' in sys.argv
ANGLES=[math.radians(a) for a in (-125,-100,-75,-50,-25,0,25,50,75,105,135,165)]

def family(key):
    b.GROUP=key
    return len(b.PARTS)

def count(start,expected):
    assert len(b.PARTS)-start==expected,(b.GROUP,len(b.PARTS)-start,expected)

def ppolar(a,r,z):return (r*math.cos(a),r*math.sin(a),z)

def limestone(label,loc,size,angle=0):
    """Thin irregular fracture slab: closed convex volume, not a rounded cube."""
    bm=bmesh.new()
    for level in (-1,1):
        for k in range(8):
            a=k*TAU/8
            rr=R.uniform(.80,1.08)
            bm.verts.new((size[0]*.5*math.cos(a)*rr,size[1]*.5*math.sin(a)*rr,
                          size[2]*(level*.46+R.uniform(-.10,.10))))
    bmesh.ops.convex_hull(bm,input=list(bm.verts),use_existing_faces=False)
    data=bpy.data.meshes.new(label);bm.to_mesh(data);bm.free()
    obj=b.finish(bpy.data.objects.new(label,data),label,R.choice(['rock','rock_light','rock_light','rock_shade']),.023,False)
    obj.location=loc;obj.rotation_euler.z=angle
    return obj

def add_rocks():
    s=family('01_Rock_Anchors')
    # Break the six broad boulder rows into finer, irregular strata.
    for row in range(6):
        rad=[8.18,8.18,7.80,6.80,5.50,3.90][row]
        z=[-1.4,-2.65,-4.0,-5.7,-7.45,-9.0][row]
        for j in range(20):
            a=(j+.31*(row%2))*TAU/20
            x,y,_=ppolar(a,rad,z)
            y=max(-5.65,y)
            limestone(f'Fracture_shelf_{row+1}_{j+1:02d}',(x,y,z+R.uniform(-.25,.25)),
                      (R.uniform(1.15,2.0),R.uniform(.50,.95),R.uniform(.32,.75)),a+math.pi/2)
    # Slender downward fractures give the base a hanging, tapered silhouette.
    for j in range(48):
        a=j*TAU/48;r=2.9+2.2*(.5+.5*math.sin(j*2.3));z=-9.0-.55*math.cos(j*1.7)
        limestone(f'Hanging_limestone_fin_{j+1:02d}',ppolar(a,r,z),(.65,.88,2.2+R.random()*1.3),a)
    # Two articulated retaining belts, with independent mounts and fasteners.
    for level,(r,z) in enumerate([(8.50,-2.32),(6.85,-6.1)]):
        for j in range(12):
            a0=math.radians(35)+j*math.radians(195)/12;a1=a0+math.radians(195)/12
            b.sector(f'Retaining_belt_{level+1}_segment{j+1}',r,r+.12,a0+.002,a1-.002,z,z+.15,'gold',bev=.017)
            a=(a0+a1)/2
            b.box(f'Belt_joint_mount_{level+1}_{j+1}',ppolar(a,r+.12,z+.075),(.13,.38,.30),'gold',.025,a)
            obj=b.cylinder(f'Belt_joint_bolt_{level+1}_{j+1}',ppolar(a,r+.20,z+.075),.074,.055,'bronze',n=12,bev=.007)
            obj.rotation_euler=Vector((math.cos(a),math.sin(a),0)).to_track_quat('Z','Y').to_euler()
    count(s,240)

def fine_deck():
    b.ALLOC['02_Civic_Deck']=460
    s=b.begin('02_Civic_Deck')
    rings=[(.62,2.80,48),(2.82,3.55,48),(3.57,4.30,48),(4.32,5.08,48),
           (5.13,5.85,60),(5.87,6.58,60),(6.60,7.18,60),(7.20,7.83,48)]
    for ring,(ri,ro,n) in enumerate(rings):
        shift=.5*(ring%2)
        for i in range(n):
            a=(i+shift)*TAU/n
            b.sector(f'Cut_paving_course{ring+1}_stone{i+1:02d}',ri,ro,a+.001,a+TAU/n-.001,-.22,0,
                     ['ivory','ivory','ivory','cream'][R.randrange(4)],bev=.008,n=5)
    b.cylinder('Compass_centre_medallion',(0,0,.005),.60,.08,'gold',n=96)
    for i in range(24):
        a=i*TAU/24
        pts=[(.67*math.cos(a),.67*math.sin(a)),(2.72*math.cos(a+.018),2.72*math.sin(a+.018)),
             (2.72*math.cos(a+.115),2.72*math.sin(a+.115))]
        b.prism(f'Compass_gold_ray_{i+1:02d}',pts,.003,.012,'gold',.002)
    for r in (.65,2.80,5.11):
        b.cylinder(f'Flush_inlay_ring_{r}',(0,0,-.005),r+.022,.035,'gold',inner=r-.018,n=192,bev=.003)
    for layer,(ri,ro,z0,z1,mat) in enumerate([(0,7.82,-.62,-.24,'cream'),(7.45,8.04,-.40,-.22,'ivory'),(7.55,8.10,-.23,-.12,'gold')]):
        for i in range(4):
            b.sector(f'Deck_cornice_course{layer+1}_quadrant{i+1}',ri,ro,i*TAU/4+.001,(i+1)*TAU/4-.001,z0,z1,mat,bev=.025)
    b.end(s)

def add_facade():
    s=family('03_Civic_Facade')
    # A second tier of crafted iron arches, visible below the main stone bays.
    for bay,cx in enumerate((-3.25,3.25)):
        for j in range(20):
            a0=j*math.pi/20;a1=(j+1)*math.pi/20
            b.arch(f'Lower_iron_arch{bay+1}_web{j+1}',cx,-6.45,-6.62,2.64,3.08,a0+.004,a1-.004,.14,'pearl',.013)
        for rr in (2.71,2.83,2.95):
            for j in range(20):
                a=(j+.5)*math.pi/20
                b.cylinder(f'Lower_rib{bay+1}_rivet_{rr}_{j+1}',(cx+rr*math.cos(a),-6.54,-6.62+rr*math.sin(a)),.039,.05,'gold',n=12,axis='Y',bev=.006)
    for x in (-6.5,0,6.5):
        for j in range(5):
            z=-6.05+j*1.05
            for side in (-1,1):
                b.box('Pier_recess_edge_bead',(x+side*.335,-6.80,z),(.025,.035,.80),'gold',.006)
    # Small cut stones occupy the flat crown band, instead of a featureless slab.
    for j in range(40):
        b.box(f'Cornice_dentil_{j+1:02d}',(-6.7+j*.3436,-6.99,-.39),(.19,.12,.16),'ivory',.014)
    for cx in (-3.25,3.25):
        for j in range(10):
            z=-1.07+j*.058;w=.17*(1-abs(j-4.5)/7)
            b.rod('Keystone_palm_relief',(cx,-7.024,z),(cx+(-w if j%2 else w),-7.024,z+.07),.012,'gold',12)
    count(s,250)

def scroll(label,cx,cy,cz,r,plane='XZ',turns=1.05):
    path=[]
    for j in range(19):
        t=j/18;a=t*TAU*turns;rr=r*(1-.83*t)
        x=rr*math.cos(a);z=rr*math.sin(a)
        path.append((cx+x,cy,cz+z) if plane=='XZ' else (cx,cy+x,cz+z))
    return b.tube(label,path,.017,'gold')

def add_rails():
    s=family('04_Railings_Lamps')
    for i,a in enumerate(ANGLES):
        x,y,_=ppolar(a,7.66,0)
        # Four bowed cage ribs, two rings, a shoulder and a base collar.
        for j in range(4):
            aa=a+j*TAU/4
            b.tube(f'Lantern{i+1}_cage_rib{j+1}',[(x+.075*math.cos(aa),y+.075*math.sin(aa),1.94),
              (x+.15*math.cos(aa),y+.15*math.sin(aa),1.74),(x+.13*math.cos(aa),y+.13*math.sin(aa),1.43)],.012,'gold')
        for z in (1.44,1.90):b.cylinder('Lantern_hexagonal_ring',(x,y,z),.155,.028,'gold',inner=.12,n=6,bev=.003)
        b.cylinder('Lantern_crown_shoulder',(x,y,1.95),.15,.055,'gold',n=6,bev=.006)
        b.cylinder('Lantern_foot_collar',(x,y,1.40),.20,.040,'gold',n=48,bev=.006)
    for panel in range(8):
        a0,a1=ANGLES[panel]+.032,ANGLES[panel+1]-.032
        # Six connected miniature scrolls, six pickets and six raised leaves.
        for j in range(6):
            a=a0+(a1-a0)*(j+.5)/6
            path=[]
            for k in range(17):
                t=k/16;q=t*TAU;rr=.18*(1-.78*t)
                da=rr*math.cos(q)/7.66
                path.append(ppolar(a+da,7.66,.70+rr*math.sin(q)))
            b.tube(f'Balustrade{panel+1}_scroll{j+1}',path,.014,'gold')
            b.rod('Balustrade_fine_picket',ppolar(a,7.66,.40),ppolar(a,7.66,1.04),.012,'gold',12)
            ob=b.sphere('Balustrade_foliated_crest',ppolar(a,7.66,.96),(.055,.12,.12),'gold',2)
            ob.rotation_euler.z=a
    for a in ANGLES:
        for side in (-1,1):
            tang=a+math.pi/2
            x=7.861*math.cos(a)+side*.105*math.cos(tang)
            y=7.861*math.sin(a)+side*.105*math.sin(tang)
            b.rod('Post_panel_edge_pin',(x,y,.39),(x,y,1.04),.010,'gold',12)
    for a in ANGLES[:6]:
        ob=b.sphere('Post_relief_oval',ppolar(a,7.88,.78),(.044,.105,.16),'ivory',2);ob.rotation_euler.z=a
    count(s,270)

def add_access():
    s=family('05_Access')
    for i in range(8):
        for j in range(4):
            b.box('Upper_stair_cut_tread',(-3.52+j*.61,3.55+i*.32,(i+1)*.08+.043),(.596,.31,.023),'ivory',.005)
    for i in range(6):
        for j in range(4):
            b.box('Lower_stair_cut_tread',(-6.8-i*.34,-3.74+j*.525,-i*.2+.069),(.33,.509,.018),'ivory',.004)
    for x in (-3.99,-1.21):
        for y,z in ((3.42,.05),(6.10,.58)):
            b.box('Stair_newel_foot',(x,y,z+.13),(.54,.54,.22),'cream',.035)
            b.box('Stair_newel_shaft',(x,y,z+.53),(.38,.38,.70),'ivory',.025)
            b.box('Stair_newel_cap',(x,y,z+.91),(.51,.51,.13),'ivory',.025)
            b.box('Stair_newel_gold_inset',(x,y-.20,z+.54),(.13,.028,.49),'gold',.010)
            b.cylinder('Stair_newel_crown',(x,y,z+1.03),.14,.09,'gold',n=48)
            b.sphere('Stair_newel_pearl',(x,y,z+1.12),(.17,.17,.15),'pearl',3)
    for j in range(10):
        y=-1.30+j*.73;z=(y+1.68)/12
        b.box('Ramp_cut_stone_joint',(-5.1,y,z+.011),(1.29,.011,.010),'cream',.002)
    count(s,90)

def add_engine():
    s=family('06_Steam_Machinery')
    for y in (-7.535,-7.18):
        for j in range(24):
            a=j*TAU/24
            b.cylinder('Flywheel_rim_fastener',(-1.65+.925*math.cos(a),y,-3.62+.925*math.sin(a)),.028,.024,'bronze',n=6,axis='Y',bev=.004)
    for y in (-7.91,-6.29):
        for j in range(12):
            a=j*TAU/12
            b.cylinder('Bearing_cap_fastener',(-1.65+.27*math.cos(a),y,-3.62+.27*math.sin(a)),.032,.026,'bronze',n=6,axis='Y',bev=.004)
    for z in (-4.40,-2.54):
        for j in range(16):
            a=j*TAU/16
            obj=b.cylinder('Boiler_band_rivet',(-4.76+.416*math.cos(a),-6.73+.416*math.sin(a),z),.025,.025,'bronze',n=12,bev=.003)
            obj.rotation_euler=Vector((math.cos(a),math.sin(a),0)).to_track_quat('Z','Y').to_euler()
    for j in range(24):
        a=j*TAU/24;x=-3.85+.438*math.cos(a);y=-7+.438*math.sin(a)
        b.rod('Cylinder_jacket_fine_flute',(x,y,-4.30),(x,y,-3.21),.011,'gold',12)
    for x,z in ((-4.76,-3.43),(-3.85,-3.62)):
        for j in range(16):
            a=math.radians(-45)+j*math.radians(270)/15
            b.rod('Gauge_engraved_tick',(x+.135*math.cos(a),-7.314,z+.135*math.sin(a)),
              (x+.164*math.cos(a),-7.314,z+.164*math.sin(a)),.0045,'pearl',8)
    for x in (-5.15,-4.22):
        for j in range(4):
            a=j*TAU/4
            b.cylinder('Valve_mount_bolt',(x+.11*math.cos(a),-6.99,-2.8+.11*math.sin(a)),.024,.035,'gold',n=6,axis='Y',bev=.003)
    paths=[((-5.55,-6.77,-2.8),(-5.33,-6.77,-2.8),(-5.11,-6.77,-2.8)),
           ((-3.5,-6.17,-4),(-3.1,-6.15,-4),(-2.7,-6.15,-4)),
           ((-4.76,-6.73,-2.08),(-4.76,-6.73,-2.20),(-4.76,-6.73,-2.32)),
           ((-.30,-6,-3.1),(-.30,-6,-2.85),(-.30,-6,-2.6))]
    for i,path in enumerate(paths):
        for p in path:b.cylinder('Service_pipe_union',p,.087,.052,'gold',inner=.074,n=32,axis='X' if i<2 else 'Z',bev=.004)
    for j in range(6):b.box('Engine_plinth_recessed_panel',(-4.5+j*.68,-7.79,-4.80),(.53,.028,.08),'bronze',.010)
    for y in (-7.91,-7.65,-6.64,-6.21):
        b.cylinder('Drive_shaft_lock_collar',(-1.65,y,-3.62),.139,.045,'gold',inner=.103,n=48,axis='Y',bev=.005)
    count(s,190)

def add_balcony():
    s=family('07_Maintenance_Balcony')
    for j in range(36):
        # Narrow cut paving along the front and returns, clear of the engine.
        if j<24:loc=(-5.44+j*.231,-8.39,-4.948);size=(.222,.18,.025)
        else:loc=(-5.51 if j<30 else -.09,-8.10+(j%6)*.31,-4.948);size=(.20,.30,.025)
        b.box('Balcony_edge_paving',loc,size,'ivory',.005)
    for j in range(12):scroll('Balcony_suspended_volute',-5.30+j*.45,-8.67,-5.35,.19)
    for j in range(12):
        x=-5.25+j*.47
        b.rod('Balcony_fine_upright',(x,-8.58,-4.88),(x,-8.58,-4.13),.012,'gold',12)
        b.box('Balcony_fascia_panel',(x,-8.57,-5.105),(.35,.035,.095),'cream',.013)
    for x in (-4.9,-.8):
        for j in range(9):
            z=-5.2-j*.205
            b.cylinder('Balcony_mount_rivet',(x,-6.42,z),.037,.055,'gold',n=12,axis='Y',bev=.005)
    count(s,90)

def add_basin():
    s=family('08_Basin')
    for j in range(24):
        b.box('Basin_submerged_mosaic',(1.07+(j%8)*.495,3.56+(j//8)*.63,.334),(.475,.61,.013),'teal' if j%3 else 'ivory',.004)
    for j in range(12):
        b.box('Basin_coping_leaf_inlay',(1.0+j*.325,3.145,.766),(.028,.21,.010),'gold',.003,math.pi/5)
    for j in range(16):
        a=j*2.40;r=.22+.036*j
        ob=b.cylinder('Water_ripple_crescent',(3.10+.52*math.cos(a),4.42+.25*math.sin(a),.377+j*.0002),r,.006,'water_glint',inner=r-.007,n=64,bev=.001)
        ob.scale.y=.43
    x,y=2.9,5.36
    for k,(r,h,z,mat) in enumerate([(.48,.12,.76,'ivory'),(.40,.10,.88,'gold'),(.30,.50,1.16,'ivory'),
                (.34,.075,1.44,'gold'),(.28,.13,1.54,'pearl'),(.24,.08,1.63,'gold'),(.17,.11,1.72,'ivory'),(.12,.08,1.81,'gold')]):
        b.cylinder('Fountain_crown_course', (x,y,z),r,h,mat,n=64,bev=.009)
    for j in range(12):
        a=j*TAU/12
        b.rod('Fountain_fluted_reed',(x+.305*math.cos(a),y+.305*math.sin(a),.97),(x+.305*math.cos(a),y+.305*math.sin(a),1.36),.013,'gold',12)
        b.cylinder('Fountain_base_fastener',(x+.36*math.cos(a),y+.36*math.sin(a),.944),.024,.024,'bronze',n=6,bev=.003)
    for j in range(8):
        # Articulated descending spout with visually connected collars.
        t=j/7
        b.cylinder('Fountain_spout_link',(x,y-.22-t*.22,1.28-t*.48),.073,.115,'gold',inner=.052,n=32,axis='Y',bev=.006)
    for j in range(8):
        b.sphere('Fountain_water_drop',(x,y-.48,.73-j*.045),(.033,.033,.047),'water_glint',2)
    count(s,100)

def compound_ellipsoids(label,loc,pieces,mat):
    bm=bmesh.new()
    for centre,size,angle in pieces:
        transform=Matrix.Translation(Vector(centre)) @ Matrix.Rotation(angle,4,'Z') @ Matrix.Diagonal(Vector((*size,1)))
        bmesh.ops.create_uvsphere(bm,u_segments=8,v_segments=6,radius=1,matrix=transform)
    data=bpy.data.meshes.new(label);bm.to_mesh(data);bm.free()
    ob=b.finish(bpy.data.objects.new(label,data),label,mat);ob.location=loc
    return ob

def garden_position(i,n):
    bed=i%2;a0,a1=[(111,184),(18,83)][bed]
    a=math.radians(a0+(a1-a0)*((i//2+.5)/(n/2)))
    r=6.53+R.random()*.61
    return Vector(ppolar(a,r,.51))

def add_gardens():
    s=family('09_Gardens')
    for i in range(200):
        p=garden_position(i,200);p.z+=R.uniform(.14,.46)
        pieces=[]
        for j in range(5):
            a=j*TAU/5
            pieces.append(((.040*math.cos(a),.040*math.sin(a),.004),(.045,.022,.014),a))
        pieces.append(((0,0,.013),(.019,.019,.014),0))
        ob=compound_ellipsoids(f'Individual_ivory_flower_{i+1:03d}',p,pieces,'flower');ob.rotation_euler=(R.uniform(-.3,.3),R.uniform(-.3,.3),R.random()*TAU)
    for i in range(150):
        p=garden_position(i,150);a=R.random()*TAU;pieces=[]
        for j in range(6):
            q=a+j*2.4;h=.05+j*.052
            pieces.append(((.10*math.cos(q),.10*math.sin(q),h),(.16,.041,.012),q))
        compound_ellipsoids(f'Fine_sage_spray_{i+1:03d}',p,pieces,R.choice(['sage','sage','leaf_dark']))
    for i in range(80):
        p=garden_position(i,80);h=.30+R.random()*.26
        b.tube(f'Botanical_branch_{i+1:02d}',[tuple(p),tuple(p+Vector((.02,.01,h*.55))),tuple(p+Vector((.06,.04,h)))],.009,'leaf_dark')
    for bed,(a0,a1) in enumerate([(111,184),(18,83)]):
        for j in range(20):
            a=math.radians(a0+(a1-a0)*(j+.5)/20)
            ob=b.box('Planter_recessed_flute',ppolar(a,6.187,.40),(.030,.20,.20),'cream',.008,a)
    count(s,470)

def materials():
    b.materials()
    b.M['water_glint']=b.make_material('MSCT3_Water_glint',b.rgb('CFE9DD'),.06,.14,transmission=.25)
    # Retain a plain Principled base for GLB; procedural detail is Cycles-only.
    palette={'ivory':'F1E5CF','cream':'E7D8BD','gold':'D3B582','rock':'C4BFAC','rock_light':'DAD2BC',
             'rock_shade':'ACA997','pearl':'E7E0D0','sage':'93A987','leaf_dark':'667F61','copper':'B88E73'}
    for key,col in palette.items():
        mat=b.M[key];mat.diffuse_color=b.rgb(col)
        bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=b.rgb(col)
    for key in ('ivory','cream','rock','rock_light','rock_shade','gold','pearl','copper'):
        nt=b.M[key].node_tree;bs=nt.nodes.get('Principled BSDF')
        tex=nt.nodes.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=11 if 'rock' in key else 42
        tex.inputs['Detail'].default_value=3
        coord=nt.nodes.new('ShaderNodeTexCoord');nt.links.new(coord.outputs['Object'],tex.inputs['Vector'])
        bump=nt.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.22 if 'rock' in key else .12
        bump.inputs['Distance'].default_value=.045 if 'rock' in key else .008
        nt.links.new(tex.outputs['Fac'],bump.inputs['Height']);nt.links.new(bump.outputs[0],bs.inputs['Normal'])
    bs=b.M['water'].node_tree.nodes.get('Principled BSDF')
    bs.inputs['Transmission Weight'].default_value=.58;bs.inputs['Roughness'].default_value=.09

def refine_original_parts():
    for o in b.PARTS:
        label=o['design_part']
        if label.startswith('Sage_cluster'):o.scale*=.78
        if label.startswith('Ivory_blossom_cluster'):o.scale*=.58
        if 'opal_lamp' in label:
            o.scale.x=.78;o.scale.y=.78
        # The old rim band is reduced to a fine reveal, not a broad gold plate.
        if 'Facade_cornice3' in label:
            o.data.materials[0]=b.M['ivory']
        if 'Stratum_' in label:
            o.scale.z*=1.12;o.scale.y*=.83
        if label.startswith('Iron_rib') and '_rivet' in label:
            o.location.y=-6.832
    # Narrower hubs and continuous bearing supports, without adding objects.
    for o in b.PARTS:
        if o['design_part']=='Bearing_pedestal':
            o.scale.z=1.17;o.location.z+=.035
    # Preserve the walkable footprint; elongate only the underside toward the
    # hanging limestone silhouette in the reference.
    bpy.context.view_layer.update()
    for o in b.PARTS:
        if o['family']=='01_Rock_Anchors':
            inv=o.matrix_world.inverted()
            for v in o.data.vertices:
                p=o.matrix_world@v.co
                if p.z < -4:p.z=-4+(p.z+4)*1.32
                v.co=inv@p
            o.data.update()

def setup_scene():
    b.studio()
    scene=bpy.context.scene;scene.cycles.use_auto_tile=False;scene.cycles.samples=32 if QUICK else 64
    scene.render.resolution_x=1500;scene.render.resolution_y=1400
    scene.view_settings.exposure=.55
    # Perspective permits the procedural world clouds to vary across the image.
    cam=scene.camera;cam.data.type='PERSP';cam.data.lens=74
    cam.location=(-27,-37,25);cam.rotation_euler=(Vector((0,0,-3.8))-cam.location).to_track_quat('-Z','Y').to_euler()
    for light in bpy.data.lights:
        if light.name=='Warm_sunrise':light.energy=1.55;light.color=(1,.91,.76)
        if light.name=='Pearl_fill':light.energy=2800
    nt=scene.world.node_tree
    for node in nt.nodes:
        if node.type=='TEX_NOISE':node.inputs['Scale'].default_value=8
        if node.type=='VALTORGB':
            node.color_ramp.elements[0].position=.40;node.color_ramp.elements[0].color=(.63,.75,.80,1)
            node.color_ramp.elements[1].position=.60;node.color_ramp.elements[1].color=(.96,.92,.82,1)
    scene['asset_part_count']=3000
    scene['design_scope']='Reference-led isolated static terrace, not live world replacement'

def render_views():
    scene=bpy.context.scene;scene.cycles.use_auto_tile=False
    scene.cycles.samples=24 if QUICK else 64
    views=[('01_hero',(-27,-37,25),(0,0,-3.8),74,(1500,1400)),
           ('02_arch_detail',(8,-21,4),(3.0,-6.0,-2.45),64,(1200,850)),
           ('03_engine_detail',(1,-18,1),(-2.85,-7,-3.45),62,(1200,850)),
           ('04_civic_detail',(-9,-14,14),(-1.7,2.3,.30),58,(1200,850)),
           ('05_rear_view',(25,31,22),(0,0,-3.3),58,(1400,1500))]
    if '--hero-only' in sys.argv:views=views[:1]
    if '--audit-views' in sys.argv:
        views=[('06_pier_support',(15,-20,4),(5,-5.2,-4.8),62,(1300,1200)),
               ('07_curved_masonry',(7,-19,2),(3.25,-6.1,-3.3),64,(1300,1000))]
    for name,loc,target,lens,size in views:
        cam=scene.camera;cam.data.type='PERSP';cam.data.lens=lens
        cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
        scene.render.resolution_x=size[0];scene.render.resolution_y=size[1]
        scene.render.filepath=str(OUT/'previews'/f'{name}.png')
        bpy.ops.render.render(write_still=True);print('[RENDER]',name,flush=True)

def export():
    bpy.ops.object.select_all(action='DESELECT')
    for o in b.PARTS:o.select_set(True)
    bpy.context.view_layer.objects.active=b.PARTS[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT/'celestial_terrace_3000.glb'),export_format='GLB',
        use_selection=True,export_extras=True,export_cameras=False,export_lights=False)
    for o in b.PARTS:o.select_set(False)

def main():
    b.OUT=OUT
    if '--render-only' in sys.argv:
        bpy.ops.wm.open_mainfile(filepath=str(OUT/'source/celestial_terrace_3000.blend'))
        render_views();return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version=0
    for d in (OUT,OUT/'source',OUT/'previews'):d.mkdir(parents=True,exist_ok=True)
    (OUT/'.gdignore').touch()
    materials()
    for original,extra in ((b.rock,add_rocks),(fine_deck,None),(b.facade,add_facade),(b.railings,add_rails),
                            (b.access,add_access),(b.machinery,add_engine),(b.balcony,add_balcony),(b.basin,add_basin),(b.gardens,add_gardens)):
        original()
        if extra:extra()
        print('[REVISION]',b.GROUP,Counter(o['family'] for o in b.PARTS)[b.GROUP],flush=True)
    assert len(b.PARTS)==3000
    assert dict(Counter(o['family'] for o in b.PARTS))==TARGET
    refine_original_parts()
    repair(b)
    architecture=audit(b.PARTS)
    assert all(c['passed'] for c in connection_checks(architecture))
    for i,o in enumerate(b.PARTS,1):
        o.name=f'CT3_{i:04d}_'+o['design_part'];o.data.name=o.name+'_Editable_Triangles'
        o['part_id']=i;o['revision']='architecture_connection_audit';o['lod']='authoring_high'
    b.ALLOC=TARGET
    bpy.context.view_layer.update()
    result=b.manifest()
    result['revision']='architecture_connection_audit'
    result['previous_version']='../celestial_terrace_1000/'
    result['reference_review']='Visual/manual comparison, not a numerical image-similarity certificate'
    (OUT/'parts_manifest.json').write_text(json.dumps(result,indent=2))
    export();setup_scene()
    ref=bpy.data.images.load(str(ROOT/'docs/concepts/mind_spark_terrain_heavenly_v3.png'))
    ref.name='REFERENCE_Approved_Celestial_Concept';ref.pack()
    notes=bpy.data.texts.new('START_HERE_3000')
    notes.write('Celestial Terrace / 3000 independent mesh parts / nine collections.\n'
                'Select a CT3_ object; Tab edits vertices, edges and triangle faces.\n'
                'Compound floral objects contain separately selectable petal mesh islands.\n'
                'Reference is packed. Shared materials; preliminary UVs; static authoring asset.\n'
                'Procedural stone microdetail is Cycles-only and is not baked into the GLB.\n'
                'Previous 1000-part source, live map and Git history are untouched.\n')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/celestial_terrace_3000.blend'),compress=True)
    print('[SAVED]',len(b.PARTS),result['triangles'],'triangles',flush=True)
    if '--no-render' not in sys.argv:render_views()

if __name__=='__main__':main()
