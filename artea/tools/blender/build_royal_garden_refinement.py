"""Editable Blender master + compact glTF assets. No fluid cache or textures.

Geometry is authored in Godot metres/Y-up and converted once to Blender Z-up.
Static components remain separate in the .blend, then batch for the web GLBs.
Water motion exports actual shape-key and droplet transform animation.
"""
import bpy
import bmesh
import json
import math
import sys
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets3D/royal_garden"
(OUT / "glb").mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.scene.render.fps = 24
bpy.context.scene.frame_start = 1
bpy.context.scene.frame_end = 97
GROUPS = {}
ACTIVE = ""
FOUNTAIN_ONLY = "--fountain-only" in sys.argv


def point(v):
    return Vector((v[0], -v[2], v[1]))


def group(name):
    global ACTIVE
    ACTIVE = name
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    GROUPS[name] = col


def adopt(obj, name):
    obj.name = name
    for col in list(obj.users_collection):
        col.objects.unlink(obj)
    GROUPS[ACTIVE].objects.link(obj)
    return obj


def material(name, color, rough=0.8, metal=0.0):
    # Match Godot's sRGB palette; Blender node colours are linear values.
    color = tuple(c / 12.92 if c <= .04045 else ((c + .055) / 1.055)**2.4 for c in color)
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = metal
    mat.use_backface_culling = False
    return mat


STONE = material('Castle blue limestone', (0.57, 0.66, 0.71))
PALE = material('Pale carved limestone', (0.77, 0.81, 0.76))
JOINT = material('Recessed stone joints', (0.36, 0.46, 0.50))
GOLD = material('Aged brass inlay', (0.55, 0.41, 0.19), .38, .35)
LEAF = material('Leaf blade green', (.24, .43, .20))
VEIN = material('Leaf fibre pale green', (.44, .61, .29))
PETAL = material('Iris petal ivory', (.84, .79, .62))
PURPLE = material('Iris petal violet', (.31, .10, .48))
WATER = material('Living water', (.12, .42, .53), .13)


def finish(obj, mat, bevel=0, smooth=False):
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    if bevel:
        mod = obj.modifiers.new('Soft carved arris', 'BEVEL')
        mod.width = bevel
        mod.segments = 3
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    # Weld the lathe's seam and pole vertices before triangulation. This keeps
    # a continuous smooth normal and avoids zero-area triangles at the centre.
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.000001)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=.000001)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    for poly in obj.data.polygons:
        poly.use_smooth = smooth
    return obj


def mesh(name, vertices, faces, mat, smooth=False, bevel=0):
    data = bpy.data.meshes.new(name)
    data.from_pydata([point(v) for v in vertices], [], faces)
    obj = bpy.data.objects.new(name, data)
    GROUPS[ACTIVE].objects.link(obj)
    return finish(obj, mat, bevel, smooth)


def box(name, pos, size, mat, bevel=.02):
    bpy.ops.mesh.primitive_cube_add(size=1, location=point(pos))
    obj = adopt(bpy.context.object, name)
    obj.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, mat, bevel)


def lathe(name, profile, mat, segments=64, start=0, end=math.tau, smooth=True):
    # Closed profile; a sector also closes its two cut faces.
    vertices = []
    for i in range(segments + 1):
        angle = start + (end-start)*i/segments
        for radius, height in profile:
            vertices.append((radius*math.cos(angle), height, radius*math.sin(angle)))
    n = len(profile)
    faces = []
    for i in range(segments):
        for j in range(n):
            k = (j+1) % n
            faces.append((i*n+j, (i+1)*n+j, (i+1)*n+k, i*n+k))
    if end-start < math.tau-.001:
        faces += [tuple(range(n-1,-1,-1)), tuple(segments*n+j for j in range(n))]
    return mesh(name, vertices, faces, mat, smooth)


def tube(name, path, radius, mat, sides=8):
    verts, faces = [], []
    for i, p in enumerate(path):
        tangent = Vector(path[min(i+1,len(path)-1)])-Vector(path[max(0,i-1)])
        tangent.normalize()
        side = tangent.cross(Vector((0,0,1)))
        if side.length < .01:
            side = tangent.cross(Vector((1,0,0)))
        side.normalize()
        normal = side.cross(tangent).normalized()
        for j in range(sides):
            angle = math.tau*j/sides
            local_radius = radius(i/(len(path)-1)) if callable(radius) else radius
            verts.append(Vector(p)+local_radius*(side*math.cos(angle)+normal*math.sin(angle)))
    for i in range(len(path)-1):
        for j in range(sides):
            k=(j+1)%sides
            faces.append((i*sides+j,(i+1)*sides+j,(i+1)*sides+k,i*sides+k))
    return mesh(name, verts, faces, mat, True)


def ball(name, pos, radius, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=radius, location=point(pos))
    return finish(adopt(bpy.context.object,name),mat,smooth=True)


def export_groups():
    for col in GROUPS.values():
        for obj in col.objects:
            if obj.type != 'MESH' or obj.data.uv_layers:
                continue
            # Valid face-planar UVs also let Godot generate tangents for morph
            # targets. No texture is necessary, but missing UVs cause import errors.
            uv = obj.data.uv_layers.new(name='Stone and leaf coordinates')
            for poly in obj.data.polygons:
                normal_axis = max(range(3), key=lambda axis: abs(poly.normal[axis]))
                axes = [axis for axis in range(3) if axis != normal_axis]
                for loop_index in poly.loop_indices:
                    vertex = obj.data.vertices[obj.data.loops[loop_index].vertex_index].co
                    uv.data[loop_index].uv = (vertex[axes[0]], vertex[axes[1]])

    bpy.context.preferences.filepaths.save_version = 0
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source'/('castle_fountain_refined.blend' if FOUNTAIN_ONLY else 'royal_garden_components.blend')),compress=True)
    manifest={'authoring':'Blender 5.2 direct scripting; reuses existing anyCreature carp asset',
              'units':'metres; game Y-up','water_loop_seconds':4,'fountain_diameter':3.304,'stone_height':2.3125,'max_profile_edge':0.12,'assets':{}}
    for name,col in GROUPS.items():
        objects=[o for o in col.objects if o.type=='MESH']
        manifest['assets'][name]={'editable_components':len(objects),
            'triangles':sum(len(o.data.polygons) for o in objects),
            'shape_key_meshes':sum(o.data.shape_keys is not None for o in objects)}
        bpy.ops.object.select_all(action='DESELECT')
        if name!='WaterMotion':
            copies=[]
            for obj in objects:
                copy=obj.copy()
                copy.data=obj.data.copy()
                bpy.context.scene.collection.objects.link(copy)
                copy.select_set(True)
                copies.append(copy)
            bpy.context.view_layer.objects.active=copies[0]
            bpy.ops.object.join()
            merged=bpy.context.object
            merged.name=name
            # Bake joined object transforms, keeping the exported origin at (0,0,0).
            bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        else:
            for obj in objects:
                obj.select_set(True)
        path=OUT/'glb'/('%s.glb'%name)
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
            export_animations=name=='WaterMotion',export_animation_mode='SCENE',
            export_anim_scene_split_object=False,
            export_frame_range=True,export_force_sampling=True,export_morph=True,
            export_extras=True,export_yup=True,export_cameras=False,export_lights=False)
        manifest['assets'][name]['bytes']=path.stat().st_size
        if name!='WaterMotion':
            bpy.data.objects.remove(merged,do_unlink=True)
    (OUT/'source'/('manifest_fountain.json' if FOUNTAIN_ONLY else 'manifest.json')).write_text(json.dumps(manifest,indent=2)+'\n')
    print('ROYAL_GARDEN_BLENDER: '+json.dumps(manifest))


group('FountainStone')
# Larger dressed-stone profile, authored at its actual physics dimensions.
# Frequent cross-section samples and 192 radial stations create small triangles;
# the mouldings are curved stone, not a visibly faceted low-sided cylinder.
CASTLE_STONE = material('Reference castle limestone', (145/255,152/255,162/255), .92)
CASTLE_TRIM = material('Reference castle dressed trim', (104/255,115/255,121/255), .92)
def stone_lathe(name, profile, mat=CASTLE_STONE, segments=192, start=0, end=math.tau):
    refined=[]
    for i,a in enumerate(profile):
        b=profile[(i+1)%len(profile)]
        count=max(1,math.ceil(math.dist(a,b)/.12))
        refined.extend((a[0]+(b[0]-a[0])*j/count,a[1]+(b[1]-a[1])*j/count) for j in range(count))
    return lathe(name,refined,mat,segments,start,end)

stone_lathe('Basin structural core', [(0,0),(1.372,0),(1.624,.75),(0,.75)])
stone_lathe('Foot moulding', [(1.372,.02),(1.402,.045),(1.445,.14),(1.437,.17),(1.411,.17),(1.386,.11)], CASTLE_TRIM)
for i in range(32):
    a,b=math.tau*i/32+.0015,math.tau*(i+1)/32-.0015
    stone_lathe('Lower rounded coping %02d'%i,
        [(1.372,.725),(1.627,.725),(1.648,.755),(1.652,.895),
         (1.643,.925),(1.622,.95),(1.395,.95),(1.372,.925)],
        CASTLE_TRIM,8,a,b)
# Small, low-contrast ashlar groups keep the original tower's quiet stone style.
for patch in range(8):
    centre=math.tau*patch/8
    for j,(offset,y,width) in enumerate([(-.10,.48,.28),(.09,.33,.34),(-.09,.18,.28)]):
        r=1.372+.252*y/.75
        a=centre+(offset-width/2)/r
        b=centre+(offset+width/2)/r
        stone_lathe('Basin dressed patch %d %d'%(patch,j),
            [(r,y-.055),(r+.011,y-.055),(r+.049,y+.055),(r+.037,y+.055)],
            CASTLE_STONE,6,a,b)
stone_lathe('Pedestal turned stem',
    [(.42,.75),(.42,.81),(.385,.875),(.32,.92),(.27,1.36),(.24,1.52),
     (.285,1.565),(.30,1.61),(0,1.61),(0,.75)], CASTLE_TRIM,128)
for i in range(12):
    angle=math.tau*i/12
    tube('Pedestal carved flute %02d'%i,
        [(r*math.cos(angle),y,r*math.sin(angle)) for y,r in [(.94,.315),(1.20,.283),(1.44,.253)]],
        .012,CASTLE_STONE,8)
stone_lathe('Upper bowl shell',
    [(0,1.5125),(.28,1.5125),(.34,1.53),(.48,1.60),(.66,1.72),(.76,1.82),(.784,1.8625),(0,1.8625)])
stone_lathe('Upper bowl rounded coping',
    [(.644,1.825),(.80,1.825),(.812,1.855),(.812,1.957),(.791,1.9875),(.662,1.9875),(.644,1.958)], CASTLE_TRIM,160)
stone_lathe('Crown nozzle',[(0,1.8625),(.168,1.8625),(.155,2.06),(.12,2.18),(.098,2.3125),(0,2.3125)],GOLD,96)

# Import the plugin-generated creature. Apply the static bind pose and retain
# separate body/eyes/fins in the editable master, with four radial instances.
existing=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(OUT/'source/anycreature_carp.glb'))
imported=set(bpy.data.objects)-existing
fish=[]
for obj in imported:
    # Blender creates an unlinked Icosphere as an armature display widget.
    # Only skinned glTF meshes are the creature; never export bone widgets.
    if obj.type=='MESH' and any(mod.type=='ARMATURE' for mod in obj.modifiers):
        evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        data=bpy.data.meshes.new_from_object(evaluated)
        data.transform(obj.matrix_world)
        for slot,mat in enumerate(data.materials):
            data.materials[slot] = JOINT if 'eye' in mat.name else PALE
        for poly in data.polygons:
            poly.use_smooth = True
        fish.append((obj.name,data))
assert len(fish) == 1, 'Expected the one skinned anyCreature carving, without bone widgets'
for obj in imported:
    bpy.data.objects.remove(obj,do_unlink=True)
for i in range(4):
    angle=math.tau*i/4+math.pi/4
    # In Blender, Godot forward +Z is -Y. Rotate into the radial direction.
    rot=Matrix.Rotation(math.pi/2-angle,4,'Z')
    trans=Matrix.Translation(point((.50*math.cos(angle),2.0,.50*math.sin(angle))))
    for name,data in fish:
        obj=bpy.data.objects.new('Carp spout %d %s'%(i,name),data.copy())
        GROUPS[ACTIVE].objects.link(obj)
        obj.matrix_world=trans@rot@Matrix.Scale(.36,4)

group('WaterMotion')
def animate_shape(obj, deform):
    obj.shape_key_add(name='Basis')
    for phase_index in range(3):
        phase=math.tau*phase_index/3
        key=obj.shape_key_add(name='Flow phase %d'%phase_index)
        for i,vert in enumerate(key.data):
            vert.co=deform(i,vert.co.copy(),phase)
        for frame in range(1,98,4):
            t=(frame-1)/96
            key.value=(1+math.sin(math.tau*t+phase))/3
            key.keyframe_insert('value',frame=frame)

# Ballistic paths: the same gravity curve drives continuous water and droplets.
for i in range(4):
    angle=math.tau*i/4+math.pi/4
    radial=Vector((math.cos(angle),0,math.sin(angle)))
    for label,start_r,start_y,end_r,end_y,up_speed,stream_radius in [
        ('CrownWaterJet',.04,2.3125,.52,1.8825,3.15,.027),
        ('BasinCascade',.745,2.025,1.22,.77,.16,.044)]:
        duration=(up_speed+math.sqrt(up_speed**2+2*9.81*(start_y-end_y)))/9.81
        def flow_path(t):
            seconds=t*duration
            pos=radial*(start_r+(end_r-start_r)*t)
            pos.y=start_y+up_speed*seconds-.5*9.81*seconds*seconds
            return pos
        path=[flow_path(j/48) for j in range(49)]
        obj=tube('%s_%d'%(label,i),path,
            lambda t:stream_radius*(1-.30*t)*(1+.035*math.sin(t*math.tau*4+i)),WATER,12)
        def deform(index,co,phase):
            t=(index//12)/48
            sway=math.sin(math.pi*t)**2*.009
            co.x+=sway*math.sin(t*math.tau*3+phase)
            co.y+=sway*math.cos(t*math.tau*2+phase)
            return co
        animate_shape(obj,deform)
        for drop_index in range(4):
            drop=ball('%s droplet %d %d'%(label,i,drop_index),(0,0,0),.012+(drop_index%3)*.004,WATER)
            for frame in range(1,98):
                # Flight uses its physical gravity duration, then the invisible
                # droplet waits in the pool until the next one-second emission.
                t=min(1,(((frame-1)/24+drop_index/4+i*.17)%1)/duration)
                pos=flow_path(t)
                pos+=Vector((math.sin(t*17+i)*.035,0,math.cos(t*13+i)*.035))*math.sin(math.pi*t)
                drop.location=point(pos)
                fade=max(.001,min(1,t*12,(1-t)*12))
                drop.scale=(fade,fade,fade*1.45)
                drop.keyframe_insert('location',frame=frame)
                drop.keyframe_insert('scale',frame=frame)

for label,radius,height in [('LowerBasinWater',1.365,.77),('UpperBasinWater',.637,1.8825)]:
    segments,rings=128,20
    verts=[(0,height,0)]
    for ring in range(1,rings+1):
        for i in range(segments):
            a=math.tau*i/segments
            verts.append((radius*ring/rings*math.cos(a),height,radius*ring/rings*math.sin(a)))
    faces=[(0,1+i,1+(i+1)%segments) for i in range(segments)]
    for ring in range(rings-1):
        for i in range(segments):
            j=(i+1)%segments
            faces.append((1+ring*segments+i,1+(ring+1)*segments+i,1+(ring+1)*segments+j,1+ring*segments+j))
    pool=mesh(label,verts,faces,WATER,True)
    uv=pool.data.uv_layers.new(name='Basin coordinates')
    for loop in pool.data.loops:
        v=pool.data.vertices[loop.vertex_index].co
        uv.data[loop.index].uv=(.5+v.x/(2*radius),.5-v.y/(2*radius))
    def wave(index,co,phase):
        r=math.hypot(co.x,co.y)/radius
        co.z+=.0025*math.sin(co.x*13+phase)*math.cos(co.y*11-phase)*(1-r*r)
        return co
    animate_shape(pool,wave)

if FOUNTAIN_ONLY:
    export_groups()
    raise SystemExit(0)

group('VeinedFoliage')
for frond in range(7):
    angle=math.tau*frond/7
    radial=Vector((math.cos(angle),0,math.sin(angle)))
    side=Vector((-radial.z,0,radial.x))
    length=.31+(frond%3)*.045
    origin=Vector((0,.015,0))
    def blade_point(t,u):
        width=.085*math.sin(math.pi*t)**.75
        p=origin+radial*length*t+side*width*u
        p.y+=.31*math.sin(t*math.pi*.65)+.013*(1-u*u)*math.sin(math.pi*t)
        return p
    verts=[blade_point(i/12,j/2-1) for i in range(13) for j in range(5)]
    faces=[]
    for i in range(12):
        for j in range(4):
            a=i*5+j
            faces.append((a,a+1,a+6,a+5))
    mesh('FernLeaf blade %d'%frond,verts,faces,LEAF,True)
    tube('Leaf midrib %d'%frond,[blade_point(i/12,0)+Vector((0,.003,0)) for i in range(13)],.0035,VEIN,5)
    for vein in range(1,5):
        t=vein*.16
        for side_sign in [-1,1]:
            tube('Leaf lateral fibre %d %d %d'%(frond,vein,side_sign),
                 [blade_point(t+u*.10,side_sign*u*.88)+Vector((0,.003,0)) for u in [0,.33,.66,1]],.0018,VEIN,4)

group('RoyalIris')
tube('Iris stem',[(0,0,0),(.01,.15,0),(0,.30,0)],.008,LEAF,6)
for i in range(6):
    angle=math.tau*i/6
    radial=Vector((math.cos(angle),0,math.sin(angle)))
    side=Vector((-radial.z,0,radial.x))
    verts=[]
    for j in range(9):
        t=j/8
        for k in range(5):
            u=k/2-1
            p=radial*(.018+.16*t)+side*(.065*math.sin(math.pi*t)**.7*u)
            p.y=.30+.07*math.sin(t*math.pi)-.015*t+.008*u*u
            verts.append(p)
    faces=[]
    for j in range(8):
        for k in range(4):
            a=j*5+k
            faces.append((a,a+1,a+6,a+5))
    mesh('Petal_%d'%i,verts,faces,PETAL,True)
    tube('Petal fibre %d'%i,[verts[j*5+2]+Vector((0,.003,0)) for j in range(1,8)],.0016,PALE,4)
ball('Iris pollen heart',(0,.325,0),.036,GOLD)

group('MasonryBridge')
SPAN = 8.6  # Generated LumenBridgeRoadbed is 9.6 m, with 0.5 m end overlaps.
HALF = SPAN / 2
# Deck top = original roadbed collider top, NOT the old raised timber overlay.
box('Continuous stone deck',(0,-.006,0),(4.8,.428,SPAN),STONE,.012)
# Flat inlaid blocks below the physical top; their 1 mm finish never lifts feet.
for row in range(24):
    z=-HALF+(row+.5)*SPAN/24
    for col in range(6):
        box('Deck paver %02d %d'%(row,col),(-2.4+(col+.5)*.8,.210,z),(.792,.020,SPAN/24-.008),
            STONE,.004)
for sign in [-1,1]:
    # Core and flared wings exactly follow the existing safety-wall centreline.
    route=[Vector((sign*3.51,0,-HALF)),Vector((sign*2.56,0,-HALF+1.4)),
           Vector((sign*2.56,0,HALF-1.4)),Vector((sign*3.51,0,HALF))]
    for section in range(3):
        a,b=route[section:section+2]
        delta=b-a
        length=delta.length
        yaw=math.atan2(delta.x,delta.z)
        def bridge_box(name,pos,size,mat,bevel=.012):
            obj=box(name,pos,size,mat,bevel)
            obj.rotation_euler.z=yaw
            return obj
        bridge_box('Parapet core %d %d'%(sign,section),(a+b)*.5+Vector((0,.98,0)),(.18,1.56,length),STONE)
        bridge_box('Rounded coping %d %d'%(sign,section),(a+b)*.5+Vector((0,1.735,0)),(.25,.05,length),PALE,.02)
        n=max(1,round(length/.70))
        for row in range(4):
            for col in range(n):
                # Shallow relief on each side; no deep blocks into the aisle.
                centre=a.lerp(b,(col+.5)/n)+Vector((0,.36+row*.35,0))
                bridge_box('Parapet ashlar %d %d %d %d'%(sign,section,row,col),centre,
                           (.190,.342,length/n-.012),STONE,.007)
    # Stone arch soffit closes the old loose timber underside into one vault.
    verts=[]
    for i in range(49):
        z=-HALF+SPAN*i/48
        bottom=-1.45+1.12*math.sin(math.pi*i/48)
        verts += [(sign*2.42,-.21,z),(sign*2.42,bottom,z),(sign*2.18,bottom,z),(sign*2.18,-.21,z)]
    faces=[]
    for i in range(48):
        for j in range(4):
            k=(j+1)%4
            faces.append((i*4+j,(i+1)*4+j,(i+1)*4+k,i*4+k))
    faces += [(3,2,1,0),(192,193,194,195)]
    mesh('Arch spandrel %d'%sign,verts,faces,STONE,True)
    for i in range(24):
        z=-HALF+(i+.5)*SPAN/24
        y=-1.45+1.12*math.sin(math.pi*(i+.5)/24)
        voussoir=box('Soffit voussoir %d %02d'%(sign,i),(sign*2.425,y+.07,z),(.025,.13,SPAN/24-.013),STONE,.006)
        slope=1.12*math.pi/SPAN*math.cos(math.pi*(i+.5)/24)
        # Align the carved stones to the arch, not a row of hanging stair teeth.
        voussoir.rotation_euler.x=-math.atan(slope)

# Real closed soffit between the two longitudinal arch faces.
verts=[]
for i in range(49):
    z=-HALF+SPAN*i/48
    y=-1.45+1.12*math.sin(math.pi*i/48)
    verts.extend([(-2.42,y,z),(2.42,y,z)])
mesh('Continuous vaulted underside',verts,[(i*2,i*2+1,i*2+3,i*2+2) for i in range(48)],STONE,True)

export_groups()
