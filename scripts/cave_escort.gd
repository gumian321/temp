extends RefCounted
## A convoy follows the player's physically travelled tunnel, one hull at a
## time. A wide open-space formation cannot be swept through a cave as a disc.
const SPACING=52.0
const FOLLOW_GAP=64.0
const SAMPLE_STEP=8.0
const MAX_POINTS=2048
var world
var player
var speed=72.0
var follow_range=600.0
var radius=15.0
var route:Array[Vector3]=[]
var first=0
var connected=false
var reconnect_left=0.0
var goal_queued=false
var status="ready"
var start_distance=1.0

func point(entry:Vector3)->Vector2:return Vector2(entry.x,entry.y)

func append_point(at:Vector2)->bool:
	if route.size()-first>=MAX_POINTS:return false
	var distance=0.0 if route.is_empty() else route.back().z+point(route.back()).distance_to(at)
	if not route.is_empty() and distance-route.back().z<.01:return true
	route.append(Vector3(at.x,at.y,distance))
	return true

func segment(distance:float)->int:
	var low=first;var high=route.size()-1
	while low+1<high:
		var middle=(low+high)/2
		if route[middle].z<=distance:low=middle
		else:high=middle
	return low

func position_at(distance:float)->Vector2:
	if route.size()==1 or distance<=route[first].z:return point(route[first])
	if distance>=route.back().z:return point(route.back())
	var index=segment(distance)
	return point(route[index]).lerp(point(route[index+1]),inverse_lerp(route[index].z,route[index+1].z,distance))

func setup(terrain,body,ships:Array,data:Dictionary,goal:Vector2):
	world=terrain;player=body
	route.clear();first=0;connected=false;goal_queued=false;reconnect_left=0;status="ready"
	speed=float(data.movingSpeed)*48;follow_range=float(data.disFromPlayerToMove)*48
	for ship in ships:radius=maxf(radius,float(ship.radius))
	var trail:Array[Vector2]=[]
	var needed=maxf(1,ships.size()-1)*SPACING
	# Try four small, local folded tails. Every seed segment receives the same
	# physical clearance check as subsequent movement; no formation-sized scan.
	for forward in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
		var origin=player.head-forward*FOLLOW_GAP
		if not world.clear_segment(player.head,origin,radius+2):origin=player.head
		var candidate:Array[Vector2]=[];var length=0.0
		for at in world.initial_trail(origin,forward):
			if world.blocked(at,radius+2):break
			if not candidate.is_empty():
				if not world.clear_segment(candidate.back(),at,radius+2):break
				length+=candidate.back().distance_to(at)
			candidate.append(at)
			if length>=needed+SAMPLE_STEP:break
		if candidate.size()>trail.size():trail=candidate
		if length>=needed:trail=candidate;break
	if trail.is_empty():trail.append(player.head)
	for i in range(trail.size()-1,-1,-1):append_point(trail[i])
	var head_distance=route.back().z
	for i in ships.size():
		var ship=ships[i]
		ship.escort_distance=maxf(route[first].z,head_distance-i*SPACING)
		ship.position=position_at(ship.escort_distance);ship.ground_previous=ship.position
		ship.offset=ship.position-ships[0].position
	connected=world.clear_segment(point(route.back()),player.head,radius+2)
	if connected:append_point(player.head)
	start_distance=maxf(1,Vector2(ships[0].position).distance_to(goal)) if not ships.is_empty() else 1

func reconnect(leader:Dictionary)->bool:
	# Returning from a detour or teleport must not draw a straight shortcut
	# through rock. Test this only on reconnect, at most four times a second.
	if not world.clear_segment(leader.position,player.head,radius+2):return false
	var distance=float(leader.escort_distance)
	var at=position_at(distance)
	var index=segment(distance)
	route.resize(index+1)
	append_point(at);append_point(player.head)
	goal_queued=false
	return true

func advance(ship:Dictionary,limit:float,dt:float):
	var budget=maxf(0,speed*dt)
	var distance=float(ship.escort_distance)
	var expected=position_at(distance)
	if Vector2(ship.position).distance_to(expected)>.25:
		ship.position=world.move(ship.position,Vector2(ship.position).move_toward(expected,budget),ship.radius)
		ship.ground_previous=ship.position
		return
	# Usually one or two short segments; the cap also bounds a stalled frame.
	for leg in 32:
		if budget<=.001 or distance>=limit-.001:break
		var index=segment(distance+.001)
		if index+1>=route.size():break
		var next_distance=minf(limit,minf(route[index+1].z,distance+budget))
		var desired=position_at(next_distance)
		var before:Vector2=ship.position
		ship.position=world.move(before,desired,ship.radius)
		var fraction=clampf((Vector2(ship.position)-before).dot(desired-before)/maxf(.000001,before.distance_squared_to(desired)),0,1)
		var used=(next_distance-distance)*fraction
		distance+=used;budget-=used
		if Vector2(ship.position).distance_to(before)>.001:ship.angle=before.direction_to(ship.position).angle()
		if fraction<.999:break
	ship.escort_distance=distance;ship.ground_previous=ship.position

func step(dt:float,ships:Array,goal:Vector2)->Vector2:
	if ships.is_empty():return Vector2.ZERO
	var leader:Dictionary=ships[0]
	var previous:Vector2=leader.position
	reconnect_left=maxf(0,reconnect_left-dt)
	if previous.distance_to(player.head)>=follow_range:
		connected=false;status="far"
		return previous
	if not connected and reconnect_left<=0:
		reconnect_left=.25;connected=reconnect(leader)
	if not connected:
		status="regroup";return previous
	if not goal_queued:
		var last=point(route.back());var delta=last.distance_to(player.head)
		if delta>128:
			connected=false;status="regroup";return previous
		if delta>=SAMPLE_STEP and not append_point(player.head):
			connected=false;status="regroup";return previous
		if player.head.distance_to(goal)<120 and point(route.back()).distance_to(goal)<256 and world.clear_segment(point(route.back()),goal,radius+2):
			goal_queued=append_point(goal)
	var target_distance=maxf(float(leader.escort_distance),route.back().z-(0 if goal_queued else FOLLOW_GAP))
	advance(leader,target_distance,dt)
	for i in range(1,ships.size()):advance(ships[i],maxf(float(ships[i].escort_distance),float(leader.escort_distance)-i*SPACING),dt)
	status="arriving" if goal_queued else ("moving" if previous.distance_to(leader.position)>.001 else "ready")
	if target_distance>float(leader.escort_distance)+1 and previous.distance_to(leader.position)<.001:status="blocked"
	var minimum=float(ships.back().escort_distance)-SAMPLE_STEP
	while first+1<route.size() and route[first+1].z<minimum:first+=1
	if first>128:route=route.slice(first);first=0
	return leader.position
