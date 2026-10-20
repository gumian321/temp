extends RefCounted
## Persistent physical poses, keyed by module identity rather than array index.
## Reading/refreshing poses never advances the animation (including paused UI).
const ENTER_DURATION = 0.95
const EXIT_DURATION = 0.8
const FOLLOW_DELAY = 0.32
var phase = "idle"
var elapsed = 0.0
var heading = 0.0
var anchor = Vector2.ZERO
var source: Dictionary = {}
var current: Dictionary = {}
var max_speed = 0.0

func reset():
	phase = "idle"
	elapsed = 0.0
	source.clear()
	current.clear()
	max_speed = 0.0

func engaged() -> bool:
	return phase != "idle"

func begin(body, entering: bool):
	phase = "enter" if entering else "exit"
	elapsed = 0.0
	heading = body.facing.angle()
	anchor = body.head
	source.clear()
	current.clear()
	for index in body.body_part_indices():
		var p: Dictionary = body.parts[index]
		var uid = int(p.feedback_uid)
		var pose = {"point": Vector2(p.position), "direction": Vector2.from_angle(float(p.body_angle))}
		current[uid] = pose
		source[uid] = {"point": Vector2(pose.point) - body.head, "direction": pose.direction}
	# Bounds even very long chains without making their entry last past the skill.
	max_speed = maxf(360.0, body.segment_count() * body.body_spacing * 3.5 / duration())

func duration() -> float:
	return EXIT_DURATION if phase == "exit" else ENTER_DURATION

func targets(body) -> Array:
	var result: Array = []
	var angle = PI + heading
	for i in body.segment_count():
		if phase == "exit":
			result.append(body.head - Vector2.from_angle(heading) * body.body_spacing * (i + 1))
		else:
			# Approximately one shell-length along an expanding spiral per link.
			var radius = 58.0 + float(i) * 6.0
			if i > 0: angle += body.body_spacing / radius
			result.append(body.head + Vector2.from_angle(angle) * radius)
	return result

func advance(body, dt: float):
	if not engaged() or dt <= 0: return
	dt = clampf(dt, 0, 0.1)
	elapsed += dt
	var translation: Vector2 = body.head - anchor
	anchor = body.head
	var order: Array = body.body_part_indices()
	var goal = targets(body)
	var surviving: Dictionary = {}
	var settled = true
	for ordinal in order.size():
		var p: Dictionary = body.parts[order[ordinal]]
		var uid = int(p.feedback_uid)
		if not current.has(uid):
			current[uid] = {"point": Vector2(p.position), "direction": Vector2.from_angle(float(p.body_angle))}
			source[uid] = {"point": Vector2(p.position) - body.head, "direction": current[uid].direction}
		var delay = FOLLOW_DELAY * float(ordinal) / maxf(1, order.size() - 1)
		var progress = clampf((elapsed / duration() - delay) / (1.0 - delay), 0, 1)
		var eased = smoothstep(0, 1, progress)
		if body.terrain!=null: goal[ordinal]=body.terrain.safe_position(goal[ordinal],27.0)
		var desired: Vector2 = (body.head + Vector2(source[uid].point)).lerp(goal[ordinal], eased)
		var old: Vector2 = Vector2(current[uid].point) + translation
		var point = old.move_toward(desired, max_speed * dt)
		if body.terrain!=null:
			var from: Vector2 = current[uid].point
			if not body.terrain.clear_segment(from,desired,27.0):
				point=from+body.terrain.direction(from,desired,27.0,p)*minf(from.distance_to(desired),max_speed*dt)
			point=body.ground_position(from,point,27.0)
		var leader: Vector2 = body.head if ordinal == 0 else surviving[int(body.parts[order[ordinal - 1]].feedback_uid)].point
		var direction = point.direction_to(leader)
		if direction.is_zero_approx(): direction = body.facing
		var desired_angle = direction.angle()
		if phase == "exit": desired_angle = lerp_angle(Vector2(source[uid].direction).angle(), heading, eased)
		var angle = rotate_toward(Vector2(current[uid].direction).angle(), desired_angle, 12.0 * dt)
		surviving[uid] = {"point": point, "direction": Vector2.from_angle(angle)}
		if point.distance_to(goal[ordinal]) > 0.001: settled = false
		if phase == "exit" and absf(angle_difference(angle, heading)) > 0.001: settled = false
	current = surviving
	for uid in source.keys():
		if not current.has(uid): source.erase(uid)
	if elapsed + 0.000001 >= duration() and settled:
		if phase == "enter": phase = "hold"
		elif phase == "exit":
			# Seed the ordinary follower solver from the released physical chain.
			body.motion.reset()
			body.motion.ensure_length(body)
			for i in order.size():
				var pose: Dictionary = current[int(body.parts[order[i]].feedback_uid)]
				body.motion.centers[i] = pose.point
				body.motion.spine[i] = heading
				body.motion.route[i] = heading
				body.motion.orientations[i] = heading
			reset()

func poses(body) -> Array:
	var result: Array = [{"point": body.head, "direction": body.facing}]
	for index in body.body_part_indices():
		var p: Dictionary = body.parts[index]
		result.append(current.get(int(p.feedback_uid), {"point": Vector2(p.position), "direction": Vector2.from_angle(float(p.get("body_angle", heading)))}))
	return result
