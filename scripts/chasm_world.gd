extends RefCounted
## One world-space definition for the painted pits, swept collisions and AI routes.
## Coordinates trace the lip in the original PNG, before its atlas crop.
const SIZE = Vector2(780,520)
const CROP = Rect2(25,11,1494,998)
const OPENING = [Vector2(-790,-280),Vector2(-860,450),Vector2(910,-340),Vector2(940,630),Vector2(-140,-840)]
const LIP = [Vector2(258,600),Vector2(295,526),Vector2(360,454),Vector2(452,415),Vector2(583,393),Vector2(696,361),Vector2(799,277),Vector2(957,210),Vector2(1060,183),Vector2(1188,216),Vector2(1306,297),Vector2(1383,374),Vector2(1366,449),Vector2(1311,539),Vector2(1200,580),Vector2(1138,604),Vector2(1050,682),Vector2(946,743),Vector2(829,788),Vector2(718,807),Vector2(618,810),Vector2(523,776),Vector2(458,738),Vector2(383,722),Vector2(308,679)]
const SKIN = 0.4
var cache: Dictionary = {}

func shape(key: String, at: Vector2, scale_value: float, angle: float) -> Dictionary:
	if cache.has(key): return cache[key]
	var points = PackedVector2Array()
	for point in LIP: points.append(at + (((point-CROP.position)/CROP.size-Vector2(.5,.5))*SIZE*scale_value).rotated(angle))
	# The small inward chips in the painted lip stay inside a conservative hull.
	var polygon = Geometry2D.convex_hull(points)
	if polygon[0].is_equal_approx(polygon[polygon.size()-1]): polygon.resize(polygon.size()-1)
	var center = Vector2.ZERO
	for point in polygon: center += point
	center /= polygon.size()
	var bounds = Rect2(polygon[0],Vector2.ZERO)
	var normals = PackedVector2Array()
	for i in polygon.size():
		bounds = bounds.expand(polygon[i])
		var edge = polygon[(i+1)%polygon.size()]-polygon[i]
		var normal = Vector2(edge.y,-edge.x).normalized()
		if normal.dot(polygon[i]-center)<0: normal=-normal
		normals.append(normal)
	var miter = 1.0
	for i in normals.size():
		var before: Vector2 = normals[(i+normals.size()-1)%normals.size()]
		miter=maxf(miter,(before+normals[i]).length()/maxf(.01,1.0+before.dot(normals[i])))
	var result = {"id":key,"at":at,"scale":scale_value,"angle":angle,"polygon":polygon,"normals":normals,"bounds":bounds,"miter":miter}
	# Infinite terrain uses a bounded geometry cache; definitions are deterministic.
	if cache.size()>=256: cache.erase(cache.keys()[0])
	cache[key] = result
	return result

func nearby(area: Rect2) -> Array:
	var result: Array = []
	var search = area.grow(620)
	for i in OPENING.size():
		if search.has_point(OPENING[i]): result.append(shape("opening:%d"%i,OPENING[i],1.0+(i%3)*.12,float(i)*1.13))
	var low = ((search.position-Vector2(430,270))/1450).floor()
	var high = ((search.end-Vector2(430,270))/1450).floor()
	for y in range(int(low.y),int(high.y)+1):
		for x in range(int(low.x),int(high.x)+1):
			var point = Vector2(x,y)*1450+Vector2(430,270)
			if point.length()<1850: continue
			var seed_value = absi(x*73856093 ^ y*19349663)
			if seed_value%3==0: continue
			result.append(shape("%d:%d"%[x,y],point,.85+(seed_value%5)*.09,float(seed_value%17)*.23))
	return result

func contains(pit: Dictionary, point: Vector2, radius: float) -> bool:
	if not Rect2(pit.bounds).grow(radius*float(pit.miter)+SKIN).has_point(point): return false
	for i in pit.polygon.size():
		if Vector2(pit.normals[i]).dot(point-pit.polygon[i])>radius: return false
	return true

func blocked(point: Vector2, radius: float = 0.0) -> bool:
	for pit in nearby(Rect2(point,Vector2.ZERO).grow(radius)):
		if contains(pit,point,radius): return true
	return false

func safe_position(point: Vector2, radius: float) -> Vector2:
	return safe_among(point,radius,nearby(Rect2(point,Vector2.ZERO).grow(radius*2)))

func safe_among(point: Vector2, radius: float, pits: Array) -> Vector2:
	var result = point
	for iteration in 12:
		var changed = false
		for pit in pits:
			if not contains(pit,result,radius): continue
			var depth = INF
			var outward = Vector2.ZERO
			for i in pit.polygon.size():
				var normal: Vector2 = pit.normals[i]
				var distance = radius-normal.dot(result-pit.polygon[i])
				if distance<depth: depth=distance;outward=normal
			result += outward*(depth+SKIN)
			changed = true
		if not changed: break
	return result

func sweep(pit: Dictionary, start: Vector2, delta: Vector2, radius: float) -> Dictionary:
	if not Rect2(pit.bounds).grow(radius*float(pit.miter)+SKIN).intersects(Rect2(start,Vector2.ZERO).expand(start+delta).grow(SKIN)): return {}
	var enter = 0.0
	var leave = 1.0
	var normal = Vector2.ZERO
	for i in pit.polygon.size():
		var n: Vector2 = pit.normals[i]
		var gap = n.dot(start-pit.polygon[i])-radius
		var speed = n.dot(delta)
		if absf(speed)<.000001:
			if gap>0: return {}
			continue
		var t = -gap/speed
		if speed<0:
			if t>=enter: enter=t;normal=n
		else: leave=minf(leave,t)
		if enter>leave: return {}
	if enter<0 or enter>1 or normal.is_zero_approx(): return {}
	return {"time":enter,"normal":normal,"pit":pit}

func first_hit(start: Vector2, end: Vector2, radius: float, pits: Array) -> Dictionary:
	var closest: Dictionary = {}
	for pit in pits:
		var hit = sweep(pit,start,end-start,radius)
		if not hit.is_empty() and (closest.is_empty() or hit.time<closest.time): closest=hit
	return closest

func clear_segment(start: Vector2, end: Vector2, radius: float = 0.0) -> bool:
	var pits = nearby(Rect2(start,Vector2.ZERO).expand(end).grow(radius))
	for pit in pits:
		if contains(pit,start,radius) or contains(pit,end,radius): return false
	return first_hit(start,end,radius,pits).is_empty()

func move(start: Vector2, desired: Vector2, radius: float) -> Vector2:
	var pits = nearby(Rect2(start,Vector2.ZERO).expand(desired).grow(radius*2))
	var point = safe_among(start,radius,pits)
	var delta = desired-start
	for slide in 4:
		if delta.length_squared()<.000001: break
		var hit = first_hit(point,point+delta,radius,pits)
		if hit.is_empty(): point+=delta;break
		var travel = maxf(0,float(hit.time)-SKIN/maxf(delta.length(),SKIN))
		point += delta*travel
		delta *= 1.0-travel
		var normal: Vector2 = hit.normal
		delta -= normal*minf(0,delta.dot(normal))
	return point

func outline(pit: Dictionary, radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in pit.polygon.size():
		var before: Vector2 = pit.normals[(i+pit.polygon.size()-1)%pit.polygon.size()]
		var after: Vector2 = pit.normals[i]
		points.append(pit.polygon[i]+(before+after)*(radius/maxf(.01,1.0+before.dot(after))))
	return points

func direction(origin: Vector2, target: Vector2, radius: float, memory: Dictionary) -> Vector2:
	# Reuse a verified route between short movements; physical sweeps still run
	# every tick. No per-frame path rebuild for each member of a large swarm.
	if memory.has("ground_waypoint") and memory.get("ground_probe_radius",-1.0)==radius:
		var waypoint: Vector2 = memory.ground_waypoint
		if origin.distance_squared_to(memory.ground_probe_origin)<24*24 and target.distance_squared_to(memory.ground_probe_target)<48*48 and origin.distance_squared_to(waypoint)>12*12:
			return origin.direction_to(waypoint)
	# A knockback can leave a unit just outside the physical lip, but inside
	# the navigation clearance. Plan from that clearance so it can escape.
	var goal = origin+(target-origin).limit_length(2200)
	var pits = nearby(Rect2(origin,Vector2.ZERO).expand(goal).grow(radius*2+16))
	var start = safe_among(origin,radius+4,pits)
	if start.distance_squared_to(target)<1: return Vector2.ZERO
	goal = safe_among(goal,radius+8,pits)
	var hit = first_hit(start,goal,radius+2,pits)
	if hit.is_empty():
		memory.erase("ground_path")
		return remember_direction(origin,target,goal,radius,memory)
	var path: Array = memory.get("ground_path",[])
	if Vector2(memory.get("ground_goal",goal)).distance_squared_to(goal)>96*96: path=[]
	while not path.is_empty() and start.distance_squared_to(path[0])<12*12: path.pop_front()
	if not path.is_empty() and not first_hit(start,path[0],radius+2,pits).is_empty(): path=[]
	if path.is_empty():
		var points = outline(hit.pit,radius+14)
		var best = INF
		# Follow either side of this convex lip; choose the shorter visible arc.
		for i in points.size():
			if not first_hit(start,points[i],radius+2,pits).is_empty(): continue
			for side in [-1,1]:
				var candidate: Array = []
				var length = start.distance_to(points[i])
				for step in points.size():
					var j = posmod(i+step*side,points.size())
					if step>0: length+=Vector2(candidate.back()).distance_to(points[j])
					candidate.append(points[j])
					if first_hit(points[j],goal,radius+2,pits).is_empty():
						var total = length+points[j].distance_to(goal)
						if total<best: best=total;path=candidate.duplicate()
						break
		memory.ground_goal=goal
		memory.ground_path=path
	if not path.is_empty():return remember_direction(origin,target,path[0],radius,memory)
	memory.erase("ground_waypoint")
	return start.direction_to(goal)

func remember_direction(origin: Vector2, target: Vector2, waypoint: Vector2, radius: float, memory: Dictionary) -> Vector2:
	memory.ground_probe_origin=origin;memory.ground_probe_target=target
	memory.ground_waypoint=waypoint;memory.ground_probe_radius=radius
	return origin.direction_to(waypoint)
