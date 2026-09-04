"""Fourth Mind Spark island: winged Dawn Viaduct, without mutating v11."""
import csv
import json
import math
import sys
from collections import Counter
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_astral_refinement_v16 as v16
import build_celestial_islands_v11 as reference

base, kit, astral = v16.base, v16.kit, v16.astral
ROOT = v16.ROOT
OUT = ROOT / "assets3D/mind_spark/celestial_dawn_v17"
SOURCE = ROOT / "assets3D/mind_spark/celestial_islands_v11/source/island_04_3000.blend"
RECORD = ROOT / "assets3D/mind_spark/celestial_islands_v11/island_04_record.json"
ROLES = ["Rock", "Architecture", "Machinery", "Inlay", "Railing"]
MOTION = {}


def remove(obj):
    base.PARTS.remove(obj)
    base.discard_object(obj)


def group(category, assembly):
    base.GROUP = category
    base.ASSEMBLY = assembly


def setup_materials():
    kit.M = {
        "ivory": bpy.data.materials["MSCT_ivory"],
        "gold": bpy.data.materials["MSCT_gold"],
        "copper": bpy.data.materials["MSCT_copper.002"],
        "rock": bpy.data.materials["MSCT_rock"],
        "rock_light": bpy.data.materials["MSCT_rock_light"],
        "rock_shade": bpy.data.materials["MSCT_rock_shade"],
        "opal": bpy.data.materials["MSCT_v6_energy"],
        "blue": bpy.data.materials["MSCT_teal"],
    }
    for key, rgb, metal, rough in [
        ("ivory", (.83, .79, .69), 0.0, .56),
        ("gold", (.62, .44, .21), .72, .32),
        ("copper", (.42, .23, .12), .65, .40),
        ("blue", (.055, .145, .16), .22, .38),
    ]:
        shader = kit.M[key].node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = (*rgb, 1)
        shader.inputs["Metallic"].default_value = metal
        shader.inputs["Roughness"].default_value = rough


def prepare():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    base.PARTS[:] = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    base.SCENE_COLLECTION = bpy.data.collections.new("DAWN_V17_WINGED_VIADUCT")
    bpy.context.scene.collection.children.link(base.SCENE_COLLECTION)
    base.COLLECTIONS.clear()
    kit.register = base.register
    # Keep the original carved masonry, paving and rock silhouette. Replace the
    # oversized rail and static duplicated machinery with purpose-built systems.
    for obj in list(base.PARTS):
        if obj.get("category") in ("05_Reference_Balustrades", "06_Bearing_Cornice"):
            remove(obj)
        elif obj.get("category") == "04_Reference_Enginehouses" and obj.get("role") == "Machinery":
            remove(obj)
    setup_materials()


def tapered_prism(name, center, bottom, top, height, depth, material="ivory", role="Architecture"):
    x, y, z = center
    verts = []
    for yy in (-depth / 2, depth / 2):
        verts.extend(((x-bottom/2, y+yy, z-height/2), (x+bottom/2, y+yy, z-height/2),
                      (x+top/2, y+yy, z+height/2), (x-top/2, y+yy, z+height/2)))
    faces = [(0,1,2,3), (4,7,6,5), (0,4,5,1), (1,5,6,2), (2,6,7,3), (3,7,4,0)]
    return kit.mesh(name, verts, faces, material, role)


def ellipse_disc(name, side, x, y, z, radius_y, radius_z, depth, material="blue", segments=64):
    """A closed, triangulated oval panel in the island's side elevation."""
    verts = []
    for xx in (x - depth / 2, x + depth / 2):
        verts.append((side * xx, y, z))
        for index in range(segments):
            angle = 2 * math.pi * index / segments
            verts.append((side * xx, y + radius_y * math.cos(angle), z + radius_z * math.sin(angle)))
    faces = []
    for index in range(segments):
        nxt = (index + 1) % segments
        faces.append((0, 1 + index, 1 + nxt))
        back = segments + 1
        faces.append((back, back + 1 + nxt, back + 1 + index))
        faces.extend(((1 + index, back + 1 + index, back + 1 + nxt),
                      (1 + index, back + 1 + nxt, 1 + nxt)))
    if side > 0:
        faces = [tuple(reversed(face)) for face in faces]
    return kit.mesh(name, verts, faces, material, "Architecture")


def ellipse_ring(name, side, x, y, z, radius_y, radius_z, width, material, role="Architecture"):
    path = [Vector((side * x,
                    y + radius_y * math.cos(2 * math.pi * index / 64),
                    z + radius_z * math.sin(2 * math.pi * index / 64)))
            for index in range(65)]
    return kit.tube(name, path, width, material, role, sides=12)


def sanctum_arch(name, side, center_y, base_z, top_z):
    """A small machine chapel: straight load piers joined by a half-ellipse."""
    x = side * 1.018
    half_width = .205
    spring_z = top_z - .205
    path = [Vector((x, center_y - half_width, base_z)),
            Vector((x, center_y - half_width, spring_z))]
    path.extend(Vector((x,
                        center_y - half_width * math.cos(math.pi * index / 20),
                        spring_z + .205 * math.sin(math.pi * index / 20)))
                for index in range(21))
    path.append(Vector((x, center_y + half_width, base_z)))
    kit.tube(name + "IvoryPortal", path, .040, "ivory", "Architecture", sides=12)
    gilt = [point + Vector((side * .008, 0, 0)) for point in path]
    kit.tube(name + "GiltReveal", gilt, .011, "gold", "Inlay", sides=10)
    for pillar_y in (center_y - half_width, center_y + half_width):
        kit.box(name + "PierFoot", (side * 1.012, pillar_y, base_z - .018),
                (.095, .112, .055), "ivory", .012, "Architecture")
        kit.box(name + "PierCapital", (side * 1.013, pillar_y, spring_z),
                (.090, .125, .045), "gold", .009, "Inlay")


def mantle_x(z, y):
    """Convex load-shell profile: broad at the deck and settled into the keel."""
    rise = max(0.0, min(1.0, (z + 1.50) / 1.36))
    crown = .032 * max(0.0, 1.0 - (y / .58) ** 2)
    return .31 + .665 * rise ** .72 + crown


def mantle_panel(side, index, z_top, z_bottom):
    """A closed, triangulated armor band instead of a thin disconnected blade."""
    y_values = [-.57 + 1.14 * step / 12 for step in range(13)]
    thickness = .022
    verts = []
    for y in y_values:
        for z in (z_top, z_bottom):
            x = mantle_x(z, y)
            verts.append((side * (x + thickness / 2), y, z))
            verts.append((side * (x - thickness / 2), y, z))
    faces = []
    for step in range(len(y_values) - 1):
        a = step * 4
        b = (step + 1) * 4
        faces.extend(((a, b, b + 2), (a, b + 2, a + 2),
                      (a + 1, a + 3, b + 3), (a + 1, b + 3, b + 1),
                      (a, a + 1, b + 1), (a, b + 1, b),
                      (a + 2, b + 3, a + 3), (a + 2, b + 2, b + 3)))
    last = (len(y_values) - 1) * 4
    faces.extend(((0, 2, 3), (0, 3, 1),
                  (last, last + 1, last + 3), (last, last + 3, last + 2)))
    # The mirrored starboard shell needs mirrored winding as well. Without
    # this, Godot correctly back-face-culls its broad skins and exposes only
    # the narrow internal ribs—the exact organ-pipe look being replaced.
    if side > 0:
        faces = [tuple(reversed(face)) for face in faces]
    panel = kit.mesh("DawnMantleArmor_%02d" % index, verts, faces, "ivory")
    panel["structural_purpose"] = "load-spreading curved armor shell"
    for z in (z_top, z_bottom):
        path = [Vector((side * (mantle_x(z, y) + thickness / 2 + .004), y, z)) for y in y_values]
        kit.tube("DawnMantleGiltSeam", path, .007, "gold", "Inlay", sides=10)
    for y in (-.575, .575):
        path = [Vector((side * (mantle_x(z, y) + thickness / 2 + .004), y, z))
                for z in (z_bottom, (z_bottom + z_top) / 2, z_top)]
        kit.tube("DawnMantleSideRail", path, .009, "gold", "Inlay", sides=10)
        x = side * (mantle_x(z_top, y) + thickness / 2 + .015)
        base.cylinder("DawnMantleHinge", (x, y, z_top - .025), .022, .045, "copper", 20, "X")
    z_mid = (z_top + z_bottom) / 2
    x_mid = side * (mantle_x(z_mid, 0.0) + thickness / 2 + .010)
    kit.box("DawnMantleVentFrame", (x_mid, 0, z_mid), (.026, .26, .075), "gold", .008, "Inlay")
    kit.box("DawnMantleEnergyVent", (x_mid + side * .008, 0, z_mid), (.014, .205, .045), "blue", .010, "Inlay")


def winged_foundation():
    group("08_Dawn_Load_Wings", "Celestial oval engine arcades")
    for side in (-1, 1):
        tapered_prism("DawnSplitKeel", (side*.26, .12, -1.48), .34, .07, 1.12, .30)
        kit.box("DawnKeelGoldSpine", (side*.26, -.044, -1.43), (.025, .018, .90), "gold", .002, "Inlay")
        # Concealed copper ribs carry the deck into the split keels.
        for rib_index in range(7):
            y = -.48 + rib_index * .16
            foot = Vector((side*.27, y*.18, -1.58))
            control = Vector((side*.54, y, -1.05))
            crown = Vector((side*.91, y, -.17))
            path = [(1-t)**2*foot + 2*(1-t)*t*control + t*t*crown for t in (i/28 for i in range(29))]
            kit.tube("DawnArcadeLoadRib", path, .016 if rib_index%2 else .021,
                     "copper", "Architecture", sides=12)
            for t in (.18, .52, .84):
                point = (1-t)**2*foot + 2*(1-t)*t*control + t*t*crown
                base.cylinder("DawnArcadeRibLock", point, .028, .025, "gold", 18, "Y")

        back = ellipse_disc("DawnArcadeTealSanctum", side, .930, 0, -.84,
                            .605, .665, .034, "blue")
        back["structural_purpose"] = "recessed pressure chamber enclosure"
        ellipse_ring("DawnArcadeIvoryLoadRing", side, .970, 0, -.84,
                     .655, .715, .060, "ivory")
        ellipse_ring("DawnArcadeOuterGiltRing", side, 1.005, 0, -.84,
                     .686, .748, .016, "gold", "Inlay")
        ellipse_ring("DawnArcadeInnerCopperSeal", side, 1.010, 0, -.84,
                     .570, .625, .012, "copper", "Inlay")

        # Four bearing piers and a broad crown shoe connect ring to deck.
        for pier_y in (-.56, .56):
            tapered_prism("DawnArcadeBearingPier", (side*.930, pier_y, -.91),
                          .16, .105, .92, .16)
            kit.box("DawnArcadePierGilt", (side*1.010, pier_y, -.91),
                    (.022, .055, .70), "gold", .007, "Inlay")
            base.cylinder("DawnArcadeBearingPin", (side*1.025, pier_y, -.49),
                          .038, .032, "copper", 24, "X")
        kit.box("DawnArcadeCrownShoe", (side*.945, 0, -.205),
                (.185, 1.17, .105), "ivory", .018, "Architecture")
        kit.box("DawnArcadeCrownGilt", (side*1.042, 0, -.205),
                (.020, 1.05, .034), "gold", .009, "Inlay")

        # Two civic-industrial machine chapels occupy the framed pressure hall.
        for bay_index, bay_y in enumerate((-.305, .305), 1):
            sanctum_arch("DawnSanctum%02d" % bay_index, side, bay_y, -1.30, -.545)
            kit.box("DawnSanctumRecess", (side*.990, bay_y, -.94),
                    (.040, .315, .590), "blue", .055, "Architecture")
            base.cylinder("DawnSanctumAccumulator", (side*1.047, bay_y-.065, -.985),
                          .078, .390, "ivory" if bay_index == 1 else "copper", 32)
            for band_z in (-1.145, -.985, -.825):
                base.cylinder("DawnSanctumAccumulatorBand", (side*1.047, bay_y-.065, band_z),
                              .086, .018, "gold", 32)
            kit.box("DawnSanctumSightGlass", (side*1.125, bay_y-.065, -.985),
                    (.018, .050, .205), "opal", .010, "Inlay")
            for fin in range(8):
                fin_z = -1.155 + fin * .048
                kit.box("DawnSanctumCondenserFin", (side*1.052, bay_y+.095, fin_z),
                        (.080, .130, .020), "copper", .004, "Machinery")
            base.pipe("DawnSanctumPressureHeader", [
                (side*1.055, bay_y-.065, -.775),
                (side*1.055, bay_y, -.690),
                (side*1.055, 0, -.690)], .013, "gold")
            base.pipe("DawnSanctumKeelFeed", [
                (side*1.055, bay_y+.095, -1.18),
                (side*.88, bay_y+.095, -1.38),
                (side*.30, bay_y*.25, -1.55)], .015, "copper")

        # One radiant lift turbine replaces the repeated panel medallions.
        base.cylinder("DawnArcadeTurbineBezel", (side*1.072, 0, -.755),
                      .165, .050, "gold", 48, "X")
        base.cylinder("DawnArcadeTurbineIvory", (side*1.102, 0, -.755),
                      .132, .032, "ivory", 48, "X")
        base.cylinder("DawnArcadeTurbineCore", (side*1.126, 0, -.755),
                      .070, .020, "opal", 36, "X")
        for ray_angle in range(0, 360, 30):
            angle = math.radians(ray_angle)
            start = Vector((side*1.135, .078*math.cos(angle), -.755+.078*math.sin(angle)))
            end = Vector((side*1.135, .124*math.cos(angle), -.755+.124*math.sin(angle)))
            kit.tube("DawnArcadeTurbineRay", [start, end], .008, "gold", "Inlay", sides=8)
        for valve_y in (-.44, .44):
            base.cylinder("DawnArcadeServiceValve", (side*1.060, valve_y, -1.285),
                          .055, .026, "gold", 24, "X")
            for spoke_angle in range(0, 360, 90):
                angle = math.radians(spoke_angle)
                kit.tube("DawnArcadeValveSpoke", [
                    Vector((side*1.078, valve_y, -1.285)),
                    Vector((side*1.078, valve_y+.074*math.cos(angle), -1.285+.074*math.sin(angle)))],
                    .006, "gold", "Inlay", sides=8)
    group("09_Dawn_Crown_Ties", "Viaduct crown and arch spring ties")
    for side in (-1, 1):
        for y in (-.66, .66):
            kit.tube("DawnCrownTie", [(side*.23,.08,-1.42), (side*.72,y,-.42),
                                      (side*.98,y,-.08)], .025, "copper", sides=14)
            kit.box("DawnBearingShoe", (side*.98,y,-.075), (.15,.18,.05), "ivory", .005)


def pressure_column(name, x, y, z, material="blue"):
    base.cylinder(name+"Body", (x,y,z), .072, .34, material, 36)
    for dz in (-.15, 0, .15):
        base.cylinder(name+"Band", (x,y,z+dz), .079, .018, "gold", 36)
    kit.box(name+"SightGlass", (x, y-.074, z+.01), (.042,.014,.18), "opal", .003, "Machinery")
    for sx in (-1,1):
        kit.box(name+"Foot", (x+sx*.038,y,z-.19), (.032,.08,.04), "ivory", .003, "Machinery")


def motion_group(name, center):
    group("12_Dawn_Lift_Engine", name)
    MOTION[name] = center


def lift_engine():
    # Two mirrored engine rooms match the double-arch facade, but the exposed
    # gear trains and lift conduits give the viaduct its own function.
    for side, label in ((-1,"West"),(1,"East")):
        group("12_Dawn_Lift_Engine", label+" fixed lift engine")
        kit.box(label+"EngineBed", (side*.30,-.70,-1.38), (.43,.28,.055), "ivory", .006, "Machinery")
        kit.box(label+"EngineBedInlay", (side*.30,-.848,-1.36), (.37,.014,.022), "gold", .002, "Inlay")
        pressure_column(label+"BuoyancyDrum", side*.18, -.70, -1.12)
        pressure_column(label+"SteamAccumulator", side*.38, -.70, -1.12, "copper")
        base.pipe(label+"CrownHeader", [(side*.18,-.70,-.93),(side*.38,-.70,-.93),
                  (side*.38,-.48,-.93),(side*.60,-.48,-.30)], .014, "gold")
        base.pipe(label+"KeelFeed", [(side*.18,-.70,-1.30),(side*.18,-.32,-1.48),
                  (side*.26,.08,-1.60)], .014, "copper")
        wheel=(side*.44,-.865,-1.18)
        pinion=(side*.44,-.865,-.94)
        motion_group(label+"SunFlywheel", wheel)
        v16.gear(label+"SunFlywheel", wheel, .15, 20, math.pi/20)
        motion_group(label+"LiftPinion", pinion)
        v16.gear(label+"LiftPinion", pinion, .09, 12, 0)
        base.cylinder(label+"DriveShaft", (side*.44,-.70,-1.18), .020, .32, "copper", 24, "Y")
        for yy in (-.54,-.86):
            kit.box(label+"ShaftBearing", (side*.44,yy,-1.18), (.11,.06,.11), "ivory", .004, "Machinery")
    group("13_Dawn_Halo_Manifold", "Central sunrise lift manifold")
    kit.arch("DawnHaloArch", (0,-.60,-.82), .56, .58, .055, .085, 0, 31)
    for index in range(9):
        angle=math.pi*index/8
        start=Vector((0,-.69,-.82))
        finish=Vector((.49*math.cos(angle),-.69,-.82+.50*math.sin(angle)))
        kit.tube("DawnHaloRay", [start,finish], .009, "gold", "Inlay", sides=10)
    kit.box("DawnManifold", (0,-.70,-1.40), (.25,.28,.07), "ivory", .005, "Machinery")
    for x in (-.085,0,.085):
        base.pressure_column("DawnManifoldCell", x, -.70, -1.28, .25, .028, "blue")


def barriers():
    radius_m=120.0
    r=.992
    directions=[Vector(v) for v in json.loads(RECORD.read_text())["route_directions_blender"]]
    half=math.asin(22.5/(r*radius_m))
    blocked=sorted((math.atan2(d.y,d.x)%(2*math.pi)-half,
                    math.atan2(d.y,d.x)%(2*math.pi)+half) for d in directions)
    spans=[(0,blocked[0][0]),(blocked[0][1],blocked[1][0]),
           (blocked[1][1],2*math.pi)]
    panels=[]
    group("05_Player_Scale_Dawn_Balustrade", "Five metre sunrise panel")
    panel_index=0
    for lo,hi in spans:
        count=math.ceil((hi-lo)*r*radius_m/5.0)
        for i in range(count):
            a0=lo+(hi-lo)*i/count;a1=lo+(hi-lo)*(i+1)/count
            panels.append([a0,a1]);panel_index+=1
            p=lambda a,z:Vector((r*math.cos(a),r*math.sin(a),z/radius_m))
            for h,width in ((.30,.032),(1.36,.043)):
                kit.tube("DawnGuardRail", [p(a0+(a1-a0)*k/4,h) for k in range(5)],
                         width/radius_m, "gold", "Railing", sides=8)
            for f in (.18,.50,.82):
                a=a0+(a1-a0)*f
                kit.tube("DawnGuardPicket", [p(a,.30),p(a,1.36)], .018/radius_m,
                         "gold", "Railing", sides=8)
            am=(a0+a1)/2;tangent=Vector((-math.sin(am),math.cos(am),0));centre=p(am,.82)
            for q0,q1 in ((centre+tangent*.18/radius_m,centre+Vector((0,0,.28/radius_m))),
                          (centre+Vector((0,0,.28/radius_m)),centre-tangent*.18/radius_m),
                          (centre-tangent*.18/radius_m,centre-Vector((0,0,.28/radius_m))),
                          (centre-Vector((0,0,.28/radius_m)),centre+tangent*.18/radius_m)):
                kit.tube("DawnSunLozenge", [q0,q1], .016/radius_m, "gold", "Railing", sides=8)
            for a in ([a0,a1] if i==count-1 else [a0]):
                kit.box("DawnIvoryPost", p(a,.70), (.25/radius_m,.25/radius_m,1.40/radius_m), "ivory", .001)
                kit.box("DawnPostCapital", p(a,1.42), (.38/radius_m,.38/radius_m,.10/radius_m), "ivory", .001)
    return {"radius_m":r*radius_m,"height_m":1.40,"collision_height_m":1.48,
            "panel_angles":panels,"route_directions":[list(d) for d in directions],
            "bridge_half_width_m":22.5}


def batch(triangle_limit=540000):
    temporary=bpy.data.collections.new("_DawnExportOnly")
    bpy.context.scene.collection.children.link(temporary)
    output=[]
    moving=set(MOTION)
    groups=[(role,[o for o in base.PARTS if o.get("role")==role and o.get("assembly") not in moving])
            for role in ROLES]
    groups.extend((name,[o for o in base.PARTS if o.get("assembly")==name]) for name in MOTION)
    for name,members in groups:
        assert members,name
        copies=[]
        for obj in members:
            copy=obj.copy();copy.data=obj.data.copy();temporary.objects.link(copy);copies.append(copy)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in copies:obj.select_set(True)
        bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join()
        merged=bpy.context.object
        merged.data.transform(merged.matrix_world);merged.matrix_world=Matrix.Identity(4)
        if name in MOTION:
            center=Vector(MOTION[name]);merged.data.transform(Matrix.Translation(-center));merged.location=center
        merged.name=(name+"_v17" if name in MOTION else name+"_v17_04")
        for key in list(merged.keys()):del merged[key]
        merged["role"]="Mechanism" if name in MOTION else name
        bpy.ops.object.material_slot_remove_unused();output.append(merged)
    triangles=sum(len(o.data.polygons) for o in output)
    assert triangles<triangle_limit,triangles
    pending=OUT/"staging/island_04.glb"
    kit.export_parts(output,pending);pending.replace(OUT/"island_04.glb")
    for obj in output:base.discard_object(obj)
    bpy.data.collections.remove(temporary)
    return triangles


def finish(barrier):
    natural=len(base.PARTS)
    merges=reference.combine_to_budget(max_group_size=12)
    splits=base.subdivide_to_target()
    parts=sorted(base.PARTS,key=lambda o:(o["category"],o["assembly"],o.name));rows=[]
    for i,obj in enumerate(parts):
        obj.data.transform(obj.matrix_world);obj.matrix_world=Matrix.Identity(4)
        center=sum((v.co for v in obj.data.vertices),Vector())/len(obj.data.vertices)
        obj.data.transform(Matrix.Translation(-center));obj.location=center
        old=obj.name;identifier=f"MS17-I04-P{i+1:04d}"
        obj.name=identifier+"_"+old[-39:];obj["part_id"]=identifier;obj["island_id"]=4
        rows.append({"part_id":identifier,"name":old,"role":obj["role"],"category":obj["category"],
            "assembly":obj["assembly"],"kind":obj["component_kind"],"triangles":len(obj.data.polygons),
            "source_component":obj.get("source_component",old)})
    triangles=batch()
    bpy.context.preferences.filepaths.save_version=0
    pending=OUT/"staging/island_04_3000.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(pending),compress=True)
    pending.replace(OUT/"source/island_04_3000.blend")
    with (OUT/"bom/island_04_parts.csv").open("w",newline="") as stream:
        writer=csv.DictWriter(stream,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    record=json.loads(RECORD.read_text())
    record.update(revision="v17",name="Dawn Wing Viaduct",runtime_meshes=9,runtime_triangles=triangles,
        editable_mesh_parts=3000,natural_components=natural,related_fitting_merges=merges,
        surface_patch_splits=splits,component_kinds=dict(Counter(o["component_kind"] for o in base.PARTS)),
        silhouette="celestial oval engine arcades and split keels",moving_assemblies=list(MOTION),
        barrier=barrier,gameplay_policy="Original 120 m floor, Hope Path jump course and two bridge approaches retained.",
        machinery_simulation="Four kinematic 20:12 gear assemblies drive fictional paired buoyancy drums.")
    (OUT/"island_04_record.json").write_text(json.dumps(record,indent=2)+"\n")
    return record


def main():
    for sub in ("source","bom","staging"):
        (OUT/sub).mkdir(parents=True,exist_ok=True);(OUT/sub/".gdignore").touch()
    old_hash=base.sha(SOURCE)
    prepare();winged_foundation();lift_engine();barrier=barriers();setup_materials()
    record=finish(barrier)
    (OUT/"barriers.json").write_text(json.dumps(barrier,indent=2)+"\n")
    (OUT/"manifest.json").write_text(json.dumps({"revision":"v17","island_id":4,
        "variant":record,"source_sha256":old_hash},indent=2)+"\n")
    assert base.sha(SOURCE)==old_hash
    print("DAWN_V17_BUILT",json.dumps({"triangles":record["runtime_triangles"],
        "natural":record["natural_components"],"merges":record["related_fitting_merges"],
        "splits":record["surface_patch_splits"]}),flush=True)


if __name__=="__main__":main()
