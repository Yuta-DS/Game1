"""Island-two hanging-garden silhouette. Preserve v11 and the gameplay disc.

Run in Blender background; export a separate revision, never overwrite v11.
Reusable connected components are grouped transparently to 3,000 authoring parts.
"""
import csv
import json
import math
import random
import sys
from collections import Counter
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_celestial_islands_v11 as reference
base = reference.base
kit = reference.kit
ROOT = reference.ROOT
OUT = ROOT / "assets3D/mind_spark/celestial_verdant_v12"
SOURCE = reference.OUT / "source/island_02_3000.blend"
TAU = math.tau
RNG = random.Random(1202)


def group(category, assembly):
    base.GROUP = category
    base.ASSEMBLY = assembly


def smooth(t):
    t = max(0, min(1, t))
    return t*t*(3-2*t)


def solid(name, rings, material="rock", role="Rock", sides=14, phase=0):
    """Closed triangulated, irregular strata; rings are cx,cy,z,rx,ry."""
    verts = []
    modulation = [1 + RNG.uniform(-.10, .10) for _ in range(sides)]
    for k, (x, y, z, rx, ry) in enumerate(rings):
        for j in range(sides):
            a = phase + TAU*j/sides
            f = modulation[j]
            verts.append((x+rx*f*math.cos(a), y+ry*f*math.sin(a), z))
    faces = [tuple(reversed(range(sides)))]
    for k in range(len(rings)-1):
        for j in range(sides):
            a = k*sides+j
            b = k*sides+(j+1)%sides
            faces.append((a, b, b+sides, a+sides))
    faces.append(tuple((len(rings)-1)*sides+j for j in range(sides)))
    return kit.mesh(name, verts, faces, material, role)


def retain_upper_rock():
    """Cut and cap the former single cone; its crown still bears the civic deck."""
    removed = 0
    for obj in list(base.PARTS):
        if obj.get("role") != "Rock":
            continue
        obj.data.transform(obj.matrix_world)
        obj.matrix_world = Matrix.Identity(4)
        if max(v.co.z for v in obj.data.vertices) < -.745:
            base.PARTS.remove(obj)
            base.discard_object(obj)
            removed += 1
            continue
        if min(v.co.z for v in obj.data.vertices) < -.745:
            bm = bmesh.new()
            bm.from_mesh(obj.data)
            result = bmesh.ops.bisect_plane(bm, geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                dist=.000001, plane_co=(0,0,-.745), plane_no=(0,0,1), clear_inner=True)
            boundary = [e for e in bm.edges if e.is_boundary and all(abs(v.co.z+.745)<.00001 for v in e.verts)]
            if boundary:
                bmesh.ops.holes_fill(bm, edges=boundary, sides=0)
            bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
            bmesh.ops.triangulate(bm, faces=list(bm.faces))
            bm.to_mesh(obj.data)
            bm.free()
            obj.data.update()
        obj["silhouette_component"] = "preserved capped rock crown"
    return removed


def keels():
    group("07_Split_Floating_Keels", "West hanging rock keel")
    solid("WestKeel_Core", [(-.43,.07,-.66,.46,.42),(-.49,.03,-.98,.35,.32),
        (-.57,.03,-1.32,.25,.23),(-.69,.02,-1.68,.026,.04)], sides=19)
    group("07_Split_Floating_Keels", "East hanging rock keel")
    solid("EastKeel_Core", [(.44,.08,-.65,.47,.43),(.55,.07,-1.08,.35,.35),
        (.65,.02,-1.54,.22,.21),(.74,.01,-2.02,.025,.035)], sides=21)
    # Basalt-like hanging flutes give scale and an irregular, non-conical outline.
    for side in (-1,1):
        group("07_Split_Floating_Keels", "West rock flutes" if side<0 else "East rock flutes")
        for j in range(26):
            a = TAU*j/26
            cx = side*(.50 if side<0 else .56) + .26*math.cos(a)
            cy = .06+.27*math.sin(a)
            length = RNG.uniform(.43,.82) * (1.15 if side>0 else .95)
            z = -.78-RNG.uniform(0,.15)
            r = RNG.uniform(.07,.115)
            tipx = cx+side*.12
            solid(f"{'East' if side>0 else 'West'}_RockFlute_{j+1:02d}",
                [(cx,cy,z,r*1.18,r),(cx+side*.03,cy,z-length*.5,r,r*.85),
                 (tipx,cy*.88,z-length,r*.17,r*.20)],
                material=("rock","rock_light","rock_shade")[j%3], sides=6+j%3, phase=a)


def ellipse_point(center, rx, ry, angle, z):
    return Vector((center[0]+rx*math.cos(angle), center[1]+ry*math.sin(angle), z))


def ellipse_path(center, rx, ry, z, count=64):
    return [ellipse_point(center, rx, ry, j*TAU/count, z) for j in range(count+1)]


def leaf_cluster(label, origin, size, variant):
    """One editable foliage cluster with curved leaf blades and visible petioles."""
    verts, faces = [], []
    for j in range(7):
        a = TAU*j/7+variant*.7
        length = size*RNG.uniform(.65,1.05)
        root = Vector(origin)+Vector((0,0,size*.15))
        tangent = Vector((math.cos(a),math.sin(a),0))
        across = Vector((-math.sin(a),math.cos(a),0))
        # Curved blade sections; pointed tips use a tiny non-zero width.
        start = len(verts)
        for k in range(4):
            t=k/3
            mid=root+tangent*length*t+Vector((0,0,size*(.35*math.sin(math.pi*t)+.12*t)))
            width=max(.007,math.sin(math.pi*t))*length*.22
            verts.extend([tuple(mid-across*width),tuple(mid+Vector((0,0,size*.045*math.sin(math.pi*t)))),tuple(mid+across*width)])
        for k in range(3):
            n=start+k*3
            faces.extend([(n,n+3,n+4,n+1),(n+1,n+4,n+5,n+2)])
    return kit.mesh(label,verts,faces,"leaf" if variant%3 else "leaf_light","Architecture",smooth=True)


def terrace(label, center, rx, ry, z, side, plants):
    group("08_Hanging_Garden_Terraces", label+" masonry")
    # Segment masonry follows a true ellipse, avoiding disconnected circular pods.
    for j in range(24):
        a0=TAU*j/24+.002
        a1=TAU*(j+1)/24-.002
        vs=[]
        for zz in (z-.065,z):
            for s in (.83,1.0):
                for k in range(4):
                    a=a0+(a1-a0)*k/3
                    vs.append(tuple(ellipse_point(center,rx*s,ry*s,a,zz)))
        fs=[]
        for k in range(3):
            fs += [(k,k+1,k+5,k+4),(k+8,k+12,k+13,k+9),
                   (k,k+8,k+9,k+1),(k+4,k+5,k+13,k+12)]
        fs += [(0,4,12,8),(3,11,15,7)]
        kit.mesh(f"{label}_CurvedStone_{j+1:02d}",vs,fs,"ivory",bevel=.0015)
    solid(label+"_PlanterBowl",[(center[0],center[1],z-.065,rx*.90,ry*.90),
        (center[0],center[1],z-.020,rx*.87,ry*.87)],"ivory","Architecture",48)
    solid(label+"_Soil",[(center[0],center[1],z-.021,rx*.82,ry*.82),
        (center[0],center[1],z-.016,rx*.82,ry*.82)],"soil","Architecture",48)
    for suffix,scale,zz,thick,mat in [("OuterBrassLip",1.005,z-.008,.006,"gold"),
            ("LowerChampagneReveal",.96,z-.060,.0045,"gold"),
            ("SageFrieze",.97,z-.040,.009,"sage")]:
        kit.tube(label+suffix,ellipse_path(center,rx*scale,ry*scale,zz),thick,mat,sides=10)
    # Stone consoles are rooted in the rock crown/keel and carry the outer bowl.
    group("08_Hanging_Garden_Terraces", label+" load-bearing consoles")
    for j,dy in enumerate((-.17,.17)):
        origin=Vector((side*.63,center[1]+dy,z-.35))
        end=Vector((center[0]+side*rx*.59,center[1]+dy,z-.068))
        pts=[origin.lerp(end,t)+Vector((0,0,-.045*math.sin(t*math.pi))) for t in [k/20 for k in range(21)]]
        kit.tube(label+f"_IvoryConsole_{j}",pts,.025,"ivory",sides=12)
        kit.tube(label+f"_ConsoleBrassEdge_{j}",[p+Vector((0,-.025,0)) for p in pts],.005,"gold",sides=10)
        kit.box(label+f"_ConsoleBearing_{j}",end,(.10,.09,.028),"gold",.004)
    group("09_Botanical_Planting", label+" planted bed")
    # Dense planted ledges stay well below the gameplay plane.
    for j in range(plants):
        a=j*2.3999632297
        r=math.sqrt((j+.5)/plants)
        at=(center[0]+rx*.74*r*math.cos(a),center[1]+ry*.70*r*math.sin(a),z-.008)
        leaf_cluster(label+f"_Plant_{j+1:02d}",at,.052+RNG.random()*.018,j)
    group("09_Botanical_Planting", label+" trailing vines")
    outward=0 if side>0 else math.pi
    for j in range(7):
        a=outward-.9+j*.3
        top=ellipse_point(center,rx*.95,ry*.95,a,z-.013)
        length=.16+.09*(j%3)
        path=[top+Vector((side*.025*math.sin(t*math.pi),.012*math.sin(t*TAU),-length*t)) for t in [k/18 for k in range(19)]]
        kit.tube(label+f"_VineStem_{j}",path,.0028,"leaf","Architecture",sides=6)
        for k in range(3):
            leaf_cluster(label+f"_VineLeaves_{j}_{k}",path[(k+1)*5],.023,j+k)
    # Rooted shoulder volume ties garden terraces into the silhouette.
    group("07_Split_Floating_Keels", label+" rocky shoulder")
    solid(label+"_RockShoulder",[(center[0]-side*.07,center[1],z-.07,rx*.83,ry*.82),
        (center[0]-side*.13,center[1],z-.26,rx*.55,ry*.60),
        (side*.62,center[1]*.5,z-.49,.11,.12)],sides=16)


def load_stays():
    group("10_Steam_Lift_Structure", "Keel tie beams")
    # Upper structural bridge and explicit socket plates join both load paths.
    for y in (-.23,.28):
        kit.box("TransverseKeelTie",(.02,y,-.80),(1.38,.065,.08),"ivory",.009)
        kit.box("TransverseKeelTie_BrassWeb",(.02,y-.036,-.80),(1.31,.011,.033),"gold",.003)
    for side in (-1,1):
        for j,y in enumerate((-.38,.31)):
            group("10_Steam_Lift_Structure", f"{'East' if side>0 else 'West'} steam suspension stay {j+1}")
            top=Vector((side*.91,y,-.19))
            foot=Vector((side*(.68 if side>0 else .59),y*.53,-1.29 if side>0 else -1.13))
            axis=(top-foot).normalized()
            kit.tube("LiftStay_IvoryOuterCasing",[foot,top],.049,"ivory","Machinery",sides=32)
            mid1=foot.lerp(top,.23)
            mid2=foot.lerp(top,.79)
            kit.tube("LiftStay_CopperPressureJacket",[mid1,mid2],.057,"copper","Machinery",sides=32)
            for k in range(7):
                at=foot.lerp(top,.23+k*.56/6)
                kit.tube(f"LiftStay_BrassCompressionHoop_{k}",[at-axis*.008,at+axis*.008],.062,"gold","Machinery",sides=32)
            for k,at in enumerate((foot,top)):
                kit.box(f"LiftStay_LoadSpreadingShoe_{k}",at,(.17,.16,.06),"gold",.009,"Machinery")
                for sx in (-1,1):
                    for sy in (-1,1):
                        base.cylinder(f"LiftStay_ShoeBolt_{k}_{sx}_{sy}",at+Vector((sx*.058,sy*.054,.033)),.011,.013,"copper",8)
            # Continuous supply / return paths lead to the crown bearing band.
            for offset,mat in ((-.075,"copper"),(.075,"gold")):
                p=foot+Vector((0,offset,0))
                q=top+Vector((0,offset,0))
                base.pipe("LiftStay_ConnectedFluidLine",[p,q,Vector((q.x*.82,q.y,-.085))],.009,mat)
            # Narrow pale-teal level glass communicates energy without a clock.
            window1=foot.lerp(top,.33)+Vector((0,-.060,0))
            window2=foot.lerp(top,.69)+Vector((0,-.060,0))
            kit.tube("LiftStay_LevelGlass",[window1,window2],.012,"opal","Machinery",sides=12)


def finish():
    bpy.context.view_layer.update()
    natural=len(base.PARTS)
    merges=reference.combine_to_budget(max_group_size=12)
    splits=base.subdivide_to_target()
    rows=[]
    for i,obj in enumerate(sorted(base.PARTS,key=lambda o:(o["category"],o["assembly"],o.name))):
        obj.data.transform(obj.matrix_world)
        obj.matrix_world=Matrix.Identity(4)
        center=sum((v.co for v in obj.data.vertices),Vector())/len(obj.data.vertices)
        obj.data.transform(Matrix.Translation(-center))
        obj.location=center
        old_name=obj.name
        identifier=f"MS12-I02-P{i+1:04d}"
        obj.name=identifier+"_"+old_name[-39:]
        obj["part_id"]=identifier
        obj["island_id"]=2
        rows.append({"part_id":identifier,"name":old_name,"role":obj["role"],"category":obj["category"],
            "assembly":obj["assembly"],"kind":obj["component_kind"],"triangles":len(obj.data.polygons),
            "source_component":obj.get("source_component",old_name)})
    bpy.context.view_layer.update()
    # Reuse the five-family exporter; only its destination is changed.
    reference.OUT=OUT
    triangles=reference.batch(1)
    bpy.context.preferences.filepaths.save_version=0
    pending=OUT/"staging/island_02_3000.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(pending),compress=True)
    pending.replace(OUT/"source/island_02_3000.blend")
    with (OUT/"bom/island_02_parts.csv").open("w",newline="") as stream:
        writer=csv.DictWriter(stream,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    record=json.loads((SOURCE.parent.parent/"island_02_record.json").read_text())
    record.update(revision="v12",silhouette="split asymmetric hanging-garden keels",runtime_triangles=triangles,
        source="source/island_02_3000.blend",bom="bom/island_02_parts.csv",natural_components=natural,
        related_fitting_merges=merges,surface_patch_splits=splits,
        component_kinds=dict(Counter(o["component_kind"] for o in base.PARTS)),
        planting_terraces=4,pressure_suspension_stays=4,
        gameplay_policy="Original circular collision/paving and bridges unchanged; side gardens are inaccessible scenic ledges below gameplay.",
        machinery_policy="Static fictional steam lift architecture, no physical levitation simulation.")
    (OUT/"island_02_record.json").write_text(json.dumps(record,indent=2)+"\n")
    return record


def main():
    for sub in ("source","bom","staging"):
        (OUT/sub).mkdir(parents=True,exist_ok=True)
        (OUT/sub/".gdignore").touch()
    sources=[SOURCE,SOURCE.parent.parent/"island_02.glb",ROOT/"assets3D/mind_spark/celestial_islands_v08/shared_paving.glb"]
    hashes={str(p.relative_to(ROOT)):base.sha(p) for p in sources}
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    base.PARTS[:]=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    base.SCENE_COLLECTION=bpy.data.collections.new("VERDANT_V12_ADDITIONS")
    bpy.context.scene.collection.children.link(base.SCENE_COLLECTION)
    base.COLLECTIONS.clear()
    kit.register=base.register
    kit.M={"ivory":bpy.data.materials["MSCT_ivory"],"gold":bpy.data.materials["MSCT_gold"],
        "copper":bpy.data.materials["MSCT_copper.002"],"sage":bpy.data.materials["CelestialSageEnamel"],
        "rock":bpy.data.materials["MSCT_rock"],"rock_light":bpy.data.materials["MSCT_rock_light"],
        "rock_shade":bpy.data.materials["MSCT_rock_shade"],"opal":bpy.data.materials["MSCT_v6_energy"]}
    kit.M["soil"]=kit.newmat("VerdantV12_PlanterSoil",(.10,.12,.075))
    kit.M["leaf"]=kit.newmat("VerdantV12_SageFoliage",(.18,.31,.18))
    kit.M["leaf_light"]=kit.newmat("VerdantV12_OliveFoliage",(.34,.44,.23))
    for key in ("leaf","leaf_light"):
        kit.M[key].use_backface_culling=False
    removed=retain_upper_rock()
    keels()
    terrace("EastUpperGarden",(.99,.06),.58,.43,-.23,1,32)
    terrace("EastLowerGarden",(1.05,.10),.45,.33,-.56,1,24)
    terrace("WestUpperGarden",(-.94,.14),.45,.37,-.35,-1,26)
    terrace("WestLowerGarden",(-.95,.09),.36,.28,-.65,-1,20)
    load_stays()
    bpy.context.view_layer.update()
    print("V12_PREPARED",len(base.PARTS),"removed old lower rock",removed,flush=True)
    record=finish()
    assert all(base.sha(ROOT/p)==h for p,h in hashes.items()),"Baseline source changed"
    manifest={"revision":"v12","island_id":2,"name":"Verdant Engine Gardens","source_checksums":hashes,
        "shared_paving":"res://assets3D/mind_spark/celestial_islands_v08/shared_paving.glb","variant":record}
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print("VERDANT_V12_BUILT",json.dumps(record),flush=True)


if __name__=="__main__":main()
