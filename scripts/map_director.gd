extends RefCounted
const Formation=preload("res://scripts/radial_formation.gd")

var session: WeakRef
var db
var battle
var player
var config: Dictionary
var nodes: Dictionary = {}
var remembered_types: Dictionary = {}
var destroyed_nodes: Dictionary = {}
var easy_positions: Array = []
var first_positions: Array = []
var events: Array = []
var event_index = -1
var last_grid = Vector2(INF, INF)
var distance = 45.0

func _init(run):
	session = weakref(run)
	db = run.db
	battle = run.combat
	player = run.player
	config = run.configuration
	distance = maxf(1, float(config.get("distanceBetweenNodes", 45)))
	events = db.packed(config.get("mapEventsList"))
	var x = float(config.get("xOffset", 0)) + distance * 0.5
	var y = float(config.get("yOffset", 0)) + distance * 0.5
	first_positions = [Vector2(x,y), Vector2(x,-y), Vector2(-x,y), Vector2(-x,-y)]
	easy_positions = first_positions.duplicate()
	easy_positions.append(Vector2(distance+x,y))
	easy_positions.append(Vector2(distance+x,-y))
	update_grid()

func random_circle(radius: float) -> Vector2:
	return Vector2.from_angle(battle.rng.randf() * TAU) * sqrt(battle.rng.randf()) * radius

func event_type(pos: Vector2) -> int:
	if remembered_types.has(pos): return remembered_types[pos]
	var type = 104
	var easy = db.packed(db.scene_config.get("MapNodesManager", {}).get("easyEventsType"))
	if pos in easy_positions and not easy.is_empty():
		type = easy[battle.rng.randi_range(0, easy.size()-1)]
	elif config.get("emptyFirstLayerMapNodes", false) and pos in first_positions:
		type = 104
	elif not events.is_empty():
		event_index += 1
		if event_index >= events.size():
			event_index = 0
			for i in range(events.size()-1, 0, -1):
				var j = battle.rng.randi_range(0, i)
				var item = events[i]
				events[i] = events[j]
				events[j] = item
		type = events[event_index]
	remembered_types[pos] = type
	return type

func update_grid():
	var grid = (player.head / (distance * 48)).round() * distance
	if grid == last_grid: return
	last_grid = grid
	var positions: Array = []
	for x in [-1.5, -0.5, 0.5, 1.5]:
		for y in [-1.5, -0.5, 0.5, 1.5]:
			var pos = grid + Vector2(x,y) * distance
			pos += Vector2(signf(pos.x)*float(config.get("xOffset",0)), signf(pos.y)*float(config.get("yOffset",0)))
			positions.append(pos)
	for pos in nodes.keys():
		if pos not in positions:
			var node: Dictionary = nodes[pos]
			battle.enemies = battle.enemies.filter(func(e): return e.uid not in node.members)
			nodes.erase(pos)
	for pos in positions:
		if not nodes.has(pos) and not destroyed_nodes.has(pos): spawn_node(pos, event_type(pos))

func add_actor(node: Dictionary, type: int, offset: Vector2, objective: bool = true) -> Dictionary:
	var actor = battle.spawn(db.pool.get(str(type), ""), node.position + offset, "map")
	if actor.is_empty(): return actor
	actor.map_node = node.key
	actor.mission_controlled = true
	actor.origin = node.position
	actor.orbit_offset = offset
	node.members.append(actor.uid)
	if objective: node.objectives.append(actor.uid)
	return actor

func weighted_asset(ids: Array, weight: String) -> Dictionary:
	var pool: Array = []
	for id in ids:
		var asset = db.asset(id)
		for i in range(int(asset.get(weight, 1))): pool.append(asset)
	return pool[battle.rng.randi_range(0, pool.size()-1)] if not pool.is_empty() else {}

func set_cores(actor: Dictionary, data: Dictionary):
	actor.guns.clear()
	for i in range(data.get("coresList", []).size()):
		var slot: Dictionary = actor.slots[i] if i < actor.slots.size() else {"x":0,"y":0}
		actor.guns.append({"id":data.coresList[i],"cooldown":battle.rng.randf(),"angle":0.0,"offset":Vector2(slot.x,slot.y)*48})

func source_points(prefab: String, component: String, field: String) -> Array:
	var points: Array = []
	for reference in db.component(prefab,component).get(field,[]):
		var pose: Dictionary = db.prefab_transforms.get(prefab,{}).get(str(int(reference.fileID)),{})
		if not pose.is_empty(): points.append(Vector2(pose.x,pose.y)*48)
	return points

func set_art(actor: Dictionary, sprite):
	if actor.render.is_empty(): return
	actor.render = actor.render.duplicate(true)
	actor.render[0].sprite = sprite

func spawn_guards(node: Dictionary, ratio: float, faction: int):
	var points = source_points(node.prefab,"AIGuardsSpawner","AIGuardSpawnPointsList")
	points=Formation.circularized(points,ceili(points.size()*ratio))
	for i in points.size():
		var data = weighted_asset(db.stores.AIDataStore.aIGuardUnitList,"unitProbabilty")
		if data.is_empty(): continue
		var actor = add_actor(node,int(data.prefabType),points[i],false)
		if actor.is_empty(): continue
		set_cores(actor,data)
		actor.range_modifier = 0.25
		actor.orbit_speed = node.rotation
		var key = "FederationGuardsLevelSprites" if faction == 0 else "ASVWGuardsLevelSprites"
		set_art(actor,db.stores.AIDataStore[key][int(data.aIThreatLevel)])

func spawn_node(pos: Vector2, type: int):
	var prefab: String = db.pool.get(str(type),"")
	var node = {"key":pos,"type":type,"prefab":prefab,"position":pos*48+random_circle(240),"members":[],"objectives":[],"reward_ids":[],"threat":0,"rotation":deg_to_rad(battle.rng.randf_range(-10,10))}
	nodes[pos] = node
	if type in [100,101]:
		var field = db.component(prefab,"AsteroidField" if type == 100 else "ContainerField")
		var count = battle.rng.randi_range(int(field.minFieldCount),int(field.maxFieldCount)-1)
		var ratio = float(count)/float(field.maxFieldCount)
		var radius = clampi(int(ratio*float(field.maxFieldArea)),int(field.minFieldArea),int(field.maxFieldArea))*48
		if type == 100:
			var weights = [int(field.smallAsteroidsProb),int(field.midAsteroidsProb),int(field.bigAsteroidsProb)]
			var total = weights[0]+weights[1]+weights[2]
			for size in range(3):
				for i in range(int(float(count)*weights[size]/total)):
					var actor = add_actor(node,130+size,random_circle(radius))
					if not actor.is_empty(): actor.orbit_speed = 0.0
		else:
			var containers = db.packed(field.containersPrefabTypes)
			for i in range(count): add_actor(node,containers[battle.rng.randi_range(0,containers.size()-1)],random_circle(radius))
			spawn_guards(node,ratio,0)
	elif type == 103:
		var faction = 1 if battle.rng.randi_range(0,99)>50 else 0
		node.center_sprite=db.stores.AIDataStore["FederationStationCoreSprite" if faction==0 else "ASVWStationCoreSprite"]
		var points = source_points(prefab,"AIStation","aIStationPartSpawnPointsList")
		points=Formation.circularized(points)
		var threat_score = 0
		for offset in points:
			var data = weighted_asset(db.stores.AIDataStore.aIStationPartsList,"partProbabilty")
			var actor = add_actor(node,int(data.prefabType),offset)
			if actor.is_empty(): continue
			set_cores(actor,data)
			actor.orbit_speed = node.rotation
			actor.range_modifier = 0.3
			threat_score += 1+int(data.aIThreatLevel)
			node.reward_ids.append_array(data.rewardPacksList)
			var key = "FederationStationsLevelSprites" if faction == 0 else "ASVWStationsLevelSprites"
			set_art(actor,db.stores.AIDataStore[key][int(data.aIThreatLevel)])
		node.threat = 0 if threat_score <= 4 else (1 if threat_score <= 8 else 2)
		var ratios = [Vector2(0.1,0.4),Vector2(0.4,0.75),Vector2(0.75,1)]
		spawn_guards(node,battle.rng.randf_range(ratios[node.threat].x,ratios[node.threat].y),faction)
	elif type == 105:
		add_actor(node,510,Vector2.ZERO)
		spawn_guards(node,battle.rng.randf_range(0.5,1),1)

func step(dt: float):
	update_grid()
	for node in nodes.values():
		if node.objectives.is_empty() or destroyed_nodes.has(node.key): continue
		var alive = node.objectives.any(func(uid): return battle.entity(uid).get("hp",0)>0)
		if not alive:
			destroyed_nodes[node.key] = true
			if node.type in [103,105]:battle.statistics.stat_StationsDestroyed=int(battle.statistics.get("stat_StationsDestroyed",0))+1
			if node.type == 103:
				for i in range(2): battle.loot.append({"position":node.position,"value":0,"pack":true,"rarity":1+int(node.threat),"pack_ids":node.reward_ids})
	for actor in battle.enemies:
		if actor.get("orbit_speed",0) != 0:
			actor.orbit_offset = Vector2(actor.orbit_offset).rotated(actor.orbit_speed*dt)
			actor.position = actor.origin + actor.orbit_offset
			actor.angle += actor.orbit_speed*dt
