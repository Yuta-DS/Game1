"""Deterministic Blender-only terrain asset production, not a live map replacement.

blender --background --python-exit-code 1 --python tools/blender/build_mind_spark_terrain_triangles.py
Use -- --no-render to regenerate meshes/exports only.
"""
from __future__ import annotations

import contextlib
import hashlib
import io
import json
import math
import random
import sys
from collections import Counter
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_mind_spark_luxury_steam_kit import create_materials, make_material

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets3D/mind_spark/terrain_triangle_kit'
PARTS, ASSEMBLIES, PREVIEWS, SOURCE = [OUT / p for p in ('parts', 'assemblies', 'previews', 'source')]
REGISTRY = {}
RECORDS = []
SPECS = {}
MATS = {}
RNG = random.Random(17031)


def triangulate(obj, bevel=0):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if bevel:
        mod = obj.modifiers.new('Machined_edge_bevel', 'BEVEL')
        mod.width, mod.segments = bevel, 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bmesh.ops.triangulate(bm, faces=list(bm.faces), quad_method='BEAUTY', ngon_method='BEAUTY')
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    for face in obj.data.polygons:
        face.use_smooth = False
    obj.select_set(False)
    return obj


def mesh(name, verts, faces, mat='ivory', bevel=0):
    data = bpy.data.meshes.new(name + '_triangles')
    data.from_pydata(verts, [], faces)
    data.materials.append(MATS[mat])
    obj = bpy.data.objects.new('VIS_' + name, data)
    bpy.context.scene.collection.objects.link(obj)
    return triangulate(obj, bevel)


def box(name, size, mat='ivory', bevel=.025, centre=None):
    x, y, z = size
    cx, cy, cz = centre if centre else (0, 0, z / 2)
    v = [(cx+sx*x/2, cy+sy*y/2, cz+sz*z/2) for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]
    return mesh(name, v, [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)], mat, bevel)


def prism(name, xy, bottom, top, mat='ivory', bevel=0):
    n = len(xy)
    v = [(x,y,bottom) for x,y in xy] + [(x,y,top) for x,y in xy]
    faces = [tuple(reversed(range(n))), tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,v,faces,mat,bevel)


def wedge(name, width, run, rise, thickness=.15, curb=0, mat='ivory'):
    return mesh(name, [(0,0,-thickness),(width,0,-thickness),(0,run,-thickness),(width,run,-thickness),
                       (0,0,curb),(width,0,curb),(0,run,rise+curb),(width,run,rise+curb)],
                [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],mat)


def cylinder(name,radius,height,mat='brass',vertices=12,inner=0):
    if not inner:
        return prism(name,[(radius*math.cos(i*math.tau/vertices),radius*math.sin(i*math.tau/vertices)) for i in range(vertices)],0,height,mat,.004 if height>.015 else 0)
    verts=[]
    for z in (0,height):
        for r in (radius,inner):
            verts += [(r*math.cos(i*math.tau/vertices),r*math.sin(i*math.tau/vertices),z) for i in range(vertices)]
    faces=[]; n=vertices
    for i in range(n):
        j=(i+1)%n
        faces += [(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),
                  (i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)]
    return mesh(name,verts,faces,mat)


def sector(name,inner,outer,bottom,top,mat='ivory',segments=12):
    angle=math.pi/6
    xy=[(outer*math.cos(i*angle/segments),outer*math.sin(i*angle/segments)) for i in range(segments+1)]
    if inner:
        xy += [(inner*math.cos(i*angle/segments),inner*math.sin(i*angle/segments)) for i in range(segments,-1,-1)]
    else:
        xy.append((0,0))
    return prism(name,xy,bottom,top,mat)


def rock_sector(name,levels,seed):
    """30-degree slice. Exact shared boundaries; jitter is confined to its interior."""
    rng=random.Random(seed); n=16; verts=[]
    for k,(radius,z) in enumerate(levels):
        for i in range(n+1):
            a=(math.pi/6)*i/n
            pinned=i in (0,n) or k in (0,len(levels)-1)
            r=radius+(0 if pinned else rng.uniform(-.20,.20))
            zz=z+(0 if pinned else rng.uniform(-.14,.14))
            verts.append((r*math.cos(a),r*math.sin(a),zz))
    faces=[]
    for k in range(len(levels)-1):
        for i in range(n):
            a=k*(n+1)+i; b=a+n+1
            faces += [(a,a+1,b+1),(a,b+1,b)] if (i+k)%2 else [(a,a+1,b),(a+1,b+1,b)]
    lo=len(verts); verts.append((0,0,levels[0][1]))
    hi=len(verts); verts.append((0,0,levels[-1][1]))
    last=(len(levels)-1)*(n+1)
    for i in range(n):
        faces += [(lo,i+1,i),(hi,last+i,last+i+1)]
    faces += [tuple([lo]+[k*(n+1) for k in range(len(levels))]+[hi]),
              tuple([lo,hi]+[k*(n+1)+n for k in reversed(range(len(levels)))])]
    obj=mesh(name,verts,faces,'rock_mid')
    for key in ('rock_light','rock_dark','rock_warm'):
        obj.data.materials.append(MATS[key])
    for face in obj.data.polygons:
        # Large planes read as stone strata, small triangles as fractured edges.
        face.material_index=0 if abs(face.normal.z)>.99 else rng.choices(range(4),[6,2,2,1])[0]
    return obj


def boulder(name,size,seed,subdivisions=2):
    rng=random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions,radius=1)
    obj=bpy.context.object; obj.name='VIS_'+name
    for vertex in obj.data.vertices:
        noise=rng.uniform(.82,1.16)
        vertex.co=Vector((vertex.co.x*size[0]/2,vertex.co.y*size[1]/2,vertex.co.z*size[2]/2))*noise
    bottom=min(v.co.z for v in obj.data.vertices)
    for vertex in obj.data.vertices: vertex.co.z-=bottom
    for key in ('rock_mid','rock_light','rock_dark','rock_warm'): obj.data.materials.append(MATS[key])
    triangulate(obj)
    for face in obj.data.polygons: face.material_index=rng.choices(range(4),[7,2,2,1])[0]
    return obj


def soil_panel():
    rng=random.Random(183); n=14; size=1.78; verts=[]
    for j in range(n+1):
        for i in range(n+1):
            edge=i in (0,n) or j in (0,n)
            verts.append((-size/2+i*size/n+(0 if edge else rng.uniform(-.025,.025)),
                          -size/2+j*size/n+(0 if edge else rng.uniform(-.025,.025)),
                          .18+(0 if edge else rng.uniform(-.025,.025))))
    faces=[]
    for j in range(n):
        for i in range(n):
            a=j*(n+1)+i
            faces += [(a,a+1,a+n+2),(a,a+n+2,a+n+1)]
    perimeter=list(range(n+1))+[j*(n+1)+n for j in range(1,n+1)]+[n*(n+1)+i for i in range(n-1,-1,-1)]+[j*(n+1) for j in range(n-1,0,-1)]
    base=len(verts)
    verts.extend([(verts[i][0],verts[i][1],0) for i in perimeter])
    for i,a in enumerate(perimeter):
        j=(i+1)%len(perimeter)
        faces.append((a,base+i,base+j,perimeter[j]))
    faces.append(tuple(reversed(range(base,len(verts)))))
    obj=mesh('soil_insert',verts,faces,'soil')
    obj.data.materials.append(MATS['soil_light'])
    for face in obj.data.polygons: face.material_index=int(rng.random()<.2)
    return obj


def collection(name):
    c=bpy.data.collections.new(name); bpy.context.scene.collection.children.link(c)
    if name.startswith(('PART_', 'ASSEMBLY_')):
        c.asset_mark()
    return c


def move(obj,coll):
    for c in list(obj.users_collection): c.objects.unlink(obj)
    coll.objects.link(obj)


def socket(root,label,loc,direction=(0,0,1)):
    obj=bpy.data.objects.new('SOCKET_'+label,None)
    root.users_collection[0].objects.link(obj)
    obj.parent=root; obj.location=loc
    obj.empty_display_type='ARROWS'; obj.empty_display_size=.16
    obj['forward']=list(direction)
    obj.rotation_euler=Vector(direction).to_track_quat('Z','Y').to_euler()
    return obj


def register(cid,family,obj,description,datum='ground',snap=.1):
    coll=collection('PART_'+cid)
    root=bpy.data.objects.new('MST_'+cid,None); coll.objects.link(root)
    move(obj,coll); obj.parent=root
    root['part_id']=cid; root['family']=family; root['description']=description
    root['datum']=datum; root['snap_m']=snap
    root.asset_mark(); root.asset_data.description=description
    socket(root,'ORIGIN',(0,0,0))
    REGISTRY[cid]=root
    SPECS[cid]={'id':cid,'kind':'part','family':family,'description':description,'datum':datum,'snap_m':snap}
    return root


def descendants(root):
    return [root]+list(root.children_recursive)


def create_parts():
    def add(cid,family,obj,desc,datum='ground',snap=.1):
        return register(cid,family,obj,desc,datum,snap)
    add('rock_cap_sector','rock',rock_sector('cap_sector',[(8,-.7),(8.15,-.40),(8,0)],10),'30° pinned-edge rock cap; top datum Z=0','deck',0)
    add('rock_shoulder_sector','rock',rock_sector('shoulder_sector',[(6,-3.2),(7.5,-2.7),(8.0,-1.8),(8,-.7)],11),'30° fractured shoulder band matching cap and keel','deck',0)
    add('rock_keel_sector','rock',rock_sector('keel_sector',[(.8,-7),(1.7,-6.1),(3,-5.4),(4.6,-4.3),(6,-3.2)],12),'30° tapered underside, five triangulated strata','deck',0)
    add('rock_fracture_plate','rock',boulder('fracture_plate',(1.8,.30,1.1),14),'Thin fracture plate; raised cliff detail')
    add('rock_tip_shard','rock',boulder('tip_shard',(1.8,1.8,2.6),15),'Faceted terminal shard',snap=.1)
    add('rock_boulder_large','rock',boulder('boulder_large',(1.5,1.2,.8),16),'Large irregular twenty-face-derived boulder')
    add('rock_boulder_small','rock',boulder('boulder_small',(.65,.55,.4),17),'Small edge boulder')
    add('rock_scree_chip','rock',boulder('scree_chip',(.17,.13,.09),18,1),'Small reusable triangular rubble chip')
    add('deck_structural_half','deck',prism('deck_structural_half',[(0,0),(2,0),(0,2)],-.38,-.10,'cream'),'2 m right-triangle structural half; pair forms square','deck',2)
    add('deck_paving_half','deck',prism('deck_paving_half',[(.01,.01),(1.97,.01),(.01,1.97)],-.10,0,'ivory',.008),'Inlaid triangular paving half; flat top','deck',2)
    add('deck_border_half','deck',prism('deck_border_half',[(.01,.01),(1.97,.01),(.01,1.97)],-.10,0,'cream',.008),'Warm triangular alternate paving half','deck',2)
    add('deck_edge_fascia','deck',box('fascia',(2,.12,.38),'ivory',.025,centre=(1,0,-.19)),'2 m replaceable deck edge face','deck',2)
    add('deck_inlay_strip','deck',box('inlay',(1.92,.022,.012),'brass',.003,centre=(.96,0,-.006)),'Flush 1.92 m champagne-brass strip','deck',.02)
    add('deck_joint_strip','deck',box('joint',(2,.018,.025),'gunmetal',0,centre=(1,0,-.015)),'Recessed expansion-joint strip','deck',2)
    add('rim_wall_sector','rim',sector('rim_wall',7.7,8,-.7,.16,'ivory'),'R8 m, 30° retaining segment; common island-centre origin','deck',0)
    add('rim_coping_sector','rim',sector('coping',7.65,8.07,.16,.30,'cream'),'Overhanging beveled-profile coping sector','deck',0)
    add('rim_brass_sector','rim',sector('rim_brass',8.005,8.035,-.27,-.20,'brass'),'External curved brass belt','deck',0)
    add('rim_buttress','rim',wedge('buttress',.32,.70,.85,mat='cream'),'Triangular retaining support; rotate/position per rim')
    add('rim_drain_spout','rim',box('drain_spout',(.16,.45,.10),'copper',.018),'Rose-copper scupper body; pair with a grille')
    add('rim_seam_cover','rim',box('seam_cover',(.06,.025,.74),'brass',.004),'Narrow vertical cover for sector seam')
    add('landing_footing','landing',box('footing',(.8,.8,.65),'cream',.065),'Corner spread footing with cut arrises')
    add('landing_bearing','landing',box('bearing',(.65,.65,.10),'gunmetal',.025),'Isolated dark bearing pad')
    add('landing_crossbeam','landing',box('crossbeam',(4,.35,.45),'cream',.04),'4 m bearing beam')
    add('landing_gusset','landing',prism('gusset',[(0,0),(1,0),(0,.75)],0,.09,'brass',.008),'True triangular 1×.75 m gusset plate')
    add('landing_pin_collar','landing',cylinder('pin_collar',.10,.10,inner=.052),'Annular bridge pin collar')
    ramp=add('access_ramp_wedge','access',wedge('ramp',2,3.6,.3),'2 m width, 3.6 m run, .3 m rise; smooth 1:12 geometry','low_entry',.3)
    socket(ramp,'ENTRY',(1,0,0),(0,-1,0)); socket(ramp,'EXIT',(1,3.6,.3),(0,1,0))
    add('access_slope_curb','access',wedge('curb',.09,3.6,.3,curb=.12,mat='cream'),'Sloped edge curb, not a railing','low_entry',.3)
    add('access_landing_slab','access',box('landing_slab',(2,1.5,.25),'ivory',.015,centre=(1,.75,-.125)),'Flat landing slab; top at local zero','top_surface',.5)
    add('access_step_block','access',box('step',(2,.3,.15),'ivory',.005,centre=(1,.15,.075)),'One step: .15 m rise × .3 m tread × 2 m width','bottom_front',.15)
    add('access_nosing','access',box('nosing',(1.94,.035,.01),'brass',.003),'Flush brass tread-edge strip')
    add('access_side_stringer','access',wedge('stringer',.09,.6,.3,mat='cream'),'Triangular two-step side foundation','bottom_front',.15)
    add('access_tactile_stud','access',cylinder('tactile_stud',.012,.003,'brass',8),'3 mm-high guidance stud; decorative, not a code claim')
    add('ledge_shelf_slab','ledge',box('shelf',(4,1.5,.22),'ivory',.035,centre=(0,.75,-.11)),'4×1.5 m ledge deck; wall-line origin','top_surface',.5)
    add('ledge_diagonal_brace','ledge',box('brace',(.12,.12,1.75),'gunmetal',.014),'Reusable diagonal compression strut')
    add('ledge_grate_frame','ledge',box('frame',(1,.07,.08),'gunmetal',.008),'1 m frame member')
    add('ledge_grate_bar','ledge',box('bar',(.84,.022,.035),'brass',.004),'Inset grate bar; rotate for diamond lattice')
    add('soil_wall','soil',box('bed_wall',(2,.16,.55),'terracotta',.04),'2 m terracotta raised-bed wall')
    add('soil_corner_post','soil',box('corner',(.22,.22,.60),'cream',.035),'Raised-bed corner / joint pier')
    add('soil_insert','soil',soil_panel(),'1.78 m square triangulated soil insert; separate from shell')
    add('soil_drainage_insert','soil',box('drainage',(1.78,1.78,.10),'rock_dark',.01),'Hidden gravel support layer; reusable cell')
    add('soil_separator_sheet','soil',box('separator',(1.78,1.78,.006),'gunmetal',0),'Thin separator membrane, deliberately separate')
    add('basin_liner','basin',box('liner',(4,4,.16),'teal',.035),'Watertight-looking flat liner; no liquid included')
    add('basin_wall','basin',box('basin_wall',(2,.20,.55),'ivory',.025),'2 m liner side-wall segment')
    add('basin_corner','basin',box('basin_corner',(.25,.25,.58),'cream',.025),'Corner closure block')
    add('basin_coping','basin',box('basin_coping',(1,.30,.10),'cream',.022),'1 m coping stone')
    add('basin_drain_disc','basin',cylinder('drain_disc',.16,.025,'brass',24,inner=.12),'Annular drain bezel')
    add('basin_grille','basin',box('grille',(.24,.014,.015),'gunmetal',.002),'Individual drain-grid bar')
    add('hardware_anchor_plate','hardware',box('anchor_plate',(.3,.3,.045),'brass',.018),'Shared mount plate; bolts are independent meshes')
    add('hardware_hex_bolt','hardware',cylinder('hex_bolt',.037,.042,'brass',6),'Six-sided bolt head, triangulated bevels')
    add('hardware_washer','hardware',cylinder('washer',.052,.008,'gunmetal',12,inner=.024),'Open-centre washer')
    # True mechanical connection sockets are part of the assets, not inferred later.
    for cid in ('rock_cap_sector','rock_shoulder_sector','rock_keel_sector','rim_wall_sector','rim_coping_sector','rim_brass_sector'):
        root=REGISTRY[cid]
        socket(root,'SECTOR_START',(8,0,0),(0,-1,0))
        socket(root,'SECTOR_END',(8*math.cos(math.pi/6),4,0),(-.5,math.sqrt(3)/2,0))
    for cid in ('deck_structural_half','deck_paving_half','deck_border_half'):
        root=REGISTRY[cid]
        socket(root,'GRID_X',(2,0,0),(1,0,0)); socket(root,'GRID_Y',(0,2,0),(0,1,0))
    assert len(REGISTRY)==50, len(REGISTRY)


def assembly(cid,title):
    coll=collection('ASSEMBLY_'+cid)
    root=bpy.data.objects.new('MST_'+cid,None); coll.objects.link(root)
    root['assembly_id']=cid; root['description']=title
    root.asset_mark(); root.asset_data.description=title
    SPECS[cid]={'id':cid,'kind':'assembly','family':cid.split('_',1)[1],'description':title,'datum':'assembly_origin','snap_m':.1}
    socket(root,'ORIGIN',(0,0,0))
    return root


def instance(root,cid,loc=(0,0,0),rot=(0,0,0),layer='core',scale=(1,1,1)):
    original=next(o for o in REGISTRY[cid].children if o.type=='MESH')
    obj=original.copy(); obj.data=original.data
    root.users_collection[0].objects.link(obj); obj.parent=root
    obj.name='VIS_'+cid; obj.location=loc; obj.rotation_euler=rot; obj.scale=scale
    obj['part_id']=cid; obj['assembly_layer']=layer
    return obj


def fastener(root,loc,rot=(0,0,0),layer='fasteners'):
    a=instance(root,'hardware_washer',loc,rot,layer)
    axis=a.rotation_euler.to_matrix()@Vector((0,0,.008))
    instance(root,'hardware_hex_bolt',Vector(loc)+axis,rot,layer)


def collision(root,obj,label):
    obj.name='COL_'+label+'-colonly'; obj.parent=root
    move(obj,root.users_collection[0]); obj['collision_proxy']=True
    obj.hide_render=True; obj.display_type='WIRE'
    return obj


def tiles(root,cells=4,start=(-4,-4),z=0):
    for y in range(cells):
        for x in range(cells):
            px=start[0]+x*2; py=start[1]+y*2
            for half in (0,1):
                pos=(px+half*2,py+half*2,z); rot=(0,0,half*math.pi)
                instance(root,'deck_structural_half',pos,rot,'structure')
                cid='deck_border_half' if (x+y+half)%4==0 else 'deck_paving_half'
                instance(root,cid,pos,rot,'paving')
            instance(root,'deck_inlay_strip',(px+.04,py+.04,z),layer='inlay')
            instance(root,'deck_inlay_strip',(px+.04,py+.04,z),(0,0,math.pi/2),'inlay')
            # Diagonal strip uses one existing stock length, scaled only in its length.
            instance(root,'deck_inlay_strip',(px+.03,py+1.97,z),(0,0,-math.pi/4),'inlay',(math.sqrt(2),1,1))


def build_assemblies():
    results=[]
    a=assembly('01_rock_base','P0 · Floating-island rock base · 16 m reference specimen')
    for i in range(12):
        angle=i*math.pi/6
        for cid in ('rock_cap_sector','rock_shoulder_sector','rock_keel_sector'):
            instance(a,cid,rot=(0,0,angle),layer=cid)
        for k in range(3):
            t=angle+(k+1)*math.pi/24
            instance(a,'rock_fracture_plate',(7.45*math.cos(t),7.45*math.sin(t),-2.2-k*.12),(0,.15,t+math.pi/2),'fractures')
        instance(a,'rock_boulder_small',(7.1*math.cos(angle),7.1*math.sin(angle),-.05),(0,0,angle),'surface_rocks')
    instance(a,'rock_tip_shard',(0,0,-9.0),layer='tip')
    socket(a,'DECK',(0,0,0)); results.append(a)
    a=assembly('02_civic_deck','P0 · Ivory civic deck · paired triangular tiles on 2 m grid')
    tiles(a)
    for i in range(4):
        v=-4+i*2
        instance(a,'deck_edge_fascia',(v,-4,0),layer='edge')
        instance(a,'deck_edge_fascia',(v,4,0),layer='edge')
        instance(a,'deck_edge_fascia',(-4,v,0),(0,0,math.pi/2),'edge')
        instance(a,'deck_edge_fascia',(4,v,0),(0,0,math.pi/2),'edge')
    collision(a,box('deck_proxy',(8,8,.38),'cream',0,centre=(0,0,-.19)),'deck')
    socket(a,'EDGE_X',(4,0,0),(1,0,0)); socket(a,'EDGE_Y',(0,4,0),(0,1,0)); results.append(a)
    a=assembly('03_retaining_band','P0 · 90° retaining-band assembly · R8 m')
    for i in range(3):
        angle=i*math.pi/6
        for cid in ('rim_wall_sector','rim_coping_sector','rim_brass_sector'):
            instance(a,cid,rot=(0,0,angle),layer=cid)
        for j in range(3):
            t=angle+(j+.5)*math.pi/18
            instance(a,'rim_buttress',(8.1*math.cos(t),8.1*math.sin(t),-.7),(0,0,t+math.pi/2),'supports')
            fastener(a,(7.85*math.cos(t),7.85*math.sin(t),.30))
        t=angle+math.pi/12
        instance(a,'rim_drain_spout',(8.1*math.cos(t),8.1*math.sin(t),-.3),(0,0,t-math.pi/2),'drainage')
    socket(a,'START',(8,0,0),(0,-1,0)); socket(a,'END',(0,8,0),(-1,0,0)); results.append(a)
    a=assembly('04_bridge_foundation','P0 · Bridge landing · separate feet, bearings, beams and triangular gussets')
    for x in (-1.5,1.5):
        for y in (-1.5,1.5):
            instance(a,'landing_footing',(x,y,-1.62),layer='footings')
            instance(a,'landing_bearing',(x,y,-.97),layer='bearings')
            instance(a,'hardware_anchor_plate',(x,y,-.85),layer='anchors')
            for dx in (-.09,.09):
                for dy in (-.09,.09): fastener(a,(x+dx,y+dy,-.80))
    for y in (-1.5,1.5): instance(a,'landing_crossbeam',(0,y,-.83),layer='beams')
    for x in (-1.5,1.5): instance(a,'landing_crossbeam',(x,0,-.83),(0,0,math.pi/2),'beams')
    tiles(a,2,(-2,-2))
    for x in (-1.65,.65): instance(a,'landing_gusset',(x,-1.73,-.90),(math.pi/2,0,0),'brackets')
    for x in (-1.5,1.5): instance(a,'landing_pin_collar',(x,-2,.01),layer='pins')
    collision(a,box('landing_proxy',(4,4,.38),'cream',0,centre=(0,0,-.19)),'landing')
    socket(a,'BRIDGE',(0,-2,0),(0,-1,0)); socket(a,'ISLAND',(0,2,0),(0,1,0)); results.append(a)
    a=assembly('05_ramp_stair','P0 · Parallel smooth ramp and two-step foundation · shared landing')
    instance(a,'access_ramp_wedge',layer='ramp')
    instance(a,'access_slope_curb',(-.09,0,0),layer='curbs')
    instance(a,'access_slope_curb',(2,0,0),layer='curbs')
    for x in (0,2): instance(a,'access_landing_slab',(x,3.6,.3),layer='landing')
    for i in range(2):
        instance(a,'access_step_block',(2,3+i*.3,i*.15),layer='steps')
        instance(a,'access_nosing',(3,3+i*.3+.025,(i+1)*.15-.01),layer='inlay')
    instance(a,'access_side_stringer',(4.01,3,0),layer='stringer')
    for i in range(16):
        for j in range(3): instance(a,'access_tactile_stud',(.12+i*.25,3.82+j*.09,.3),layer='tactile')
    collision(a,wedge('smooth_ramp_proxy',2,3.6,.3),'ramp')
    collision(a,box('shared_landing',(4,1.5,.25),'cream',0,centre=(2,4.35,.175)),'shared_landing')
    c=collision(a,wedge('stair_smooth_proxy',2,.6,.3),'stair_ramp'); c.location=(2,3,0)
    socket(a,'ENTRY',(1,0,0),(0,-1,0)); socket(a,'EXIT',(1,5.1,.3),(0,1,0)); results.append(a)
    a=assembly('06_cliff_ledge','P1 · Maintenance shelf · replaceable diamond grate and braced supports')
    instance(a,'ledge_shelf_slab',layer='deck')
    for x in (-1.6,1.6):
        instance(a,'hardware_anchor_plate',(x,0,-1.2),(math.pi/2,0,0),'anchors')
        instance(a,'ledge_diagonal_brace',(x,.08,-1.2),(-math.pi/4,0,0),'supports',(1,1,.8))
        for dx in (-.08,.08): fastener(a,(x+dx,-.026,-1.10),(math.pi/2,0,0))
    for centre in (-1,0,1):
        for yy in (.30,1.30): instance(a,'ledge_grate_frame',(centre,yy,.008),layer='grates')
        for xx in (-.5,.5): instance(a,'ledge_grate_frame',(centre+xx,.8,.008),(0,0,math.pi/2),'grates')
        for j in range(11):
            for sign in (-1,1):
                # Clip each diagonal to the frame's .9 m clear opening.
                c=-.75+j*.15; h=.45; points=[]
                for x in (-h,h):
                    y=sign*x+c
                    if -h<=y<=h: points.append(Vector((x,y,0)))
                for y in (-h,h):
                    x=(y-c)/sign
                    if -h<x<h: points.append(Vector((x,y,0)))
                if len(points)!=2: continue
                p,q=points; midpoint=(p+q)/2; delta=q-p
                instance(a,'ledge_grate_bar',(centre+midpoint.x,.8+midpoint.y,.02),
                         (0,0,math.atan2(delta.y,delta.x)),'grates',(delta.length/.84,1,1))
    collision(a,box('ledge_proxy',(4,1.5,.22),'cream',0,centre=(0,.75,-.11)),'ledge')
    socket(a,'WALL',(0,0,-.2),(0,-1,0)); results.append(a)
    a=assembly('07_planter_bed','P1 · Raised planter · replaceable soil, membrane and drainage cells')
    for x in (-1,1):
        for y in (-1,1): instance(a,'soil_wall',(x,y,0),layer='walls')
        instance(a,'soil_drainage_insert',(x,0,0),layer='drainage')
        instance(a,'soil_separator_sheet',(x,0,.10),layer='separator')
        instance(a,'soil_insert',(x,0,.106),layer='soil')
        for i in range(15):
            instance(a,'rock_scree_chip',(x+RNG.uniform(-.7,.7),RNG.uniform(-.7,.7),.28),(0,0,RNG.random()*math.tau),'gravel')
    for x in (-2,2): instance(a,'soil_wall',(x,0,0),(0,0,math.pi/2),'walls')
    for x in (-2,0,2):
        for y in (-1,1):
            instance(a,'soil_corner_post',(x,y,0),layer='posts')
            fastener(a,(x,y,.6))
    socket(a,'PLANT_LEFT',(-1,0,.286)); socket(a,'PLANT_RIGHT',(1,0,.286)); results.append(a)
    a=assembly('08_water_basin','P2 · Empty basin shell · liner, coping, corner closures and drain')
    instance(a,'basin_liner',layer='liner')
    for x in (-1,1):
        for y in (-1.9,1.9): instance(a,'basin_wall',(x,y,.14),layer='walls')
    for x in (-1.9,1.9):
        for y in (-1,1): instance(a,'basin_wall',(x,y,.14),(0,0,math.pi/2),'walls')
    for x in (-1.9,1.9):
        for y in (-1.9,1.9): instance(a,'basin_corner',(x,y,.14),layer='corners')
    for i in range(4):
        v=-1.5+i
        for y in (-1.9,1.9): instance(a,'basin_coping',(v,y,.69),layer='coping')
        for x in (-1.9,1.9): instance(a,'basin_coping',(x,v,.69),(0,0,math.pi/2),'coping')
    instance(a,'basin_drain_disc',(0,0,.16),layer='drain')
    for i in range(-3,4): instance(a,'basin_grille',(0,i*.03,.166),layer='drain')
    socket(a,'WATER_LEVEL',(0,0,.5)); socket(a,'DRAIN_OUTLET',(0,0,0),(0,0,-1)); results.append(a)
    return results


def bounds(root):
    bpy.context.view_layer.update()
    pts=[o.matrix_world@Vector(v) for o in descendants(root) if o.type=='MESH' and not o.get('collision_proxy') for v in o.bound_box]
    low=Vector(tuple(min(p[i] for p in pts) for i in range(3)))
    high=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
    return low,high


def export(root):
    cid=root.get('part_id') or root['assembly_id']
    spec=dict(SPECS[cid])
    path=(PARTS if spec['kind']=='part' else ASSEMBLIES)/(cid+'.glb')
    bpy.ops.object.select_all(action='DESELECT')
    for obj in descendants(root): obj.hide_set(False); obj.select_set(True)
    bpy.context.view_layer.objects.active=root
    with contextlib.redirect_stdout(io.StringIO()):
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_extras=True,export_yup=True,export_cameras=False,export_lights=False)
    lo,hi=bounds(root)
    meshes=[o for o in descendants(root) if o.type=='MESH' and not o.get('collision_proxy')]
    spec.update(glb=str(path.relative_to(OUT)),bytes=path.stat().st_size,
                sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                bounds_min_m=list(lo),bounds_max_m=list(hi),dimensions_m=list(hi-lo),
                triangles=sum(len(o.data.polygons) for o in meshes),
                mesh_instances=len(meshes),unique_meshes=len({o.data.name for o in meshes}),
                sockets=[{'name':o.name,'position_m':list(o.location),'forward':list(o.get('forward',[]))} for o in root.children if o.name.startswith('SOCKET_')],
                bill_of_materials=dict(sorted(Counter(o['part_id'] for o in meshes if 'part_id' in o).items())),
                collisions=sum(bool(o.get('collision_proxy')) for o in descendants(root)))
    RECORDS.append(spec)
    print('[MST] exported',cid,spec['triangles'],'triangles',flush=True)


def setup_studio():
    scene=bpy.context.scene
    scene.render.engine='BLENDER_EEVEE'
    scene.render.image_settings.file_format='PNG'
    scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('Terrain_studio')
    scene.world.use_nodes=True
    bg=scene.world.node_tree.nodes.get('Background')
    bg.inputs['Color'].default_value=(.20,.24,.28,1); bg.inputs['Strength'].default_value=.55
    scene.view_settings.look='AgX - Medium High Contrast'
    rig=collection('STUDIO_not_exported')
    bpy.ops.object.camera_add(location=(20,-26,22)); cam=bpy.context.object; move(cam,rig)
    cam.name='Terrain_Review_Camera'; cam.data.type='ORTHO'; scene.camera=cam
    for name,energy,color,pos,size in [
        ('Warm_key',3100,(1,.84,.66),(4,-7,13),9),
        ('Soft_fill',2400,(.80,.88,1),(-8,-1,9),10),
        ('Warm_rim',3500,(1,.89,.72),(2,9,12),8)]:
        bpy.ops.object.light_add(type='AREA',location=pos); o=bpy.context.object; move(o,rig)
        o.name=name; o.data.energy=energy; o.data.color=color; o.data.shape='DISK'; o.data.size=size
        o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.light_add(type='SUN',rotation=(.4,-.5,-.3))
    sun=bpy.context.object; move(sun,rig)
    sun.name='Soft_daylight'; sun.data.energy=1.4; sun.data.angle=.4
    return cam,rig


def show_only(roots,shown):
    for root in roots:
        for o in descendants(root): o.hide_render=root not in shown or bool(o.get('collision_proxy'))


def frame(camera,roots,width=1100,height=850):
    scene=bpy.context.scene
    scene.render.resolution_x=width; scene.render.resolution_y=height
    scene.render.resolution_percentage=100
    boxes=[bounds(root) for root in roots]
    low=Vector(tuple(min(b[0][i] for b in boxes) for i in range(3)))
    high=Vector(tuple(max(b[1][i] for b in boxes) for i in range(3)))
    target=(low+high)*.5
    low_angle=len(roots)==1 and roots[0].get('assembly_id')=='01_rock_base'
    camera.location=target+Vector((20,-26,10) if low_angle else (20,-26,22))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    bpy.context.view_layer.update()
    view=camera.matrix_world.inverted()
    pts=[view@(o.matrix_world@Vector(v)) for root in roots for o in descendants(root) if o.type=='MESH' and not o.get('collision_proxy') for v in o.bound_box]
    span_x=max(p.x for p in pts)-min(p.x for p in pts)
    span_y=max(p.y for p in pts)-min(p.y for p in pts)
    # Blender ortho_scale is horizontal field width for landscape sensor fit.
    camera.data.ortho_scale=max(span_x,span_y*width/height)*1.20


def render(camera,roots,shown,path,width=1100,height=850):
    show_only(roots,shown); frame(camera,shown,width,height)
    bpy.context.scene.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)


def contact_sheet(camera,roots,assemblies):
    """Blender-rendered review board, individually framed assets rather than a distant grid."""
    scene=bpy.context.scene; board=collection('TEMP_contact_sheet')
    show_only(roots,[])
    old_view=scene.view_settings.view_transform; old_look=scene.view_settings.look
    scene.view_settings.view_transform='Standard'; scene.view_settings.look='None'
    titles=['01  FLOATING ROCK BASE','02  CIVIC DECK','03  RETAINING BAND','04  BRIDGE FOUNDATION',
            '05  RAMP + STAIRS','06  CLIFF LEDGE','07  PLANTER SOIL BED','08  EMPTY BASIN SHELL']
    for i,root in enumerate(assemblies):
        x=((i%4)-1.5)*4.8; y=(.5-(i//4))*4.3
        bpy.ops.mesh.primitive_plane_add(size=2,location=(x,y,0))
        plane=bpy.context.object; move(plane,board); plane.scale=(2.2,1.7,1)
        mat=bpy.data.materials.new('TEMP_board_image_'+str(i)); mat.use_nodes=True
        nodes=mat.node_tree.nodes; nodes.clear()
        tex=nodes.new('ShaderNodeTexImage'); tex.image=bpy.data.images.load(str(PREVIEWS/(root['assembly_id']+'.png')),check_existing=True)
        emit=nodes.new('ShaderNodeEmission'); output=nodes.new('ShaderNodeOutputMaterial')
        mat.node_tree.links.new(tex.outputs['Color'],emit.inputs['Color'])
        mat.node_tree.links.new(emit.outputs[0],output.inputs['Surface'])
        plane.data.materials.append(mat)
        bpy.ops.object.text_add(location=(x-2.2,y-1.98,.01))
        label=bpy.context.object; move(label,board); label.data.body=titles[i]
        label.data.size=.18; label.data.materials.append(MATS['ivory'])
    camera.location=(0,0,20); camera.rotation_euler=(0,0,0); camera.data.ortho_scale=19.7
    scene.render.resolution_x=2000; scene.render.resolution_y=1000
    scene.render.filepath=str(PREVIEWS/'00_eight_assemblies.png')
    bpy.ops.render.render(write_still=True)
    for obj in list(board.objects): bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.collections.remove(board)
    scene.view_settings.view_transform=old_view; scene.view_settings.look=old_look
    for root in roots:
        for obj in descendants(root): obj.hide_render=bool(obj.get('collision_proxy'))


def previews(roots,assemblies):
    camera,rig=setup_studio()
    for root in assemblies:
        cid=root['assembly_id']
        render(camera,roots,[root],PREVIEWS/(cid+'.png'))
        original={o:o.location.copy() for o in root.children if o.type=='MESH'}
        orders={
            '01_rock_base':[['tip'],['rock_keel_sector'],['rock_shoulder_sector'],['fractures'],['rock_cap_sector'],['surface_rocks']],
            '02_civic_deck':[['structure','edge'],['paving'],['inlay']],
            '03_retaining_band':[['supports'],['rim_wall_sector','drainage'],['rim_brass_sector'],['rim_coping_sector'],['fasteners']],
            '04_bridge_foundation':[['footings'],['bearings'],['beams','brackets'],['anchors'],['fasteners'],['structure'],['paving'],['inlay','pins']],
            '05_ramp_stair':[['ramp','steps','stringer'],['landing','curbs'],['inlay','tactile']],
            '06_cliff_ledge':[['supports','anchors'],['deck','fasteners'],['grates']],
            '07_planter_bed':[['drainage','walls','posts'],['separator'],['soil'],['gravel','fasteners']],
            '08_water_basin':[['liner'],['walls','corners','drain'],['coping']],
        }
        layer_levels={layer:i for i,layers in enumerate(orders[cid]) for layer in layers}
        for obj in original:
            if obj.get('collision_proxy'): continue
            level=layer_levels[obj['assembly_layer']]
            obj.location.z+=level*(.9 if cid!='01_rock_base' else 1.1)
        render(camera,roots,[root],PREVIEWS/(cid+'_exploded.png'))
        for obj,loc in original.items(): obj.location=loc
    for cid,root in REGISTRY.items():
        render(camera,roots,[root],PREVIEWS/'parts'/(cid+'.png'),600,600)
    # Physical triangle edges, on the real model; not a painted texture.
    for cid in ('rock_shoulder_sector','deck_paving_half','soil_insert'):
        root=REGISTRY[cid]
        original=next(o for o in root.children if o.type=='MESH')
        wire=original.copy(); wire.data=original.data.copy(); root.users_collection[0].objects.link(wire)
        wire.name='PREVIEW_actual_triangle_edges'; wire.parent=root
        wire.data.materials.clear(); wire.data.materials.append(MATS['gunmetal'])
        mod=wire.modifiers.new('Actual_mesh_edges','WIREFRAME'); mod.thickness=.009 if cid=='rock_shoulder_sector' else .002
        render(camera,roots,[root],PREVIEWS/(cid+'_topology.png'))
        bpy.data.objects.remove(wire,do_unlink=True)
    for root in roots:
        for obj in descendants(root): obj.hide_render=bool(obj.get('collision_proxy'))
    # Master is an editable, labelled collection library, not a runtime scene.
    for i,root in enumerate(REGISTRY.values()): root.location=((i%10)*5,65+(i//10)*6,0)
    for i,root in enumerate(assemblies): root.location=((i%4)*22,(i//4)*28,0)
    contact_sheet(camera,roots,assemblies)
    frame(camera,assemblies,1500,1100)


def main():
    for path in (OUT,PARTS,ASSEMBLIES,PREVIEWS,PREVIEWS/'parts',SOURCE): path.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system='METRIC'
    bpy.context.scene.unit_settings.scale_length=1
    bpy.context.preferences.filepaths.save_version=0
    MATS.update(create_materials())
    for name,color in [('rock_mid',(.23,.18,.145,1)),('rock_light',(.32,.265,.21,1)),('rock_dark',(.115,.09,.075,1)),('rock_warm',(.27,.17,.115,1)),('soil',(.08,.035,.018,1)),('soil_light',(.13,.07,.03,1))]:
        MATS[name]=make_material('MST_'+name,color,roughness=.88)
    create_parts()
    assemblies=build_assemblies(); roots=list(REGISTRY.values())+assemblies
    for root in roots: export(root)
    # Confirm actual seam positions before presentation transforms are applied.
    seam_tests=[]
    for cid in ('rock_cap_sector','rock_shoulder_sector','rock_keel_sector','rim_wall_sector'):
        mesh_obj=next(o for o in REGISTRY[cid].children if o.type=='MESH')
        verts=[v.co for v in mesh_obj.data.vertices]
        start=sorted((round(v.x,5),round(v.z,5)) for v in verts if abs(v.y)<1e-6 and v.x>.01)
        end=sorted((round(math.hypot(v.x,v.y),5),round(v.z,5)) for v in verts if abs(math.atan2(v.y,v.x)-math.pi/6)<1e-6)
        seam_tests.append({'id':cid,'passed':start==end,'start_edge':start,'rotated_end_edge':end})
    assert all(t['passed'] for t in seam_tests),seam_tests
    if '--no-render' not in sys.argv: previews(roots,assemblies)
    bpy.ops.object.select_all(action='DESELECT')
    # Save a useful opening viewport on the eight assemblies.
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_distance=90
                area.spaces.active.region_3d.view_location=(25,12,-1)
                area.spaces.active.shading.type='MATERIAL'
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'mind_spark_terrain_triangles.blend'))
    payload={'schema':1,'part_count':len(REGISTRY),'assembly_count':len(assemblies),
             'units':'metres','source_up':'Z','gltf_up':'Y','seed':17031,
             'not_integrated_into_live_map':True,'sector_angle_degrees':30,'reference_island_radius_m':8,
             'seam_tests':seam_tests,'assets':RECORDS}
    (OUT/'manifest.json').write_text(json.dumps(payload,indent=2))
    print('[MST] COMPLETE: 50 parts, 8 assemblies; all faces triangulated; seam tests passed',flush=True)


if __name__=='__main__': main()
