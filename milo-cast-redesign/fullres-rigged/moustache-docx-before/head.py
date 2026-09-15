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
for s in (-1,1):
    # DOCX image7, panel 05 separates the curled moustache from two compact
    # cheek tufts. The central lobe ends beneath the spectacles, not at the
    # outside of the head; its underside is full and its tip curls upward.
    stations=[(.004,-.286,1.155,1.103,.022),(.052,-.295,1.174,1.064,.034),
              (.112,-.281,1.153,1.056,.037),(.168,-.251,1.132,1.077,.031),
              (.213,-.220,1.143,1.106,.023),(.239,-.191,1.166,1.145,.014),
              (.248,-.171,1.184,1.178,.007)]
    dense=[]
    for i in range(len(stations)-1):
        for j in range(4):
            t=j/4;a=stations[max(0,i-1)];b=stations[i];c=stations[i+1];d=stations[min(len(stations)-1,i+2)]
            dense.append(tuple(.5*(2*b[k]+(-a[k]+c[k])*t+(2*a[k]-5*b[k]+4*c[k]-d[k])*t*t+(-a[k]+3*b[k]-3*c[k]+d[k])*t*t*t) for k in range(5)))
    dense.append(stations[-1]);vs=[];n=16
    for x,y,top,bottom,depth in dense:
        for j in range(n):
            a=math.tau*j/n
            vs.append((s*x,y+depth*math.sin(a),(top+bottom)/2+(top-bottom)*.5*math.cos(a)))
    fs=[(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(len(dense)-1) for j in range(n)]
    fs.extend((tuple(reversed(range(n))),tuple((len(dense)-1)*n+j for j in range(n))))
    moustache_parts=[mesh('Moustache_'+str(s),vs,fs,ivory,True)]
    whisker=sculpt_union(moustache_parts,'Moustache_'+str(s),ivory,
                        voxel=.0035,reduction=.24,smooth_iters=3)
    # The voxel/decimation boundary can leave a few isolated tip triangles.
    # Remove only these tiny artifacts; never silently discard a fur lock.
    bm=bmesh.new();bm.from_mesh(whisker.data);remaining=set(bm.verts);components=[]
    while remaining:
        comp={remaining.pop()};stack=list(comp)
        while stack:
            for edge in stack.pop().link_edges:
                for vert in edge.verts:
                    if vert in remaining:remaining.remove(vert);comp.add(vert);stack.append(vert)
        components.append(comp)
    components.sort(key=len,reverse=True)
    for comp in components[1:]:
        assert len(comp)<16,'A moustache lock is detached; repair its root'
        bmesh.ops.delete(bm,geom=list(comp),context='VERTS')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(whisker.data);bm.free()
    whisker.data.update()
    for p in whisker.data.polygons:p.use_smooth=True
    whisker['design']='DOCX panel 05: full curved muzzle moustache, tapered upturned tip; separate from the compact paired cheek tufts.'

    # Broad almond/leaf-shaped fur masses from the isolated DOCX cheek detail.
    # Two unequal, offset lobes per side, each buried in the skull, not three
    # parallel whisker tubes. Their curved depth wraps around the cheek.
    outlines=[
        [(.309,-.151,1.228),(.343,-.147,1.267),(.380,-.117,1.282),
         (.418,-.082,1.266),(.457,-.047,1.273),(.433,-.067,1.242),
         (.391,-.119,1.228),(.343,-.157,1.217)],
        [(.316,-.155,1.211),(.341,-.145,1.238),(.372,-.123,1.232),
         (.407,-.090,1.199),(.439,-.053,1.183),(.410,-.080,1.178),
         (.365,-.134,1.190),(.329,-.158,1.197)]]
    for k,outline in enumerate(outlines):
        # A biconvex cushion closes at a shared perimeter, instead of a
        # constant-thickness extrusion whose profile reads as a long rail.
        pts=path([(s*x,-.130+(y+.130)*.45,z) for x,y,z in outline],4,True)
        center=Vector((s*(.378 if k==0 else .365),-.132,1.249 if k==0 else 1.211))
        n=len(pts);vs=[tuple(p) for p in pts];fs=[]
        for face_sign,bulge in ((-1,.032),(1,.045)):
            previous=list(range(n))
            for r in (.80,.50,.20):
                ring=[]
                for p in pts:
                    q=center+(p-center)*r;q.y+=face_sign*bulge*(1-r*r)
                    ring.append(len(vs));vs.append(tuple(q))
                for j in range(n):
                    f=(previous[j],previous[(j+1)%n],ring[(j+1)%n],ring[j])
                    fs.append(f if face_sign<0 else tuple(reversed(f)))
                previous=ring
            pole=len(vs);q=center.copy();q.y+=face_sign*bulge;vs.append(tuple(q))
            for j in range(n):
                f=(previous[j],previous[(j+1)%n],pole)
                fs.append(f if face_sign<0 else tuple(reversed(f)))
        tuft=mesh('Cheek_Tuft_'+('Upper_' if k==0 else 'Lower_')+str(s),vs,fs,ivory,True)
        select(tuft);md=tuft.modifiers.new('Rounded reference cheek cushion','SUBSURF');md.levels=1
        bpy.ops.object.modifier_apply(modifier=md.name)
        tuft['design']='Two compact cream cheek tufts per side, traced from DOCX image7 panel 05; rounded broad base and short tapered tip.'

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
