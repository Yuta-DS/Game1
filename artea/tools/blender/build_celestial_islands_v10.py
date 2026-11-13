"""V10: load-bearing perimeter steam engines and articulated levitation cradles.

Preserves all previous assets. Source: 3,000 real editable mesh parts per island;
runtime: four static material-role batches plus independently moving assemblies.
The lift field is fictional. Rotors/pistons are visual machinery, not a physics solver.
"""
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_celestial_islands_v09 as base

kit = base.kit
OUT = base.ROOT / "assets3D/mind_spark/celestial_islands_v10"
COUNTS = [4, 6, 5, 4, 8, 6]
SCALES = [1.27, 1.10, 1.18, 1.35, 1.00, 1.13]
DEPTHS = [-1.05, -1.04, -1.06, -1.17, -1.02, -1.10]
MOTION = ""
ROOTS = {}
POWER_LINKS = []
RUNTIME = {}


def register(obj, role):
    base.register(obj, role)
    if MOTION:
        obj["motion_id"] = MOTION
    return obj


def group(category, assembly):
    base.GROUP = category
    base.ASSEMBLY = assembly


def transform_new(start, matrix):
    bpy.context.view_layer.update()
    for obj in base.PARTS[start:]:
        obj.matrix_world = matrix @ obj.matrix_world


def axis_ring(name, center, radius, width, depth, mat="gold", axis="Z"):
    obj = kit.ring(name, radius, width, 0, depth, mat, 96, role="Machinery")
    obj.location = center
    if axis == "Y":
        obj.rotation_euler.x = math.pi / 2
    return obj


def gear(label, radius, teeth, center, root_matrix, phase=0):
    """Open-spoke gear with individual bevelled teeth; matching module for pairs."""
    global MOTION
    MOTION = label
    start = len(base.PARTS)
    module = 2 * radius / teeth
    rim_radius = radius - module * 1.25
    axis_ring("MachinedToothRootRim", (0, 0, 0), rim_radius-.009, .024, .033, "gold")
    for zz in (-.022, .022):
        axis_ring("TurnedCopperRimReveal", (0, 0, zz), rim_radius-.020, .010, .008, "copper")
    base.cylinder("KeyedAxleHub", (0, 0, 0), radius*.20, .072, "gold", 32)
    base.cylinder("IvoryHubCap", (0, 0, .045), radius*.155, .018, "ivory", 32)
    for j in range(8 if teeth >= 32 else 6):
        a = j * math.tau / (8 if teeth >= 32 else 6)
        kit.box("RadialFlywheelSpoke", (radius*.50*math.cos(a), radius*.50*math.sin(a), 0),
                (radius*.72, .019 if teeth >= 32 else .013, .025), "ivory", .004, "Machinery", a)
        base.cylinder("SpokeRimFastener", ((rim_radius-.024)*math.cos(a),
            (rim_radius-.024)*math.sin(a), .025), .006, .012, "copper", 8)
    for j in range(teeth):
        a = j * math.tau / teeth + phase
        # Tapered addendum and root, with small bevels on real triangular faces.
        polar = [(radius-module*1.32, a-.34*math.tau/teeth),
                 (radius+module*.92, a-.17*math.tau/teeth),
                 (radius+module*.92, a+.17*math.tau/teeth),
                 (radius-module*1.32, a+.34*math.tau/teeth)]
        vertices = [(r*math.cos(t), r*math.sin(t), z) for z in (-.016, .016) for r,t in polar]
        faces = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
        kit.mesh(f"GearTooth_{j+1:03d}", vertices, faces, "gold", "Machinery", .0008)
    matrix = root_matrix @ Matrix.Translation(Vector(center))
    transform_new(start, matrix)
    ROOTS[label] = matrix
    MOTION = ""


def engine_pod(index, j, angle):
    global MOTION
    label = f"Perimeter_Engine_{j+1:02d}"
    group("04_Engine_Assemblies", label)
    start = len(base.PARTS)
    yaw = angle + math.pi/2
    scale = SCALES[index]
    matrix = Matrix.Translation(Vector(kit.radial_point(1.09,angle,DEPTHS[index]))) @ Matrix.Rotation(yaw,4,"Z") @ Matrix.Scale(scale,4)
    prior = set(ROOTS)
    enamel = "blue" if index in (0,2) else "sage"
    kit.box("MassiveCarvedEngineSaddle",(0,0,-.036),(.81,.49,.080),"ivory",.016,"Architecture")
    kit.box("CastBronzeBedplate",(0,0,.018),(.77,.44,.030),"gold",.007,"Machinery")
    for x in (-.35,.35):
        for y in (-.17,.17):
            base.cylinder("SaddleAnchorBolt",(x,y,.043),.014,.026,"copper",8)
    # Boiler rather than a cabinet: shell, jacket bands, dished ends, valves,
    # level glass, riveted flanges and exposed steam/condensate ports.
    base.pressure_column("TallRivetedBoiler",.23,.055,.093,.49,.103,enamel)
    for x in (-.31,.02):
        kit.box("IvoryAxleBearingPedestal",(x,-.06,.155),(.085,.15,.235),"ivory",.008,"Machinery")
        base.cylinder("BronzeAxleBearing",(x,-.14,.275),.048,.15,"gold",32,"Y")
        base.cylinder("SteelTransmissionAxle",(x,-.19,.275),.018,.24,"copper",24,"Y")
    # 32:16 pair: equal module, centre distance = .22 + .11.
    vertical = Matrix.Rotation(math.pi/2,4,"X")
    # Gear local plane is XY, so translate before orienting.
    gear(f"V10Rotor_Drive_{j+1:02d}",.22,32,(0,0,0),Matrix.Translation(Vector((-.31,-.272,.275))) @ vertical)
    gear(f"V10Rotor_Pinion_{j+1:02d}",.11,16,(0,0,0),Matrix.Translation(Vector((.02,-.272,.275))) @ vertical,math.pi/16)
    # A guided crosshead is an editable moving assembly. Cylinder encloses
    # piston stroke; no decorative rod hangs unsupported in space.
    base.cylinder("SteamPowerCylinder",(-.31,.095,.495),.058,.19,"copper",32)
    for zz in (.395,.595):
        base.cylinder("PowerCylinderFlange",(-.31,.095,zz),.071,.018,"gold",32)
    for dx in (-.063,.063):
        base.pipe("CrossheadGuideRail",[(-.31+dx,.095,.06),(-.31+dx,.095,.60)],.009,"gold")
    MOTION=f"V10Piston_{j+1:02d}"
    piston_start=len(base.PARTS)
    base.cylinder("ReciprocatingPistonRod",(0,0,.05),.012,.23,"gold",24)
    kit.box("GuidedCrosshead",(0,0,-.015),(.15,.05,.035),"ivory",.004,"Machinery")
    piston_matrix=Matrix.Translation(Vector((-.31,.095,.295)))
    transform_new(piston_start,piston_matrix)
    ROOTS[MOTION]=piston_matrix
    MOTION=""
    # Steam distribution touches the actual vessel/header and cylinder ports.
    base.pipe("MainSteamDelivery",[(.33,.055,.638),(.38,.055,.638),(.38,.095,.68),(-.31,.095,.68),(-.31,.095,.60)],.021,"gold")
    base.pipe("CondensateReturn",[(-.31,.095,.405),(-.41,.095,.405),(-.41,.12,.04),(.33,.12,.04),(.33,-.005,.053)],.014,"copper")
    base.exchanger("ReturnWaterCooler",.11,.205,.29,.16,.29)
    base.pipe("CoolerFeed",[(.19,.205,.435),(.23,.20,.48),(.23,.055,.48)],.012,"copper")
    base.pipe("CoolerDrain",[(.03,.205,.145),(.03,.12,.04)],.012,"copper")
    # A squared mechanical transfer casing links the pinion axle to the
    # circumferential power bus at the saddle, not an unrelated floating gear.
    base.pipe("EnclosedBevelTransferShaft",[(.02,-.06,.275),(.02,.16,.275),(.02,.16,-.13)],.027,"gold")
    base.cylinder("TransferGearbox",(.02,.16,.275),.062,.10,"ivory",32,"Y")
    for side in (-1,1):
        kit.box("CantedEngineFrame",(side*.405,.055,.33),(.035,.11,.62),"ivory",.007,"Architecture")
        kit.box("FrameGiltInlay",(side*.405,-.005,.33),(.011,.007,.48),"gold",.001,"Inlay")
    kit.arch("CurvedEngineCrown",(0,.055,.64),.405,.095,.035,.105,blocks=9)
    # Leave the gears exposed; a partial stationary guard protects their top.
    guard_start=len(base.PARTS)
    guard=kit.ring("FlywheelCrescentGuard",.247,.017,0,.020,"ivory",40,.10,math.pi-.10,"Architecture")
    guard.matrix_world=Matrix.Translation(Vector((-.31,-.269,.275))) @ vertical
    bpy.context.view_layer.update()
    transform_new(start,matrix)
    for key in set(ROOTS)-prior:
        ROOTS[key]=matrix@ROOTS[key]
    # Load path: original deck -> twin upper columns -> engine bed -> inner
    # compression cradle. Every console overlaps a bearing shoe at each end.
    group("05_Load_Bearing_Cradle",label+"_StructuralConnections")
    for side in (-1,1):
        foot=matrix@Vector((side*.32,.05,-.072))
        top=Vector((foot.x*.78,foot.y*.78,-.115))
        inner=Vector((foot.x*.57,foot.y*.57,DEPTHS[index]-.30))
        base.pipe("IvoryDeckLoadColumn",[top,foot],.041,"ivory")
        base.pipe("GoldColumnFluting",[top+Vector((.012,0,0)),foot+Vector((.012,0,0))],.008,"gold")
        base.pipe("DeepTriangulatedLoadStrut",[foot,inner],.049,"ivory")
        base.cylinder("SaddleLoadShoe",foot,.063,.035,"gold",32)
        base.cylinder("CradleLoadShoe",inner,.065,.04,"gold",32)
    port=matrix@Vector((.38,.095,.68))
    deck_port=Vector((port.x*.72,port.y*.72,-.14))
    base.pipe("DeckPowerRiser",[port,Vector((deck_port.x,deck_port.y,port.z)),deck_port],.017,"gold")
    transmission=matrix@Vector((.02,.16,-.13))
    bus=Vector(kit.radial_point(.94,angle,DEPTHS[index]-.13*scale))
    base.pipe("GeneratorBusConnection",[transmission,bus],.027,"copper")
    POWER_LINKS.append({"engine":j+1,"angle_radians":angle,"scale":scale,
        "boiler_height":.49*scale,"flywheel_diameter":.44*scale,
        "steam_source":list(port),"deck_connection":list(deck_port),
        "generator_connection":list(bus),"gear_ratio":"32:16, counter-rotating 1:2"})


def additions(index):
    global MOTION
    ROOTS.clear();POWER_LINKS.clear();RUNTIME.clear();MOTION=""
    # Keep the heavenly palette, with restrained sage/blue lift lenses.
    kit.M["opal"].node_tree.nodes.get("Principled BSDF").inputs["Emission Strength"].default_value=.6
    group("03_Civic_Frieze","Ivory power-bearing entablature")
    for j in range(24):
        a=j*math.tau/24
        start=len(base.PARTS)
        kit.box("RecessedBrassRimPanel",(0,0,0),(.225,.044,.073),"gold",.006)
        kit.box("IvoryRimPanelInset",(0,-.025,0),(.20,.011,.052),"ivory",.004)
        for k in (-1,0,1):
            kit.box("CivicPanelVent",(k*.048,-.033,0),(.012,.008,.032),"sage",.002)
        transform_new(start,Matrix.Translation(Vector(kit.radial_point(1.016,a,-.09))) @ Matrix.Rotation(a+math.pi/2,4,"Z"))
    for j in range(COUNTS[index]):
        engine_pod(index,j,j*math.tau/COUNTS[index]+.18)
    group("05_Load_Bearing_Cradle","Continuous structural and power transfer rings")
    z=DEPTHS[index]-.13*SCALES[index]
    for rr,zz,width,height,mat in ((.94,z,.10,.075,"ivory"),(.94,z+.047,.07,.019,"gold"),
            (.72,DEPTHS[index]-.30,.16,.09,"ivory"),(.72,DEPTHS[index]-.355,.12,.023,"gold"),
            (.99,-.155,.10,.075,"ivory")):
        kit.ring("FoundationBearingRing",rr,width,zz,height,mat,128)
    for zz in (z+.075,z-.06):
        kit.ring("ContinuousCopperPowerBus",.94,.021,zz,.021,"copper",160,role="Machinery")
    # Main gear is an open annulus, leaving the original suspended rock intact.
    group("06_Levitation_Generator","Annular lift-field generator")
    MOTION="V10Rotor_MainRing"
    start=len(base.PARTS)
    ring_z=DEPTHS[index]-.43
    kit.ring("RotatingGeneratorAnnulus",1.03,.08,0,.048,"gold",160,role="Machinery")
    for j in range(72):
        a=j*math.tau/72
        kit.box("AnnularGeneratorTooth",kit.radial_point(1.079,a,0),(.026,.045,.036),"copper",.002,"Machinery",a)
    for j in range(24):
        a=j*math.tau/24
        kit.box("GeneratorFieldCoil",kit.radial_point(1.03,a,-.042),(.071,.10,.025),"sage",.004,"Machinery",a)
        kit.box("GeneratorOpalSlot",kit.radial_point(1.03,a,-.058),(.035,.070,.007),"opal",.002,"Machinery",a)
    matrix=Matrix.Translation(Vector((0,0,ring_z)))
    transform_new(start,matrix);ROOTS[MOTION]=matrix;MOTION=""
    # Stationary ring bearing has clear radial/vertical separation from rotor.
    for dz in (-.095,.095):
        kit.ring("AnnularBearingStator",1.03,.11,ring_z+dz,.031,"ivory",160,role="Machinery")
        kit.ring("BearingGiltReveal",1.086,.008,ring_z+dz,.022,"gold",160,role="Inlay")
    for j in range(12):
        a=j*math.tau/12+.18
        group("06_Levitation_Generator",f"Lift_Emitter_And_Bearing_{j+1:02d}")
        inner=kit.radial_point(.72,a,DEPTHS[index]-.30)
        outer=kit.radial_point(1.17,a,ring_z-.095)
        # U-shaped bracket skirts the moving outer gear teeth (max r1.094).
        base.pipe("BearingSuspensionBracket",[inner,kit.radial_point(.87,a,ring_z+.15),
            kit.radial_point(1.17,a,ring_z+.15),outer,kit.radial_point(1.03,a,ring_z-.095)],.025,"ivory")
        point=kit.radial_point(1.03,a,ring_z-.18)
        base.cylinder("DownwardLiftEmitterHousing",point,.067,.12,"gold",32)
        base.cylinder("IvoryEmitterShroud",(point[0],point[1],point[2]-.04),.080,.055,"ivory",32)
        base.cylinder("OpalLiftFieldLens",(point[0],point[1],point[2]-.071),.059,.014,"opal",48)
        base.pipe("LiftEmitterPowerFeed",[kit.radial_point(.94,a,z),kit.radial_point(.86,a,z-.08),
            kit.radial_point(.86,a,ring_z-.18),point],.012,"copper")
    # Continuous light band makes the lift system readable from every direction.
    kit.ring("ContinuousLevitationFieldBand",1.03,.026,ring_z-.26,.018,"opal",192,role="Machinery")
    for j in range(12):
        a=j*math.tau/12+.18
        base.pipe("FieldBandSuspension",[kit.radial_point(1.03,a,ring_z-.24),kit.radial_point(1.03,a,ring_z-.265)],.008,"gold")


def keep_original(obj,index):
    # Replace obsolete small machinery, not the distinctive masonry/deck.
    return obj.get("role")!="Machinery" and not obj.name.startswith(("DawnSmallEngine","CelestialServiceBalcony","CelestialSteamDistribution"))


def batch_runtime(index):
    temporary=bpy.data.collections.new("_ExportOnly")
    bpy.context.scene.collection.children.link(temporary)
    output=[]
    groups={role:[o for o in base.PARTS if o["role"]==role and not o.get("motion_id")] for role in kit.ROLES}
    groups.update({key:[o for o in base.PARTS if o.get("motion_id")==key] for key in ROOTS})
    for key,members in groups.items():
        assert members,key
        copies=[]
        for obj in members:
            duplicate=obj.copy();duplicate.data=obj.data.copy();temporary.objects.link(duplicate);copies.append(duplicate)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in copies:obj.select_set(True)
        bpy.context.view_layer.objects.active=copies[0]
        bpy.ops.object.join()
        merged=bpy.context.object
        matrix=ROOTS.get(key,Matrix.Identity(4))
        merged.data.transform(matrix.inverted() @ merged.matrix_world)
        merged.matrix_world=matrix
        merged.name=key if key in ROOTS else f"{key}_v10_{index+1:02d}"
        for prop in list(merged.keys()):del merged[prop]
        merged["role"]="Machinery" if key in ROOTS else key
        if key in ROOTS:merged["motion_id"]=key
        bpy.ops.object.material_slot_remove_unused()
        output.append(merged)
    bpy.context.view_layer.update();base.prune_unused_meshes()
    triangles=sum(len(o.data.polygons) for o in output)
    top=max((o.matrix_world@v.co).z for o in output for v in o.data.vertices)
    assert triangles<500000 and top<.0004,(triangles,top)
    RUNTIME.update({"runtime_meshes":len(output),"animated_assemblies":len(ROOTS),"engine_count":COUNTS[index],
        "engine_scale":SCALES[index],"power_connections":list(POWER_LINKS),
        "motion_roots":{key:[list(row) for row in matrix] for key,matrix in ROOTS.items()}})
    path=OUT/f"island_{index+1:02d}.glb";pending=OUT/"staging"/path.name
    kit.export_parts(output,pending);pending.replace(path)
    for obj in output:base.discard_object(obj)
    bpy.data.collections.remove(temporary);base.prune_unused_meshes()
    return triangles,path.stat().st_size


def main():
    base.OUT=OUT;base.REVISION="v10";base.additions=additions;base.keep_original=keep_original;base.batch_runtime=batch_runtime
    kit.register=register
    for sub in ("source","bom","staging"):
        (OUT/sub).mkdir(parents=True,exist_ok=True);(OUT/sub/".gdignore").touch()
    sources=[base.SOURCE]+list((base.ROOT/"assets3D/mind_spark/celestial_islands_v09/source").glob("*.blend"))
    before={str(p.relative_to(base.ROOT)):base.sha(p) for p in sources}
    selected=next((int(s.split("=",1)[1])-1 for s in sys.argv if s.startswith("--island=")),None)
    if selected is not None:
        assert 0<=selected<6
        record=base.build(selected);record.update(RUNTIME)
        (OUT/f"island_{selected+1:02d}_record.json").write_text(json.dumps(record,indent=2)+"\n")
        assert all(base.sha(base.ROOT/p)==value for p,value in before.items())
        print("V10_BUILT: "+json.dumps({k:v for k,v in record.items() if k not in ("motion_roots","power_connections")}),flush=True)
        return
    assert "--finalize" in sys.argv,"Build one island at a time using --island=1..6 to bound memory."
    records=[json.loads((OUT/f"island_{i+1:02d}_record.json").read_text()) for i in range(6)]
    manifest={"revision":"v10","parts_per_island":3000,"total_editable_mesh_parts":18000,
        "source_checksums":before,"sources_unchanged":True,
        "shared_paving":"res://assets3D/mind_spark/celestial_islands_v08/shared_paving.glb",
        "counting_policy":"Real nonempty meshes: constructed fittings, connected masonry and explicitly labelled surface patches. Not 3000 machines or closed solids.",
        "power_model":"Fictional steam-magitech lift. Visual mechanical motion, not a thermodynamic or levitation simulation.",
        "variants":records}
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print("V10_COMPLETE: 18000 editable mesh parts; 33 perimeter engines",flush=True)


if __name__=="__main__":main()
