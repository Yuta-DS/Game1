"""Independent GLB reimport, silhouette, clearance and source-preservation audit."""
from array import array
import hashlib
import json
import math
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets3D/mind_spark/celestial_islands_v08"


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    manifest=json.loads((OUT/"manifest.json").read_text())
    result={"checks":{},"assets":[]}
    result["checks"]["v07_master_unchanged"]=sha(ROOT/"assets3D/mind_spark/celestial_condenser_v07/source/celestial_condenser_v07.blend")==manifest["source_checksums"]["v07_master"]
    result["checks"]["v07_runtime_unchanged"]=sha(ROOT/"assets3D/mind_spark/celestial_land_runtime/celestial_land.glb")==manifest["source_checksums"]["v07_runtime"]
    profiles=[];total=0;paving_triangles=0
    for item in [{"id":0,"file":"shared_paving.glb"}]+manifest["variants"]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(OUT/item["file"]))
        objects=[o for o in bpy.data.objects if o.type=="MESH"]
        triangles=sum(len(o.data.polygons) for o in objects)
        checks={
            "expected_mesh_count":len(objects)==(1 if item["id"]==0 else 4),
            "finite_vertices":all(math.isfinite(c) for o in objects for v in o.data.vertices for c in v.co),
            "triangles_only":all(len(p.vertices)==3 for o in objects for p in o.data.polygons),
            "positive_areas":all(p.area>1e-20 for o in objects for p in o.data.polygons),
            "no_repairs_needed":not any(o.data.validate() for o in objects),
            "clear_gameplay_plane":max((o.matrix_world@v.co).z for o in objects for v in o.data.vertices)<.0004,
        }
        if item["id"]:
            checks["export_count_matches"]=triangles==item["triangles"]
            checks["triangle_budget"]=triangles<350000
            rock=next(o for o in objects if o.name.startswith("Rock_v08"))
            coordinates=array("f",[c for v in rock.data.vertices for c in v.co])
            profiles.append(hashlib.sha256(coordinates.tobytes()).hexdigest())
            total+=triangles
        else:
            paving_triangles=triangles
        result["assets"].append({"file":item["file"],"triangles":triangles,"checks":checks})
    result["checks"]["six_distinct_geometric_profiles"]=len(set(profiles))==6
    result["checks"]["whole_family_triangle_budget"]=total+6*paving_triangles<1500000
    result["visible_family_triangles"]=total+6*paving_triangles
    result["shared_paving_triangles"]=paving_triangles
    result["passed"]=all(result["checks"].values()) and all(all(a["checks"].values()) for a in result["assets"])
    (OUT/"validation_report.json").write_text(json.dumps(result,indent=2)+"\n")
    print("V08_VALIDATION: "+json.dumps(result),flush=True)
    assert result["passed"]


if __name__=="__main__":main()
