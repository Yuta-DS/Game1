"""The face is built at the supplied image's measured landmarks."""
before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(OUT/'head_seed.glb'));new=set(bpy.data.objects)-before
core=next(o for o in new if o.type=='MESH');world=core.matrix_world.copy();core.parent=None;core.matrix_world=world
for md in list(core.modifiers):core.modifiers.remove(md)
select(core);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
# Vertical AnyCreature chains use a rotated section frame: map its major
# cross-section axis to horizontal X, not forward depth. Otherwise the eyes
# would be buried by a protruding central cranium.
for v in core.data.vertices:v.co.x,v.co.y=v.co.y,-v.co.x
for o in new:
    if o!=core:bpy.data.objects.remove(o,do_unlink=True)
for a in list(core.data.color_attributes):core.data.color_attributes.remove(a)
# Cheek and brow masses belong to one connected cranium, not an exposed sphere.
cheekcore=[core]
for s in (-1,1):
    cheekcore.append(ell('cheek mass',(s*.280,-.015,1.178),(.214,.196,.135),fur))
    cheekcore.append(ell('orbital mass',(s*.205,-.030,1.365),(.206,.232,.180),fur))
cranium=sculpt_union(cheekcore,'Milo_Sculpt_Head',fur,.012,.035,3)
def surface_y(x,z):
    hit,p,normal,idx=cranium.ray_cast(Vector((x,-3,z)),Vector((0,1,0)))
    return p.y if hit else -.22
# Facets primarily on the crown/back; the facial transitions are softly shaded.
paint=mat('00 painted cream and taupe fur','FFFFFF');vcol=paint.node_tree.nodes.new('ShaderNodeVertexColor');vcol.layer_name='FurColor';paint.node_tree.links.new(vcol.outputs['Color'],paint.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
cranium.data.materials.clear();cranium.data.materials.append(paint)
colors=cranium.data.color_attributes.new(name='FurColor',type='BYTE_COLOR',domain='CORNER');cranium.data.color_attributes.active_color_index=0
base=rgba('BCAE96');cream=rgba('DDD0B6');taupe=rgba('978A75')
for p in cranium.data.polygons:
    center=sum((cranium.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
    p.use_smooth=center.y<-.12 and center.z<1.48
    for li in p.loop_indices:
        x,y,z=cranium.data.vertices[cranium.data.loops[li].vertex_index].co;front=max(0,min(1,(-y-.04)/.16))
        blaze=max(0,1-abs(x)/(.13+.08*max(0,1.65-z)))*front*max(0,min(1,(z-1.42)/.13))
        light=max(blaze,.13*front);c=[base[k]*(1-light)+cream[k]*light for k in range(3)]
        v=max(0,1-abs(abs(x)-(.07+(z-1.54)*.75))/.065)*front*max(0,min(1,(z-1.52)/.12))*.78
        if y>.04:v=max(v,.20+.20*max(0,min(1,(z-1.5)/.17)))
        if y<-.06 and z<1.24 and abs(x)>.24:
            c=list(rgba('DAD0B9')[:3])
        colors.data[li].color=tuple(c[k]*(1-v)+taupe[k]*v for k in range(3))+(1,)
# Paint the actual skull polygons; no projected planes at crown ray misses.
# Material regions retain their colour reliably in both Blender and GLB.
for a in list(cranium.data.color_attributes):cranium.data.color_attributes.remove(a)
palette=[fur,mat('06 taupe forehead markings','998B73'),mat('08 central ivory blaze','D8CDB4'),mat('09 back head taupe','B3A48B'),ivory]
cranium.data.materials.clear()
for m in palette:cranium.data.materials.append(m)
for p in cranium.data.polygons:
    c=sum((cranium.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices);x,y,z=c
    idx=3 if y>.02 else 0
    if y<-.05 and z>1.50:
        if abs(x)<.075:idx=2
        elif z>1.57 and abs(abs(x)-(.095+(z-1.55)*.72))<.075:idx=1
    if y<-.06 and z<1.23 and abs(x)>.25:idx=4
    p.material_index=idx
# Thick rooted ears, with recessed pink bowls and a cream rim.
for s in (-1,1):
    outer=[(s*.18,-.025,1.60),(s*.26,-.013,1.735),(s*.361,.015,1.854),
           (s*.391,.019,1.845),(s*.427,-.010,1.617),(s*.363,-.062,1.533)]
    patch('Milo_Sculpt_Ear_'+str(s),outer,(s*.326,-.020,1.676),rimfur,.08,1)
    bowl=[(s*.226,-.062,1.628),(s*.29,-.045,1.721),(s*.367,-.012,1.816),
          (s*.392,-.048,1.627),(s*.340,-.079,1.583)]
    patch('Milo_Inner_Ear_'+str(s),bowl,(s*.330,-.033,1.670),inner,.012,1)
# White lower-face shell: muzzle foundation, short chin and stepped ruff share one surface.
whiteparts=[ell('muzzle base',(0,-.163,1.100),(.215,.083,.075),ivory),ell('short chin',(0,-.158,1.025),(.137,.108,.050),ivory)]
for s in (-1,1):
    whiteparts.append(ell('integrated cream cheek',(s*.241,-.047,1.107),(.158,.143,.079),ivory))
    for k,(z,root,tip) in enumerate(((1.295,.390,.521),(1.224,.378,.549),(1.154,.343,.502))):
        outline=[(s*(root-.075),-.164,z+.046),(s*(tip-.065),-.077,z+.032),
                 (s*tip,-.025,z+.019-k*.016),(s*(tip-.066),-.082,z-.045),(s*(root-.080),-.177,z-.051)]
        whiteparts.append(patch('short cheek ruff',outline,(s*(root+.010),-.161,z),ivory,.034,1))
    # Cross-sections of a broad moustache fan, from the nose into an upturned tip.
    stations=[(.012,-.293,1.192,1.118,.033),(.074,-.305,1.196,1.079,.057),
              (.166,-.298,1.166,1.038,.061),(.260,-.258,1.131,1.046,.046),
              (.333,-.224,1.132,1.083,.025),(.370,-.215,1.145,1.142,.002)]
    dense=[]
    for i in range(len(stations)-1):
        for j in range(5):
            t=j/5;a=stations[max(0,i-1)];b=stations[i];c=stations[i+1];d=stations[min(len(stations)-1,i+2)]
            dense.append(tuple(.5*(2*b[k]+(-a[k]+c[k])*t+(2*a[k]-5*b[k]+4*c[k]-d[k])*t*t+(-a[k]+3*b[k]-3*c[k]+d[k])*t*t*t) for k in range(5)))
    dense.append(stations[-1]);vs=[];n=20
    for x,y,top,bottom,d in dense:
        for j in range(n):
            a=math.tau*j/n;z=(top+bottom)/2+(top-bottom)*.5*math.cos(a)
            yy=y+d*math.sin(a)
            if math.sin(a)<0:yy+=.0018*math.sin(3*a+x*8)**2
            vs.append((s*x,yy,z))
    fs=[(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(len(dense)-1) for j in range(n)]
    fs.extend((tuple(reversed(range(n))),tuple((len(dense)-1)*n+j for j in range(n))))
    whiteparts.append(mesh('sculpted moustache fan',vs,fs,ivory))
mask=sculpt_union(whiteparts,'Milo_Sculpt_Connected_Muzzle_Ruff',ivory,.006,.22,3)
for p in mask.data.polygons:p.use_smooth=True
groovemat=mat('07 fine moustache fur groove','C8BDA7')
for s in (-1,1):
    for offset in (0,.022,.042):
        pts=[]
        for x,z in ((.052,1.162),(.107,1.123),(.185,1.091),(.26,1.089),(.326,1.111)):
            x*=s;z+=offset;hit,p,n,idx=mask.ray_cast(Vector((x,-2,z)),Vector((0,1,0)))
            if hit:pts.append((x,p.y-.0014,z))
        if len(pts)>2:tube('Milo_Moustache_Fur_Groove',path(pts,4),.0011,groovemat,6)
# Eyes are recessed into the orbital masses, with small amber irises and vertical pupils.
for s in (-1,1):
    ex=s*.215;ez=1.30
    ell('Milo_Eye_White_'+str(s),(ex,-.251,ez),(.107,.051,.113),white,32,20)
    # One continuous radial iris surface, not three nested medallion-like shells.
    irispaint=mat('Amber radial iris '+str(s),'FFFFFF',.28)
    node=irispaint.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='IrisColor';irispaint.node_tree.links.new(node.outputs['Color'],irispaint.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    vs=[];n=48;rings=[0,.20,.48,.74,.92,1]
    for r in rings:
        for j in range(n):
            a=j*math.tau/n;vs.append((ex+.098*r*math.cos(a),-.325+.022*r*r,ez+.104*r*math.sin(a)))
    fs=[(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(len(rings)-1) for j in range(n)]
    irisobj=mesh('Milo_Painted_Amber_Iris_'+str(s),vs,fs,irispaint)
    ca=irisobj.data.color_attributes.new(name='IrisColor',type='BYTE_COLOR',domain='CORNER');irisobj.data.color_attributes.active_color_index=0
    shades=[rgba(c) for c in ('8F672D','9B7231','B78B43','A37A38','725325','544123')]
    for poly in irisobj.data.polygons:
        for li in poly.loop_indices:
            vi=irisobj.data.loops[li].vertex_index;ring=vi//n;j=vi%n;col=shades[ring];v=1+.025*math.sin(j*2.71)
            ca.data[li].color=tuple(c*v for c in col[:3])+(1,)
    ell('Milo_Pupil_'+str(s),(ex,-.328,ez+.003),(.049,.006,.066),pupil,32,16)
    ell('Milo_Eye_Glint_'+str(s),(ex-.019,-.331,ez+.029),(.012,.003,.017),highlight,16,10)
    ell('Milo_Eye_Small_Glint_'+str(s),(ex+.022,-.331,ez-.034),(.004,.002,.005),highlight,12,8)
    # Upper lid seats the eye in the face instead of leaving a bare concentric stack.
    pts=[(ex+.104*math.cos(a),-.283,ez+.111*math.sin(a)) for a in [math.pi*j/16 for j in range(17)]]
    ring=[(ex+.136*math.cos(j*math.tau/64),-.343,ez+.136*math.sin(j*math.tau/64)) for j in range(64)]
    tube('Milo_Gold_Spectacle_'+str(s),ring,.0095,gold,10,closed=True)
    tube('Milo_Spectacle_Temple_'+str(s),path([(s*.352,-.343,1.315),(s*.414,-.203,1.35),(s*.391,-.017,1.381),(s*.357,.11,1.37)],7),.0055,gold,8)
    brow=[(s*.112,-.215,1.486),(s*.146,-.206,1.523),(s*.222,-.180,1.547),(s*.278,-.155,1.536),(s*.316,-.144,1.501),(s*.233,-.198,1.514),(s*.164,-.222,1.493)]
    brow=[(x,surface_y(x,z)-.006,z) for x,y,z in brow]
    brow=[(x,y,1.52+(z-1.52)*1.35) for x,y,z in brow]
    patch('Milo_Ivory_Brow_'+str(s),brow,(s*.211,surface_y(s*.211,1.525)-.054,1.525),ivory,.030,0)
tube('Milo_Gold_Bridge',path([(-.079,-.343,1.319),(-.040,-.356,1.33),(0,-.367,1.335),(.040,-.356,1.33),(.079,-.343,1.319)],5),.0075,gold,10)
nose_outline=[(-.043,-.326,1.195),(.043,-.326,1.195),(.030,-.341,1.175),(0,-.350,1.151),(-.030,-.341,1.175)]
patch('Milo_Peach_Nose',nose_outline,(0,-.369,1.185),nosemat,.025,1)
tube('Milo_Small_Mouth',path([(-.033,-.293,1.034),(0,-.301,1.029),(.033,-.293,1.034)],5),.0022,mouthmat,8)
# Seat the eye assemblies closer to the facial surface. The nose/moustache
# retain their deliberate projection; glasses remain thin circular frames.
for o in list(bpy.data.objects):
    if o.type=='MESH' and o.name.startswith(('Milo_Eye_','Milo_Painted_Amber_Iris','Milo_Pupil','Milo_Gold_Spectacle','Milo_Spectacle_','Milo_Gold_Bridge')):
        for v in o.data.vertices:v.co.y+=.017
