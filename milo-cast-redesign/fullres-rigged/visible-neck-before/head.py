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
    v.co.x,v.co.y=v.co.y*1.04,-v.co.x*.90
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

# The prototype's face is one clean rounded cranium. Earlier boolean cheek
# wedges created a visible lumpy band in profile; the fuller AnyCreature seed
# now supplies the cheek mass directly, while the separate side locks carry
# the only intentional silhouette breaks.
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

# A rounded underside recedes into the neck instead of projecting as a
# detached chin shelf. Both volumes overlap the original, unchanged skull.
def neck_volume(name,rows):
    vs=[];fs=[];n=48
    for z,rx,front,back in rows:
        center=(front+back)*.5;depth=(back-front)*.5
        for j in range(n):
            a=math.tau*j/n
            vs.append((rx*math.sin(a),center-depth*math.cos(a),z))
    for k in range(len(rows)-1):
        for j in range(n):fs.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
    fs.extend((tuple(reversed(range(n))),tuple((len(rows)-1)*n+j for j in range(n))))
    obj=mesh(name,vs,fs,headfur,True)
    select(obj);md=obj.modifiers.new('Rounded jaw and throat transition','SUBSURF');md.levels=2
    bpy.ops.object.modifier_apply(modifier=md.name)
    return obj
chin=neck_volume('Chin',[
    (.990,.056,-.116,.059),(1.005,.082,-.145,.061),
    (1.026,.124,-.191,.049),(1.051,.157,-.224,.021),
    (1.077,.171,-.239,-.010),(1.104,.174,-.230,-.031),
    (1.130,.167,-.211,-.036)])
chin['design']='Tucked rounded jaw underside, broad skull overlap and a receding throat; no projecting chin shelf.'
neck=neck_volume('Neck_Transition',[
    (.944,.112,-.087,.097),(.960,.121,-.098,.101),
    (.976,.126,-.105,.104),(.992,.122,-.112,.106),
    (1.012,.126,-.124,.111),(1.040,.143,-.145,.122),
    (1.076,.169,-.169,.166),(1.116,.190,-.186,.188)])
neck['design']='Short tapered fur neck, buried beneath collar and skull; smoothly blended chest/neck/head weights.'
# Folded, sculpted fur rather than smooth tubular lobes. The longitudinal
# ridges share one closed surface; they are not loose whisker decorations.
def fur_loft(name,stations,side,fold_strength=1):
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
                    fold+=fold_strength*amount*max(0,1-abs(v-crest)/width)*envelope
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
        (.003,-.283,1.160,1.106,.026),
        (.041,-.284,1.190,1.069,.046),
        (.099,-.280,1.178,1.032,.056),
        (.166,-.253,1.157,1.028,.052),
        (.228,-.223,1.154,1.056,.044),
        (.275,-.193,1.177,1.105,.031),
        (.300,-.176,1.200,1.158,.019),
        (.310,-.163,1.211,1.201,.004)],s,fold_strength=1.7)

    # Sculpt two overlapping almond volumes into a single buried root.
    # Unlike the rejected radial patch, this has no squared-off backing plate,
    # and the concave notch cannot fold a triangle fan through itself.
    lobes=[]
    for k,rows in enumerate((
        [(.300,-.100,1.292,1.254,.019),(.343,-.121,1.314,1.235,.037),
         (.388,-.133,1.307,1.240,.038),(.429,-.117,1.286,1.257,.022),
         (.457,-.096,1.277,1.271,.003)],
        [(.300,-.105,1.239,1.205,.018),(.340,-.126,1.257,1.187,.035),
         (.382,-.138,1.250,1.184,.036),(.420,-.122,1.230,1.199,.021),
         (.447,-.101,1.219,1.213,.003)])):
        lobe=fur_loft('Cheek_Fur_Lobe_'+str(s)+'_'+str(k),rows,s)
        # Seat the locks behind and just below the spectacle arm. This keeps
        # their buried roots in the cheek while preventing the upper lock from
        # cutting through the gold temple in head turns.
        for v in lobe.data.vertices:
            v.co.y += .035 if k == 0 else .020
            v.co.z -= .025 if k == 0 else .010
        bm=bmesh.new();bm.from_mesh(lobe.data)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(lobe.data);bm.free()
        lobes.append(lobe)
    ruff=sculpt_union(lobes,'Cheek_Ruff_'+str(s),ivory,voxel=.002,reduction=.35,smooth_iters=3)
    for poly in ruff.data.polygons:poly.use_smooth=True
    ruff['design']='DOCX image7 layered side moustache: two soft swept almond locks sculpt-unioned at a broad buried root, no detached backing plate.'

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
# Anchor the small smile to the new jaw surface, rather than retaining the
# previous forward-floating mouth position in front of the old chin shelf.
smile=[]
for x,z in ((-.026,1.064),(0,1.060),(.026,1.064)):
    hit,p,_,_=chin.ray_cast(Vector((x,-3,z)),Vector((0,1,0)))
    assert hit,'Smile must remain on the new jaw'
    smile.append((x,p.y-.0007,z))
tube('Mouth',path(smile,4),.0022,mouthmat,8)

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
