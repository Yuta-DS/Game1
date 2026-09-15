"""Connected, subdivision-ready paw cages with authored digit ownership.

Three fingers extrude from one palm; the thumb extrudes from its side.
Weights follow the anatomical loops, never a nearest-finger distance field.
All coordinates use the wrist's anatomical frame (u across, v distal,
w PALMAR). The thumb side defines handedness; positive X curl bends into
the palm. Resting palms face inward, dorsal knuckles outward/front.
"""
from mathutils import Matrix,Quaternion
import numpy as np

HAND_CHAINS={}
HAND_FRAMES={}
HAND_ANATOMY={}
for old in list(bpy.data.objects):
    if old.name.startswith('Milo_Sculpt_Paw'):
        bpy.data.objects.remove(old,do_unlink=True)

for s,label in ((-1,'R'),(1,'L')):
    origin=Vector((s*.443,-.018,.553))
    ey=Vector((s*.027,-.005,-.108)).normalized()
    ex=Vector((1,0,0));ex=(ex-ey*ex.dot(ey)).normalized()
    ez=ex.cross(ey).normalized()
    # Mirrored pronation: thumbs forward, palms toward the coat, backs out.
    pronation=Quaternion(ey,math.radians(-s*55))
    ex=pronation@ex;ez=pronation@ez
    basis=Matrix((ex,ey,ez)).transposed()
    HAND_FRAMES[label]=(origin,basis)
    def world(p):
        u,v,w=p
        # Keep the wrist attachment, shorten the palm and especially digits.
        v=v*.85 if v<=.091 else .091*.85+(v-.091)*.68
        return origin+basis@Vector((u*.90,v,w*.95))
    vs=[];fs=[];ws=[]
    def vertex(p,weights=None):
        vs.append(tuple(world(p)));ws.append(weights or {'hand.'+label:1});return len(vs)-1
    def bridge(a,b):
        fs.extend((a[j],a[(j+1)%len(a)],b[(j+1)%len(a)],b[j]) for j in range(len(a)))
    # Rectangular cross-section: six divisions across each broad face and
    # two around each side. The distal grid can branch into three fingers.
    perimeter=[(k,-1) for k in range(7)]+[(6,0)]+[(k,1) for k in range(6,-1,-1)]+[(0,0)]
    inner=-s
    levels=[(-.016,.033,.024),(0,.036,.025),(.022,.046,.026),(.045,.054,.027),(.068,.056,.025),(.091,.055,.020)]
    def knuckle_v(u):
        # A curved metacarpal line: middle forward, little-finger edge lower.
        return .091+.003*(1-(u/.055)**2)+inner*u*.065-.003*max(0,-inner*u/.055)
    rings=[];maps=[]
    for v,width,depth in levels:
        mapping={}
        for k,d in perimeter:
            u=width*(k/3-1)
            # Rounded dorsal arch, gently cupped palm. No broad flat slab.
            fraction=abs(u/width)
            w=d*depth*math.sqrt(1-.60*fraction*fraction)
            w*=1.04 if d<0 else (.79+.21*fraction*fraction)
            vv=knuckle_v(u) if v==levels[-1][0] else v
            # The palm is a metacarpal fan, not a rigid slab. The wrist
            # stays fixed while the outer ray can cup toward the thumb.
            influence=max(0,min(1,(v-.008)/.075))
            influence=influence*influence*(3-2*influence)
            owners=[max(0,min(2,(k-1)//2)),min(2,k//2)]
            weights={'hand.'+label:1-influence}
            for owner in owners:
                name='palm%d.'%owner+label
                weights[name]=weights.get(name,0)+influence/2
            thenar_weight=.80*math.exp(-((u-inner*.052)/.040)**2-((v-.044)/.050)**2)*max(0,min(1,v/.022))*max(0,min(1,(.086-v)/.024))
            weights={name:value*(1-thenar_weight) for name,value in weights.items()}
            weights['thumb_cmc.'+label]=thenar_weight
            mapping[k,d]=vertex((u,vv,w),weights)
        maps.append(mapping);rings.append([mapping[key] for key in perimeter])
    side_edges=(6,7) if inner>0 else (14,15)
    for row in range(len(rings)-1):
        for j in range(16):
            if row in (2,3) and j in side_edges:continue
            fs.append((rings[row][j],rings[row][(j+1)%16],rings[row+1][(j+1)%16],rings[row+1][j]))
    fs.append(tuple(reversed(rings[0])))
    distal=maps[-1];width=levels[-1][1];depth=levels[-1][2]
    for k in (2,4):
        u=width*(k/3-1)
        distal[k,0]=vertex((u,knuckle_v(u),0),{'palm%d.'%(k//2-1)+label:.5,'palm%d.'%(k//2)+label:.5})
    chains={}
    digit_shapes=[]
    for k in range(3):
        anatomical=k if inner<0 else 2-k # index, middle, little
        length=(.098,.110,.083)[anatomical]
        thickness=(.0154,.0162,.0138)[anatomical]
        a=2*k
        ring=[distal[a,-1],distal[a+1,-1],distal[a+2,-1],distal[a+2,0],distal[a+2,1],distal[a+1,1],distal[a,1],distal[a,0]]
        u=width*((a+1)/3-1);spread=(k-1)*.003
        start=Vector((u,knuckle_v(u),0))
        def digit_axis(t):return start+Vector((spread*t,length*t,.002*t+.006*t*t))
        joint=digit_axis(.46);dip=digit_axis(.76);tip=digit_axis(1)
        digit_shapes.append((start.copy(),length,thickness))
        palm='palm%d.'%k+label
        prox='finger%d.'%k+label;middle='finger%d_mid.'%k+label;dist='finger%d_tip.'%k+label
        chains[palm]=(world((u*.42,.012,0)),world(start),'hand.'+label)
        chains[prox]=(world(start),world(joint),palm)
        chains[middle]=(world(joint),world(dip),prox)
        chains[dist]=(world(dip),world(tip),middle)
        for t in (.08,.19,.34,.41,.46,.51,.60,.69,.76,.81,.89,.96):
            center=digit_axis(t)
            radius=thickness*(1-.20*t)
            radius*=1+.045*math.exp(-((t-.50)/.14)**2)
            if t>.76:radius*=math.sqrt(max(.06,1-((t-.76)/.25)**2))
            # A support loop either side of the interphalangeal joint.
            if t<.20:
                blend=min(1,t/.18);weights={palm:1-blend,prox:blend}
            else:
                # Broad overlapping joint support prevents the palmar skin
                # from folding through itself when the PIP flexes deeply.
                pip_blend=max(0,min(1,(t-.27)/.36))
                dip_blend=max(0,min(1,(t-.63)/.26))
                weights={prox:1-pip_blend,middle:pip_blend-dip_blend,dist:dip_blend}
            new=[]
            for j in range(8):
                # Clockwise around the same perimeter as the palm opening.
                coords=[(-.707,-.707),(0,-1),(.707,-.707),(1,0),(.707,.707),(0,1),(-.707,.707),(-1,0)][j]
                # Broad fingertip pad, gently flattened dorsal surface; not
                # identical round cylinders with hemispheres on the ends.
                z=coords[1]*radius*(.90 if coords[1]>0 else .82)
                if coords[1]>0:z+=.0014*math.exp(-((t-.78)/.19)**2)
                new.append(vertex(center+Vector((coords[0]*radius,0,z)),weights))
            bridge(ring,new);ring=new
        pole=vertex(tip+Vector((0,.001,0)),{dist:1})
        fs.extend((ring[j],ring[(j+1)%8],pole) for j in range(8))
    # Thumb side opening: a connected saddle, not a separate floating sphere.
    sidek=6 if inner>0 else 0
    ring=[maps[2][sidek,-1],maps[3][sidek,-1],maps[4][sidek,-1],maps[4][sidek,0],maps[4][sidek,1],maps[3][sidek,1],maps[2][sidek,1],maps[2][sidek,0]]
    start=Vector((inner*.054,.045,.003));joint=Vector((inner*.075,.064,.009));tip=Vector((inner*.082,.097,.016))
    prox='thumb.'+label;dist='thumb_tip.'+label
    cmc='thumb_cmc.'+label
    chains[cmc]=(world((inner*.025,.009,.002)),world(start),'hand.'+label)
    chains[prox]=(world(start),world(joint),cmc);chains[dist]=(world(joint),world(tip),prox)
    # Move CMC blending into the broad thenar region instead of making
    # the first narrow thumb ring bridge rotating and immobile skin.
    for index in ring:ws[index]={cmc:.92,prox:.08}
    # The first two rings leave the palm laterally before turning toward the
    # tip. This avoids the folded/collapsed saddle of a tilted first ring.
    thumb_loops=[
        ((inner*.063,.045,.004),.021,0,{cmc:.50,prox:.50}),
        ((inner*.071,.053,.006),.020,.27,{cmc:.23,prox:.77}),
        ((inner*.075,.064,.009),.0185,.65,{prox:.55,dist:.45}),
        ((inner*.079,.079,.012),.0167,.95,{prox:.08,dist:.92}),
        ((inner*.081,.089,.015),.0144,1.02,{dist:1}),
        ((inner*.082,.095,.016),.008,1.02,{dist:1}),
    ]
    for center,radius,tilt,weights in thumb_loops:
        center=Vector(center);au=Vector((-inner*math.sin(tilt),math.cos(tilt),0));av=Vector((0,0,1))
        coords=[(-.707,-.707),(0,-1),(.707,-.707),(1,0),(.707,.707),(0,1),(-.707,.707),(-1,0)]
        new=[vertex(center+radius*(u*au+w*av),weights) for u,w in coords]
        bridge(ring,new);ring=new
    pole=vertex(tip+Vector((inner*.001,.001,0)),{dist:1});fs.extend((ring[j],ring[(j+1)%8],pole) for j in range(8))
    o=mesh('Milo_Articulated_Paw.'+label,vs,fs,rimfur)
    for i,weights in enumerate(ws):
        for name,value in weights.items():
            if value>1e-7:
                group=o.vertex_groups.get(name) or o.vertex_groups.new(name=name);group.add([i],value,'REPLACE')
    select(o)
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
    md=o.modifiers.new('Connected paw surface','SUBSURF');md.levels=2;bpy.ops.object.modifier_apply(modifier=md.name)
    # Sculpt anatomy INTO the existing skin, preserving one connected mesh.
    # These millimetre-scale forms remain beige fur, without separate pads,
    # painted crease lines, or detached knuckle primitives.
    def gauss(x,center,width):return math.exp(-((x-center)/width)**2)
    for vert in o.data.vertices:
        local=basis.transposed()@(vert.co-origin)
        u=local.x/.90;v=local.y/.85 if local.y<=.091*.85 else .091+(local.y-.091*.85)/.68
        w=local.z/.95
        palm_mask=gauss(v,.048,.045)*max(0,min(1,(.097-v)/.012))
        palmar=max(0,min(1,w/.014));dorsal=max(0,min(1,-w/.014))
        thenar=.0075*gauss(u,inner*.026,.021)*gauss(v,.037,.025)
        heel=.0035*gauss(u,-inner*.036,.017)*gauss(v,.043,.029)
        hollow=-.0055*gauss(u,-inner*.002,.021)*gauss(v,.059,.022)
        finger_pad=.0030*gauss(v,.079,.012)*gauss(u,0,.052)
        # Two broad, shallow flexion folds; no etched black wrinkles.
        crossfold=.071+.08*inner*u-.17*u*u/.055
        thumbfold=inner*(.008+.025*((v-.041)/.037)**2)
        crease=.0018*gauss(v,crossfold,.0038)*gauss(u,0,.046)
        crease+=.0012*gauss(u,thumbfold,.0035)*gauss(v,.045,.024)
        delta=palmar*palm_mask*(thenar+heel+hollow+finger_pad-crease)
        for start,length,radius in digit_shapes:
            # Dorsal knuckles/metacarpals are subtle, not bony human hands.
            ridge=.0022*gauss(u,start.x,.010)*gauss(v,start.y-.015,.012)
            ridge+=.0008*gauss(u,start.x*.75,.009)*gauss(v,.055,.020)
            delta-=dorsal*ridge
            t=(v-start.y)/length
            if -.05<t<.95 and abs(u-start.x)<radius*1.05:
                delta-=palmar*.00035*gauss(t,.52,.075)*gauss(u,start.x,radius*.64)
        local.z+=delta*.95;vert.co=origin+basis@local
    o.data.update()
    # Diffuse the thumb-web skin weights over the mesh connectivity. The
    # sparse cage's row bands are too abrupt for multi-axis CMC opposition.
    # Fixed finger/thumbnail anchors retain their hinge ownership; only the
    # web/thenar transition is relaxed, with no geometry shrinkage.
    count=len(o.data.vertices);group_count=len(o.vertex_groups)
    weights=np.zeros((count,group_count),dtype=np.float64)
    active=np.zeros(count,dtype=bool)
    for vert in o.data.vertices:
        for group in vert.groups:weights[vert.index,group.group]=group.weight
        local=basis.transposed()@(vert.co-origin)
        u=local.x/.90;v=local.y/.85 if local.y<=.091*.85 else .091+(local.y-.091*.85)/.68
        finger_ownership=sum(g.weight for g in vert.groups if o.vertex_groups[g.group].name.startswith('finger'))
        active[vert.index]=u*inner>.010 and .008<v<.110 and finger_ownership<.65
    edge_array=np.array([edge.vertices[:] for edge in o.data.edges],dtype=np.int32)
    a=edge_array[:,0];b=edge_array[:,1]
    degree=np.bincount(np.concatenate((a,b)),minlength=count).reshape(-1,1)
    for iteration in range(24):
        neighbors=np.zeros_like(weights)
        np.add.at(neighbors,a,weights[b]);np.add.at(neighbors,b,weights[a])
        relaxed=.40*weights+.60*neighbors/np.maximum(1,degree)
        weights[active]=relaxed[active]
    for vert in o.data.vertices:
        if not active[vert.index]:continue
        for group in list(vert.groups):o.vertex_groups[group.group].remove([vert.index])
        for group,value in enumerate(weights[vert.index]):
            if value>1e-7:o.vertex_groups[group].add([vert.index],float(value),'REPLACE')
    # Normalize interpolated subdivision weights explicitly for glTF.
    for v in o.data.vertices:
        total=sum(g.weight for g in v.groups)
        for g in list(v.groups):o.vertex_groups[g.group].add([v.index],g.weight/total,'REPLACE')
    o['hand_topology']='Metacarpal fan, three MCP/PIP/DIP digit chains, CMC/MCP/IP thumb; connected joint-loop skinning.'
    o['anatomical_palm_axis']='+Z in hand bone space; +X curl; mirrored inward resting palms'
    HAND_CHAINS[label]=chains
    HAND_ANATOMY[label]={'finger_joint_fractions':[0,.46,.76,1],'finger_count':3,'palm_rays':3,'thumb_chain':['CMC','MCP','IP'],'local_palmar_axis':'+Z','note':'Human-inspired mechanics adapted to the reference three-finger cartoon paw, not a literal human anatomical model.'}
