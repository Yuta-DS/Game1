"""Human-inspired hand mechanics adapted to Milo's three-finger silhouette.

MCP: flexion + spread. PIP/DIP: hinge flexion, DIP follows PIP at 0.65
for this authored animation (not claimed as a universal anatomical ratio).
Palm rays articulate; CMC opposition combines abduction, sweep and axial roll.
There is no free fingertip aiming, bone scaling, or wrist motion used to fake curl.
"""
import math
from mathutils import Quaternion

HAND_POSES={
    'relaxed':{'mcp':[6,8,10],'pip':[5,6,8],'spread':0,'cup':.12,'thumb':[4,7,8,5,7]},
    'open':{'mcp':[2,3,4],'pip':[3,4,5],'spread':1,'cup':0,'thumb':[2,3,3,2,3]},
    'hook':{'mcp':[18,20,22],'pip':[12,14,14],'spread':0,'cup':.12,'thumb':[5,8,10,7,8]},
    'grasp':{'mcp':[18,20,20],'pip':[12,14,14],'spread':0,'cup':.15,'thumb':[8,8,10,5,5]},
    'point':{'mcp':[1,18,20],'pip':[3,12,14],'spread':0,'cup':.20,'thumb':[10,15,15,2.5,0]},
    # The enlarged thenar pad needs an abducted approach before the thumb
    # sweeps inward; retain the opposition roll instead of crossing skin.
    # Compact fingers reach the thumb sooner: leave an approach gap instead
    # of replaying the long-glove pinch through the opposing fingertip.
    'opposition':{'mcp':[12,14,16],'pip':[10,12,14],'spread':0,'cup':.20,'thumb':[10,15,15,2.5,0]},
}

def blend_hand(a,b,t):
    t=max(0,min(1,t))
    return {key:[x+(y-x)*t for x,y in zip(a[key],b[key])] if isinstance(a[key],list) else a[key]+(b[key]-a[key])*t for key in a}

def apply_hand(rig,label,settings):
    inner=-1 if label=='L' else 1
    def hinge(name,angle,max_angle):
        rig.pose.bones[name].rotation_quaternion=Quaternion((1,0,0),math.radians(max(0,min(max_angle,angle))))
    for k in range(3):
        digit=k if label=='L' else 2-k
        cup=max(0,min(1,settings['cup']))
        hinge('palm%d.'%k+label,(0,3,12)[digit]*cup,15)
        mcp=max(0,min(85,settings['mcp'][digit]));pip=max(0,min(100,settings['pip'][digit]))
        # Splay reduces as the MCP flexes: a closed hand does not fan like
        # an open greeting. PIP/DIP have no sideways bending or axial spin.
        spread=-(k-1)*max(0,min(15,settings['spread']))*(1-mcp/95)
        pb=rig.pose.bones['finger%d.'%k+label]
        pb.rotation_quaternion=Quaternion((0,0,1),math.radians(spread))@Quaternion((1,0,0),math.radians(mcp))
        hinge('finger%d_mid.'%k+label,pip,100)
        hinge('finger%d_tip.'%k+label,.65*pip,70)
    sweep,abduction,twist,mcp,ip=settings['thumb']
    sweep=max(0,min(65,sweep));abduction=max(0,min(45,abduction));twist=max(0,min(65,twist))
    rig.pose.bones['thumb_cmc.'+label].rotation_quaternion=(
        Quaternion((0,0,1),math.radians(inner*sweep)) @
        Quaternion((1,0,0),math.radians(abduction)) @
        Quaternion((0,1,0),math.radians(-inner*twist)))
    hinge('thumb.'+label,mcp,60);hinge('thumb_tip.'+label,ip,70)

def mechanics_demo(u):
    # Hold each configuration briefly; interpolate actual joint angles.
    stages=[(0,'open'),(.12,'open'),(.27,'relaxed'),(.43,'hook'),(.55,'hook'),(.70,'opposition'),(.81,'opposition'),(.94,'open'),(1,'open')]
    for (a,pa),(b,pb) in zip(stages,stages[1:]):
        if a<=u<=b:
            t=(u-a)/(b-a);t=t*t*(3-2*t)
            return blend_hand(HAND_POSES[pa],HAND_POSES[pb],t)
    return HAND_POSES['open']
