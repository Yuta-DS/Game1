import bpy,bmesh
from pathlib import Path
OUT=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'milo_fullres.glb'))
for name in ('Moustache_1','Moustache_-1'):
    obj=bpy.data.objects[name];bm=bmesh.new();bm.from_mesh(obj.data)
    remaining=set(bm.verts);sizes=[]
    while remaining:
        component={remaining.pop()};stack=list(component)
        while stack:
            for e in stack.pop().link_edges:
                for v in e.verts:
                    if v in remaining:remaining.remove(v);component.add(v);stack.append(v)
        sizes.append(len(component))
    print('MOUSTACHE_COMPONENTS',name,sorted(sizes,reverse=True),'bad',sum(not e.is_manifold for e in bm.edges),flush=True)
    bm.free()
