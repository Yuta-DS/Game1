"""The coat and body follow the reference image, without inherited rig distortion."""
def shell(name,profile,m,opening=0,sides=40):
    vs=[];rows=[];n=sides+1 if opening else sides
    for z,rx,ry in profile:
        row=[]
        for j in range(n):
            a=opening+(math.tau-2*opening)*j/(n-1) if opening else j*math.tau/n
            # Subtle tailored fullness between waist and skirt, not a smooth cylinder.
            x=rx*math.sin(a);y=-ry*math.cos(a)
            row.append((x,y,z))
        vs+=row;rows.append(row)
    fs=[(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(len(rows)-1) for j in range(n-1 if opening else n)]
    if not opening:fs.extend((tuple(reversed(range(n))),tuple((len(rows)-1)*n+j for j in range(n))))
    o=mesh(name,vs,fs,m)
    if opening:
        select(o);md=o.modifiers.new('Coat lining thickness','SOLIDIFY');md.thickness=.012;md.offset=-1;bpy.ops.object.modifier_apply(modifier=md.name)
        md=o.modifiers.new('Soft hem edges','BEVEL');md.width=.003;md.segments=2;bpy.ops.object.modifier_apply(modifier=md.name)
    return o,rows
body,coatrows=shell('Milo_Sculpt_Tailored_Coat',[(.25,.422,.226),(.33,.421,.235),(.48,.395,.255),(.62,.372,.256),(.77,.345,.224),(.90,.320,.186),(.972,.154,.117)],navy,.35)
for edge in (0,-1):tube('Milo_Coat_Gold_Edge',[(x,y-.004,z) for x,y,z in [r[edge] for r in coatrows]],.0042,edgegold,8)
tube('Milo_Gold_Hem',[(x*1.005,y*1.006,z+.01) for x,y,z in coatrows[0]],.0042,edgegold,8)
# Narrow waistcoat, only 30px wide in the supplied front image.
vest,_=shell('Milo_Narrow_Purple_Waistcoat',[(.395,.141,.220),(.46,.173,.244),(.59,.184,.264),(.76,.160,.228),(.91,.105,.137)],purple)
for v in vest.data.vertices:
    v.co.x*=.86
    if v.co.y>0:v.co.y*=.60
for s in (-1,1):
    panel('Milo_Vest_Point',[(s*.01,-.227,.406),(s*.132,-.225,.439),(s*.151,-.214,.405),(s*.101,-.231,.373)],purple,.012,.003)
    # Broad folded notched lapels, physically wider than the exposed waistcoat.
    lap=[(s*.065,-.131,.979),(s*.168,-.156,.945),(s*.253,-.185,.899),(s*.210,-.225,.876),(s*.228,-.236,.846),(s*.122,-.266,.724),(s*.139,-.212,.880)]
    panel('Milo_Notched_Lapel',lap,lapel,.023,.004)
    tube('Milo_Teal_Lapel_Piping',[(x,y-.006,z) for x,y,z in lap[:6]],.0035,teal,8)
    panel('Milo_Cream_Collar',[(s*.013,-.150,.968),(s*.083,-.140,.963),(s*.127,-.195,.904),(s*.051,-.225,.838)],shirt,.012,.003)
    panel('Milo_Coat_Welt',[(s*.240,-.200,.481),(s*.340,-.161,.475),(s*.342,-.163,.456),(s*.242,-.207,.461)],lapel,.008,.003)
    tube('Milo_Pocket_Gold_Welt',[(s*.241,-.206,.481),(s*.339,-.167,.475)],.0038,edgegold,8)
    button('Milo_Coat_Button',(s*.218,-.229,.658),.012)
panel('Milo_Violet_Tie',[(-.025,-.205,.91),(.025,-.205,.91),(.034,-.244,.848),(0,-.255,.815),(-.034,-.244,.848)],tie,.012,.003)
ell('Milo_Tie_Knot',(0,-.218,.919),(.023,.015,.023),tie,16,10)
button('Milo_Cravat_Pin',(0,-.262,.847),.011)
for z,y in ((.73,-.252),(.591,-.276),(.455,-.253)):button('Milo_Waistcoat_Button',(0,y,z),.010)
# Enamel insignia on image-right lapel, small enough not to dominate the face.
gem=mat('40 teal lapel enamel','3C9D9C',.35,.1);leaf=mat('41 olive leaf enamel','839755',.62);star=mat('42 violet enamel','8E7199',.4,.05)
for x,y,z,r,m in ((.173,-.228,.882,.013,gem),(.192,-.218,.910,.011,leaf),(.161,-.247,.849,.010,star)):
    panel('Milo_Lapel_Pin',[(x-r,y,z),(x,y-.005,z+r*1.3),(x+r,y,z),(x,y-.005,z-r*1.3)],m,.005,.001)
# Back waist tab and real seams.
panel('Milo_Back_Waist_Tab',[(-.175,.261,.55),(.175,.261,.55),(.175,.262,.498),(-.175,.262,.498)],lapel,-.019,.004)
tube('Milo_Back_Tab_Trim',[(-.173,.268,.545),(.173,.268,.545),(.173,.269,.503),(-.173,.269,.503)],.003,edgegold,8,closed=True)
for s in (-1,1):button('Milo_Back_Tab_Button',(s*.141,.274,.524),.017)
tube('Milo_Center_Back_Seam',[(0,.122,.964),(0,.188,.89),(0,.23,.754),(0,.26,.61),(0,.258,.50),(0,.232,.27)],.0017,lapel,6)
# Straight, relaxed sleeves with broad cuffs. No rig offsets or spherical shoulders.
for s in (-1,1):
    pts=path([(s*.233,0,.854),(s*.286,0,.850),(s*.359,-.006,.782),(s*.435,-.010,.667),(s*.494,-.018,.556)],7)
    radii=[(.040+.084*math.sin(math.pi*.5*min(1,i/7))) if i<7 else .124-.019*(i-7)/(len(pts)-8) for i in range(len(pts))]
    tube('Milo_Sleeve_'+str(s),pts,radii,navy,20,depth=.94)
    axis=Vector((s*.059,-.008,-.111)).normalized();a=axis.cross(Vector((0,1,0))).normalized();b=axis.cross(a).normalized()
    # The wide cuff is cloth with two fine gold boundaries, not detached torus rings.
    end=Vector((s*.494,-.018,.556));cuffpts=[end-axis*.08,end-axis*.065,end-axis*.012,end+axis*.002]
    tube('Milo_Broad_Cuff_'+str(s),cuffpts,[.110,.114,.113,.105],lapel,24,depth=.94)
    for t,r in ((-.066,.114),(-.011,.113)):
        c=end+axis*t;pts=[c+r*(math.cos(j*math.tau/40)*a+.94*math.sin(j*math.tau/40)*b) for j in range(40)]
        tube('Milo_Cuff_Gold_Braid',pts,.0042,edgegold,8,closed=True)
    tube('Milo_Linen_Cuff',[end-axis*.012,end+axis*.018],[.083,.080],shirt,24,depth=.94)
    # Mittens with low finger knuckles and a small naturally opposing thumb.
    c=Vector((s*.527,-.023,.447));p=[ell('paw palm',c,(.073,.068,.079)),ell('paw wrist',c+Vector((-s*.015,.008,.055)),(.057,.050,.063))]
    for dx,dz in ((-.041,.004),(0,0),(.041,.010)):
        p.append(ell('paw fingertip',c+Vector((dx,-.009,-.055+dz)),(.027,.050,.036),seg=20,rings=12))
    p.append(ell('paw thumb',c+Vector((-s*.063,-.026,.015)),(.032,.041,.045),seg=20,rings=12))
    paw=sculpt_union(p,'Milo_Sculpt_Paw_'+str(s),rimfur,.005,.18,4)
    for dx in (-.023,.024):
        tube('Milo_Paw_Short_Groove',path([c+Vector((dx,-.069,-.041)),c+Vector((dx,-.072,-.060)),c+Vector((dx,-.062,-.078))],4),.0013,mouthmat,6)
    # Short trouser legs and flat, wide shoes, measured from the reference.
    xc=s*.225
    tube('Milo_Trouser_Leg',[(xc,.028,.445),(xc,.017,.28),(xc,.005,.13)],[.142,.133,.112],pants,20,depth=.9)
    vs=[];n=32;rows=[(.012,.135,.166,-.042),(.035,.139,.175,-.042),(.070,.137,.173,-.045),(.112,.127,.153,-.021),(.162,.097,.102,.018)]
    for z,rx,ry,yc in rows:
        for j in range(n):
            a=j*math.tau/n;xx=math.copysign(abs(math.sin(a))**.78,math.sin(a));yy=math.copysign(abs(math.cos(a))**.78,math.cos(a));vs.append((xc+rx*xx,yc-ry*yy,z))
    fs=[(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(len(rows)-1) for j in range(n)];fs.extend((tuple(reversed(range(n))),tuple((len(rows)-1)*n+j for j in range(n))))
    boot=mesh('Milo_Sculpt_Boot_'+str(s),vs,fs,leather);boot.data.materials.append(sole)
    for p in boot.data.polygons:
        if p.index<n:p.material_index=1
    tube('Milo_Boot_Upper_Seam',path([(xc-.11,-.10,.105),(xc-.07,-.185,.097),(xc+.07,-.185,.097),(xc+.11,-.10,.105)],5),.0016,sole,6)
# Curved banded tail with a broad pale end.
pts=path([(0,.21,.39),(.03,.32,.32),(.12,.46,.23),(.24,.58,.17),(.33,.67,.20),(.35,.69,.31)],6)
radii=[.061+.018*math.sin(i*math.pi/(len(pts)-1)) for i in range(len(pts))]
for i in range(len(pts)-5,len(pts)):radii[i]*=(len(pts)-i)/5
tail= tube('Milo_Sculpt_Tail',pts,radii,fur,16,smooth=False);tail.data.materials.append(ivory);tail.data.materials.append(mat('43 tail taupe band','9E8E76'))
for p in tail.data.polygons:
    t=p.index/(16*(len(pts)-1));p.material_index=1 if t>.78 else (2 if .18<t<.29 or .47<t<.56 else 0)
