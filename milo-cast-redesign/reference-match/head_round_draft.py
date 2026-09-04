"""Archived spherical-head construction: failed the supplied-image likeness review."""
before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(OUT/'head_seed.glb'));new=set(bpy.data.objects)-before;head=next(o for o in new if o.type=='MESH' and len(o.data.polygons)>100)
world=head.matrix_world.copy();head.parent=None;head.matrix_world=world
for m in list(head.modifiers):head.modifiers.remove(m)
select(head);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for o in new:
    if o!=head:bpy.data.objects.remove(o,do_unlink=True)
# Round the sampled crown into a broad cranium, removing the conical cap.
zmin=min(v.co.z for v in head.data.vertices);zmax=max(v.co.z for v in head.data.vertices)
for v in head.data.vertices:
    x,y,z=v.co;t=(z-zmin)/(zmax-zmin);a=math.atan2(y/.355,x/.475);rr=math.sqrt(max(0,1-(2*t-1)**2));zz=1.20+t*.78
    v.co=(.478*rr*math.cos(a),.351*rr*math.sin(a),zz)
    if y<0:v.co.y-=.030*math.exp(-(v.co.x/.25)**4-((zz-1.40)/.12)**2)
headmat=material('Milo reference fur colours','FFFFFF');node=headmat.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='ReferenceColor';headmat.node_tree.links.new(node.outputs['Color'],headmat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
skin(head,headmat,smooth=True);head.name='Milo_Reference_Head'
for a in list(head.data.color_attributes):head.data.color_attributes.remove(a)
attr=head.data.color_attributes.new(name='ReferenceColor',type='BYTE_COLOR',domain='CORNER');head.data.color_attributes.active_color_index=0;head.data.color_attributes.render_color_index=0
base=rgba('B3A68F');light=rgba('DDD3BA');dark=rgba('8F826F')
for p in head.data.polygons:
    variation=.965+.055*((p.index*17)%11)/10
    for i in p.loop_indices:
        x,y,z=head.data.vertices[head.data.loops[i].vertex_index].co;front=max(0,min(1,(-y-.05)/.2))
        blaze=max(0,min(1,(.18-abs(x))/ .10))*max(0,min(1,(z-1.58)/.25))*front
        cheeks=max(0,min(1,(1.56-z)/.2))*front
        t=max(blaze,cheeks*.6);c=[base[k]*(1-t)+light[k]*t for k in range(3)]
        stripe=front*max(0,1-abs(abs(x)-(.08+(z-1.72)*.70))/.063)*max(0,min(1,(z-1.73)/.09))*.88
        back=max(0,min(1,(y-.03)/.18));rear=.40+.22*max(0,1-abs(abs(x)-.19)/.09);stripe=max(stripe,back*rear)
        attr.data[i].color=tuple((c[k]*(1-stripe)+dark[k]*stripe)*variation for k in range(3))+(1,)
def face_y(x,z):
    hit,co,n,idx=head.ray_cast(Vector((x,-2,z)),Vector((0,1,0)));return co.y if hit else -.29
start=len(created)
# Upright triangular ears, rooted inside the head, with full rims and inset bowls.
for s in (-1,1):
    outline=[(s*.229,-.048,1.855),(s*.322,-.02,2.003),(s*.454,.008,2.130),(s*.482,.018,2.129),(s*.481,.001,2.074),(s*.450,-.03,1.817),(s*.35,-.057,1.79)]
    tuft('Milo full ear',outline,(s*.372,-.065,1.925),fur,.045)
    inside=[(s*.295,-.067,1.875),(s*.353,-.049,1.993),(s*.45,-.022,2.089),(s*.43,-.054,1.87),(s*.36,-.068,1.84)]
    tuft('Milo inner ear',inside,(s*.38,-.072,1.935),inner,.010)
# A connected cream muzzle under the moustache; no visible gap at the root.
ellipsoid('Milo white muzzle',(0,-.285,1.385),(.207,.121,.099),ivory,segments=20,rings=10)
ellipsoid('Milo chin',(0,-.230,1.278),(.112,.095,.052),ivory,segments=20,rings=10)
for s in (-1,1):
    # Three broad layered cheek tufts rather than spikes or detached balls.
    for k,(z,tipx) in enumerate(((1.485,.506),(1.420,.522),(1.362,.476))):
        outline=[(s*.275,-.215,z+.045),(s*.404,-.178,z+.048),(s*tipx,-.087,z+.028),(s*(tipx-.065),-.142,z-.028),(s*.302,-.237,z-.040)]
        tuft('Milo layered cheek fur',outline,(s*.386,-.229,z+.001),ivory,.025)
    ex=s*.207;ez=1.631;ey=face_y(ex,ez)
    ellipsoid('Milo cream eye socket',(ex,ey-.007,ez),(.112,.032,.116),eye_white,segments=24,rings=12)
    ellipsoid('Milo amber iris',(ex,ey-.033,ez),(.096,.023,.100),amber,segments=24,rings=12)
    ellipsoid('Milo warm pupil',(ex,ey-.052,ez+.004),(.063,.012,.078),eye_dark,segments=24,rings=12)
    ellipsoid('Milo eye highlight',(ex-.024,ey-.066,ez+.040),(.011,.004,.018),shine,segments=16,rings=8)
    ellipsoid('Milo eye soft glint',(ex+.023,ey-.065,ez-.037),(.005,.003,.007),shine,segments=12,rings=6)
    pts=[(ex+.131*math.cos(j*math.tau/40),ey-.071,ez+.131*math.sin(j*math.tau/40)) for j in range(40)]
    sweep('Milo round gold glasses',pts,.012,gold,sides=8,closed=True)
    sweep('Milo glasses side arm',curve([(s*.338,ey-.070,1.65),(s*.433,-.205,1.675),(s*.417,-.020,1.708),(s*.370,.100,1.723)],5),.007,gold,sides=8)
    # Reference's two low ivory brows; roots meet the skull surface.
    pts=curve([(s*.096,face_y(s*.096,1.817)-.012,1.817),(s*.163,face_y(s*.163,1.846)-.010,1.846),(s*.233,face_y(s*.233,1.823)-.009,1.823),(s*.274,face_y(s*.274,1.797)-.006,1.797)],5)
    sweep('Milo sculpted ivory brow',pts,[.007+.027*math.sin(math.pi*i/(len(pts)-1))**.55 for i in range(len(pts))],ivory,flat=.72)
    # Swept fan-shaped moustache; broad connected root and an upturned outer tip.
    pts=curve([(s*.021,-.399,1.423),(s*.091,-.416,1.395),(s*.170,-.392,1.373),(s*.249,-.336,1.394),(s*.302,-.268,1.434)],5)
    radii=[.013+.041*math.sin(math.pi*i/(len(pts)-1))**.6 for i in range(len(pts))];radii[-1]=.004
    sweep('Milo swept white moustache',pts,radii,ivory,sides=12,flat=.70)
    for k in range(2):
        pts=curve([(s*.053,-.433,1.412-k*.014),(s*.137,-.438,1.389-k*.012),(s*.219,-.385,1.388-k*.005),(s*.285,-.300,1.419)],5)
        sweep('Milo moustache strand',pts,.0016,groove,sides=6)
sweep('Milo gold nose bridge',curve([(-.070,-.405,1.65),(0,-.439,1.673),(.070,-.405,1.65)],6),.010,gold,sides=8)
nosez=1.449;outline=curve([(-.049,-.431,nosez+.017),(.049,-.431,nosez+.017),(.033,-.441,nosez-.015),(0,-.445,nosez-.039),(-.033,-.441,nosez-.015)],4,True);tuft('Milo peach nose',outline,(0,-.477,nosez+.001),nosemat,.042)
sweep('Milo small smile',curve([(-.041,-.374,1.278),(0,-.389,1.266),(.041,-.374,1.278)],5),.004,groove,sides=6)
# Merge muzzle/cheek roots so the white fur reads as one sculpted structure.
white=[o for o in created[start:] if o.name.startswith(('Milo white muzzle','Milo chin','Milo layered cheek fur','Milo swept white moustache'))]
other=[o for o in created[start:] if o not in white]
mask=join_objects(white,'Milo connected muzzle fur')
for mod in list(mask.modifiers):mask.modifiers.remove(mod)
m=mask.modifiers.new('Joined muzzle and cheek roots','REMESH');m.mode='VOXEL';m.voxel_size=.007;m.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=m.name)
m=mask.modifiers.new('Fur root smoothing','SMOOTH');m.factor=.45;m.iterations=2;bpy.ops.object.modifier_apply(modifier=m.name)
m=mask.modifiers.new('Fur topology reduction','DECIMATE');m.ratio=.32;bpy.ops.object.modifier_apply(modifier=m.name);mask.data.validate(clean_customdata=True)
mask.vertex_groups.clear();g=mask.vertex_groups.new(name='head');g.add(list(range(len(mask.data.vertices))),1,'REPLACE');mask.data.materials.clear();mask.data.materials.append(ivory)
m=mask.modifiers.new('Reference skin','ARMATURE');m.object=rig
for p in mask.data.polygons:p.use_smooth=True
head_details=join_objects(other+[mask],'Milo_Reference_Face_Details')
