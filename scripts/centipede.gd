extends RefCounted

var db
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
var stats: Dictionary = {}
var hq_weapon: String
var levels: Dictionary = {}
var last_error = ""
var built_count = 0
var built_score = 0

func _init(source):
	db = source
	hq_weapon = db.stores.PlayerDataStore.mainTurretCore
	reset()

func reset():
	head = Vector2.ZERO
	velocity = Vector2.ZERO
	history.clear()
	for i in range(2000):
		history.append(Vector2(-i * 4.0, 0))
	parts = [make_part(db.stores.PlayerDataStore.HQCore, Vector2i.ZERO)]
	pending.clear()
	stats.clear()
	levels.clear()
	fuel = 0.0
	max_fuel=0.0
	built_count = 0

func make_part(id: String, cell: Vector2i) -> Dictionary:
	var c: Dictionary = db.asset(id)
	var hp = float(c.get("CoreHealth", 90))
	return {"id": id, "cell": cell, "hp": hp, "max_hp": hp, "cooldown": 0.0, "shield": float(c.get("maxShieldHealth",0)), "shield_broken":false, "shield_delay": 0.0, "wall": false, "position": head, "angle": 0.0, "body_angle":0.0, "active": true, "stun": 0.0}

func add_piece(id: String, cell: Vector2i) -> bool:
	if parts.size() >= int(db.stores.PlayerDataStore.maxBuiltCores) + 1:
		last_error = "Maximum parts reached"
		return false
	if not can_place(cell):
		return false
	parts.append(make_part(id, cell))
	built_count += 1
	built_score += int(db.asset(id).get("coreRatePrize",0))
	refresh_upgrades()
	refresh_positions()
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
		last_error = "Outside original build limits"
		return false
	if occupied(cell, ignore):
		last_error = "Occupied cell"
		return false
	for v in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if occupied(cell + v, ignore):
			return true
	last_error = "Parts must connect to the structure"
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
	var old: Vector2i = parts[index].cell
	parts[index].cell = cell
	if not connected():
		parts[index].cell = old
		last_error = "This move disconnects the structure"
		return false
	actions.move -= 1
	return true

func swap_piece(a: int, b: int) -> bool:
	if a <= 0 or b <= 0 or a == b or actions.swap <= 0:
		return false
	var old: Vector2i = parts[a].cell
	parts[a].cell = parts[b].cell
	parts[b].cell = old
	actions.swap -= 1
	return true

func duplicate_piece(index: int, cell: Vector2i) -> bool:
	if index <= 0 or actions.duplicate <= 0:
		return false
	if add_piece(parts[index].id, cell):
		actions.duplicate -= 1
		return true
	return false

func reinforce(index: int) -> bool:
	if index <= 0 or actions.wall <= 0 or parts[index].wall:
		return false
	parts[index].wall = true
	var amount = float(db.stores.CoresDataStore.walledCoreAddedHealth)
	parts[index].max_hp += amount
	parts[index].hp += amount
	actions.wall -= 1
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
	velocity = velocity.move_toward(direction.limit_length() * speed, speed * (0.75 if direction.length() > 0 else 1.5) * dt)
	if velocity.length() > 0.1:
		facing = velocity.normalized()
		head += velocity * dt
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
	var rows = body_rows()
	parts[0].position = head
	parts[0].body_angle = facing.angle()
	for i in range(1, parts.size()):
		var p: Dictionary = parts[i]
		var idx = rows.find(p.cell.y) + 1
		var pose = path_sample(idx * body_spacing)
		var normal: Vector2 = pose.direction.orthogonal()
		p.position = pose.point + normal * (float(p.cell.x) - 0.5) * 44.0
		p.body_angle = pose.direction.angle()
		if not db.asset(p.id).has("coreProjectile"):p.angle=p.body_angle

var support_tick=false
var chip_sources:Array=[]
func begin_support_tick():
	chip_sources.clear()
	for part in parts:
		if db.asset(part.id).has("coreChip"):chip_sources.append(part)
	support_tick=true
func end_support_tick():support_tick=false

func chips(index: int) -> Dictionary:
	var result = {}
	if index == 0:
		return result
	var sources=chip_sources if support_tick else parts.filter(func(p):return db.asset(p.id).has("coreChip"))
	if sources.is_empty():return result
	var c: Dictionary = db.asset(parts[index].id)
	if not c.get("isChipable", false):
		return result
	var projectile: Dictionary = db.asset(c.get("coreProjectile", c.get("coreMine", "")))
	if c.has("coreDrone"):projectile=db.asset(db.asset(c.coreDrone).get("droneProjectile",""))
	var allowed: Array = db.packed(c.get("activatableChips",projectile.get("activatableChips", {})).get("activatedChipsList"))
	for p in sources:
		var chip_core: Dictionary = db.asset(p.id)
		if not chip_core.has("coreChip") or p.hp <= 0:
			continue
		var delta: Vector2i = parts[index].cell - p.cell
		if abs(delta.x) <= 1 and abs(delta.y) <= 1:
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
	for p in parts:
		result.append({"id": p.id, "x": p.cell.x, "y": p.cell.y, "wall": p.wall})
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
		p.hp += maxf(0, hp - p.max_hp)
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
	var visited: Array = [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]
	var todo = visited.duplicate()
	while not todo.is_empty():
		var at: Vector2i = todo.pop_back()
		for p in parts:
			if p.hp<=0 or p.cell in visited: continue
			if absi(p.cell.x-at.x)+absi(p.cell.y-at.y)==1:
				visited.append(p.cell)
				todo.append(p.cell)
	var detached: Array = []
	for i in range(1,parts.size()):
		if parts[i].hp<=0 or parts[i].cell not in visited: detached.append(i)
	return detached
