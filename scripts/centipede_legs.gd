extends RefCounted
## Visual-only articulated legs. Stance feet remain planted in world coordinates.
const UPPER=23.0
const LOWER=23.0
const STRIDE=TAU/0.075
var segments:Dictionary={}
func reset():segments.clear()
static func solve(root:Vector2,foot:Vector2,side:int)->Dictionary:
 var delta=foot-root
 var distance=clampf(delta.length(),1.0,UPPER+LOWER-.1)
 var end=root+delta.normalized()*distance
 var bend=acos(clampf((UPPER*UPPER+distance*distance-LOWER*LOWER)/(2*UPPER*distance),-1,1))
 var knee=root+Vector2.from_angle(delta.angle()+side*bend)*UPPER
 return {"root":root,"knee":knee,"foot":end,"side":side}
static func resting(phase:float)->Array:
 var result=[]
 for side in [-1,1]:
  for pair in [-1,1]:
   var u=fposmod((phase+pair*.65+(PI if side==1 else 0))/TAU,1.0)
   var x=STRIDE*.25-u*STRIDE if u<.5 else lerpf(-STRIDE*.25,STRIDE*.25,smoothstep(0,1,(u-.5)*2))
   var lift=0.0 if u<.5 else sin((u-.5)*TAU)*6
   var root=Vector2(pair*12,side*19)
   result.append(solve(root,root+Vector2(x,side*(30-lift)),side))
 return result
func step(player,dt:float):
 for index in range(1,player.segment_count()+1):
  var pose=player.segment_pose(index);var point:Vector2=pose.point;var angle=Vector2(pose.direction).angle()
  if not segments.has(index):segments[index]={"point":point,"phase":-index*.8,"legs":[],"poses":[]}
  var state=segments[index];var travelled=point.distance_to(state.point)
  if travelled>100:state.legs.clear();travelled=0
  state.phase+=travelled*.075;state.point=point;state.poses=[]
  var slot=0
  for side in [-1,1]:
   for pair in [-1,1]:
    var u=fposmod((state.phase+pair*.65+(PI if side==1 else 0))/TAU,1.0)
    var root=Vector2(pair*12,side*19)
    var root_world=point+root.rotated(angle)
    var landing=point+(root+Vector2(STRIDE*.25,side*30)).rotated(angle)
    if state.legs.size()<=slot:
     var nominal=resting(state.phase)[slot].foot
     var initial=point+nominal.rotated(angle)
     state.legs.append({"foot":initial,"start":initial,"u":u,"recovery":0.0})
    var leg=state.legs[slot]
    if u>=.5 and leg.u<.5:leg.start=leg.foot
    if u<.5 and leg.u>=.5:leg.foot=landing
    if u>=.5:
     var t=(u-.5)*2
     leg.foot=Vector2(leg.start).lerp(landing,smoothstep(0,1,t))-Vector2(0,side*sin(t*PI)*6).rotated(angle)
    # A tight turn can put a planted foot beyond reach. Lift/replant it over
    # several frames instead of teleporting a joint or stretching the sprite.
    if leg.recovery<=0 and root_world.distance_to(leg.foot)>44:
     leg.recovery=.14;leg.start=leg.foot
    if leg.recovery>0:
     leg.recovery=maxf(0,leg.recovery-dt)
     var t=1-leg.recovery/.14
     var target=point+(root+Vector2(4,side*30)).rotated(angle)
     leg.foot=Vector2(leg.start).lerp(target,smoothstep(0,1,t))-Vector2(0,side*sin(t*PI)*5).rotated(angle)
    leg.u=u
    var local=(Vector2(leg.foot)-point).rotated(-angle)
    state.poses.append(solve(root,local,side));slot+=1
 for key in segments.keys():
  if key>player.segment_count():segments.erase(key)
func poses(index:int)->Array:return segments.get(index,{}).get("poses",[])
