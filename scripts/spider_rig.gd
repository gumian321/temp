extends RefCounted
## Simulation-owned, world-space planted feet. Rendering only reads this rig.
const GROUPS = [[0, 3, 4, 7], [1, 2, 5, 6]]
const BASE_LENGTH = 80.0
const MODULE_LENGTH = 30.0
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

func reset(player = null):
	legs.clear()
	_active_group = -1
	_next_group = 0
	_settle = 0.0
	_serial = -1
	_speed = 0.0
	_turn_speed = 0.0
	if player != null: ensure(player)

func ensure(player):
	if legs.size() == 8: return
	_head = player.head
	_angle = player.facing.angle()
	_serial = int(player.character_reset_serial)
	for index in range(8):
		var length = BASE_LENGTH + MODULE_LENGTH * clampi(player.spider_leg_count(index), 0, 4)
		var hip = _hip(index, _head, _angle)
		var foot = _neutral(index, hip, _angle, length)
		legs.append({"hip": hip, "knee": hip, "foot": foot,
			"points": PackedVector2Array(), "lift": 0.0, "stepping": false,
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
	return center + Vector2(31.0 - pair * 8.0, side * [11.0, 16.0, 18.0, 18.0][pair]).rotated(angle)

func _neutral(index: int, hip: Vector2, angle: float, length: float) -> Vector2:
	var spread = [0.62, 1.20, 1.94, 2.54][index / 2]
	var side = -1.0 if index % 2 == 0 else 1.0
	return hip + Vector2.from_angle(angle + spread * side) * length * lerpf(0.59, 0.35, clampf((_speed - 120.0) / 300.0, 0.0, 1.0))

func _tick(player, dt: float, velocity: Vector2):
	_speed = velocity.length()
	_settle = maxf(0.0, _settle - dt)
	for index in range(8):
		var leg: Dictionary = legs[index]
		leg.target_length = BASE_LENGTH + MODULE_LENGTH * clampi(player.spider_leg_count(index), 0, 4)
		leg.length = move_toward(leg.length, leg.target_length, 105.0 * dt)
		leg.hip = _hip(index, _head, _angle)
	if _active_group >= 0:
		var finished = true
		for index in GROUPS[_active_group]:
			var leg: Dictionary = legs[index]
			leg.progress = minf(1.0, leg.progress + dt / leg.duration)
			var t: float = leg.progress
			var eased = t * t * (3.0 - 2.0 * t)
			leg.foot = leg.start.lerp(leg.target, eased)
			leg.lift = sin(t * PI)
			leg.stepping = t < 1.0
			if leg.stepping: finished = false
			else:
				leg.foot = leg.target
				leg.lift = 0.0
				leg.plant_angle = _angle
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

func _urgency(group: int) -> float:
	var result = 0.0
	for index in GROUPS[group]:
		var leg: Dictionary = legs[index]
		var neutral = _neutral(index, leg.hip, _angle, leg.length)
		result = maxf(result, leg.foot.distance_to(neutral) / maxf(10.0, leg.length * 0.16))
		result = maxf(result, absf(angle_difference(leg.plant_angle, _angle)) / 0.40)
	return result

func _begin_group(group: int, velocity: Vector2):
	_active_group = group
	var duration = lerpf(0.13, 0.055, clampf(velocity.length() / 420.0, 0.0, 1.0))
	for index in GROUPS[group]:
		var leg: Dictionary = legs[index]
		leg.start = leg.foot
		var lead = (velocity * duration * 0.95).limit_length(leg.length * 0.32)
		var predicted_angle = _angle + clampf(_turn_speed * duration * 0.8, -0.30, 0.30)
		leg.target = _neutral(index, leg.hip, predicted_angle, leg.length) + lead
		leg.progress = 0.0
		leg.duration = duration
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
	var elbow = -side if index < 4 else side
	leg.knee = leg.hip + direction * projection + direction.orthogonal() * bend * elbow
	leg.points = PackedVector2Array([leg.hip, leg.knee, leg.foot])
	leg.visual_points = PackedVector2Array([leg.hip, leg.knee + Vector2.UP * leg.lift * 5.0, leg.foot + Vector2.UP * leg.lift * 10.0])

func mount_pose(mount: int) -> Dictionary:
	if legs.size() != 8 or mount < 1 or mount > 32:
		return {"point": _head, "direction": Vector2.from_angle(_angle)}
	var index = (mount - 1) % 8
	var depth = (mount - 1) / 8
	var leg: Dictionary = legs[index]
	var visual: PackedVector2Array = leg.visual_points
	var upper: Vector2 = visual[1] - visual[0]
	var lower: Vector2 = visual[2] - visual[1]
	var path_length = upper.length() + lower.length()
	# Fixed intervals grow outward on the same articulated leg, never on the torso.
	var travel = minf(37.0 + depth * 41.0, path_length * 0.92)
	if travel <= upper.length():
		return {"point": visual[0] + upper.normalized() * travel, "direction": upper.normalized()}
	return {"point": visual[1] + lower.normalized() * (travel - upper.length()), "direction": lower.normalized()}
