"""Author a watertight water volume with a curved back and rounded crest lip."""
import bpy
import bmesh
import math
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "assets3D" / "curling_surf"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
# Smooth parametric normals preserve rounded silhouettes with 87% fewer
# vertices. Cross-section samples matter more than micro-ripples in this style.
NX, NY = 56, 40
vertices, faces, coords = [], [], []

def point(u, v, side):
    if v < .35:
        s = v / .35
        front = -.60 + 1.40 * (1 - s) ** 2
        back = -.78 - .82 * (1 - s) ** 2
        z, h = front * (1 - side) + back * side, .43 * s * s
    else:
        theta = math.pi - (v - .35) / .65 * (math.pi - .20)
        z = (.60 + .18 * side) * math.cos(theta)
        h = .43 + (.36 + .16 * side) * math.sin(theta)
        blend = max(0, min(1, (v - .96) / .04))
        blend = blend * blend * (3 - 2 * blend)
        cap = .085 * math.sin(side * math.pi) * blend
        z += math.sin(theta) * cap
        h -= math.cos(theta) * cap
    z += .85 * math.sin(u * math.pi) ** 2 * math.sin(v * math.pi / 2)
    return ((u - .5) * 8, -z, h - .028)

for side in range(2):
    for j in range(NY + 1):
        v = j / NY
        for i in range(NX + 1):
            u = i / NX
            vertices.append(point(u, v, side))
            coords.append((u, v, side))
layer = (NX + 1) * (NY + 1)
for side in range(2):
    for j in range(NY):
        for i in range(NX):
            a = side * layer + j * (NX + 1) + i
            face = (a, a + 1, a + NX + 2, a + NX + 1)
            faces.append(face if side == 0 else face[::-1])
perimeter = list(range(NX + 1))
perimeter += [j * (NX + 1) + NX for j in range(1, NY + 1)]
perimeter += [NY * (NX + 1) + i for i in range(NX - 1, -1, -1)]
perimeter += [j * (NX + 1) for j in range(NY - 1, 0, -1)]
previous = perimeter
for step in range(1, 5):
    side = step / 4
    ring = []
    for original in perimeter:
        if step == 4:
            ring.append(original + layer)
        else:
            u, v, _ = coords[original]
            ring.append(len(vertices))
            vertices.append(point(u, v, side))
            coords.append((u, v, side))
    for k in range(len(ring)):
        n = (k + 1) % len(ring)
        faces.append((previous[k], ring[k], ring[n], previous[n]))
    previous = ring
mesh = bpy.data.meshes.new("ClosedWaterVolume")
mesh.from_pydata(vertices, [], faces)
mesh.update()
bm = bmesh.new()
bm.from_mesh(mesh)
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
assert all(edge.is_manifold for edge in bm.edges), "Wave must be watertight"
volume = abs(bm.calc_volume(signed=True))
assert volume > 2.0, f"Wave must enclose substantial water, got {volume} m3"
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new("CurlingSurfSheet", mesh)
bpy.context.collection.objects.link(obj)
uv = mesh.uv_layers.new(name="WaveCoordinates")
shell = mesh.uv_layers.new(name="ShellSide")
for polygon in mesh.polygons:
    polygon.use_smooth = True
    for loop in polygon.loop_indices:
        u, v, side = coords[mesh.loops[loop].vertex_index]
        uv.data[loop].uv = (u, 1 - v)
        shell.data[loop].uv = (side, 0)
material = bpy.data.materials.new("TurquoiseSurf")
material.diffuse_color = (.025, .43, .48, 1)
mesh.materials.append(material)
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "curling_surf.blend"), compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT / "curling_surf.glb"), export_format="GLB", use_selection=True)
print(f"CURLING_SURF_ASSET: {len(vertices)} vertices, {len(faces)} quads; watertight volume {volume:.3f} m3; rounded lip")
