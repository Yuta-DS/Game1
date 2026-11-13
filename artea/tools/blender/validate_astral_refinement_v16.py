"""Independent source/export, guard scale and arch-occlusion checks."""
import csv
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
import validate_astral_underside_v14 as prior
common=prior.common
ROOT=prior.ROOT
OUT=ROOT/"assets3D/mind_spark/celestial_astral_v16"


def objects():
    bpy.context.view_layer.update()
    return [o for o in bpy.context.scene.objects if o.type=="MESH"]


def main():
    manifest=json.loads((OUT/"manifest.json").read_text())
    record=manifest["variant"]
    checks={"previous_source_unchanged":common.sha(ROOT/"assets3D/mind_spark/celestial_astral_v15/source/island_03_3000.blend")==manifest["source_sha256"]}
    bpy.ops.wm.open_mainfile(filepath=str(OUT/record["source"]))
    meshes=objects()
    rows=list(csv.DictReader((OUT/record["bom"]).open()))
    checks["3000_nonempty_editable_meshes"]=len(meshes)==3000 and all(o.data.polygons for o in meshes)
    checks["matching_unique_part_inventory"]={o["part_id"] for o in meshes}=={r["part_id"] for r in rows} and len(rows)==3000
    geometry=common.geometry_checks(meshes);geometry.pop("below_walkable_plane",None)
    checks.update({"source_"+k:v for k,v in geometry.items()})
    rails=[o for o in meshes if o["role"]=="Railing"]
    points=[o.matrix_world@v.co for o in rails for v in o.data.vertices]
    checks["player_scale_rails_and_lamps"]=max(p.z for p in points)*175<3.2
    checks["rails_seated_inside_collision_floor"]=all(.99<math.hypot(p.x,p.y)<1 for p in points)
    directions=[Vector(d) for d in record["route_directions_blender"]]
    checks["bridge_clearance"]=not any(p.dot(d)>.72 and abs(p.x*d.y-p.y*d.x)<22/175 for p in points for d in directions)
    tree=prior.surface(rails)
    missed=[];samples=0
    for i in range(1440):
        a=(i+.5)*math.tau/1440;d=Vector((math.cos(a),math.sin(a),0))
        if any(d.dot(v)>.72 and abs(d.x*v.y-d.y*v.x)<23/173.7 for v in directions):continue
        samples+=1
        if tree.ray_cast(d*.98+Vector((0,0,1.36/175)),d,.03)[0] is None:missed.append(i)
    checks["continuous_hand_edge"]=not missed
    # A silhouette/ray check against the structures responsible for the v15
    # defect. This is not a claim of full mechanical collision simulation.
    blockers=prior.surface([o for o in meshes if o["category"] in ("01_Rock_Profile","08_Resolved_Load_Path","09_Outboard_Observation_Turrets")])
    occluded=[]
    for side in (-1,1):
        for y,z in ((.04,-.17),(-.06,-.22),(.14,-.22),(.04,-.43)):
            hit=blockers.ray_cast(Vector((side*1.8,y,z)),Vector((-side,0,0)),.88)
            if hit[0] is not None:occluded.append([side,y,z])
    checks["arch_and_vent_clear_of_old_rock_and_transfer_beam"]=not occluded
    rock=prior.surface([o for o in meshes if o["category"]=="01_Rock_Profile"])
    rock_occlusions=[]
    for side in (-1,1):
        for i in range(11):
            u=-.28+i*.056
            top=-.615+.40*math.sqrt(1-(u/.331)**2)
            for j in range(13):
                z=-1.40+(top+1.40)*j/12
                if rock.ray_cast(Vector((side*1.8,.04+u,z)),Vector((-side,0,0)),1.25)[0] is not None:
                    rock_occlusions.append([side,u,z])
    checks["286_interior_samples_have_clear_rock_recesses"]=not rock_occlusions
    piers=prior.surface([o for o in meshes if "PierCourse" in o.name])
    checks["all_four_piers_reach_their_capitals"]=all(piers.find_nearest(Vector((side*.8875,.04+u,-.649)))[3]<.003
        for side in (-1,1) for u in (-.39375,.39375))
    checks["eight_separate_motion_assemblies"]=all(any(o["assembly"]==name for o in meshes) for name in record["moving_assemblies"]) and len(record["moving_assemblies"])==8
    source=common.measurements([o for o in meshes if o["role"]!="Paving"])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OUT/record["file"]))
    runtime=objects();measure=common.measurements(runtime)
    checks["13_runtime_meshes_including_moving_parts"]=len(runtime)==13
    checks["source_export_coverage"]=common.close(source,measure)
    checks["restored_540k_architecture_budget"]=measure["triangles"]<540000
    checks["recorded_triangles"]=measure["triangles"]==record["runtime_triangles"]
    geometry=common.geometry_checks(runtime);geometry.pop("below_walkable_plane",None)
    checks.update({"runtime_"+k:v for k,v in geometry.items()})
    result={"passed":all(checks.values()),"checks":checks,"runtime":measure,"rail_samples":samples,"missing_samples":missed,"occluded_arch_samples":occluded,"interior_rock_occlusions":rock_occlusions,
            "scope":"Geometry, export, scale, edge coverage and targeted visual occlusion. Gameplay collision and crank kinematics tested in Godot."}
    (OUT/"validation_report.json").write_text(json.dumps(result,indent=2)+"\n")
    print("ASTRAL_V16_VALIDATION",json.dumps(result),flush=True)
    assert result["passed"],[k for k,v in checks.items() if not v]


if __name__=="__main__":main()
