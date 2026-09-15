"""Milo quality rebuild. Outputs isolated from the live game and v1 review."""
from pathlib import Path
import math, json, sys
import bpy, bmesh
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(OUT))
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
parts=[]

def active(o):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.context.view_layer.objects.active=o

def linear(h):
    a=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in a)

def material(name,hex,rough=.65,metal=0,texture=None):
    m=bpy.data.materials.new(name); m.diffuse_color=(*linear(hex),1)
    m.use_nodes=True; m.roughness=rough; m.metallic=metal
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=m.diffuse_color
    p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
    if texture:
        noise=m.node_tree.nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=texture[0]
        noise.inputs['Detail'].default_value=2
        bump=m.node_tree.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.07
        bump.inputs['Distance'].default_value=texture[1]
        m.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height'])
        m.node_tree.links.new(bump.outputs['Normal'],p.inputs['Normal'])
    if name.startswith('Fur'):
        p.inputs['Subsurface Weight'].default_value=.045
        p.inputs['Subsurface Radius'].default_value=(.4,.2,.12)
    return m

fur=material('Fur warm biscuit','E1BB88',.78,texture=(180,.0008))
cream=material('Fur soft ivory','F2E4CB',.8,texture=(200,.0006))
pink=material('Ear velvet rose','BF8984',.8)
navy=material('Midnight wool','293D56',.86,texture=(260,.0012))
lapel=material('Navy satin lapel','3A506B',.52,texture=(330,.0005))
plum=material('Muted mulberry waistcoat','785C7C',.61,texture=(230,.0007))
shirt=material('Warm ivory linen','E8DECA',.85,texture=(220,.0007))
gold=material('Brushed champagne gold','D9B675',.27,.72)
dark=material('Trouser wool','303444',.85,texture=(270,.0008))
leather=material('Oxblood leather','53352E',.32,texture=(180,.0005))
sole=material('Rubber sole','25242B',.8)
wood=material('Walnut cane','71462E',.38,texture=(25,.0003))
eye_white=material('Warm eye sclera','EDE7D8',.25)
iris=material('Lavender iris','9373BA',.25)
pupil=material('Deep plum pupil','281F3A',.18)
shine=material('Eye highlight','FFFFFF',.1)
nosemat=material('Rose nose','B47780',.42)
mouthmat=material('Warm mouth interior','59363C',.9)

def finish(o,name,mat,bone=None):
    o.name=name; active(o)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    o.data.materials.clear(); o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=True
    if bone:o['bind_bone']=bone
    parts.append(o); return o

def ellipsoid(name,loc,scale,mat,bone=None,segments=48,rings=28,register=True):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=loc)
    o=bpy.context.object;o.scale=scale
    if register:return finish(o,name,mat,bone)
    active(o);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return o

def meshobj(name,verts,faces,mat,bone=None):
    me=bpy.data.meshes.new(name+'Mesh');me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new(name,me);scene.collection.objects.link(o)
    return finish(o,name,mat,bone)

def sculpt(name,shapes,mat,bone,voxel=.008):
    objs=[ellipsoid('',p,s,mat,register=False,segments=36,rings=20) for p,s in shapes]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();o=objs[0]
    mod=o.modifiers.new('Unified sculpt surface','REMESH');mod.mode='VOXEL';mod.voxel_size=voxel
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=o.modifiers.new('Relax sculpt','SMOOTH');mod.factor=.55;mod.iterations=6
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=o.modifiers.new('Efficient smooth surface','DECIMATE');mod.ratio=.55
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,name,mat,bone)

def tube(name,points,radii,mat,bone=None,sides=12):
    pts=[Vector(p) for p in points];verts=[];faces=[]
    for i,p in enumerate(pts):
        tangent=(pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]).normalized()
        ref=Vector((0,1,0)) if abs(tangent.y)<.9 else Vector((1,0,0))
        u=tangent.cross(ref).normalized();v=tangent.cross(u).normalized()
        radius=radii[i] if isinstance(radii,list) else radii
        rx,ry=radius if isinstance(radius,tuple) else (radius,radius)
        for j in range(sides):
            a=j*math.tau/sides;verts.append(p+u*math.cos(a)*rx+v*math.sin(a)*ry)
    for i in range(len(pts)-1):
        for j in range(sides):
            a=i*sides+j;b=i*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
    faces += [tuple(reversed(range(sides))),tuple(range((len(pts)-1)*sides,len(pts)*sides))]
    return meshobj(name,verts,faces,mat,bone)

def curve(name,points,radius,mat,bone):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=12
    cu.bevel_depth=radius;cu.bevel_resolution=3
    s=cu.splines.new('BEZIER');s.bezier_points.add(len(points)-1)
    for bp,co in zip(s.bezier_points,points):
        bp.co=co;bp.handle_left_type=bp.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,cu);scene.collection.objects.link(o);active(o)
    bpy.ops.object.convert(target='MESH')
    return finish(o,name,mat,bone)

def panel(name,outline,depth,mat,bone,bevel=.008):
    offsets={'Waistcoat':.009,'ShirtFront':.025,'Collar':.038,'Lapel':.031,'Cravat':.044,'PocketSquare':.037,'PocketWelt':.013}
    conform=name.split('.')[0] in offsets
    if conform:
        offset=offsets[name.split('.')[0]]
        outline=[(x,0,z) for x,y,z in outline]
    vs=list(outline)+[(x,y+depth,z) for x,y,z in outline];n=len(outline)
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    o=meshobj(name,vs,fs,mat,bone);active(o)
    if conform:
        bm=bmesh.new();bm.from_mesh(o.data)
        bmesh.ops.triangulate(bm,faces=list(bm.faces))
        bmesh.ops.subdivide_edges(bm,edges=list(bm.edges),cuts=7,use_grid_fill=True)
        for v in bm.verts:v.co.y+=coat_surface_y(v.co.x,v.co.z)-offset
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
    mod=o.modifiers.new('Rounded tailoring edge','BEVEL');mod.width=bevel;mod.segments=3
    bpy.ops.object.modifier_apply(modifier=mod.name);o.data.validate()
    return o

# AnyCreature body forms, welded and smoothly subdivided before re-rigging.
bpy.ops.import_scene.gltf(filepath=str(OUT/'body_seed.glb'))
seed_objs=list(scene.objects)
for src in seed_objs:
    if src.type!='MESH' or not src.data.materials:continue
    for matname,target_mat,label in [('coat',navy,'CoatBody'),('sleeves',navy,'Sleeve'),('trousers',dark,'Trouser')]:
        for side in ([None] if matname=='coat' else ['l','r']):
            verts=[];faces=[];remap={}
            for poly in src.data.polygons:
                if src.data.materials[poly.material_index].name!=matname:continue
                coords=[src.matrix_world@src.data.vertices[i].co for i in poly.vertices]
                if side and (sum(c.x for c in coords)>0)!=(side=='l'):continue
                face=[]
                for index,co in zip(poly.vertices,coords):
                    if index not in remap:remap[index]=len(verts);verts.append(co)
                    face.append(remap[index])
                faces.append(face)
            assert verts,(matname,side)
            o=meshobj(label+('.'+side if side else ''),verts,faces,target_mat)
            bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00005)
            bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
            active(o);sub=o.modifiers.new('Tailored smooth topology','SUBSURF');sub.levels=2
            bpy.ops.object.modifier_apply(modifier=sub.name)
            o['weight_region']=matname;o['anatomical_side']=side or ''
for o in seed_objs:bpy.data.objects.remove(o,do_unlink=True)
for a in list(bpy.data.actions):bpy.data.actions.remove(a)
coat=bpy.data.objects['CoatBody']
coat_bvh=BVHTree.FromPolygons([v.co for v in coat.data.vertices],[list(p.vertices) for p in coat.data.polygons])
def coat_surface_y(x,z):
    hit=coat_bvh.ray_cast(Vector((x,-2,z)),Vector((0,1,0)))
    return hit[0].y if hit[0] is not None else -.15

# Full cheeks and muzzle are fused into one continuous head, not attached cards.
head=sculpt('Head',[
    ((0,.015,1.635),(.355,.285,.345)),
    ((-.197,-.080,1.475),(.184,.226,.155)),
    ((.197,-.080,1.475),(.184,.226,.155)),
    ((0,-.112,1.365),(.185,.155,.075)),
    ((-.085,-.276,1.48),(.113,.132,.087)),
    ((.085,-.276,1.48),(.113,.132,.087)),
    ((0,.015,1.282),(.146,.15,.14)),
],fur,'head',.0075)

# Eye sockets carved into the sculpt. Eye spheres sit in the recesses.
for sign,side in [(1,'l'),(-1,'r')]:
    cutter=ellipsoid('',(sign*.160,-.215,1.70),(.124,.137,.146),fur,register=False)
    active(head);mod=head.modifiers.new('Sculpted eye socket '+side,'BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
for p in head.data.polygons:p.use_smooth=True

# Vertex-painted tabby mask follows the actual curved sculpt and exports to glTF.
attr=head.data.color_attributes.new(name='FurColor',type='FLOAT_COLOR',domain='POINT')
c0=Vector(linear('E9CC9D'));c1=Vector(linear('B77D49'));c2=Vector(linear('F2E1BD'))
for v in head.data.vertices:
    x,y,z=v.co
    front=max(0,min(1,(-y+.02)/.22))
    eye_mask=max(math.exp(-(((x-s*.16)/.146)**4+((z-1.70)/.185)**4)) for s in [-1,1])*front
    stripe=max(math.exp(-((x-a)/w)**4) for a,w in [(0,.031),(-.096,.018),(.096,.018)])
    stripe*=math.exp(-((z-1.875)/.075)**4)*front
    amount=min(.82,max(eye_mask*.67,stripe*.8))
    col=c0.lerp(c1,amount)
    muzzle=max(0,min(1,(1.52-z)/.12))*max(0,min(1,(-y-.16)/.1))
    col=col.lerp(c2,muzzle*.8)
    attr.data[v.index].color=(*col,1)
node=fur.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='FurColor'
fur.node_tree.links.new(node.outputs['Color'],fur.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
# Other fur parts use a regular material, not the head's vertex-color node.
plainfur=material('Fur caramel paws','D6AE7C',.8,texture=(180,.0006))
bvh=BVHTree.FromPolygons([v.co for v in head.data.vertices],[list(p.vertices) for p in head.data.polygons])
def surface_y(x,z):
    hit=bvh.ray_cast(Vector((x,-2,z)),Vector((0,1,0)))
    return hit[0].y if hit[0] is not None else -.24

for sign,side in [(1,'l'),(-1,'r')]:
    bone='ear.'+side
    ear=[(sign*.205,-.01,1.815),(sign*.217,-.01,1.90),(sign*.333,.018,2.103),
         (sign*.367,.035,2.087),(sign*.403,.04,1.847),(sign*.343,-.005,1.792)]
    panel('EarOuter.'+side,ear,.095,plainfur,bone,.025)
    ear_inner=[(sign*.247,-.022,1.845),(sign*.335,.003,2.052),(sign*.372,.005,1.858),
               (sign*.326,-.025,1.823)]
    panel('EarInner.'+side,ear_inner,.022,pink,bone,.019)
    curve('EarFold.'+side,[(sign*.25,-.028,1.85),(sign*.278,-.032,1.91),(sign*.327,-.014,2.02)],.007,cream,bone)
    # Soft dimensional cheek tufts, rooted deeply in the fuller cheek silhouette.
    for i in range(3):
        z=1.53-i*.056
        pts=[(sign*.286,-.10,z),(sign*.348,-.10,z-.004),(sign*(.400-i*.022),-.07,z+.028)]
        tube('CheekTuft.%s.%d'%(side,i),pts,[.041,.034,.0015],cream,'head',16)
    ec=(sign*.16,-.215,1.70)
    ellipsoid('EyeWhite.'+side,ec,(.119,.133,.14),eye_white,'eye.'+side)
    ellipsoid('Iris.'+side,(ec[0],-.343,1.70),(.060,.014,.071),iris,'eye.'+side)
    ellipsoid('Pupil.'+side,(ec[0],-.356,1.70),(.025,.005,.049),pupil,'eye.'+side)
    ellipsoid('Catchlight.'+side,(ec[0]-.015,-.363,1.731),(.010,.004,.012),shine,'eye.'+side,24,12)
    ellipsoid('CatchlightSmall.'+side,(ec[0]+.019,-.362,1.683),(.004,.002,.004),shine,'eye.'+side,16,8)
    # Curved upper eyelid with real Blink morph, hugging the eye globe.
    vs=[];closed=[];fs=[];nx=32;ny=8
    for j in range(ny+1):
        t=j/ny
        for i in range(nx+1):
            u=-.997+1.994*i/nx;rim=math.sqrt(max(.00001,1-u*u))
            for arr,bottom in [(vs,.044),(closed,-.138)]:
                zz=(.14*(1-t)+bottom*t)*rim
                yy=-.215-.137*math.sqrt(max(.00001,1-u*u-(zz/.145)**2))-.017
                arr.append((ec[0]+.122*u,yy,1.70+zz))
    for j in range(ny):
        for i in range(nx):
            a=j*(nx+1)+i;fs.append((a,a+1,a+nx+2,a+nx+1))
    lid=meshobj('UpperLid.'+side,vs,fs,plainfur,'head');lid.shape_key_add(name='Basis')
    key=lid.shape_key_add(name='Blink')
    for p,co in zip(key.data,closed):p.co=co
    key.value=0
    # Integrated lower lid rim.
    pts=[]
    for i in range(33):
        a=math.pi+i/32*math.pi
        pts.append((ec[0]+.116*math.cos(a),-.215-.055*math.sin(math.pi*i/32)-.008,1.70+.134*math.sin(a)))
    tube('LowerLidRim.'+side,pts,.009,plainfur,'head',10)
    # Rounded eyebrows replace the old rigid rectangular plates.
    pts=[]
    for i in range(17):
        t=i/16;x=sign*(.055+.213*t);z=1.849+.024*math.sin(math.pi*t)-.02*t
        pts.append((x,surface_y(x,z)-.01,z))
    tube('Eyebrow.'+side,pts,[.006+.015*math.sin(math.pi*i/16)**.5 for i in range(17)],cream,'brow.'+side,14)
    pts=[(ec[0]+.142*math.cos(a),-.394+.007*math.cos(a)**2,1.70+.151*math.sin(a)) for a in [i*math.tau/64 for i in range(65)]]
    tube('GlassesRim.'+side,pts,.005, gold,'head',10)
    curve('GlassesTemple.'+side,[(sign*.302,-.383,1.735),(sign*.344,-.22,1.75),(sign*.343,-.035,1.795),(sign*.310,.027,1.82)],.004,gold,'head')
curve('GlassesBridge',[(-.022,-.399,1.708),(0,-.412,1.723),(.022,-.399,1.708)],.005,gold,'head')

# Sculpted nose, smiling mouth, swept ivory moustache. No hanging chin card.
nose=panel('Nose',[(-.048,-.428,1.51),(0,-.441,1.48),(.048,-.428,1.51),(.025,-.425,1.535),(-.025,-.425,1.535)],.033,nosemat,'head',.016)
curve('Philtrum',[(0,-.422,1.481),(0,-.424,1.448),(0,-.416,1.421)],.0035,mouthmat,'head')
ellipsoid('MouthSocket',(0,-.337,1.403),(.073,.030,.025),mouthmat,'jaw')
curve('Smile',[(-.07,-.361,1.416),(-.042,-.391,1.394),(0,-.400,1.389),(.042,-.391,1.394),(.07,-.361,1.416)],.0045,nosemat,'jaw')
for sign,side in [(1,'l'),(-1,'r')]:
    pts=[];rs=[]
    for i in range(25):
        t=i/24
        pts.append((sign*(.018+.252*t),-.428+.066*t*t,1.456-.054*math.sin(math.pi*t)+.011*t))
        rs.append((.010+.036*math.sin(math.pi*t)**.65,.012+.031*math.sin(math.pi*t)**.65))
    rs[-1]=(.001,.001)
    tube('Moustache.'+side,pts,rs,cream,'moustache.'+side,20)
    for k in range(3):
        curve('Whisker.%s.%d'%(side,k),[(sign*.17,-.355,1.447-k*.022),(sign*.30,-.337,1.45-k*.025),(sign*.385,-.29,1.474-k*.032)],.0012,cream,'head')

# Fine fitted layers with real thickness; broad coat remains a single sculpted mass.
panel('Waistcoat',[(-.158,-.190,1.174),(.158,-.190,1.174),(.178,-.214,.899),(0,-.229,.791),(-.178,-.214,.899)],.025,plum,'chest',.014)
panel('ShirtFront',[(-.113,-.204,1.207),(.113,-.204,1.207),(.072,-.232,1.02),(0,-.247,.98),(-.072,-.232,1.02)],.014,shirt,'chest',.008)
for sign,side in [(1,'l'),(-1,'r')]:
    panel('Collar.'+side,[(sign*.015,-.221,1.21),(sign*.129,-.191,1.217),(sign*.106,-.254,1.115),(sign*.041,-.263,1.159)],.015,shirt,'chest',.008)
    panel('Lapel.'+side,[(sign*.132,-.191,1.218),(sign*.244,-.191,1.181),(sign*.091,-.254,.866),(sign*.118,-.223,1.095)],.018,lapel,'chest',.006)
    curve('LapelStitch.'+side,[(sign*.231,-.198,1.173),(sign*.166,-.227,1.035),(sign*.104,-.258,.894)],.0013,gold,'chest')
    panel('PocketWelt.'+side,[(sign*.165,-.179,.799),(sign*.266,-.133,.812),(sign*.266,-.141,.787),(sign*.165,-.187,.775)],.012,lapel,'hips',.004)
    # Smooth cuffs, ivory sleeve lining, and tiny brass cufflinks.
    ellipsoid('Cuff.'+side,(sign*.43,-.08,.718),(.081,.080,.032),shirt,'wrist.'+side)
    ellipsoid('Cufflink.'+side,(sign*.503,-.087,.717),(.008,.011,.008),gold,'wrist.'+side,20,12)
    shapes=[((sign*.43,-.09,.660),(.073,.066,.078))]
    for k in range(3):
        shapes.append(((sign*(.395+k*.034),-.105,.614),(.026,.063,.035)))
    shapes.append(((sign*.378,-.12,.672),(.033,.043,.047)))
    paw=sculpt('Paw.'+side,shapes,plainfur,'hand.'+side,.004)
    paw.shape_key_add(name='Basis');curl=paw.shape_key_add(name='FingerCurl')
    for item in curl.data:
        t=max(0,min(1,(.655-item.co.z)/.06));item.co.y+=.021*t;item.co.z+=.010*t
    curl.value=0
    # Continuous shoe upper down to the welt, with a broad flat contact sole.
    def shoe_profile(name,profile,mat):
        verts=[];faces=[];n=48
        for z,rx,ry,cy in profile:
            for i in range(n):
                a=i*math.tau/n;verts.append((sign*.15+rx*math.cos(a),cy+ry*math.sin(a),z))
        for j in range(len(profile)-1):
            for i in range(n):
                a=j*n+i;b=j*n+(i+1)%n;faces.append((a,b,b+n,a+n))
        faces.extend([tuple(reversed(range(n))),tuple(range((len(profile)-1)*n,len(profile)*n))])
        return meshobj(name+'.'+side,verts,faces,mat,'foot.'+side)
    shoe=shoe_profile('Shoe',[(.031,.100,.156,-.06),(.045,.105,.16,-.06),(.073,.105,.155,-.06),(.108,.098,.14,-.053),(.144,.083,.112,-.03),(.178,.063,.084,.006),(.194,.042,.055,.025),(.198,.016,.025,.03)],leather)
    active(shoe);sub=shoe.modifiers.new('Supple leather','SUBSURF');sub.levels=1;bpy.ops.object.modifier_apply(modifier=sub.name)
    shoe_profile('Sole',[(0,.100,.153,-.06),(.006,.108,.16,-.06),(.028,.108,.16,-.06),(.038,.103,.157,-.06)],sole)
    curve('ShoeWelt.'+side,[(sign*.15+.104*math.cos(a),-.06+.158*math.sin(a),.038) for a in [i*math.tau/40 for i in range(41)]],.0025,leather,'foot.'+side)
    for k in range(3):
        y=-.027-k*.02
        curve('ShoeLace.%s.%d'%(side,k),[(sign*.15-.032,y,.174),(sign*.15,y-.004,.18),(sign*.15+.032,y,.174)],.002,sole,'foot.'+side)
    # Separate, softly rounded back coat tails with dedicated follow-through bones.
    panel('CoatTail.'+side,[(sign*.025,.195,.89),(sign*.252,.17,.87),(sign*.292,.176,.58),(sign*.233,.214,.47),(sign*.032,.234,.52)],.025,navy,'coat_tail.'+side,.022)

# Cravat folds and small signet brooch.
panel('Cravat',[(-.036,-.252,1.183),(.043,-.252,1.18),(.063,-.257,1.082),(.008,-.274,1.033),(-.052,-.251,1.092)],.014,shirt,'chest',.012)
ellipsoid('Brooch',(0,-.281,1.158),(.026,.012,.026),gold,'chest',32,16)
ellipsoid('BroochEnamel',(0,-.293,1.158),(.018,.004,.018),plum,'chest',24,12)
for i in range(3):
    z=1.02-i*.085
    ellipsoid('WaistcoatButton.%d'%i,(0,-.238,z),(.012,.008,.012),gold,'chest',24,12)
curve('WatchChain',[(.032,-.244,.983),(.10,-.241,.911),(.16,-.218,.935),(.195,-.199,.982)],.0025,gold,'chest')
panel('PocketSquare',[(-.222,-.208,1.018),(-.190,-.224,1.05),(-.164,-.231,1.019),(-.15,-.235,1.041),(-.142,-.235,1.005),(-.219,-.206,.987)],.007,shirt,'chest',.002)
# Accents sit on their tailored host layer, not an unrelated front plane.
for obj in parts:
    if obj.name.startswith(('Brooch','WaistcoatButton','WatchChain','LapelStitch')):
        center=sum((v.co for v in obj.data.vertices),Vector())/len(obj.data.vertices)
        layer=.072 if obj.name=='BroochEnamel' else .056 if obj.name.startswith('Brooch') else .017 if obj.name.startswith('WaistcoatButton') else .024 if obj.name.startswith('WatchChain') else .035
        for v in obj.data.vertices:
            v.co.y=coat_surface_y(v.co.x,v.co.z)-layer+(v.co.y-center.y)

# Cane is independently controlled, with the hand solved to the grip.
tube('CaneShaft',[(.515,-.09,.025),(.515,-.09,.67)],[.015,.012],wood,'cane',20)
curve('CaneHandle',[(.515,-.09,.66),(.515,-.09,.714),(.494,-.09,.744),(.452,-.09,.744),(.436,-.09,.714)],.017,wood,'cane')
tube('CaneFerrule',[(.515,-.09,.026),(.515,-.09,.075)],.016,gold,'cane',20)
ellipsoid('CaneTip',(.515,-.09,.018),(.016,.016,.015),sole,'cane',24,12)
for z in [.10,.654]:
    tube('CaneCollar'+str(z),[(.515,-.09,z-.006),(.515,-.09,z+.006)],.0165,gold,'cane',20)

# Author a clean deform rig and visible edit controls; no inherited combat rig.
arm=bpy.data.armatures.new('MiloQualitySkeleton');rig=bpy.data.objects.new('MiloQualityRig',arm);scene.collection.objects.link(rig)
active(rig);bpy.ops.object.mode_set(mode='EDIT')
definitions={
 'root':((0,0,0),(0,0,.2),None),
 'hips':((0,0,.64),(0,0,.87),'root'),
 'spine':((0,0,.87),(0,0,1.10),'hips'),
 'chest':((0,0,1.10),(0,0,1.27),'spine'),
 'head':((0,0,1.31),(0,0,1.80),'chest'),
 'jaw':((0,-.22,1.44),(0,-.35,1.39),'head'),
 'cane':((.515,-.09,.018),(.515,-.09,.718),'root'),
}
for sign,side in [(1,'l'),(-1,'r')]:
    definitions.update({
      'upperarm.'+side:((sign*.30,0,1.17),(sign*.405,-.04,.95),'chest'),
      'lowerarm.'+side:((sign*.405,-.04,.95),(sign*.43,-.08,.74),'upperarm.'+side),
      'wrist.'+side:((sign*.43,-.08,.74),(sign*.43,-.09,.69),'lowerarm.'+side),
      'hand.'+side:((sign*.43,-.09,.69),(sign*.43,-.10,.61),'wrist.'+side),
      'upperleg.'+side:((sign*.14,0,.64),(sign*.15,-.03,.36),'hips'),
      'lowerleg.'+side:((sign*.15,-.03,.36),(sign*.15,0,.14),'upperleg.'+side),
      'foot.'+side:((sign*.15,0,.14),(sign*.15,-.12,.075),'lowerleg.'+side),
      'ear.'+side:((sign*.28,.02,1.86),(sign*.355,.03,2.08),'head'),
      'eye.'+side:((sign*.16,-.215,1.70),(sign*.16,-.345,1.70),'head'),
      'brow.'+side:((sign*.16,-.22,1.845),(sign*.23,-.22,1.86),'head'),
      'moustache.'+side:((sign*.018,-.428,1.456),(sign*.25,-.38,1.45),'head'),
      'coat_tail.'+side:((sign*.14,.20,.88),(sign*.16,.21,.51),'hips'),
    })
for name,(h,t,parent) in definitions.items():
    if name.split('.')[0] in ['head','jaw','ear','eye','brow','moustache']:
        h=(h[0],h[1],h[2]-.04);t=(t[0],t[1],t[2]-.04)
    b=arm.edit_bones.new(name);b.head=h;b.tail=t
    if parent:b.parent=arm.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True;rig.data.display_type='BBONE'

def assign(o,weights):
    for name in weights:o.vertex_groups.new(name=name)
    for i,values in enumerate(zip(*weights.values())):
        total=sum(values);assert total>0
        for name,w in zip(weights,values):
            if w>0:o.vertex_groups[name].add([i],w/total,'REPLACE')

for o in parts:
    if o.get('bind_bone','').split('.')[0] in ['head','jaw','ear','eye','brow','moustache']:
        if o.data.shape_keys:
            for key in o.data.shape_keys.key_blocks:
                for item in key.data:item.co.z-=.04
        else:
            for vertex in o.data.vertices:vertex.co.z-=.04
    if o.name.startswith(('Waistcoat','ShirtFront','Collar.','Lapel','Cravat','Pocket','Brooch','WatchChain')):
        if 'bind_bone' in o:del o['bind_bone']
        o['weight_region']='coat';o['anatomical_side']=''
    if 'bind_bone' in o:
        g=o.vertex_groups.new(name=o['bind_bone']);g.add(list(range(len(o.data.vertices))),1,'REPLACE')
    else:
        region=o['weight_region'];side=o['anatomical_side']
        if region=='coat':
            weights={'hips':[],'spine':[],'chest':[]}
            for v in o.data.vertices:
                z=v.co.z;h=max(0,min(1,(.93-z)/.18));c=max(0,min(1,(z-.99)/.18));s=1-h-c
                weights['hips'].append(h);weights['spine'].append(max(0,s));weights['chest'].append(c)
        else:
            names=['upperarm.'+side,'lowerarm.'+side,'wrist.'+side,'chest'] if region=='sleeves' else ['upperleg.'+side,'lowerleg.'+side]
            weights={n:[] for n in names}
            for v in o.data.vertices:
                z=v.co.z
                if region=='sleeves':
                    up=max(0,min(1,(z-.88)/.16));wrist=max(0,min(1,(.82-z)/.10))
                    chest=max(0,min(1,(.36-abs(v.co.x))/.12))*max(0,min(1,(z-1.03)/.10))
                    vals=[up*(1-chest),max(0,1-up-wrist)*(1-chest),wrist*(1-chest),chest]
                else:
                    up=max(0,min(1,(z-.31)/.13));vals=[up,1-up]
                for n,w in zip(names,vals):weights[n].append(w)
        assign(o,weights)
    o.parent=rig;mod=o.modifiers.new('Milo skin','ARMATURE');mod.object=rig
    o.data.validate();o.data.update()

# Rig bone collections document the animator-facing separation.
for title,prefixes in [('Body',['root','hips','spine','chest','head']),('Arms',['upperarm','lowerarm','wrist','hand']),('Legs',['upperleg','lowerleg','foot']),('Face',['jaw','ear','eye','brow','moustache']),('Props and coat',['cane','coat_tail'])]:
    collection=rig.data.collections.new(title)
    for b in rig.data.bones:
        if any(b.name==p or b.name.startswith(p+'.') for p in prefixes):collection.assign(b)

rig['design']='Milo quality v2 — fuller cheeks, continuous sculpt, bespoke rig'
rig['forward_axis']='Blender -Y / glTF +Z'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'milo_quality_model.blend'))
print('MODEL_OK',len(parts),'meshes',len(rig.data.bones),'bones')
