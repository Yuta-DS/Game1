"""Audited third-island revision. Old assets are inputs only, never overwritten."""
import json
import math
import sys
from pathlib import Path
import bpy
import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_astral_enclosure_v15 as previous

astral, base, kit, reference = previous.astral, previous.base, previous.kit, previous.reference
ROOT = previous.ROOT
OUT = ROOT / "assets3D/mind_spark/celestial_astral_v16"
SOURCE = ROOT / "assets3D/mind_spark/celestial_astral_v15/source/island_03_3000.blend"
TAU = math.tau
group = astral.group
MOTION = {}


def remove(obj):
    base.PARTS.remove(obj)
    base.discard_object(obj)


def materials():
    # Consolidate genuinely equivalent materials before batching. Preserve the
    # source's colour variation in stone; do not atlas away authored detail.
    canonical = {}
    for obj in base.PARTS:
        for slot in obj.material_slots:
            mat = slot.material
            if not mat or not mat.use_nodes:
                continue
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            if not bsdf:
                continue
            key = tuple(tuple(s.default_value) if hasattr(s.default_value, "__len__") else s.default_value
                        for s in [bsdf.inputs[n] for n in ("Base Color", "Metallic", "Roughness", "Emission Color", "Emission Strength", "Transmission Weight")])
            canonical.setdefault(key, mat)
            slot.material = canonical[key]
    kit.M = {"ivory": bpy.data.materials["MSCT_ivory"], "gold": bpy.data.materials["MSCT_gold"],
             "copper": bpy.data.materials["MSCT_copper.002"], "blue": bpy.data.materials["AstralV13_DeepTealEnamel"],
             "opal": bpy.data.materials["MSCT_v6_energy"]}
    for key, rgb, metal, rough in [("ivory", (.83,.79,.69), .0,.56),
                                  ("gold", (.62,.44,.21), .72,.32),
                                  ("copper", (.42,.23,.12), .65,.4),
                                  ("blue", (.055,.145,.16), .22,.38)]:
        p = kit.M[key].node_tree.nodes.get("Principled BSDF")
        p.inputs["Base Color"].default_value = (*rgb,1)
        p.inputs["Metallic"].default_value = metal
        p.inputs["Roughness"].default_value = rough


def prepare():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    base.PARTS[:] = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    base.SCENE_COLLECTION = bpy.data.collections.new("ASTRAL_V16_REFINED_CONSTRUCTION")
    bpy.context.scene.collection.children.link(base.SCENE_COLLECTION)
    base.COLLECTIONS.clear()
    kit.register = base.register
    for obj in list(base.PARTS):
        category = obj.get("category", "")
        if category.startswith(("05_", "08_", "12_", "15_", "16_")):
            remove(obj)
        elif category == "14_Steam_And_Return_Network" and "engine closed" in obj["assembly"]:
            remove(obj)
        elif category == "09_Outboard_Observation_Turrets":
            # Turrets move aft of the side openings; the new bearings also move.
            obj.location.y += .29
    bpy.context.view_layer.update()
    for obj in base.PARTS:
        if obj.get("category") != "01_Rock_Profile":
            continue
        points = [obj.matrix_world @ v.co for v in obj.data.vertices]
        lo = [min(p[k] for p in points) for k in range(3)]
        hi = [max(p[k] for p in points) for k in range(3)]
        if hi[1] < -.38 or lo[1] > .49 or hi[2] < -1.45 or lo[2] > -.10:
            continue
        # Reserve the full machine bay, not just its decorative arch outline.
        if lo[0] > 0 and hi[0] > .48:
            obj.location.x -= hi[0] - .48
        elif hi[0] < 0 and lo[0] < -.48:
            obj.location.x += -.48 - lo[0]
    for obj in base.PARTS:
        if obj.get("category") != "04_Reference_Enginehouses":
            continue
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.dissolve_limit(bm,angle_limit=math.radians(.5),verts=list(bm.verts),edges=list(bm.edges),delimit={"MATERIAL","NORMAL"})
        bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
        if len(obj.data.polygons)>800:
            bpy.context.view_layer.objects.active=obj
            mod=obj.modifiers.new("V16_Detail_LOD","DECIMATE")
            mod.ratio=.82;mod.use_collapse_triangulate=True
            bpy.ops.object.modifier_apply(modifier=mod.name)
    cut_core_recesses()
    materials()


def cut_core_recesses():
    """Recess intact rock patches without booleaning their open boundaries.

    The inherited 3,000-part source includes surface patches, not just closed
    volumes. Boolean difference on those patches can invert a cut or create
    cutter-shaped faces. Affine fitting preserves their exact topology and is
    idempotent: a fitted patch is never cut or compressed again.
    """
    bpy.context.view_layer.update()
    for obj in base.PARTS:
        if obj.get("category")!="01_Rock_Profile" or obj.get("rock_recess_revision")==2:continue
        points=[obj.matrix_world@v.co for v in obj.data.vertices]
        lo=[min(p[k] for p in points) for k in range(3)]
        hi=[max(p[k] for p in points) for k in range(3)]
        if hi[1]<-.41 or lo[1]>.49 or hi[2]<-1.50 or lo[2]>-.075:continue
        if lo[0]>=0:
            obj.location.x-=max(0,hi[0]-.475)
        elif hi[0]<=0:
            obj.location.x+=max(0,-.475-lo[0])
        else:
            factor=min(1,.475/max(abs(lo[0]),abs(hi[0])))
            obj.data.transform(obj.matrix_world.inverted()@Matrix.Diagonal((factor,1,1,1))@obj.matrix_world)
        obj["rock_recess_revision"]=2


def restore_rock_patches():
    """Discard only failed v16 rock cuts; recover the untouched v15 topology."""
    old_names=[o.name for o in base.PARTS if o.get("category")=="01_Rock_Profile"]
    with bpy.data.libraries.load(str(SOURCE),link=False) as (available,loaded):
        loaded.objects=[name for name in available.objects if "SculptedRock.002_Block_" in name]
    restored=[o for o in loaded.objects if o and o.get("category")=="01_Rock_Profile"]
    assert restored and len(restored)>200
    for name in old_names:remove(bpy.data.objects[name])
    for obj in restored:
        bpy.context.scene.collection.objects.link(obj)
        base.PARTS.append(obj)
    cut_core_recesses()


def bay(side):
    label = "West" if side < 0 else "East"
    def p(u,z,d=0): return (side*(.84+d), .04+u, z)
    group("16_Integrated_Engine_Chambers", label+" masonry frame")
    kit.box(label+"LoadSill", (side*.73,.04,-1.469), (.43,.91,.042), "ivory", .006)
    for u in (-.375,.375):
        for j in range(5):
            kit.box(label+"PierCourse",p(u,-1.367+j*.163),(.095,.078,.163),"ivory",.002)
        kit.box(label+"PierFoot",p(u,-1.436),(.13,.12,.04),"ivory",.004)
        kit.box(label+"SpringingCapital",p(u,-.615),(.13,.13,.04),"ivory",.004)
        kit.tube(label+"GiltFlute",[p(u,z,.049) for z in (-1.40,-.67)],.0025,"gold",sides=10)
    kit.arch(label+"SeatedArch",p(0,-.615),.335,.425,.052,.11,
             math.pi/2 if side>0 else -math.pi/2,23)
    # A clean inner wall follows the arch instead of filling the whole silhouette.
    outline=[(-.331,-1.442),(.331,-1.442),(.331,-.615)]
    outline.extend((.331*math.cos(j*math.pi/32),-.615+.421*math.sin(j*math.pi/32)) for j in range(1,33))
    n=len(outline)
    vs=[p(u,z,d) for d in (-.34,-.31) for u,z in outline]
    fs=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]
    fs.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    kit.mesh(label+"ArchedEnamelRecess",vs,fs,"blue")
    # Three narrow keyed courses bridge the arch crown to the existing cornice.
    for z,w in ((-.142,.20),(-.106,.25),(-.074,.30)):
        kit.box(label+"CrownKey",p(0,z),(.12,w,.034),"ivory",.004)
    group("16_Integrated_Engine_Chambers", label+" ventilator")
    for j in range(10):
        kit.box(label+"Louver",p(0,-.55+j*.029,-.075),(.048,.31,.012),"copper",.002)
    for u in (-.17,.17):
        kit.box(label+"VentJamb",p(u,-.42,-.072),(.05,.02,.32),"gold",.002)
    group("08_Resolved_Load_Path",label+" deck and turret cradle")
    # One fore and one aft curved rib; the aft bearing is outside the arch bay.
    for y,topx,topz in ((-.43,.95,-.08),(.61,1.27,-.465)):
        foot=Vector((.045+side*.17,.085,-1.57))
        top=Vector((side*topx,y,topz))
        control=Vector((side*.86,y,-1.26))
        path=[(1-t)**2*foot+2*(1-t)*t*control+t*t*top for t in [i/48 for i in range(49)]]
        astral.rib(label+"SweptBearing",path,.059,.09)
        kit.box(label+"BearingShoe",top,(.16,.16,.046),"ivory",.005)
    kit.box(label+"AftTurretBearer",(side*1.05,.59,-.454),(.53,.25,.066),"ivory",.007)
    kit.box(label+"AftTurretGiltWeb",(side*1.05,.455,-.454),(.46,.018,.028),"gold",.002)
    for u in (-.30,.30):
        kit.tube(label+"SillCorbel",[(.045+side*.17,.085,-1.57),p(u,-1.49)],.021,"ivory",sides=16)


def motion_group(name, center):
    group("12_Operational_Engine",name)
    MOTION[name]=center


def widen_bays():
    # Positive running clearance between the pinion envelope and the masonry.
    transform=Matrix.Translation((0,.04,0))@Matrix.Diagonal((1,1.05,1,1))@Matrix.Translation((0,-.04,0))
    for obj in base.PARTS:
        if obj.get("category")=="16_Integrated_Engine_Chambers":
            obj.data.transform(obj.matrix_world.inverted()@transform@obj.matrix_world)


def gear(name,center,radius,teeth,phase=0):
    # Matched module and tooth pitch, with clearance at both root and tip.
    depth=.024
    profile=[]
    for i in range(teeth):
        for f,r in ((-.5,radius-.010),(-.30,radius-.010),(-.18,radius+.008),(.18,radius+.008),(.30,radius-.010)):
            a=(i+f)*TAU/teeth+phase
            profile.append((r*math.cos(a),r*math.sin(a)))
    n=len(profile)
    vs=[(x,y,z) for x in (-depth/2,depth/2) for y,z in profile]
    if radius>.1:
        # Open spokes make the flywheel's drive and rotation readable.
        vs.extend((x,.076*math.cos((i+f)*TAU/teeth+phase),.076*math.sin((i+f)*TAU/teeth+phase))
                  for x in (-depth/2,depth/2) for i in range(teeth) for f in (-.5,-.30,-.18,.18,.30))
        fs=[]
        for j in range(n):
            k=(j+1)%n
            fs.extend(((j,k,n+k,n+j),(j,2*n+j,2*n+k,k),
                       (n+j,n+k,3*n+k,3*n+j),(2*n+j,3*n+j,3*n+k,2*n+k)))
    else:
        fs=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]
        fs.extend((j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n))
    obj=kit.mesh(name+"ToothedWeb",vs,fs,"gold","Machinery",.001)
    obj.location=center
    if radius>.1:
        for i in range(8):
            a=i*TAU/8
            obj=kit.box(name+"Spoke",(0,0,0),(.025,.092,.018),"ivory",.002,"Machinery")
            obj.matrix_world=Matrix.Translation(Vector(center)+Vector((0,.050*math.cos(a),.050*math.sin(a))))@Matrix.Rotation(a,4,"X")
    for rr in (radius*.66,radius*.87):
        obj=kit.ring(name+"Rim",rr,.006,0,.034,"copper",64,role="Machinery")
        obj.matrix_world=Matrix.Translation(Vector(center)) @ Matrix.Rotation(math.pi/2,4,"Y")
    base.cylinder(name+"Hub",center,.032,.040,"ivory",32,"X")
    for i in range(teeth//2):
        a=i*TAU/(teeth//2)
        base.cylinder(name+"WebBolt",Vector(center)+Vector((.024,radius*.76*math.cos(a),radius*.76*math.sin(a))),.004,.009,"ivory",8,"X")


def engine(side):
    label="West" if side<0 else "East"
    group("12_Operational_Engine",label+" fixed cylinder and transmission")
    kit.box(label+"EngineSkid",(side*.70,.08,-1.445),(.32,.61,.030),"ivory",.006,"Machinery")
    astral.lathe(label+"PressureCylinder",(side*.65,.04),[(-1.04,.062),(-1.01,.083),(-.78,.083),(-.747,.058)],"blue",48,"Machinery")
    for z in (-1.016,-.89,-.765):
        base.cylinder(label+"CylinderBand",(side*.65,.04,z),.087,.014,"gold",48)
    for y in (-.09,.17):
        kit.tube(label+"CylinderStay",[(side*.65,y,-1.429),(side*.65,y,-.735)],.010,"gold","Machinery",16)
    kit.box(label+"GlassFrame",(side*.74,.04,-.89),(.014,.04,.19),"gold",.002,"Machinery")
    kit.box(label+"SightGlass",(side*.749,.04,-.89),(.005,.025,.16),"opal",.001,"Machinery")
    for y in (.04,.28):
        base.cylinder(label+"Shaft",(side*.72,y,-1.26),.020,.28,"copper",32,"X")
        kit.box(label+"Pedestal",(side*.70,y,-1.36),(.13,.085,.17),"ivory",.006,"Machinery")
        base.cylinder(label+"Bearing",(side*.775,y,-1.26),.035,.05,"gold",32,"X")
    # Pinion shaft ends in an enclosed generator; cable terminates at the lift collar.
    base.cylinder(label+"Generator",(side*.59,.28,-1.26),.073,.23,"blue",40,"X")
    for x in (.49,.53,.57,.61,.65,.69):
        base.cylinder(label+"GeneratorFin",(side*x,.28,-1.26),.078,.009,"gold",32,"X")
    previous.prior.pipe(label+"PowerConduit",[(side*.48,.28,-1.26),(side*.35,.28,-1.26),(.045+side*.17,.085,-1.57)],.016,"copper")
    for y,z in ((-.015,-.775),(.095,-1.014)):
        previous.prior.pipe(label+"SteamRiser",[(side*.65,y,z),(side*.45,y,z),(side*.45,y,-.66)],.012,"gold" if z>-.9 else "copper")
    motion_group(label+"Flywheel",(side*.84,.04,-1.26))
    gear(label+"Flywheel",MOTION[label+"Flywheel"],.15,20,math.pi/20)
    base.cylinder(label+"CrankPin",(side*.88,.04,-1.205),.015,.055,"gold",24,"X")
    motion_group(label+"Pinion",(side*.84,.28,-1.26))
    gear(label+"Pinion",MOTION[label+"Pinion"],.09,12)
    motion_group(label+"ConnectingRod",(side*.88,.04,-1.1025))
    base.cylinder(label+"ConnectingRod",MOTION[label+"ConnectingRod"],.010,.205,"ivory",24)
    motion_group(label+"Crosshead",(side*.88,.04,-1.0))
    kit.box(label+"Crosshead",MOTION[label+"Crosshead"],(.08,.04,.028),"gold",.002,"Machinery")
    kit.tube(label+"PistonRod",[(side*.65,.04,-1.0),(side*.65,.04,-.90)],.009,"gold","Machinery",16)
    kit.tube(label+"CrossheadArm",[(side*.65,.04,-1.0),(side*.88,.04,-1.0)],.012,"ivory","Machinery",16)


def barriers():
    radius=173.7
    half=math.asin(22.5/radius)
    blocked=sorted((math.atan2(d.y,d.x)%TAU-half,math.atan2(d.y,d.x)%TAU+half) for d in reference.directions(2))
    spans=[(0,blocked[0][0]),(blocked[0][1],blocked[1][0]),(blocked[1][1],TAU)]
    panels=[]
    def p(a,h,r=radius):return (r*math.cos(a)/175,r*math.sin(a)/175,h/175)
    for lo,hi in spans:
        n=math.ceil((hi-lo)*radius/5.0)
        for j in range(n):
            a,b=lo+(hi-lo)*j/n,lo+(hi-lo)*(j+1)/n
            panels.append([a,b])
            group("05_Player_Scale_Balustrade",f"Reusable five metre panel {len(panels):03d}")
            for h,r in ((.28,.033),(1.36,.045)):
                kit.tube("ChampagneHandrail",[p(a+(b-a)*k/4,h) for k in range(5)],r/175,"gold","Railing",8)
            for f in (.25,.5,.75):
                aa=a+(b-a)*f
                kit.tube("SlenderPicket",[p(aa,.28),p(aa,1.36)],.025/175,"gold","Railing",8)
            # A small pointed quatrefoil is readable at player distance.
            m=(a+b)/2
            kit.tube("DiamondMedallion",[p(m,.48),p(m+.30/radius,.82),p(m,1.16),p(m-.30/radius,.82),p(m,.48)],.022/175,"gold","Railing",8)
            for aa in ([a,b] if j==n-1 else [a]):
                kit.box("IvoryPier",p(aa,.70),(.28/175,.28/175,1.40/175),"ivory",.025/175,"Railing",aa)
                kit.box("GiltCapital",p(aa,1.44),(.40/175,.40/175,.08/175),"gold",.02/175,"Railing",aa)
            if j%5==2:
                kit.tube("PromenadeLampStem",[p(m,0),p(m,2.6)],.055/175,"gold","Railing",12)
                kit.box("WarmOpalLantern",p(m,2.78),(.24/175,.24/175,.46/175),"opal",.035/175,"Railing",m)
                kit.box("LanternCap",p(m,3.05),(.38/175,.38/175,.10/175),"gold",.025/175,"Railing",m)
    return {"radius_m":radius,"height_m":1.40,"collision_height_m":1.48,"panel_angles":panels,"bridge_half_width_m":22.0}


def batch(index,triangle_limit=540000):
    temporary=bpy.data.collections.new("_ExportOnly")
    bpy.context.scene.collection.children.link(temporary)
    output=[]
    for role in reference.ROLES+list(MOTION):
        moving=role in MOTION
        members=[o for o in base.PARTS if (o["assembly"]==role if moving else o["role"]==role and o["assembly"] not in MOTION)]
        copies=[]
        for obj in members:
            copy=obj.copy();copy.data=obj.data.copy();temporary.objects.link(copy);copies.append(copy)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in copies:obj.select_set(True)
        bpy.context.view_layer.objects.active=copies[0]
        if len(copies)>1:bpy.ops.object.join()
        merged=bpy.context.view_layer.objects.active
        merged.data.transform(merged.matrix_world);merged.matrix_world=Matrix.Identity(4)
        merged.name=(role+"_v16") if moving else f"{role}_v11_03"
        for key in list(merged.keys()):del merged[key]
        merged["role"]="Machinery" if moving else role
        if moving:
            center=Vector(MOTION[role]);merged.data.transform(Matrix.Translation(-center));merged.location=center
            merged["mechanism"]=role
        bpy.ops.object.material_slot_remove_unused();output.append(merged)
    bpy.context.view_layer.update()
    triangles=sum(len(o.data.polygons) for o in output)
    assert triangles<triangle_limit,triangles
    kit.export_parts(output,OUT/"island_03.glb")
    for obj in output:base.discard_object(obj)
    bpy.data.collections.remove(temporary)
    return triangles


def main():
    for sub in ("source","bom","staging"):
        (OUT/sub).mkdir(parents=True,exist_ok=True);(OUT/sub/".gdignore").touch()
    old_hash=base.sha(SOURCE)
    prepare()
    bay(-1);bay(1);engine(-1);engine(1)
    bpy.context.view_layer.update();widen_bays()
    rail=barriers()
    for obj in base.PARTS:
        if obj.get("role")=="Railing" and len(obj.data.polygons)>40:
            bpy.context.view_layer.objects.active=obj
            mod=obj.modifiers.new("RailingMicroBevelBudget","DECIMATE")
            mod.ratio=.48;mod.use_collapse_triangulate=True
            bpy.ops.object.modifier_apply(modifier=mod.name)
    materials()
    # Keep animated assemblies separate from fittings when grouping for authoring.
    reference.batch=batch
    astral.OUT=OUT;astral.SOURCE=SOURCE
    record=astral.finish("v16",{"runtime_meshes":13,"enclosed_side_bays":2,
        "source_preservation":"v15 retained on disk; side bays, supports and rails redesigned in v16.",
        "barrier":rail,"moving_assemblies":list(MOTION),"runtime_triangle_limit":540000,"bay_width_factor":1.05,
        "machinery_simulation":"Kinematic piston, connecting rod and matched 20:12 gear pair; fictional generator supplies lift collar.",
        "gameplay_policy":"Original island radius, bridges and quests retained; player-scale collision-backed perimeter added."})
    for key in ("new_panel_intervals","bridge_opening_intervals","rail_post_connectors","fitted_panel_count",
                "retained_railing_groups","omitted_railing_groups","new_enclosure_triangles","budget_note",
                "new_underside_components","new_underside_triangles"):
        record.pop(key,None)
    (OUT/"island_03_record.json").write_text(json.dumps(record,indent=2)+"\n")
    (OUT/"barriers.json").write_text(json.dumps(rail,indent=2)+"\n")
    (OUT/"manifest.json").write_text(json.dumps({"revision":"v16","island_id":3,"variant":record,"source_sha256":old_hash},indent=2)+"\n")
    assert base.sha(SOURCE)==old_hash
    print("ASTRAL_V16_BUILT",json.dumps({k:v for k,v in record.items() if k not in ("barrier","new_panel_intervals")}),flush=True)


def refine_saved():
    """Small source corrections without redoing the expensive assembly grouping."""
    manifest=json.loads((OUT/"manifest.json").read_text())
    record=manifest["variant"]
    bpy.ops.wm.open_mainfile(filepath=str(OUT/"source/island_03_3000.blend"))
    base.PARTS[:]=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    base.SCENE_COLLECTION=bpy.data.collections.new("V16_Final_Fit")
    bpy.context.scene.collection.children.link(base.SCENE_COLLECTION)
    base.COLLECTIONS.clear();kit.register=base.register
    materials()
    for obj in base.PARTS:
        if "PierCourse" not in obj.name:continue
        # Each of the twenty courses is still an independent mesh.
        world=[obj.matrix_world@v.co for v in obj.data.vertices]
        if max(v.z for v in world)-min(v.z for v in world)>.16:continue
        old=(min(v.z for v in world)+max(v.z for v in world))*.5
        j=round((old+1.37)/.158)
        new=-1.367+j*.163
        inv=obj.matrix_world.inverted()
        for vertex,p in zip(obj.data.vertices,world):
            p.z=new+(p.z-old)*(.163/.155);vertex.co=inv@p
    if "--restore-rock" in sys.argv:restore_rock_patches()
    else:cut_core_recesses()
    if record.get("bay_width_factor",1)<1.05:
        bpy.context.view_layer.update();widen_bays()
        record["bay_width_factor"]=1.05
    for side,label in ((-1,"West"),(1,"East")):
        for part,center in (("Flywheel",(side*.84,.04,-1.26)),("Pinion",(side*.84,.28,-1.26)),
                            ("ConnectingRod",(side*.88,.04,-1.1025)),("Crosshead",(side*.88,.04,-1.0))):
            MOTION[label+part]=center
        for obj in list(base.PARTS):
            if obj["assembly"]==label+"Flywheel":remove(obj)
        motion_group(label+"Flywheel",MOTION[label+"Flywheel"])
        gear(label+"Flywheel",MOTION[label+"Flywheel"],.15,20,math.pi/20)
        base.cylinder(label+"CrankPin",(side*.88,.04,-1.205),.015,.055,"gold",24,"X")
    reference.batch=batch;astral.OUT=OUT;astral.SOURCE=OUT/"source/island_03_3000.blend"
    # finish reads the current record, preserving the geometry-derived barrier data.
    updated=astral.finish("v16",{k:v for k,v in record.items() if k not in ("runtime_triangles","natural_components","related_fitting_merges","surface_patch_splits","component_kinds")})
    manifest["variant"]=updated
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print("ASTRAL_V16_FIT_FINISHED",updated["runtime_triangles"],flush=True)


def sanitize_saved():
    manifest=json.loads((OUT/"manifest.json").read_text());record=manifest["variant"]
    bpy.ops.wm.open_mainfile(filepath=str(OUT/"source/island_03_3000.blend"))
    base.PARTS[:]=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    for obj in base.PARTS:
        if obj.get("category")!="01_Rock_Profile":continue
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-8)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
        obj.data.validate()
    for side,label in ((-1,"West"),(1,"East")):
        for part,center in (("Flywheel",(side*.84,.04,-1.26)),("Pinion",(side*.84,.28,-1.26)),
                            ("ConnectingRod",(side*.88,.04,-1.1025)),("Crosshead",(side*.88,.04,-1.0))):
            MOTION[label+part]=center
    reference.batch=batch;astral.OUT=OUT;astral.SOURCE=OUT/"source/island_03_3000.blend"
    updated=astral.finish("v16",{k:v for k,v in record.items() if k not in ("runtime_triangles","natural_components","related_fitting_merges","surface_patch_splits","component_kinds")})
    manifest["variant"]=updated
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print("ASTRAL_V16_CLEAN",updated["runtime_triangles"],flush=True)


if __name__=="__main__":
    if "--sanitize-only" in sys.argv:sanitize_saved()
    elif "--refine-saved" in sys.argv:refine_saved()
    else:main()
