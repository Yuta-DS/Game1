"""Cast-style elder cat: shaped AnyCreature skull and restrained dark eyes.

Rogue/Mage/Barbarian and Fox use dark oval eyes, not colored iris rings.
Keep Milo's gold spectacles, white brows and moustache as identity anchors.
"""
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(OUT/'head_seed.glb'))
new=set(bpy.data.objects)-before
core=next(o for o in new if o.type=='MESH')
world=core.matrix_world.copy();core.parent=None;core.matrix_world=world
for md in list(core.modifiers):core.modifiers.remove(md)
select(core);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for v in core.data.vertices:
    v.co.x,v.co.y=v.co.y*1.04,-v.co.x*.89
    if v.co.z>1.40:
        # Ease into a horizontal crown tangent instead of a conical apex.
        u=min(1,(v.co.z-1.40)/.27)
        v.co.z=1.40+.24*math.sin(u*math.pi/2)
for o in new:
    if o!=core:bpy.data.objects.remove(o,do_unlink=True)
for a in list(core.data.color_attributes):core.data.color_attributes.remove(a)
headfur=mat('Milo head - soft warm cream','C5B69B',.84)
core.name='Head_Cranium_AnyCreature'
core.data.materials.clear();core.data.materials.append(headfur)
select(core)
md=core.modifiers.new('Round the crown and jaw transitions','SUBSURF');md.levels=1
bpy.ops.object.modifier_apply(modifier=md.name)
from mathutils.bvhtree import BVHTree
bare_skull_surface=BVHTree.FromPolygons([v.co.copy() for v in core.data.vertices],
                                      [p.vertices[:] for p in core.data.polygons])

# Two compact swept cheek points connected into the cranium. The old three
# horizontal plates on each side are removed rather than smoothed in place.
cheeks=[core]
for s in (-1,1):
    for k,(z,tip) in enumerate(((1.245,.449),(1.153,.423))):
        outline=[(s*.299,-.150,z+.040),(s*.367,-.100,z+.027),
                 (s*tip,-.012,z+.012),(s*.404,-.040,z-.022),
                 (s*.334,-.120,z-.036),(s*.286,-.170,z-.025)]
        cheeks.append(patch('Cheek_Sweep_'+str(s)+'_'+str(k),outline,
                            (s*.345,-.120,z),headfur,.080,1))
core=sculpt_union(cheeks,'Head_Cranium_AnyCreature',headfur,
                  voxel=.008,reduction=.20,smooth_iters=4)
for p in core.data.polygons:p.use_smooth=True
core['design']='Connected chubby cheek/jaw silhouette; smooth cast-style normals'
core['source_spec']='head_spec.json / local AnyCreature compile'
core.data.update()
def surf(x,z):
    hit,p,_,_=core.ray_cast(Vector((x,-3,z)),Vector((0,1,0)))
    if not hit:raise ValueError('Face feature outside the skull: '+str((x,z)))
    return p.y

# Shorter, wider-rooted ears follow the rounded skull rather than perching on
# top as thin spikes. The inset is comfortably inside the outer bowl.
for s in (-1,1):
    outline=[(s*.183,-.035,1.536),(s*.244,-.012,1.653),
             (s*.351,.012,1.747),(s*.381,.018,1.755),
             (s*.401,-.001,1.570),(s*.349,-.045,1.507)]
    patch('Ear_'+str(s),outline,(s*.315,-.042,1.619),rimfur,.062,1)
    bowl=[(s*.249,-.053,1.596),(s*.293,-.042,1.663),
          (s*.360,-.022,1.719),(s*.371,-.040,1.590),(s*.333,-.068,1.560)]
    patch('Ear_Inner_'+str(s),bowl,(s*.318,-.067,1.625),inner,.014,1)

# Tucked chin, broad jaw and a restrained elder moustache with lifted tips.
patch('Chin',[(-.133,-.182,1.065),(-.096,-.204,1.015),(-.035,-.218,.998),
              (.035,-.218,.998),(.096,-.204,1.015),(.133,-.182,1.065)],
      (0,-.252,1.043),headfur,.061,1)
# Folded, sculpted fur rather than smooth tubular lobes. The longitudinal
# ridges share one closed surface; they are not loose whisker decorations.
def fur_loft(name,stations,side):
    dense=[]
    for i in range(len(stations)-1):
        for j in range(4):
            t=j/4;a=stations[max(0,i-1)];b=stations[i];c=stations[i+1];d=stations[min(len(stations)-1,i+2)]
            dense.append(tuple(.5*(2*b[k]+(-a[k]+c[k])*t+(2*a[k]-5*b[k]+4*c[k]-d[k])*t*t+(-a[k]+3*b[k]-3*c[k]+d[k])*t*t*t) for k in range(5)))
    dense.append(stations[-1]);vs=[];fs=[];n=48
    for row,(x,y,top,bottom,depth) in enumerate(dense):
        u=row/(len(dense)-1)
        for j in range(n):
            a=math.tau*j/n
            v=(1+math.cos(a))*.5
            front=math.sin(a)<0
            q=abs(math.sin(a))
            # Two broad fur folds sweep down from the root and converge at
            # the curl. Shallow valleys remain part of the same skin.
            fold=0
            if front:
                envelope=math.sin(math.pi*u)**.65*q
                for crest,amount,width in ((.30+.21*(1-u),.003,.22),(.57+.32*(1-u),.007,.24)):
                    fold+=amount*max(0,1-abs(v-crest)/width)*envelope
            offset=(-1 if front else 1)*depth*q
            vs.append((side*x,y+offset-fold,bottom+(top-bottom)*v))
    for i in range(len(dense)-1):
        for j in range(n):fs.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
    fs.extend((tuple(reversed(range(n))),tuple((len(dense)-1)*n+j for j in range(n))))
    obj=mesh(name,vs,fs,ivory,True)
    select(obj);md=obj.modifiers.new('Continuous folded fur surface','SUBSURF');md.levels=1
    bpy.ops.object.modifier_apply(modifier=md.name)
    obj['design']='DOCX image7 panel 05: two swept fur folds, full inner lobe, fine outer curl; one closed head-bound surface.'
    return obj

for s in (-1,1):
    # High inner shoulder, low rounded underside, then a restrained rising
    # outer curl. The tip is swept outward, not a vertical horn.
    fur_loft('Moustache_'+str(s),[
        (.003,-.282,1.153,1.119,.019),
        (.032,-.290,1.178,1.087,.031),
        (.073,-.290,1.168,1.064,.036),
        (.121,-.269,1.145,1.062,.033),
        (.172,-.242,1.136,1.081,.026),
        (.211,-.215,1.148,1.111,.018),
        (.237,-.192,1.170,1.153,.010),
        (.245,-.181,1.180,1.176,.002)],s)

    # One volumetric cheek ruff per side replaces the separate splayed fins.
    # The two short leaf tips share a broad buried root and a sculpted fold.
    outline=[
        (.307,1.277),(.335,1.291),(.368,1.285),(.405,1.267),
        (.438,1.257),(.451,1.261),(.439,1.242),(.411,1.231),
        (.425,1.217),(.442,1.209),(.425,1.194),(.393,1.190),
        (.370,1.199),(.339,1.211),(.311,1.235)]
    pts=path([(s*x,-.154+(x-.335)*.36,z) for x,z in outline],4,True)
    center=Vector((s*.366,-.137,1.242));n=len(pts)
    vs=[tuple(p) for p in pts];fs=[]
    for face_sign,bulge in ((-1,.034),(1,.072)):
        previous=list(range(n))
        for r in (.90,.75,.58,.40,.22,.08):
            ring=[]
            for p in pts:
                q=center+(p-center)*r
                # Recess the diagonal between the two fur lobes, keeping a
                # continuous root instead of a dark gap between loose leaves.
                seam_z=1.247-(abs(q.x)-.350)*.22
                crease=.012*math.exp(-((q.z-seam_z)/.009)**2)
                relief=(bulge-crease if face_sign<0 else bulge)*(1-r*r)
                q.y+=face_sign*relief
                # Inner third sits beneath the skull surface.
                if abs(q.x)<.362:q.y+=.060*(.362-abs(q.x))/.055
                if q.z<1.219:q.y+=.028*(1.219-q.z)/.028
                ring.append(len(vs));vs.append(tuple(q))
            for j in range(n):
                f=(previous[j],previous[(j+1)%n],ring[(j+1)%n],ring[j])
                fs.append(f if face_sign<0 else tuple(reversed(f)))
            previous=ring
        pole=len(vs);q=center.copy();q.y+=face_sign*bulge;vs.append(tuple(q))
        for j in range(n):
            f=(previous[j],previous[(j+1)%n],pole)
            fs.append(f if face_sign<0 else tuple(reversed(f)))
    ruff=mesh('Cheek_Ruff_'+str(s),vs,fs,ivory,True)
    select(ruff);md=ruff.modifiers.new('Integrated paired cheek fur','SUBSURF');md.levels=1
    bpy.ops.object.modifier_apply(modifier=md.name)
    ruff['design']='Two short overlapping leaf tips on one connected cream cheek ruff; shared skull-buried root, sculpted diagonal separation.'

# One dark, shallow oval per eye with a soft lighting highlight only. Closed
# eye meshes conform to the face and embed their backs in the skull.
# No iris/sclera rings, black socket tubes, or painted sparkle meshes.
cast_eye=mat('Milo eyes - cast charcoal oval','202521',.56)
cast_eye.node_tree.nodes['Principled BSDF'].inputs['Specular IOR Level'].default_value=.22
EYE_CENTERS={}
for s,label in ((-1,'R'),(1,'L')):
    ex=s*.166;ez=1.286
    eye=ell('Eye_'+str(s),(ex,0,ez),(.046,.014,.066),cast_eye,32,20)
    # No eye texture is used; omit UV seams so the exported closed surface
    # stays welded instead of splitting at the sphere's meridian and poles.
    for uv in list(eye.data.uv_layers):eye.data.uv_layers.remove(uv)
    for v in eye.data.vertices:v.co.y+=surf(v.co.x,v.co.z)-.004
    EYE_CENTERS[label]=(ex,surf(ex,ez)-.004,ez)
    eye['style']='Single charcoal oval, matching the game cast eye vocabulary'
    eye.data.update()

    # Light round frames keep Milo identifiable without making each entire
    # lens read as an oversized eyeball.
    gx=s*.171;gy=-.255
    ring=[]
    for j in range(64):
        a=j*math.tau/64;x=gx+.108*math.cos(a)
        ring.append((x,gy+(abs(x)-.171)*.35,ez+.111*math.sin(a)))
    tube('Glasses_Rim_'+str(s),ring,.0067,gold,10,closed=True)
    tube('Glasses_Temple_'+str(s),path([(s*.279,-.2172,1.291),
         (s*.355,-.157,1.305),(s*.392,-.025,1.351),(s*.344,.090,1.375)],5),.0058,gold,8)

    # Soft outward-falling brows read kindly, not angry.
    brow_xz=[(.102,1.427),(.128,1.449),(.176,1.452),(.219,1.437),
             (.254,1.412),(.222,1.412),(.176,1.426),(.131,1.427)]
    brow=[(s*x,surf(s*x,z)-.007,z) for x,z in brow_xz]
    patch('Brow_'+str(s),brow,(s*.176,surf(s*.176,1.435)-.027,1.436),ivory,.016,1)

tube('Glasses_Bridge',path([(-.063,-.2928,1.295),(-.032,-.297,1.306),
     (0,-.298,1.310),(.032,-.297,1.306),(.063,-.2928,1.295)],5),.0063,gold,10)
nose_outline=[(-.039,-.280,1.172),(-.032,-.304,1.183),(.032,-.304,1.183),
              (.039,-.280,1.172),(.018,-.325,1.146),(0,-.330,1.137),(-.018,-.325,1.146)]
patch('Nose',nose_outline,(0,-.344,1.169),nosemat,.025,1)
tube('Mouth',path([(-.026,-.261,1.027),(0,-.268,1.023),(.026,-.261,1.027)],4),.0022,mouthmat,8)

# Remove the old beige bars beneath the new fan by projecting this small
# side region back onto the original smooth AnyCreature skull. The eyes and
# brows were placed before this edit, and their surface region is untouched.
for v in core.data.vertices:
    x,y,z=v.co
    lateral=max(0,min(1,(abs(x)-.285)/.050))
    band=min(max(0,min(1,(z-1.07)/.04)),max(0,min(1,(1.34-z)/.04)))
    blend=lateral*lateral*(3-2*lateral)*band
    if blend>0:
        nearest=bare_skull_surface.find_nearest(v.co)[0]
        if nearest is not None:v.co=v.co.lerp(nearest,blend)
core.data.update()
