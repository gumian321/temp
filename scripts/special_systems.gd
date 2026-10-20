extends RefCounted
const Feedback = preload("res://scripts/weapon_feedback.gd")
const Formation = preload("res://scripts/radial_formation.gd")
const FlameWhip = preload("res://scripts/flame_whip.gd")
var flame_whips:Dictionary={}
var battle_ref: WeakRef
var db
var player
var mines: Array = []
var mine_rings:Dictionary={}
var black_holes: Array = []
func _init(battle):
	battle_ref = weakref(battle)
	db = battle.db
	player = battle.player
func battle(): return battle_ref.get_ref()
func mine_capacity(core:Dictionary)->int:
	return maxi(1,int(float(core.maxMinesCount)*(1+player.upgrade_bonus(core.id,"maxMinesCountPercent"))))
func mine_ring(core:Dictionary)->Array[Vector2]:
	var capacity=mine_capacity(core)
	if not mine_rings.has(capacity):mine_rings[capacity]=Formation.ring(capacity,maxf(144.0,capacity*26.0/TAU))
	return mine_rings[capacity]
func chip(field: String, level: int) -> float:
	if level<=0: return 0.0
	var values = db.stores.ChipsDataStore[field]
	if values is String: values = db.packed(values)
	return float(values[clampi(level-1,0,values.size()-1)])
func add_black_hole(b: Dictionary):
	var data: Dictionary = b.data
	battle().effects.append(Feedback.decorate({"kind":"hole_birth","position":b.position,"radius":40,"life":0.55},"blackhole",bool(b.friendly)))
	black_holes.append({"position":b.position,"life":float(data.projectileEffectAreaDuration),"radius":float(data.projectileEffectArea)*48*(1+chip("MammothAreaPercentBoost",int(b.chips.get(5,0)))),"damage":float(b.damage),"shield_damage":float(b.shield_damage),"friendly":b.friendly,"force":float(db.component(data.blackHoleObject,"BlackHoleController").get("maxForce",10))*48})
func process_destroyed_part(index: int):
	var part: Dictionary = player.parts[index]
	if part.hp > 0 or part.get("destroy_processed",false): return
	part.destroy_processed = true
	var core: Dictionary = db.asset(part.id)
	battle().segment_destroyed(index)
	battle().spawn_scraps(part.position,int(core.get("coreScraps",0)))
	if core["class"]=="PackCore":
		for j in range(battle().rng.randi_range(int(core.minPacksCount),int(core.maxPacksCount))):
			battle().loot.append({"position":part.position,"value":0,"pack":true})

func step(dt: float):
	for key in flame_whips.keys():
		flame_whips[key].idle=float(flame_whips[key].get("idle",0))+dt
		if flame_whips[key].idle>.3:flame_whips.erase(key)
	for i in range(player.parts.size()):
		var p: Dictionary = player.parts[i]
		var c: Dictionary = db.asset(p.id)
		var was_cloaked = bool(p.get("cloaked",false))
		p.cloaked = false
		if i>0 and c.get("isClockable",false):
			for neighbor_index in player.adjacent_part_indices(i, true):
				var neighbor: Dictionary = player.parts[neighbor_index]
				if db.asset(neighbor.id).get("name")=="Core_Clocking" and neighbor.hp>0 and neighbor.stun<=0:
					p.cloaked = true
		if p.cloaked and not was_cloaked: player.pulse_feedback(i,"cloak",0.65)
		if p.hp<=0:
			process_destroyed_part(i)
			continue
		if p.stun>0 or c["class"] not in ["MinesCore","MineSpawnerCore"]: continue
		if p.cooldown>0: continue
		var count = 1
		var anchored = c["class"]=="MinesCore"
		var choices: Array = []
		if anchored:
			var maximum = mine_capacity(c)
			if mines.filter(func(m): return m.owner==i and m.anchored).size()>=maximum: continue
			# Source rewards use negative recharge percentages, as interval reductions.
			# Keep the original unupgraded interval and a positive high-stack floor.
			p.cooldown = maxf(0.05,(1.0/maxf(0.05,float(c.minesRechargeRate)))*(1+player.upgrade_bonus(c.id,"minesRechargeRatePercent")))
			var occupied=mine_slots(i)
			for slot in maximum:
				if slot not in occupied:choices.append(slot)
		else:
			if player.velocity.length()<1: continue
			p.cooldown = maxf(0.05,float(c.minesSpawnRate)*(1+player.upgrade_bonus(c.id,"minesRechargeRatePercent")))
			count = int(c.minesCountPerSpawn)
			choices.assign(Formation.ring(count,float(c.get("spawnRadius",1))*48))
		if choices.is_empty(): continue
		p.organ_pulse=0.18
		player.pulse_chip_sources(i)
		for j in range(count):
			var slot=int(choices[battle().rng.randi_range(0,choices.size()-1)]) if anchored else j
			var offset:Vector2=mine_ring(c)[slot] if anchored else choices[j]
			var position:Vector2=p.position+offset.rotated(player.facing.angle())
			mines.append({"owner":i,"anchored":anchored,"slot":slot,"offset":offset,"position":position,"life":INF if anchored else 7.0,"data":db.asset(c.coreMine),"chips":player.chips(i),"fusion_multiplier":player.fusion_multiplier(i)})
			battle().effects.append(Feedback.decorate({"kind":"mine_arm","position":position,"radius":22,"life":0.3},"mine"))
	for mine in mines:
		mine.life -= dt
		if mine.anchored:
			if mine.owner>=player.parts.size() or player.parts[mine.owner].hp<=0: mine.life=0; continue
			var ring=mine_ring(db.asset(player.parts[mine.owner].id))
			mine.offset=ring[int(mine.slot)%ring.size()]
			mine.position = player.parts[mine.owner].position + Vector2(mine.offset).rotated(player.facing.angle())
		var enemy = battle().nearest(mine.position,24)
		if enemy.is_empty(): continue
		var projectile = {"class":"BasicProjectile","projectileDamage":mine.data.mineDamage,"fx_family":"mine"}
		var b = {"position":mine.position,"data":projectile,"damage":float(mine.data.mineDamage.hullDamage)*float(mine.get("fusion_multiplier",1)),"shield_damage":float(mine.data.mineDamage.shieldDamage)*float(mine.get("fusion_multiplier",1)),"friendly":true,"chips":mine.chips,"velocity":Vector2.RIGHT,"pierce":1,"hit":[]}
		b.damage *= battle().momentum.damage_multiplier()
		b.shield_damage *= battle().momentum.damage_multiplier()
		battle().hit_enemy(enemy,b)
		battle().explosion(mine.position,62,0.55,"mine")
		mine.life=0
	mines = mines.filter(func(m):return m.life>0)
	for hole in black_holes:
		hole.life-=dt
		if hole.life<=0:
			battle().effects.append(Feedback.decorate({"kind":"hole_collapse","position":hole.position,"radius":hole.radius,"life":0.65},"blackhole",bool(hole.friendly)))
		for e in battle().area_candidates(hole.position, hole.radius):
			if e.hp<=0 or not e.damageable or (e.role=="friendly" if hole.friendly else e.role!="friendly"): continue
			if e.position.distance_to(hole.position)<hole.radius:
				e.hp-=hole.damage*dt
				battle().erode_mineral(e,{"position":hole.position,"velocity":Vector2(hole.position).direction_to(e.position)})
				preload("res://scripts/soft_insect.gd").impact(e,Vector2(hole.position),Vector2(e.position)-Vector2(hole.position),hole.damage*dt,"blackhole")
				e.last_fx="blackhole"; e.last_friendly=hole.friendly
				e.last_death_direction=Vector2(e.position).direction_to(hole.position)
				if not e.mission_controlled and e.parent==0:
					var pull_delta=Vector2(hole.position)-Vector2(e.position)
					if dt>0:preload("res://scripts/soft_insect.gd").pull(e,pull_delta,minf(hole.force,pull_delta.length()/dt),dt)
					e.position = Vector2(e.position).move_toward(hole.position,hole.force*dt)
					battle().spatial_moved(e)
		if not hole.friendly:
			for i in range(player.parts.size()):
				if player.parts[i].position.distance_to(hole.position)<hole.radius: battle().hurt_player(i,hole.damage*dt,hole.shield_damage*dt)
	black_holes = black_holes.filter(func(h): return h.life>0)
func mine_slots(owner:int)->Array:
	return mines.filter(func(m):return m.owner==owner and m.anchored and m.life>0).map(func(m):return int(m.slot))
func continuous(core: Dictionary,at: Vector2,dir: Vector2,friendly: bool,chips: Dictionary,boost: float,dt: float,visual_owner:String="",range_boost:float=0.0):
	var projectile = db.asset(core.coreProjectile)
	var reach = db.range_units(core.get("turretRange",1))*48*maxf(0.0,1+range_boost)*(1+chip("MammothAreaPercentBoost",int(chips.get(5,0))))
	var damage = float(projectile.projectileDamage.hullDamage)*maxf(0.0,1+boost)*(1+chip("MammothDamagePercentBoost",int(chips.get(5,0))))*dt
	var shield_damage = float(projectile.projectileDamage.shieldDamage)*maxf(0.0,1+boost)*dt
	if friendly and not visual_owner.begins_with("enemy:"):
		# Continuous weapons receive the equivalent throughput of faster reloads.
		var multiplier = battle().momentum.damage_multiplier() * battle().momentum.rate_multiplier()
		damage *= multiplier
		shield_damage *= multiplier
	for e in battle().area_candidates(at, reach):
		if e.hp<=0 or not e.damageable or (e.role=="friendly" if friendly else e.role!="friendly"): continue
		var delta: Vector2 = battle().target_position(e)-at
		if delta.length()<reach and absf(angle_difference(dir.angle(),delta.angle()))<0.2:
			battle().hit_enemy(e,{"data":projectile,"damage":damage,"shield_damage":shield_damage,"position":at,"friendly":friendly,"chips":{},"velocity":dir,"pierce":1})
	if not friendly:
		for i in range(player.parts.size()):
			var delta: Vector2 = player.parts[i].position-at
			if delta.length()<reach and absf(angle_difference(dir.angle(),delta.angle()))<0.2: battle().hurt_player(i,damage,shield_damage)
	var key=visual_owner if not visual_owner.is_empty() else str(at)+str(friendly)
	if not flame_whips.has(key):flame_whips[key]={"phase":float(hash(key)%127)*.03}
	var curve=FlameWhip.advance(flame_whips[key],at,dir,reach,dt)
	# Replace the previous frame's tether, then allow a short anchored release.
	battle().effects=battle().effects.filter(func(e):return e.kind!="flame" or e.get("owner","")!=key)
	battle().effects.append(Feedback.decorate({"position":at,"end":at+dir*reach,"radius":reach,"life":0.14,"kind":"flame","owner":key,"curve":curve},"flame",friendly))
