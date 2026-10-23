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
var pending_nodes: Array = []
var incremental = false
var actor_jobs:Array=[]
var defer_actor_jobs=false
var use_remote_orbits=true
var orbit_activity_view=Rect2()
var orbit_moves=0
var remote_orbit_skips=0
const REMOTE_ORBIT_INTERVAL=1.0/15.0

func _init(run, defer_spawns: bool = false):
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
	incremental = defer_spawns
	update_grid(defer_spawns)

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

func update_grid(defer_spawns: bool = false):
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
	pending_nodes.clear()
	for pos in positions:
		if not nodes.has(pos) and not destroyed_nodes.has(pos): pending_nodes.append(pos)
	if not defer_spawns:
		while not pending_nodes.is_empty(): prepare_next_node()

func prepare_next_node(defer_actors:bool=false):
	if pending_nodes.is_empty(): return
	var pos: Vector2 = pending_nodes.pop_front()
	defer_actor_jobs=defer_actors and battle.cave_enabled()
	spawn_node(pos, event_type(pos))
	defer_actor_jobs=false

func add_actor(node: Dictionary, type: int, offset: Vector2, objective: bool = true,placement:Dictionary={}) -> Dictionary:
	var actor = battle.spawn(db.pool.get(str(type), ""), node.position + offset, "map",false,placement)
	if actor.is_empty(): return actor
	actor.map_node = node.key
	actor.mission_controlled = true
	# Cave placement can shift a prefab into a nearby chamber. Keep its orbit
	# around that accepted spawn, rather than sweeping back through solid rock
	# toward the original requested map position on every subsequent tick.
	actor.origin = Vector2(actor.position)-offset if battle.cave_enabled() else node.position
	actor.orbit_offset = offset
	node.members.append(actor.uid)
	if objective: node.objectives.append(actor.uid)
	return actor

func request_actor(node:Dictionary,type:int,offset:Vector2,objective:bool=true,decor:Dictionary={}):
	var job={"node":node,"type":type,"offset":offset,"objective":objective,"decor":decor,"placement":{}}
	if defer_actor_jobs:
		actor_jobs.append(job);node.pending+=1
	else:run_actor_job(job)

func run_actor_job(job:Dictionary,placement:Dictionary={}):
	var actor=add_actor(job.node,job.type,job.offset,job.objective,placement)
	if actor.is_empty():return
	var decor:Dictionary=job.decor
	if decor.has("cores"):set_cores(actor,decor.cores)
	if decor.has("range"):actor.range_modifier=decor.range
	if decor.has("orbit"):actor.orbit_speed=decor.orbit
	if decor.has("sprite"):set_art(actor,decor.sprite)
	if decor.has("rewards"):job.node.reward_ids.append_array(decor.rewards)

func prepare_actor():
	if actor_jobs.is_empty():return
	var job:Dictionary=actor_jobs[0]
	if not nodes.has(job.node.key) or not is_same(nodes[job.node.key],job.node):actor_jobs.pop_front();return
	var prefab:String=db.pool.get(str(job.type),"")
	var point:Vector2=job.node.position+Vector2(job.offset)
	if not battle.terrain.prepare_placement(job.placement,point,battle.formation_radius(prefab)):return
	run_actor_job(job,job.placement)
	job.node.pending-=1;actor_jobs.pop_front()

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
		var key = "FederationGuardsLevelSprites" if faction == 0 else "ASVWGuardsLevelSprites"
		request_actor(node,int(data.prefabType),points[i],false,{"cores":data,"range":.25,"orbit":node.rotation,"sprite":db.stores.AIDataStore[key][int(data.aIThreatLevel)]})

func spawn_node(pos: Vector2, type: int):
	var prefab: String = db.pool.get(str(type),"")
	var node = {"key":pos,"type":type,"prefab":prefab,"position":pos*48+random_circle(240),"members":[],"objectives":[],"reward_ids":[],"threat":0,"rotation":deg_to_rad(battle.rng.randf_range(-10,10)),"pending":0}
	nodes[pos] = node
	if type == 100 and battle.cave_enabled():
		# Deposits already live in the continuous rock. The legacy asteroid field
		# placed 263px boulders into chambers that cannot contain them, repeatedly
		# searching hundreds of positions and duplicating the new mining content.
		node.cave_deposit = true
		return
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
					request_actor(node,130+size,random_circle(radius),true,{"orbit":0.0})
		else:
			var containers = db.packed(field.containersPrefabTypes)
			for i in range(count):request_actor(node,containers[battle.rng.randi_range(0,containers.size()-1)],random_circle(radius))
			spawn_guards(node,ratio,0)
	elif type == 103:
		var faction = 1 if battle.rng.randi_range(0,99)>50 else 0
		node.center_sprite=db.stores.AIDataStore["FederationStationCoreSprite" if faction==0 else "ASVWStationCoreSprite"]
		var points = source_points(prefab,"AIStation","aIStationPartSpawnPointsList")
		points=Formation.circularized(points)
		var threat_score = 0
		for offset in points:
			var data = weighted_asset(db.stores.AIDataStore.aIStationPartsList,"partProbabilty")
			if data.is_empty():continue
			threat_score += 1+int(data.aIThreatLevel)
			var key = "FederationStationsLevelSprites" if faction == 0 else "ASVWStationsLevelSprites"
			request_actor(node,int(data.prefabType),offset,true,{"cores":data,"orbit":node.rotation,"range":.3,"rewards":data.rewardPacksList,"sprite":db.stores.AIDataStore[key][int(data.aIThreatLevel)]})
		node.threat = 0 if threat_score <= 4 else (1 if threat_score <= 8 else 2)
		var ratios = [Vector2(0.1,0.4),Vector2(0.4,0.75),Vector2(0.75,1)]
		spawn_guards(node,battle.rng.randf_range(ratios[node.threat].x,ratios[node.threat].y),faction)
	elif type == 105:
		request_actor(node,510,Vector2.ZERO)
		spawn_guards(node,battle.rng.randf_range(0.5,1),1)

func step(dt: float):
	update_grid(incremental)
	if not pending_nodes.is_empty(): prepare_next_node(true)
	if not actor_jobs.is_empty():prepare_actor()
	for node in nodes.values():
		if int(node.get("pending",0))>0:continue
		if node.objectives.is_empty() or destroyed_nodes.has(node.key): continue
		var alive = node.objectives.any(func(uid): return battle.entity(uid).get("hp",0)>0)
		if not alive:
			destroyed_nodes[node.key] = true
			if node.type in [103,105]:battle.statistics.stat_StationsDestroyed=int(battle.statistics.get("stat_StationsDestroyed",0))+1
			if node.type == 103:
				for i in range(2): battle.loot.append({"position":node.position,"value":0,"pack":true,"rarity":1+int(node.threat),"pack_ids":node.reward_ids})
	step_orbits(dt)

func step_orbits(dt:float):
	orbit_moves=0;remote_orbit_skips=0
	var reduced=use_remote_orbits and battle.cave_enabled() and orbit_activity_view.has_area()
	var active_radius=2500.0
	var observers:Array=[]
	if reduced:
		for i in player.parts.size():
			if player.parts[i].hp<=0:continue
			var core:Dictionary=player.effective_core(i)
			var reach=db.range_units(core.get("turretRange",1))*48.0*(1+player.stats.get("17" if i==0 else "3",0.0)+player.upgrade_bonus(core.id,"RangePercent"))
			active_radius=maxf(active_radius,player.head.distance_to(player.parts[i].position)+reach+1024)
		for actor in battle.enemies:
			if actor.role=="friendly" and actor.hp>0:observers.append(Vector3(actor.position.x,actor.position.y,1800))
		for drone in battle.drones:observers.append(Vector3(drone.position.x,drone.position.y,1800))
		for bullet in battle.bullets:observers.append(Vector3(bullet.position.x,bullet.position.y,1024))
		for hole in battle.special.black_holes:observers.append(Vector3(hole.position.x,hole.position.y,float(hole.radius)+512))
	for actor in battle.enemies:
		if actor.get("orbit_speed",0) != 0:
			actor.orbit_offset = Vector2(actor.orbit_offset).rotated(actor.orbit_speed*dt)
			var remote=reduced and actor.get("mission_controlled",false) and actor.role!="friendly" and actor.hp>0
			if remote:
				var at:Vector2=actor.position
				remote=not orbit_activity_view.has_point(at) and at.distance_squared_to(player.head)>active_radius*active_radius
				remote=remote and float(actor.get("feedback_left",0))<=0 and float(actor.get("stun",0))<=0 and not actor.has("insect_control") and Vector2(actor.get("knockback_velocity",Vector2.ZERO)).is_zero_approx()
				var soft:Dictionary=actor.get("soft_body",{})
				remote=remote and float(soft.get("hold",0))<=0 and float(soft.get("pull_left",0))<=0
				if remote:
					for observer:Vector3 in observers:
						if at.distance_squared_to(Vector2(observer.x,observer.y))<=observer.z*observer.z:remote=false;break
			if remote:
				# Only distant, unengaged map orbits use a slower collision cadence.
				# Their phase/angle, combat timers and all nearby actors still tick
				# every frame. Each move retains the continuous rock sweep.
				var elapsed=float(actor.get("remote_orbit_elapsed",float(int(actor.uid)%4)/60.0))+dt
				actor.remote_orbit_elapsed=fmod(elapsed,REMOTE_ORBIT_INTERVAL) if elapsed>=REMOTE_ORBIT_INTERVAL else elapsed
				if elapsed<REMOTE_ORBIT_INTERVAL:
					actor.angle+=actor.orbit_speed*dt;remote_orbit_skips+=1;continue
			else:actor.erase("remote_orbit_elapsed")
			battle.move_actor(actor,actor.origin+actor.orbit_offset)
			actor.angle+=actor.orbit_speed*dt
			orbit_moves+=1
