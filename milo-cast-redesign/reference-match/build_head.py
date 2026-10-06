"""Restarted planar cat-head construction, measured against the supplied turnaround."""
before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(OUT/'head_seed.glb'));new=set(bpy.data.objects)-before
head=next(o for o in new if o.type=='MESH' and len(o.data.polygons)>100)
world=head.matrix_world.copy();head.parent=None;head.matrix_world=world
for m in list(head.modifiers):head.modifiers.remove(m)
select(head);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for o in new:
    if o!=head:bpy.data.objects.remove(o,do_unlink=True)
# The AnyCreature seed is retopologized into a compact, explicitly planar cat cage.
# Broad cheek/jaw rows replace the former analytic sphere and conical crown cap.
# Restart the failing lower-face part as a broad, shallow jaw cage. A later
# head-space transform restores collar contact without keeping the long chin.
rows=[(1.325,.22,.16),(1.365,.29,.22),(1.415,.372,.268),(1.470,.448,.31),
      (1.565,.462,.321),(1.680,.443,.308),(1.790,.394,.273),
      (1.880,.302,.220),(1.940,.170,.142),(1.972,.035,.036)]
verts=[];n=16
for k,(z,rx,ry) in enumerate(rows):
    for j in range(n):
        a=math.tau*(j+.22*(k%2))/n;x=rx*math.cos(a);y=ry*math.sin(a)
        if abs(x)>rx*.85:x=math.copysign(rx*.85+(abs(x)-rx*.85)*.72,x)
        if y<0:y=max(y,-ry*.96)
        zz=z+(.009*math.sin(j*2.31+k*1.73) if 0<k<len(rows)-1 else 0)
        verts.append((x,y,zz))
faces=[]
for k in range(len(rows)-1):
    for j in range(n):
        a,b,c,d=k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j
        faces.extend(((a,b,d),(b,c,d)) if (j+k)%2 else ((a,b,c),(a,c,d)))
faces.extend((tuple(reversed(range(n))),tuple((len(rows)-1)*n+j for j in range(n))))
data=bpy.data.meshes.new('Milo planar reference skull');data.from_pydata(verts,[],faces);data.update();old=head.data;head.data=data
if old.users==0:bpy.data.meshes.remove(old)
head_world=[v.co.copy() for v in head.data.vertices]
skin(head,fur,smooth=False);head.name='Milo_Reference_Head'
palette=[fur,material('Milo tabby sand','B7A991'),material('Milo tabby shadow','AC9E88'),
         material('Milo tabby dark planes','9E8D74'),material('Milo central cream blaze','D8CDB5'),
         material('Milo warm light cheek','D1C3A8'),material('Milo crown medium','C2B399'),ivory]
head.data.materials.clear()
for mat in palette:head.data.materials.append(mat)
for p in head.data.polygons:
    c=sum((head_world[i] for i in p.vertices),Vector())/len(p.vertices);x,y,z=c
    idx=0
    if y>.035:idx=1 if z<1.72 else 0
    if y>.07 and z>1.78 and abs(abs(x)-.17)<.05:idx=2
    if y<-.06 and z>1.74:idx=4 if abs(x)<.12 else (3 if abs(abs(x)-(.10+(z-1.74)*.65))<.077 else 1)
    if y<-.1 and z<1.48:idx=5
    if y<-.06 and z<1.48:idx=7
    if abs(x)>.32 and 1.60<z<1.72:idx=2
    p.material_index=idx
def face_y(x,z):
    for k in range(len(rows)-1):
        if rows[k][0]<=z<=rows[k+1][0]:
            t=(z-rows[k][0])/(rows[k+1][0]-rows[k][0]);rx=rows[k][1]*(1-t)+rows[k+1][1]*t;ry=rows[k][2]*(1-t)+rows[k+1][2]*t
            return -ry*math.sqrt(max(.12,1-(x/rx)**2))
    return -.24
start=len(created)
for s in (-1,1):
    # Broad rooted ears with substantial back surfaces, not thin triangular cards.
    outline=[(s*.233,-.055,1.817),(s*.275,-.019,1.945),(s*.401,.008,2.038),
             (s*.433,.013,2.034),(s*.455,-.002,1.902),(s*.417,-.049,1.787)]
    tuft('Milo full ear',outline,(s*.350,-.074,1.912),fur,.115)
    inside=[(s*.276,-.071,1.850),(s*.317,-.043,1.932),(s*.405,-.016,2.004),
            (s*.424,-.040,1.898),(s*.389,-.068,1.838)]
    tuft('Milo inner ear',inside,(s*.354,-.078,1.915),inner,.017)
    for k,(z,tip) in enumerate(((1.484,.495),(1.437,.511),(1.395,.463))):
        outline=[(s*.263,-.191,z+.034),(s*.416,-.138,z+.025),(s*tip,-.075,z+.013-k*.009),
                 (s*(tip-.085),-.128,z-.030),(s*.265,-.207,z-.036)]
        tuft('Milo layered cheek fur',outline,(s*.372,-.198,z),ivory,.022)
    ex=s*.207;ez=1.649;ey=face_y(ex,ez)
    ellipsoid('Milo cream eye socket',(ex,ey-.013,ez),(.115,.030,.114),eye_white,segments=24,rings=12)
    ellipsoid('Milo amber iris',(ex,ey-.038,ez),(.100,.023,.102),amber,segments=24,rings=12)
    ellipsoid('Milo warm pupil',(ex,ey-.058,ez+.003),(.055,.013,.071),eye_dark,segments=24,rings=12)
    ellipsoid('Milo eye highlight',(ex-.022,ey-.073,ez+.034),(.010,.004,.015),shine,segments=12,rings=8)
    ellipsoid('Milo eye soft glint',(ex+.023,ey-.072,ez-.034),(.004,.003,.006),shine,segments=12,rings=6)
    pts=[(ex+.135*math.cos(j*math.tau/40),ey-.079,ez+.135*math.sin(j*math.tau/40)) for j in range(40)]
    sweep('Milo round gold glasses',pts,.011,gold,sides=8,closed=True)
    sweep('Milo glasses side arm',curve([(s*.342,ey-.079,ez+.008),(s*.431,-.191,1.686),(s*.407,-.030,1.712),(s*.372,.10,1.727)],5),.006,gold,sides=8)
    pts=curve([(s*.095,face_y(s*.095,1.811)-.009,1.811),(s*.162,face_y(s*.162,1.838)-.008,1.838),(s*.237,face_y(s*.237,1.818)-.008,1.818),(s*.276,face_y(s*.276,1.79)-.003,1.790)],5)
    sweep('Milo sculpted ivory brow',pts,[.006+.025*math.sin(math.pi*i/(len(pts)-1))**.6 for i in range(len(pts))],ivory,flat=.75)
# Nose offset: approximately one third of a lens diameter below eye centers.
ellipsoid('Milo white muzzle',(0,-.291,1.493),(.145,.076,.057),ivory,segments=24,rings=12)
for s in (-1,1):
    # Small, flattened fur lobes flow directly from the raised nose into the cheeks.
    pts=curve([(s*.018,-.372,1.525),(s*.088,-.385,1.491),(s*.168,-.349,1.473),(s*.255,-.278,1.478),(s*.305,-.219,1.515)],5)
    radii=[.014+.032*math.sin(math.pi*i/(len(pts)-1))**.65 for i in range(len(pts))];radii[-1]=.002
    sweep('Milo swept white moustache',pts,radii,ivory,sides=12,flat=.62)
sweep('Milo gold nose bridge',curve([(-.072,-.363,1.666),(0,-.387,1.677),(.072,-.363,1.666)],5),.009,gold,sides=8)
nosez=1.563;outline=curve([(-.043,-.392,nosez+.012),(.043,-.392,nosez+.012),(.033,-.404,nosez-.012),(0,-.414,nosez-.032),(-.033,-.404,nosez-.012)],3,True)
tuft('Milo peach nose',outline,(0,-.433,nosez),nosemat,.041)
sweep('Milo small smile',curve([(-.035,face_y(-.035,1.416)-.007,1.416),(0,face_y(0,1.405)-.009,1.405),(.035,face_y(.035,1.416)-.007,1.416)],4),.0023,groove,sides=6)
# Work in Idle-space, preserving the round glasses when restoring head height.
# Full assembly moves together; a broad cheek base replaces the pointed chin.
deform=rig.pose.bones['head'].matrix@rig.pose.bones['head'].bone.matrix_local.inverted()
for obj in [head]+created[start:]:
    circular=obj.name.startswith(('Milo cream eye','Milo amber iris','Milo warm pupil','Milo eye highlight','Milo eye soft glint','Milo round gold glasses'))
    center=sum(((deform@v.co).z for v in obj.data.vertices))/len(obj.data.vertices)
    for vertex in obj.data.vertices:
        p=deform@vertex.co;p.z=(1.20+(center-1.325)*1.14+p.z-center) if circular else 1.20+(p.z-1.325)*1.14;vertex.co=deform.inverted()@p
head_details=join_objects(created[start:],'Milo_Reference_Face_Details')
