"""Celestial Terrace: exactly 1000 independently editable, triangulated mesh parts.
Run in Blender 5: --background --python-exit-code 1 --python this_file.py
Flags after --: --no-render, --quick (lower resolution/samples).
This asset is NOT inserted into a live world.
"""
from __future__ import annotations
import bpy, bmesh, math, random, json, csv, sys, hashlib
from pathlib import Path
from collections import Counter
from mathutils import Vector, Matrix

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets3D/mind_spark/celestial_terrace_1000'
sys.path.insert(0,str(Path(__file__).resolve().parent))
from build_mind_spark_luxury_steam_kit import make_material
TAU=math.tau
RNG=random.Random(31028)
PARTS=[]; M={}; GROUP=None; COLLECTIONS={}
ALLOC={'01_Rock_Anchors':120,'02_Civic_Deck':160,'03_Civic_Facade':220,
       '04_Railings_Lamps':160,'05_Access':70,'06_Steam_Machinery':100,
       '07_Maintenance_Balcony':50,'08_Basin':40,'09_Gardens':80}
QUICK='--quick' in sys.argv

def rgb(h):
    v=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in v)+(1,)

def materials():
    specs={'ivory':('EFE4CE',0,.46),'cream':('E3D3B8',0,.52),
      'gold':('D4B67A',.75,.27),'bronze':('8B795D',.65,.34),
      'pearl':('E7E7D9',.3,.24),'copper':('BF927A',.74,.29),
      'slate':('75828D',.12,.55),'rock':('C5C1B2',0,.8),
      'rock_light':('DDD5C0',0,.78),'rock_shade':('ABB1B0',0,.83),
      'soil':('807967',0,.95),'sage':('A0B59A',0,.74),
      'leaf_dark':('718C77',0,.73),'flower':('FFF4DD',0,.38),
      'teal':('78AFB2',.25,.3),'water':('97D8D4',.15,.14),
      'glass':('F5DEB3',.15,.18)}
    for k,(h,metal,rough) in specs.items():
        M[k]=make_material('MSCT_'+k,rgb(h),metal,rough,
              emission=rgb('FFDB9C') if k=='glass' else None,
              emission_strength=.65 if k=='glass' else 0,
              transmission=.25 if k=='water' else (.12 if k=='glass' else 0))

def begin(name):
    global GROUP
    GROUP=name
    col=bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    col.asset_mark()
    COLLECTIONS[name]=col
    return len(PARTS)

def end(start):
    n=len(PARTS)-start
    print('[CELESTIAL]',GROUP,n,'/',ALLOC[GROUP],flush=True)
    assert n==ALLOC[GROUP],(GROUP,n,ALLOC[GROUP])

def finish(obj,label,mat='ivory',bevel=0,smooth=True):
    if obj.type!='MESH':
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True); bpy.context.view_layer.objects.active=obj
        bpy.ops.object.convert(target='MESH')
        obj=bpy.context.object
    for col in list(obj.users_collection): col.objects.unlink(obj)
    COLLECTIONS[GROUP].objects.link(obj)
    obj.name=f'CT_{len(PARTS)+1:04d}_{label}'
    obj.data.name=obj.name+'_Editable_Triangles'
    obj.data.materials.append(M[mat])
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    if bevel:
        extent=[max(v.co[k] for v in bm.verts)-min(v.co[k] for v in bm.verts) for k in range(3)]
        bevel=min(bevel,min(extent)*.20)
        bmesh.ops.bevel(bm,geom=list(bm.edges),offset=bevel,segments=3,
                        affect='EDGES',clamp_overlap=True)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6)
    orphaned=[v for v in bm.verts if not v.link_faces]
    if orphaned:bmesh.ops.delete(bm,geom=orphaned,context='VERTS')
    for f in bm.faces:f.smooth=smooth
    for e in bm.edges:
        if len(e.link_faces)==2:e.smooth=e.calc_face_angle()<math.radians(38)
    bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
    bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    # A simple deterministic UV layout makes every part ready for manual painting.
    uv=obj.data.uv_layers.new(name='Editable_UV')
    for poly in obj.data.polygons:
        axis=max(range(3),key=lambda i:abs(poly.normal[i]))
        axes=[i for i in range(3) if i!=axis]
        for li in poly.loop_indices:
            co=obj.data.vertices[obj.data.loops[li].vertex_index].co
            uv.data[li].uv=(co[axes[0]]*.25,co[axes[1]]*.25)
    obj['part_id']=len(PARTS)+1;obj['family']=GROUP
    obj['editable']='Independent mesh; Tab for vertices / edges / triangular faces'
    obj['design_part']=label;obj['units']='metres'
    obj['smooth_angle_degrees']=38
    PARTS.append(obj);obj.select_set(False)
    return obj

def mesh(label,v,f,mat='ivory',bevel=0,smooth=True):
    data=bpy.data.meshes.new(label);data.from_pydata(v,[],f);data.update()
    return finish(bpy.data.objects.new(label,data),label,mat,bevel,smooth)

def box(label,loc,size,mat='ivory',bev=.035,rz=0):
    x,y,z=[a/2 for a in size]
    v=[(sx*x,sy*y,sz*z) for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)]
    obj=mesh(label,v,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],mat,bev)
    obj.location=loc;obj.rotation_euler.z=rz
    return obj

def prism(label,points,z0,z1,mat='ivory',bev=.015):
    n=len(points);v=[(x,y,z) for z in (z0,z1) for x,y in points]
    f=[tuple(reversed(range(n))),tuple(range(n,n*2))]
    f += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(label,v,f,mat,bev)

def sector(label,ri,ro,a0,a1,z0,z1,mat='ivory',center=(0,0),bev=.014,n=None):
    n=n or max(4,int(abs(a1-a0)*32))
    points=[(center[0]+ro*math.cos(a0+(a1-a0)*i/n),center[1]+ro*math.sin(a0+(a1-a0)*i/n)) for i in range(n+1)]
    if ri>0:
        points += [(center[0]+ri*math.cos(a0+(a1-a0)*i/n),center[1]+ri*math.sin(a0+(a1-a0)*i/n)) for i in range(n,-1,-1)]
    else:points.append(center)
    return prism(label,points,z0,z1,mat,bev)

def tube(label,path,r,mat='gold',sides=12):
    curve=bpy.data.curves.new(label,'CURVE');curve.dimensions='3D'
    curve.resolution_u=8;curve.bevel_depth=r;curve.bevel_resolution=3;curve.use_fill_caps=True
    spline=curve.splines.new('BEZIER');spline.bezier_points.add(len(path)-1)
    for p,co in zip(spline.bezier_points,path):
        p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    obj=bpy.data.objects.new(label,curve);bpy.context.scene.collection.objects.link(obj)
    return finish(obj,label,mat)

def rod(label,a,b,r,mat='gold',n=24):
    a,b=Vector(a),Vector(b);length=(b-a).length
    obj=cylinder(label,(a+b)/2,r,length,mat,n=n)
    obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return obj

def cylinder(label,loc,r,h,mat='gold',inner=0,n=48,axis='Z',bev=.012):
    if inner:
        v=[(rr*math.cos(i*TAU/n),rr*math.sin(i*TAU/n),z) for z in (-h/2,h/2) for rr in (r,inner) for i in range(n)]
        f=[]
        for i in range(n):
            j=(i+1)%n
            f += [(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),
                  (i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)]
    else:
        v=[(r*math.cos(i*TAU/n),r*math.sin(i*TAU/n),z) for z in (-h/2,h/2) for i in range(n)]
        f=[tuple(reversed(range(n))),tuple(range(n,2*n))]
        f += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    obj=mesh(label,v,f,mat,bev);obj.location=loc
    if axis=='Y':obj.rotation_euler.x=math.pi/2
    if axis=='X':obj.rotation_euler.y=math.pi/2
    return obj

def handwheel_structure(obj):
    """Stem and three spokes remain editable mesh islands of one wheel part."""
    bm=bmesh.new();bm.from_mesh(obj.data)
    def spoke(a,b,r):
        a,b=Vector(a),Vector(b)
        transform=Matrix.Translation((a+b)/2) @ (b-a).to_track_quat('Z','Y').to_matrix().to_4x4()
        bmesh.ops.create_cone(bm,cap_ends=True,cap_tris=True,segments=16,
                             radius1=r,radius2=r,depth=(b-a).length,matrix=transform)
    spoke((0,0,-.31),(0,0,.035),.035)
    for i in range(3):
        a=i*TAU/3
        spoke((.018*math.cos(a),.018*math.sin(a),0),(.22*math.cos(a),.22*math.sin(a),0),.021)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    for face in bm.faces:face.smooth=True
    for edge in bm.edges:
        if len(edge.link_faces)==2:edge.smooth=edge.calc_face_angle()<math.radians(38)
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    uv=obj.data.uv_layers.active
    for poly in obj.data.polygons:
        axis=max(range(3),key=lambda i:abs(poly.normal[i]))
        axes=[i for i in range(3) if i!=axis]
        for li in poly.loop_indices:
            co=obj.data.vertices[obj.data.loops[li].vertex_index].co
            uv.data[li].uv=(co[axes[0]]*.25,co[axes[1]]*.25)
    return obj

def arch(label,cx,y,cz,ri,ro,a0=0,a1=math.pi,depth=.45,mat='ivory',bev=.02):
    obj=sector(label,ri,ro,a0,a1,-depth/2,depth/2,mat,bev=bev,n=max(4,int((a1-a0)*38)))
    obj.location=(cx,y,cz);obj.rotation_euler.x=math.pi/2
    return obj

def sphere(label,loc,size,mat='ivory',sub=2,rough=0):
    bm=bmesh.new();bmesh.ops.create_icosphere(bm,subdivisions=sub,radius=1)
    for v in bm.verts:
        v.co.x*=size[0]/2;v.co.y*=size[1]/2;v.co.z*=size[2]/2
        if rough:v.co*=RNG.uniform(1-rough,1+rough)
    data=bpy.data.meshes.new(label);bm.to_mesh(data);bm.free()
    obj=finish(bpy.data.objects.new(label,data),label,mat,smooth=not rough)
    obj.location=loc;return obj

def grate(label,loc,w,d,mat='bronze',spacing=.14):
    verts=[];faces=[]
    def bar(x,y,sx,sy):
        off=len(verts)
        verts.extend([(x+a*sx/2,y+b*sy/2,c*.028) for c in (-1,1) for b in (-1,1) for a in (-1,1)])
        faces.extend([tuple(off+i for i in f) for f in [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]])
    for i in range(int(w/spacing)+1):bar(-w/2+i*w/int(w/spacing),0,.035,d)
    for j in range(int(d/spacing)+1):bar(0,-d/2+j*d/int(d/spacing),w,.035)
    obj=mesh(label,verts,faces,mat,.007);obj.location=loc
    return obj

def rock():
    s=begin('01_Rock_Anchors')
    levels=[(7.6,-.6),(8,-2),(7.7,-4),(6.4,-6.3),(4.8,-8.2),(2.4,-10.2),(.4,-11.6)]
    n=48;v=[]
    for r,z in levels:
        for i in range(n):
            a=i*TAU/n;rr=r+RNG.uniform(-.25,.25)
            v.append((rr*math.cos(a),max(-5.05,rr*math.sin(a)),z+RNG.uniform(-.1,.1)))
    f=[tuple(reversed(range(n))),tuple(range((len(levels)-1)*n,len(levels)*n))]
    for k in range(len(levels)-1):
        for i in range(n):
            a=k*n+i;b=k*n+(i+1)%n;f.append((a,b,b+n,a+n))
    mesh('Island_structural_rock_core',v,f,'rock',.08,False)
    for layer,(n,r,z,sz) in enumerate([(28,7.45,-1.5,1.7),(24,7.55,-3.1,1.85),(20,6.8,-5,2.15),(16,5.7,-6.9,2.4),(12,4.05,-8.5,2.4),(8,2.1,-10.1,2.2)]):
        for i in range(n):
            a=(i+.32*(layer%2))*TAU/n
            # Irregular convex fracture volumes, not dressed masonry blocks.
            rr=r+RNG.uniform(-.32,.25)
            dims=(TAU*r/n*1.2,1.65,sz)
            points=[]
            for level in range(3):
                for q in range(7):
                    ang=q*TAU/7+.15*(level%2)
                    rad=RNG.uniform(.67,1.02) if level==1 else RNG.uniform(.56,.92)
                    points.append((math.cos(ang)*dims[0]*.62*rad,
                                   math.sin(ang)*dims[1]*.64*rad,
                                   (level-1)*dims[2]*.48+RNG.uniform(-.19,.19)))
            bm=bmesh.new()
            for co in points:bm.verts.new(co)
            bmesh.ops.convex_hull(bm,input=list(bm.verts),use_existing_faces=False)
            data=bpy.data.meshes.new('Fractured_limestone');bm.to_mesh(data);bm.free()
            obj=finish(bpy.data.objects.new('rock',data),f'Stratum_{layer+1:02d}_fracture_{i+1:02d}',
                       RNG.choice(['rock','rock','rock_light','rock_shade']),.047,False)
            obj.rotation_euler.z=a+math.pi/2
            obj.location=(rr*math.cos(a),rr*math.sin(a),z+RNG.uniform(-.22,.22))
            bpy.context.view_layer.update()
            front=min((obj.matrix_world@vv.co).y for vv in obj.data.vertices)
            if front < -5.80:obj.location.y+=-5.80-front
    for i in range(3):
        sphere(f'Terminal_limestone_shard_{i}',((i-1)*.48,.15,-11.25-i*.14),(1.6,1.6,2.1),'rock',2,.18)
    for i in range(8):
        a=i*TAU/8
        obj=sector(f'Cliff_anchor_band_{i}',7.79,7.9,a+.008,a+TAU/8-.008,-3.22,-3.04,'gold',bev=.025)
        front=min(v.co.y for v in obj.data.vertices)
        if front < -5.2:obj.location.y+=-5.2-front
    end(s)

def deck():
    s=begin('02_Civic_Deck')
    for ring,(ri,ro,n) in enumerate([(.62,2.8,24),(2.82,5.1,32),(5.12,6.7,32),(6.72,7.83,32)]):
        for i in range(n):
            a=i*TAU/n
            sector(f'Paving_ring{ring+1}_stone{i+1:02d}',ri,ro,a+.0018,a+TAU/n-.0018,-.22,0,
                   'ivory' if (i+ring)%5 else 'cream',bev=.014)
    cylinder('Compass_centre_medallion',(0,0,.005),.60,.08,'gold',n=96)
    for i in range(24):
        a=i*TAU/24
        # Tapered sun rays alternate with quiet ivory sectors.
        points=[(.67*math.cos(a),.67*math.sin(a)),
                (2.72*math.cos(a+.018),2.72*math.sin(a+.018)),
                (2.72*math.cos(a+.115),2.72*math.sin(a+.115))]
        prism(f'Compass_gold_ray_{i+1:02d}',points,.003,.012,'gold',.002)
    for r in (.65,2.80,5.11):
        cylinder(f'Flush_inlay_ring_{r}',(0,0,-.005),r+.022,.035,'gold',inner=r-.018,n=192,bev=.003)
    for layer,(ri,ro,z0,z1,mat) in enumerate([(0,7.82,-.62,-.24,'cream'),(7.45,8.04,-.40,-.22,'ivory'),(7.55,8.10,-.23,-.12,'gold')]):
        for i in range(4):
            sector(f'Deck_cornice_course{layer+1}_quadrant{i+1}',ri,ro,i*TAU/4+.001,(i+1)*TAU/4-.001,z0,z1,mat,bev=.035)
    end(s)

def facade():
    s=begin('03_Civic_Facade')
    for bay,cx in enumerate((-3.25,3.25)):
        for i in range(13):
            arch(f'Arch{bay+1}_voussoir_{i+1:02d}',cx,-6.34,-3.65,2.50,3.08,i*math.pi/13+.006,(i+1)*math.pi/13-.006,.90,'ivory',.027)
        for rr in (2.48,3.09):
            arch(f'Arch{bay+1}_molded_gold_edge_{rr}',cx,-6.85,-3.65,rr,rr+.065,depth=.10,mat='gold',bev=.018)
        for i in range(9):
            a=(i+1)*math.pi/10
            rod(f'Arch{bay+1}_sunburst_relief_{i}',(cx+2.72*math.cos(a),-6.83,-3.65+2.72*math.sin(a)),
                (cx+2.99*math.cos(a),-6.84,-3.65+2.99*math.sin(a)),.043,'gold',16)
        # Elongated keystone in the sculpted stone face.
        box(f'Arch{bay+1}_crown_keystone',(cx,-6.88,-.78),(.48,.25,.82),'cream',.06)
    for p,x in enumerate((-6.5,0,6.5)):
        for j,(w,d,h,z) in enumerate([(1.12,1.36,.24,-7.03),(1.04,1.25,.19,-6.82),(.92,1.13,.18,-6.64)]):
            box(f'Pier{p+1}_plinth_course{j+1}',(x,-6.26,z),(w,d,h),'ivory',.045)
        for j in range(5):
            box(f'Pier{p+1}_shaft_course{j+1}',(x,-6.23,-6.05+j*1.05),(.83,1.1,1.025),'ivory',.035)
        for j in range(3):
            box(f'Pier{p+1}_capital_course{j+1}',(x,-6.25,-.73+j*.17),(.95+j*.16,1.22+j*.13,.18),'ivory',.04)
        box(f'Pier{p+1}_inset_plaque',(x,-6.805,-2.95),(.58,.08,2.2),'cream',.06)
        for j in range(3):
            box(f'Pier{p+1}_gold_flute{j}',(x+(j-1)*.17,-6.86,-2.94),(.034,.035,1.86),'gold',.012)
        sphere(f'Pier{p+1}_gold_crest',(x,-6.91,-1.99),(.25,.08,.34),'gold',2)
    for cx in (-3.25,3.25):
        for side in (-1,1):
            # Solid spandrel between an arch's extrados and the level cornice.
            rr=3.13; pts=[(cx+side*rr,-.5),(cx,-.5)]
            for j in range(17):
                a=math.pi/2*(1-j/16)
                pts.append((cx+side*rr*math.cos(a),-3.65+rr*math.sin(a)))
            obj=prism('Spandrel_sculpted_closure',pts,-.27,.27,'cream',.014)
            obj.rotation_euler.x=math.pi/2;obj.location.y=-6.24
    for layer,(z,d,h,mat) in enumerate([(-.51,1.20,.20,'cream'),(-.30,1.35,.20,'ivory'),(-.16,1.45,.065,'gold')]):
        for i in range(6):
            box(f'Facade_cornice{layer+1}_block{i+1}',(-5.75+i*2.3,-6.25,z),(2.28,d,h),mat,.025)
    for bay,cx in enumerate((-3.25,3.25)):
        for layer in range(3):
            arch(f'Iron_rib{bay+1}_layer{layer+1}',cx,-6.5-layer*.11,-3.65,2.16+layer*.11,2.27+layer*.11,depth=.18,
                 mat='pearl' if layer!=1 else 'gold',bev=.015)
        for i in range(14):
            a=(i+.5)*math.pi/14
            cylinder(f'Iron_rib{bay+1}_rivet{i+1}',(cx+2.3*math.cos(a),-6.92,-3.65+2.3*math.sin(a)),.061,.055,'gold',n=12,axis='Y',bev=.009)
    for p,x in enumerate((-6.5,0,6.5)):
        for j in range(6):
            cylinder(f'Pier{p+1}_rosette{j+1}',(x+(-.26 if j%2 else .26),-6.86,-5.9+(j//2)*.56),.052,.042,'gold',n=12,axis='Y',bev=.01)
        for j in range(8):
            z=-4.4+(j//2)*.35
            rod(f'Pier{p+1}_chevron{j+1}',(x,-6.875,z),(x+(-.23 if j%2 else .23),-6.875,z+.25),.022,'gold',12)
        for j in range(4):
            box(f'Pier{p+1}_capital_flute{j+1}',(x+(j-1.5)*.14,-6.88,-1.0),(.035,.04,.35),'gold',.01)
        for j in range(4):
            cylinder(f'Pier{p+1}_foot_anchor{j+1}',(x+(j%2-.5)*.6,-6.95,-6.8+(j//2)*.24),.075,.06,'bronze',n=6,axis='Y',bev=.012)
    end(s)

def railings():
    s=begin('04_Railings_Lamps')
    angles=[math.radians(a) for a in (-125,-100,-75,-50,-25,0,25,50,75,105,135,165)]
    for i,a in enumerate(angles):
        x,y=7.66*math.cos(a),7.66*math.sin(a)
        box(f'Post{i+1}_plinth',(x,y,.13),(.6,.6,.26),'cream',.05,a)
        box(f'Post{i+1}_shaft',(x,y,.72),(.38,.38,1.02),'ivory',.035,a)
        box(f'Post{i+1}_inset_panel',(x+.2*math.cos(a),y+.2*math.sin(a),.72),(.055,.19,.67),'gold',.018,a)
        box(f'Post{i+1}_capital',(x,y,1.25),(.52,.52,.16),'ivory',.04,a)
        cylinder(f'Post{i+1}_lamp_base',(x,y,1.37),.18,.10,'gold',n=32)
        sphere(f'Post{i+1}_opal_lamp',(x,y,1.68),(.24,.24,.53),'glass',3)
        cylinder(f'Post{i+1}_lamp_cap',(x,y,1.98),.12,.11,'gold',n=32)
        cylinder(f'Post{i+1}_lamp_finial',(x,y,2.09),.044,.16,'gold',n=20)
    for i in range(8):
        a0,a1=angles[i]+.032,angles[i+1]-.032;ac=(a0+a1)/2
        sector(f'Balustrade{i+1}_stone_sill',7.43,7.84,a0,a1,.03,.20,'ivory',bev=.025)
        for z in (1.06,.38):
            path=[(7.66*math.cos(a0+(a1-a0)*j/12),7.66*math.sin(a0+(a1-a0)*j/12),z) for j in range(13)]
            tube(f'Balustrade{i+1}_curved_rail_{z}',path,.045,'gold')
        # Two broad fans and two diagonals, visibly shaped rather than a square grid.
        for side in (-1,1):
            aa=ac+side*(a1-a0)*.38
            path=[]
            for j in range(9):
                t=j/8;a=ac+(aa-ac)*t
                path.append((7.66*math.cos(a),7.66*math.sin(a),.41+.61*math.sin(t*math.pi/2)))
            tube(f'Balustrade{i+1}_fan_{side}',path,.028,'gold')
            rod(f'Balustrade{i+1}_diagonal_{side}',
                (7.66*math.cos(ac),7.66*math.sin(ac),.42),
                (7.66*math.cos(aa),7.66*math.sin(aa),.99),.021,'bronze',12)
        x,y=7.66*math.cos(ac),7.66*math.sin(ac)
        obj=box(f'Balustrade{i+1}_diamond',(x,y,.70),(.17,.06,.17),'gold',.025,ac-math.pi/2)
        obj.rotation_euler.y=math.pi/4
    end(s)

def access():
    s=begin('05_Access')
    for i in range(8):
        z=(i+1)*.08;y=3.55+i*.32
        box(f'Upper_stair{i+1}_core',(-2.6,y,z/2),(2.45,.34,z),'cream',.018)
        box(f'Upper_stair{i+1}_tread',(-2.6,y,z+.015),(2.49,.35,.045),'ivory',.012)
        box(f'Upper_stair{i+1}_gold_nosing',(-2.6,y-.162,z+.031),(2.42,.035,.023),'gold',.007)
    for i in range(6):
        x=-6.8-i*.34;z=-i*.2
        box(f'Lower_stair{i+1}_core',(x,-2.95,z-.16),(.36,2.10,.32),'cream',.02)
        box(f'Lower_stair{i+1}_tread',(x,-2.95,z+.025),(.38,2.16,.08),'ivory',.018)
        box(f'Lower_stair{i+1}_nosing',(x-.18,-2.95,z+.065),(.028,2.08,.022),'gold',.006)
    box('Upper_landing',(-2.6,6.0,.56),(2.5,.85,.16),'ivory',.03)
    box('Lower_landing',(-8.75,-2.95,-1.08),(.75,2.3,.16),'ivory',.03)
    # 0.64 rise / 7.68 run; topology is explicit triangles, smooth planar slope.
    x0,x1,y0,y1=-5.8,-4.4,-1.68,6.0
    v=[(x,y,z) for z in (-.18,0) for y in (y0,y1) for x in (x0,x1)]
    v[6]=(x0,y1,.64);v[7]=(x1,y1,.64)
    mesh('Accessible_ramp_1_to_12',v,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],'ivory',.012)
    for x in (x0,x1):
        tube('Ramp_low_gold_curb',[(x,y0,.07),(x,y1,.71)],.045,'gold')
        box('Ramp_cheek_base',(x,(y0+y1)/2,-.12),(.15,y1-y0,.25),'cream',.025)
    for i in range(10):
        x=-3.96 if i<5 else -1.24;y=3.5+(i%5)*.53
        box('Upper_stair_cheek_block',(x,y,.23+(i%5)*.08),(.24,.55,.5),'ivory',.03)
    for side in (-1,1):
        for j in range(3):
            box('Lower_stair_cheek_coping',(-7.08-j*.65,-2.95+side*1.17,-.1-j*.39),(.69,.24,.22),'ivory',.035)
    for i in range(5):
        box('Landing_gold_division',(-3.56+i*.48,6,.648),(.018,.70,.015),'gold',.003)
    end(s)

def machinery():
    s=begin('06_Steam_Machinery')
    for i,(z,w,d) in enumerate([(-4.96,4.8,1.6),(-4.80,4.48,1.46),(-4.67,4.20,1.30)]):
        box(f'Engine_plinth_course{i+1}',(-2.8,-7.05,z),(w,d,.17),'ivory' if i!=1 else 'gold',.045)
    cylinder('Vertical_cylinder_jacket',(-3.85,-7.0,-3.76),.43,1.55,'pearl',n=64)
    for z in (-4.40,-3.82,-3.11):cylinder('Cylinder_bolted_band',(-3.85,-7,z),.48,.095,'gold',n=64)
    cylinder('Cylinder_crown',(-3.85,-7,-2.96),.38,.20,'ivory',n=64)
    for x in (-4.15,-3.55):rod('Crosshead_guide',(x,-7.06,-3.05),(x,-7.06,-2.02),.044,'bronze')
    rod('Piston_rod',(-3.85,-7.06,-3),(-3.85,-7.06,-2.04),.07,'gold',32)
    box('Sliding_crosshead',(-3.85,-7.06,-2.23),(.69,.24,.18),'pearl',.035)
    wheel=(-1.65,-7.36,-3.62)
    for y in (-7.28,-7.43):
        cylinder('Flywheel_spoked_rim',(-1.65,y,-3.62),1.00,.15,'gold',inner=.83,n=96,axis='Y')
    cylinder('Flywheel_hub',wheel,.22,.44,'bronze',n=64,axis='Y')
    for i in range(8):
        a=i*TAU/8
        rod('Flywheel_spoke',(-1.65+.18*math.cos(a),-7.34,-3.62+.18*math.sin(a)),
            (-1.65+.88*math.cos(a),-7.34,-3.62+.88*math.sin(a)),.059,'pearl',20)
    rod('Drive_shaft',(-1.65,-8.0,-3.62),(-1.65,-6.2,-3.62),.10,'bronze',48)
    for y in (-7.79,-6.40):
        cylinder('Bearing_round_housing',(-1.65,y,-3.62),.35,.19,'gold',inner=.115,n=64,axis='Y')
        box('Bearing_pedestal',(-1.65,y,-4.09),(.63,.35,.57),'pearl',.06)
        box('Bearing_foot',(-1.65,y,-4.44),(.92,.52,.13),'gold',.025)
    cylinder('Crank_pin',(-1.98,-7.64,-3.31),.11,.22,'gold',n=32,axis='Y')
    rod('Connecting_rod',(-3.85,-7.18,-2.23),(-1.98,-7.64,-3.31),.065,'gold',24)
    cylinder('Eccentric_disc',(-1.65,-7.68,-3.62),.31,.13,'pearl',n=64,axis='Y')
    cylinder('Vertical_boiler',(-4.76,-6.73,-3.47),.37,2.05,'copper',n=64)
    for z in (-4.4,-3.6,-2.54):cylinder('Boiler_reinforcement_band',(-4.76,-6.73,z),.40,.09,'gold',n=64)
    sphere('Boiler_domed_cap',(-4.76,-6.73,-2.39),(.74,.74,.42),'pearl',3)
    cylinder('Boiler_neck',(-4.76,-6.73,-2.07),.12,.40,'gold',n=32)
    paths=[
      [(-5.7,-6.77,-2.8),(-5.2,-6.77,-2.8),(-4.9,-6.9,-2.8),(-3.85,-7,-2.8)],
      [(-3.85,-6.7,-4),(-3.85,-6.2,-4),(-2.7,-6.15,-4),(-1.1,-6.15,-4.3)],
      [(-4.76,-6.73,-2),(-4.76,-6.7,-1.8),(-4.2,-6.1,-1.8),(-4.2,-6.1,-2.8)],
      [(-1.1,-6.1,-4.3),(-.5,-6.1,-4.3),(-.3,-6.0,-3.5),(-.3,-6,-2.5)]]
    for i,path in enumerate(paths):
        tube(f'Copper_service_pipe{i+1}',path,.073,'copper')
        for p in (path[0],path[-1]):cylinder('Pipe_flange',p,.145,.065,'gold',n=32,axis='X')
    for x in (-5.15,-4.22):
        cylinder('Valve_body',(x,-6.83,-2.80),.145,.24,'pearl',n=32,axis='X')
        handwheel_structure(cylinder('Valve_handwheel',(x,-7.09,-2.8),.25,.07,'gold',inner=.20,n=48,axis='Y'))
    for i,(x,z) in enumerate([(-4.76,-3.43),(-3.85,-3.62)]):
        cylinder('Gauge_case',(x,-7.22,z),.225,.12,'gold',n=64,axis='Y')
        cylinder('Gauge_enamel_dial',(x,-7.295,z),.185,.016,'teal',n=64,axis='Y',bev=.003)
        rod('Gauge_pointer',(x,-7.312,z),(x+.10,-7.312,z+.10),.011,'gold',12)
    cylinder('Condenser_body',(-.58,-6.60,-4.06),.28,1.10,'pearl',n=64,axis='Y')
    for y in (-7.17,-6.03):
        cylinder('Condenser_endcap',(-.58,y,-4.06),.31,.10,'gold',n=48,axis='Y')
    for x in (-.8,-.36):
        for y in (-6.98,-6.28):box('Condenser_support_foot',(x,y,-4.40),(.12,.17,.35),'bronze',.025)
    cylinder('Relief_stack',(-4.76,-6.73,-1.82),.067,.46,'copper',n=32)
    cylinder('Relief_crown',(-4.76,-6.73,-1.56),.14,.08,'gold',n=32)
    for i in range(30):
        # Real cylinder band / plinth / bearing fasteners, not hidden count fillers.
        if i<16:
            a=(i%8)*TAU/8;z=-3.11 if i<8 else -4.4
            loc=(-3.85+.47*math.cos(a),-7+.47*math.sin(a),z+.064)
            cylinder(f'Cylinder_flange_bolt{i+1}',loc,.040,.045,'bronze',n=6,bev=.007)
        else:
            j=i-16;x=-4.8+(j%7)*.65;y=-7.68 if j<7 else -6.42
            cylinder(f'Engine_base_fastener{j+1}',(x,y,-4.66),.046,.06,'gold',n=6,bev=.008)
    end(s)

def balcony():
    s=begin('07_Maintenance_Balcony')
    box('Balcony_structural_slab',(-2.8,-7.3,-5.10),(5.7,2.5,.24),'ivory',.13)
    box('Balcony_front_gold_coping',(-2.8,-8.59,-4.98),(5.85,.13,.15),'gold',.04)
    for x in (-5.67,.07):box('Balcony_side_gold_coping',(x,-7.35,-4.98),(.13,2.40,.15),'gold',.04)
    for i in range(6):
        grate(f'Walkable_grate_cassette{i+1}',(-4.68+(i%3)*1.88,-7.95+(i//3)*1.10,-4.964),1.75,.90,'bronze')
    for x in (-4.9,-.8):
        for k in range(3):
            tube('Swept_balcony_bracket',[(x,-8.35,-5.22-k*.07),(x,-7.9,-5.45-k*.08),
                 (x,-7.05,-6.26-k*.08),(x,-6.25,-7.0-k*.08)],.09 if k==0 else .043,'pearl' if k==0 else 'gold')
    for x in (-4.9,-.8):
        for z in (-5.18,-7.12):box('Bracket_anchor_plate',(x,-6.25,z),(.48,.22,.5),'gold',.045)
    for i in range(4):
        x=-5.08+i*1.52
        tube('Balcony_fan_brace',[(x-.32,-8.65,-5.15),(x,-8.65,-5.68),(x+.32,-8.65,-5.15)],.037,'gold')
    for a,b in [((-5.66,-8.57,-4.1),(.06,-8.57,-4.1)),((-5.66,-8.57,-4.1),(-5.66,-6.15,-4.1)),
                ((.06,-8.57,-4.1),(.06,-6.15,-4.1))]:rod('Balcony_handrail',a,b,.047,'gold')
    for i in range(7):
        x=-5.55+i*.92
        rod(f'Balcony_post{i+1}',(x,-8.57,-4.96),(x,-8.57,-4.10),.034,'gold')
    for i in range(16):
        x=-5.5+(i//2)*.68
        rod(f'Balcony_lattice_bar{i+1}',(x,-8.58,-4.86),(x+.53,-8.58,-4.20 if i%2 else -4.65),.022,'bronze',12)
    end(s)

def basin():
    s=begin('08_Basin')
    cx,cy=2.8,4.2
    box('Basin_molded_foundation',(cx,cy,.10),(4.50,2.42,.24),'cream',.16)
    box('Basin_pearl_liner',(cx,cy,.25),(4.16,2.10,.14),'teal',.10)
    box('Basin_aquamarine_water',(cx,cy,.35),(3.97,1.92,.035),'water',.10)
    for x in (cx-2.12,cx+2.12):box('Basin_short_wall',(x,cy,.41),(.22,2.18,.42),'ivory',.055)
    for y in (cy-1.04,cy+1.04):box('Basin_long_wall',(cx,y,.41),(4.14,.22,.42),'ivory',.055)
    for x in (cx-2.1,cx+2.1):
        for y in (cy-1.02,cy+1.02):box('Basin_corner_pier',(x,y,.44),(.31,.31,.53),'ivory',.07)
    for j in range(4):
        x=cx-1.59+j*1.06
        for y in (cy-1.04,cy+1.04):
            box('Basin_coping_segment',(x,y,.67),(1.04,.35,.16),'ivory',.045)
            box('Basin_gold_inlay',(x,y-.17 if y<cy else y+.17,.68),(1.01,.028,.05),'gold',.008)
    for j in range(4):
        box('Basin_recessed_front_panel',(cx-1.59+j*1.06,cy-1.16,.43),(.76,.035,.19),'gold',.035)
    cylinder('Basin_dain_bezel',(cx,cy,.351),.14,.025,'gold',inner=.105,n=48,bev=.004)
    for i in range(4):box('Basin_drain_grille',(cx-.072+i*.048,cy,.363),(.012,.17,.016),'bronze',.003)
    tube('Basin_copper_inlet',[(cx+2.42,cy+.42,0),(cx+2.42,cy+.42,.83),(cx+1.83,cy+.42,.83),(cx+1.83,cy+.42,.60)],.05,'copper')
    tube('Basin_service_outlet',[(cx+2.15,cy-.50,.27),(cx+2.51,cy-.50,.27),(cx+2.51,cy-.50,-.2)],.05,'copper')
    cylinder('Basin_regulator',(cx+2.41,cy+.42,.91),.105,.06,'gold',n=24)
    cylinder('Basin_regulator_bezel',(cx+2.41,cy+.42,.85),.15,.06,'pearl',n=32)
    end(s)

def plantmesh(label,loc,flower=False):
    # A compound reusable plant component; leaves/petals remain editable mesh islands.
    verts=[];faces=[]
    def ellipsoid(c,sz,rz=0):
        bm=bmesh.new();bmesh.ops.create_uvsphere(bm,u_segments=8,v_segments=5,radius=1)
        off=len(verts);bm.verts.ensure_lookup_table()
        for vv in bm.verts:
            x,y,z=vv.co.x*sz[0],vv.co.y*sz[1],vv.co.z*sz[2]
            verts.append((c[0]+x*math.cos(rz)-y*math.sin(rz),c[1]+x*math.sin(rz)+y*math.cos(rz),c[2]+z))
        faces.extend([tuple(off+v.index for v in f.verts) for f in bm.faces]);bm.free()
    if flower:
        for i in range(5):
            a=i*2.4;cx=.20*math.cos(a);cy=.20*math.sin(a);z=.25+(i%3)*.10
            for j in range(5):
                aa=j*TAU/5
                ellipsoid((cx+.07*math.cos(aa),cy+.07*math.sin(aa),z),(.066,.035,.024),aa)
            ellipsoid((cx,cy,z+.012),(.026,.026,.023))
    else:
        for i in range(14):
            a=i*2.399;d=.15+.045*(i%3);z=.10+.043*i
            ellipsoid((d*math.cos(a),d*math.sin(a),z),(.27,.07,.025),a)
    obj=mesh(label,verts,faces,'flower' if flower else RNG.choice(['sage','leaf_dark']))
    obj.location=loc
    return obj

def gardens():
    s=begin('09_Gardens')
    beds=[(math.radians(111),math.radians(184)),(math.radians(18),math.radians(83))]
    positions=[]
    for k,(a0,a1) in enumerate(beds):
        sector(f'Planter{k+1}_foot',6.19,7.48,a0,a1,.01,.20,'cream',bev=.045)
        sector(f'Planter{k+1}_soil_tray',6.37,7.29,a0+.025,a1-.025,.20,.49,'soil',bev=.025)
        for j in range(5):
            b0=a0+(a1-a0)*j/5+.004;b1=a0+(a1-a0)*(j+1)/5-.004
            for ri,ro in ((6.20,6.38),(7.30,7.47)):
                sector(f'Planter{k+1}_wall{j+1}',ri,ro,b0,b1,.18,.61,'ivory',bev=.025)
            sector(f'Planter{k+1}_coping{j+1}',6.13,6.43,b0,b1,.59,.70,'ivory',bev=.045)
        for aa in (a0,a1):
            sector(f'Planter{k+1}_end_closure',6.20,7.47,aa-.015,aa+.015,.19,.69,'ivory',bev=.025)
        sector(f'Planter{k+1}_gold_reveal',6.16,6.205,a0,a1,.40,.45,'gold',bev=.008)
        for j in range(10):
            a=a0+(a1-a0)*(j+.5)/10;r=6.71+.19*math.sin(j*2.1)
            positions.append((r*math.cos(a),r*math.sin(a),.50))
    for i,p in enumerate(positions):plantmesh(f'Sage_cluster_{i+1:02d}',p)
    for i,p in enumerate(positions):plantmesh(f'Ivory_blossom_cluster_{i+1:02d}',(p[0]+.16,p[1]-.15,p[2]+.12),True)
    end(s)

def manifest():
    records=[]
    for o in PARTS:
        records.append({'id':o['part_id'],'name':o.name,'family':o['family'],
          'design_part':o['design_part'],'vertices':len(o.data.vertices),'triangles':len(o.data.polygons),
          'material':o.data.materials[0].name,'dimensions_m':list(o.dimensions),
          'location_blender_z_up':list(o.location),'mesh_datablock':o.data.name,
          'independent_mesh_users':o.data.users,'smooth_faces':sum(p.use_smooth for p in o.data.polygons)})
    result={'name':'MineSpark Celestial Terrace','scope':'Isolated static asset, not a fitted live map',
      'reference':'docs/concepts/mind_spark_terrain_heavenly_v3.png',
      'part_count':len(records),'allocation':ALLOC,'triangles':sum(r['triangles'] for r in records),
      'vertices':sum(r['vertices'] for r in records),'parts':records,
      'limitations':['Not a pixel-exact reconstruction','No rig or working steam simulation','No live-map placement or collision integration',
                      'No game/Web performance certification','Shader-independent GLB has simpler material response than Cycles render']}
    (OUT/'parts_manifest.json').write_text(json.dumps(result,indent=2))
    with (OUT/'parts_catalogue.csv').open('w') as f:
        writer=csv.DictWriter(f,fieldnames=list(records[0]));writer.writeheader();writer.writerows(records)
    return result

def export():
    bpy.ops.object.select_all(action='DESELECT')
    for o in PARTS:o.select_set(True)
    bpy.context.view_layer.objects.active=PARTS[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT/'celestial_terrace_1000.glb'),
        export_format='GLB',use_selection=True,export_apply=False,export_extras=True,
        export_yup=True,export_cameras=False,export_lights=False)
    for o in PARTS:o.select_set(False)

def camera(name,loc,target,scale):
    data=bpy.data.cameras.new(name);obj=bpy.data.objects.new(name,data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location=loc;obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
    data.type='ORTHO';data.ortho_scale=scale;bpy.context.scene.camera=obj
    return obj

def studio():
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=24 if QUICK else 64
    scene.cycles.use_denoising=True
    scene.render.resolution_x=1400 if QUICK else 2200
    scene.render.resolution_y=1400 if QUICK else 2200
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.render.film_transparent=False
    scene.world=bpy.data.worlds.new('Celestial_soft_sky')
    scene.world.use_nodes=True
    bg=scene.world.node_tree.nodes.get('Background')
    bg.inputs['Color'].default_value=(.68,.77,.83,1);bg.inputs['Strength'].default_value=.38
    scene.view_settings.view_transform='AgX'
    scene.view_settings.exposure=.35
    # Bright camera-only procedural sky; it never hides missing model geometry.
    nt=scene.world.node_tree;nodes=nt.nodes
    lightpath=nodes.new('ShaderNodeLightPath')
    backdrop=nodes.new('ShaderNodeBackground');backdrop.inputs['Strength'].default_value=.9
    tex=nodes.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=2.8
    tex.inputs['Detail'].default_value=3
    coord=nodes.new('ShaderNodeTexCoord');nt.links.new(coord.outputs['Normal'],tex.inputs['Vector'])
    ramp=nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position=.40;ramp.color_ramp.elements[0].color=(.58,.72,.84,1)
    ramp.color_ramp.elements[1].position=.63;ramp.color_ramp.elements[1].color=(.94,.91,.82,1)
    nt.links.new(tex.outputs['Fac'],ramp.inputs[0]);nt.links.new(ramp.outputs[0],backdrop.inputs['Color'])
    mix=nodes.new('ShaderNodeMixShader')
    nt.links.new(lightpath.outputs['Is Camera Ray'],mix.inputs[0]);nt.links.new(bg.outputs[0],mix.inputs[1])
    nt.links.new(backdrop.outputs[0],mix.inputs[2]);nt.links.new(mix.outputs[0],nodes.get('World Output').inputs[0])
    sun=bpy.data.lights.new('Warm_sunrise','SUN');sun.energy=1.25;sun.angle=.18;sun.color=(1,.91,.78)
    sunob=bpy.data.objects.new('Warm_sunrise',sun);scene.collection.objects.link(sunob)
    sunob.rotation_euler=(.45,-.4,-.65)
    for name,loc,power,size,col in [
      ('Sunrise_key',(-12,-15,22),3200,12,(1,.89,.73)),
      ('Pearl_fill',(14,-7,12),2200,12,(.79,.88,1)),
      ('Heavenly_rim',(-3,15,18),3600,10,(1,.94,.82))]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=col
        obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj);obj.location=loc
        obj.rotation_euler=(Vector((0,0,-2))-obj.location).to_track_quat('-Z','Y').to_euler()
    camera('CAM_Hero',(20,-34,18),(0,0,-3.3),26)
    # Preview is real geometry under clear studio lighting, without mist hiding errors.
    scene['reference_image']=str(ROOT/'docs/concepts/mind_spark_terrain_heavenly_v3.png')
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_distance=27
                area.spaces.active.region_3d.view_location=(0,0,-3)
                area.spaces.active.shading.type='MATERIAL'

def render_views():
    scene=bpy.context.scene
    if hasattr(scene.cycles,'use_auto_tile'):scene.cycles.use_auto_tile=False
    if QUICK:
        scene.cycles.samples=24
        scene.render.resolution_x=1400;scene.render.resolution_y=1400
    views=[
      ('01_hero',(20,-34,18),(0,0,-3.3),26),
      ('02_arch_detail',(8,-19,4),(2.5,-6.2,-2.4),10.7),
      ('03_engine_detail',(3,-17,1),(-2.7,-7,-3.6),7.4),
      ('04_civic_floor',(13,-18,21),(0,.6,.1),18.8),
      ('05_rear_view',(-23,30,21),(0,0,-3.3),26)]
    for name,loc,target,scale in views:
        if '--skip-hero' in sys.argv and name=='01_hero':continue
        obj=scene.camera;obj.location=loc
        obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
        obj.data.ortho_scale=scale
        scene.render.filepath=str(OUT/'previews'/f'{name}.png')
        bpy.ops.render.render(write_still=True)
        print('[RENDER]',name,flush=True)
    # A real exploded assembly view, with category separation, not generative art.
    offsets={name:Vector(((i%3-1)*13,(i//3-1)*11,i*.65)) for i,name in enumerate(ALLOC)}
    for o in PARTS:o.location+=offsets[o['family']]
    obj=scene.camera;obj.location=(38,-54,46)
    obj.rotation_euler=(Vector((0,0,-1))-obj.location).to_track_quat('-Z','Y').to_euler()
    obj.data.ortho_scale=51
    scene.render.filepath=str(OUT/'previews/06_family_exploded.png')
    bpy.ops.render.render(write_still=True)
    for o in PARTS:o.location-=offsets[o['family']]
    # Restore hero camera for the file opened by the user.
    obj.location=(20,-34,18);obj.rotation_euler=(Vector((0,0,-3.3))-obj.location).to_track_quat('-Z','Y').to_euler()
    obj.data.ortho_scale=26

def main():
    if '--render-only' in sys.argv:
        bpy.ops.wm.open_mainfile(filepath=str(OUT/'source/celestial_terrace_1000.blend'))
        PARTS.extend(sorted([o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith('CT_')],key=lambda o:o['part_id']))
        assert len(PARTS)==1000
        render_views()
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version=0
    for d in (OUT,OUT/'previews',OUT/'source'):d.mkdir(parents=True,exist_ok=True)
    (OUT/'source/.gdignore').touch();(OUT/'previews/.gdignore').touch()
    materials()
    for fn in (rock,deck,facade,railings,access,machinery,balcony,basin,gardens):fn()
    assert len(PARTS)==1000
    bpy.context.view_layer.update()
    report=manifest();export();studio()
    # Keep the exact approved image inside the blend as a reference datablock.
    ref=bpy.data.images.load(str(ROOT/'docs/concepts/mind_spark_terrain_heavenly_v3.png'))
    ref.name='REFERENCE_Approved_Celestial_Concept';ref.pack()
    notes=bpy.data.texts.new('START_HERE')
    notes.write('Celestial Terrace — 1000 independent editable triangle meshes.\n'
                'Nine named collections. Select a CT_ object and press Tab to edit vertices, edges and faces.\n'
                'UVs are preliminary box-projection UVs, not a final packed texture atlas.\n'
                'REFERENCE_Approved_Celestial_Concept is packed in this file for comparison.\n'
                'This is an isolated high-detail art asset. It has NOT replaced the live world.\n')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/celestial_terrace_1000.blend'))
    if '--no-render' not in sys.argv:render_views()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/celestial_terrace_1000.blend'))
    print('[CELESTIAL COMPLETE]',report['part_count'],'parts',report['triangles'],'triangles',flush=True)

if __name__=='__main__':main()
