"""Compact feline head and a supported walking-cane grip, isolated from game assets."""
from pathlib import Path
import bpy,bmesh,math,json
from mathutils import Vector
OUT=Path(__file__).resolve().parent
# Reuse the inspected mesh helpers and the original coat/rig cleanup only.
HELPERS=OUT.parent/'statue-face-paws/refine_face_paws.py'
exec(compile(HELPERS.read_text().split('# New AnyCreature skull/cheeks')[0],str(HELPERS),'exec'))
cream=material('Cat warm cream','E6D5B1');fur_light=material('Cat muzzle cream','F0E0BF')
fur_point=material('Soft caramel paws','C69B66');wood=material('Walnut cane','65452F',.68)
rubber=material('Cane ferrule','343333',.9);eye_blue=material('Quiet blue eyes','456577',.5)
eye_dark=material('Cat dark eyes','172831',.5);frame_mat=material('Fine aged-gold glasses','A48655',.6,.18)
crease=material('Soft muzzle crease','91664E')
# The new cane is modeled as a handle, shaft and ferrule. Keep the old tail only.
bm=bmesh.new();bm.from_mesh(identity.data);layer=bm.verts.layers.deform.active;gi=identity.vertex_groups['hand.r'].index
bmesh.ops.delete(bm,geom=[v for v in bm.verts if v[layer].get(gi,0)>.9],context='VERTS');bm.to_mesh(identity.data);bm.free();identity.name='Milo_Preserved_Tail'
before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(OUT/'head_seed.glb'));new=set(bpy.data.objects)-before;head=next(o for o in new if o.type=='MESH' and len(o.data.polygons)>100)
world=head.matrix_world.copy();head.parent=None;head.matrix_world=world
for mod in list(head.modifiers):head.modifiers.remove(mod)
select(head);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for o in new:
    if o!=head:bpy.data.objects.remove(o,do_unlink=True)
sub=head.modifiers.new('Continuous cheek topology','SUBSURF');sub.levels=1;select(head);bpy.ops.object.modifier_apply(modifier=sub.name)
# Low, paired muzzle pads grow directly from the cheek surface, not separate balls.
for v in head.data.vertices:
    x,y,z=v.co;front=max(0,min(1,-y/.19))
    pads=sum(math.exp(-((x-s*.068)/.098)**2-((z-1.474)/.075)**2) for s in (-1,1))
    v.co.y-=front*.051*pads
    v.co.x*=1+.014*math.exp(-((z-1.48)/.07)**2)
facemat=material('Natural cat face colours','FFFFFF');node=facemat.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='StatueColor';facemat.node_tree.links.new(node.outputs['Color'],facemat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
bind(head,facemat);head.name='Milo_Natural_Face'
for a in list(head.data.color_attributes):head.data.color_attributes.remove(a)
attr=head.data.color_attributes.new(name='StatueColor',type='BYTE_COLOR',domain='CORNER');head.data.color_attributes.active_color_index=0;head.data.color_attributes.render_color_index=0
base=rgba('E6D5B1');point=rgba('C09A6C');muzzle=rgba('F0E0BF')
for p in head.data.polygons:
    p.use_smooth=True
    for index in p.loop_indices:
        x,y,z=head.data.vertices[head.data.loops[index].vertex_index].co
        d=min(((x-s*.15)/.145)**2+((z-1.627)/.115)**2 for s in (-1,1))
        t=max(0,min(1,(1.5-d)/1.1))*max(0,min(1,(-y-.12)/.12));t=t*t*(3-2*t)*.8
        mu=math.exp(-(x/.205)**4-((z-1.472)/.097)**4)*max(0,min(1,(-y-.16)/.15))
        shade=.94+.055*max(0,min(1,(z-1.3)/.65))
        attr.data[index].color=tuple(((base[k]*(1-t)+point[k]*t)*(1-mu)+muzzle[k]*mu)*shade for k in range(3))+(1,)
def surface(x,z):
    hit,co,normal,index=head.ray_cast(Vector((x,-2,z)),Vector((0,1,0)))
    return co.y if hit else -.26
ellipsoid('Short fur neck',(0,.015,1.29),(.117,.12,.135),cream)
# Ear shells have buried roots, softer tips, and a shallow inset bowl.
for s in (-1,1):
    outline=sample_curve([(s*.22,0,1.77),(s*.247,0,1.89),(s*.350,0,2.027),(s*.382,0,2.045),(s*.402,0,2.002),(s*.405,0,1.825),(s*.35,0,1.755)],5,True)
    center=Vector((s*.331,0,1.884));n=len(outline)
    front=[(p.x,-.03+(p.z-1.8)*.15,p.z) for p in outline];back=[(x,y+.085,z) for x,y,z in front]
    verts=front+back+[(center.x,-.040,center.z),(center.x,.105,center.z)]
    faces=[(i,(i+1)%n,2*n) for i in range(n)]+[(n+(i+1)%n,n+i,2*n+1) for i in range(n)]+[(i,n+i,n+(i+1)%n,(i+1)%n) for i in range(n)]
    mesh('Short sculpted ear',verts,faces,fur_point)
    innerpts=[center+(p-center)*.61 for p in outline]
    mesh('Ear inset',[(p.x,-.044+(p.z-1.88)*.10,p.z) for p in innerpts]+[(center.x,-.049,center.z)],[(i,(i+1)%n,n) for i in range(n)],inner)
for s in (-1,1):
    ex=s*.157;ez=1.634;ey=surface(ex,ez)
    ellipsoid('Small blue iris',(ex,ey-.012,ez),(.052,.026,.063),eye_blue)
    ellipsoid('Quiet dark pupil',(ex,ey-.033,ez+.001),(.043,.011,.055),eye_dark)
    ellipsoid('Small eye glint',(ex-.012,ey-.045,ez+.022),(.006,.003,.0075),glint)
    pts=[]
    for j in range(32):
        a=j*math.tau/32;x=ex+.084*math.cos(a);z=ez+.086*math.sin(a)
        pts.append((x,surface(x,z)-.043,z))
    sweep('Fine curved spectacle',pts,.006,frame_mat,closed=True,sides=8)
    sweep('Spectacle temple',sample_curve([(s*.239,surface(s*.239,ez)-.043,ez),(s*.342,-.196,1.672),(s*.383,-.026,1.713)],5),.0055,frame_mat,sides=8)
    pts=[]
    for x,z in [(s*.086,1.739),(s*.143,1.764),(s*.204,1.756),(s*.232,1.739)]:pts.append((x,surface(x,z)-.004,z))
    pts=sample_curve(pts,5);sweep('Low soft brow',pts,[.002+.013*math.sin(math.pi*i/(len(pts)-1))**.6 for i in range(len(pts))],fur_light,flatten=.7)
    # Short whisker marks follow the muzzle, avoiding the earlier floating moustache.
    for k in range(2):
        pts=[]
        for x,z in [(s*.125,1.48-k*.024),(s*.165,1.489-k*.022),(s*.198,1.496-k*.022)]:pts.append((x,surface(x,z)-.002,z))
        sweep('Subtle whisker crease',sample_curve(pts,4),.0025,crease,sides=6)
pts=sample_curve([(-.073,surface(-.073,1.65)-.043,1.65),(0,surface(0,1.665)-.031,1.665),(.073,surface(.073,1.65)-.043,1.65)],5);sweep('Glasses bridge',pts,.0055,frame_mat,sides=8)
nosez=1.508;nosey=surface(0,nosez)
outline=sample_curve([(-.035,0,nosez+.013),(.035,0,nosez+.013),(.023,0,nosez-.008),(0,0,nosez-.029),(-.023,0,nosez-.008)],4,True);n=len(outline)
mesh('Compact pink nose',[(p.x,nosey-.007,p.z) for p in outline]+[(0,nosey-.027,nosez),(0,nosey+.015,nosez)],[(i,(i+1)%n,n) for i in range(n)]+[((i+1)%n,i,n+1) for i in range(n)],pink)
def facecurve(name,xzs,radius):return sweep(name,sample_curve([(x,surface(x,z)-.004,z) for x,z in xzs],4),radius,crease,sides=6)
facecurve('Cat philtrum',[(0,1.479),(0,1.456)],.003)
for s in (-1,1):facecurve('Small cat smile',[(0,1.456),(s*.024,1.444),(s*.049,1.456)],.003)
# Accessories remain a separate material group so face colours export reliably.
features=[o for o in parts if o!=head];select(features[0])
for o in features:o.select_set(True)
bpy.ops.object.join();bpy.context.object.name='Milo_Natural_Features'
ad.action,ad.action_slot=clips['Idle'];scene.frame_set(0);bpy.context.view_layer.update()
def sculpt_paw(objects,name,bone):
    select(objects[0])
    for o in objects:o.select_set(True)
    bpy.ops.object.join();o=bpy.context.object;o.name=name
    rem=o.modifiers.new('Joined finger roots','REMESH');rem.mode='VOXEL';rem.voxel_size=.0045;rem.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=rem.name)
    sm=o.modifiers.new('Restrained smoothing','SMOOTH');sm.factor=.55;sm.iterations=2;bpy.ops.object.modifier_apply(modifier=sm.name)
    dec=o.modifiers.new('Compact paw topology','DECIMATE');dec.ratio=.20;bpy.ops.object.modifier_apply(modifier=dec.name)
    for p in o.data.polygons:p.use_smooth=True
    return bind(o,fur_point,bone,True)
# Relaxed paw: narrow wrist, compact palm, three short digits rather than a fist.
pb=rig.pose.bones['hand.l'];wrist=rig.pose.bones['wrist.l'].head.copy();c=pb.head+Vector((0,-.008,-.025));pieces=[ellipsoid('Compact palm',c,(.076,.050,.063))]
pieces.append(sweep('Slim wrist',sample_curve([wrist,pb.head,c+Vector((0,0,.03))],3),[.059,.059,.057,.055,.055,.056,.056],sides=12))
for dx,length in [(-.047,.057),(0,.067),(.047,.054)]:
    pts=sample_curve([c+Vector((dx,-.001,-.028)),c+Vector((dx,-.015,-length)),c+Vector((dx,-.032,-length+.003))],3)
    pieces.append(sweep('Short relaxed digit',pts,[.025,.026,.025,.024,.022,.016,.009],sides=10))
pts=sample_curve([c+Vector((-.062,.002,.019)),c+Vector((-.088,-.012,-.005)),c+Vector((-.083,-.035,-.026))],3);pieces.append(sweep('Small opposing thumb',pts,[.025,.026,.025,.024,.022,.016,.008],sides=10))
sculpt_paw(pieces,'Milo_Compact_Paw_l','hand.l')
# Grip is built around a horizontal handle. Offset shaft avoids the curled fingers.
cx=-.58;cy=-.145;hz=.708;shaft_x=cx+.083
pb=rig.pose.bones['hand.r'];wrist=rig.pose.bones['wrist.r'].head.copy();palm=Vector((cx,cy+.030,hz+.051))
pieces=[ellipsoid('Supported grip palm',palm,(.075,.054,.043))]
pieces.append(sweep('Aligned grip wrist',sample_curve([wrist,pb.head+Vector((0,0,.025)),palm],3),[.059,.059,.058,.057,.055,.055,.051],sides=12))
for dx in (-.054,-.012,.030):
    pts=[(cx+dx,cy+.040*math.cos(a),hz+.040*math.sin(a)) for a in [math.radians(75+j*21) for j in range(11)]]
    pieces.append(sweep('Finger over and under handle',pts,[.024,.024,.023,.021,.020,.019,.018,.017,.016,.014,.009],sides=10))
pts=sample_curve([palm+Vector((.058,.006,.003)),Vector((cx+.077,cy-.005,hz+.049)),Vector((cx+.062,cy-.033,hz+.035))],4);pieces.append(sweep('Thumb beside handle stem',pts,[.023,.024,.024,.023,.022,.021,.019,.014,.008],sides=10))
sculpt_paw(pieces,'Milo_Compact_Paw_r','hand.r')
cane=[]
cane.append(sweep('Tapered cane shaft',[(shaft_x,cy,.024),(shaft_x,cy,.28),(shaft_x,cy,.52),(shaft_x,cy,hz-.009)],[.013,.014,.015,.017],sides=12))
pts=sample_curve([(cx-.126,cy,hz-.012),(cx-.105,cy,hz+.005),(cx-.05,cy,hz+.005),(cx+.053,cy,hz+.004),(cx+.107,cy,hz-.013)],5)
cane.append(sweep('Visible ergonomic handle',pts,[.012+.011*math.sin(math.pi*i/(len(pts)-1))**.3 for i in range(len(pts))],sides=12))
cane.append(ellipsoid('Rounded handle end',(cx-.126,cy,hz-.012),(.013,.013,.013)))
for o in cane:bind(o,wood,'hand.r',True)
select(cane[0])
for o in cane:o.select_set(True)
bpy.ops.object.join();bpy.context.object.name='Milo_Handled_Cane'
f=sweep('Cane ferrule',[(shaft_x,cy,.008),(shaft_x,cy,.031)],.018,sides=12);bind(f,rubber,'hand.r',True);f.name='Milo_Cane_Ferrule'
collar=sweep('Cane small collar',[(shaft_x,cy,hz-.05),(shaft_x,cy,hz-.037)],.0185,sides=12);bind(collar,frame_mat,'hand.r',True);collar.name='Milo_Cane_Collar'
rig['revision']='Compact cat face; supported handle grip; original coat/body actions'
scene.frame_set(0);bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'milo_natural_face_grip.blend'))
ad.action=None;bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    if o.type in ('MESH','ARMATURE'):o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'milo_natural_face_grip.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,export_skins=True,export_yup=True,export_all_vertex_colors=False)
report={'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.data.objects if o.type=='MESH'),'bones':len(rig.data.bones),'actions':list(clips),'cane_handle_center':[cx,cy,hz],'shaft_axis':[shaft_x,cy],'scope':'Local face/paws/cane revision; no game integration'}
(OUT/'build_report.json').write_text(json.dumps(report,indent=2));print('NATURAL_FACE_GRIP_DONE',report)
