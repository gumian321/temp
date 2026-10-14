extends RefCounted
var achievements
var notifications:Array=[]
var recycled_packs:Array=[]
var achievement_timer=0.0
var collected_scraps=0
var roster_boss_kills=0

const MissionDirector = preload("res://scripts/mission_director.gd")
const MapDirector = preload("res://scripts/map_director.gd")
const RewardDirector = preload("res://scripts/reward_director.gd")
var rewards
var map_director
var director
var db
var save
var player
var combat
var mission: Dictionary
var objective: Dictionary
var configuration: Dictionary
var mode: Dictionary
var elapsed = 0.0
var duration = 0.0
var heat = 0.0
var scraps = 0
var level = 0
var packs = 0
var opened = 0
var finished = false
var won = false
var result: Dictionary = {}
var timers = {"swarm": 2.0, "wave": 4.0, "patrol": 5.0}
var fleet_flags: Array = []
var offers: Array = []
var rng = RandomNumberGenerator.new()

func _init(source, persistence, centipede, battle, selected: Dictionary, difficulty: int):
	db = source
	save = persistence
	player = centipede
	combat = battle
	mission = selected
	if mission.get("isOffsetPlayer",false):
		var offset=Vector2(float(mission.playerYOffset)*48,0)
		player.head=offset
		for i in player.history.size():player.history[i]+=offset
		player.refresh_positions()
		for drone in combat.drones:drone.position=player.parts[drone.owner].position
	objective = mission.MissionsObjectiveList[difficulty]
	configuration = db.asset(objective.objectiveAIConfiguration)
	combat.despawn_radius=float(configuration.get("despawningRadius",100))
	combat.patrol_radius=float(configuration.get("PatrolSpawningRadius",75))
	duration = float(objective.objectiveTime) * 60.0
	var config: Dictionary = db.prefabs.get(objective.objectivePrefab, {})
	for c in config.get("components", []):
		if str(c["class"]).ends_with("ModeManager"):
			mode = c
	var d: Dictionary = db.stores.MissionDataStore.DifficultiesList[difficulty]
	combat.health_modifier = float(d.enemiesHealthModifier)
	combat.damage_modifier = float(d.enemiesDamageModifier)
	rng.seed = 20261012
	director = MissionDirector.new(self)
	map_director = MapDirector.new(self)
	rewards = RewardDirector.new(self)
	achievements=preload("res://scripts/achievements.gd").new(db,save,player,combat)

func step(dt: float):
	if finished:
		return
	track_character_bosses()
	step_recycled_packs(dt)
	elapsed += dt
	achievement_timer+=dt
	if achievement_timer>=1:achievement_timer=0;achievements.check_build()
	heat = elapsed / maxf(1.0, duration)
	combat.heat = heat
	for key in timers:
		timers[key] -= dt
		if timers[key] <= 0:
			spawn_group(key)
	step_local_spawners(dt)
	map_director.step(dt)
	director.step(dt)
	for drop in combat.loot.duplicate():
		if drop.has("reserved_by"):continue
		if drop.get("delivered",false):
			combat.effects.append({"position":player.head,"radius":20,"life":0.12,"kind":"pickup","particle_type":304})
			scraps += int(drop.value)
			collected_scraps += int(drop.value)
			if drop.pack:
				rewards.enqueue(false,drop)
			combat.loot.erase(drop)
	var cost = maxi(1, int(round(float(db.stores.RewardDataStore.ScrapsPerRewardPack) * maxf(1, player.parts.size() - 1 + packs))))
	while scraps >= cost:
		scraps -= cost
		level += 1
		rewards.enqueue(true)
		cost = maxi(1, int(round(float(db.stores.RewardDataStore.ScrapsPerRewardPack) * maxf(1, player.parts.size() - 1 + packs))))
	if player.parts[0].hp <= 0:
		finish(false)
	elif mission.get("isTimeEndCondition", false) and elapsed >= duration:
		finish(bool(mission.isPlayerWinWhenTimerIsOver))

func spawn_fleet(types, radius: float, objective_boss: bool = false, point = null):
	for type in db.packed(types):
		var id: String = db.pool.get(str(type), "")
		var pos: Vector2 = player.head + Vector2.from_angle(rng.randf() * TAU) * radius * 48
		if point is Vector2: pos = point
		combat.spawn(id, pos, "", objective_boss)

func choose(entries: Array) -> Dictionary:
	var list = entries.filter(func(x): return minf(heat, 1.0) >= float(x.get("entryHeatPercent", 0)) and minf(heat, 1.0) <= float(x.get("exitHeatPercent", 1)))
	if list.is_empty():
		return {}
	var total = 0.0
	for x in list:
		total += float(x.get("probablity", 1))
	var number = rng.randf() * total
	for x in list:
		number -= float(x.get("probablity", 1))
		if number <= 0:
			return x
	return list.back()

func spawn_group(key: String):
	if director != null and director.boss_pause > 0:
		timers[key] = director.boss_pause
		return
	var enabled_key: String = {"swarm": "IsAISwarmSpawnerActive", "wave": "IsAIWaveSpawnerActive", "patrol": "IsAIPatrolSpawnerActive"}[key]
	if not configuration.get(enabled_key, false):
		timers[key] = 5.0
		return
	var active = combat.enemies.filter(func(e): return e.group=="ambient_"+key and e.parent==0).size()
	if key=="patrol":active=combat.patrols.size()
	var boss = combat.enemies.any(func(e): return e.kind=="AIBossUnit" and e.active)
	var percent = float(configuration.get({"swarm":"AISwarmSpawnerBossPercent","wave":"AIWaveSpawnerBossPercent","patrol":"AIPatrolSpawnerBossPercent"}[key],1)) if boss else 1.0
	var radius = float(configuration.get({"swarm":"swarmSpawningRadius","wave":"waveSpawningRadius","patrol":"PatrolSpawningRadius"}[key],40))
	var count = 0
	var entries: Array = []
	if key=="swarm":
		timers[key] = float(configuration.SwarmingSpawningDelay)
		count = int(clampi(roundi(heat*float(configuration.MaxSwarmingUnits)),int(configuration.MinSwarmingUnits),int(configuration.MaxSwarmingUnits))*percent)-active
		entries = configuration.aISwarmingList
	elif key=="patrol":
		timers[key] = 1.0
		count = int((clampi(roundi(heat*float(configuration.MaxPatrolUnits)),int(configuration.MinPatrolUnits),int(configuration.MaxPatrolUnits))-active)*percent)
		entries = configuration.aIPatrolsList
	else:
		timers[key] = clampf(roundf(heat*float(configuration.MaxWaveTimer)),float(configuration.MinWaveTimer),float(configuration.MaxWaveTimer))
		count = int(clampi(roundi(heat*float(configuration.MaxWaveCount)),int(configuration.MinWaveCount),int(configuration.MaxWaveCount))*percent)
		entries = configuration.aIWaveSwarmList
	var target_mission = not bool(configuration.get({"swarm":"IsAISwarmSpawnerPlayerTargeting","wave":"IsAIWaveSpawnerPlayerTargeting","patrol":"IsAIPatrolSpawnerPlayerTargeting"}[key],true))
	var center = director.target() if target_mission else player.head
	for i in range(maxi(0,count)):
		var entry = choose(entries)
		if entry.is_empty(): continue
		var id = entry.AIPrefab if key=="patrol" else db.pool.get(str(int(entry.AIPrefab)),"")
		var pos = center+Vector2.from_angle(rng.randf()*TAU)*radius*48
		if key=="swarm" and director.station_data.get("ActivateSpawners",false):
			var sources = combat.enemies.filter(func(e): return e.get("station_spawner",false) and e.hp>0)
			if sources.is_empty(): continue
			pos = sources[rng.randi_range(0,sources.size()-1)].position
		var before = combat.next_uid
		combat.spawn(id,pos)
		for e in combat.enemies:
			if e.uid>=before:
				e.group = "ambient_"+key
				e.target_mission = target_mission
				e.angle = (center-e.position).angle()

func percent_allowed(type: int, value: float) -> bool:
	var next = float(player.stats.get(str(type),0))+value
	var data: Dictionary = db.stores.PlayerDataStore
	return next >= float(data.minStatsPercentage) and next <= float(data.maxStatsPercentage)

func character_module_cap()->int:
	return player.module_cap() if player.has_method("module_cap") else int(db.stores.PlayerDataStore.maxBuiltCores)

func can_reward(r: Dictionary) -> bool:
	if r.is_empty() or not save.available(r.id): return false
	if r["class"] == "BlockReward":
		if player.get("character_id")!=null and player.get("character_id")!="centipede":return player.pending.is_empty()
		return player.parts.size()+player.pending.size()+player.reward_module_count(r)<=character_module_cap()+1
	if "LevelUp" in str(r["class"]): return int(player.levels.get(r.id,0))<int(db.stores.PlayerDataStore.get("levelUpsAllowed",3))
	if r["class"] == "MainCoreTurretReward": return player.hq_weapon != r.core
	if r["class"] == "MainCoreDroneReward": return combat.drones.filter(func(d): return d.owner==0).size()+int(r.dronesCount)<=int(db.stores.PlayerDataStore.maxHQDronesCount)
	if r["class"] == "PercentBasicReward": return percent_allowed(int(r.rewardType),float(r.percent))
	if r["class"] == "CrusedReward": return percent_allowed(int(r.buffRewardType),float(r.buffPercent)) and percent_allowed(int(r.debuffRewardType),float(r.debuffPercent))
	if r["class"] == "CountBasicReward":
		if not player.uses_build_actions() and int(r.rewardType) in [8,9,20]:return false
		match int(r.rewardType):
			8: return player.parts.size()>=3
			9: return player.parts.size()>=2 and player.parts.size()+int(r.rewardCount)<=character_module_cap()+1
			20: return player.parts.size()>=2
			21: return player.parts.filter(func(p): return not p.wall).size()-1>=int(r.rewardCount)
	return true

func roll_rewards() -> Array:
	if packs <= 0: return []
	if not offers.is_empty(): return offers
	offers = rewards.roll()
	return offers

func take_reward(r: Dictionary) -> bool:
	if r not in offers or not can_reward(r):
		return false
	match r["class"]:
		"BlockReward":
			for i in range(player.reward_module_count(r)):
				player.pending.append(r.blockCore)
				if preload("res://scripts/character_roster.gd").is_support(db,str(r.blockCore)):
					for id in save.record_support_module():notifications.append("虫巢解锁："+preload("res://scripts/character_roster.gd").config(id).display_name)
		"CountBasicReward":
			var key: String = {8: "swap", 9: "duplicate", 20: "move", 21: "wall"}.get(int(r.rewardType), "")
			if key != "":
				player.actions[key] += int(r.get("count", r.get("rewardCount", 1)))
		"PercentBasicReward":
			player.change_stat(int(r.rewardType), float(r.get("percent", r.get("rewardPercent", 0))))
		"CrusedReward":
			player.change_stat(int(r.buffRewardType), float(r.buffPercent))
			player.change_stat(int(r.debuffRewardType), float(r.debuffPercent))
		"MainCoreTurretReward":
			player.set_hq_weapon(r.core)
		"MainCoreDroneReward":
			for i in range(int(r.dronesCount)):
				if combat.drones.filter(func(d): return d.owner == 0).size() < int(db.stores.PlayerDataStore.maxHQDronesCount):
					combat.add_drone(0, db.asset(r.drone))
		_:
			player.levels[r.id] = int(player.levels.get(r.id, 0)) + 1
	player.refresh_upgrades()
	player.record_reward_feedback(r,combat.drones)
	# The targeted feedback event owns the acquisition notice exactly once.
	rewards.consume()
	opened += 1
	offers.clear()
	return true

func track_character_bosses():
	while roster_boss_kills<combat.boss_kills:
		roster_boss_kills+=1
		for id in save.record_boss_kill():notifications.append("虫巢解锁："+preload("res://scripts/character_roster.gd").config(id).display_name)

func finish(victory: bool):
	if finished:
		return
	track_character_bosses()
	save.end_character_run()
	finished = true
	won = victory
	var breakdown={1:int(combat.destruction / float(db.stores.RatingDataStore.AIHealthToDestructionRate)),3:combat.boss_score,4:player.built_score,6:opened*250,9:0,10:0,5:0}
	if victory:
		breakdown[9]=int(mode.get("MissionRating",25000))
		breakdown[10]=director.bonus(victory)
	if mode.get("class")=="EndlessModeManager":breakdown[5]=int(elapsed*float(mode.BonusRatingPerSecSurvived))
	var score:int=0
	for value in breakdown.values():score+=int(value)
	var grade = "F"
	var meta = 5
	for rating in db.stores.RatingDataStore.LetterRatingsList:
		if score >= int(rating.scoreValue):
			grade = str(rating.title)
			meta = int(rating.metaPoints)
			break
	result = {"won": won, "score": score, "grade": grade, "meta": meta, "kills": combat.kills, "time": elapsed,"breakdown":breakdown}
	save.state.meta += meta
	save.state.scores[mission.id] = maxi(int(save.state.scores.get(mission.id, 0)), score)
	if victory and objective.get("objectiveACHID") != null and objective.objectiveACHID not in save.state.achievements:
		save.state.achievements.append(objective.objectiveACHID)
	achievements.finish(self)
	save.save()

func step_local_spawners(dt: float):
	for e in combat.enemies.duplicate():
		var spawner = combat.source_component(e.components,"AISpawner")
		if spawner.is_empty() or e.hp<=0: continue
		var config: Dictionary = {}
		for candidate in configuration.HeatSpawnersList:
			if heat>=float(candidate.selectHeatPercent): config = candidate
		if config.is_empty(): continue
		e.spawn_timer = float(e.get("spawn_timer",config.timeBetweenSpawns))-dt
		if e.spawn_timer>0 or e.position.distance_to(director.target())>float(spawner.disToSpawn)*48: continue
		var count = combat.enemies.filter(func(a): return a.get("spawner_owner",0)==e.uid).size()
		if count>=int(config.maxSpawnCount): continue
		e.spawn_timer = float(config.timeBetweenSpawns)
		var types = db.packed(config.SpawnObjectsList)
		if types.is_empty(): continue
		var actor = combat.spawn(db.pool.get(str(types[rng.randi_range(0,types.size()-1)]),""),e.position)
		if not actor.is_empty(): actor.spawner_owner = e.uid

func step_recycled_packs(dt:float):
	for pack in recycled_packs.duplicate():
		pack.age+=dt
		pack.position=Vector2(pack.start).lerp(pack.target,minf(1,pack.age))
		if pack.age>=1.25:combat.spawn_scraps(pack.target,int(pack.count));recycled_packs.erase(pack)
