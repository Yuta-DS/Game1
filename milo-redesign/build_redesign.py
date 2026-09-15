"""Isolated AnyCreature + Blender redesign. Never writes the source game assets."""
import json
import math
from pathlib import Path
import bpy
from mathutils import Vector, Quaternion, Matrix
from mathutils.kdtree import KDTree

OUT = Path(__file__).resolve().parent
SOURCE = OUT.parent / 'artea/assets3D/characters/milo_exact_target_parts.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene = bpy.context.scene
scene.render.fps = 24
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
rig.data.pose_position = 'REST'
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
    track.mute = True
for bone in rig.pose.bones:
    bone.matrix_basis = Matrix.Identity(4)
bpy.context.view_layer.update()
parts = [o for o in scene.objects if o.type == 'MESH' and not o.name.startswith('RENDER_ONLY')]

def select(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

def color(mat, code, rough=.7, metal=0):
    srgb = [int(code[i:i+2], 16)/255 for i in (0,2,4)]
    rgb = [c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4 for c in srgb]
    mat.diffuse_color = (*rgb, 1)
    mat.roughness, mat.metallic = rough, metal
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*rgb, 1)
    shader.inputs['Roughness'].default_value = rough
    shader.inputs['Metallic'].default_value = metal
    return mat

palette = {
    'Target Mayor Blue': ('405775', .85, 0),
    'Target Mayor Tailored Panel Blue': ('405775', .85, 0),
    'Target Mayor Lapel Blue': ('536887', .78, 0),
    'Target Dark Navy Pocket': ('3C506B', .85, 0),
    'Target Dark Navy Seam': ('28394D', .85, 0),
    'Target Lavender': ('956A8C', .83, 0),
    'Target Lavender Highlight': ('A47C9A', .8, 0),
    'Target Lavender Seam': ('684F6A', .85, 0),
    'Target Mint Piping': ('E5D7B9', .72, 0),
    'Target Gold': ('DCC28C', .28, .65),
    'Target Shoes': ('684939', .35, 0),
    'Target Trousers': ('343B49', .82, 0),
    'Mayor Cane Dark Wood': ('62442E', .4, 0),
}
for name, values in palette.items():
    color(bpy.data.materials[name], *values)
ivory = color(bpy.data.materials.new('Redesign Ivory Silk'), 'E5D7B9', .55)
enamel = color(bpy.data.materials.new('Redesign Plum Enamel'), '765779', .24)
gold = bpy.data.materials['Target Gold']
for name in ['Tie', 'GoldTieClip']:
    bpy.data.objects[name].data.materials.clear()
    bpy.data.objects[name].data.materials.append(ivory)

# Bring the facial shell under the layered mask/brows. The old side view exposed
# daylight behind these cards; a broad front-only sculpt retains the rear silhouette.
head = bpy.data.objects['Head']
inverse_head = head.matrix_world.inverted()
for vertex in head.data.vertices:
    point = head.matrix_world @ vertex.co
    if point.y < -.06:
        vertical = math.exp(-((point.z-1.53)/.29)**4)
        horizontal = max(0, 1-(abs(point.x)/.43)**4)
        facing = min(1, max(0, (-point.y-.06)/.22))
        point.y = max(-.342, point.y - .025 * vertical * horizontal * facing)
        vertex.co = inverse_head @ point

# Give the recessed speech socket real depth behind the existing mouth states.
socket = bpy.data.objects['MouthSocket']
for vertex in socket.data.vertices:
    point = socket.matrix_world @ vertex.co
    if point.y > -.43:
        point.y += .045
        vertex.co = socket.matrix_world.inverted() @ point

# Preserve original rest-world matrices and weight fields before replacing sleeves.
original_sleeves = {side: bpy.data.objects['Sleeve_' + side] for side in ['L','R']}
before = set(scene.objects)
bpy.ops.import_scene.gltf(filepath=str(OUT / 'tailoring.glb'))
imported = set(scene.objects) - before
new_sleeves = []
for obj in list(imported):
    if obj.type != 'MESH' or not any(m and m.name.startswith('sleeve') for m in obj.data.materials):
        continue
    # glTF duplicates vertices at creases: loose-island separation would fragment
    # each sleeve. Split by material and anatomical side instead.
    for side in ['L', 'R']:
        vertices, faces, remap = [], [], {}
        for poly in obj.data.polygons:
            if not obj.data.materials[poly.material_index].name.startswith('sleeve'):
                continue
            coords = [obj.matrix_world @ obj.data.vertices[i].co for i in poly.vertices]
            positive = sum(v.x for v in coords) > 0
            if positive != (side == 'R'):
                continue
            face = []
            for index, coord in zip(poly.vertices, coords):
                if index not in remap:
                    remap[index] = len(vertices)
                    vertices.append(coord)
                face.append(remap[index])
            faces.append(face)
        assert vertices, side
        mesh = bpy.data.meshes.new('AnyCreatureSleeve_' + side)
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        sleeve = bpy.data.objects.new('AnyCreatureSleeve_' + side, mesh)
        scene.collection.objects.link(sleeve)
        donor = original_sleeves[side]
        kd = KDTree(len(donor.data.vertices))
        for v in donor.data.vertices:
            kd.insert(donor.matrix_world @ v.co, v.index)
        kd.balance()
        sleeve.vertex_groups.clear()
        for g in donor.vertex_groups:
            sleeve.vertex_groups.new(name=g.name)
        for v in sleeve.data.vertices:
            nearest = kd.find_n(v.co, 4)
            factors = [1/max(distance, .002)**2 for _,_,distance in nearest]
            weights = {}
            for (_, index, _), factor in zip(nearest, factors):
                for group in donor.data.vertices[index].groups:
                    name = donor.vertex_groups[group.group].name
                    weights[name] = weights.get(name, 0) + factor * group.weight
            total = sum(weights.values())
            assert total > 0
            for name, weight in weights.items():
                sleeve.vertex_groups[name].add([v.index], weight/total, 'REPLACE')
        sleeve.data.materials.clear()
        sleeve.data.materials.append(bpy.data.materials['Target Mayor Blue'])
        for poly in sleeve.data.polygons:
            poly.use_smooth = True
        # Keep vertex colors in the editable source but PBR material is authoritative.
        sleeve.parent = rig
        sleeve.matrix_parent_inverse = rig.matrix_world.inverted()
        modifier = sleeve.modifiers.new('Milo shared deform rig', 'ARMATURE')
        modifier.object = rig
        donor.name = 'SOURCE_SLEEVE_' + side
        sleeve.name = 'Sleeve_' + side
        sleeve['geometry_source'] = 'AnyCreature tailoring.json'
        sleeve['weight_transfer'] = '4-nearest inverse-square normalized original sleeve weights'
        new_sleeves.append(sleeve)
        parts.remove(donor)
        bpy.data.objects.remove(donor, do_unlink=True)
        parts.append(sleeve)
for obj in imported:
    if obj not in new_sleeves and obj.name in bpy.data.objects:
        bpy.data.objects.remove(obj, do_unlink=True)
assert len(new_sleeves) == 2

# Softer sculptural edges, retaining the topology and shape-state names required by Godot.
for obj in parts:
    if obj.name.startswith(('MoustachePad', 'CheekUpper', 'CheekLower', 'Nose', 'CoatLapel', 'PocketFlap')):
        select(obj)
        bevel = obj.modifiers.new('Soft crafted edge', 'BEVEL')
        bevel.width = .008 if 'Moustache' not in obj.name else .014
        bevel.segments = 3
        # Apply before armature so bevel geometry receives interpolated weights.
        bpy.ops.object.modifier_move_up(modifier=bevel.name)
        bpy.ops.object.modifier_apply(modifier=bevel.name)
        for poly in obj.data.polygons:
            poly.use_smooth = True

def bind(obj, name, material, bone='chest'):
    obj.name = name
    select(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1, 'REPLACE')
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.matrix_world = world
    modifier = obj.modifiers.new('Milo shared deform rig', 'ARMATURE')
    modifier.object = rig
    for poly in obj.data.polygons:
        poly.use_smooth = True
    parts.append(obj)
    return obj

# Replace polygonal spectacle rims with thinner round wire without changing eye clearance.
for side in ['L', 'R']:
    old = bpy.data.objects['GlassesRing_' + side]
    loc = old.location.copy()
    parts.remove(old)
    bpy.data.objects.remove(old, do_unlink=True)
    bpy.ops.mesh.primitive_torus_add(major_radius=.14, minor_radius=.0065,
        major_segments=48, minor_segments=8, location=loc, rotation=(math.pi/2,0,0))
    bind(bpy.context.object, 'GlassesRing_' + side, gold, 'head')

# Shrink the four large uniform buttons to let face and compass pin lead.
for obj in parts:
    if obj.name.startswith('Button_'):
        for v in obj.data.vertices:
            v.co *= .66
medallion = bpy.data.objects['Medallion']
medallion.data.materials.clear()
medallion.data.materials.append(enamel)
center = medallion.location.copy()
for angle, label in [(0,'North'),(math.pi/2,'East'),(math.pi,'South'),(3*math.pi/2,'West')]:
    # A shallow four-point compass motif with a clear gold / plum value separation.
    x, z = math.sin(angle), math.cos(angle)
    mesh = bpy.data.meshes.new('Compass' + label)
    px, py, pz = center.x, center.y-.014, center.z
    verts = [(px,py,pz), (px+x*.028-z*.007,py,pz+z*.028+x*.007),
             (px+x*.049,py-.002,pz+z*.049), (px+x*.028+z*.007,py,pz+z*.028-x*.007)]
    mesh.from_pydata(verts, [], [(0,1,2,3)])
    obj = bpy.data.objects.new('Compass' + label, mesh)
    scene.collection.objects.link(obj)
    bind(obj, 'Compass' + label, gold)

# New clips use actual deform bones, not non-exporting Blender control constraints.
rig.data.pose_position = 'POSE'
def reset_pose():
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
        pb.rotation_mode = 'QUATERNION'

def world_rotation(name, axis, degrees):
    pb = rig.pose.bones[name]
    basis = (rig.matrix_world @ pb.bone.matrix_local).to_quaternion()
    q = Quaternion(Vector(axis), math.radians(degrees))
    pb.rotation_quaternion = pb.rotation_quaternion @ (basis.inverted() @ q @ basis)

# A fresh Godot import removes the source's immutable elbow/wrist tracks. Author
# real, modest stride-timed articulation rather than retaining dummy constant keys.
walk = bpy.data.actions['Milo_Walking']
bag = walk.layers[0].strips[0].channelbag(walk.slots[0])
for bone_name, amplitude, offset in [('lowerarm.l',4,0), ('wrist.l',2,.08),
                                    ('lowerarm.r',8,.5), ('wrist.r',3,.58),
                                    ('hand.r',3,.62)]:
    basis = (rig.matrix_world @ rig.data.bones[bone_name].matrix_local).to_quaternion()
    curve_path = 'pose.bones["' + bone_name + '"].rotation_quaternion'
    curves = {c.array_index:c for c in bag.fcurves if c.data_path == curve_path}
    assert len(curves) == 4, bone_name
    for curve in curves.values():
        curve.keyframe_points.clear()
    start, end = 0, 25.60000228881836
    for i in range(33):
        phase = i/32
        angle = amplitude * math.sin(2*math.pi*(phase+offset))
        q = basis.inverted() @ Quaternion(Vector((1,0,0)), math.radians(angle)) @ basis
        for component, curve in curves.items():
            point = curve.keyframe_points.insert(start+(end-start)*phase, q[component])
            point.interpolation = 'BEZIER'
            point.handle_left_type = point.handle_right_type = 'AUTO_CLAMPED'
    for curve in curves.values():
        curve.update()

new_actions = []
for name, seconds in [('Milo_Redesign_Idle',3.2), ('Milo_Redesign_Welcome',2.4), ('Milo_Redesign_Listen',3.0)]:
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    n = round(seconds*24)
    for frame in range(n+1):
        scene.frame_set(frame)
        reset_pose()
        t = frame/n
        envelope = math.sin(math.pi*t)**2
        if name.endswith('Idle'):
            world_rotation('head', (1,0,0), math.sin(2*math.pi*t)*1.2)
        elif name.endswith('Welcome'):
            world_rotation('upperarm.r', (1,0,0), -28*envelope)
            world_rotation('lowerarm.r', (1,0,0), -24*envelope)
            world_rotation('hand.r', (0,0,1), -16*envelope)
            world_rotation('head', (1,0,0), 3*envelope)
        else:
            world_rotation('head', (0,1,0), -5*envelope)
            world_rotation('head', (1,0,0), 4*envelope*math.sin(2*math.pi*t))
        for pb in rig.pose.bones:
            pb.keyframe_insert(data_path='rotation_quaternion', frame=frame)
            pb.keyframe_insert(data_path='location', frame=frame)
            pb.keyframe_insert(data_path='scale', frame=frame)
    new_actions.append(action)

keep = {'Idle','Walking_A','Milo_Walking','Running_A','Cheer','1H_Ranged_Aiming',
        '2H_Ranged_Aiming','Use_Item','Interact'} | {a.name for a in new_actions}
rig.animation_data.action = new_actions[0]
if new_actions[0].slots:
    rig.animation_data.action_slot = new_actions[0].slots[0]
for action in list(bpy.data.actions):
    if action.name not in keep:
        bpy.data.actions.remove(action)
for action in bpy.data.actions:
    action.use_fake_user = True
rig.show_in_front = True
rig['cane_hand'] = 'hand.l (viewer right); free gesture hand = hand.r'
rig['review_status'] = 'Isolated redesign; not installed into the live game'
scene.frame_set(0)
reset_pose()
bpy.context.view_layer.update()
repaired_meshes = []
for obj in parts:
    if obj.data.validate(verbose=False):
        repaired_meshes.append(obj.name)
    obj.data.update()
    deform_groups = [g for g in obj.vertex_groups if g.name in rig.data.bones]
    if len(deform_groups) == 1:
        # Bevel-generated corner vertices occasionally lose their rigid group.
        deform_groups[0].add(list(range(len(obj.data.vertices))), 1, 'REPLACE')
    else:
        for vertex in obj.data.vertices:
            memberships = [(g.group, g.weight) for g in vertex.groups
                           if obj.vertex_groups[g.group].name in rig.data.bones]
            total = sum(weight for _, weight in memberships)
            assert total > 0, (obj.name, vertex.index)
            for index, weight in memberships:
                obj.vertex_groups[index].add([vertex.index], weight/total, 'REPLACE')
(OUT/'mesh_repairs.json').write_text(json.dumps(repaired_meshes, indent=2))

def aim(obj, target):
    obj.rotation_euler = (Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()

camera = scene.camera
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 2.48
scene.render.resolution_x = 800
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.look = 'AgX - Medium High Contrast'
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.15,.19,.24,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .35
floor = bpy.data.objects.get('RENDER_ONLY_StudioFloor')
color(floor.data.materials[0], '858D97', .9)
for collection in bpy.data.collections:
    if 'REFERENCE' in collection.name:
        collection.hide_render = True
        collection.hide_viewport = True

# Hidden mouth/lid meshes are required by the game but should not stack in the preview.
for obj in parts:
    obj.hide_render = obj.name.startswith(('EyelidHalf','EyelidClosed','MouthOpen','Tongue'))
    obj.hide_set(obj.hide_render)
scene.frame_start, scene.frame_end = 0, 77
camera.location = (2.8,-5.5,2.15)
aim(camera, (0,0,1.02))
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'milo_redesign.blend'))

# Export all animation-state meshes, excluding studio objects and cameras.
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for obj in parts:
    obj.hide_set(False)
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'milo_redesign.glb'), export_format='GLB',
    use_selection=True, export_animations=True, export_animation_mode='ACTIONS',
    export_nla_strips=False, export_force_sampling=True, export_materials='EXPORT',
    export_extras=True)

views = {'hero': (2.8,-5.5,2.15), 'front': (0,-5,1.1), 'side': (5,0,1.1), 'back': (0,5,1.1)}
for name, location in views.items():
    camera.location = location
    aim(camera, (0,0,1.02))
    scene.render.filepath = str(OUT/(name+'.png'))
    bpy.ops.render.render(write_still=True)

camera.location = (2.8,-5.5,2.15)
aim(camera, (0,0,1.02))
for action_name, frames in {'Milo_Redesign_Welcome':[0,15,29,43,58], 'Milo_Walking':[0,6,13,19,25]}.items():
    action = bpy.data.actions[action_name]
    rig.animation_data.action = action
    if action.slots:
        rig.animation_data.action_slot = action.slots[0]
    for i, frame in enumerate(frames):
        scene.frame_set(frame)
        scene.render.filepath = str(OUT/(action_name+'_'+str(i)+'.png'))
        scene.render.resolution_x, scene.render.resolution_y = 480, 600
        bpy.ops.render.render(write_still=True)

print('MILO_REDESIGN_BUILD_OK', len(parts), 'mesh objects;', len(rig.data.bones), 'bones')
