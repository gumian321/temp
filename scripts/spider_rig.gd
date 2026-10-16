extends RefCounted
## Simulation-owned, world-space planted feet. Rendering only reads this rig.
const GROUPS = [[0, 3, 4, 7], [1, 2, 5, 6]]
const BASE_LENGTH = 66.0
const CLAW_LENGTH = 28.0
const CONNECTOR_LENGTH = BASE_LENGTH - CLAW_LENGTH
const MODULE_LENGTH = 54.0
const MAX_STEP = 1.0 / 120.0
var legs: Array = []
var _head = Vector2.ZERO
var _angle = 0.0
var _serial = -1
var _active_group = -1
var _next_group = 0
var _settle = 0.0
var _speed = 0.0
var _turn_speed = 0.0
var _individual_gait = false

func reset(player = null):
	legs.clear()
	_active_group = -1
	_next_group = 0
	_settle = 0.0
	_serial = -1
	_speed = 0.0
	_turn_speed = 0.0
	_individual_gait = false
	if player != null: ensure(player)

func ensure(player):
	if legs.size() == 8:
		# Assembly changes geometry immediately, without advancing a planted gait.
		for index in range(8):
			var count = clampi(player.spider_leg_count(index), 0, 4)
			if int(legs[index].module_count) != count:
				legs[index].module_count = count
				legs[index].target_length = BASE_LENGTH + MODULE_LENGTH * count
				_solve(index)
		return
	_head = player.head
	_angle = player.facing.angle()
	_serial = int(player.character_reset_serial)
	for index in range(8):
		var length = BASE_LENGTH + MODULE_LENGTH * clampi(player.spider_leg_count(index), 0, 4)
		var hip = _hip(index, _head, _angle)
		var foot = _neutral(index, hip, _angle, length)
		legs.append({"index": index, "hip": hip, "knee": hip, "foot": foot,
			"points": PackedVector2Array(), "lift": 0.0, "stepping": false,
			"module_count": clampi(player.spider_leg_count(index), 0, 4), "segments": [],
			"length": length, "target_length": length, "start": foot, "target": foot,
			"progress": 0.0, "duration": 0.16, "plant_angle": _angle})
		_solve(index)

func step(player, dt: float):
	ensure(player)
	if dt <= 0.0 or not is_finite(dt): return
	if _serial != int(player.character_reset_serial) or _head.distance_to(player.head) > 400.0:
		reset(player)
		return
	# Substeps make gait transitions insensitive to render rate and large frame deltas.
	dt = minf(dt, 0.1)
	var count = maxi(1, ceili(dt / MAX_STEP))
	var origin = _head
	var angle = _angle
	var destination: Vector2 = player.head
	var heading: float = player.facing.angle()
	var velocity: Vector2 = ((destination - origin) / dt).limit_length(600.0)
	_turn_speed = clampf(angle_difference(angle, heading) / dt, -10.0, 10.0)
	for substep in range(count):
		var t = float(substep + 1) / count
		_head = origin.lerp(destination, t)
		_angle = lerp_angle(angle, heading, t)
		_tick(player, dt / count, velocity)

func _hip(index: int, center: Vector2, angle: float) -> Vector2:
	var pair = index / 2
	var side = -1.0 if index % 2 == 0 else 1.0
	return center + Vector2(31.0 - pair * 18.0, side * [11.0, 16.0, 18.0, 18.0][pair]).rotated(angle)

func _neutral(index: int, hip: Vector2, angle: float, length: float) -> Vector2:
	var spread = [0.62, 1.20, 1.94, 2.54][index / 2]
	var side = -1.0 if index % 2 == 0 else 1.0
	# Long equipped legs open their fan instead of stacking their armor at knees.
	var equipped = clampf((length - BASE_LENGTH) / (MODULE_LENGTH * 4.0), 0.0, 1.0)
	var resting_reach = lerpf(0.59, 0.87, equipped)
	var running_reach = lerpf(0.28, 0.58, equipped)
	return hip + Vector2.from_angle(angle + spread * side) * length * lerpf(resting_reach, running_reach, clampf((_speed - 120.0) / 300.0, 0.0, 1.0))

func _tick(player, dt: float, velocity: Vector2):
	_speed = velocity.length()
	_settle = maxf(0.0, _settle - dt)
	for index in range(8):
		var leg: Dictionary = legs[index]
		leg.target_length = BASE_LENGTH + MODULE_LENGTH * clampi(player.spider_leg_count(index), 0, 4)
		leg.length = move_toward(leg.length, leg.target_length, 105.0 * dt)
		leg.hip = _hip(index, _head, _angle)
	var equipped = false
	for leg in legs: equipped = equipped or int(leg.module_count) > 0
	_individual_gait = _individual_gait or equipped
	if _individual_gait:
		# A long loaded foot must not block every short leg in its old quartet.
		# Independent contact scheduling preserves four supports at all times.
		_active_group = -1
		var airborne = 0
		for leg in legs:
			leg.rest = maxf(0.0, float(leg.get("rest", 0.0)) - dt)
			if leg.stepping: _advance_leg(leg, dt)
			if leg.stepping: airborne += 1
		while airborne < 4:
			var candidate = -1
			var priority = 1.0
			for index in 8:
				var leg: Dictionary = legs[index]
				if leg.stepping or float(leg.get("rest", 0.0)) > 0.0: continue
				var score = _leg_urgency(index)
				if index in GROUPS[_next_group]: score *= 1.08
				if score > priority:
					priority = score
					candidate = index
			if candidate < 0: break
			_begin_leg(candidate, velocity)
			_next_group = 1 if candidate in GROUPS[0] else 0
			airborne += 1
	else:
		if _active_group >= 0:
			var finished = true
			for index in GROUPS[_active_group]:
				var leg: Dictionary = legs[index]
				_advance_leg(leg, dt)
				if leg.stepping: finished = false
			if finished:
				_next_group = 1 - _active_group
				_active_group = -1
				_settle = 0.017
		elif _settle <= 0.0:
			var urgency = [_urgency(0), _urgency(1)]
			var group = _next_group
			if urgency[group] < 1.0: group = 1 - group
			if urgency[group] >= 1.0: _begin_group(group, velocity)
	for index in range(8): _solve(index)

func _advance_leg(leg: Dictionary, dt: float):
	leg.progress = minf(1.0, leg.progress + dt / leg.duration)
	var t: float = leg.progress
	var eased = t * t * (3.0 - 2.0 * t)
	if bool(leg.get("swing_arc", false)):
		var a: Vector2 = leg.start - leg.swing_center
		var b: Vector2 = leg.target - leg.swing_center
		leg.foot = leg.swing_center + Vector2.from_angle(lerp_angle(a.angle(), b.angle(), eased)) * lerpf(a.length(), b.length(), eased)
	else:
		leg.foot = leg.start.lerp(leg.target, eased)
	leg.lift = sin(t * PI)
	leg.stepping = t < 1.0
	if not leg.stepping:
		leg.foot = leg.target
		leg.lift = 0.0
		leg.plant_angle = _angle

	if not leg.stepping: leg.rest = 0.017

func _leg_urgency(index: int) -> float:
	var leg: Dictionary = legs[index]
	var neutral = _neutral(index, leg.hip, _angle, leg.length)
	var error = leg.foot.distance_to(neutral) / maxf(7.0, leg.length * 0.13)
	return maxf(error, absf(angle_difference(leg.plant_angle, _angle)) / 0.40) + maxf(0.0, leg.foot.distance_to(leg.hip) / leg.length - 0.8) * 80.0

func _urgency(group: int) -> float:
	var result = 0.0
	for index in GROUPS[group]:
		var leg: Dictionary = legs[index]
		var neutral = _neutral(index, leg.hip, _angle, leg.length)
		result = maxf(result, leg.foot.distance_to(neutral) / maxf(7.0, leg.length * 0.13))
		result = maxf(result, absf(angle_difference(leg.plant_angle, _angle)) / 0.40)
	return result

func _begin_group(group: int, velocity: Vector2):
	_active_group = group
	for index in GROUPS[group]: _begin_leg(index, velocity)

func _begin_leg(index: int, velocity: Vector2):
	var duration = lerpf(0.105, 0.035, clampf(velocity.length() / 420.0, 0.0, 1.0))
	var leg: Dictionary = legs[index]
	leg.step_serial = int(leg.get("step_serial", 0)) + 1
	leg.start = leg.foot
	var lead = (velocity * duration * 0.95).limit_length(leg.length * 0.32)
	var predicted_angle = _angle + clampf(_turn_speed * duration * 0.8, -0.30, 0.30)
	leg.target = _neutral(index, leg.hip, predicted_angle, leg.length) + lead
	if float(leg.length) > BASE_LENGTH * 1.1:
		var radial: Vector2 = leg.start - leg.hip
		var desired: Vector2 = leg.target - leg.hip
		var turn = clampf(angle_difference(radial.angle(), desired.angle()), -0.8, 0.8)
		leg.target = leg.hip + Vector2.from_angle(radial.angle() + turn) * desired.length()
	var stride: Vector2 = leg.target - leg.start
	leg.swing_center = leg.hip
	leg.swing_arc = float(leg.length) > BASE_LENGTH * 1.1
	leg.progress = 0.0
	# Cubic easing peaks at 1.5 times mean speed. Equipped legs need
	# enough real swing time to remain legible even during boosted reversals.
	var path_length = stride.length()
	if leg.swing_arc:
		var start_radial: Vector2 = leg.start - leg.swing_center
		var end_radial: Vector2 = leg.target - leg.swing_center
		var arc = absf(angle_difference(start_radial.angle(), end_radial.angle())) * maxf(start_radial.length(), end_radial.length())
		path_length = Vector2(arc, end_radial.length() - start_radial.length()).length()
	leg.duration = maxf(duration, path_length * 1.5 / 1800.0) if leg.swing_arc else duration
	leg.stepping = true
	leg.lift = 0.0

func _solve(index: int):
	var leg: Dictionary = legs[index]
	var delta: Vector2 = leg.foot - leg.hip
	var distance = maxf(delta.length(), 0.001)
	var direction = delta / distance
	
	# Emergency reach is shared evenly by both bones rather than sliding a planted
	# contact or putting all strain into the shin during abrupt boosted turns.
	leg.solved_length = maxf(leg.length, distance * 1.001)
	var half: float = leg.solved_length * 0.5
	var projection = minf(distance * 0.5, half)
	var bend = sqrt(maxf(0.0, half * half - projection * projection))
	var side = -1.0 if index % 2 == 0 else 1.0
	# Equipped chains on each side sweep the same way. Opposite bend signs
	# made the two middle legs converge into one shared-looking shaft.
	var elbow = -side
	leg.knee = leg.hip + direction * projection + direction.orthogonal() * bend * elbow
	leg.points = PackedVector2Array([leg.hip, leg.knee, leg.foot])
	leg.visual_points = PackedVector2Array([leg.hip, leg.knee + Vector2.UP * leg.lift * 5.0, leg.foot + Vector2.UP * leg.lift * 10.0])

	_solve_segments(leg)

func _scaffold_sample(leg: Dictionary, travel: float) -> Vector2:
	var visual: PackedVector2Array = leg.visual_points
	var upper: Vector2 = visual[1] - visual[0]
	var lower: Vector2 = visual[2] - visual[1]
	if travel <= upper.length(): return visual[0] + upper.normalized() * travel
	return visual[1] + lower.normalized() * minf(lower.length(), travel - upper.length())

func _solve_segments(leg: Dictionary):
	# A real serial chain: connector, N separate armor shells, terminal claw.
	# FABRIK preserves each shell's length while following the planted contact.
	var count = int(leg.module_count)
	var nominal = BASE_LENGTH + MODULE_LENGTH * count
	var stretch = float(leg.solved_length) / nominal
	var lengths: Array[float] = [CONNECTOR_LENGTH * stretch]
	for depth in range(count): lengths.append(MODULE_LENGTH * stretch)
	lengths.append(CLAW_LENGTH * stretch)
	var visual: PackedVector2Array = leg.visual_points
	var origin: Vector2 = visual[0]
	var target: Vector2 = visual[2]
	var path_length = visual[0].distance_to(visual[1]) + visual[1].distance_to(visual[2])
	var nodes = PackedVector2Array([origin])
	var travel = 0.0
	for length in lengths:
		travel += length
		nodes.append(_scaffold_sample(leg, travel / leg.solved_length * path_length))
	if count > 0:
		# Distribute the bend along all articulated shells instead of folding a
		# long serial chain over one sharp two-bone knee. A convex arc seed also
		# keeps FABRIK on one anatomical branch as the hip passes a planted foot.
		var chord: Vector2 = target - origin
		var reach = maxf(chord.length(), 0.001)
		var ratio = clampf(reach / leg.solved_length, 0.05, 0.99999)
		var lo = 0.001
		var hi = PI - 0.01
		for search in 12:
			var mid = (lo + hi) * 0.5
			if sin(mid) / mid > ratio: lo = mid
			else: hi = mid
		var theta = (lo + hi) * 0.5
		var radius = reach / (2.0 * sin(theta))
		var forward = chord / reach
		var outward = forward.orthogonal() * (1.0 if int(leg.get("index", 0)) % 2 == 0 else -1.0)
		var arc_travel = 0.0
		for joint in range(1, nodes.size()):
			arc_travel += lengths[joint - 1]
			var phi = -theta + 2.0 * theta * arc_travel / leg.solved_length
			nodes[joint] = origin + forward * (reach * 0.5 + radius * sin(phi)) + outward * (radius * (cos(phi) - cos(theta)))
	for iteration in range(16):
		nodes[-1] = target
		for joint in range(nodes.size() - 2, -1, -1):
			var direction = (nodes[joint] - nodes[joint + 1]).normalized()
			if direction == Vector2.ZERO: direction = Vector2.LEFT.rotated(_angle)
			nodes[joint] = nodes[joint + 1] + direction * lengths[joint]
		nodes[0] = origin
		for joint in range(1, nodes.size()):
			var direction = (nodes[joint] - nodes[joint - 1]).normalized()
			if direction == Vector2.ZERO: direction = Vector2.RIGHT.rotated(_angle)
			nodes[joint] = nodes[joint - 1] + direction * lengths[joint - 1]
		if nodes[-1].distance_to(target) < 0.01: break
	# The contact is authoritative even in an abrupt emergency extension.
	nodes[-1] = target
	leg.chain_points = nodes
	leg.connector = {"a": nodes[0], "b": nodes[1]}
	var segments: Array = []
	for depth in range(count):
		var a: Vector2 = nodes[depth + 1]
		var b: Vector2 = nodes[depth + 2]
		segments.append({"a": a, "b": b, "point": (a + b) * 0.5,
			"direction": (b - a).normalized(), "depth": depth})
	leg.segments = segments
	leg.claw = {"a": nodes[-2], "b": nodes[-1]}

func mount_pose(mount: int) -> Dictionary:
	if legs.size() != 8 or mount < 1 or mount > 32:
		return {"point": _head, "direction": Vector2.from_angle(_angle)}
	var index = (mount - 1) % 8
	var depth = (mount - 1) / 8
	var leg: Dictionary = legs[index]
	if depth < leg.segments.size():
		var segment: Dictionary = leg.segments[depth]
		return {"point": segment.point, "direction": segment.direction}
	# Unoccupied slots are only insertion hints, never drawn armor or mounts.
	return {"point": (Vector2(leg.claw.a) + Vector2(leg.claw.b)) * 0.5,
		"direction": (Vector2(leg.claw.b) - Vector2(leg.claw.a)).normalized()}
