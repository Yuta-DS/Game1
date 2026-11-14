"""Independent v13 geometry, elevated-turret clearance and preservation audit."""
import csv
import json
import math
import sys
from collections import Counter
from pathlib import Path
import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
import validate_celestial_islands_v09 as common
ROOT=common.ROOT
OUT=ROOT/"assets3D/mind_spark/celestial_astral_v13"


def meshes():
    bpy.context.view_layer.update()
    return [o for o in bpy.context.scene.objects if o.type=="MESH"]


def geometry(objects,record,prefix):
    checks=common.geometry_checks(objects)
    del checks["below_walkable_plane"]
    rails=[o for o in objects if o.get("role")=="Railing" or o.name.startswith("Railing_")]
    rail_points=[o.matrix_world@v.co for o in rails for v in o.data.vertices]
    high=[o.matrix_world@v.co for o in objects if o not in rails for v in o.data.vertices if (o.matrix_world@v.co).z>.0004]
    directions=[Vector(d) for d in record["route_directions_blender"]]
    def route_clear(points):
        return not any(p.dot(d)>.72 and abs(p.x*d.y-p.y*d.x)<record["route_half_width"] for p in points for d in directions)
    checks.update(railing_outside_disc=bool(rail_points) and min(math.hypot(p.x,p.y) for p in rail_points)>1.003,
        rail_bridge_openings=route_clear(rail_points),turrets_outside_playable_disc=bool(high) and min(math.hypot(p.x,p.y) for p in high)>1.03,
        turret_bridge_clearance=route_clear(high),turret_height_limit=bool(high) and max(p.z for p in high)<.55)
    return {prefix+"_"+key:value for key,value in checks.items()}


def main():
    manifest=json.loads((OUT/"manifest.json").read_text());record=manifest["variant"]
    checks={"preserved_v11_and_verdant_assets":all(common.sha(ROOT/p)==h for p,h in manifest["source_checksums"].items())}
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/"assets3D/mind_spark/celestial_islands_v11/source/island_03_3000.blend"))
    old=meshes()
    old_arch=common.measurements([o for o in old if o["category"]=="04_Reference_Enginehouses"])
    old_rails=common.measurements([o for o in old if o["role"]=="Railing"])
    bpy.ops.wm.open_mainfile(filepath=str(OUT/record["source"]));objects=meshes()
    rows=list(csv.DictReader((OUT/record["bom"]).open()))
    ids=[o.get("part_id","") for o in objects]
    checks.update(exactly_3000_nonempty_parts=len(objects)==3000 and all(len(o.data.polygons)>0 for o in objects),
        unique_ids=len(set(ids))==3000 and all(p.startswith("MS13-I03-P") for p in ids),
        matching_inventory=len(rows)==3000 and {r["part_id"] for r in rows}==set(ids),
        matching_kind_counts=dict(Counter(o["component_kind"] for o in objects))==record["component_kinds"],
        matching_inventory_triangles=sum(int(r["triangles"]) for r in rows)==sum(len(o.data.polygons) for o in objects),
        original_reference_arches_and_machines=common.close(old_arch,common.measurements([o for o in objects if o["category"]=="04_Reference_Enginehouses"])),
        original_balustrades=common.close(old_rails,common.measurements([o for o in objects if o["role"]=="Railing"])),
        two_outboard_turrets=len({o["assembly"] for o in objects if o["category"]=="09_Outboard_Observation_Turrets"})==2,
        four_flying_buttress_assemblies=len({o["assembly"] for o in objects if o["category"]=="08_Astral_Flying_Buttresses" and "flying rib" in o["assembly"]})==4,
        elevated_nonrail_geometry_is_only_turrets=all(o["role"]=="Railing" or o["category"]=="09_Outboard_Observation_Turrets"
            for o in objects if any((o.matrix_world@v.co).z>.0004 for v in o.data.vertices)))
    checks.update(geometry(objects,record,"source"))
    # Each fore/aft rib head must meet a continuous turret bearing beam.
    bearing_ok=True
    for side,label in ((-1,"West"),(1,"East")):
        bearers=[o for o in objects if o["assembly"]==label+" longitudinal turret bearing"]
        points=[o.matrix_world@v.co for o in bearers for v in o.data.vertices]
        if not points:
            bearing_ok=False
            continue
        low=[min(p[k] for p in points) for k in range(3)]
        high=[max(p[k] for p in points) for k in range(3)]
        bearing_ok=bearing_ok and all(all(low[k] <= p[k] <= high[k] for k in range(3))
            for p in ((side*1.19,-.31,-.43),(side*1.19,.36,-.43)))
    checks["all_four_flying_rib_heads_meet_turret_bearers"]=bearing_ok
    source=common.measurements([o for o in objects if o["role"]!="Paving"])
    paving=common.measurements([o for o in objects if o["role"]=="Paving"])
    checks["distinct_citadel_bounds"]=source["bounds"][0][2]<-2.10 and source["bounds"][1][2]>.48 and source["bounds"][1][0]-source["bounds"][0][0]>3.0
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OUT/record["file"]));runtime=meshes()
    measure=common.measurements(runtime);checks.update(geometry(runtime,record,"runtime"))
    checks.update(five_batched_families=len(runtime)==5,source_runtime_coverage=common.close(source,measure),
        recorded_triangle_count=measure["triangles"]==record["runtime_triangles"],triangle_budget=measure["triangles"]<540000)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/manifest["shared_paving"].removeprefix("res://")))
    shared=common.measurements(meshes());checks["shared_paving_unchanged"]=common.close(paving,shared)
    result={"checks":checks,"passed":all(checks.values()),"runtime":measure,"visible_triangles":measure["triangles"]+shared["triangles"]}
    (OUT/"validation_report.json").write_text(json.dumps(result,indent=2)+"\n")
    print("ASTRAL_V13_AUDIT",json.dumps(result),flush=True)
    assert result["passed"]


if __name__=="__main__":main()
