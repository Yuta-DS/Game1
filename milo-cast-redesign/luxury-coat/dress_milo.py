"""A separate medieval-classic wardrobe variant. Original Milo is never overwritten."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT.parent/'milo_cast.blend'))
scene=bpy.context.scene;rig=bpy.data.objects['Milo_Cast_Rig'];ad=rig.animation_data
ad.action=None
for tr in ad.nla_tracks:tr.mute=True
for b in rig.pose.bones:b.matrix_basis.identity()
bpy.context.view_layer.update()
def linear(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
def color(h):return tuple(linear(int(h[i:i+2],16)/255) for i in (0,2,4))+(1,)
def mat(name,h,rough=.82,metal=0):
    m=bpy.data.materials.new(name);m.diffuse_color=color(h);m.use_nodes=True;p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=m.diffuse_color;p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal;p.inputs['Specular IOR Level'].default_value=.25
    return m
navy=mat('Royal midnight coat','293E58');lapelmat=mat('Blue satin lapels','40536D',.65);plum=mat('Burgundy waistcoat','693849');gold=mat('Antique gold braid','C9A254',.48,.32);ivory=mat('Ivory cravat','EAE1CA');lining=mat('Burgundy coat lining','713E4A');boots=mat('Espresso shoes','302D30',.62)
original_body=bpy.data.objects['Milo_Body'];bpy.data.objects.remove(original_body,do_unlink=True)
created=[]
def weights(p):
    x,y,z=p
    if z<.63:
        leg=max(0,min(.6,(.60-z)*2.1))
        return {'hips':1-leg,('upperleg.l' if x>=0 else 'upperleg.r'):leg}
    if z<.98:
        t=(z-.63)/.35;return {'hips':1-t,'spine':t}
    t=max(0,min(1,(z-.98)/.20));return {'spine':1-t,'chest':t}
def skin(o,m,bone=None):
    o.data.materials.append(m);o.parent=rig
    for v in o.data.vertices:
        for name,w in ({bone:1} if bone else weights(v.co)).items():
            if w>0:
                group=o.vertex_groups.get(name) or o.vertex_groups.new(name=name);group.add([v.index],w,'REPLACE')
    mod=o.modifiers.new('Cast wardrobe skin','ARMATURE');mod.object=rig;created.append(o);return o
def mesh(name,verts,faces,m,bone=None):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update();o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);return skin(o,m,bone)
def tube(name,pts,r,m=gold,bone=None,closed=False,sides=6):
    pts=[Vector(p) for p in pts];verts=[]
    for i,p in enumerate(pts):
        tangent=(pts[(i+1)%len(pts)]-pts[(i-1)%len(pts)]) if closed else pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]
        tangent.normalize();a=tangent.cross(Vector((0,1,0)))
        if a.length<.01:a=tangent.cross(Vector((1,0,0)))
        a.normalize();b=tangent.cross(a).normalized()
        verts.extend(tuple(p+r*(math.cos(j*math.tau/sides)*a+math.sin(j*math.tau/sides)*b)) for j in range(sides))
    faces=[]
    for i in range(len(pts) if closed else len(pts)-1):
        for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,((i+1)%len(pts))*sides+(j+1)%sides,((i+1)%len(pts))*sides+j))
    if not closed:faces.extend((tuple(reversed(range(sides))),tuple((len(pts)-1)*sides+j for j in range(sides))))
    return mesh(name,verts,faces,m,bone)
def button(name,loc,r=.017,m=gold,bone=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,location=loc);o=bpy.context.object;o.name=name;o.scale=(r,.009,r)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);return skin(o,m,bone)
def panel(name,points,m,depth=.008):
    # Closed folded cloth plaque, with a restrained bevel-like edge.
    n=len(points);verts=list(points)+[(x,y+depth,z) for x,y,z in points];faces=[tuple(range(n)),tuple(reversed(range(n,n*2)))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,verts,faces,m)

# Full waistcoat under the open outer coat: no inherited belt, scarf, armor or pouches.
profile=[(.49,.25,.24),(.60,.31,.285),(.80,.33,.31),(.98,.31,.29),(1.12,.27,.21),(1.24,.145,.135)]
verts=[];sides=24
for z,rx,ry in profile:
    verts.extend((rx*math.sin(j*math.tau/sides),-ry*math.cos(j*math.tau/sides),z) for j in range(sides))
faces=[(k*sides+j,k*sides+(j+1)%sides,(k+1)*sides+(j+1)%sides,(k+1)*sides+j) for k in range(len(profile)-1) for j in range(sides)]
faces.extend((tuple(reversed(range(sides))),tuple((len(profile)-1)*sides+j for j in range(sides))))
vest=mesh('Milo_Tailored_Waistcoat',verts,faces,plum)
for p in vest.data.polygons:p.use_smooth=True

# Long open-front coat: flared hem, narrow waist, folded notched lapels.
coatprofile=[(.34,.40,.30,.68),(.48,.395,.32,.60),(.65,.35,.335,.43),(.82,.365,.35,.45),(1.02,.34,.31,.56),(1.16,.30,.23,.43),(1.24,.18,.15,.42)]
verts=[];rows=[];n=27
for z,rx,ry,opening in coatprofile:
    row=[]
    for j in range(n):
        a=opening+(math.tau-2*opening)*j/(n-1);pz=z
        if z<.5:pz+=.07*max(0,1-abs(a-math.pi)/.25) # small rear vent for walking
        row.append((rx*math.sin(a),-ry*math.cos(a),pz))
    rows.append(row);verts.extend(row)
faces=[(k*n+j,k*n+j+1,(k+1)*n+j+1,(k+1)*n+j) for k in range(len(rows)-1) for j in range(n-1)]
coat=mesh('Milo_Open_Long_Coat',verts,faces,navy)
for p in coat.data.polygons:p.use_smooth=True
solid=coat.modifiers.new('Coat hem thickness','SOLIDIFY');solid.thickness=.012;solid.offset=-1
bpy.context.view_layer.objects.active=coat;bpy.ops.object.modifier_apply(modifier=solid.name)
# Gold piping follows the same vertices and skin weights as its cloth edge.
for side,index in [('Left',0),('Right',n-1)]:tube('Milo_Gold_Coat_Edge_'+side,[(x,y-.009,z) for x,y,z in (row[index] for row in rows)],.011)
tube('Milo_Gold_Hem',[(x*1.003,y*1.003,z+.012) for x,y,z in rows[0]],.011)

for s in (-1,1):
    lapel=[(s*.073,-.182,1.245),(s*.193,-.214,1.191),(s*.236,-.275,1.112),(s*.193,-.301,1.112),(s*.237,-.315,1.061),(s*.117,-.348,.858),(s*.136,-.286,1.07)]
    panel('Milo_Notched_Lapel',lapel,lapelmat)
    tube('Milo_Gold_Lapel_Border',[(x,y-.010,z) for x,y,z in lapel[:6]],.009)
    # Short heraldic filigree rather than photoreal embroidery.
    pts=[(s*.292,-.233,.52),(s*.307,-.218,.565),(s*.314,-.212,.612)]
    tube('Milo_Laurel_Stem',pts,.0055)
    for z in (.544,.577):
        x=s*(.299+(z-.544)*.30);y=-.232+(z-.544)*.3
        panel('Milo_Laurel_Leaf',[(x,y-.008,z),(x+s*.023,y+.006,z+.028),(x+s*.023,y+.006,z+.010)],gold,.004)
    # Welt pocket and paired gold waistcoat buttons, sized for game-scale readability.
    panel('Milo_Coat_Pocket',[(s*.207,-.285,.71),(s*.302,-.219,.70),(s*.300,-.221,.668),(s*.202,-.289,.682)],lapelmat)
    tube('Milo_Gold_Pocket_Welt',[(s*.207,-.295,.710),(s*.302,-.229,.700)],.007)
    for z,y in ((.94,-.306),(.84,-.321),(.74,-.314),(.64,-.304)):button('Milo_Waistcoat_Button',(s*.058,y,z),.014)

# Shirt and cravat form a bright classic focal point beneath the chubby face.
panel('Milo_Ivory_Shirt',[(-.095,-.157,1.25),(.095,-.157,1.25),(.100,-.257,1.075),(0,-.308,.981),(-.10,-.257,1.075)],ivory)
panel('Milo_Folded_Cravat',[(-.062,-.218,1.197),(.064,-.218,1.197),(.044,-.302,1.037),(0,-.319,1.007),(-.050,-.302,1.047)],ivory)
button('Milo_Cravat_Brooch',(0,-.249,1.15),.027)
tube('Milo_Waistcoat_Gold_Edge',[(0,-.286,.51),(0,-.302,.65),(0,-.324,.8),(0,-.310,.96)],.005)
# A small, legible draped gold chain communicates luxury at cast scale.
tube('Milo_Pocket_Chain',[(.064,-.326,.79),(.104,-.331,.755),(.163,-.314,.744),(.212,-.290,.767)],.006)

# Restyle the original skinned sleeves and legs without disturbing the cast rig.
for o in list(bpy.data.objects):
    if o.type!='MESH' or not o.name.startswith(('Milo_Arm','Milo_Leg')):continue
    ca=o.data.color_attributes.get('Color')
    for p in o.data.polygons:
        center=sum((o.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
        if 'Arm' in o.name:
            ax=abs(center.x);h='C99B63' if ax>.735 else '293E58'
        else:h='302D30' if center.z<.21 else '293E58'
        for i in p.loop_indices:ca.data[i].color=color(h)
for s,label in [(-1,'r'),(1,'l')]:
    # Closed, continuous cuffs; their borders are part of the fabric surface.
    cuffrows=[(.598,.152),(.613,.155),(.698,.151),(.717,.146)]
    cv=[(s*x,r*math.cos(j*math.tau/16),1.1067+r*math.sin(j*math.tau/16)) for x,r in cuffrows for j in range(16)]
    cf=[(k*16+j,k*16+(j+1)%16,(k+1)*16+(j+1)%16,(k+1)*16+j) for k in range(3) for j in range(16)]
    cf.extend((tuple(reversed(range(16))),tuple(48+j for j in range(16))))
    cuff=mesh('Milo_Tailored_Cuff',cv,cf,lapelmat,bone='lowerarm.'+label);cuff.data.materials.append(gold)
    for p in cuff.data.polygons:p.material_index=1 if p.index<16 or 32<=p.index<48 else 0
    for x in (.638,.674):button('Milo_Cuff_Button',(s*x,-.159,1.1067),.012,bone='lowerarm.'+label)

# Joining keeps the costume editable as one skin; source face/rig/actions stay intact.
bpy.ops.object.select_all(action='DESELECT')
for o in created:o.select_set(True)
bpy.context.view_layer.objects.active=vest;bpy.ops.object.join();vest.name='Milo_Luxury_Coat_and_Suit'
rig['wardrobe']='Medieval-classic navy coat, burgundy waistcoat, ivory cravat and antique gold trim'
rig['local_review_only']=True
idle=next(tr.strips[0] for tr in ad.nla_tracks if tr.name=='Idle');ad.action=idle.action;ad.action_slot=idle.action_slot;scene.frame_set(0)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'milo_luxury_coat.blend'))
ad.action=None;bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    if o.type in ('MESH','ARMATURE'):o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'milo_luxury_coat.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,export_skins=True,export_yup=True)
meshes=[o for o in bpy.data.objects if o.type=='MESH']
report={'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),'meshes':len(meshes),'bones':len(rig.data.bones),'actions':[tr.name for tr in ad.nla_tracks],'source_model_unchanged':str(OUT.parent/'milo_cast.blend')}
(OUT/'build_report.json').write_text(json.dumps(report,indent=2));print('WARDROBE_BUILD_DONE',report,flush=True)
