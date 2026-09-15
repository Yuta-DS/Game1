"""Six related, deliberately different World One foundations (v08).

Reuses v07 materials, paving, gateway facade and the actual 80-part condenser.
All new construction stays below the unchanged unit-radius gameplay plane.
Run: blender --background --python-exit-code 1 --python this_file.py
"""
import hashlib
import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OLD = ROOT / "assets3D/mind_spark/celestial_land_runtime/celestial_land.glb"
MASTER = ROOT / "assets3D/mind_spark/celestial_condenser_v07/source/celestial_condenser_v07.blend"
OUT = ROOT / "assets3D/mind_spark/celestial_islands_v08"
NAMES = ["Sun Gate", "Verdant Engine Gardens", "Astral Observatory", "Dawn Viaduct", "Stormworks Bastion", "Crownroot Sanctuary"]
ROLES = ["Rock", "Architecture", "Machinery", "Inlay"]
PARTS = []
COLL = None
M = {}


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def newmat(name, rgb, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = .43 if metal else .7
    return m


def register(obj, role):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    COLL.objects.link(obj)
    obj["role"] = role
    obj["component_id"] = len(PARTS) + 1
    PARTS.append(obj)
    return obj


def mesh(name, verts, faces, mat, role="Architecture", bevel=0, smooth=False):
    data = bpy.data.meshes.new(name + "Mesh")
    data.from_pydata(verts, [], faces)
    data.materials.append(M[mat])
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect="EDGES")
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    data.validate()
    data.update()
    for p in data.polygons:
        p.use_smooth = smooth
    obj = bpy.data.objects.new(name, data)
    return register(obj, role)


def box(name, center, size, mat="ivory", bevel=.003, role="Architecture", yaw=0):
    verts = [(x*size[0]/2, y*size[1]/2, z*size[2]/2) for z in (-1, 1) for y in (-1, 1) for x in (-1, 1)]
    faces = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    o = mesh(name, verts, faces, mat, role, bevel)
    o.location = center
    o.rotation_euler.z = yaw
    return o


def ring(name, radius, width, z, height, mat="ivory", segments=96, start=0, end=math.tau, role="Architecture"):
    vs, fs = [], []
    for i in range(segments + 1):
        a = start + (end-start)*i/segments
        for zz in (z-height/2, z+height/2):
            for rr in (radius-width/2, radius+width/2):
                vs.append((rr*math.cos(a), rr*math.sin(a), zz))
    for i in range(segments):
        a, b = 4*i, 4*(i+1)
        fs.extend([(a,b,b+1,a+1), (a+2,a+3,b+3,b+2), (a,a+2,b+2,b), (a+1,b+1,b+3,a+3)])
    fs.extend([(0,1,3,2), (4*segments,4*segments+2,4*segments+3,4*segments+1)])
    return mesh(name, vs, fs, mat, role)


def tube(name, points, radius, mat="gold", role="Architecture", sides=12):
    vs, fs = [], []
    ps = [Vector(p) for p in points]
    for i,p in enumerate(ps):
        tangent = (ps[min(i+1,len(ps)-1)]-ps[max(0,i-1)]).normalized()
        normal = tangent.cross(Vector((0,0,1)))
        if normal.length < .01:
            normal = tangent.cross(Vector((0,1,0)))
        normal.normalize()
        other = tangent.cross(normal).normalized()
        for j in range(sides):
            vs.append(tuple(p + radius*(normal*math.cos(j*math.tau/sides)+other*math.sin(j*math.tau/sides))))
    for i in range(len(ps)-1):
        for j in range(sides):
            k=(j+1)%sides
            fs.append((i*sides+j, i*sides+k, (i+1)*sides+k, (i+1)*sides+j))
    fs += [tuple(reversed(range(sides))), tuple((len(ps)-1)*sides+j for j in range(sides))]
    return mesh(name, vs, fs, mat, role, smooth=True)


def radial_point(r,a,z):
    return (r*math.cos(a), r*math.sin(a), z)


def arch(name, center, rx, rz, thick, depth, yaw=0, blocks=17, mat="ivory"):
    # Individually editable wedge stones; both springings bear on piers.
    for i in range(blocks):
        a0=i*math.pi/blocks+.002
        a1=(i+1)*math.pi/blocks-.002
        vs=[]
        for y in (-depth/2,depth/2):
            for d in (0,thick):
                for a in (a0,(a0+a1)/2,a1):
                    vs.append(((rx+d)*math.cos(a),y,(rz+d)*math.sin(a)))
        fs=[(0,1,4,3),(1,2,5,4),(6,9,10,7),(7,10,11,8),
            (0,6,7,1),(1,7,8,2),(3,4,10,9),(4,5,11,10),(0,3,9,6),(2,8,11,5)]
        o=mesh(f"{name}_Voussoir_{i+1:02d}",vs,fs,mat,bevel=.002)
        o.location=center
        o.rotation_euler.z=yaw
    # Continuous slender brass reveal traces the same seated arch.
    path=[(rx*math.cos(j*math.pi/48),-depth*.54,rz*math.sin(j*math.pi/48)) for j in range(49)]
    q=Matrix.Rotation(yaw,4,"Z")
    tube(name+"_BrassReveal",[Vector(center)+q@Vector(p) for p in path],.006)


def copy_part(template, name, role, scale=(1,1,1), location=(0,0,0), yaw=0, unique=False):
    obj=template.copy()
    if unique:
        obj.data=template.data.copy()
    obj.name=name
    obj.matrix_world=Matrix.Identity(4)
    obj.scale=scale
    obj.location=location
    obj.rotation_euler.z=yaw
    return register(obj,role)


def rock_variant(template, index):
    o=copy_part(template, "SculptedRock", "Rock", unique=True)
    if o.data.has_custom_normals:
        bpy.context.view_layer.objects.active=o
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    for v in o.data.vertices:
        x,y,z=v.co
        t=min(1,max(0,(-z-.10)/.9))
        s=t*t*(3-2*t)
        a=math.atan2(y,x)
        if index==1:
            garden_t=min(1,max(0,(-z-.08)/.50))
            garden_s=garden_t*garden_t*(3-2*garden_t)
            f=1-.42*garden_s+.08*garden_s*math.cos(3*a)
            v.co=(x*f,y*f,z*.82)
        elif index==2:
            f=1-.68*s
            v.co=(x*f,y*f,z*.88)
        elif index==3:
            bridge_t=min(1,max(0,(-z-.06)/.42))
            bridge_s=bridge_t*bridge_t*(3-2*bridge_t)
            v.co=(x*(1-.58*bridge_s),y*(1-.72*bridge_s),z*1.08)
        elif index==4:
            f=1+.08*s*math.cos(8*a)
            v.co=(x*f,y*f,z*.73)
        elif index==5:
            f=1-.53*s+.12*s*math.cos(6*a)
            v.co=(x*f,y*f,z*1.18)
    o.data.update()
    return o


def condenser(template, name, x, y, z, scale=1, yaw=0):
    # Unit origin is the actual bottom of the v07 mounting skid.
    copy_part(template,name,"Machinery",(scale,)*3,(x,y,z),yaw)
    box(name+"_BearingSill",(x,y,z-.025),(.43*scale,.20*scale,.05),"ivory",yaw=yaw)
    # The two exposed lines join the actual original inlet and return ports.
    rot=Matrix.Rotation(yaw,4,"Z")
    for label,port,mat in [("Supply",(0,.0243,.5211),"gold"),("Return",(0,.0281,.0358),"copper")]:
        p=Vector((x,y,z))+rot@(Vector(port)*scale)
        bend=p+rot@Vector((.12*scale,.02,0))
        end=Vector((bend.x,bend.y,-.035))
        tube(name+label,[p,bend,end],.009,mat,"Machinery")


def common_bearing():
    ring("CivicBearingRing",.962,.09,-.063,.055)
    ring("GildedReveal",1.0,.013,-.049,.018,"gold")


def forest(unit):
    for tier,(radius,z) in enumerate(((.96,-.15),(.87,-.42),(.75,-.72))):
        ring(f"GardenTerrace_{tier}",radius,.12,z,.065)
        ring(f"SageTerraceFrieze_{tier}",radius+.007,.032,z-.068,.055,"sage")
        ring(f"TerraceGoldLip_{tier}",radius+.064,.010,z+.030,.012,"gold")
        for j in range(12):
            a=j*math.tau/12
            box(f"TerraceCorbel_{tier}_{j}",radial_point(radius-.025,a,z-.115),(.09,.13,.18),"ivory",yaw=a)
    for j,a in enumerate((-math.pi/2-.50,-math.pi/2+.50,math.pi/2)):
        x,y,_=radial_point(.90,a,0)
        condenser(unit,f"GardenCondenser_{j}",x,y,-.64,.82,a+math.pi/2)
        box(f"GardenEngineTerrace_{j}",radial_point(.85,a,-.69),(.38,.40,.06),"ivory",yaw=a)
        tube(f"GardenEngineCorbel_{j}",[radial_point(.28,a,-.91),radial_point(.91,a,-.72)],.037,"ivory")
    for j in range(6):
        a=j*math.tau/6
        path=[radial_point(.72-.59*t,a+.12*math.sin(t*math.pi),-.69-.65*t) for t in [k/24 for k in range(25)]]
        tube(f"LivingEngineRoot_{j}",path,.038,"sage")
        tube(f"RootBrassInlay_{j}",[(p[0]*1.035,p[1]*1.035,p[2]) for p in path],.007)


def observatory(unit):
    ring("ObservatoryGallerySill",.81,.18,-.79,.08)
    ring("ObservatoryCentralCompressionHub",.265,.20,-1.07,.50,"ivory")
    ring("ObservatorySpokeBearingCollar",.32,.32,-1.10,.10,"gold")
    ring("ObservatoryFrieze",.91,.12,-.145,.14)
    ring("BlueEnamelFrieze",.974,.008,-.145,.047,"blue")
    for j in range(10):
        a=j*math.tau/10
        p=radial_point(.84,a,-.46)
        box(f"ObservatoryPier_{j}",p,(.073,.10,.59),"ivory",yaw=a)
        box(f"PierCapital_{j}",radial_point(.84,a,-.21),(.12,.14,.07),"ivory",yaw=a)
        box(f"PierFoot_{j}",radial_point(.84,a,-.745),(.14,.16,.08),"gold",yaw=a)
        tube(f"PierEngraving_{j}",[radial_point(.9,a,-.7),radial_point(.9,a,-.25)],.008)
        tube(f"GalleryRadialBrace_{j}",[radial_point(.80,a,-.79),radial_point(.37,a,-1.11)],.035,"ivory")
        mid=a+math.pi/10
        arch(f"ObservatoryArcade_{j}",radial_point(.84*math.cos(math.pi/10),mid,-.62),
             .84*math.sin(math.pi/10),.365,.035,.10,mid+math.pi/2,11)
    for j,(r,z) in enumerate(((.98,-.91),(.86,-1.10),(.64,-1.30))):
        ring(f"AstralHalo_{j}",r,.016,z,.016,"gold",128)
        for k,a in enumerate((0,math.tau/3,2*math.tau/3)):
            tube(f"HaloBearing_{j}_{k}",[radial_point(.35,a,z+.05),radial_point(r,a,z)],.009,"gold")
    condenser(unit,"ObservatoryCoolingCore",0,.63,-.74,.65,math.pi)
    box("ObservatoryEngineSupportBridge",(0,.50,-.795),(.32,.50,.05))


def viaduct(unit):
    for j,y in enumerate((-.53,.53)):
        arch(f"DawnLoadArch_{j}",(0,y,-.81),.74,.63,.067,.14)
        box(f"DawnContinuousLintel_{j}",(0,y,-.095),(1.68,.19,.11))
        for side in (-1,1):
            x=side*.77
            box(f"DawnPier_{j}_{side}",(x,y,-.71),(.17,.23,.59))
            box(f"DawnPierCapital_{j}_{side}",(x,y,-.405),(.22,.27,.065))
            box(f"DawnPierGoldRecess_{j}_{side}",(x,y-.119,-.69),(.065,.012,.39),"gold",.002)
            box(f"DawnFoot_{j}_{side}",(x,y,-1.025),(.23,.29,.08),"gold")
            path=[(x*(1-t*.88),y*(1-t*.85),-1.0-.76*t) for t in [k/20 for k in range(21)]]
            tube(f"DawnSweepingButtress_{j}_{side}",path,.056,"ivory")
            tube(f"ButtressEdge_{j}_{side}",[(p[0],p[1]-.05,p[2]) for p in path],.008)
    for k in range(7):
        box(f"ViaductTransverseBeam_{k}",(-.68+k*.226,0,-.125),(.035,1.26,.055),"gold")
    condenser(unit,"DawnSmallEngine",0,-.54,-.90,.60)
    box("DawnEngineCrossBearer",(0,-.53,-.975),(1.66,.25,.05),"gold")
    ring("ViaductKeelSocket",.15,.13,-1.76,.10,"gold")


def bastion(unit):
    for j,z in enumerate((-.18,-.76,-1.05)):
        ring(f"OctagonalBastionCourse_{j}",.93-j*.065,.14,z,.105,"ivory",8,start=math.pi/8,end=math.tau+math.pi/8)
        ring(f"BastionBrassBelt_{j}",.97-j*.065,.025,z+.055,.025,"gold",8,start=math.pi/8,end=math.tau+math.pi/8)
    for j in range(8):
        a=j*math.tau/8
        box(f"BastionTower_{j}",radial_point(.87,a,-.53),(.20,.23,.89),"ivory",yaw=a)
        box(f"TowerBronzeInset_{j}",radial_point(.987,a,-.46),(.028,.14,.48),"copper",yaw=a)
        for k in range(5):
            box(f"CoolingLouvre_{j}_{k}",radial_point(1.007,a,-.64+k*.09),(.035,.16,.026),"gold",yaw=a)
        tube(f"TowerAnchoringStrut_{j}",[radial_point(.90,a,-.98),radial_point(.48,a,-1.35)],.044,"copper")
    for j,a in enumerate((-math.pi/2, -math.pi/2-.78, -math.pi/2+.78)):
        p=radial_point(.93,a,-.75)
        condenser(unit,f"StormPressureBank_{j}",*p,.95,a+math.pi/2)
    ring("PressureHeader",1.015,.026,-.20,.026,"copper",96)
    ring("BastionRootBearing",.36,.30,-1.33,.09,"gold")


def sanctuary(unit):
    # Eight flared stone petals connect the deck bearing to the rock-root socket.
    for j in range(8):
        a=j*math.tau/8
        points=[]
        for k in range(41):
            t=k/40
            r=.28+.62*math.sin(t*math.pi/2)
            points.append(radial_point(r,a,-1.19+1.10*t))
        tube(f"CrownPetalRib_{j}",points,.055,"ivory",sides=16)
        tube(f"CrownPetalGoldEdge_{j}",[(p[0]*1.06,p[1]*1.06,p[2]) for p in points],.009)
        # A second curving rib splits from the same rooted socket, not thin air.
        path=[radial_point(.30+.52*math.sin(t*math.pi/2),a+.21*math.sin(t*math.pi),-1.18+1.04*t) for t in [k/40 for k in range(41)]]
        tube(f"CrownPetalBranch_{j}",path,.025,"sage",sides=12)
        box(f"PetalBearingCapital_{j}",radial_point(.90,a,-.095),(.15,.18,.09),"ivory",yaw=a)
    ring("RootCrownSocket",.32,.12,-1.19,.14,"gold")
    ring("CrownUpperCollar",.925,.064,-.16,.08,"ivory")
    ring("CrownOpalFrieze",.962,.012,-.17,.034,"sage")
    for j in range(8):
        a=j*math.tau/8
        tube(f"LowerRootFiligree_{j}",[radial_point(.32,a,-1.20),radial_point(.21,a+.2,-1.57),radial_point(.12,a+.25,-1.93)],.011)
    condenser(unit,"SanctuaryQuietEngine",0,.56,-.75,.63,math.pi)
    box("SanctuaryEngineRootSill",(0,.45,-.795),(.32,.38,.05))


def motif(index):
    # Flush inlay (not raised obstacles); each identity reads on the minimap too.
    z=.00024
    ring("CentralInlayBoundary",.35,.005,z,.00008,"gold",96,role="Inlay")
    if index==0:
        for j in range(16):
            a=j*math.tau/16
            pts=[radial_point(.10,a,z),radial_point(.32,a+.028,z),radial_point(.32,a+.14,z)]
            mesh(f"SunRay_{j}",pts,[(0,1,2)],"gold","Inlay")
    elif index in (1,5):
        n=5 if index==1 else 8
        for j in range(n):
            a=j*math.tau/n
            pts=[radial_point(.055,a,z),radial_point(.22,a-.22,z),radial_point(.32,a,z),radial_point(.22,a+.22,z)]
            mesh(f"BotanicalPetal_{j}",pts,[(0,1,2,3)],"sage","Inlay")
            tube(f"PetalVein_{j}",[radial_point(.06,a,z),radial_point(.31,a,z)],.00010,"gold","Inlay",8)
    elif index==2:
        for r in (.13,.23,.30):
            ring("AstralInlayRing",r,.004,z,.00008,"gold",96,role="Inlay")
        for j in range(6):
            a=j*math.tau/6
            pts=[radial_point(.10,a,z),radial_point(.32,a,z),radial_point(.16,a+.24,z)]
            mesh(f"AstralStarPoint_{j}",pts,[(0,1,2)],"blue","Inlay")
    elif index==3:
        for j in range(4):
            a=j*math.tau/4
            pts=[radial_point(.04,a,z),radial_point(.31,a-.07,z),radial_point(.25,a,z),radial_point(.31,a+.07,z)]
            mesh(f"DawnCompass_{j}",pts,[(0,1,2,3)],"gold","Inlay")
    else:
        for r in (.12,.23,.31):
            ring("BastionInlayOctagon",r,.011,z,.00008,"copper",8,role="Inlay")
        for j in range(8):
            a=j*math.tau/8
            tube(f"BastionInlaySpoke_{j}",[radial_point(.24,a,z),radial_point(.32,a,z)],.00010,"gold","Inlay",8)


def export_parts(parts,path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,
        export_extras=True,export_cameras=False,export_lights=False)


def batch_export(parts,index):
    grouped=[]
    for role in ROLES:
        members=[o for o in parts if o["role"]==role]
        copies=[]
        for o in members:
            c=o.copy();c.data=o.data.copy();COLL.objects.link(c);copies.append(c)
        bpy.ops.object.select_all(action="DESELECT")
        for c in copies:c.select_set(True)
        bpy.context.view_layer.objects.active=copies[0]
        if len(copies)>1:
            bpy.ops.object.join()
        merged=bpy.context.object
        # Bake the active member transform so all exports have identical units.
        merged.data.transform(merged.matrix_world)
        merged.matrix_world=Matrix.Identity(4)
        merged.name=ROLES[ROLES.index(role)] + "_v08_%02d" % (index+1)
        merged.data.validate();merged.data.update()
        for key in list(merged.keys()):del merged[key]
        merged["variant_id"]=index+1;merged["family_role"]=role
        bpy.ops.object.material_slot_remove_unused()
        grouped.append(merged)
    path=OUT / ("island_%02d.glb" % (index+1))
    export_parts(grouped,path)
    verts=[o.matrix_world@v.co for o in grouped for v in o.data.vertices]
    result={"id":index+1,"name":NAMES[index],"file":path.name,
        "editable_components":len(parts),"mesh_nodes":len(grouped),
        "triangles":sum(len(o.data.polygons) for o in grouped),"bytes":path.stat().st_size,
        "bounds_min":[min(v[i] for v in verts) for i in range(3)],
        "bounds_max":[max(v[i] for v in verts) for i in range(3)]}
    for o in grouped:bpy.data.objects.remove(o,do_unlink=True)
    return result


def main():
    global COLL,M
    before={"v07_master":sha(MASTER),"v07_runtime":sha(OLD)}
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/"source").mkdir(exist_ok=True)
    (OUT/"source/.gdignore").touch()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OLD))
    templates={o.name:o for o in bpy.data.objects if o.type=="MESH"}
    M={"ivory":bpy.data.materials.get("MSCT_ivory"),"gold":bpy.data.materials.get("MSCT_gold"),
       "copper":bpy.data.materials.get("MSCT_copper")}
    assert all(M.values()),[m.name for m in bpy.data.materials]
    M["sage"]=newmat("CelestialSageEnamel",(.24,.43,.33),.20)
    M["blue"]=newmat("CelestialAstralBlueEnamel",(.12,.26,.34),.22)
    # Keep the paving as one shared resource. Remove only its central gold motif.
    paving=templates["CelestialIvoryDeck"]
    bm=bmesh.new();bm.from_mesh(paving.data)
    remove=[]
    for f in bm.faces:
        mat=paving.data.materials[f.material_index]
        if "gold" in mat.name.lower() and max(math.hypot(v.co.x,v.co.y) for v in f.verts)<.40:
            remove.append(f)
    bmesh.ops.delete(bm,geom=remove,context="FACES")
    bm.to_mesh(paving.data);bm.free()
    # The original centre medallion covered a small opening: fill it in stone.
    COLL=bpy.data.collections.new("SharedPaving");bpy.context.scene.collection.children.link(COLL)
    register(paving,"Inlay")
    vs=[(0,0,.00004)]+[radial_point(.0805,j*math.tau/96,.00004) for j in range(96)]
    centre=mesh("CentreStoneInsert",vs,[(0,j+1,(j+1)%96+1) for j in range(96)],"ivory","Inlay")
    bpy.ops.object.select_all(action="DESELECT");paving.select_set(True);centre.select_set(True)
    bpy.context.view_layer.objects.active=paving;bpy.ops.object.join()
    paving.name="CelestialIvoryDeck"
    export_parts([paving],OUT/"shared_paving.glb")
    # Load the eighty real v07 condenser pieces, independently from the master.
    with bpy.data.libraries.load(str(MASTER),link=False) as (src,dst):
        dst.objects=[name for name in src.objects if name.startswith("CC7_")]
    unit_parts=[o for o in dst.objects if o is not None]
    assert len(unit_parts)==80
    for o in unit_parts:
        COLL.objects.link(o)
    bpy.context.view_layer.update()
    for o in unit_parts:
        o.data=o.data.copy()
        o.data.transform(Matrix.Translation(Vector((-3.15,6.65,5.18)))@o.matrix_world)
        o.matrix_world=Matrix.Identity(4)
        o.data.transform(Matrix.Scale(1/7.83,4))
        if len(o.data.polygons)>240:
            bpy.context.view_layer.objects.active=o
            mod=o.modifiers.new("RuntimeUnitReduction","DECIMATE");mod.ratio=.25;mod.use_collapse_triangulate=True
            bpy.ops.object.modifier_apply(modifier=mod.name)
        o.data.validate();o.data.update()
    bpy.ops.object.select_all(action="DESELECT")
    for o in unit_parts:o.select_set(True)
    bpy.context.view_layer.objects.active=unit_parts[0];bpy.ops.object.join()
    unit=bpy.context.object;unit.name="SharedCondenserUnit"
    record=[];collections=[]
    for index in range(6):
        COLL=bpy.data.collections.new("%02d_%s"%(index+1,NAMES[index].replace(" ","_")))
        bpy.context.scene.collection.children.link(COLL);collections.append(COLL)
        start=len(PARTS)
        rock_variant(templates["CelestialRockAnchors"],index)
        if index==0:
            for name in ("CelestialArchesAndCondenser","CelestialSteamDistribution","CelestialServiceBalcony"):
                copy_part(templates[name],name,"Machinery" if name=="CelestialSteamDistribution" else "Architecture")
        else:
            common_bearing()
            [None,forest,observatory,viaduct,bastion,sanctuary][index](unit)
        motif(index)
        parts=PARTS[start:]
        result=batch_export(parts,index)
        assert result["bounds_max"][2] < .0004,result
        assert result["triangles"]<350000,result
        record.append(result)
        print("V08_VARIANT: "+json.dumps(result),flush=True)
        # Arrange only the authoring copy on a 3 x 2 board after game export.
        offset=Vector(((index%3-1)*3.0,(1-index//3)*3.0,0))
        for o in parts:o.location+=offset
        tile=paving.copy();COLL.objects.link(tile);tile.location+=offset
    for o in templates.values():
        if o!=paving:bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.objects.remove(unit,do_unlink=True)
    paving.hide_render=True;paving.hide_viewport=True
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"source/celestial_island_family_v08.blend"),compress=True)
    assert before=={"v07_master":sha(MASTER),"v07_runtime":sha(OLD)}
    manifest={"revision":"v08","source_checksums":before,"old_assets_unchanged":True,
        "shared_paving":"shared_paving.glb","condenser_source_components":80,
        "collision_policy":"Existing six circular gameplay footprints and all routes unchanged; visual-only variants.",
        "variants":record}
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print("V08_COMPLETE",flush=True)


if __name__=="__main__":main()
