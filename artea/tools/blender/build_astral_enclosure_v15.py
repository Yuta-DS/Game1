"""Complete missing perimeter rail panels and enclose the exposed side plant.

Retains every v14 surface; new curved bays and rail infills are editable meshes.
Only bridge corridors remain open. Previous .blend and GLB files stay untouched.
"""
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_astral_underside_v14 as prior
astral,base,kit,reference=prior.astral,prior.base,prior.kit,prior.reference
ROOT=prior.ROOT
OUT=ROOT/"assets3D/mind_spark/celestial_astral_v15"
SOURCE=ROOT/"assets3D/mind_spark/celestial_astral_v14/source/island_03_3000.blend"
TRIANGLE_LIMIT=595000  # Completed reference rails; whole-world 3.5M ceiling unchanged.
TAU=math.tau
group=astral.group


def merged(intervals):
    out=[]
    for lo,hi in sorted(intervals,key=lambda pair:pair[0]):
        if out and lo<=out[-1][1]+1e-5:out[-1][1]=max(hi,out[-1][1])
        else:out.append([lo,hi])
    return out


def angular_intervals(objects):
    groups={}
    for obj in objects:groups.setdefault(obj["assembly"],[]).append(obj)
    result=[]
    for members in groups.values():
        points=[o.matrix_world@v.co for o in members for v in o.data.vertices]
        angles=[math.atan2(p.y,p.x)%TAU for p in points]
        # Current bays and posts are all much shorter than a semicircle.
        if max(angles)-min(angles)>math.pi:
            shifted=[a-TAU if a>math.pi else a for a in angles]
            result.extend(((0,max(shifted)),(min(shifted)+TAU,TAU)))
        else:result.append((min(angles),max(angles)))
    return merged(result)


def uncovered(covered):
    result=[];start=0
    for lo,hi in merged(covered):
        if lo-start>.001:result.append((start,lo))
        start=max(start,hi)
    if TAU-start>.001:result.append((start,TAU))
    return result


def horizontal_section_intervals(objects,z):
    """Actual triangle/plane intersections, not a post's wider base footprint."""
    intervals=[]
    for obj in objects:
        points=[obj.matrix_world@v.co for v in obj.data.vertices]
        for face in obj.data.polygons:
            vs=[points[i] for i in face.vertices]
            if min(v.z for v in vs)>z or max(v.z for v in vs)<z:continue
            crosses=[]
            for a,b in zip(vs,vs[1:]+vs[:1]):
                if abs(a.z-b.z)<1e-9:continue
                t=(z-a.z)/(b.z-a.z)
                if 0<=t<=1:
                    p=a.lerp(b,t);crosses.append(math.atan2(p.y,p.x)%TAU)
            if len(crosses)<2:continue
            lo,hi=min(crosses),max(crosses)
            if hi-lo>math.pi:intervals.extend(((0,lo),(hi,TAU)))
            else:intervals.append((lo,hi))
    return merged(intervals)


def fit_post_connections(routes):
    bpy.context.view_layer.update()
    count=0
    for z in (.135,.049):
        rails=[o for o in base.PARTS if o["role"]=="Railing"]
        gaps=uncovered(horizontal_section_intervals(rails,z)+routes)
        for lo,hi in gaps:
            assert hi-lo<.10,("Large unfilled rail span",lo,hi)
            lo-=.002;hi+=.002
            for a,b in routes:
                if abs(lo-b)<.003:lo=b
                if abs(hi-a)<.003:hi=a
            group("15_Completed_Ground_Barriers",f"Fitted post connection {count+1:02d}")
            # Original handrails sit at r~1.050; short returns use r=1.073.
            # A shallow radial socket reaches both, instead of a floating splice.
            kit.ring("BrassRailToPostConnector",1.059,.038,z,.012,"gold",2,lo,hi,"Railing")
            count+=1
    return count


def rail_post(angle,label,width=.036):
    group("15_Completed_Ground_Barriers",label)
    r=1.073
    for z,sz,material in ((.017,(width*1.5,.070,.032),"ivory"),
                          (.076,(width,.052,.096),"ivory"),
                          (.132,(width*1.5,.072,.020),"ivory"),
                          (.148,(width*1.18,.058,.012),"gold")):
        # Local X is tangent, local Y is radial.
        kit.box(label+"_MasonryCourse",(r*math.cos(angle),r*math.sin(angle),z),sz,material,.002,"Railing",angle-math.pi/2)
    for rr in (r-.028,r+.028):
        kit.box(label+"_GoldInlay",(rr*math.cos(angle),rr*math.sin(angle),.079),
                (width*.35,.004,.068),"gold",.0007,"Railing",angle-math.pi/2)


def rail_infills():
    bpy.context.view_layer.update()
    rails=[o for o in base.PARTS if o["role"]=="Railing"]
    template=[o for o in rails if o["assembly"]=="Panel_06"]
    points=[o.matrix_world@v.co for o in template for v in o.data.vertices]
    source_lo=min(math.atan2(p.y,p.x) for p in points)
    source_hi=max(math.atan2(p.y,p.x) for p in points)
    half=math.asin((22/175)/1.003)+.003
    routes=[]
    for i,d in enumerate(reference.directions(2)):
        a=math.atan2(d.y,d.x)%TAU
        routes.append((a-half,a+half))
        # A compact terminal pier, beyond the full bridge clearance envelope.
        for sign in (-1,1):
            rail_post(a+sign*(half+.013),f"Bridge_{i+1}_terminal_{sign}",.018)
    bpy.context.view_layer.update()
    rails=[o for o in base.PARTS if o["role"]=="Railing"]
    gaps=uncovered(angular_intervals(rails)+routes)
    for i,(lo,hi) in enumerate(gaps):
        if hi-lo>math.radians(31):rail_post((lo+hi)/2,f"LongSpan_IntermediatePier_{i+1}",.040)
    bpy.context.view_layer.update()
    gaps=uncovered(angular_intervals([o for o in base.PARTS if o["role"]=="Railing"])+routes)
    records=[]
    for i,(lo,hi) in enumerate(gaps):
        if hi-lo<.001:continue
        # Modest overlap with adjacent post geometry avoids hairline gaps.
        lo-=.001;hi+=.001
        # Never expand a span into the reserved entrance sector.
        for a,b in routes:
            if abs(lo-b)<.002:lo=b
            if abs(hi-a)<.002:hi=a
        group("15_Completed_Ground_Barriers",f"Fitted perimeter panel {i+1:02d}")
        records.append([lo,hi])
        if hi-lo<.085:
            for name,z,h,w,mat in (("Sill",.014,.022,.040,"ivory"),("Handrail",.135,.012,.013,"gold"),("Footrail",.049,.010,.009,"gold")):
                kit.ring("ShortReturn_"+name,1.073,w,z,h,mat,8,lo,hi,"Railing")
            for t in (.25,.75):
                a=lo+(hi-lo)*t
                kit.tube("ShortReturn_Picket",[(1.073*math.cos(a),1.073*math.sin(a),z) for z in (.05,.134)],.003,"gold","Railing",8)
            continue
        for original in template:
            obj=original.copy();obj.data=original.data.copy()
            obj.data.transform(original.matrix_world);obj.matrix_world=Matrix.Identity(4)
            for v in obj.data.vertices:
                r=math.hypot(v.co.x,v.co.y)
                a=lo+(math.atan2(v.co.y,v.co.x)-source_lo)/(source_hi-source_lo)*(hi-lo)
                v.co.x=r*math.cos(a);v.co.y=r*math.sin(a)
            if obj.data.has_custom_normals:
                # Remapping changes curvature; do not carry stale split normals.
                obj.data.normals_split_custom_set([(0,0,0)]*len(obj.data.loops))
            for key in list(obj.keys()):del obj[key]
            obj.name=f"FittedRail_{i+1:02d}_"+original.name[-32:]
            base.register(obj,"Railing")
    return {"bridge_opening_intervals":routes,"new_panel_intervals":records,"fitted_panel_count":len(records)}


def side_bay(side):
    label="West" if side<0 else "East"
    def p(u,z,depth=0):return (side*(.84+depth),.04+u,z)
    group("16_Carved_Side_Engine_Bays",label+" seated arch and pilasters")
    kit.box(label+"Bay_LoadSill",(side*.74,.04,-1.469),(.46,.84,.048),"ivory",.005)
    kit.box(label+"Bay_GoldSillReveal",(side*.979,.04,-1.459),(.010,.78,.014),"gold",.001)
    for u in (-.325,.325):
        for j in range(4):
            z=-1.3575+j*.177
            kit.box(label+f"Bay_PierCourse_{u}_{j}",p(u,z),(.13,.103,.174),"ivory",.003)
        kit.box(label+"Bay_PierShoe",p(u,-1.43),(.17,.145,.040),"ivory",.004)
        kit.box(label+"Bay_Impost",p(u,-.737),(.18,.15,.040),"ivory",.004)
        for du in (-.038,.038):
            kit.tube(label+"Bay_PierGoldFlute",[p(u+du,z,.067) for z in (-1.407,-.79)],.0035,"gold",sides=8)
        kit.box(label+"Bay_PierTealInlay",p(u,-1.04,.067),(.007,.049,.23),"blue",.001)
    # Segmented elliptical voussoirs span the piers; outside face looks outward.
    yaw=math.pi/2 if side>0 else -math.pi/2
    kit.arch(label+"Bay_CurvedStoneArch",p(0,-.737),.28,.43,.054,.14,yaw,19)
    # Upper spandrels run from the arch extrados to the underside of the crown.
    for j in range(18):
        a0=j*math.pi/18;a1=(j+1)*math.pi/18
        profile=[(.334*math.cos(a0),-.737+.484*math.sin(a0)),
                 (.334*math.cos(a1),-.737+.484*math.sin(a1)),
                 (.334*math.cos(a1),-.1025),(.334*math.cos(a0),-.1025)]
        vs=[p(u,z,d) for d in (-.10,-.035) for u,z in profile]
        # Flat infill stones sit behind the separately bevelled arch; no hidden bevel grid.
        kit.mesh(label+f"Bay_ShapedSpandrel_{j+1:02d}",vs,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],"ivory")
    for z,size,mat in ((-.12,(.18,.83,.035),"ivory"),(-.085,(.22,.88,.040),"ivory"),(-.061,(.21,.85,.010),"gold")):
        kit.box(label+"Bay_CrownCornice",(side*.84,.04,z),size,mat,.003)
    # Closed dark recess behind the engine, not a slab across its exposed front.
    group("16_Carved_Side_Engine_Bays",label+" recessed ventilation chamber")
    profile=[(-.274,-1.442),(.274,-1.442),(.274,-.737)]
    profile.extend((.274*math.cos(a),-.737+.423*math.sin(a)) for a in [j*math.pi/24 for j in range(1,25)])
    n=len(profile)
    vs=[p(u,z,d) for d in (-.347,-.322) for u,z in profile]
    fs=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]
    fs.extend((j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n))
    kit.mesh(label+"Bay_ArchedTealBacking",vs,fs,"blue")
    # Horizontal brass louvers fill the formerly empty space above the cylinder.
    for j in range(11):
        z=-.681+j*.028
        obj=kit.box(label+f"Bay_VentLouver_{j+1:02d}",p(0,z,-.092),(.050,.31,.013),"copper",.001)
        obj.rotation_euler.y=side*math.radians(-16)
    for u in (-.168,.168):
        kit.box(label+"Bay_VentFrame",p(u,-.53,-.080),(.033,.020,.345),"gold",.002)
    # Relief plates and warm opal bosses articulate the upper load-bearing face.
    for u in (-.245,.245):
        kit.box(label+"Bay_SpandrelGoldInset",p(u,-.268,-.030),(.011,.026,.19),"gold",.001)
    group("16_Carved_Side_Engine_Bays",label+" tied bay footing")
    for u in (-.25,.25):
        kit.tube(label+"Bay_FootingBrace",[(.045+side*.17,.085,-1.57),(side*.84,.04+u,-1.493)],.021,"ivory",sides=12)


def main():
    for sub in ("source","bom","staging"):
        (OUT/sub).mkdir(parents=True,exist_ok=True);(OUT/sub/".gdignore").touch()
    paths=[SOURCE,SOURCE.parent.parent/"island_03.glb",ROOT/"assets3D/mind_spark/celestial_islands_v08/shared_paving.glb",ROOT/"assets3D/mind_spark/celestial_verdant_v12/island_02.glb"]
    hashes={str(p.relative_to(ROOT)):base.sha(p) for p in paths}
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    base.PARTS[:]=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    base.SCENE_COLLECTION=bpy.data.collections.new("ASTRAL_V15_RAIL_AND_BAY_COMPLETION")
    bpy.context.scene.collection.children.link(base.SCENE_COLLECTION);base.COLLECTIONS.clear();kit.register=base.register
    kit.M={"ivory":bpy.data.materials["MSCT_ivory"],"gold":bpy.data.materials["MSCT_gold"],"copper":bpy.data.materials["MSCT_copper.002"],"blue":bpy.data.materials["AstralV13_DeepTealEnamel"]}
    count=sum(len(o.data.polygons) for o in base.PARTS)
    rail_record=rail_infills()
    rail_record["rail_post_connectors"]=fit_post_connections(rail_record["bridge_opening_intervals"])
    side_bay(-1);side_bay(1)
    added_triangles=sum(len(o.data.polygons) for o in base.PARTS)-count
    print("V15_ADDITIONS",len(base.PARTS)-3000,added_triangles,json.dumps(rail_record),flush=True)
    astral.OUT=OUT;astral.SOURCE=SOURCE
    record=astral.finish("v15",{**rail_record,"enclosed_side_bays":2,"ground_barrier_completion":True,
        "new_enclosure_triangles":added_triangles,"runtime_triangle_limit":TRIANGLE_LIMIT,
        "source_preservation":"All v14 geometry retained; new fitted perimeter panels and seated side enclosures.",
        "budget_note":"Completed railings raise this island's ceiling from 540k to 595k. The whole-family limit remains 3.5M."},triangle_limit=TRIANGLE_LIMIT)
    assert all(base.sha(ROOT/p)==h for p,h in hashes.items())
    manifest={"revision":"v15","island_id":3,"name":"Astral Observatory","source_checksums":hashes,
        "shared_paving":"res://assets3D/mind_spark/celestial_islands_v08/shared_paving.glb","variant":record}
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print("ASTRAL_V15_BUILT",json.dumps(record),flush=True)


if __name__=="__main__":main()
