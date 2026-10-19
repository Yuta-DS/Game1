"""Third-island celestial citadel: outboard turrets, flying ribs, crystal keel.

Separate reversible source, exact 3,000-part inventory, preserved game footprint.
Run with Blender --background --python-exit-code 1 --python this_file.py.
"""
import csv
import json
import math
import sys
from collections import Counter
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_verdant_island_v12 as sculpt
reference=sculpt.reference
base=sculpt.base
kit=sculpt.kit
ROOT=sculpt.ROOT
OUT=ROOT/"assets3D/mind_spark/celestial_astral_v13"
SOURCE=ROOT/"assets3D/mind_spark/celestial_islands_v11/source/island_03_3000.blend"
TAU=math.tau
group=sculpt.group


def lathe(name, center, profile, mat="ivory", sides=40, role="Architecture"):
    vertices=[(center[0]+r*math.cos(j*TAU/sides),center[1]+r*math.sin(j*TAU/sides),z)
        for z,r in profile for j in range(sides)]
    faces=[tuple(reversed(range(sides)))]
    for k in range(len(profile)-1):
        for j in range(sides):
            a=k*sides+j;b=k*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.append(tuple((len(profile)-1)*sides+j for j in range(sides)))
    obj=kit.mesh(name,vertices,faces,mat,role,smooth=True)
    for face in obj.data.polygons:
        if abs(face.normal.z)>.99:face.use_smooth=False
    return obj


def ring_at(name, center, radius, width, z, height, mat="gold", segments=64, role="Architecture"):
    obj=kit.ring(name,radius,width,z,height,mat,segments,role=role)
    obj.location=(center[0],center[1],0)
    return obj


def crystal_keel():
    group("07_Astral_Crystalline_Keel","Central faceted hanging keel")
    sculpt.solid("AstralKeel_Core",[(-.04,.08,-.66,.45,.39),(-.035,.08,-1.02,.31,.29),
        (.025,.09,-1.51,.18,.17),(.09,.10,-2.13,.018,.02)],sides=12)
    for j in range(22):
        a=TAU*j/22
        r=.255
        cx=-.02+r*math.cos(a);cy=.08+r*.88*math.sin(a)
        length=.78+.22*math.sin(j*1.9)**2
        top=-.77-.07*(j%3)
        rr=.070+.011*(j%4)
        sculpt.solid(f"AstralKeel_CrystalFlute_{j+1:02d}",
            [(cx,cy,top,rr,rr*.8),(cx*.77,cy*.8,top-length*.52,rr*.78,rr*.62),
             (cx*.55+.05,cy*.55,top-length,rr*.10,rr*.11)],
            material=("rock_light","rock","rock_shade")[j%3],sides=6,phase=a)
    group("07_Astral_Crystalline_Keel","Keel crown bearing bands")
    ring_at("KeelIvoryBearing",(0,.08),.315,.085,-1.20,.073,"ivory",64)
    ring_at("KeelBrassBearingReveal",(0,.08),.358,.012,-1.18,.026,"gold",64)
    ring_at("KeelLowerSocket",(.045,.085),.177,.043,-1.57,.062,"ivory",64)
    ring_at("KeelLowerSocketReveal",(.045,.085),.200,.009,-1.565,.022,"gold",64)


def rib(name, points, width=.07, depth=.11):
    """Rectangular curved masonry rib with separately modelled brass arris."""
    points=[Vector(p) for p in points]
    vertices=[]
    for i,p in enumerate(points):
        tangent=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
        across=Vector((0,1,0))
        normal=tangent.cross(across).normalized()
        for d,w in ((-1,-1),(-1,1),(1,1),(1,-1)):
            vertices.append(tuple(p+across*d*depth*.5+normal*w*width*.5))
    faces=[(3,2,1,0)]
    for k in range(len(points)-1):
        for j in range(4):
            a=k*4+j;b=k*4+(j+1)%4
            faces.append((a,b,b+4,a+4))
    n=(len(points)-1)*4;faces.append((n,n+1,n+2,n+3))
    kit.mesh(name,vertices,faces,"ivory",bevel=.002)
    kit.tube(name+"_BrassArris",[p+Vector((0,-depth*.515,0)) for p in points],.0055,"gold",sides=8)


def flying_buttresses():
    for side in (-1,1):
        # The fore/aft rib heads share one longitudinal bearing under each turret.
        # This prevents a front flying-rib tip from ending in unsupported air.
        group("08_Astral_Flying_Buttresses",f"{'West' if side<0 else 'East'} longitudinal turret bearing")
        kit.box("TurretLongitudinalBearing",(side*1.19,.04,-.43),(.22,.84,.080),"ivory",.007)
        kit.box("TurretBearingBrassWeb",(side*1.19-.115,.04,-.43),(.014,.77,.030),"gold",.002)
        for j,y in enumerate((-.31,.36)):
            group("08_Astral_Flying_Buttresses",f"{'West' if side<0 else 'East'} flying rib {j+1}")
            top=Vector((side*1.19,y,-.43))
            foot=Vector((side*.16,y*.22,-1.56))
            control=Vector((side*.95,y,-1.43))
            path=[(1-t)**2*foot+2*(1-t)*t*control+t*t*top for t in [k/28 for k in range(29)]]
            rib("SweepingIvoryLoadRib",path,.072,.11)
            kit.box("RibCrownBearing",top,(.24,.19,.064),"ivory",.006)
            kit.box("RibCrownBearingGold",top+Vector((0,0,-.038)),(.21,.17,.020),"gold",.003)
            kit.box("RibKeelSocket",foot,(.18,.12,.073),"gold",.006)
            # The upper secondary rib bears directly into the civic deck crown.
            branch=path[19]
            end=Vector((side*.94,y,-.080))
            control2=Vector((side*1.02,y,-.49))
            rib("SecondaryCrownRib",[(1-t)**2*branch+2*(1-t)*t*control2+t*t*end for t in [k/20 for k in range(21)]],.045,.080)
            for k in range(4):
                p=path[7+k*5]
                kit.box(f"RibCarvedBrassJoint_{k}",p+Vector((0,-.060,0)),(.047,.012,.024),"gold",.003)


def turret(label,x,y,dz):
    group("09_Outboard_Observation_Turrets",label)
    lathe(label+"_CorbelledFoot",(x,y),[(dz-.55,.14),(dz-.49,.19),(dz-.45,.255),
        (dz-.42,.255),(dz-.40,.208)],"ivory",48)
    lathe(label+"_RecessedEnamelDrum",(x,y),[(dz-.40,.163),(dz+.12,.163)],"blue",48)
    for k,z in enumerate((dz-.40,dz-.31,dz+.08,dz+.135)):
        ring_at(label+f"_IvoryStringCourse_{k}",(x,y),.188,.040,z,.036,"ivory",64)
        ring_at(label+f"_GoldCourseReveal_{k}",(x,y),.211,.009,z+.013,.011,"gold",64)
    # Twelve slender pilasters seat on the continuous base and crown cornice.
    for j in range(12):
        a=j*TAU/12
        p=Vector((x+.177*math.cos(a),y+.177*math.sin(a),dz-.14))
        kit.box(label+f"_IvoryPilaster_{j}",p,(.031,.031,.48),"ivory",.003,yaw=a)
        kit.box(label+f"_PilasterGiltInset_{j}",p+Vector((.017*math.cos(a),.017*math.sin(a),0)),(.008,.010,.33),"gold",.001,yaw=a)
        for k,zz in enumerate((dz-.365,dz+.080)):
            kit.box(label+f"_PilasterCapital_{j}_{k}",(p.x,p.y,zz),(.057,.052,.035),"ivory",.003,yaw=a)
        # Curved decorative arch between adjacent pilasters, not a flat sticker.
        aa=a+TAU/24
        r=.179
        local=[Vector((.041*math.cos(t),-.012,.048*math.sin(t))) for t in [k*math.pi/12 for k in range(13)]]
        rotation=Matrix.Rotation(aa+math.pi/2,4,"Z")
        at=Vector((x+r*math.cos(aa),y+r*math.sin(aa),dz+.014))
        kit.tube(label+f"_WindowArchReveal_{j}",[at+rotation@p for p in local],.004,"gold",sides=8)
    dome=[(dz+.145,.190),(dz+.19,.181),(dz+.235,.161),(dz+.280,.137),
        (dz+.325,.102),(dz+.367,.064),(dz+.405,.025),(dz+.432,.004)]
    lathe(label+"_CurvedAstralDome",(x,y),dome,"roof",48)
    for j in range(12):
        a=j*TAU/12
        kit.tube(label+f"_DomeSeam_{j}",[(x+(r+.002)*math.cos(a),y+(r+.002)*math.sin(a),z) for z,r in dome],.0035,"gold",sides=8)
    lathe(label+"_GildedFinial",(x,y),[(dz+.427,.010),(dz+.452,.020),(dz+.468,.010),(dz+.516,.002)],"gold",20)
    # A direct transfer beam embeds the outboard turret foot into the crown.
    side=1 if x>0 else -1
    group("08_Astral_Flying_Buttresses",label+" crown transfer")
    kit.box(label+"_IvoryTransferBeam",(side*.97,y,dz-.44),(.59,.26,.095),"ivory",.008)
    kit.box(label+"_BrassTransferWeb",(side*.97,y-.139,dz-.44),(.53,.016,.033),"gold",.003)


def power_core():
    group("10_Suspended_Astral_Power_Core","Three-cylinder suspended power engine")
    origin=Vector((0,-.43,-1.52))
    kit.box("AstralCore_IvoryLoadSill",origin,(.76,.39,.075),"ivory",.009,"Machinery")
    kit.box("AstralCore_BrassEngineBed",origin+Vector((0,0,.045)),(.69,.34,.022),"gold",.004,"Machinery")
    for j,x in enumerate((-.205,0,.205)):
        base.pressure_column(f"AstralCore_PressureCylinder_{j+1}",x,-.43,-1.43,.38,.066,"blue")
    base.exchanger("AstralCore_CoolingFins",0,-.535,-1.23,.125,.25)
    base.pipe("AstralCore_SteamHeader",[(-.30,-.43,-1.012),(.31,-.43,-1.012),(.31,-.30,-1.012),(.31,-.30,-.10)],.016,"gold")
    base.pipe("AstralCore_ReturnHeader",[(-.30,-.49,-1.47),(.31,-.49,-1.47),(.31,-.27,-1.47),(.31,-.27,-.11)],.012,"copper")
    for x in (-.205,0,.205):
        base.pipe("AstralCore_BranchConnection",[(x+.10,-.43,-.975),(x+.10,-.43,-1.012)],.010,"gold")
        base.pipe("AstralCore_ReturnConnection",[(x+.10,-.49,-1.47),(x+.10,-.49,-1.483)],.009,"copper")
    # Visible service skid is tied into the crystal collar, not suspended in air.
    for side in (-1,1):
        rib("AstralCore_SkidCorbel",[(side*.10,.02,-1.65),(side*.22,-.19,-1.59),(side*.30,-.43,-1.56)],.058,.083)
    for x in (-.35,.35):
        kit.tube("AstralCore_MountingStrap",[(x,-.43,-1.48),(x,-.43,-.77)],.012,"gold","Machinery",sides=12)
        kit.box("AstralCore_UpperShoe",(x,-.43,-.755),(.11,.11,.04),"gold",.005,"Machinery")


def finish(revision="v13", record_extra=None, triangle_limit=540000):
    bpy.context.view_layer.update()
    natural=len(base.PARTS)
    merges=reference.combine_to_budget(max_group_size=12)
    splits=base.subdivide_to_target()
    rows=[]
    for i,obj in enumerate(sorted(base.PARTS,key=lambda o:(o["category"],o["assembly"],o.name))):
        obj.data.transform(obj.matrix_world);obj.matrix_world=Matrix.Identity(4)
        center=sum((v.co for v in obj.data.vertices),Vector())/len(obj.data.vertices)
        obj.data.transform(Matrix.Translation(-center));obj.location=center
        previous=obj.name;identifier=f"MS{revision[1:]}-I03-P{i+1:04d}"
        obj.name=identifier+"_"+previous[-39:];obj["part_id"]=identifier;obj["island_id"]=3
        rows.append({"part_id":identifier,"name":previous,"role":obj["role"],"category":obj["category"],
            "assembly":obj["assembly"],"kind":obj["component_kind"],"triangles":len(obj.data.polygons),
            "source_component":obj.get("source_component",previous)})
    bpy.context.view_layer.update();reference.OUT=OUT
    triangles=reference.batch(2, triangle_limit=triangle_limit)
    bpy.context.preferences.filepaths.save_version=0
    pending=OUT/"staging/island_03_3000.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(pending),compress=True)
    pending.replace(OUT/"source/island_03_3000.blend")
    with (OUT/"bom/island_03_parts.csv").open("w",newline="") as stream:
        writer=csv.DictWriter(stream,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    record=json.loads((SOURCE.parent.parent/"island_03_record.json").read_text())
    record.update(revision=revision,silhouette="astral crown citadel with crystalline needle keel",runtime_triangles=triangles,
        natural_components=natural,related_fitting_merges=merges,surface_patch_splits=splits,
        component_kinds=dict(Counter(o["component_kind"] for o in base.PARTS)),
        observation_turrets=2,flying_buttresses=4,power_cylinders=3,
        gameplay_policy="Paving, collision and routes unchanged. Turrets are inaccessible outboard architecture, outside the walking disc and bridge corridors.")
    record.update(record_extra or {})
    (OUT/"island_03_record.json").write_text(json.dumps(record,indent=2)+"\n")
    return record


def main():
    for sub in ("source","bom","staging"):
        (OUT/sub).mkdir(parents=True,exist_ok=True);(OUT/sub/".gdignore").touch()
    sources=[SOURCE,SOURCE.parent.parent/"island_03.glb",ROOT/"assets3D/mind_spark/celestial_islands_v08/shared_paving.glb",
        ROOT/"assets3D/mind_spark/celestial_verdant_v12/island_02.glb"]
    hashes={str(p.relative_to(ROOT)):base.sha(p) for p in sources}
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    base.PARTS[:]=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    base.SCENE_COLLECTION=bpy.data.collections.new("ASTRAL_V13_ADDITIONS")
    bpy.context.scene.collection.children.link(base.SCENE_COLLECTION);base.COLLECTIONS.clear()
    kit.register=base.register;sculpt.RNG.seed(1303)
    kit.M={"ivory":bpy.data.materials["MSCT_ivory"],"gold":bpy.data.materials["MSCT_gold"],
        "copper":bpy.data.materials["MSCT_copper.002"],"rock":bpy.data.materials["MSCT_rock"],
        "rock_light":bpy.data.materials["MSCT_rock_light"],"rock_shade":bpy.data.materials["MSCT_rock_shade"],
        "opal":bpy.data.materials["MSCT_v6_energy"]}
    kit.M["blue"]=kit.newmat("AstralV13_DeepTealEnamel",(.13,.26,.29),.25)
    kit.M["roof"]=kit.newmat("AstralV13_PearlescentBlueRoof",(.33,.49,.53),.28)
    removed=sculpt.retain_upper_rock()
    crystal_keel();flying_buttresses()
    turret("WestAstralTurret",-1.27,.28,-.025)
    turret("EastAstralTurret",1.27,.28,.005)
    power_core()
    print("V13_PREPARED",len(base.PARTS),"replaced lower rock pieces",removed,flush=True)
    record=finish()
    assert all(base.sha(ROOT/p)==h for p,h in hashes.items()),"Baseline asset changed"
    manifest={"revision":"v13","island_id":3,"name":"Astral Observatory","source_checksums":hashes,
        "shared_paving":"res://assets3D/mind_spark/celestial_islands_v08/shared_paving.glb","variant":record}
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print("ASTRAL_V13_BUILT",json.dumps(record),flush=True)


if __name__=="__main__":main()
