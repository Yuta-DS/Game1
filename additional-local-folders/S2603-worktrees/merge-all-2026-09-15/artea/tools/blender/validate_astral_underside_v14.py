"""Independent v14 preservation, geometry, inventory and seating checks."""
import csv
import json
import math
import sys
from collections import Counter
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0,str(Path(__file__).resolve().parent))
import validate_astral_castle_v13 as castle
common=castle.common
ROOT=common.ROOT
OUT=ROOT/"assets3D/mind_spark/celestial_astral_v14"


def surface(objects):
    vs,fs=[],[]
    for obj in objects:
        offset=len(vs)
        vs.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        fs.extend(tuple(offset+i for i in p.vertices) for p in obj.data.polygons)
    return BVHTree.FromPolygons(vs,fs,all_triangles=True)


def nearby(tree,points,tolerance):
    return all((hit:=tree.find_nearest(Vector(p)))[0] is not None and hit[3]<=tolerance for p in points)


def main():
    manifest=json.loads((OUT/"manifest.json").read_text());record=manifest["variant"]
    checks={"previous_v13_verdant_and_paving_files_unchanged":all(common.sha(ROOT/p)==h for p,h in manifest["source_checksums"].items())}
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/"assets3D/mind_spark/celestial_astral_v13/source/island_03_3000.blend"))
    old=castle.meshes()
    categories=sorted({o["category"] for o in old})
    previous={c:common.measurements([o for o in old if o["category"]==c]) for c in categories}
    old_total=sum(len(o.data.polygons) for o in old)
    bpy.ops.wm.open_mainfile(filepath=str(OUT/record["source"]));objects=castle.meshes()
    rows=list(csv.DictReader((OUT/record["bom"]).open()))
    ids=[o.get("part_id","") for o in objects]
    checks.update(exactly_3000_nonempty_parts=len(objects)==3000 and all(len(o.data.polygons)>0 for o in objects),
        unique_ids=len(set(ids))==3000 and all(p.startswith("MS14-I03-P") for p in ids),
        matching_inventory=len(rows)==3000 and {r["part_id"] for r in rows}==set(ids),
        matching_component_kinds=dict(Counter(o["component_kind"] for o in objects))==record["component_kinds"],
        matching_inventory_triangles=sum(int(r["triangles"]) for r in rows)==sum(len(o.data.polygons) for o in objects))
    for c in categories:
        checks["preserved_"+c]=common.close(previous[c],common.measurements([o for o in objects if o["category"]==c]))
    checks.update(castle.geometry(objects,record,"source"))
    added=[o for o in objects if o["category"] not in categories]
    checks["only_below_court_additions"]=max((o.matrix_world@v.co).z for o in added for v in o.data.vertices)<-.64
    checks["new_geometry_fully_accounted"]=sum(len(o.data.polygons) for o in added)==record["new_underside_triangles"]==sum(len(o.data.polygons) for o in objects)-old_total
    checks["two_lateral_engine_assemblies"]=len({o["assembly"] for o in added if o["category"]=="12_Lateral_Flywheel_Engines"})==2
    # Geometry witnesses: deck, skid and pressure feet share actual contact planes.
    deck=surface([o for o in added if o["assembly"]=="Continuous oval service deck"])
    checks["side_skids_seated_on_service_deck"]=nearby(deck,[(x,.04,-1.4825) for x in (-.61,.61)],.001)
    checks["rear_sill_seated_on_service_deck"]=nearby(deck,[(x,.49,-1.4825) for x in (-.18,.18)],.001)
    brackets=surface([o for o in added if o["assembly"].startswith("Keel-to-gallery bracket")])
    collar=surface([o for o in objects if o["assembly"]=="Keel crown bearing bands"])
    inner=[(.045+.17*math.cos(j*math.tau/8),.085+.17*math.sin(j*math.tau/8),-1.57) for j in range(8)]
    outer=[(.78*math.cos(j*math.tau/8),.04+.57*math.sin(j*math.tau/8),-1.51) for j in range(8)]
    checks["eight_gallery_brackets_meet_existing_keel_socket"]=nearby(collar,inner,.03) and nearby(brackets,inner,.028)
    checks["eight_gallery_brackets_meet_service_deck"]=nearby(deck,outer,.03) and nearby(brackets,outer,.03)
    cradles=surface([o for o in added if o["assembly"]=="Aft condenser cradle"])
    cradle_roots=[(.045+s*.17,.085,-1.57) for s in (-1,1)]
    checks["both_rear_cradles_seat_in_offset_keel_collar"]=nearby(collar,cradle_roots,.03) and nearby(cradles,cradle_roots,.025)
    # Supply and return flange endpoints are on the cylinder crown/drain fittings.
    lateral=surface([o for o in added if o["category"]=="12_Lateral_Flywheel_Engines"])
    network=surface([o for o in added if o["category"]=="14_Steam_And_Return_Network"])
    ports=[(s*.61,.04+dy,z) for s in (-1,1) for dy,z in ((-.055,-.77),(.055,-1.015))]
    checks["four_side_engine_ports_meet_supply_return_lines"]=nearby(lateral,ports,.033) and nearby(network,ports,.02)
    rear=surface([o for o in added if o["category"]=="13_Rear_Condenser_Bank"])
    ports=[(x,.49,z) for x in (-.18,.18) for z in (-.907,-1.36)]
    checks["four_rear_condenser_ports_meet_headers"]=nearby(rear,ports,.015) and nearby(network,ports,.02)
    source=common.measurements([o for o in objects if o["role"]!="Paving"])
    paving=common.measurements([o for o in objects if o["role"]=="Paving"])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OUT/record["file"]));runtime=castle.meshes()
    measure=common.measurements(runtime);checks.update(castle.geometry(runtime,record,"runtime"))
    checks.update(five_runtime_batches=len(runtime)==5,source_runtime_coverage=common.close(source,measure),
        triangle_budget_unchanged=measure["triangles"]<540000,recorded_triangles=measure["triangles"]==record["runtime_triangles"])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/manifest["shared_paving"].removeprefix("res://")))
    shared=common.measurements(castle.meshes());checks["shared_paving_geometry_unchanged"]=common.close(paving,shared)
    result={"passed":all(checks.values()),"checks":checks,"runtime":measure,
        "visible_triangles":measure["triangles"]+shared["triangles"],
        "scope":"Geometry/seating/clearance audit, not an engineering simulation or proof of playable maintenance access."}
    (OUT/"validation_report.json").write_text(json.dumps(result,indent=2)+"\n")
    print("ASTRAL_V14_AUDIT",json.dumps(result),flush=True)
    assert result["passed"],[k for k,v in checks.items() if not v]


if __name__=="__main__":main()
