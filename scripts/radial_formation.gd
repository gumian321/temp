extends RefCounted
## Shared world-space formations, independent of old construction-grid cells.
static func ring(count:int,radius:float,center:Vector2=Vector2.ZERO,phase:float=-PI*.5)->Array[Vector2]:
	var points:Array[Vector2]=[]
	for i in count:points.append(center+Vector2.from_angle(phase+TAU*i/maxi(1,count))*radius)
	return points

static func circularized(points:Array,count:int=-1)->Array[Vector2]:
	if points.is_empty():return []
	var center=Vector2.ZERO
	for point in points:center+=Vector2(point)
	center/=points.size()
	var radius=0.0
	for point in points:radius+=Vector2(point).distance_to(center)
	radius/=points.size()
	return ring(points.size() if count<0 else count,radius,center)
