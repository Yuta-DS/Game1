"""Cast-derived Milo. Writes exclusively to this local review directory."""
from pathlib import Path
import bpy, math, json
from mathutils import Vector, Matrix
OUT=Path(__file__).resolve().parent
ASSETS=OUT.parent/'artea/assets3D/characters'
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene

def linear(v): return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
def rgba(h): return tuple(linear(int(h[i:i+2],16)/255) for i in (0,2,4))+(1,)
def material(name,h):
    m=bpy.data.materials.new(name);m.diffuse_color=rgba(h);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=m.diffuse_color;p.inputs['Roughness'].default_value=.88;p.inputs['Specular IOR Level'].default_value=.18
    return m
fur=material('Biscuit fur','C99B63');cream=material('Warm ivory muzzle','ECD8B1');white=material('Moustache ivory','E7E2CC');dark=material('Bean eyes','242829');earmat=material('Warm inner ear','AB745F');brass=material('Muted bronze glasses','755A34');nosemat=material('Nose','684638');leather=material('Cane leatherwood','614939');stripe=material('Tabby markings','A1764E')

bpy.ops.import_scene.gltf(filepath=str(ASSETS/'Rogue.glb'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.name='Milo_Cast_Rig';rig.data.name='Milo_Cast_Skeleton'
ad=rig.animation_data;chosen={}
for tr in list(ad.nla_tracks):
    if tr.name in ('Idle','Walking_A','Use_Item','Wave'):
        chosen[tr.name]=(tr.strips[0].action,tr.strips[0].action_slot)
    ad.nla_tracks.remove(tr)
assert 'Idle' in chosen and 'Walking_A' in chosen
ad.action=None
for name,(act,slot) in chosen.items():
    act.name=name;track=ad.nla_tracks.new();track.name=name;strip=track.strips.new(name,0,act);strip.action_slot=slot;track.mute=True
def pose(name,frame=0):
    act,slot=chosen[name];ad.action=act;ad.action_slot=slot;scene.frame_set(frame);bpy.context.view_layer.update()
body=[]
for o in list(bpy.data.objects):
    if o.type!='MESH':continue
    if o.name in ('Rogue_Body','Rogue_ArmLeft','Rogue_ArmRight','Rogue_LegLeft','Rogue_LegRight'):body.append(o)
    else:bpy.data.objects.remove(o,do_unlink=True)

palette=bpy.data.materials.new('Cast palette — matte vertex color');palette.use_nodes=True
bs=palette.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.9;bs.inputs['Specular IOR Level'].default_value=.16
attr=palette.node_tree.nodes.new('ShaderNodeVertexColor');attr.layer_name='Color';palette.node_tree.links.new(attr.outputs['Color'],bs.inputs['Base Color'])
for o in body:
    old=o.data.materials[0];img=next(n.image for n in old.node_tree.nodes if n.type=='TEX_IMAGE');w,h=img.size;pix=list(img.pixels);uv=o.data.uv_layers.active.data
    ca=o.data.color_attributes.new(name='Color',type='BYTE_COLOR',domain='CORNER')
    for p in o.data.polygons:
        u=sum(uv[i].uv.x for i in p.loop_indices)/len(p.loop_indices);v=sum(uv[i].uv.y for i in p.loop_indices)/len(p.loop_indices);idx=(max(0,min(h-1,int(v*h)))*w+max(0,min(w-1,int(u*w))))*4;r,g,b=pix[idx:idx+3]
        center=sum((o.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
        if 'Arm' in o.name and abs(center.x)>.735:target='C99B63'
        elif g>r*1.3 and g>b*.9:target='60798E' if 'Body' in o.name and center.z>1.06 else '344C62'
        elif r>.88 and g>.5:target='C99B63'
        elif r>g*1.2 and r>b*1.3:target='70523D'
        else:target='AC9870'
        base=rgba(target);variation=.88+.18*max(r,g,b)
        for i in p.loop_indices:ca.data[i].color=tuple(c*variation for c in base[:3])+(1,)
        p.material_index=0
    o.data.materials.clear();o.data.materials.append(palette);o.name=o.name.replace('Rogue_','Milo_')

before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(OUT/'head_seed.glb'));new=set(bpy.data.objects)-before
head=next(o for o in new if o.type=='MESH' and len(o.data.polygons)>0);matrix=head.matrix_world.copy();head.parent=None;head.matrix_world=matrix
for mod in list(head.modifiers):head.modifiers.remove(mod)
bpy.ops.object.select_all(action='DESELECT');head.select_set(True);bpy.context.view_layer.objects.active=head;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for o in new:
    if o!=head:bpy.data.objects.remove(o,do_unlink=True)
head.name='Milo_Chubby_Cat_Head';head.vertex_groups.clear();vg=head.vertex_groups.new(name='head');vg.add(list(range(len(head.data.vertices))),1,'REPLACE');head.parent=rig;mod=head.modifiers.new('Cast head skin','ARMATURE');mod.object=rig
# Keep AnyCreature's AO/gradient on its head material; simplify reflectance to the cast.
for m in head.data.materials:
    if m.use_nodes:
        p=m.node_tree.nodes.get('Principled BSDF')
        if p:p.inputs['Roughness'].default_value=.92;p.inputs['Specular IOR Level'].default_value=.16
parts=[]
def bind(o,mat,bone='head'):
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    o.data.materials.clear();o.data.materials.append(mat);o.parent=rig;o.vertex_groups.clear();g=o.vertex_groups.new(name=bone);g.add(list(range(len(o.data.vertices))),1,'REPLACE');m=o.modifiers.new('Cast skin','ARMATURE');m.object=rig;parts.append(o);return o
def ellipsoid(name,loc,scale,mat,bone='head',segments=12,rings=6):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=loc);o=bpy.context.object;o.name=name;o.scale=scale
    for p in o.data.polygons:p.use_smooth=True
    return bind(o,mat,bone)
def mesh(name,verts,faces,mat,bone='head'):
    m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update();o=bpy.data.objects.new(name,m);scene.collection.objects.link(o);return bind(o,mat,bone)
def tube(name,points,radius,mat,bone='head',sides=6,closed=False):
    points=[Vector(p) for p in points];verts=[]
    for i,p in enumerate(points):
        t=(points[(i+1)%len(points)]-points[i-1 if i else (len(points)-1 if closed else 0)]).normalized()
        if not t.length:t=Vector((0,0,1))
        a=t.cross(Vector((0,1,0)))
        if a.length<.01:a=t.cross(Vector((1,0,0)))
        a.normalize();b=t.cross(a).normalized()
        verts.extend(tuple(p+radius*(math.cos(j*math.tau/sides)*a+math.sin(j*math.tau/sides)*b)) for j in range(sides))
    faces=[]
    for i in range(len(points) if closed else len(points)-1):
        for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,((i+1)%len(points))*sides+(j+1)%sides,((i+1)%len(points))*sides+j))
    if not closed:faces.extend((tuple(reversed(range(sides))),tuple((len(points)-1)*sides+j for j in range(sides))))
    return mesh(name,verts,faces,mat,bone)

# New facial language: same small dark bean eyes as the actual cast.
for s in (-1,1):
    mesh('Milo_Ear',[(s*.22,.005,1.84),(s*.46,.04,1.89),(s*.415,.045,2.19),(s*.29,-.135,1.85),(s*.445,-.10,1.91),(s*.402,-.085,2.13)],[(0,2,1),(3,4,5),(0,3,5,2),(2,5,4,1),(1,4,3,0)],fur)
    mesh('Milo_Inner_Ear',[(s*.32,-.139,1.90),(s*.427,-.112,1.934),(s*.403,-.098,2.079)],[(0,1,2)],earmat)
    ellipsoid('Milo_Cream_Cheek',(s*.155,-.259,1.405),(.205,.085,.125),cream)
    ellipsoid('Milo_Bean_Eye',(s*.165,-.297,1.658),(.043,.025,.063),dark)
    # Small, open spectacles. No glass, giant rims, sclera or iris layers.
    pts=[(s*.165+.098*math.cos(a),-.329,1.658+.099*math.sin(a)) for a in [i*math.tau/12 for i in range(12)]]
    tube('Milo_Spectacle_Rim',pts,.009,brass,closed=True)
    tube('Milo_Spectacle_Arm',[(s*.262,-.325,1.671),(s*.38,-.252,1.695),(s*.402,-.025,1.7)],.009,brass)
    # One readable white brow and swept moustache wedge per side.
    mesh('Milo_Brow',[(s*.08,-.303,1.792),(s*.245,-.283,1.796),(s*.253,-.285,1.757),(s*.096,-.321,1.766),(s*.172,-.329,1.801)],[(0,1,4),(1,2,3,4),(0,4,3)],white)
    mesh('Milo_Moustache',[(s*.023,-.355,1.459),(s*.14,-.361,1.487),(s*.282,-.306,1.474),(s*.215,-.335,1.406),(s*.079,-.371,1.403),(s*.143,-.399,1.447)],[(0,1,5),(1,2,5),(2,3,5),(3,4,5),(4,0,5),(0,4,3,2,1)],white)
    mesh('Milo_Temple_Stripe',[(s*.307,-.253,1.64),(s*.402,-.147,1.66),(s*.408,-.115,1.621),(s*.33,-.242,1.604)],[(0,1,2,3)],stripe)
tube('Milo_Glasses_Bridge',[(-.067,-.329,1.67),(0,-.346,1.681),(.067,-.329,1.67)],.009,brass)
mesh('Milo_Nose',[(-.058,-.356,1.514),(.058,-.356,1.514),(0,-.389,1.468),(0,-.399,1.505)],[(0,1,3),(1,2,3),(2,0,3),(0,2,1)],nosemat)
tube('Milo_Smile',[(-.05,-.349,1.391),(0,-.355,1.384),(.05,-.349,1.391)],.006,nosemat)
for x in (-.11,0,.11):
    mesh('Milo_Forehead_Tab',[ (x-.021,-.238,1.848),(x+.021,-.238,1.848),(x+.013,-.283,1.783),(x-.011,-.283,1.783)],[(0,1,2,3)],stripe)

# Short curved tail, with a restrained silhouette behind the belt.
tailpts=[(0,.24,.69),(.12,.39,.68),(.27,.47,.75),(.4,.48,.9),(.43,.44,1.04)]
tube('Milo_Tail',tailpts,.068,fur,bone='hips',sides=8)
ellipsoid('Milo_Tail_Tip',tailpts[-1],(.069,.069,.075),cream,bone='hips')

pose('Idle',0)
# Build cane in the held idle pose, then reverse the hand deformation into bind space.
pb=rig.pose.bones['hand.r'];grip=rig.matrix_world@(pb.matrix@Vector((0,.035,0)))
cx=grip.x-.075;cy=grip.y-.025;gz=grip.z
staff=tube('Milo_Walking_Stick',[(cx,cy,.045),(cx,cy,gz+.025),(cx+.025,cy,gz+.065),(cx+.075,cy,gz+.065),(cx+.102,cy,gz+.035)],.022,leather,bone='hand.r',sides=8)
undo=(pb.matrix@pb.bone.matrix_local.inverted()).inverted()
for v in staff.data.vertices:v.co=undo@v.co

# Combine facial/prop pieces: keep cast body meshes separate for easy editing.
faceparts=[head]+parts
bpy.ops.object.select_all(action='DESELECT')
for o in faceparts:o.select_set(True)
bpy.context.view_layer.objects.active=head;bpy.ops.object.join();head.name='Milo_Head_and_Identity'
scene.render.fps=24;scene.frame_start=0;scene.frame_end=26;pose('Idle',0)
rig['design']='Cast-matched scholar cat; Rogue donor body and native skeleton, new AnyCreature head'
rig['source']='Project-local Rogue.glb; preserve original licensing'
rig['local_review_only']=True
character=[rig]+body+[head]
scene['candidate']='Milo cast redesign — not integrated into the live game'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'milo_cast.blend'))
bpy.ops.object.select_all(action='DESELECT')
for o in character:o.select_set(True)
bpy.context.view_layer.objects.active=rig
ad.action=None
bpy.ops.export_scene.gltf(filepath=str(OUT/'milo_cast.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,export_materials='EXPORT',export_skins=True,export_def_bones=False,export_yup=True)
pose('Idle',0)
(OUT/'build_report.json').write_text(json.dumps({'meshes':len(body)+1,'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in body+[head]),'bones':len(rig.data.bones),'actions':list(chosen),'cane_grip':list(grip),'native_file':'milo_cast.blend','runtime_file':'milo_cast.glb'},indent=2))
print('MILO_CAST_BUILD_COMPLETE',flush=True)
