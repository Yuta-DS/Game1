"""Connected, subdivision-ready paw cages with authored digit ownership.

Three fingers extrude from one palm; the thumb extrudes from its side.
Weights follow the anatomical loops, never a nearest-finger distance field.
All coordinates use the wrist's anatomical frame (u across, v distal,
w PALMAR). The thumb side defines handedness; positive X curl bends into
the palm. Resting palms face inward, dorsal knuckles outward/front.
"""
from mathutils import Matrix,Quaternion

HAND_CHAINS={}
HAND_FRAMES={}
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
    levels=[(-.016,.033,.025),(0,.036,.026),(.022,.046,.030),(.045,.056,.033),(.068,.058,.029),(.091,.055,.022)]
    rings=[];maps=[]
    for v,width,depth in levels:
        mapping={}
        for k,d in perimeter:
            u=width*(k/3-1)
            # Rounded dorsal arch, gently cupped palm. No broad flat slab.
            fraction=abs(u/width)
            w=d*depth*math.sqrt(1-.60*fraction*fraction)
            w*=1.15 if d<0 else (.80+.20*fraction*fraction)
            mapping[k,d]=vertex((u,v,w))
        maps.append(mapping);rings.append([mapping[key] for key in perimeter])
    inner=-s
    side_edges=(6,7) if inner>0 else (14,15)
    for row in range(len(rings)-1):
        for j in range(16):
            if row in (2,3) and j in side_edges:continue
            fs.append((rings[row][j],rings[row][(j+1)%16],rings[row+1][(j+1)%16],rings[row+1][j]))
    fs.append(tuple(reversed(rings[0])))
    distal=maps[-1];width=levels[-1][1];depth=levels[-1][2]
    for k in (2,4):distal[k,0]=vertex((width*(k/3-1),.091,0))
    chains={}
    for k,length in enumerate((.058,.065,.056)):
        a=2*k
        ring=[distal[a,-1],distal[a+1,-1],distal[a+2,-1],distal[a+2,0],distal[a+2,1],distal[a+1,1],distal[a,1],distal[a,0]]
        u=width*((a+1)/3-1);spread=(k-1)*.005
        start=Vector((u,.091,0));joint=start+Vector((spread*.50,length*.51,-.0015));tip=start+Vector((spread,length,-.003))
        prox='finger%d.'%k+label;dist='finger%d_tip.'%k+label
        chains[prox]=(world(start),world(joint),'hand.'+label)
        chains[dist]=(world(joint),world(tip),prox)
        for t in (.12,.27,.43,.51,.60,.76,.88,.96):
            center=start.lerp(tip,t)
            radius=.0175*(1-.10*t)
            if t>.76:radius*=math.sqrt(max(.06,1-((t-.76)/.25)**2))
            # A support loop either side of the interphalangeal joint.
            if t<.27:weights={'hand.'+label:max(0,1-t/.24),prox:min(1,t/.24)}
            else:
                blend=max(0,min(1,(t-.38)/.25));weights={prox:1-blend,dist:blend}
            new=[]
            for j in range(8):
                # Clockwise around the same perimeter as the palm opening.
                coords=[(-.707,-.707),(0,-1),(.707,-.707),(1,0),(.707,.707),(0,1),(-.707,.707),(-1,0)][j]
                new.append(vertex(center+Vector((coords[0]*radius,0,coords[1]*radius*1.07)),weights))
            bridge(ring,new);ring=new
        pole=vertex(tip+Vector((0,.001,0)),{dist:1})
        fs.extend((ring[j],ring[(j+1)%8],pole) for j in range(8))
    # Thumb side opening: a connected saddle, not a separate floating sphere.
    sidek=6 if inner>0 else 0
    ring=[maps[2][sidek,-1],maps[3][sidek,-1],maps[4][sidek,-1],maps[4][sidek,0],maps[4][sidek,1],maps[3][sidek,1],maps[2][sidek,1],maps[2][sidek,0]]
    start=Vector((inner*.056,.045,0));joint=Vector((inner*.080,.062,-.005));tip=Vector((inner*.098,.095,-.009))
    prox='thumb.'+label;dist='thumb_tip.'+label
    chains[prox]=(world(start),world(joint),'hand.'+label);chains[dist]=(world(joint),world(tip),prox)
    for index in ring:ws[index]={'hand.'+label:.8,prox:.2}
    # The first two rings leave the palm laterally before turning toward the
    # tip. This avoids the folded/collapsed saddle of a tilted first ring.
    thumb_loops=[
        ((inner*.066,.045,-.002),.020,0,{'hand.'+label:.50,prox:.50}),
        ((inner*.075,.050,-.004),.020,.24,{'hand.'+label:.23,prox:.77}),
        ((inner*.080,.062,-.005),.019,.50,{prox:.55,dist:.45}),
        ((inner*.087,.075,-.007),.018,.60,{prox:.08,dist:.92}),
        ((inner*.093,.086,-.008),.016,.60,{dist:1}),
        ((inner*.097,.093,-.009),.009,.60,{dist:1}),
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
    # Normalize interpolated subdivision weights explicitly for glTF.
    for v in o.data.vertices:
        total=sum(g.weight for g in v.groups)
        for g in list(v.groups):o.vertex_groups[g.group].add([v.index],g.weight/total,'REPLACE')
    o['hand_topology']='Compact rounded paw, three short two-joint digits, opposing thumb; connected authored-loop skinning.'
    o['anatomical_palm_axis']='+Z in hand bone space; +X curl; mirrored inward resting palms'
    HAND_CHAINS[label]=chains
