"""Medieval-inspired court coat and doublet; actual tailored, skinned geometry.

Replaces the modern lapels/tie/waistcoat, preserving Milo's head, legs and tail.
The look is fantasy court clothing, not a claim of historical reconstruction.
"""
replace_prefixes=('Milo_Sculpt_Tailored_Coat','Milo_Coat_','Milo_Gold_Hem',
 'Milo_Narrow_Purple','Milo_Vest_','Milo_Notched_','Milo_Teal_Lapel',
 'Milo_Cream_Collar','Milo_Cravat','Milo_Gold_Tie','Milo_Waistcoat_',
 'Milo_Standing_Collar','Milo_Collar_Teal','Milo_Back_','Milo_Center_Back_','Milo_Pocket_',
 'Milo_Sleeve_','Milo_Broad_Cuff_','Milo_Cuff_','Milo_Linen_Cuff','Pin_')
for obj in list(bpy.data.objects):
    if obj.type=='MESH' and obj.name.startswith(replace_prefixes):
        bpy.data.objects.remove(obj,do_unlink=True)
court=mat('50 deep peacock court wool','253B45',.84)
velvet=mat('51 burgundy velvet doublet','6B3648',.88)
facing=mat('52 dark teal collar facing','324F55',.8)
braid=mat('53 antique gold woven borders','C0A165',.62,.24)
stitch=mat('54 wine doublet stitched seams','8D5860',.9)
strap=mat('55 chestnut belt leather','4E342B',.7)

# Fitted waist, flared divided skirts, open front: no modern notched lapels.
coat_profile=[(.265,.403,.229),(.31,.405,.235),(.40,.391,.247),
 (.50,.364,.251),(.60,.339,.248),(.69,.322,.234),(.78,.328,.213),
 (.86,.319,.190),(.915,.277,.162),(.97,.172,.127)]
coat,coatrows=shell('Milo_Medieval_Surcoat',coat_profile,court,.32,56)
for vertex in coat.data.vertices:
    if vertex.co.z<.34:
        angle=math.atan2(vertex.co.x/.403,-vertex.co.y/.229)
        # Longer fronts and back; raised side vents keep the feet readable.
        vertex.co.z+=.022*math.sin(angle)**2*(.34-vertex.co.z)/.075
def interpolate_profile(profile,z):
    if z<=profile[0][0]:return profile[0][1:]
    for (a,ax,ay),(b,bx,by) in zip(profile,profile[1:]):
        if a<=z<=b:
            t=(z-a)/(b-a);return ax+(bx-ax)*t,ay+(by-ay)*t
    return profile[-1][1:]
def coat_point(angle,z,lift=.005):
    rx,ry=interpolate_profile(coat_profile,z)
    return ((rx+lift)*math.sin(angle),-(ry+lift)*math.cos(angle),z)
for side in (-1,1):
    tube('Milo_Medieval_Front_Gold_Border',[coat_point(side*.32,z) for z,rx,ry in coat_profile],.006,braid,10)
    tube('Milo_Medieval_Parallel_Front_Stitch',[coat_point(side*.38,z,.003) for z,rx,ry in coat_profile[:-1]],.0017,braid,6)
    # Real narrow brocade motifs follow the coat surface, not floating decals.
    for z in (.38,.47,.69):
        pts=[]
        for j in range(32):
            t=j*math.tau/32;r=.72+.28*math.cos(4*t)
            pts.append(coat_point(side*(.59+.085*r*math.cos(t)),z+.027*r*math.sin(t),.006))
        tube('Milo_Medieval_Gold_Quatrefoil',pts,.0018,braid,6,closed=True)
    seam=[coat_point(side*.93,z,.0015) for z in (.30,.40,.50,.60,.70,.80,.87)]
    tube('Milo_Medieval_Tailored_Seam',seam,.0014,facing,6)
hem=[coat_point(.32+(math.tau-.64)*j/64,.276+.018*math.sin(.32+(math.tau-.64)*j/64)**2,.002) for j in range(65)]
tube('Milo_Medieval_Gold_Hem',hem,.005,braid,10)

# Short shoulder mantle/pelerine with a shaped hem and a tall court collar.
mantle_profile=[(.837,.333,.202),(.87,.340,.193),(.917,.302,.174),(.965,.207,.146),(.991,.180,.140)]
mantle,mantlerows=shell('Milo_Medieval_Shoulder_Mantle',mantle_profile,facing,.48,48)
for v in mantle.data.vertices:
    if v.co.z<.872:
        a=math.atan2(v.co.x/.333,-v.co.y/.202)
        v.co.z-=.016*(.5+.5*math.cos(a*5))*(.872-v.co.z)/.035
mantle_edge=[]
for j in range(65):
    a=.48+(math.tau-.96)*j/64
    mantle_edge.append((.338*math.sin(a),-.207*math.cos(a),.837-.016*(.5+.5*math.cos(a*5))))
tube('Milo_Medieval_Mantle_Braid',mantle_edge,.0055,braid,10)
for edge in (0,-1):tube('Milo_Medieval_Mantle_Opening',[r[edge] for r in mantlerows],.004,braid,9)
collar,collarrows=shell('Milo_Medieval_High_Collar',[(.957,.174,.139),(.995,.184,.143),(1.028,.191,.147)],court,.60,40)
tube('Milo_Medieval_Collar_Gold_Edge',collarrows[-1],.004,braid,10)

# Burgundy padded doublet and a small linen stand collar in place of tie/lapels.
doublet_profile=[(.385,.139,.225),(.44,.164,.245),(.57,.178,.273),(.67,.170,.260),(.78,.147,.229),(.895,.108,.154),(.955,.075,.139)]
doublet,_=shell('Milo_Medieval_Burgundy_Doublet',doublet_profile,velvet,0,48)
for v in doublet.data.vertices:
    if v.co.y>0:v.co.y*=.55
def doublet_front(x,z,lift=.006):
    rx,ry=interpolate_profile(doublet_profile,z)
    return (x,-ry*math.sqrt(max(.01,1-(x/rx)**2))-lift,z)
for side in (-1,1):
    panel('Milo_Medieval_Doublet_Waist_Tab',[doublet_front(side*.012,.42),doublet_front(side*.131,.435),doublet_front(side*.139,.384),doublet_front(side*.078,.363)],velvet,.015,.004)
    for x in (.042,.082):
        tube('Milo_Medieval_Doublet_Quilt_Seam',[doublet_front(side*x,z,.0025) for z in (.48,.56,.64,.72,.78)],.0013,stitch,6)
    panel('Milo_Medieval_Linen_Throat',[(side*.008,-.147,.978),(side*.07,-.142,.976),(side*.086,-.158,.942),(side*.015,-.17,.923)],shirt,.013,.003)
# Visible gold frog closures, each joined to the doublet's front surface.
for z in (.868,.788,.708):
    for side in (-1,1):
        pts=[doublet_front(side*(.014+.033*(.5+.5*math.cos(j*math.tau/24))),z+.010*math.sin(j*math.tau/24),.008) for j in range(24)]
        tube('Milo_Medieval_Gold_Frog_Clasp',pts,.0028,braid,8,closed=True)
    o=button('Milo_Medieval_Clasp_Button',doublet_front(0,z,.012),.009,gold);o['rigid_accessory']=True
# One small teal stone keeps Milo's scholarly insignia without business lapels.
panel('Milo_Medieval_Throat_Brooch',[(-.013,-.174,.955),(0,-.181,.970),(.013,-.174,.955),(0,-.181,.940)],gold,.010,.002)
panel('Milo_Medieval_Brooch_Inlay',[(-.008,-.182,.955),(0,-.186,.964),(.008,-.182,.955),(0,-.186,.946)],gem,.005,.001)

# Belt, buckle and a short pointed belt tongue — no modern pocket welts.
belt,_=shell('Milo_Medieval_Leather_Belt',[(.563,.351,.285),(.596,.350,.282)],strap,0,64)
for z in (.566,.593):
    tube('Milo_Medieval_Belt_Stitch',[(.352*math.sin(j*math.tau/64),-.286*math.cos(j*math.tau/64),z) for j in range(64)],.0014,braid,6,closed=True)
bucklepts=path([(-.042,-.293,.560),(.042,-.293,.560),(.042,-.293,.600),(-.042,-.293,.600)],5,True)
o=tube('Milo_Medieval_Belt_Buckle',bucklepts,.0055,gold,10,closed=True);o['rigid_accessory']=True
tube('Milo_Medieval_Buckle_Pin',[(0,-.298,.562),(0,-.298,.597)],.0028,gold,8)
panel('Milo_Medieval_Belt_Tongue',[(.018,-.288,.563),(.050,-.286,.563),(.052,-.278,.481),(.033,-.280,.463),(.016,-.280,.486)],strap,.012,.003)
for z in (.506,.529):button('Milo_Medieval_Belt_Stud',(.034,-.292,z),.0045,braid)

# Padded upper sleeves, fitted forearms and subtly flared embroidered cuffs.
def hollow_cuff(obj,thickness=.003):
    # Garment tubes must have an opening for the wrist, not a solid end disk.
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if len(f.verts)>4],context='FACES_ONLY')
    bm.to_mesh(obj.data);bm.free()
    select(obj);mod=obj.modifiers.new('Fabric wall thickness','SOLIDIFY')
    mod.thickness=thickness;mod.offset=-1
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj
for side in (-1,1):
    pts=path([(side*.239,0,.854),(side*.280,-.003,.839),(side*.336,-.006,.774),(side*.379,-.010,.692),(side*.443,-.018,.553)],6)
    radii=[]
    for i,p in enumerate(pts):
        t=i/(len(pts)-1)
        radii.append(.065+.049*math.sin(min(1,t/.35)*math.pi/2) if t<.35 else .114-.029*(t-.35)/.65)
    hollow_cuff(tube('Milo_Sleeve_Medieval_'+str(side),pts,radii,court,32,depth=.94))
    # Fine paned-sleeve seams follow the upper-arm form.
    for phi in (-.55,0,.55):
        line=[]
        for i in range(3,12):
            p=pts[i];tangent=(pts[i+1]-pts[i-1]).normalized()
            a=tangent.cross(Vector((0,1,0))).normalized();b=tangent.cross(a).normalized()
            line.append(p+(radii[i]+.001)*(math.sin(phi)*a+math.cos(phi)*b))
        tube('Milo_Sleeve_Medieval_Pane_Seam',line,.0018,braid,7)
    end=Vector((side*.443,-.018,.553));axis=Vector((side*.064,-.008,-.139)).normalized()
    a=axis.cross(Vector((0,1,0))).normalized();b=axis.cross(a).normalized()
    hollow_cuff(tube('Milo_Broad_Cuff_Medieval_'+str(side),[end-axis*.074,end-axis*.057,end+axis*.005,end+axis*.018],[.091,.104,.118,.112],facing,32,depth=.94))
    for t,r in ((-.055,.104),(.008,.118)):
        c=end+axis*t
        tube('Milo_Cuff_Medieval_Gold_Border',[c+r*(math.cos(j*math.tau/48)*a+.94*math.sin(j*math.tau/48)*b) for j in range(48)],.0045,braid,10,closed=True)
    hollow_cuff(tube('Milo_Linen_Cuff_Medieval',[end-axis*.009,end+axis*.007],[.070,.061],shirt,32,depth=.94),.004)

for obj in bpy.data.objects:
    if obj.type=='MESH' and ('Medieval' in obj.name or obj.name.startswith('Milo_Medieval')):
        obj['design']='Medieval-inspired scholarly court coat, mantle, burgundy doublet and gold fasteners.'
scene['wardrobe_design']='Medieval fantasy court coat and doublet; modern notched lapels and tie removed.'
