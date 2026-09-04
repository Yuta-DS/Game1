"""Independent editable-source, export, scale and corridor validation."""
import csv
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import validate_astral_underside_v14 as prior

common=prior.common
ROOT=prior.ROOT
OUT=ROOT/"assets3D/mind_spark/celestial_dawn_v17"


def meshes():
    bpy.context.view_layer.update()
    return [o for o in bpy.context.scene.objects if o.type=="MESH"]


def main():
    manifest=json.loads((OUT/"manifest.json").read_text());record=manifest["variant"]
    checks={"v11_source_unchanged":common.sha(ROOT/"assets3D/mind_spark/celestial_islands_v11/source/island_04_3000.blend")==manifest["source_sha256"]}
    bpy.ops.wm.open_mainfile(filepath=str(OUT/"source/island_04_3000.blend"))
    source=meshes();rows=list(csv.DictReader((OUT/"bom/island_04_parts.csv").open()))
    checks["3000_nonempty_editable_meshes"]=len(source)==3000 and all(o.data.polygons for o in source)
    checks["unique_matching_part_inventory"]=len(rows)==3000 and {o["part_id"] for o in source}=={r["part_id"] for r in rows}
    geometry=common.geometry_checks(source);geometry.pop("below_walkable_plane",None)
    checks.update({"source_"+k:v for k,v in geometry.items()})
    rails=[o for o in source if o.get("category")=="05_Player_Scale_Dawn_Balustrade"]
    points=[o.matrix_world@v.co for o in rails for v in o.data.vertices]
    checks["player_scale_guard"]=bool(points) and max(p.z for p in points)*120<1.6
    checks["guard_seated_inside_floor"]=all(.985<math.hypot(p.x,p.y)<1.0 for p in points)
    directions=[Vector(v) for v in record["route_directions_blender"]]
    checks["two_bridge_approaches_clear"]=not any(p.dot(d)>.72 and abs(p.x*d.y-p.y*d.x)<22/120 for p in points for d in directions)
    tree=prior.surface(rails);missing=[];samples=0
    for i in range(960):
        a=(i+.5)*math.tau/960;d=Vector((math.cos(a),math.sin(a),0))
        if any(d.dot(v)>.72 and abs(d.x*v.y-d.y*v.x)<23/120 for v in directions):continue
        samples+=1
        if tree.ray_cast(d*.98+Vector((0,0,1.36/120)),d,.03)[0] is None:missing.append(i)
    checks["continuous_guard_outside_approaches"]=not missing
    fixed=common.measurements([o for o in source if o.get("role")!="Paving"])
    checks["four_separate_motion_assemblies"]=len(record["moving_assemblies"])==4 and all(any(o.get("assembly")==name for o in source) for name in record["moving_assemblies"])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OUT/"island_04.glb"))
    runtime=meshes();measurement=common.measurements(runtime)
    checks["nine_runtime_meshes"]=len(runtime)==9
    checks["source_export_coverage"]=common.close(fixed,measurement)
    checks["under_540k_triangles"]=measurement["triangles"]<540000
    checks["recorded_triangles"]=measurement["triangles"]==record["runtime_triangles"]
    geometry=common.geometry_checks(runtime);geometry.pop("below_walkable_plane",None)
    checks.update({"runtime_"+k:v for k,v in geometry.items()})
    result={"passed":all(checks.values()),"checks":checks,"runtime":measurement,
        "guard_samples":samples,"missing_guard_samples":missing,
        "scope":"Editable/export geometry, route openings, human scale and continuous visual guard."}
    (OUT/"validation_report.json").write_text(json.dumps(result,indent=2)+"\n")
    print("DAWN_V17_VALIDATION",json.dumps(result),flush=True)
    assert result["passed"],[k for k,v in checks.items() if not v]


if __name__=="__main__":main()
