extends "res://scripts/grid_centipede.gd"
## One element per segment. Array indices stay stable when the chain is reordered
## so drones and deployed devices retain their existing combat owners.

const CharacterRoster = preload("res://scripts/character_roster.gd")
var character_id = "centipede"
var character_config: Dictionary = {}
var character_reset_serial = 0
var coil_active = false
var rush_active = false

func configure_character(id: String):
	character_config = CharacterRoster.config(id).duplicate(true)
	character_id = str(character_config.get("id", "centipede"))
	reset()

func module_cap() -> int:
	return int(character_config.get("slot_cap", 60))

func compact_body() -> bool:
	return character_id != "centipede"

func compact_mount_offset(mount: int) -> Vector2:
	if character_id == "spider":
		return Vector2(36.0 - float((mount - 1) / 2) * 25.0, -43.0 if mount % 2 else 43.0)
	return Vector2(12.0 - float((mount - 1) / 2) * 27.0, -23.0 if mount % 2 else 23.0)

func make_part(id: String, cell: Vector2i) -> Dictionary:
	var part = super.make_part(id, cell)
	part.hp *= float(character_config.get("health_multiplier", 1.0))
	part.max_hp = part.hp
	return part

func refresh_upgrades():
	var old: Array = parts.map(func(p): return [p.hp, p.max_hp])
	super.refresh_upgrades()
	for i in parts.size():
		parts[i].max_hp *= float(character_config.get("health_multiplier", 1.0))
		parts[i].hp = minf(parts[i].max_hp, float(old[i][0]) + maxf(0, parts[i].max_hp - float(old[i][1]))) if float(old[i][0]) > 0 else float(old[i][0])

func step(dt: float, direction: Vector2, wants_boost: bool):
	if not compact_body() and not coil_active:
		super.step(dt, direction, wants_boost)
		return
	dt = clampf(dt, 0, 0.1)
	update_fuel_capacity()
	boost = wants_boost and fuel > 0 and direction.length_squared() > 0.001 and not rush_active
	var speed = clampf(float(db.stores.PlayerDataStore.enginePower) * (1.0 + stats.get("11", 0.0)), 2, 4) * 48.0
	speed *= float(character_config.get("speed_multiplier", 1.0))
	if boost:
		fuel = maxf(0, fuel - 50 * dt); fuel_delay = 2
		speed += 48 * minf(float(db.stores.PlayerDataStore.boostEnginePower) * (1.0 + stats.get("12", 0.0)), 3)
	else:
		fuel_delay -= dt
		if fuel_delay <= 0: fuel = minf(max_fuel, fuel + 25 * dt)
	if coil_active: speed *= 0.3
	if rush_active: speed = 0
	input_velocity = direction.limit_length()
	velocity = input_velocity * speed
	engine_power = speed
	if not rush_active and direction.length_squared() > 0.001:
		facing = Vector2.from_angle(rotate_toward(facing.angle(), direction.angle(), dt * (3.0 if character_id == "beetle" else 7.0)))
	head += velocity * dt
	motion.elapsed += dt
	motion.activity = move_toward(motion.activity, direction.length(), dt * 4)
	refresh_positions()
	step_mount_sway(dt)

func refresh_body_poses():
	if compact_body():
		body_poses = [{"point": head, "direction": facing}]
		for mount in range(1, module_cap() + 1):
			body_poses.append({"point": head + compact_mount_offset(mount).rotated(facing.angle()), "direction": facing})
	elif coil_active:
		body_poses = [{"point": head, "direction": facing}]
		for mount in range(1, segment_count() + 1):
			var angle = float(mount) * 0.72
			var radius = 52.0 + 5.0 * mount
			body_poses.append({"point": head + Vector2.from_angle(angle + facing.angle()) * radius, "direction": Vector2.from_angle(angle + facing.angle() + PI / 2)})
	else:
		super.refresh_body_poses()

func reset():
	character_reset_serial += 1
	coil_active = false
	rush_active = false
	resting_segments = 0
	grown_segments = 0
	super.reset()

func segment_count() -> int:
	return module_cap() if compact_body() else maxi(0, parts.size() - 1)

func body_part_indices() -> Array:
	var order: Array = range(1, parts.size())
	order.sort_custom(func(a,b):return int(parts[a].get("segment",a))<int(parts[b].get("segment",b)))
	return order

func segment_index(index: int) -> int:
	return 0 if index==0 else int(parts[index].segment)

func mount_cell(segment: int, _slot: int = 4) -> Vector2i:
	return Vector2i(-segment,0)

func slot_offset(_slot: int) -> Vector2:
	return Vector2.ZERO

func part_at(segment: int, _slot: int = 4) -> int:
	for index in range(1,parts.size()):
		if int(parts[index].segment)==segment:return index
	return -1

func parts_on_segment(segment: int) -> Array:
	var index = part_at(segment)
	return [index] if index>0 else []

func can_mount(segment: int, _slot: int = 4, _ignore: int = -1) -> bool:
	if compact_body():
		if segment < 1 or segment > module_cap(): return false
		var occupant = part_at(segment)
		return occupant < 0 or occupant == _ignore
	if segment<1 or segment>segment_count()+1:
		last_error="请选择身体之间的位置，或拖到尾部。"
		return false
	return true

func install_module(id: String, before: int, _slot: int = 4) -> bool:
	if parts.size() - 1 >= module_cap():
		last_error="挂点已满。"
		return false
	if db.asset(id).is_empty() or not can_mount(before):return false
	for part in parts.slice(1):
		if not compact_body() and int(part.segment)>=before:part.segment+=1
	var part = make_part(id,mount_cell(before))
	part.segment=before;part.slot=4
	parts.append(part)
	built_count+=1;built_score+=int(db.asset(id).get("coreRatePrize",0))
	refresh_positions();refresh_upgrades();last_error=""
	emit_feedback("installed",[part.feedback_uid])
	pulse_feedback(parts.size()-1,"installed",1.2)
	return true

func first_free_mount() -> Vector2i:
	if compact_body():
		for mount in range(1, module_cap() + 1):
			if part_at(mount) < 0: return Vector2i(mount, 4)
		return Vector2i(-1, 4)
	return Vector2i(segment_count()+1,4)

func append_segment(id: String) -> bool:
	return install_module(id, first_free_mount().x)

func move_to_mount(index: int, before: int, _slot: int = 4) -> bool:
	if index<=0 or index>=parts.size() or not can_mount(before):return false
	if compact_body():
		parts[index].segment = before
		refresh_positions()
		return true
	var order = body_part_indices()
	var start = order.find(index)
	var destination = before-1
	if destination==start or destination==start+1:return false
	order.remove_at(start)
	if destination>start:destination-=1
	order.insert(destination,index)
	for i in order.size():parts[order[i]].segment=i+1
	refresh_positions();last_error=""
	return true

func move_piece_to_segment(index: int, before: int) -> bool:
	return move_to_mount(index,before)

func swap_piece(a: int,b: int) -> bool:
	if a<=0 or b<=0 or a>=parts.size() or b>=parts.size() or a==b:return false
	var segment=int(parts[a].segment)
	parts[a].segment=parts[b].segment;parts[b].segment=segment
	refresh_positions()
	return true

func duplicate_to_mount(index: int,before: int,_slot: int = 4) -> bool:
	if index<=0 or index>=parts.size() or actions.duplicate<=0:return false
	if parts.size()-1+pending.size()>=module_cap():return false
	if not install_module(parts[index].id,before):return false
	actions.duplicate-=1
	return true

func refresh_positions():
	var order = body_part_indices()
	for i in order.size():
		var part:Dictionary=parts[order[i]]
		if not compact_body(): part.segment=i+1
		part.slot=4;part.cell=mount_cell(int(part.segment))
	grown_segments=segment_count()
	super.refresh_positions()

func adjacent_part_indices(index: int,include_self: bool = false) -> Array:
	var result:Array=[]
	if index<0 or index>=parts.size():return result
	var segment=segment_index(index)
	if include_self:result.append(index)
	for other in range(parts.size()):
		if compact_body():
			if other == index: continue
			var a = Vector2.ZERO if index == 0 else compact_mount_offset(segment)
			var b = Vector2.ZERO if other == 0 else compact_mount_offset(segment_index(other))
			if a.distance_to(b) <= 45.0: result.append(other)
		elif absi(segment_index(other)-segment)==1:result.append(other)
	return result

func module_size(index: int) -> float:
	return (58.0 if index == 0 else 30.0) if compact_body() else (42.0 if index==0 else 56.0)

func display_slot_offset(segment: int,_slot: int = 4,_additional: int = 0) -> Vector2:
	return Vector2.ZERO if compact_body() else Vector2(0,-6 if segment%2 else 6)

func collision_radius(index: int) -> float:
	return (40.0 if index == 0 else 14.0) if compact_body() else (30.0 if index==0 else 27.0)

func reward_module_count(_reward:Dictionary) -> int:
	return 1

func uses_build_actions() -> bool:
	return false

func replace_module(index: int, id: String) -> bool:
	if not compact_body() or index <= 0 or index >= parts.size() or db.asset(id).is_empty(): return false
	var mount = int(parts[index].segment)
	parts[index] = make_part(id, mount_cell(mount))
	parts[index].segment = mount; parts[index].slot = 4
	built_count += 1
	built_score += int(db.asset(id).get("coreRatePrize", 0))
	refresh_positions(); refresh_upgrades()
	emit_feedback("installed", [parts[index].feedback_uid])
	return true
