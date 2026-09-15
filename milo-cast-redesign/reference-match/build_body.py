"""Reference wardrobe, compact limbs and a curved banded tail."""
body_start=len(created)
def profile_mesh(name,profile,mat,bone=torso_weights,sides=24,open_front=False):
    verts=[];rows=[]
    for row in profile:
        z,rx,ry=row[:3];opening=row[3] if open_front else 0;count=sides+1 if open_front else sides
        pts=[]
        for j in range(count):
            a=opening+(math.tau-2*opening)*j/(count-1) if open_front else j*math.tau/count
            zz=z+(.026*max(0,1-abs(a-math.pi)/.21) if open_front and z<.4 else 0)
            pts.append((rx*math.sin(a),-ry*math.cos(a),zz))
        rows.append(pts);verts.extend(pts)
    n=len(rows[0]);faces=[(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(len(rows)-1) for j in range(n-1 if open_front else n)]
    if not open_front:faces.extend((tuple(reversed(range(n))),tuple((len(rows)-1)*n+j for j in range(n))))
    obj=mesh(name,verts,faces,mat,bone)
    if open_front:
        select(obj);m=obj.modifiers.new('Tailored cloth thickness','SOLIDIFY');m.thickness=.012;m.offset=-1;bpy.ops.object.modifier_apply(modifier=m.name)
    return obj,rows
vest,_=profile_mesh('Milo single-breasted waistcoat',[(.50,.24,.215),(.65,.30,.271),(.83,.305,.29),(1.01,.28,.25),(1.16,.15,.14)],purple)
coat,coatrows=profile_mesh('Milo reference long coat',[(.32,.393,.295,.62),(.50,.378,.295,.52),(.70,.343,.306,.44),(.90,.333,.303,.53),(1.075,.295,.242,.50),(1.175,.166,.154,.40)],navy,open_front=True)
for idx in (0,-1):sweep('Milo fine coat edge',[(x,y-.005,z) for x,y,z in [row[idx] for row in coatrows]],.0055,goldlight,torso_weights,sides=6)
sweep('Milo coat hem piping',[(x*1.003,y*1.003,z+.009) for x,y,z in coatrows[0]],.0055,goldlight,torso_weights,sides=6)
for s in (-1,1):
    lap=[(s*.075,-.161,1.185),(s*.222,-.203,1.135),(s*.260,-.245,1.075),(s*.211,-.270,1.074),(s*.235,-.287,1.024),(s*.104,-.304,.837),(s*.131,-.250,1.066)]
    panel('Milo notched teal-edged lapel',lap,lapel)
    sweep('Milo muted teal lapel edge',[(x,y-.007,z) for x,y,z in lap[:6]],.005,teal,torso_weights,sides=6)
    panel('Milo ivory shirt collar',[(s*.017,-.177,1.166),(s*.098,-.168,1.174),(s*.135,-.228,1.106),(s*.068,-.250,1.046)],shirt)
    # Small welt pockets, kept subordinate to the face.
    panel('Milo small coat pocket',[(s*.213,-.251,.585),(s*.302,-.203,.576),(s*.301,-.206,.548),(s*.208,-.258,.557)],lapel)
    sweep('Milo pocket fine welt',[(s*.213,-.258,.585),(s*.302,-.210,.576)],.0045,goldlight,torso_weights,sides=6)
    button('Milo outer coat button',(s*.173,-.281,.768),.015)
for z,y in ((.947,-.275),(.806,-.303),(.668,-.282)):button('Milo vest gold button',(.004,y,z),.014)
panel('Milo waistcoat lower notch',[(-.117,-.260,.55),(0,-.281,.51),(.117,-.260,.55),(.09,-.268,.489),(0,-.279,.519),(-.095,-.269,.482)],purple)
panel('Milo purple tie',[(-.030,-.237,1.107),(.030,-.237,1.107),(.044,-.287,1.014),(0,-.307,.958),(-.044,-.287,1.014)],purple)
ellipsoid('Milo tie knot',(0,-.243,1.115),(.034,.018,.032),purple,torso_weights,12,8)
button('Milo tie small gold jewel',(0,-.313,.99),.018)
# Reference's small teal/leaf/star lapel accents.
for x,z,size in ((.151,1.076,.018),(.183,1.097,.012),(.164,1.038,.013)):
    y=-.274+(z-1.04)*.7
    panel('Milo teal lapel emblem',[(x-size,y,z),(x,y-.004,z+size*1.25),(x+size,y,z),(x,y-.004,z-size*1.25)],teal,depth=.006,bevel=.001)
panel('Milo leaf lapel pin',[(.192,-.241,1.078),(.205,-.233,1.103),(.221,-.226,1.107),(.213,-.235,1.083)],material('Milo leaf enamel','8A9E62'),depth=.006,bevel=.001)
# Back waist tab follows the rounded coat surface; two restrained gold buttons.
panel('Milo back waist tab',[(-.17,.322,.648),(.17,.322,.648),(.17,.324,.600),(-.17,.324,.600)],lapel,depth=-.020)
sweep('Milo back tab border',[(-.17,.329,.647),(.17,.329,.647),(.17,.329,.600),(-.17,.329,.600)],.0035,goldlight,torso_weights,sides=6,closed=True)
for s in (-1,1):button('Milo back tab button',(s*.137,.336,.623),.017)
sweep('Milo back center seam',[(0,.15,1.164),(0,.232,1.073),(0,.287,.90),(0,.298,.70),(0,.298,.37)],.002,lapel,torso_weights,sides=6)
body=join_objects(created[body_start:],'Milo_Reference_Coat_and_Suit')
# Continuous sleeves; no separate spherical shoulder or oversized cuff shell.
for s,label in ((1,'l'),(-1,'r')):
    start=len(created);u=rig.pose.bones['upperarm.'+label];l=rig.pose.bones['lowerarm.'+label];w=rig.pose.bones['wrist.'+label];h=rig.pose.bones['hand.'+label]
    def arm_weights(p,label=label):
        t=max(0,min(1,(1.03-p.z)/.16));return {'upperarm.'+label:1-t,'lowerarm.'+label:t}
    pts=curve([u.head,u.tail,l.tail],5);radii=[.146-.033*i/(len(pts)-1) for i in range(len(pts))]
    sweep('Milo fitted coat sleeve',pts,radii,navy,arm_weights,sides=14,flat=.92)
    axis=(l.tail-l.head).normalized();a=axis.cross(Vector((0,1,0))).normalized();b=axis.cross(a).normalized()
    for d in (-.024,-.112):
        center=l.tail+axis*d;ring=[center+.116*(math.cos(j*math.tau/24)*a+.92*math.sin(j*math.tau/24)*b) for j in range(24)]
        sweep('Milo sleeve gold stripe',ring,.0055,goldlight,'lowerarm.'+label,sides=6,closed=True)
    sweep('Milo ivory shirt cuff',[w.head,w.head+(w.tail-w.head)*.45],[.071,.065],shirt,'wrist.'+label,sides=14)
    join_objects(created[start:],'Milo_Reference_Sleeve_'+label)
    # Soft compact mitten with a small thumb and shallow short finger lobes.
    c=h.head+Vector((0,-.012,-.043));pieces=[ellipsoid('Paw palm',c,(.077,.055,.070),segments=16,rings=10)]
    pieces.append(ellipsoid('Paw wrist',h.head+Vector((0,-.012,.012)),(.045,.043,.048),segments=16,rings=10))
    for dx,drop in ((-.041,.078),(0,.081),(.041,.077)):
        pieces.append(ellipsoid('Short paw digit',c+Vector((dx,-.006,-drop+.025)),(.025,.040,.026),segments=12,rings=8))
    thumb=curve([c+Vector((-s*.057,-.010,.028)),c+Vector((-s*.079,-.031,.001)),c+Vector((-s*.065,-.052,-.027))],4)
    pieces.append(sweep('Paw thumb',thumb,[.022,.022,.021,.020,.019,.017,.014,.010,.006],sides=10))
    paw=union_paw(pieces,'Milo_Reference_Paw_'+label,'hand.'+label)
    # Two subtle fingertip grooves, not long separate human fingers.
    for dx in (-.024,.024):
        sweep('Milo shallow paw crease',curve([c+Vector((dx,-.061,-.060)),c+Vector((dx,-.065,-.035)),c+Vector((dx,-.062,-.018))],3),.0018,groove,'hand.'+label,sides=6)
    # Dark trousers and shaped boots use the existing leg and foot bones.
    uleg=rig.pose.bones['upperleg.'+label];lleg=rig.pose.bones['lowerleg.'+label];f=rig.pose.bones['foot.'+label]
    def leg_weights(p,label=label):
        t=max(0,min(1,(.33-p.z)/.09));return {'upperleg.'+label:1-t,'lowerleg.'+label:t}
    sweep('Milo short trouser leg',[uleg.head+Vector((0,0,.03)),uleg.tail,lleg.tail+Vector((0,0,.025))],[.138,.123,.116],trouser,leg_weights,sides=14)
    xc=f.head.x;yc=f.head.y-.062;rows=[(.014,.144,.179,-.005),(.040,.151,.188,-.005),(.075,.149,.187,0),(.128,.126,.157,.024),(.19,.103,.112,.058)]
    verts=[];n=20
    for z,rx,ry,offset in rows:
        for j in range(n):
            a=j*math.tau/n;xx=math.copysign(abs(math.sin(a))**.75,math.sin(a));yy=math.copysign(abs(math.cos(a))**.75,math.cos(a));verts.append((xc+rx*xx,yc+offset-ry*yy,z))
    faces=[(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(len(rows)-1) for j in range(n)];faces.extend((tuple(reversed(range(n))),tuple((len(rows)-1)*n+j for j in range(n))))
    boot=mesh('Milo_Reference_Boot_'+label,verts,faces,leather,'foot.'+label);boot.data.materials.append(sole)
    for p in boot.data.polygons:
        if p.index<n:p.material_index=1
    sweep('Milo boot toe seam',curve([(xc-.112,yc-.114,.111),(xc-.066,yc-.172,.102),(xc+.060,yc-.174,.103),(xc+.113,yc-.112,.112)],4),.0025,sole,'foot.'+label,sides=6)
# Low thick tail: a continuous curved shape with taupe bands and a pale end.
pts=curve([(0,.245,.49),(.043,.414,.397),(.22,.547,.285),(.43,.548,.205),(.59,.476,.225),(.625,.414,.295)],5)
radii=[.065+.018*math.sin(math.pi*i/(len(pts)-1)) for i in range(len(pts))]
for i in range(len(pts)-4,len(pts)):radii[i]*=(len(pts)-i)/4
tail=sweep('Milo_Reference_Curved_Tail',pts,radii,fur,'hips',sides=12);tail.data.materials.append(ivory);tail.data.materials.append(furshade)
for p in tail.data.polygons:
    t=min(1,p.index/(12*(len(pts)-1)));p.material_index=1 if t>.76 else (2 if .18<t<.27 or .43<t<.52 else 0)
