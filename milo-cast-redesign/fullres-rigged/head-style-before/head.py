"""Measured face, using the original 1536px art rather than the screenshot."""
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(OUT/'head_seed.glb'))
new=set(bpy.data.objects)-before
core=next(o for o in new if o.type=='MESH')
world=core.matrix_world.copy();core.parent=None;core.matrix_world=world
for md in list(core.modifiers):core.modifiers.remove(md)
select(core);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for v in core.data.vertices:
    v.co.x,v.co.y=v.co.y*1.065,-v.co.x*.89
    if v.co.z>1.27:v.co.z=1.27+(v.co.z-1.27)*.88
for o in new:
    if o!=core:bpy.data.objects.remove(o,do_unlink=True)
for a in list(core.data.color_attributes):core.data.color_attributes.remove(a)
core.name='Head_Cranium_AnyCreature'
core.data.materials.clear()
headmats=[fur,mat('Fur warm light','D2C3A9'),mat('Fur muted taupe','AB9C84'),mat('Fur forehead stripe','9A8C75')]
for m in headmats:core.data.materials.append(m)
for p in core.data.polygons:
    c=p.center; x,y,z=c
    p.use_smooth=False
    p.material_index=0
    if y<-.12 and abs(x)<.18:p.material_index=1
    if y>.08:p.material_index=2 if z<1.26 else 0
    if z>1.585 and abs(x)<max(.014,(z-1.58)*.60):p.material_index=3
    if y<-.08 and 1.48<z<1.59 and .19<abs(x)<.27:p.material_index=2
def surf(x,z):
    hit,p,_,_=core.ray_cast(Vector((x,-3,z)),Vector((0,1,0)))
    return p.y if hit else -.12

# Ears are thick bowls rooted in the crown; avoid a thin triangular plate.
for s in (-1,1):
    outline=[(s*.18,-.055,1.57),(s*.245,-.006,1.668),(s*.374,.027,1.782),
             (s*.402,.023,1.788),(s*.420,-.003,1.595),(s*.351,-.065,1.510)]
    outline=[(x,y,z-.045) for x,y,z in outline]
    patch('Ear_'+str(s),outline,(s*.326,-.030,1.586),rimfur,.067,1)
    bowl=[(s*.247,-.058,1.602),(s*.304,-.033,1.684),(s*.386,-.012,1.75),
          (s*.392,-.043,1.60),(s*.349,-.080,1.559)]
    bowl=[(x,y,z-.045) for x,y,z in bowl]
    patch('Ear_Inner_'+str(s),bowl,(s*.330,-.047,1.592),inner,.018,1)

# Cheek tufts remain beige, short and stepped; white is reserved for the muzzle.
ruffmat=mat('Warm pale cheek tips','C6B89E')
for s in (-1,1):
    for k,(z,root,tip) in enumerate(((1.252,.365,.503),(1.191,.371,.494),(1.133,.325,.457))):
        ol=[(s*(root-.070),-.242,z+.049),(s*(tip-.065),-.119,z+.044),
            (s*tip,-.040,z+.009),(s*(tip-.065),-.108,z-.037),(s*(root-.055),-.232,z-.042)]
        o=patch('Cheek_Tuft_'+str(s)+'_'+str(k),ol,(s*(root+.018),-.240,z),ruffmat,.065,0)
        for p in o.data.polygons:p.use_smooth=False

# Compact lower muzzle and chin. The chin is deliberately not a hanging oval.
chin=patch('Chin', [(-.175,-.19,1.078),(-.13,-.205,1.012),(-.045,-.222,.981),
                    (.045,-.222,.981),(.13,-.205,1.012),(.175,-.19,1.078)],
           (0,-.25,1.045),ivory,.055,1)
for s in (-1,1):
    # Explicit fan cross-sections make a full lobe, not a tapered crescent tube.
    stations=[(.005,-.313,1.139,1.075,.030),(.054,-.327,1.145,1.007,.056),
              (.123,-.324,1.134,.985,.059),(.204,-.297,1.108,1.000,.049),
              (.270,-.268,1.092,1.044,.025),(.313,-.242,1.112,1.095,.010),
              (.324,-.229,1.121,1.119,.001)]
    dense=[]
    for i in range(len(stations)-1):
        for j in range(3):
            t=j/3;a=stations[max(0,i-1)];b=stations[i];c=stations[i+1];d=stations[min(len(stations)-1,i+2)]
            dense.append(tuple(.5*(2*b[k]+(-a[k]+c[k])*t+(2*a[k]-5*b[k]+4*c[k]-d[k])*t*t+(-a[k]+3*b[k]-3*c[k]+d[k])*t*t*t) for k in range(5)))
    dense.append(stations[-1]);vs=[];n=14
    for x,y,top,bottom,d in dense:
        for j in range(n):
            a=math.tau*j/n
            vs.append((s*x,y+d*math.sin(a),(top+bottom)/2+(top-bottom)*.5*math.cos(a)))
    fs=[(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(len(dense)-1) for j in range(n)]
    fs.extend((tuple(reversed(range(n))),tuple((len(dense)-1)*n+j for j in range(n))))
    mo=mesh('Moustache_'+str(s),vs,fs,ivory,False)
    # Low-relief hair ridges follow the broad fan, rather than dark drawn wires.
    for k in range(2):
        pts=[(s*.04,-.365,1.118-k*.022),(s*.10,-.372,1.084-k*.021),
             (s*.185,-.342,1.059-k*.015),(s*.263,-.291,1.073-k*.008)]
        tube('Moustache_Ridge_'+str(s),path(pts,3),.0024,ivory,5)

# Small inset oval eyes: black pupils dominate, with a narrow amber iris border.
eye_liner=mat('Eye soft umber socket','847052',.75)
for s in (-1,1):
    ex=s*.166;ez=1.272
    pts=[(ex+.097*math.cos(j*math.tau/48),-.272,ez+.115*math.sin(j*math.tau/48)) for j in range(48)]
    tube('EyeSocket_'+str(s),pts,.009,eye_liner,8,closed=True)
    n=48;radii=[0,.35,.64,.77,.89,.95,1];vs=[]
    for r in radii:
        for j in range(n):
            a=j*math.tau/n;vs.append((ex+.091*r*math.cos(a),-.326+.045*r*r,ez+.108*r*math.sin(a)))
    fs=[]
    for i in range(len(radii)-1):
        for j in range(n):fs.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
    eye=mesh('Eye_'+str(s),vs,fs,pupil)
    for m in [irisouter,iris,irislight,white]:eye.data.materials.append(m)
    for p in eye.data.polygons:
        row=p.index//n;p.material_index=0 if row<2 else (2 if row<4 else (1 if row==4 else 4))
    ell('EyeGlint_'+str(s),(ex-.014,-.329,ez+.039),(.015,.004,.021),highlight,16,10)
    ell('EyeGlintSmall_'+str(s),(ex+.019,-.323,ez-.035),(.005,.003,.007),highlight,12,8)
    # Gold spectacle rims are larger than the eyes, and slightly outward.
    gx=s*.182
    ring=[(gx+.120*math.cos(j*math.tau/64),-.328,ez+.123*math.sin(j*math.tau/64)) for j in range(64)]
    tube('Glasses_Rim_'+str(s),ring,.0085,gold,10,closed=True)
    ring=[(gx+.109*math.cos(j*math.tau/64),-.326,ez+.112*math.sin(j*math.tau/64)) for j in range(64)]
    tube('Glasses_InnerLip_'+str(s),ring,.0025,edgegold,6,closed=True)
    tube('Glasses_Temple_'+str(s),path([(s*.302,-.328,1.283),(s*.391,-.228,1.303),(s*.401,-.07,1.345),(s*.351,.10,1.344)],5),.006,gold,8)
    # Rounded wedge brows hug the forehead instead of projecting as flat blades.
    brow=[(s*.099,surf(s*.099,1.452)-.004,1.452),(s*.139,surf(s*.139,1.482)-.007,1.482),
          (s*.208,surf(s*.208,1.488)-.007,1.488),(s*.263,surf(s*.263,1.46)-.007,1.46),
          (s*.272,surf(s*.272,1.44)-.008,1.44),(s*.194,surf(s*.194,1.45)-.010,1.45),
          (s*.126,surf(s*.126,1.44)-.008,1.44)]
    brow=[(x,y,1.448+(z-1.448)*1.40) for x,y,z in brow]
    patch('Brow_'+str(s),brow,(s*.179,surf(s*.179,1.465)-.045,1.469),ivory,.017,1)
tube('Glasses_Bridge',path([(-.066,-.346,1.283),(-.033,-.359,1.293),(0,-.363,1.297),(.033,-.359,1.293),(.066,-.346,1.283)],5),.007,gold,10)
nose_outline=[(-.044,-.307,1.157),(-.037,-.327,1.176),(.037,-.327,1.176),(.044,-.307,1.157),(.019,-.34,1.125),(0,-.345,1.116),(-.019,-.34,1.125)]
patch('Nose',nose_outline,(0,-.365,1.154),nosemat,.026,1)
tube('Mouth',path([(-.029,-.264,1.003),(0,-.275,.999),(.029,-.264,1.003)],4),.002,mouthmat,8)
