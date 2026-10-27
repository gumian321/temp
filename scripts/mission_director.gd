extends RefCounted

# Source mission callbacks, with travelled-tunnel escort movement for caves.
var session: WeakRef
var db
var battle
var player
var mode: Dictionary
var objectives: Array = []
var initial_objectives = 0
var fleet_position = Vector2.ZERO
var fleet_goal = Vector2.ZERO
var fleet_data: Dictionary = {}
var fleet_ground: Dictionary = {}
var fleet_radius = 0.0
var cave_escort
var station_data: Dictionary = {}
var station_destroyed = false
var delayed: Array = []
var warp_left = 0.0
var started = false
var end_spawned = false
var endless_wave = 0
var gates: Dictionary = {}
var boss_pause = 0.0
var event_log: Array = []

func _init(run):
	session = weakref(run)
	db = run.db
	battle = run.combat
	player = run.player
	mode = run.mode
	setup()

func current():
	return session.get_ref()

func setup():
	var run = current()
	var prefab: String = run.objective.objectivePrefab
	var type: String = mode.get("class", "")
	fleet_data = db.component(prefab, "TraderFleetManager")
	station_data = db.component(prefab, "StationMissionManager")
	if type in ["BHModeManager", "GAModeManager"]:
		for blueprint in db.entities.get(prefab, []):
			if blueprint.unit["class"] != "TraderUnit": continue
			var at = Vector2(blueprint.x, blueprint.y) * 48
			var role = "friendly" if type == "GAModeManager" else "trader"
			var e = battle.spawn_actor(prefab, blueprint, at, role, true)
			e.mission_controlled = true
			e.group = "mission_traders"
			e.offset = at
			# The source overrides TraderUnit SpriteRenderer from the fleet's threat list.
			var threat = int(e.unit.get("aIThreatLevel", 0))
			var sprites: Array = fleet_data.get("tradersSpritesList", [])
			if threat < sprites.size() and not e.render.is_empty():
				e.render = e.render.duplicate(true)
				e.render[0].sprite = sprites[threat]
			objectives.append(e.uid)
		fleet_goal = Vector2(float(mode.get("fleetGoalXOffset", 600)) * 48, 0)
	elif type in ["SDestroyModeManager", "SProtectModeManager"]:
		var ring_index = 0
		var speeds:Array=db.scene_config.station_rotations.get(prefab,{}).get("rings",[])
		for station in db.prefabs[prefab].components:
			if station["class"] != "AIMissionStation": continue
			var parts: Array = station.aIStationPartsList
			for i in range(parts.size()):
				var part: Dictionary = db.asset(parts[i])
				var part_prefab: String = db.pool.get(str(int(part.prefabType)), "")
				var angle = -PI * 0.5 + TAU * i / parts.size()
				var at = Vector2.from_angle(angle) * float(station.stationRange) * 48
				var e = battle.spawn(part_prefab, at, "friendly" if type == "SProtectModeManager" else "station", true)
				if e.is_empty(): continue
				e.mission_controlled = true
				e.group = "mission_station"
				e.station_ring = ring_index
				e.station_speed=-float(speeds[ring_index]) if ring_index<speeds.size() else 0.0
				e.station_radius = float(station.stationRange) * 48
				e.station_angle = angle
				e.angle = angle + PI * 0.5
				e.guns.clear()
				for j in range(part.coresList.size()):
					var slot: Dictionary = e.slots[j] if j < e.slots.size() else {"x": 0, "y": 0}
					e.guns.append({"id": part.coresList[j], "cooldown": 0.0, "angle": e.angle, "offset": Vector2(slot.x, slot.y) * 48})
				for health in station_data.stationPartsHealthsList:
					if int(health.aIThreatLevel) == int(part.aIThreatLevel): e.hp = float(health.partHealth) * battle.health_modifier
				e.max_hp = e.hp
				var threat = int(part.aIThreatLevel)
				if threat < station_data.stationsPartSpritesList.size() and not e.render.is_empty():
					e.render = e.render.duplicate(true)
					e.render[0].sprite = station_data.stationsPartSpritesList[threat]
				objectives.append(e.uid)
			ring_index += 1
	if station_data.get("ActivateSpawners",false):
		for rim in station_data.SpawnerRimsList:
			for i in range(int(rim.spawnerCount)):
				var angle = -PI*0.5+TAU*i/int(rim.spawnerCount)
				var e = battle.spawn(db.pool["408"],Vector2.from_angle(angle)*float(rim.spawnersYPos)*48,"station")
				if e.is_empty(): continue
				e.station_spawner = true
				e.station_speed=-float(db.scene_config.station_rotations.get(prefab,{}).get("spawners",{}).get(str(int(rim.rimObject.fileID)),0))
				e.mission_controlled = true
				e.station_radius = float(rim.spawnersYPos)*48
				e.station_angle = angle
	initial_objectives = objectives.size()
	if type=="GAModeManager" and battle.cave_enabled() and initial_objectives>0:
		cave_escort=preload("res://scripts/cave_escort.gd").new()
		var ships=living_objectives()
		for e in ships:fleet_radius=maxf(fleet_radius,float(e.radius))
		fleet_goal=battle.terrain.safe_position(fleet_goal,fleet_radius+2)
		cave_escort.setup(battle.terrain,player,ships,fleet_data,fleet_goal)
		fleet_position=ships[0].position
	elif type in ["BHModeManager","GAModeManager"] and battle.terrain!=null:
		for e in living_objectives(): fleet_radius=maxf(fleet_radius,Vector2(e.offset).length()+float(e.radius))
		fleet_position=battle.terrain.safe_position(fleet_position,fleet_radius)
		for e in living_objectives():
			e.position=fleet_position+e.offset;e.ground_previous=e.position
	started = true
	event_log.append({"event": "setup", "mode": type, "objectives": initial_objectives})

func living_objectives() -> Array:
	return battle.enemies.filter(func(e): return e.uid in objectives and e.hp > 0)

func target() -> Vector2:
	if mode.get("class") == "GAModeManager": return fleet_position
	if mode.get("class") == "SProtectModeManager": return Vector2.ZERO
	return player.head

func arrow_target() -> Vector2:
	if mode.get("class") in ["BHModeManager", "GAModeManager"]: return fleet_position
	if mode.get("class") in ["SDestroyModeManager", "SProtectModeManager"]: return Vector2.ZERO
	for e in battle.enemies:
		if e.kind == "AIBossUnit" and e.objective: return e.position
	return player.head

func spawn_wave(types, name: String, radius: float = -1.0, point = null):
	var run = current()
	if radius < 0: radius = float(run.configuration.get("bossSpawningRadius", 100))
	var before = battle.next_uid
	run.spawn_fleet(types, radius, name == "survival_final", point,name)
	for e in battle.enemies:
		if e.uid >= before:
			e.group = name
			e.target_mission = not bool(run.configuration.get("IsAIBossSpawnerPlayerTargeting", true))
			if name == "survival_final": e.heat_speed = true
	gates[name] = true
	event_log.append({"event": "spawn_boss_wave", "group": name, "time": run.elapsed})

func step(dt: float):
	var run = current()
	if run.finished: return
	boss_pause = maxf(0, boss_pause - dt)
	var type: String = mode.get("class", "")
	var living = living_objectives()
	for e in battle.enemies:
		if e.has("station_radius"):
			e.station_angle += deg_to_rad(float(e.get("station_speed",0)))*dt
			battle.move_actor(e,Vector2.from_angle(e.station_angle)*e.station_radius)
			e.angle = e.station_angle+PI*0.5
	if type in ["BHModeManager", "GAModeManager"]:
		var previous_warp = warp_left
		warp_left = maxf(0, warp_left - dt)
		if previous_warp > 0 and warp_left == 0:
			fleet_position = player.head + Vector2.from_angle(run.rng.randf() * TAU) * float(mode.get("fleetWarpDistance", 50)) * 48
			if battle.terrain!=null:fleet_position=battle.terrain.safe_position(fleet_position,fleet_radius)
		if cave_escort!=null:
			fleet_position=cave_escort.step(dt,living,fleet_goal)
		elif warp_left <= 0:
			var direction = (fleet_goal - fleet_position).normalized()
			var moving = true
			if type == "BHModeManager": direction = (fleet_position - player.head).normalized()
			else: moving = fleet_position.distance_to(player.head) < float(fleet_data.disFromPlayerToMove) * 48
			if moving:
				if battle.terrain!=null:direction=battle.terrain.direction(fleet_position,fleet_position+direction*1800,fleet_radius,fleet_ground)
				var next=fleet_position+direction*float(fleet_data.movingSpeed)*48*dt
				fleet_position=battle.terrain.move(fleet_position,next,fleet_radius) if battle.terrain!=null else next
		for e in living:
			if cave_escort==null:e.position = fleet_position + e.offset
			e.ground_previous=e.position
			e.warp = warp_left
		if living.is_empty() and initial_objectives > 0:
			run.finish(type == "BHModeManager")
			return
		if type == "GAModeManager" and fleet_position.distance_to(fleet_goal) < float(fleet_data.disFromTargetToWin) * 48:
			run.finish(true)
			return
	if type in ["SProtectModeManager", "SDestroyModeManager"]:
		if living.is_empty() and initial_objectives > 0:
			station_destroyed = true
			battle.explosion(Vector2.ZERO, 110.0, 0.65, "impact")
			run.finish(type == "SDestroyModeManager")
			return
	if type == "SurvivalModeManager":
		if run.elapsed >= 15 and not end_spawned:
			end_spawned = true
			spawn_wave(mode.EndBossFleetList, "survival_final", float(mode.EndBossSpawningRadius))
		for key in ["MiniBossFleet", "MidBossFleet"]:
			if mode.has(key) and run.heat > float(mode[key].fleetPercent) and not gates.has(key): spawn_wave(mode[key].fleetTypes, key)
		if end_spawned and not run.pending_fleet("survival_final") and not battle.enemies.any(func(e): return e.group == "survival_final"):
			run.finish(true)
			return
	elif type == "EndlessModeManager":
		var round_index = int(floor(run.heat))
		for round in range(round_index + 1):
			for i in range(mode.bossesSpawnPercent.size()):
				var key = "endless_%d_%d" % [round, i]
				if run.heat > float(round) + float(mode.bossesSpawnPercent[i]) and not gates.has(key):
					var waves: Array = mode.endlessBossFleet.BossFleetWaves
					var index = mini(endless_wave, waves.size() - 1)
					var types: Array = db.packed(waves[index].BossFleetWaves)
					for added in range(maxi(0, endless_wave - waves.size() + 1)): types.append(int(mode.endlessBossFleet.PrefabToAddAfterMaxWaves))
					spawn_wave(types, key)
					endless_wave += 1
	else:
		var progress = run.heat
		if type == "BHModeManager": progress = 1.0 - float(living.size()) / maxf(1, initial_objectives)
		var fleets: Array = mode.get("BossesFleetsList", [])
		for i in range(fleets.size()):
			var key = "mission_wave_%d" % i
			if progress > float(fleets[i].fleetPercent) and not gates.has(key):
				gates[key] = true
				if type == "BHModeManager":
					if fleet_data.get("allowWarping", false) and warp_left <= 0: warp_left = 2.0
					delayed.append({"remaining": 4.0, "types": fleets[i].fleetTypes, "name": key})
				else: spawn_wave(fleets[i].fleetTypes, key)
	for event in delayed.duplicate():
		event.remaining -= dt
		if event.remaining <= 0:
			spawn_wave(event.types, event.name, -1.0, fleet_position)
			delayed.erase(event)
	for event in battle.destroyed:
		if event.kind == "AIBossUnit":
			if not run.pending_fleet(event.group) and not battle.enemies.any(func(e): return e.group == event.group):
				boss_pause = float(db.stores.AIDataStore.get("spawningPauseAfterBoss", 5))
				event_log.append({"event": "boss_wave_destroyed", "group": event.group, "time": run.elapsed})
	battle.destroyed.clear()
	battle.mission_target = target()

func escort_brief()->Dictionary:
	if mode.get("class")!="GAModeManager":return {}
	var living=living_objectives()
	var state="moving" if fleet_position.distance_to(player.head)<float(fleet_data.disFromPlayerToMove)*48 else "far"
	if cave_escort!=null:state=cave_escort.status
	var total_health=0.0;var health=0.0
	for e in living:health+=maxf(0,e.hp);total_health+=e.max_hp
	var distance=fleet_position.distance_to(fleet_goal)
	var initial_distance=cave_escort.start_distance if cave_escort!=null else fleet_goal.length()
	return {"state":state,"cave":cave_escort!=null,"alive":living.size(),"total":initial_objectives,"health":health/maxf(1,total_health),"distance":distance,"separation":fleet_position.distance_to(player.head),"range":float(fleet_data.disFromPlayerToMove)*48,"progress":clampf(1-distance/maxf(1,initial_distance),0,1)}

func bonus(victory: bool) -> int:
	if not victory: return 0
	var run = current()
	var type: String = mode.get("class", "")
	if type == "GAModeManager": return int(living_objectives().size() * float(mode.BonusRatingPerTraderSurvived))
	if type == "SProtectModeManager": return int(living_objectives().size() * float(mode.BonusRatingPerStationPartSurvived))
	var rate = float(mode.get("RatingPerSecEarly", mode.get("BonusRatingPerSecEarly", 0)))
	return int(maxf(0, run.duration - run.elapsed) * rate)
