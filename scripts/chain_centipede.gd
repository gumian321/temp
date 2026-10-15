extends "res://scripts/grid_centipede.gd"
## One element per segment. Array indices stay stable when the chain is reordered
## so drones and deployed devices retain their existing combat owners.

const SpiderRig = preload("res://scripts/spider_rig.gd")
const SPIDER_LEGS = 8
const SPIDER_LEG_CAP = 4
var spider_rig = SpiderRig.new()

const CharacterRoster = preload("res://scripts/character_roster.gd")
var character_id = "centipede"
var character_config: Dictionary = {}
var character_reset_serial = 0
const CoilRig = preload("res://scripts/centipede_coil.gd")
var coil_rig = CoilRig.new()
var coil_active = false
var rush_active = false
const Flagella = preload("res://scripts/flagella.gd")
const MAX_FUSION_LEVEL = 4
var flagella = Flagella.new()
const Fragments = preload("res://scripts/centipede_fragments.gd")
var fragment_recovery = Fragments.new()
var detached_fragments: Array:
	get: return fragment_recovery.groups

func detached_module_count() -> int:
	return fragment_recovery.count()

func remove_destroyed_parts(indices: Array):
	fragment_recovery.sever(self, indices)


func can_merge(source: Dictionary, target: Dictionary) -> bool:
	return not source.is_empty() and not target.is_empty() and source != target and parts.find(target) > 0 and source.get("id") == target.get("id") and int(source.get("fusion_level", 1)) == int(target.get("fusion_level", 1)) and int(target.get("fusion_level", 1)) < MAX_FUSION_LEVEL and float(target.get("hp", 1)) > 0 and float(source.get("hp", 1)) > 0

func merge_parts(source_index: int, target_index: int) -> bool:
	if source_index <= 0 or source_index >= parts.size() or target_index <= 0 or target_index >= parts.size(): return false
	var source: Dictionary = parts[source_index]
	var target: Dictionary = parts[target_index]
	if not can_merge(source, target): return false
	target.fusion_level = int(target.get("fusion_level", 1)) + 1
	target.hp = minf(target.max_hp, target.hp + source.hp)
	remove_parts([source_index])
	emit_feedback("installed", [target.feedback_uid])
	pulse_feedback(parts.find(target), "installed", 1.5)
	return true

func merge_pending(pending_index: int, target_index: int) -> bool:
	if pending_index < 0 or pending_index >= pending.size() or target_index <= 0 or target_index >= parts.size(): return false
	var target: Dictionary = parts[target_index]
	if not can_merge({"id": pending[pending_index]}, target): return false
	target.fusion_level = 2
	pending.remove_at(pending_index)
	refresh_upgrades()
	emit_feedback("installed", [target.feedback_uid])
	pulse_feedback(target_index, "installed", 1.5)
	return true

func step_flagella(dt: float):
	var keys: Array = []
	for i in parts.size():
		var part: Dictionary = parts[i]
		var is_head = i == 0 and character_id == "centipede"
		var level = int(part.get("fusion_level", 1))
		if not is_head and level == 1: continue
		var pose = segment_pose(int(part.segment)) if i > 0 else {"point": head, "direction": facing}
		keys.append(int(part.feedback_uid))
		flagella.step(int(part.feedback_uid), pose.point, Vector2(pose.direction).angle(), 2 if is_head else level, is_head, dt, motion.elapsed, velocity.length())
	flagella.retain(keys)

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
		spider_rig.ensure(self)
		return (Vector2(spider_rig.mount_pose(mount).point) - head).rotated(-facing.angle())
	return Vector2(12.0 - float((mount - 1) / 2) * 27.0, -23.0 if mount % 2 else 23.0)

## Encoded mounts preserve the original first eight addresses. Parts-array
## indices are combat owners and are never reordered by assembly operations.
func spider_mount(leg: int, depth: int) -> int:
	return 1 + leg + SPIDER_LEGS * depth if leg >= 0 and leg < SPIDER_LEGS and depth >= 0 and depth < SPIDER_LEG_CAP else -1

func spider_leg_for_mount(mount: int) -> int:
	return (mount - 1) % SPIDER_LEGS if mount >= 1 and mount <= SPIDER_LEGS * SPIDER_LEG_CAP else -1

func spider_depth_for_mount(mount: int) -> int:
	return (mount - 1) / SPIDER_LEGS if mount >= 1 and mount <= SPIDER_LEGS * SPIDER_LEG_CAP else -1

func spider_leg_indices(leg: int) -> Array:
	var indices: Array = []
	if leg < 0 or leg >= SPIDER_LEGS: return indices
	for index in range(1, parts.size()):
		if spider_leg_for_mount(int(parts[index].segment)) == leg: indices.append(index)
	indices.sort_custom(func(a, b): return int(parts[a].segment) < int(parts[b].segment))
	return indices

func spider_leg_count(leg: int) -> int:
	return spider_leg_indices(leg).size()

func set_spider_leg_order(leg: int, order: Array):
	for depth in order.size():
		parts[order[depth]].segment = spider_mount(leg, depth)

func normalize_spider_legs():
	for leg in SPIDER_LEGS:
		set_spider_leg_order(leg, spider_leg_indices(leg))

func make_part(id: String, cell: Vector2i) -> Dictionary:
	var part = super.make_part(id, cell)
	part.fusion_level = 1
	part.hp *= float(character_config.get("health_multiplier", 1.0))
	part.max_hp = part.hp
	return part

func refresh_upgrades():
	var old: Array = parts.map(func(p): return [p.hp, p.max_hp])
	super.refresh_upgrades()
	for i in parts.size():
		parts[i].max_hp *= float(character_config.get("health_multiplier", 1.0)) * pow(1.6, int(parts[i].get("fusion_level", 1)) - 1)
		parts[i].hp = minf(parts[i].max_hp, float(old[i][0]) + maxf(0, parts[i].max_hp - float(old[i][1]))) if float(old[i][0]) > 0 else float(old[i][0])

	# Upgrades collected while a fragment sleeps still apply to its original modules.
	for group in detached_fragments:
		for part in group.parts:
			var core: Dictionary = db.asset(part.id)
			var maximum = float(core.get("CoreHealth",90))*(1.0+upgrade_bonus(part.id,"CoreHealthPercent")+stats.get("16",0.0))
			if part.wall: maximum+=float(db.stores.CoresDataStore.walledCoreAddedHealth)
			maximum*=float(character_config.get("health_multiplier",1.0))*pow(1.6,int(part.get("fusion_level",1))-1)
			part.hp=minf(maximum,float(part.hp)+maxf(0.0,maximum-float(part.max_hp)))
			part.max_hp=maximum

func step(dt: float, direction: Vector2, wants_boost: bool):
	if not compact_body() and not coil_rig.engaged():
		super.step(dt, direction, wants_boost)
		step_flagella(dt)
		fragment_recovery.step(self, dt)
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
	if character_id == "spider": spider_rig.step(self, dt)
	elif character_id == "centipede": coil_rig.advance(self, dt)
	refresh_positions()
	step_mount_sway(dt)
	step_flagella(dt)
	fragment_recovery.step(self, dt)

func refresh_body_poses():
	if character_id == "spider":
		spider_rig.ensure(self)
		body_poses = [{"point": head, "direction": facing}]
		for mount in range(1, module_cap() + 1):
			body_poses.append(spider_rig.mount_pose(mount))
	elif compact_body():
		body_poses = [{"point": head, "direction": facing}]
		for mount in range(1, module_cap() + 1):
			body_poses.append({"point": head + compact_mount_offset(mount).rotated(facing.angle()), "direction": facing})
	elif coil_rig.engaged():
		body_poses = coil_rig.poses(self)
	else:
		super.refresh_body_poses()

func begin_coil():
	coil_rig.begin(self, true)
	coil_active = true

func end_coil():
	if coil_active: coil_rig.begin(self, false)
	coil_active = false

func reset():
	fragment_recovery.clear()
	flagella.clear()
	coil_rig.reset()
	spider_rig.reset()
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
	if character_id == "spider":
		var leg = spider_leg_for_mount(segment)
		var depth = spider_depth_for_mount(segment)
		if leg < 0:
			last_error = "请选择蜘蛛腿上的挂点。"
			return false
		var order = spider_leg_indices(leg)
		if order.size() >= SPIDER_LEG_CAP and _ignore not in order:
			last_error = "这条腿已装满 4 个模块。"
			return false
		if depth > order.size():
			last_error = "请从腿根向外依次安装模块。"
			return false
		return true
	if compact_body():
		if segment < 1 or segment > module_cap(): return false
		var occupant = part_at(segment)
		return occupant < 0 or occupant == _ignore
	if segment<1 or segment>segment_count()+1:
		last_error="请选择身体之间的位置，或拖到尾部。"
		return false
	return true

func install_module(id: String, before: int, _slot: int = 4) -> bool:
	if parts.size() - 1 + fragment_recovery.count() >= module_cap():
		last_error="挂点已满。"
		return false
	if db.asset(id).is_empty() or not can_mount(before):return false
	if character_id == "spider":
		for index in spider_leg_indices(spider_leg_for_mount(before)):
			if int(parts[index].segment) >= before: parts[index].segment += SPIDER_LEGS
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
	if character_id == "spider":
		# Grow balanced legs by default; explicit installation can focus one leg.
		for depth in SPIDER_LEG_CAP:
			for leg in SPIDER_LEGS:
				if spider_leg_count(leg) == depth: return Vector2i(spider_mount(leg, depth), 4)
		return Vector2i(-1, 4)
	if compact_body():
		for mount in range(1, module_cap() + 1):
			if part_at(mount) < 0: return Vector2i(mount, 4)
		return Vector2i(-1, 4)
	return Vector2i(segment_count()+1,4)

func append_segment(id: String) -> bool:
	return install_module(id, first_free_mount().x)

func move_to_mount(index: int, before: int, _slot: int = 4) -> bool:
	if index<=0 or index>=parts.size():return false
	if character_id == "spider":
		if not can_mount(before, 4, index): return false
		var old_leg = spider_leg_for_mount(int(parts[index].segment))
		var new_leg = spider_leg_for_mount(before)
		var source = spider_leg_indices(old_leg)
		var old_depth = source.find(index)
		var new_depth = spider_depth_for_mount(before)
		if old_leg == new_leg and (new_depth == old_depth or new_depth == old_depth + 1): return false
		source.erase(index)
		if old_leg == new_leg:
			if new_depth > old_depth: new_depth -= 1
			source.insert(new_depth, index)
			set_spider_leg_order(old_leg, source)
		else:
			var destination = spider_leg_indices(new_leg)
			destination.insert(new_depth, index)
			set_spider_leg_order(old_leg, source)
			set_spider_leg_order(new_leg, destination)
		refresh_positions(); refresh_upgrades(); last_error = ""
		return true
	if not can_mount(before):return false
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
	if character_id == "spider": refresh_upgrades()
	return true

func duplicate_to_mount(index: int,before: int,_slot: int = 4) -> bool:
	if index<=0 or index>=parts.size() or actions.duplicate<=0:return false
	if parts.size()-1+pending.size()+detached_module_count()>=module_cap():return false
	if not install_module(parts[index].id,before):return false
	actions.duplicate-=1
	return true

func refresh_positions():
	if character_id == "spider": normalize_spider_legs()
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
		if character_id == "spider":
			if other == index: continue
			if index == 0 or other == 0:
				var mount = segment_index(other if index == 0 else index)
				if spider_depth_for_mount(mount) == 0: result.append(other)
			elif spider_leg_for_mount(segment) == spider_leg_for_mount(segment_index(other)) and absi(spider_depth_for_mount(segment) - spider_depth_for_mount(segment_index(other))) == 1:
				result.append(other)
		elif compact_body():
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

func weapon_origin(index: int) -> Vector2:
	# Spider sockets already move with the articulated limb. All consumers share
	# the same authoritative world location instead of adding cosmetic sway.
	if character_id == "spider": return parts[index].position
	return super.weapon_origin(index)
