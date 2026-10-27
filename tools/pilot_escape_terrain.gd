extends RefCounted
## Controller prediction only. This helper never moves an actor, digs terrain,
## modifies health/damage, or changes the simulation clock.
const SAMPLE_STEP=24.0
const STOP_SKIN=2.0

static func reachable_distance(world,start:Vector2,direction:Vector2,max_distance:float,hull_radius:float)->float:
	if max_distance<=0:return 0.0
	if world==null or not world.enabled:return max_distance
	var heading=direction.normalized()
	if heading.is_zero_approx():return 0.0
	var side=heading.orthogonal()*maxf(0,hull_radius)
	# Start may already touch rock at one hull sample. Zero reachable distance
	# is deliberate: candidate selection retains its established tie/fallback.
	var distance=0.0
	while distance<max_distance:
		var next=minf(max_distance,distance+SAMPLE_STEP)
		var at=start+heading*next
		for offset in [Vector2.ZERO,side,-side]:
			var cell=Vector2i(((at+offset)/SAMPLE_STEP).floor())
			if world.solid(cell):return maxf(0,distance-STOP_SKIN)
		distance=next
	return max_distance

static func predicted_position(world,start:Vector2,direction:Vector2,max_distance:float,hull_radius:float)->Vector2:
	return start+direction.normalized()*reachable_distance(world,start,direction,max_distance,hull_radius)
