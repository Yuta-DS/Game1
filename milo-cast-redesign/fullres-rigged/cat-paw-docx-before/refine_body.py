"""Reference-specific garment tailoring and arm proportions."""
# A connected trouser seat hides the tail root between the two separate legs.
shell('Milo_Trouser_Seat',[(.285,.23,.135),(.36,.31,.166),(.455,.28,.173)],pants)
# A real standing collar wraps behind the neck and opens at the throat.
collar,collarrows=shell('Milo_Standing_Collar',[(.938,.173,.145),(.977,.190,.153),(1.017,.203,.158)],lapel,.52,32)
tube('Milo_Collar_Teal_Edge',collarrows[-1],.0035,teal,7)
for o in list(bpy.data.objects):
    if o.type!='MESH':continue
    if o.name.startswith(('Milo_Sleeve','Milo_Broad_Cuff','Milo_Cuff_','Milo_Linen_Cuff','Milo_Sculpt_Paw','Milo_Paw_')):
        for v in o.data.vertices:
            s=1 if v.co.x>0 else -1
            v.co.x=s*(.235+(abs(v.co.x)-.235)*.80)
    if o.name=='Milo_Sculpt_Tail':
        for v in o.data.vertices:
            v.co.x*=.78;v.co.y=.21+(v.co.y-.21)*.78
    if o.name.startswith('Milo_Notched_Lapel'):
        for v in o.data.vertices:v.co.y-=.010
    if o.name.startswith(('Milo_Lapel_Pin','Milo_Tie_Knot','Milo_Violet_Tie','Milo_Cravat_Pin','Milo_Paw_Short_Groove')):
        bpy.data.objects.remove(o,do_unlink=True)
panel('Milo_Cravat_Knot',[(-.035,-.216,.924),(0,-.229,.941),(.035,-.216,.924),(.023,-.246,.885),(0,-.25,.874),(-.023,-.246,.885)],tie,.017,.004)
panel('Milo_Gold_Tie_Ornament',[(-.016,-.252,.866),(.016,-.252,.866),(.026,-.257,.827),(0,-.266,.811),(-.026,-.257,.827)],gold,.013,.003)
# Three distinct insignia, not three interchangeable diamonds.
x,y,z=.171,-.247,.871;r=.016
panel('Pin_Cyan_Diamond',[(x-r,y,z),(x,y-.004,z+r*1.3),(x+r,y,z),(x,y-.004,z-r*1.3)],gem,.006,.001)
tube('Pin_Cyan_Inlay',[(x-r*.65,y-.005,z),(x,y-.008,z+r*.8),(x+r*.65,y-.005,z),(x,y-.008,z-r*.8)],.0013,ivory,5,closed=True)
x,y,z=.189,-.225,.901
patch('Pin_Green_Leaf',[(x-.013,y,z-.014),(x-.01,y,z+.007),(x+.018,y,z+.022),(x+.013,y,z-.008)],(x+.001,y-.005,z+.003),leaf,.004,0)
tube('Pin_Leaf_Vein',[(x-.009,y-.007,z-.013),(x+.01,y-.007,z+.011)],.0014,edgegold,5)
x,y,z=.187,-.240,.853;r=.015
points=[(x+(r if j%2==0 else r*.44)*math.sin(j*math.pi/5),y,z+(r if j%2==0 else r*.44)*math.cos(j*math.pi/5)) for j in range(10)]
panel('Pin_Purple_Star_Gold',points,gold,.006,.001)
panel('Pin_Purple_Star',[(x+(xx-x)*.72,yy-.003,z+(zz-z)*.72) for xx,yy,zz in points],star,.004,.0007)
# Fine sculpted garment seams remain quiet and do not require image textures.
for s in (-1,1):
    tube('Milo_Coat_Princess_Seam',[(s*.271,-.098,.873),(s*.323,-.132,.756),(s*.354,-.134,.603),(s*.383,-.132,.405),(s*.395,-.112,.27)],.0015,lapel,5)
    tube('Milo_Sleeve_Seam',[(s*.285,-.091,.878),(s*.344,-.106,.768),(s*.405,-.105,.650)],.0014,lapel,5)
