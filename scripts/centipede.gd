extends RefCounted

signal parts_removing(indices: Array)

func remove_parts(indices: Array):
	var removed = indices.filter(func(i): return i > 0 and i < parts.size())
	removed.sort()
	if removed.is_empty(): return
	parts_removing.emit(removed)
	removed.reverse()
	for i in removed: parts.remove_at(i)
	refresh_positions()
	refresh_upgrades()

func fusion_multiplier(index: int) -> float:
	return pow(2.2, int(parts[index].get("fusion_level", 1)) - 1)

func attack_boost(index: int, core: Dictionary) -> float:
	return (1.0 + stats.get("14" if index == 0 else "15", 0.0) + upgrade_bonus(core.id, "DamagePercent")) * fusion_multiplier(index) - 1.0

var db
var terrain

func ground_position(start: Vector2, desired: Vector2, radius: float) -> Vector2:
	return terrain.move(start,desired,radius) if terrain!=null else desired

func move_head(desired: Vector2):
	head = ground_position(head,desired,collision_radius(0))

var head = Vector2.ZERO
var velocity = Vector2.ZERO
var facing = Vector2.RIGHT
var history: Array[Vector2] = []
var parts: Array = []
var pending: Array = []
var actions = {"move": 0, "swap": 0, "duplicate": 0, "wall": 0}
var fuel = 0.0
var fuel_delay = 0.0
var max_fuel = 0.0
var boost = false
var body_spacing = 58.0
var resting_segments = 6
var input_velocity = Vector2.ZERO
var engine_power = 0.0
var body_poses: Array = []
var build_cells: Array[Vector2i] = []
var body_cells: Array[Vector2i] = []
var stats: Dictionary = {}
var hq_weapon: String
var levels: Dictionary = {}
var last_error = ""
var built_count = 0
var built_score = 0
const RewardFeedbackState = preload("res://scripts/reward_feedback_state.gd")
var feedback_events: Array = []
var feedback_next_uid = 0

func _init(source):
	db = source
	hq_weapon = db.stores.PlayerDataStore.mainTurretCore
	prepare_build_cells()
	reset()

func reset():
	feedback_events.clear()
	feedback_next_uid = 0
	hq_weapon = db.stores.PlayerDataStore.mainTurretCore
	actions = {"move":0,"swap":0,"duplicate":0,"wall":0}
	end_support_tick()
	head = Vector2.ZERO
	velocity = Vector2.ZERO
	input_velocity = Vector2.ZERO
	engine_power = 0.0
	facing = Vector2.RIGHT
	history.clear()
	body_poses.clear()
	for i in range(2000):
		history.append(Vector2(-i * 4.0, 0))
	parts = [make_part(db.stores.PlayerDataStore.HQCore, Vector2i.ZERO)]
	body_cells.clear()
	pending.clear()
	stats.clear()
	levels.clear()
	fuel = 0.0
	max_fuel=0.0
	built_count = 0
	refresh_positions()

# Keep source blueprint coordinates for saves and legacy build validation. Their
# installation order maps to individual body segments, never a row of side pods.
func prepare_build_cells():
	var limit_x = int(db.stores.PlayerDataStore.buildingLimitX)
	var limit_y = int(db.stores.PlayerDataStore.buildingLimitY)
	for y in range(-limit_y, limit_y + 1):
		for x in range(-limit_x, limit_x + 1):
			if x in [0, 1] and y in [0, 1]:
				continue
			build_cells.append(Vector2i(x, y))
	build_cells.sort_custom(func(a: Vector2i, b: Vector2i):
		var a_distance = maxi(0, -a.x) + maxi(0, a.x - 1) + maxi(0, -a.y) + maxi(0, a.y - 1)
		var b_distance = maxi(0, -b.x) + maxi(0, b.x - 1) + maxi(0, -b.y) + maxi(0, b.y - 1)
		if a_distance != b_distance:
			return a_distance < b_distance
		return a.y < b.y if a.y != b.y else a.x < b.x)

func body_part_indices() -> Array:
	var indices = []
	var present = {}
	for i in range(1, parts.size()):
		present[parts[i].cell] = i
	var retained: Array[Vector2i] = []
	for cell in body_cells:
		if present.has(cell):
			indices.append(present[cell])
			retained.append(cell)
			present.erase(cell)
	for i in range(1, parts.size()):
		if present.has(parts[i].cell):
			indices.append(i)
			retained.append(parts[i].cell)
			present.erase(parts[i].cell)
	body_cells = retained
	return indices

func segment_index(part_index: int) -> int:
	if part_index == 0:
		return 0
	return body_part_indices().find(part_index) + 1

func segment_count() -> int:
	return maxi(resting_segments, parts.size() - 1)

func segment_pose(index: int) -> Dictionary:
	if index >= 0 and index < body_poses.size():
		return body_poses[index]
	return path_sample(maxi(0, index) * body_spacing)

func next_segment_cell() -> Vector2i:
	for cell in build_cells:
		if not occupied(cell) and can_place(cell):
			return cell
	return Vector2i.ZERO

func append_segment(id: String) -> bool:
	return add_piece(id, next_segment_cell())

func move_piece_to_segment(index: int, target_segment: int) -> bool:
	if index <= 0 or index >= parts.size() or actions.move <= 0:
		return false
	var ordered = body_part_indices()
	if target_segment < 1 or target_segment > ordered.size():
		return false
	var start = ordered.find(index)
	var destination = target_segment - 1
	if start == destination:
		return false
	var cells = ordered.map(func(i): return parts[i].cell)
	ordered.remove_at(start)
	ordered.insert(destination, index)
	for i in range(ordered.size()):
		parts[ordered[i]].cell = cells[i]
	actions.move -= 1
	refresh_positions()
	return true

func make_part(id: String, cell: Vector2i) -> Dictionary:
	var c: Dictionary = db.asset(id)
	var hp = float(c.get("CoreHealth", 90))
	feedback_next_uid += 1
	return {"feedback_uid":feedback_next_uid,"feedback_pulses":{},"id": id, "cell": cell, "hp": hp, "max_hp": hp, "cooldown": 0.0, "shield": float(c.get("maxShieldHealth",0)), "shield_broken":false, "shield_delay": 0.0, "wall": false, "position": head, "angle": 0.0, "body_angle":0.0, "active": true, "stun": 0.0}

func add_piece(id: String, cell: Vector2i) -> bool:
	if parts.size() >= int(db.stores.PlayerDataStore.maxBuiltCores) + 1:
		last_error = db.ui("Maximum parts reached", "身体已装满，最多可安装60座炮塔或模块")
		return false
	if not can_place(cell):
		return false
	body_part_indices()
	parts.append(make_part(id, cell))
	body_cells.append(cell)
	built_count += 1
	built_score += int(db.asset(id).get("coreRatePrize",0))
	refresh_upgrades()
	refresh_positions()
	last_error = ""
	emit_feedback("installed", [parts[-1].feedback_uid])
	pulse_feedback(parts.size()-1,"installed",1.2)
	return true

func occupied(cell: Vector2i, ignore: int = -1) -> bool:
	if cell in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		return true
	for i in range(1, parts.size()):
		if i != ignore and parts[i].cell == cell:
			return true
	return false

func can_place(cell: Vector2i, ignore: int = -1) -> bool:
	if abs(cell.x) > int(db.stores.PlayerDataStore.buildingLimitX) or abs(cell.y) > int(db.stores.PlayerDataStore.buildingLimitY):
		last_error = db.ui("Outside original build limits", "超出可安装范围")
		return false
	if occupied(cell, ignore):
		last_error = db.ui("Occupied cell", "这个体节已安装模块")
		return false
	for v in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if occupied(cell + v, ignore):
			return true
	last_error = db.ui("Parts must connect to the structure", "模块必须与身体相连")
	return false

func connected(ignore: int = -1) -> bool:
	var visited = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var todo = visited.duplicate()
	while not todo.is_empty():
		var at: Vector2i = todo.pop_back()
		for v in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nxt: Vector2i = at + v
			if nxt not in visited and occupied(nxt, ignore):
				visited.append(nxt)
				todo.append(nxt)
	for i in range(1, parts.size()):
		if i != ignore and parts[i].cell not in visited:
			return false
	return true

func move_piece(index: int, cell: Vector2i) -> bool:
	if index <= 0 or actions.move <= 0 or not can_place(cell, index):
		return false
	body_part_indices()
	var old: Vector2i = parts[index].cell
	parts[index].cell = cell
	if not connected():
		parts[index].cell = old
		last_error = db.ui("This move disconnects the structure", "这样移动会使后面的身体断开")
		return false
	body_cells[body_cells.find(old)] = cell
	actions.move -= 1
	refresh_positions()
	return true

func swap_piece(a: int, b: int) -> bool:
	if a <= 0 or b <= 0 or a == b or actions.swap <= 0:
		return false
	var old: Vector2i = parts[a].cell
	parts[a].cell = parts[b].cell
	parts[b].cell = old
	actions.swap -= 1
	refresh_positions()
	return true

func duplicate_piece(index: int, cell: Vector2i) -> bool:
	if index <= 0 or actions.duplicate <= 0:
		return false
	if add_piece(parts[index].id, cell):
		actions.duplicate -= 1
		return true
	return false

func reinforce(index: int) -> bool:
	if index <= 0 or index >= parts.size() or parts[index].hp <= 0 or actions.wall <= 0 or parts[index].wall:
		return false
	parts[index].wall = true
	var amount = float(db.stores.CoresDataStore.walledCoreAddedHealth)
	parts[index].max_hp += amount
	parts[index].hp += amount
	actions.wall -= 1
	emit_feedback("reinforced", [parts[index].feedback_uid])
	pulse_feedback(index,"reinforced",1.2)
	return true

func step(dt: float, direction: Vector2, wants_boost: bool):
	update_fuel_capacity()
	var speed = clampf(float(db.stores.PlayerDataStore.enginePower) * (1.0 + stats.get("11", 0.0)), 2.0, 4.0) * 48.0
	boost = wants_boost and fuel > 0.0 and direction.length() > 0.0
	if boost:
		fuel = maxf(0.0, fuel - 50.0 * dt)
		fuel_delay = 2.0
		speed += 48.0 * minf(float(db.stores.PlayerDataStore.boostEnginePower) * (1.0 + stats.get("12", 0.0)), 3.0)
	else:
		fuel_delay -= dt
		if fuel_delay <= 0.0:
			fuel = minf(max_fuel, fuel + 25.0 * dt)
	# Match PlayerMovement.cs: independent axes, then engine-power interpolation.
	# The head turns visually without steering movement away from the input.
	var acceleration = clampf(float(db.stores.PlayerDataStore.enginePower) * (1.0 + stats.get("11", 0.0)), 2.0, 4.0)
	input_velocity.x = move_toward(input_velocity.x, direction.x, acceleration * (0.25 if direction.x != 0 else 0.5) * dt)
	input_velocity.y = move_toward(input_velocity.y, direction.y, acceleration * (0.25 if direction.y != 0 else 0.5) * dt)
	engine_power = lerpf(engine_power, speed, minf(1.0, 2.0 * dt))
	velocity = input_velocity.limit_length() * engine_power
	if velocity.length() > 0.1:
		facing = Vector2.from_angle(rotate_toward(facing.angle(), velocity.angle(), 12.0 * dt))
	if velocity.length() > 0.1:
		move_head(head + velocity * dt)
		if history[0].distance_to(head) >= 3.0:
			history.push_front(head)
			if history.size() > 2400:
				history.pop_back()
	refresh_positions()

func path_sample(distance: float) -> Dictionary:
	var previous = head
	for point in history:
		var length = previous.distance_to(point)
		if length >= distance and length > 0.001:
			return {"point": previous.lerp(point, distance / length), "direction": (previous - point).normalized()}
		distance -= length
		previous = point
	return {"point": previous - facing * distance, "direction": facing}

func body_rows() -> Array:
	var rows = []
	for i in range(1, parts.size()):
		if parts[i].cell.y not in rows:
			rows.append(parts[i].cell.y)
	rows.sort()
	rows.reverse()
	return rows

func refresh_positions():
	refresh_body_poses()
	parts[0].position = head
	parts[0].body_angle = facing.angle()
	var ordered = body_part_indices()
	for i in range(ordered.size()):
		var p: Dictionary = parts[ordered[i]]
		var pose = segment_pose(i + 1)
		p.position = pose.point
		p.body_angle = pose.direction.angle()
		if not db.asset(p.id).has("coreProjectile"):p.angle=p.body_angle

func refresh_body_poses():
	var previous_poses = body_poses
	body_poses = [{"point": head, "direction": facing}]
	for index in range(1, segment_count() + 1):
		var leader: Vector2 = body_poses[index - 1].point
		var point: Vector2 = previous_poses[index].point if index < previous_poses.size() else path_sample(index * body_spacing).point
		var direction = point.direction_to(leader)
		if direction.length_squared() < 0.001: direction = body_poses[index - 1].direction
		# Rigid shell spacing permits immediate strafing and reversing without
		# folding two square mounts onto the same point of the history path.
		body_poses.append({"point": leader - direction * body_spacing, "direction": direction})

var support_tick=false
var support_indices:Array=[]
func begin_support_tick():
	support_indices = [0] + body_part_indices()
	support_tick=true
func end_support_tick():
	support_tick=false
	support_indices.clear()

# Support effects follow the visible spine, including its first connection to
# the head. Hidden blueprint cells only remain a legacy construction interface.
func adjacent_part_indices(index: int, include_self: bool = false) -> Array:
	var ordered: Array = support_indices if support_tick else [0] + body_part_indices()
	var at = ordered.find(index)
	if at < 0:
		return []
	var result = []
	for slot in range(maxi(0, at - 1), mini(ordered.size(), at + 2)):
		if include_self or slot != at:
			result.append(ordered[slot])
	return result

func chips(index: int) -> Dictionary:
	var result = {}
	if index == 0:
		return result
	var c: Dictionary = db.asset(parts[index].id)
	if not c.get("isChipable", false):
		return result
	var projectile: Dictionary = db.asset(c.get("coreProjectile", c.get("coreMine", "")))
	if c.has("coreDrone"):projectile=db.asset(db.asset(c.coreDrone).get("droneProjectile",""))
	var allowed: Array = db.packed(c.get("activatableChips",projectile.get("activatableChips", {})).get("activatedChipsList"))
	for source_index in adjacent_part_indices(index):
		var p: Dictionary = parts[source_index]
		var chip_core: Dictionary = db.asset(p.id)
		if not chip_core.has("coreChip") or p.hp <= 0:
			continue
		var chip: Dictionary = db.asset(chip_core.coreChip)
		var type = int(chip.chipType)
		if type in allowed or type == 6:
			result[type] = mini(2, int(result.get(type, 0)) + 1)
	return result

func change_stat(type: int, value: float):
	var data: Dictionary = db.stores.PlayerDataStore
	stats[str(type)] = clampf(stats.get(str(type), 0.0) + value, data.minStatsPercentage, data.maxStatsPercentage)

func blueprint() -> Array:
	var result = []
	for index in [0] + body_part_indices():
		var p: Dictionary = parts[index]
		result.append({"id": p.id, "x": p.cell.x, "y": p.cell.y, "wall": p.wall, "fusion_level":int(p.get("fusion_level",1))})
	return result

func upgrade_bonus(id: String, field: String) -> float:
	var value = 0.0
	for reward_id in levels:
		var reward: Dictionary = db.asset(reward_id)
		if id in reward.get("coresList", []) or id in reward.get("dronesList", []):
			value += float(reward.get(field, 0)) * int(levels[reward_id])
	return value

func refresh_upgrades():
	update_fuel_capacity()
	for i in range(parts.size()):
		var p: Dictionary = parts[i]
		var c: Dictionary = db.asset(p.id)
		var hp = float(c.get("CoreHealth", 90)) * (1.0 + upgrade_bonus(p.id, "CoreHealthPercent") + stats.get("10" if i == 0 else "16", 0.0))
		if p.wall: hp += float(db.stores.CoresDataStore.walledCoreAddedHealth)
		if p.hp > 0: p.hp = minf(hp, p.hp + maxf(0, hp - p.max_hp))
		p.max_hp = hp

func update_fuel_capacity():
	var capacity=0.0
	for part in parts:
		var core:Dictionary=db.asset(part.id)
		if core.get("class")=="FuelCore" and part.hp>0 and part.stun<=0:capacity+=float(core.fuelCapacity)*(1+upgrade_bonus(part.id,"TankCapacityPercent"))
	if is_equal_approx(capacity,max_fuel):return
	if capacity<max_fuel:fuel=capacity*fuel/maxf(1,max_fuel)
	elif max_fuel==0:fuel_delay=2.0
	max_fuel=capacity
	fuel=minf(fuel,max_fuel)

func detached_indices() -> Array:
	# Towers mount onto a continuous body; destroying one does not sever other
	# towers according to the old, invisible building grid.
	var detached: Array = []
	for i in range(1,parts.size()):
		if parts[i].hp<=0: detached.append(i)
	return detached

func collision_radius(index: int) -> float:
	return 30.0 if index == 0 else 20.0

func weapon_visual_scale(_index: int) -> float:
	return 1.0

func weapon_origin(index: int) -> Vector2:
	return parts[index].position

func reward_module_count(reward: Dictionary) -> int:
	return maxi(1,int(reward.get("coresCount",1)))

func uses_build_actions() -> bool:
	return true

# Stable identity survives reordering; snapshots never cache array indices.
func effective_core(index: int) -> Dictionary:
	return db.asset(hq_weapon if index == 0 else parts[index].id)

func set_hq_weapon(id: String):
	if hq_weapon == id: return
	hq_weapon = id
	var core = effective_core(0)
	parts[0].shield = float(core.get("maxShieldHealth",0)) * (1 + upgrade_bonus(id,"ShieldHealthPercent"))
	parts[0].shield_broken = false
	parts[0].shield_delay = 0.0
	parts[0].cooldown = 0.0
	parts[0].feedback_pulses.clear()

func emit_feedback(kind: String, uids: Array = [], details: Dictionary = {}):
	feedback_events.append({"kind":kind,"part_uids":uids,"details":details,"life":2.0,"status":"active","title":"","reward_id":"","reward_class":""})
	while feedback_events.size() > 64: feedback_events.pop_front()

func reward_feedback(reward: Dictionary, drones: Array = []) -> Dictionary:
	return RewardFeedbackState.describe(self,reward,drones)

func record_reward_feedback(reward: Dictionary, drones: Array = []):
	var event = reward_feedback(reward,drones)
	feedback_events.append(event)
	while feedback_events.size() > 64: feedback_events.pop_front()
	for i in range(parts.size()):
		if parts[i].feedback_uid in event.part_uids: pulse_feedback(i,"reward",1.2)

func take_feedback_events() -> Array:
	var result = feedback_events.duplicate(true)
	feedback_events.clear()
	return result

func pulse_feedback(index: int, kind: String, duration: float = 0.3):
	if index >= 0 and index < parts.size() and parts[index].hp > 0:
		parts[index].feedback_pulses[kind] = duration

func step_feedback(dt: float):
	for event in feedback_events: event.life -= dt
	feedback_events = feedback_events.filter(func(event): return event.life > 0)
	for p in parts:
		if p.hp <= 0: p.feedback_pulses.clear()
		for kind in p.feedback_pulses.keys():
			p.feedback_pulses[kind] -= dt
			if p.feedback_pulses[kind] <= 0: p.feedback_pulses.erase(kind)

func passive_state(index: int) -> Dictionary:
	return RewardFeedbackState.snapshot(self,index)

func pulse_chip_sources(index: int):
	var applied = chips(index)
	if applied.is_empty(): return
	for source in adjacent_part_indices(index):
		var core: Dictionary = db.asset(parts[source].id)
		if core.has("coreChip") and parts[source].hp > 0 and applied.has(int(db.asset(core.coreChip).chipType)):
			pulse_feedback(source,"chip_trigger",0.22)
