extends "res://scripts/centipede.gd"
## Nine physical mounts per shell; the source grid interface remains in the base
## class for recovered-source fixtures, while the playable scene uses this body.
const SLOT_COUNT = 9
const SLOT_PITCH = 16.0
const Motion = preload("res://scripts/centipede_motion.gd")
var motion = Motion.new()
var grown_segments = 6
var segment_module_counts: Dictionary = {}

func reset():
	grown_segments = resting_segments
	motion.reset()
	boost = false
	fuel_delay = 0.0
	super.reset()

func step(dt: float, direction: Vector2, wants_boost: bool):
	dt = clampf(dt, 0.0, 0.1)
	update_fuel_capacity()
	var speed = clampf(float(db.stores.PlayerDataStore.enginePower) * (1.0 + stats.get("11", 0.0)), 2.0, 4.0) * 48.0
	boost = wants_boost and fuel > 0.0 and direction.length_squared() > 0.0001
	if boost:
		fuel = maxf(0.0, fuel - 50.0 * dt)
		fuel_delay = 2.0
		speed += 48.0 * minf(float(db.stores.PlayerDataStore.boostEnginePower) * (1.0 + stats.get("12", 0.0)), 3.0)
	else:
		fuel_delay -= dt
		if fuel_delay <= 0.0: fuel = minf(max_fuel, fuel + 25.0 * dt)
	motion.step(self, dt, direction, speed)
	refresh_positions()

func refresh_body_poses():
	body_poses = motion.poses(self)

func body_part_indices() -> Array:
	var indices: Array = range(1, parts.size())
	indices.sort_custom(func(a, b): return parts[a].segment * 9 + parts[a].slot < parts[b].segment * 9 + parts[b].slot)
	return indices

func segment_index(index: int) -> int:
	return 0 if index == 0 else int(parts[index].segment)

func segment_count() -> int:
	return maxi(resting_segments, grown_segments)

func mount_cell(segment: int, slot: int) -> Vector2i:
	return Vector2i(-segment * 3 + slot % 3 - 1, slot / 3 - 1)

func slot_offset(slot: int) -> Vector2:
	return Vector2(slot % 3 - 1, slot / 3 - 1) * SLOT_PITCH

func part_at(segment: int, slot: int) -> int:
	for i in range(1, parts.size()):
		if int(parts[i].segment) == segment and int(parts[i].slot) == slot: return i
	return -1

func parts_on_segment(segment: int) -> Array:
	return range(1, parts.size()).filter(func(i): return int(parts[i].segment) == segment)

func can_mount(segment: int, slot: int, ignore: int = -1) -> bool:
	if segment < 1 or segment > mini(60, segment_count() + 1) or slot < 0 or slot >= SLOT_COUNT:
		last_error = "请选择已有体节，或拖到尾部新增一节。"
		return false
	var occupant = part_at(segment, slot)
	if occupant >= 0 and occupant != ignore:
		last_error = "这个位置已有模块；拖入已有模块可消耗交换次数互换。"
		return false
	return true

func install_module(id: String, segment: int, slot: int) -> bool:
	if parts.size() - 1 >= int(db.stores.PlayerDataStore.maxBuiltCores):
		last_error = "已达到 60 个模块的上限。"
		return false
	if not can_mount(segment, slot): return false
	var part = make_part(id, mount_cell(segment, slot))
	part.segment = segment
	part.slot = slot
	parts.append(part)
	grown_segments = maxi(grown_segments, segment)
	built_count += 1
	built_score += int(db.asset(id).get("coreRatePrize", 0))
	refresh_upgrades()
	refresh_positions()
	last_error = ""
	return true

func first_free_mount() -> Vector2i:
	for segment in range(1, segment_count() + 1):
		for slot in [4, 1, 3, 5, 7, 0, 2, 6, 8]:
			if part_at(segment, slot) < 0: return Vector2i(segment, slot)
	return Vector2i(segment_count() + 1, 4)

func append_segment(id: String) -> bool:
	# Explicit one-per-segment fixtures and the legacy shortcut retain their order.
	for segment in range(1, segment_count() + 1):
		if parts_on_segment(segment).is_empty(): return install_module(id, segment, 4)
	return install_module(id, segment_count() + 1, 4)

func add_piece(id: String, _cell: Vector2i) -> bool:
	return append_segment(id)

func move_to_mount(index: int, segment: int, slot: int) -> bool:
	if index <= 0 or index >= parts.size(): return false
	if int(parts[index].segment) == segment and int(parts[index].slot) == slot: return false
	if actions.move <= 0:
		last_error = "移动次数不足，可从奖励中获得移动操作。"
		return false
	if not can_mount(segment, slot, index): return false
	set_mount(parts[index], segment, slot)
	actions.move -= 1
	grown_segments = maxi(grown_segments, segment)
	refresh_positions()
	last_error = ""
	return true

func move_piece_to_segment(index: int, segment: int) -> bool:
	return move_to_mount(index, segment, 4)

func set_mount(part: Dictionary, segment: int, slot: int):
	part.segment = segment
	part.slot = slot
	part.cell = mount_cell(segment, slot)

func swap_piece(a: int, b: int) -> bool:
	if a <= 0 or b <= 0 or a >= parts.size() or b >= parts.size() or a == b: return false
	if actions.swap <= 0:
		last_error = "交换次数不足，可从奖励中获得交换操作。"
		return false
	var segment = int(parts[a].segment)
	var slot = int(parts[a].slot)
	set_mount(parts[a], parts[b].segment, parts[b].slot)
	set_mount(parts[b], segment, slot)
	actions.swap -= 1
	refresh_positions()
	last_error = ""
	return true

func duplicate_to_mount(index: int, segment: int, slot: int) -> bool:
	if index <= 0 or index >= parts.size() or actions.duplicate <= 0:
		last_error = "复制次数不足，或尚未选择模块。"
		return false
	if not install_module(parts[index].id, segment, slot): return false
	actions.duplicate -= 1
	return true

func refresh_positions():
	refresh_body_poses()
	segment_module_counts.clear()
	parts[0].position = head
	parts[0].body_angle = facing.angle()
	for i in range(1, parts.size()):
		var p: Dictionary = parts[i]
		segment_module_counts[int(p.segment)] = int(segment_module_counts.get(int(p.segment), 0)) + 1
		var pose = segment_pose(int(p.segment))
		p.body_angle = Vector2(pose.direction).angle()
		p.position = Vector2(pose.point) + slot_offset(int(p.slot)).rotated(p.body_angle)
		if not db.asset(p.id).has("coreProjectile"): p.angle = p.body_angle

func adjacent_part_indices(index: int, include_self: bool = false) -> Array:
	var result: Array = []
	if index < 0 or index >= parts.size(): return result
	for other in range(parts.size()):
		if other == index:
			if include_self: result.append(other)
			continue
		if index == 0 or other == 0:
			var body_part: Dictionary = parts[other if index == 0 else index]
			if int(body_part.segment) == 1 and int(body_part.slot) % 3 == 2: result.append(other)
		else:
			var delta: Vector2i = parts[index].cell - parts[other].cell
			if absi(delta.x) + absi(delta.y) == 1: result.append(other)
	return result

func module_size(index: int) -> float:
	if index == 0: return 27.0
	return 35.0 if int(parts[index].slot) == 4 and int(segment_module_counts.get(int(parts[index].segment), 0)) == 1 else 14.0

func collision_radius(index: int) -> float:
	return 30.0 if index == 0 else module_size(index) * 0.5

func weapon_visual_scale(index: int) -> float:
	return module_size(index) / 35.0

func blueprint() -> Array:
	var result = super.blueprint()
	var indices = [0] + body_part_indices()
	for i in range(1, result.size()):
		result[i].segment = parts[indices[i]].segment
		result[i].slot = parts[indices[i]].slot
	return result
