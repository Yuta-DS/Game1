"""Reusable source libraries with metre-scale local origins, no runtime payload."""
import json
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"assets3D/mind_spark/celestial_astral_v16"


def main():
    bpy.ops.wm.open_mainfile(filepath=str(OUT/"source/island_03_3000.blend"))
    objects=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    destination=OUT/"modules";destination.mkdir(exist_ok=True)
    (destination/".gdignore").touch()
    selections=[
        ("promenade_panel",lambda o:o.get("assembly")=="Reusable five metre panel 001",(173.7/175,0,0)),
        ("steam_generator",lambda o:o.get("assembly","").startswith("East") and o.get("category")=="12_Operational_Engine",(.84,.04,-1.26)),
        ("carved_engine_chamber",lambda o:o.get("assembly","").startswith("East") and o.get("category")=="16_Integrated_Engine_Chambers",(.84,.04,-1.469)),
        ("curved_load_cradle",lambda o:o.get("assembly","").startswith("East") and o.get("category")=="08_Resolved_Load_Path",(.215,.085,-1.57)),
    ]
    catalog=[]
    for name,predicate,origin in selections:
        members=[o for o in objects if predicate(o)]
        assert members,name
        collection=bpy.data.collections.new(name)
        copies=[]
        for obj in members:
            copy=obj.copy();copy.data=obj.data.copy()
            collection.objects.link(copy)
            copy.matrix_world=Matrix.Scale(175,4)@Matrix.Translation(-Vector(origin))@obj.matrix_world
            copies.append(copy)
        bpy.data.libraries.write(str(destination/(name+".blend")),{collection},compress=True)
        catalog.append({"name":name,"file":name+".blend","editable_objects":len(copies),
                        "units":"metres","up_axis":"Z","source_origin":origin,
                        "usage":"Append the named Collection in Blender. Place/rotate/scale the collection as one module; internal meshes remain editable."})
        for copy in copies:
            data=copy.data;bpy.data.objects.remove(copy,do_unlink=True)
            if data.users==0:bpy.data.meshes.remove(data)
        bpy.data.collections.remove(collection)
    (destination/"catalog.json").write_text(json.dumps(catalog,indent=2)+"\n")
    print("ASTRAL_V16_REUSABLE_MODULES",json.dumps(catalog),flush=True)


if __name__=="__main__":main()
