"""Statue-inspired face and unified sculpted paws; preserve the suit and body actions."""
from pathlib import Path
import bpy,bmesh,math,json
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT.parent/'luxury-coat/milo_luxury_coat.blend'))
scene=bpy.context.scene;rig=bpy.data.objects['Milo_Cast_Rig'];ad=rig.animation_data
clips={tr.name:(tr.strips[0].action,tr.strips[0].action_slot) for tr in ad.nla_tracks}
ad.action=None
for tr in ad.nla_tracks:tr.mute=True
for b in rig.pose.bones:b.matrix_basis.identity()
bpy.context.view_layer.update()
def linear(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
def rgba(h):return tuple(linear(int(h[i:i+2],16)/255) for i in (0,2,4))+(1,)
def material(name,h,rough=.84,metal=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=rgba(h);p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=m.diffuse_color;p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal;p.inputs['Specular IOR Level'].default_value=.25;return m
cream=material('Statue warm cream','E8D7B3');ivory=material('Soft ivory whisker fur','F0E4CA');caramel=material('Statue caramel points','AD713B');pink=material('Rose pink nose','C8867A',.7);inner=material('Warm rose ear','C89481');eye=material('Soft blue iris','5B9FB9',.42);pupil=material('Deep navy pupil','182E3E',.40);glint=material('Eye glint','F4EFE0',.4);bronze=material('Brushed gold spectacles','AA8544',.50,.25);mouthmat=material('Muzzle crease','7D5037')
def select(o):bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
def delete_vertices(obj,test):
    bm=bmesh.new();bm.from_mesh(obj.data);bm.verts.ensure_lookup_table();bmesh.ops.delete(bm,geom=[v for v in bm.verts if test(v)],context='VERTS');bm.to_mesh(obj.data);bm.free();obj.data.update()
identity=bpy.data.objects['Milo_Head_and_Identity'];head_group=identity.vertex_groups['head'].index
bm=bmesh.new();bm.from_mesh(identity.data);layer=bm.verts.layers.deform.active;bmesh.ops.delete(bm,geom=[v for v in bm.verts if v[layer].get(head_group,0)>.9],context='VERTS');bm.to_mesh(identity.data);bm.free();identity.name='Milo_Preserved_Tail_and_Cane'
for name in ('Milo_ArmLeft','Milo_ArmRight'):delete_vertices(bpy.data.objects[name],lambda v:abs(v.co.x)>.711)
parts=[]
def bind(o,m,bone='head',posed=False):
    select(o);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    if posed:
        pb=rig.pose.bones[bone];undo=(pb.matrix@pb.bone.matrix_local.inverted()).inverted()
        for v in o.data.vertices:v.co=undo@v.co
    o.data.materials.clear();o.data.materials.append(m);o.vertex_groups.clear();g=o.vertex_groups.new(name=bone);g.add(list(range(len(o.data.vertices))),1,'REPLACE');o.parent=rig;mod=o.modifiers.new('Milo skin','ARMATURE');mod.object=rig
    parts.append(o);return o
def mesh(name,verts,faces,m=None,bone='head'):
    d=bpy.data.meshes.new(name);d.from_pydata(verts,[],faces);d.update();o=bpy.data.objects.new(name,d);scene.collection.objects.link(o)
    for p in d.polygons:p.use_smooth=True
    return bind(o,m,bone) if m else o
def ellipsoid(name,loc,scale,m=None,bone='head'):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;select(o);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    for p in o.data.polygons:p.use_smooth=True
    return bind(o,m,bone) if m else o
def sample_curve(points,steps=6,closed=False):
    points=[Vector(p) for p in points];out=[]
    for i in range(len(points) if closed else len(points)-1):
        a=points[(i-1)%len(points)] if closed or i>0 else points[i];b=points[i];c=points[(i+1)%len(points)];d=points[(i+2)%len(points)] if closed or i+2<len(points) else c
        for k in range(steps):
            t=k/steps;out.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    if not closed:out.append(points[-1])
    return out
def sweep(name,points,radii,m=None,bone='head',closed=False,sides=8,flatten=1):
    pts=[Vector(p) for p in points];verts=[]
    for i,p in enumerate(pts):
        tangent=(pts[(i+1)%len(pts)]-pts[(i-1)%len(pts)]) if closed else pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]
        tangent.normalize();a=tangent.cross(Vector((0,1,0)))
        if a.length<.01:a=tangent.cross(Vector((1,0,0)))
        a.normalize();b=tangent.cross(a).normalized();r=radii[i] if isinstance(radii,list) else radii
        verts.extend(tuple(p+r*(math.cos(j*math.tau/sides)*a+flatten*math.sin(j*math.tau/sides)*b)) for j in range(sides))
    faces=[(i*sides+j,i*sides+(j+1)%sides,((i+1)%len(pts))*sides+(j+1)%sides,((i+1)%len(pts))*sides+j) for i in range(len(pts) if closed else len(pts)-1) for j in range(sides)]
    if not closed:faces.extend((tuple(reversed(range(sides))),tuple((len(pts)-1)*sides+j for j in range(sides))))
    return mesh(name,verts,faces,m,bone)

# New AnyCreature skull/cheeks, treated as one continuous soft volume.
before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(OUT/'head_seed.glb'));new=set(bpy.data.objects)-before;head=next(o for o in new if o.type=='MESH' and len(o.data.polygons)>100)
world=head.matrix_world.copy();head.parent=None;head.matrix_world=world
for mod in list(head.modifiers):head.modifiers.remove(mod)
select(head);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for o in new:
    if o!=head:bpy.data.objects.remove(o,do_unlink=True)
sub=head.modifiers.new('Soft cheek topology','SUBSURF');sub.levels=1;select(head);bpy.ops.object.modifier_apply(modifier=sub.name)
for v in head.data.vertices:
    x,y,z=v.co;front=max(0,min(1,-y/.15));v.co.y-=front*.070*math.exp(-(x/.23)**4-((z-1.455)/.125)**2)
    v.co.x*=1+.022*math.exp(-((z-1.48)/.13)**2)
head.name='Milo_Statue_Face'
facemat=material('Statue face color','FFFFFF');node=facemat.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='StatueColor';facemat.node_tree.links.new(node.outputs['Color'],facemat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
bind(head,facemat)
for old_attribute in list(head.data.color_attributes):head.data.color_attributes.remove(old_attribute)
attr=head.data.color_attributes.new(name='StatueColor',type='BYTE_COLOR',domain='CORNER');base=rgba('E8D7B3');mask=rgba('AD713B')
head.data.color_attributes.active_color_index=0;head.data.color_attributes.render_color_index=0
for p in head.data.polygons:
    p.use_smooth=True
    for index in p.loop_indices:
        v=head.data.vertices[head.data.loops[index].vertex_index];x,y,z=v.co
        d=min(((x-s*.182)/.182)**2+((z-1.675)/.155)**2 for s in (-1,1));bridge=(x/.12)**2+((z-1.555)/.115)**2;d=min(d,bridge)
        t=max(0,min(1,(1.50-d)/.85))*max(0,min(1,(-y-.13)/.11));t=t*t*(3-2*t);shade=.90+.09*max(0,min(1,(z-1.3)/.66))
        attr.data[index].color=tuple((base[k]*(1-t)+mask[k]*t)*shade for k in range(3))+(1,)
def surface(x,z):
    hit,co,normal,index=head.ray_cast(Vector((x,-2,z)),Vector((0,1,0)))
    return co.y if hit else -.27

# Rounded, thick ear bowls instead of triangular blades.
for s in (-1,1):
    outline=sample_curve([(s*.24,0,1.83),(s*.27,0,1.995),(s*.395,0,2.15),(s*.432,0,2.16),(s*.458,0,2.11),(s*.475,0,1.87),(s*.40,0,1.82)],4,True)
    center=Vector((s*.37,0,1.96));front=[(v.x,-.020+max(0,v.z-1.9)*.12,v.z) for v in outline];back=[(x,y+.085,z) for x,y,z in front];n=len(front)
    verts=front+back+[(center.x,-.06,center.z),(center.x,.10,center.z)]
    faces=[(i,(i+1)%n,2*n) for i in range(n)]+[(n+(i+1)%n,n+i,2*n+1) for i in range(n)]+[(i,n+i,n+(i+1)%n,(i+1)%n) for i in range(n)]
    ear=mesh('Milo_Rounded_Ear',verts,faces,cream)
    inside=[center+(v-center)*.68 for v in outline];mesh('Milo_Ear_Inner',[(v.x,-.059+max(0,v.z-1.9)*.08,v.z) for v in inside]+[(center.x,-.064,center.z)],[(i,(i+1)%n,n) for i in range(n)],inner)
    # Thin caramel ear-tip accent from the actual statue palette.
    pts=sample_curve([(s*.28,-.011,2.005),(s*.398,.006,2.147),(s*.434,.009,2.146),(s*.463,-.003,1.99)],4)
    sweep('Milo_Caramel_Ear_Rim',pts,.014,caramel,sides=6)

eye_objects=[]
for s in (-1,1):
    ex=s*.181;ez=1.676;ey=surface(ex,ez)
    eye_objects.append(ellipsoid('Milo_Blue_Eye',(ex,ey-.014,ez),(.080,.032,.094),eye))
    eye_objects.append(ellipsoid('Milo_Dark_Pupil',(ex,ey-.040,ez+.002),(.057,.010,.074),pupil))
    eye_objects.append(ellipsoid('Milo_Eye_Glint',(ex-.023,ey-.050,ez+.035),(.012,.005,.014),glint))
    pts=[(ex+.109*math.cos(a),ey-.067,ez+.113*math.sin(a)) for a in [j*math.tau/28 for j in range(28)]]
    sweep('Milo_Round_Spectacles',pts,.0095,bronze,closed=True,sides=6)
    sweep('Milo_Glasses_Temple',sample_curve([(s*.29,ey-.062,1.69),(s*.405,-.205,1.715),(s*.44,-.045,1.72)],5),.009,bronze,sides=6)
    pts=sample_curve([(s*.080,surface(s*.080,1.805)-.022,1.805),(s*.146,surface(s*.146,1.830)-.022,1.830),(s*.225,surface(s*.225,1.823)-.022,1.823),(s*.279,surface(s*.279,1.798)-.018,1.798)],4)
    radii=[.004+.021*math.sin(math.pi*i/(len(pts)-1))**.5 for i in range(len(pts))];sweep('Milo_Soft_Brow',pts,radii,ivory,flatten=.60)
    # A swept, tapered whisker tuft: no raised crystalline triangles or cheek balls.
    pts=sample_curve([(s*.025,-.396,1.474),(s*.113,-.412,1.428),(s*.229,-.369,1.439),(s*.307,-.309,1.488)],5)
    radii=[.004+.043*math.sin(math.pi*i/(len(pts)-1))**.7 for i in range(len(pts))];sweep('Milo_Swept_Moustache',pts,radii,ivory,flatten=.60)
sweep('Milo_Spectacle_Bridge',sample_curve([(-.071,surface(-.181,1.676)-.067,1.688),(0,-.407,1.697),(.071,surface(.181,1.676)-.067,1.688)],4),.009,bronze,sides=6)
outline=sample_curve([(-.054,0,1.524),(.054,0,1.524),(.042,0,1.501),(0,0,1.470),(-.042,0,1.501)],4,True);n=len(outline)
verts=[(v.x,-.417,v.z) for v in outline]+[(0,-.439,1.508),(0,-.385,1.508)];mesh('Milo_Soft_Pink_Nose',verts,[(i,(i+1)%n,n) for i in range(n)]+[((i+1)%n,i,n+1) for i in range(n)],pink)
sweep('Milo_Muzzle_Center',[(0,-.410,1.474),(0,-.412,1.435)],.005,mouthmat,sides=6)
sweep('Milo_Gentle_Smile',sample_curve([(-.062,-.384,1.415),(0,-.405,1.405),(.062,-.384,1.415)],5),.005,mouthmat,sides=6)

# Keep the colour-painted skin separate from the plain-material accessories.
# This also prevents mixed-material COLOR_0 selection from losing the mask on export.
face_parts=[o for o in parts if o!=head];select(face_parts[0])
for o in face_parts:o.select_set(True)
bpy.context.view_layer.objects.active=face_parts[0];bpy.ops.object.join();bpy.context.object.name='Milo_Facial_Features'

# Build paws in their held/relaxed idle pose, then map them back to bind space.
ad.action,ad.action_slot=clips['Idle'];scene.frame_set(0);bpy.context.view_layer.update()
def union_paw(objects,name,bone):
    select(objects[0])
    for o in objects:o.select_set(True)
    bpy.ops.object.join();o=bpy.context.object;o.name=name
    remesh=o.modifiers.new('Unified palm and finger roots','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.007;remesh.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth=o.modifiers.new('Soft paw transitions','SMOOTH');smooth.factor=1.25;smooth.iterations=3;bpy.ops.object.modifier_apply(modifier=smooth.name)
    dec=o.modifiers.new('Game-scale paw topology','DECIMATE');dec.ratio=.30;bpy.ops.object.modifier_apply(modifier=dec.name)
    for p in o.data.polygons:p.use_smooth=True
    bind(o,cream,bone,True)
    return o
paw_report={}
for s,label in [(1,'l'),(-1,'r')]:
    pb=rig.pose.bones['hand.'+label];center=pb.matrix@Vector((0,.038,0));wrist=rig.pose.bones['wrist.'+label].head.copy();pieces=[]
    if label=='l':
        center+=Vector((0,0,.01));pieces.append(ellipsoid('Palm',center,(.101,.069,.105)))
        pieces.append(sweep('Wrist',sample_curve([wrist,center+Vector((0,0,.063)),center],3),[.065,.067,.069,.070,.075,.083,.086],sides=12))
        for i,dx in enumerate((-.058,0,.058)):
            zoff=(-.082,-.105,-.088)[i];pts=sample_curve([center+Vector((dx,-.006,-.035)),center+Vector((dx,-.035,zoff)),center+Vector((dx,-.018,zoff-.025))],3)
            pieces.append(sweep('Finger',pts,[.034,.035,.034,.032,.029,.020,.008],sides=10))
        pts=sample_curve([center+Vector((-.076,.005,.035)),center+Vector((-.122,-.013,-.010)),center+Vector((-.099,-.047,-.053))],3);pieces.append(sweep('Thumb',pts,[.041,.041,.039,.035,.031,.023,.009],sides=10))
    else:
        # Locate the existing cane shaft in this pose, not a guessed hand offset.
        group=identity.vertex_groups.get('hand.r').index;d=(pb.matrix@pb.bone.matrix_local.inverted());verts=[d@v.co for v in identity.data.vertices if any(g.group==group and g.weight>.9 for g in v.groups)];zmin=min(v.z for v in verts);bottom=[v for v in verts if v.z<zmin+.045];cx=sum(v.x for v in bottom)/len(bottom);cy=sum(v.y for v in bottom)/len(bottom);z=center.z+.01
        palm=Vector((cx+.065,cy+.038,z));pieces.append(ellipsoid('Grip palm',palm,(.070,.059,.087)))
        pieces.append(sweep('Grip wrist',sample_curve([wrist,palm+Vector((.005,.0,.06)),palm],3),[.065,.067,.07,.073,.075,.075,.072],sides=12))
        for dz in (.049,0,-.049):
            pts=[Vector((cx+.044*math.cos(a),cy+.044*math.sin(a),z+dz)) for a in [math.radians(-15-j*24) for j in range(12)]]
            pieces.append(sweep('Curled gripping finger',pts,[.031]*len(pts),sides=10))
        pts=sample_curve([palm+Vector((.028,-.03,.061)),Vector((cx+.024,cy-.062,z+.063)),Vector((cx-.007,cy-.063,z+.028))],3);pieces.append(sweep('Opposing thumb',pts,[.035,.036,.035,.033,.029,.022,.01],sides=10))
        paw_report['cane_axis']=[cx,cy]
    paw=union_paw(pieces,'Milo_Rounded_Paw_'+label,'hand.'+label);paw_report[label]={'vertices':len(paw.data.vertices),'triangles':sum(len(p.vertices)-2 for p in paw.data.polygons)}

scene.frame_set(0);rig['face_reference']='Hub statue: meshy ai/Milo_Animations.glb, existing old_milo_reference.png';rig['edit_scope']='Face and two paws; coat and body actions preserved'
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'milo_statue_face_paws.blend'))
ad.action=None;bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    if o.type in ('MESH','ARMATURE'):o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'milo_statue_face_paws.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,export_skins=True,export_yup=True,export_all_vertex_colors=False)
meshes=[o for o in bpy.data.objects if o.type=='MESH'];report={'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),'meshes':len(meshes),'bones':len(rig.data.bones),'actions':list(clips),'paws':paw_report}
(OUT/'build_report.json').write_text(json.dumps(report,indent=2));print('FACE_PAWS_BUILD_DONE',report,flush=True)
