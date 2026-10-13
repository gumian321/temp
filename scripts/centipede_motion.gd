extends RefCounted
## Persistent followers travel behind the head. Display sway never enters the
## physical chain, so a turn cannot swing the entire tail around a fresh angle.
const MAX_STEP = 1.0 / 120.0
const TRAIL_STEP = 4.0
const TURN_SPEED = 6.0
const TURN_RESPONSE = 40.0
const TURN_GAIN = 10.0
const MAX_BEND = 0.72
var turn_rate = 0.0
var phase = 0.0
var activity = 0.0
var elapsed = 0.0
var spine: Array[float] = []
var route: Array[float] = []
var centers: Array[Vector2] = []
var orientations: Array[float] = []
var anchor = Vector2.ZERO

func reset():
	turn_rate = 0.0
	phase = 0.0
	activity = 0.0
	elapsed = 0.0
	spine.clear()
	route.clear()
	centers.clear()
	orientations.clear()

func ensure_length(body):
	# Destruction shortens the chain; discard the old tail's solver state.
	var length = body.segment_count()
	if centers.size()>length:
		spine.resize(length);route.resize(length);centers.resize(length);orientations.resize(length)
	if centers.is_empty(): anchor = body.head
	# Explicit teleports/reset fixtures move the whole chain; ordinary movement
	# advances followers in advance(), rather than translating them with the head.
	var relocation: Vector2 = body.head - anchor
	if relocation.length_squared() > 0.000001:
		for i in centers.size(): centers[i] += relocation
	anchor = body.head
	while spine.size() < body.segment_count():
		var angle = body.facing.angle() if spine.is_empty() else spine.back()
		spine.append(angle)
		route.append(angle)
		orientations.append(angle)
		var leader: Vector2 = body.head if centers.is_empty() else centers.back()
		centers.append(leader - Vector2.from_angle(angle) * body.body_spacing)

func step(body, dt: float, direction: Vector2, speed: float):
	ensure_length(body)
	# Substeps make response and curvature consistent at 30/60/120 Hz. Limit
	# catch-up after a stalled frame, rather than teleporting through the world.
	var remaining = clampf(dt, 0.0, 0.1)
	while remaining > 0.000001:
		var tick = minf(remaining, MAX_STEP)
		advance(body, tick, direction.limit_length(), speed)
		remaining -= tick

func advance(body, dt: float, direction: Vector2, speed: float):
	elapsed += dt
	var moving = direction.length_squared() > 0.0001
	var heading = body.facing.angle()
	if moving:
		var error = angle_difference(heading, direction.angle())
		# Keep the same turning side at an exact reversal, including across -PI/PI.
		if absf(error) > PI - 0.02 and absf(turn_rate) > 0.1:
			error = absf(error) * signf(turn_rate)
		# Critically damped steering eases into alignment without a hard angular
		# stop, and retains momentum when the player changes direction mid-turn.
		var desired_rate = clampf(error * TURN_GAIN, -TURN_SPEED, TURN_SPEED)
		turn_rate = lerpf(turn_rate, desired_rate, 1.0 - exp(-TURN_RESPONSE * dt))
		heading += turn_rate * dt
	else:
		turn_rate = 0.0
	body.facing = Vector2.from_angle(heading)
	var target_speed = speed * direction.length()
	var current_speed = move_toward(body.velocity.length(), target_speed, speed * (6.0 if moving else 10.0) * dt)
	body.velocity = body.facing * current_speed
	body.input_velocity = body.velocity / maxf(speed, 1.0)
	body.engine_power = speed
	body.head += body.velocity * dt
	if current_speed > 0.001:
		record_trail(body)
	activity = move_toward(activity, current_speed / maxf(speed, 1.0), dt * 5.0)
	phase = fmod(phase + lerpf(1.8, 6.4, activity) * dt, TAU)
	var leader: Vector2 = body.head
	for i in range(spine.size()):
		# Project from each follower's previous world position. The bend travels
		# down the body instead of every shell rebuilding from head-relative angles.
		var tangent: Vector2 = centers[i].direction_to(leader)
		var next = tangent.angle()
		centers[i] = leader - Vector2.from_angle(next) * body.body_spacing
		spine[i] = next
		route[i] = next
		leader = centers[i]
	# Shells face the tangent through their centers, rather than the rigid link
	# ahead of them. A quickly turning head can lead without pulling the neck's
	# center around an artificial angular limit and whipping the following body.
	var previous = heading
	for i in spine.size():
		var behind = spine[mini(i+1,spine.size()-1)]
		var target = lerp_angle(spine[i],behind,0.5)
		if i==0: target=lerp_angle(target,heading,0.25)
		var next = lerp_angle(orientations[i],target,1.0-exp(-18.0*dt))
		orientations[i] = previous+clampf(angle_difference(previous,next),-MAX_BEND,MAX_BEND)
		previous = orientations[i]
	anchor = body.head

func record_trail(body):
	body.history[0] = body.head
	var anchor: Vector2 = body.history[1]
	var distance = anchor.distance_to(body.head)
	while distance >= TRAIL_STEP:
		anchor = anchor.move_toward(body.head, TRAIL_STEP)
		body.history.insert(1, anchor)
		distance -= TRAIL_STEP
	while body.history.size() > 2400:
		body.history.pop_back()

func poses(body) -> Array:
	ensure_length(body)
	var result: Array = [{"point": body.head, "direction": body.facing}]
	var point: Vector2 = body.head
	var previous = body.facing.angle()
	for i in range(body.segment_count()):
		var onset = smoothstep(0.0, 3.0, float(i + 1))
		var wave = sin(phase - (i + 1) * 0.9) * lerpf(0.045, 0.075, activity) * onset * smoothstep(0.0, 0.4, elapsed)
		point -= Vector2.from_angle(spine[i]+wave)*body.body_spacing
		var angle = previous+clampf(angle_difference(previous,orientations[i]+wave),-0.82,0.82)
		var direction = Vector2.from_angle(angle)
		result.append({"point": point, "direction": direction})
		previous = angle
	return result
