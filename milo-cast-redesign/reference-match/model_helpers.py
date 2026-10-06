"""Geometry helpers for the reference rebuild; no game assets are written."""
from pathlib import Path
import bpy,bmesh,math,json
from mathutils import Vector,Matrix
OUT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT.parent/'luxury-coat/milo_luxury_coat.blend'))
scene=bpy.context.scene;rig=bpy.data.objects['Milo_Cast_Rig'];ad=rig.animation_data
clips={tr.name:(tr.strips[0].action,tr.strips[0].action_slot) for tr in ad.nla_tracks}
for tr in ad.nla_tracks:tr.mute=True
ad.action,ad.action_slot=clips['Idle'];scene.frame_set(0)
for o in list(bpy.data.objects):
    if o.type!='ARMATURE':bpy.data.objects.remove(o,do_unlink=True)
created=[]
def linear(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
def rgba(h):return tuple(linear(int(h[i:i+2],16)/255) for i in (0,2,4))+(1,)
def material(name,h,rough=.82,metal=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=rgba(h);m.roughness=rough;m.metallic=metal;p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=m.diffuse_color;p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal;p.inputs['Specular IOR Level'].default_value=.30;return m
fur=material('Milo taupe cream fur','BCAE96');ivory=material('Milo ivory face fur','E9E2CE');furshade=material('Milo fur shadow','9E8F77');inner=material('Milo ear rose','BE9984');gold=material('Milo warm gold','BE9650',.36,.56);goldlight=material('Milo fine gold edge','C1A46A',.51,.35);navy=material('Milo charcoal navy coat','26323C');lapel=material('Milo folded lapels','2C3C44');teal=material('Milo teal piping','648E87');purple=material('Milo purple waistcoat','635168');shirt=material('Milo ivory shirt','E6DECB');trouser=material('Milo dark brown trousers','433C34');leather=material('Milo brown boots','594734',.7);sole=material('Milo boot sole','302A25');amber=material('Milo amber iris','987134',.36);eye_dark=material('Milo warm dark pupil','241F17',.3);eye_white=material('Milo eye cream','E8D8B1',.45);shine=material('Milo eye catchlight','FFF5D9',.25);nosemat=material('Milo peach nose','B98368',.62);groove=material('Milo muzzle groove','B6AA94');wood=material('Milo walnut cane','66492F',.65)
def select(o):bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
def torso_weights(p):
    z=p.z
    if z<=.60:return {'hips':1}
    if z<.94:
        t=(z-.60)/.34;return {'hips':1-t,'spine':t}
    t=min(1,(z-.94)/.21);return {'spine':1-t,'chest':t}
def skin(o,mat,bone='head',smooth=True):
    select(o);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    o.data.materials.clear();o.data.materials.append(mat);o.vertex_groups.clear()
    for v in o.data.vertices:
        ws=bone(v.co) if callable(bone) else {bone:1};D=Matrix(((0,0,0,0),)*4)
        for name,w in ws.items():
            if w<=0:continue
            pb=rig.pose.bones[name];D+=w*(pb.matrix@pb.bone.matrix_local.inverted());g=o.vertex_groups.get(name) or o.vertex_groups.new(name=name);g.add([v.index],w,'REPLACE')
        v.co=D.inverted()@v.co
    for p in o.data.polygons:p.use_smooth=smooth
    o.parent=rig;mod=o.modifiers.new('Reference skin','ARMATURE');mod.object=rig;created.append(o);return o
def mesh(name,verts,faces,mat=None,bone='head',smooth=True):
    d=bpy.data.meshes.new(name);d.from_pydata(verts,[],faces);d.update();o=bpy.data.objects.new(name,d);scene.collection.objects.link(o)
    return skin(o,mat,bone,smooth) if mat else o
def ellipsoid(name,loc,scale,mat=None,bone='head',segments=20,rings=10,smooth=True):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;select(o);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return skin(o,mat,bone,smooth) if mat else o
def curve(points,steps=5,closed=False):
    p=[Vector(v) for v in points];out=[]
    for i in range(len(p) if closed else len(p)-1):
        a=p[(i-1)%len(p)] if closed or i>0 else p[i];b=p[i];c=p[(i+1)%len(p)];d=p[(i+2)%len(p)] if closed or i+2<len(p) else c
        for j in range(steps):
            t=j/steps;out.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    if not closed:out.append(p[-1])
    return out
def sweep(name,points,radii,mat=None,bone='head',sides=10,flat=1,closed=False,smooth=True):
    pts=[Vector(v) for v in points];verts=[]
    for i,p in enumerate(pts):
        t=(pts[(i+1)%len(pts)]-pts[(i-1)%len(pts)]) if closed else pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)];t.normalize();a=t.cross(Vector((0,1,0)))
        if a.length<.01:a=t.cross(Vector((1,0,0)))
        a.normalize();b=t.cross(a).normalized();r=radii[i] if isinstance(radii,list) else radii
        verts.extend(tuple(p+r*(math.cos(j*math.tau/sides)*a+flat*math.sin(j*math.tau/sides)*b)) for j in range(sides))
    faces=[(i*sides+j,i*sides+(j+1)%sides,((i+1)%len(pts))*sides+(j+1)%sides,((i+1)%len(pts))*sides+j) for i in range(len(pts) if closed else len(pts)-1) for j in range(sides)]
    if not closed:faces.extend((tuple(reversed(range(sides))),tuple((len(pts)-1)*sides+j for j in range(sides))))
    return mesh(name,verts,faces,mat,bone,smooth)
def panel(name,points,mat,bone=torso_weights,depth=.012,bevel=.003):
    n=len(points);verts=list(points)+[(x,y+depth,z) for x,y,z in points];faces=[tuple(range(n)),tuple(reversed(range(n,n*2)))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)];o=mesh(name,verts,faces)
    if bevel:
        select(o);m=o.modifiers.new('Soft tailored edge','BEVEL');m.width=bevel;m.segments=2;bpy.ops.object.modifier_apply(modifier=m.name)
    return skin(o,mat,bone)
def tuft(name,outline,center,mat=ivory,depth=.035):
    pts=curve(outline,3,True);n=len(pts);c=Vector(center);front=[tuple(p) for p in pts];back=[tuple(p+Vector((0,depth,0))) for p in pts];verts=front+back+[tuple(c),tuple(c+Vector((0,depth+.025,0)))]
    faces=[(i,(i+1)%n,2*n) for i in range(n)]+[(n+(i+1)%n,n+i,2*n+1) for i in range(n)]+[(i,n+i,n+(i+1)%n,(i+1)%n) for i in range(n)]
    return mesh(name,verts,faces,mat)
def button(name,loc,r=.014,mat=gold,bone=torso_weights):return ellipsoid(name,loc,(r,.007,r),mat,bone,12,6)
def join_objects(objects,name):
    select(objects[0])
    for o in objects:o.select_set(True)
    bpy.ops.object.join();o=bpy.context.object;o.name=name;return o
def union_paw(objects,name,bone):
    o=join_objects(objects,name);m=o.modifiers.new('Connected paw topology','REMESH');m.mode='VOXEL';m.voxel_size=.005;m.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=m.name);m=o.modifiers.new('Paw softening','SMOOTH');m.factor=.5;m.iterations=5;bpy.ops.object.modifier_apply(modifier=m.name);m=o.modifiers.new('Paw reduction','DECIMATE');m.ratio=.24;bpy.ops.object.modifier_apply(modifier=m.name);o.data.validate(clean_customdata=True)
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);boundary=[e for e in bm.edges if e.is_boundary]
    if boundary:bmesh.ops.holes_fill(bm,edges=boundary,sides=0)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();o.data.update();return skin(o,ivory,bone)
