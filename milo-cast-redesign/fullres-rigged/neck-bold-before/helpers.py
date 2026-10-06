"""Shared geometry constructors for the full-resolution Milo build."""
from pathlib import Path
import bpy,bmesh,math,json
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
parts=[]
def linear(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
def rgba(h):return tuple(linear(int(h[i:i+2],16)/255) for i in (0,2,4))+(1,)
def mat(name,h,rough=.8,metal=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=rgba(h);m.roughness=rough;m.metallic=metal
    p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=m.diffuse_color;p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal;p.inputs['Specular IOR Level'].default_value=.32
    return m
fur=mat('01 warm stone cream fur','BDAF96');ivory=mat('02 ivory muzzle fur','E5DCC7');rimfur=mat('03 light ear rim','C9BBA1');inner=mat('04 shaded pink ear','B58E77');innerlight=mat('05 inner ear light','C59E87')
gold=mat('10 old polished gold','B18A46',.28,.65);edgegold=mat('11 fine ochre braid','BBA063',.6,.3);navy=mat('20 midnight wool coat','252F39',.83);lapel=mat('21 lapel navy','283743',.8);teal=mat('22 muted jade piping','587F79');purple=mat('23 plum waistcoat','615069');shirt=mat('24 cream linen','E4DBC4');tie=mat('25 violet cravat','55415D');pants=mat('26 brown charcoal trousers','3D3830');leather=mat('27 warm brown boots','594938',.58);sole=mat('28 boot sole','332B23',.8)
irisouter=mat('30 iris dark rim','604322',.42);iris=mat('31 amber iris','9D7837',.33);irislight=mat('32 iris warm inner','B88B3D',.34);pupil=mat('33 dark brown pupil','221D15',.19);white=mat('34 warm eye white','DCD1B8',.4);highlight=mat('35 eye reflection','FFF9E8',.15);nosemat=mat('36 peach brown nose','B0876B',.52);mouthmat=mat('37 mouth warm shadow','85745D',.85)
def select(o):bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
def finish(o,name,m,smooth=True):
    o.name=name;select(o);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    if m:o.data.materials.clear();o.data.materials.append(m)
    for p in o.data.polygons:p.use_smooth=smooth
    parts.append(o);return o
def mesh(name,vs,fs,m=None,smooth=True):
    d=bpy.data.meshes.new(name);d.from_pydata(vs,[],fs);d.update();o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);return finish(o,name,m,smooth)
def ell(name,loc,scale,m=None,seg=24,rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,location=loc);o=bpy.context.object;o.scale=scale;return finish(o,name,m)
def path(points,steps=5,closed=False):
    p=[Vector(v) for v in points];out=[]
    for i in range(len(p) if closed else len(p)-1):
        a=p[(i-1)%len(p)] if closed or i else p[i];b=p[i];c=p[(i+1)%len(p)];d=p[(i+2)%len(p)] if closed or i+2<len(p) else c
        for j in range(steps):
            t=j/steps;out.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    if not closed:out.append(p[-1])
    return out
def tube(name,pts,radii,m=None,sides=12,depth=1,closed=False,smooth=True):
    pts=[Vector(p) for p in pts];vs=[]
    for i,p in enumerate(pts):
        t=pts[(i+1)%len(pts)]-pts[(i-1)%len(pts)] if closed else pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]
        t.normalize();a=t.cross(Vector((0,1,0)))
        if a.length<.01:a=t.cross(Vector((1,0,0)))
        a.normalize();b=t.cross(a).normalized();r=radii[i] if isinstance(radii,list) else radii
        for j in range(sides):vs.append(tuple(p+r*(math.cos(j*math.tau/sides)*a+depth*math.sin(j*math.tau/sides)*b)))
    fs=[(i*sides+j,i*sides+(j+1)%sides,((i+1)%len(pts))*sides+(j+1)%sides,((i+1)%len(pts))*sides+j) for i in range(len(pts) if closed else len(pts)-1) for j in range(sides)]
    if not closed:fs.extend((tuple(reversed(range(sides))),tuple((len(pts)-1)*sides+j for j in range(sides))))
    return mesh(name,vs,fs,m,smooth)
def join(objs,name):
    select(objs[0])
    for o in objs:o.select_set(True)
    bpy.ops.object.join();o=bpy.context.object;o.name=name;return o
def sculpt_union(objs,name,m,voxel=.008,reduction=.14,smooth_iters=3):
    o=join(objs,name);mod=o.modifiers.new('Connected sculpt surface','REMESH');mod.mode='VOXEL';mod.voxel_size=voxel;mod.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=o.modifiers.new('Sculpt relaxation','SMOOTH');mod.factor=.55;mod.iterations=smooth_iters;bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=o.modifiers.new('Sculpt topology','DECIMATE');mod.ratio=reduction;bpy.ops.object.modifier_apply(modifier=mod.name)
    o.data.materials.clear();o.data.materials.append(m);o.data.validate(clean_customdata=True)
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);edges=[e for e in bm.edges if e.is_boundary]
    if edges:bmesh.ops.holes_fill(bm,edges=edges,sides=0)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
    return o
def patch(name,outline,center,m,depth=.035,sub=1):
    pts=path(outline,3,True);n=len(pts);c=Vector(center);vs=[]
    # Three concentric rings give a rounded surface, rather than a flat fan.
    for r in (1,.66,.30):
        for p in pts:
            q=c+(p-c)*r;q.y=p.y*r+c.y*(1-r)-.006*math.sin(math.pi*r);vs.append(tuple(q))
    vs.append(tuple(c));front=len(vs)
    vs.extend((x,y+depth,z) for x,y,z in vs[:front])
    fs=[]
    for k in range(2):
        for j in range(n):fs.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
    fs.extend((2*n+j,2*n+(j+1)%n,3*n) for j in range(n))
    fs+= [tuple(front+i for i in reversed(f)) for f in list(fs)]
    fs.extend((j,j+front,(j+1)%n+front,(j+1)%n) for j in range(n))
    o=mesh(name,vs,fs,m)
    if sub:
        select(o);md=o.modifiers.new('Soft sculpted edges','SUBSURF');md.levels=sub;bpy.ops.object.modifier_apply(modifier=md.name)
    return o
def panel(name,pts,m,depth=.012,bevel=.004):
    n=len(pts);vs=list(pts)+[(x,y+depth,z) for x,y,z in pts];fs=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
    o=mesh(name,vs,fs,m)
    if bevel:
        select(o);md=o.modifiers.new('Tailored edge bevel','BEVEL');md.width=bevel;md.segments=3;bpy.ops.object.modifier_apply(modifier=md.name)
    return o
def button(name,loc,r=.012,m=gold):return ell(name,loc,(r,.006,r),m,16,8)
