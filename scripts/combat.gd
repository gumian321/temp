extends RefCounted

const SpecialSystems = preload("res://scripts/special_systems.gd")
const SoftInsect = preload("res://scripts/soft_insect.gd")
const Feedback = preload("res://scripts/weapon_feedback.gd")
var shot_serial = 0
var special
var barrages: Array = []
var db
var player
var enemies: Array = []
var patrols: Dictionary = {}
var despawn_radius=100.0
var patrol_radius=75.0
var bullets: Array = []
var effects: Array = []
var loot: Array = []
var loot_rng=RandomNumberGenerator.new()
var scrap_removal_timer=0.0
var drones: Array = []
var enemy_drones:Array=[]
var kills = 0
var destruction = 0.0
var boss_kills = 0
var boss_score = 0
var next_drone_uid=1
var statistics:Dictionary={}
var rng = RandomNumberGenerator.new()
var health_modifier = 1.0
var damage_modifier = 1.0
var next_uid = 1
var hit_count = 0
var audio_events: Array = []
var destroyed: Array = []
var heat = 0.0
var mission_target = Vector2.ZERO

func _init(source, centipede):
	db = source
	player = centipede
	rng.seed = 20261012
	loot_rng.seed=20321
	special = SpecialSystems.new(self)
	for id in db.stores.PlayerDataStore.playerDronesList:
		add_drone(0, db.asset(id))

func source_component(components: Array, type: String) -> Dictionary:
	for c in components:
		if c["class"] == type: return c
	return {}

func entity(uid: int) -> Dictionary:
	for e in enemies:
		if e.uid == uid: return e
	return {}

func spawn_actor(prefab: String, blueprint: Dictionary, at: Vector2, role: String = "", objective: bool = false) -> Dictionary:
	var source: Dictionary = db.prefabs.get(prefab, {})
	var unit: Dictionary = blueprint.unit
	var movement: Dictionary = {}
	for c in blueprint.components:
		if str(c["class"]).ends_with("Movement"): movement = c
	var hp = float(unit.get("maxHealth", unit.get("objectHealth", 100))) * health_modifier
	var e = {"uid": next_uid, "prefab": prefab, "source_id": blueprint.id, "name": source.get("name", blueprint.name), "kind": unit["class"], "unit": unit, "movement": movement, "position": at, "origin": at, "hp": hp, "max_hp": hp, "angle": 0.0, "cooldown": 0.0, "stun": 0.0, "guns": [], "parts": [], "radius": maxf(14.0, float(unit.get("formationSize", 1)) * 15.0), "role": role, "objective": objective, "age": 0.0, "warp": 0.0, "parent": 0, "offset": Vector2.ZERO, "render": load("res://scripts/render_state.gd").instantiate(blueprint.render,next_uid), "slots": blueprint.slots, "components": blueprint.components, "group": "", "damageable": unit["class"] not in ["AIBossUnit", "AIStation"], "boost_left": 0.0, "boost_cooldown": 0.0, "active": false, "range_modifier": 0.0, "damage_modifier": damage_modifier, "heat_speed": false, "target": Vector2.ZERO, "mission_controlled": false}
	next_uid += 1
	for slot in blueprint.slots:
		var core_id = slot.get("core")
		if slot.get("GetCoreFromDataStore",false):
			var choices: Array = []
			for entry in db.stores.AIDataStore.aICoreList:
				if minf(heat,1) >= float(entry.entryHeatPercent) and minf(heat,1) <= float(entry.exitHeatPercent):
					for i in range(int(entry.probablity)): choices.append(entry.aICore)
			if not choices.is_empty(): core_id = choices[rng.randi_range(0,choices.size()-1)]
		if core_id is String:
			e.guns.append({"id": core_id, "cooldown": rng.randf(), "angle": 0.0, "offset": Vector2(slot.x, slot.y) * 48.0})
	var ranges: Array=[]
	for gun in e.guns:
		var core=db.asset(gun.id)
		if core.has("coreProjectile"):ranges.append(db.range_units(core.get("turretRange",1)))
	e.stop_distance=float(unit.get("stoppingdDis",0))*48
	e.action_distance=e.stop_distance*1.5
	if unit.get("calculateDistances",false) and not ranges.is_empty():e.stop_distance=float(ranges.min())*48*0.8;e.action_distance=float(ranges.min())*48
	enemies.append(e)
	return e

func spawn(prefab: String, at: Vector2, role: String = "", objective: bool = false) -> Dictionary:
	var definitions: Array = db.entities.get(prefab, [])
	var spawned = {}
	var first = {}
	for blueprint in definitions:
		var e = spawn_actor(prefab, blueprint, at + Vector2(blueprint.x, blueprint.y) * 48.0, role, objective)
		spawned[blueprint.id] = e
		if blueprint.parent_unit == "0" and first.is_empty(): first = e
	for blueprint in definitions:
		if not spawned.has(blueprint.id): continue
		var e: Dictionary = spawned[blueprint.id]
		if spawned.has(blueprint.parent_unit):
			var parent: Dictionary = spawned[blueprint.parent_unit]
			e.parent = parent.uid
			e.offset = e.position - parent.position
			parent.parts.append(e.uid)
			if parent.kind == "AIBossUnit":
				e.range_modifier = float(parent.unit.get("bossRangeModifer", 0))
				e.damage_modifier = float(parent.unit.get("bossDamageModifer", 1)) * damage_modifier
	for e in spawned.values():
		if e.kind != "AIBossUnit": continue
		var selected = {}
		e.hp = 0.0
		for uid in e.parts:
			var part = entity(uid)
			var type = int(part.unit.aIBossPartType)
			if not selected.has(type):
				var choices: Array = db.kind("AIBossPart").filter(func(v): return int(v.bossThreatLevel) == int(e.unit.aIThreatLevel) and int(v.aIBossPartType) == type)
				if not choices.is_empty(): selected[type] = choices[rng.randi_range(0, choices.size() - 1)]
			if selected.has(type):
				part.guns.clear()
				for i in range(selected[type].coresList.size()):
					var slot = part.slots[i] if i < part.slots.size() else {"x": 0, "y": 0}
					part.guns.append({"id": selected[type].coresList[i], "cooldown": rng.randf(), "angle": 0.0, "offset": Vector2(slot.x, slot.y) * 48.0})
			e.hp += part.hp
		e.max_hp = e.hp
	var patrol=db.component(prefab,"AIPatrolManager")
	if not patrol.is_empty() and not first.is_empty():
		var members=spawned.values().filter(func(e):return e.kind=="AIPatrolUnit")
		var slow=1000.0
		for e in members:
			e.patrol=first.uid;e.patrol_offset=e.position-at
			slow=minf(slow,float(e.movement.get("enginePower",2)))
		patrols[first.uid]={"members":members.map(func(e):return e.uid),"position":at,"target":player.head+Vector2.from_angle(rng.randf()*TAU)*rng.randf()*patrol_radius*48,"chase":0.0,"speed":0.0,"max_speed":slow*0.5*48,"wait":0.0,"data":patrol,"movement":db.component(prefab,"AIPatrolMovement")}
	return first

func nearest(at: Vector2, reach: float = INF) -> Dictionary:
	var result = {}
	var best = reach * reach
	for e in enemies:
		if e.hp <= 0 or not e.damageable or e.role == "friendly":
			continue
		var distance = at.distance_squared_to(e.position)
		if distance < best:
			best = distance
			result = e
	return result

var target_grid:Dictionary={}
var target_grid_active=false
var projectile_grid:Dictionary={}
var projectile_grid_active=false
func rebuild_grid(grid:Dictionary,bounds:bool):
	grid.clear()
	for i in enemies.size():
		var e:Dictionary=enemies[i]
		if e.hp<=0 or not e.damageable or e.role=="friendly":continue
		var radius=Vector2.ONE*float(e.radius) if bounds else Vector2.ZERO
		var low=Vector2i(((Vector2(e.position)-radius)/256.0).floor());var high=Vector2i(((Vector2(e.position)+radius)/256.0).floor())
		for x in range(low.x,high.x+1):
			for y in range(low.y,high.y+1):
				var cell=Vector2i(x,y)
				if not grid.has(cell):grid[cell]=[]
				grid[cell].append(i)
func grid_candidates(grid:Dictionary,low_point:Vector2,high_point:Vector2)->Array:
	var low=Vector2i((low_point/256.0).floor());var high=Vector2i((high_point/256.0).floor());var indices:Dictionary={}
	for x in range(low.x,high.x+1):
		for y in range(low.y,high.y+1):
			for index in grid.get(Vector2i(x,y),[]):indices[index]=true
	var sorted=indices.keys();sorted.sort();var result:Array=[]
	for index in sorted:result.append(enemies[index])
	return result
func target_candidates(at:Vector2,reach:float)->Array:
	return grid_candidates(target_grid,at-Vector2.ONE*reach,at+Vector2.ONE*reach) if target_grid_active and is_finite(reach) else enemies
func projectile_candidates(b:Dictionary)->Array:
	if not projectile_grid_active:return enemies
	var low=Vector2(b.previous).min(b.position)-Vector2.ONE*float(b.radius)
	var high=Vector2(b.previous).max(b.position)+Vector2.ONE*float(b.radius)
	return grid_candidates(projectile_grid,low,high)

func target_for(core: Dictionary, at: Vector2, reach: float) -> Dictionary:
	var config:Dictionary=db.asset(core.get("radarConfiguration",""))
	var radar:String=config.get("class","ClosetTargetRadarConfiguration")
	var candidates:Array=[]
	var shielded:Array=[]
	var reach_squared=reach*reach
	for e in target_candidates(at,reach):
		if e.hp<=0 or not e.damageable or e.role=="friendly" or at.distance_squared_to(e.position)>=reach_squared:continue
		candidates.append(e)
		if config.get("priortizeShield",true) and e.stun<=0:
			for gun in e.guns:
				var shield=db.asset(gun.id)
				if shield.get("class")=="ShieldCore" and float(gun.get("shield",shield.maxShieldHealth))>0:shielded.append(e);break
	if candidates.is_empty():return {}
	if radar=="RandomRadarConfiguration":return candidates[rng.randi_range(0,candidates.size()-1)]
	if not shielded.is_empty():candidates=shielded
	var result:Dictionary={}
	var best=0.0 if radar in ["BiggestTargetRadarConfiguration","FurthestRadarConfiguration"] else (1.0 if radar=="LowestHealthTargetRadarConfiguration" else INF)
	for e in candidates:
		var value=at.distance_squared_to(e.position)
		match radar:
			"BiggestTargetRadarConfiguration","SmallestTargetRadarConfiguration":value=e.max_hp
			"LowestHealthTargetRadarConfiguration":
				if e.get("repair_owner",0)!=0:continue
				value=float(e.hp)/float(e.max_hp)
			"StunnedRadarConfiguration":
				if e.kind.begins_with("AI") or e.kind=="TraderUnit":result=e
				continue
		if (value>best if radar in ["BiggestTargetRadarConfiguration","FurthestRadarConfiguration"] else value<best):best=value;result=e
	return result

func fire(core: Dictionary, at: Vector2, direction: Vector2, friendly: bool, chips: Dictionary = {}, damage_boost: float = 0.0, single: bool = false, barrel_index: int = 0, visual_scale: float = 1.0):
	var sound = db.asset(core.get("coreTurret", "")).get("fireAudioClipType",0)
	var projectile: Dictionary = db.asset(core.get("coreProjectile", ""))
	if projectile.is_empty():
		return
	var family = Feedback.family(projectile)
	shot_serial += 1
	var sound_event = Feedback.shot_sound(family,shot_serial)
	sound_event.type = int(sound); sound_event.position = at
	audio_events.append(sound_event)
	var count = int(core.get("barrageProjectileCount", 1)) if not single else 1
	if count>1 and float(core.get("barrageInterval",0))>0:
		barrages.append({"core":core,"at":at,"direction":direction,"friendly":friendly,"chips":chips,"boost":damage_boost,"count":count-1,"barrel_index":1,"timer":float(core.barrageInterval),"visual_scale":visual_scale})
		count=1
	var barrel_prefab: String = db.asset(core.get("coreTurret", "")).get("turretsBarrels", "")
	var barrel_refs: Array = db.component(barrel_prefab,"TurretBarrelsController").get("barrels",[])
	var transforms: Dictionary = db.prefab_transforms.get(barrel_prefab,{})
	for i in range(count):
		if friendly:statistics.stat_BulletsFired=int(statistics.get("stat_BulletsFired",0))+1
		var barrel: Dictionary = {}
		if not barrel_refs.is_empty():barrel=transforms.get(str(int(barrel_refs[(barrel_index+i)%barrel_refs.size()].fileID)),{})
		var dir = direction.rotated(float(barrel.get("angle",0)))
		var muzzle = at + Vector2(float(barrel.get("x",0)),float(barrel.get("y",0))).rotated(direction.angle()+PI/2)*48*visual_scale
		effects.append(Feedback.decorate({"position":muzzle,"direction":dir,"radius":clampf(float(projectile.get("projectileDamage",{}).get("hullDamage",1))*0.15,2,10),"life":0.14,"kind":"muzzle","visual_scale":visual_scale},family,friendly))
		var damage: Dictionary = projectile.get("projectileDamage", {"hullDamage": 1, "shieldDamage": 1})
		var multiplier = (1.0 + damage_boost) * (1.0 + special.chip("MammothDamagePercentBoost", int(chips.get(5,0))))
		var b = {"position": muzzle, "previous": muzzle, "velocity": dir * float(projectile.get("projectileSpeed", 20)) * 48.0, "life": maxf(0.1, float(projectile.get("projectileLifeTime", 2))), "data": projectile, "friendly": friendly, "damage": float(damage.hullDamage) * multiplier, "shield_damage": float(damage.shieldDamage) * multiplier, "pierce": int(projectile.get("targetPiercingCount", 1)) + int(special.chip("PiercingTargetCount",int(chips.get(3,0)))), "chips": chips, "hit": [], "age":0.0, "direction":dir, "homing_speed":0.0,"rot_speed":0.0, "radius": 4.0 * (1.0 + float(chips.get(5, 0)) * 0.5)}
		b.fx_family = family; b.origin = muzzle
		if int(projectile.get("projectilePrefab",0)) in [45,46]:
			var target = nearest(at,db.range_units(core.get("turretRange",4))*48) if friendly else {}
			if not target.is_empty():
				effects.append(Feedback.decorate({"position":muzzle,"end":target.position,"life":0.25 if family=="rail" else 0.18,"radius":0,"kind":"chain"},family,friendly))
				b.pierce = 1
				b.chips = chips.duplicate()
				b.line_jumps = int(projectile.targetPiercingCount)-1+int(special.chip("PiercingTargetCount",int(chips.get(3,0))))
				hit_enemy(target,b)
			elif not friendly: hurt_player(0,b.damage,b.shield_damage)
		else: bullets.append(b)

var phase_times:Dictionary={}
var profile_enabled=OS.get_environment("RBPEW_PROFILE")=="1"
func mark_phase(label:String,started:int)->int:
	var now=Time.get_ticks_usec()
	if profile_enabled:phase_times[label]=int(phase_times.get(label,0))+now-started
	return now

func step(dt: float, aim: Vector2, shooting: bool):
	step_scraps(dt)
	player.begin_support_tick()
	var measured=Time.get_ticks_usec()
	step_patrols(dt)
	special.step(dt)
	measured=mark_phase("patrol_special",measured)
	for salvo in barrages.duplicate():
		salvo.timer -= dt
		if salvo.timer<=0:
			fire(salvo.core,salvo.at,salvo.direction,salvo.friendly,salvo.chips,salvo.boost,true,salvo.barrel_index,float(salvo.get("visual_scale",1)))
			salvo.barrel_index+=1
			salvo.count-=1
			salvo.timer+=float(salvo.core.barrageInterval)
			if salvo.count<=0: barrages.erase(salvo)
	rebuild_grid(target_grid,false);target_grid_active=true
	for i in range(player.parts.size()):
		var p: Dictionary = player.parts[i]
		p.recoil=maxf(0.0,float(p.get("recoil",0))-dt*42.0)
		p.impact_left=maxf(0.0,float(p.get("impact_left",0))-dt)
		p.cooldown -= dt
		p.stun = maxf(0, p.stun - dt)
		if p.hp <= 0 or p.stun > 0:
			continue
		var c: Dictionary = db.asset(player.hq_weapon if i == 0 else p.id)
		if c.has("coreProjectile"):
			var chips: Dictionary = player.chips(i)
			var emitter: Vector2 = player.weapon_origin(i)
			var reach = db.range_units(c.get("turretRange", 1)) * 48.0 * (1.0 + player.stats.get("17" if i == 0 else "3", 0.0) + player.upgrade_bonus(c.id, "RangePercent"))
			var target = target_for(c, p.position, reach)
			var dir: Vector2 = (aim - emitter).normalized()
			var manual: bool = i == 0 or chips.has(6)
			if not manual and not target.is_empty():
				dir = (target.position - emitter).normalized()
			p.angle = rotate_toward(p.angle,dir.angle(),deg_to_rad(float(c.get("turretRotateSpeed",360)))*dt)
			if db.asset(c.coreProjectile).get("class")=="ContinuousProjectile":
				if (manual and shooting) or (not manual and not target.is_empty()): special.continuous(c,emitter,Vector2.from_angle(p.angle),true,chips,player.stats.get("15",0.0),dt,"player:"+str(i))
				continue
			if p.cooldown <= 0 and ((manual and shooting) or (not manual and not target.is_empty())) and absf(angle_difference(p.angle,dir.angle()))<deg_to_rad(float(c.get("turretErrorAngle",2))):
				var rate = float(c.get("turretRateOfFire", 1)) * (1.0 + player.stats.get("13" if i == 0 else "2", 0.0) + player.upgrade_bonus(c.id, "RateOfFirePercent"))
				p.cooldown = 1.0 / maxf(rate, 0.01)
				fire(c, emitter, dir, true, chips, player.stats.get("14" if i == 0 else "15", 0.0) + player.upgrade_bonus(c.id, "DamagePercent"), false, int(p.get("barrel_index",0)),player.weapon_visual_scale(i))
				p.barrel_index=int(p.get("barrel_index",0))+1
				p.recoil=float(Feedback.profile(Feedback.family(c)).recoil)
		elif c["class"] == "ShieldCore":
			p.shield_delay -= dt
			if p.shield_delay <= 0:
				var capacity=float(c.maxShieldHealth)*(1+player.upgrade_bonus(c.id,"ShieldHealthPercent"))
				if p.get("shield_broken",false):
					p.shield=capacity/2;p.shield_broken=false;audio_events.append({"type":50,"position":p.position})
				else:p.shield = minf(capacity, p.shield + float(c.shieldRechargeRate)*(1+player.upgrade_bonus(c.id,"ShieldRechargeRatePercent")) * dt)
		elif c["class"] == "RepairCore":
			for neighbor_index in player.adjacent_part_indices(i, true):
				var other: Dictionary = player.parts[neighbor_index]
				if other.hp > 0:
					other.hp = minf(other.max_hp, other.hp + float(c.get("repairAmountPerSec", 4)) * dt)
		elif c["class"] == "DroneCore":
			ensure_drones(i, c)
	target_grid_active=false
	measured=mark_phase("player_weapons",measured)
	for e in enemies:
		e.feedback_left=maxf(0,float(e.get("feedback_left",0))-dt)
		e.fx_cooldown=maxf(0,float(e.get("fx_cooldown",0))-dt)
		if e.kind == "AIBossUnit":
			e.hp = 0.0
			for uid in e.parts:
				e.hp += maxf(0, entity(uid).get("hp", 0))
		if e.hp <= 0:
			continue
		e.age += dt
		SoftInsect.step(e,dt)
		e.warp = maxf(0, e.warp - dt)
		e.stun = maxf(0, e.stun - dt)
		if e.stun > 0 or e.warp > 0:
			continue
		var target: Vector2 = player.head if not e.get("target_mission", false) else mission_target
		if e.role == "friendly":
			var foe = nearest(e.position, 1400)
			if not foe.is_empty(): target = foe.position
		var delta: Vector2 = target - e.position
		var speed = float(e.movement.get("enginePower", 2)) * 48.0
		var stop = float(e.stop_distance)
		if e.unit.get("isDisableIfFar",false) and delta.length()>despawn_radius*48:e.despawn=true;continue
		if e.has("patrol") and patrols.has(e.patrol):
			delta=Vector2(patrols[e.patrol].position)+Vector2(e.patrol_offset)-Vector2(e.position)
			stop=24.0
		if e.kind == "TraderUnit":
			delta = -delta if e.role != "friendly" else Vector2.RIGHT

		if e.kind in ["AIStation", "AIStationPartController", "AIGuardUnitController", "AIBossPartController", "Asteroid", "ContainerObject", "SpawnerStation"] or e.mission_controlled:
			speed = 0
		if e.kind == "AIBossUnit":
			e.active = delta.length() < float(e.unit.get("bossActionRadiuos", 30)) * 48.0
			var boost = source_component(e.components, "AIBossBoostSystem")
			e.boost_cooldown -= dt
			e.boost_left -= dt
			if e.boost_left > 0:
				speed = (float(e.movement.enginePower) + float(e.movement.get("boostEnginePower", 5))) * 48.0
			elif e.boost_left > -dt:
				e.boost_cooldown = float(boost.get("boostTimerDelay", 10))
			elif e.active and e.boost_cooldown <= 0 and delta.length() > float(boost.get("boostActivationRadious", 7.5)) * 48 and absf(angle_difference(e.angle, delta.angle())) < deg_to_rad(float(boost.get("boostActivationAngle", 25))):
				e.boost_left = float(boost.get("boostDuration", 3))
			elif e.heat_speed:
				var factor = maxf(1.0, heat) if e.active else heat
				speed *= factor * (float(e.movement.get("speedAfterTimerModifier", 2)) if factor > 1 else 1.0)
		if e.parent != 0:
			var parent = entity(e.parent)
			if not parent.is_empty():
				e.position = parent.position + Vector2(e.offset).rotated(parent.angle)
				e.angle = parent.angle
				delta = target - e.position
		if e.kind=="AIFollowingUnit":
			var modifier=1.0 if delta.length()>float(e.movement.get("stoppingdDis",0))*48 else 0.0
			if delta.length()<float(e.movement.get("runningAwayDistance",0))*48:modifier=-float(e.movement.get("movingBackSpeedPercent",0.6))
			e.position+=delta.normalized()*speed*modifier*dt
			speed=0
		if e.kind=="AIPatrolUnit" and delta.length()>stop:
			var engine=float(e.movement.get("enginePower",2))
			var error=absf(rad_to_deg(angle_difference(e.angle,delta.angle())))
			var max_rotation=engine*25
			var desired_speed=0.0 if error>60 else (1-error/60)*engine*48
			var desired_rotation=max_rotation if error>60 else error/60*max_rotation
			e.moving_speed=lerpf(float(e.get("moving_speed",0)),desired_speed,minf(1,engine/2*dt))
			e.rotation_speed=lerpf(float(e.get("rotation_speed",0)),desired_rotation,minf(1,max_rotation/8*dt))
			e.position+=Vector2.from_angle(e.angle)*e.moving_speed*dt
			e.angle=rotate_toward(e.angle,delta.angle(),deg_to_rad(e.rotation_speed)*dt)
		else:
			if delta.length()>stop:e.position+=Vector2.from_angle(e.angle)*speed*dt
			if e.boost_left<=0 and not e.mission_controlled and e.parent==0:
				var rotation_speed=float(e.movement.get("enginePower",2))*float(e.movement.get("rotEngineModifier",12))
				if e.kind=="AIBossUnit" and e.heat_speed:rotation_speed*=maxf(1,heat) if e.active else heat
				e.angle=rotate_toward(e.angle,delta.angle(),deg_to_rad(rotation_speed)*dt)
		var kamikaze=source_component(e.components,"KamikazeTrigger")
		if not kamikaze.is_empty():
			for i in range(player.parts.size()):
				if player.parts[i].hp>0 and not player.parts[i].get("cloaked",false) and e.position.distance_to(player.parts[i].position)<e.radius+player.collision_radius(i):
					hurt_player(i,float(kamikaze.explosionDamage.hullDamage),float(kamikaze.explosionDamage.shieldDamage));e.hp=0;break
		if e.unit.get("UseActionDistance",false) and e.position.distance_to(target)>e.action_distance:continue

		for gun in e.guns:
			gun.angle = rotate_toward(gun.angle,delta.angle(),deg_to_rad(float(db.asset(gun.id).get("turretRotateSpeed",360)))*dt)
			gun.cooldown -= dt
			var core: Dictionary = db.asset(gun.id)
			if core.get("class")=="DroneCore":
				ensure_enemy_drones(e,gun,core);continue
			if core.get("class")=="ShieldCore":
				gun.shield_delay = float(gun.get("shield_delay",0))-dt
				if gun.shield_delay<=0:
					if gun.get("shield_broken",false):gun.shield=float(core.maxShieldHealth)/2;gun.shield_broken=false
					else:gun.shield = minf(float(core.maxShieldHealth),float(gun.get("shield",core.maxShieldHealth))+float(core.shieldRechargeRate)*dt)
				continue
			if absf(angle_difference(gun.angle,delta.angle()))>=deg_to_rad(float(core.get("turretErrorAngle",2))):continue
			if db.asset(core.get("coreProjectile","")).get("class")=="ContinuousProjectile":
				if delta.length()<db.range_units(core.get("turretRange",1))*48: special.continuous(core,e.position,delta.normalized(),e.role=="friendly",{},e.damage_modifier-1,dt,"enemy:"+str(e.uid)+":"+str(e.guns.find(gun)))
				continue
			if gun.cooldown <= 0 and e.position.distance_to(target) < db.range_units(core.get("turretRange", 1)) * 48 * (1.0 + e.range_modifier):
				fire(core, e.position + Vector2(gun.get("offset", Vector2.ZERO)).rotated(e.angle), Vector2.from_angle(gun.angle), e.role == "friendly", {}, e.damage_modifier - 1.0, false, int(gun.get("barrel_index",0)))
				gun.barrel_index=int(gun.get("barrel_index",0))+1
				gun.cooldown = 1.0 / maxf(0.1, float(core.get("turretRateOfFire", 1)))
	measured=mark_phase("enemy_ai",measured)
	step_drones(dt)
	step_enemy_drones(dt)
	measured=mark_phase("drones",measured)
	rebuild_grid(projectile_grid,true);projectile_grid_active=true
	for b in bullets:
		b.life -= dt
		b.previous = b.position
		b.age += dt
		if b.data["class"] in ["HomingProjectile", "AreaHomingProjectile"]:
			b.homing_speed = lerpf(b.homing_speed,float(b.data.maxMovingSpeed)*48,minf(1,float(b.data.acceleration)*dt))
			if b.age>=float(b.data.projectileTargetDelay):
				var target = nearest(b.position) if b.friendly else {"position":player.head}
				if not target.is_empty():
					b.rot_speed = lerpf(b.rot_speed,float(b.data.maxRotSpeed),minf(1,float(b.data.rotAcceleration)*dt))
					b.direction = Vector2.from_angle(rotate_toward(Vector2(b.direction).angle(),(Vector2(target.position)-Vector2(b.position)).angle(),deg_to_rad(b.rot_speed)*dt))
			b.velocity = Vector2(b.direction)*b.homing_speed
		if b.data["class"]=="SonicBasicProjectile": b.radius = minf(1,b.age)*float(b.data.sonicWaveLength)*24

		b.position += b.velocity * dt
		if b.friendly:
			for e in projectile_candidates(b):
				if e.hp <= 0 or e.warp>0 or not e.damageable or e.role == "friendly" or e.uid in b.hit:
					continue
				if Geometry2D.get_closest_point_to_segment(e.position, b.previous, b.position).distance_to(e.position) < e.radius + b.radius:
					hit_enemy(e, b)
					b.hit.append(e.uid)
					b.pierce -= 1
					if b.pierce <= 0:
						b.life = 0
						break
		else:
			for ally in enemies:
				if ally.role != "friendly" or ally.hp <= 0 or ally.warp > 0: continue
				if Geometry2D.get_closest_point_to_segment(ally.position, b.previous, b.position).distance_to(ally.position) < ally.radius + b.radius:
					hit_enemy(ally, b)
					b.life = 0
					break
			if b.life <= 0: continue
			for i in range(player.parts.size()):
				var p: Dictionary = player.parts[i]
				if p.hp > 0 and not p.get("cloaked",false) and Geometry2D.get_closest_point_to_segment(p.position, b.previous, b.position).distance_to(p.position) < player.collision_radius(i):
					hit_player(i,b)
					b.life = 0
					break
	projectile_grid_active=false
	measured=mark_phase("projectiles",measured)
	bullets = bullets.filter(func(b): return b.life > 0)
	for e in enemies:
		if e.hp <= 0:
			var kamikaze=source_component(e.components,"KamikazeTrigger")
			if not kamikaze.is_empty():
				for i in range(player.parts.size()):
					if player.parts[i].position.distance_to(e.position)<float(kamikaze.explosionArea)*48:hurt_player(i,float(kamikaze.explosionDamage.hullDamage),float(kamikaze.explosionDamage.shieldDamage))
			destroyed.append({"uid": e.uid, "kind": e.kind, "group": e.group, "parent": e.parent, "objective": e.objective, "position": e.position, "unit": e.unit})
			kills += 1
			var stat_key={"Asteroid":"stat_AsteroidsDestroyed","ContainerObject":"stat_ContainersDestroyed","AISwarmingUnit":"stat_ShipsDestroyed","AIFollowingUnit":"stat_ShipsDestroyed"}.get(e.kind,"")
			if stat_key!="":statistics[stat_key]=int(statistics.get(stat_key,0))+1
			if e.damageable: destruction += e.max_hp
			if e.kind == "AIBossUnit":
				boss_kills += 1
				statistics.stat_BossesKilled=boss_kills
				var key={3:"stat_EndBossKilled",4:"stat_MiniBossKilled",6:"stat_MidBossKilled"}.get(int(e.unit.get("aIThreatLevel",3)),"stat_EndBossKilled")
				statistics[key]=int(statistics.get(key,0))+1
				boss_score += int(e.unit.get("bossRating",5000))
				for pack in e.unit.get("rewardPacksList",[]):loot.append({"position":e.position,"value":0,"pack":true,"pack_ids":[pack],"rarity":3})
			if e.parent != 0:
				var parent = entity(e.parent)
				if not parent.is_empty():
					var warp = source_component(parent.components, "AIWarpManager")
					var remaining = parent.parts.filter(func(uid): return entity(uid).get("hp", 0) > 0).size()
					if warp.get("activateWarping", false) and remaining in db.packed(warp.get("PartsCountWarp")):
						parent.position = player.head + Vector2.from_angle(rng.randf() * TAU) * float(warp.get("warpRadius", 50)) * 48
						parent.warp = 0.5
						for uid in parent.parts:
							var child = entity(uid)
							if not child.is_empty(): child.warp = 0.5
			spawn_scraps(e.position,int(e.unit.get("scrapsCount",e.unit.get("totalScrapsOnDestroy",0))))
			if e.kind == "ContainerObject": loot.append({"position": e.position,"value":0,"pack":true,"rarity":int(e.unit.containerRarity)})
			if e.kind == "SpawnerStation":
				for i in range(int(e.unit.packsDropCount)): loot.append({"position":e.position,"value":0,"pack":true,"pack_ids":e.unit.stationRewardPacksList})
			explosion(e.position,float(e.unit.get("explosionSize",e.radius/24.0))*48.0,0.65,str(e.get("last_fx","impact")),bool(e.get("last_friendly",true)))
	enemies = enemies.filter(func(e): return e.hp > 0 and not e.get("despawn",false))
	for effect in effects:
		effect.life -= dt
	effects = effects.filter(func(e): return e.life > 0)
	# Remove destroyed mounts without severing the living body; remap owners.
	var removed: Array = []
	for i in range(1,player.parts.size()):
		if player.parts[i].hp<=0 and player.parts[i].get("destroy_processed",false): removed.append(i)
	if not removed.is_empty():
		for d in drones:
			if d.owner in removed:release_drone_target(d)
		drones = drones.filter(func(d): return d.owner not in removed)
		for d in drones: d.owner -= removed.filter(func(i):return i<d.owner).size()
		special.mines = special.mines.filter(func(m): return not m.anchored or m.owner not in removed)
		for m in special.mines: m.owner -= removed.filter(func(i):return i<m.owner).size()
		removed.reverse()
		for i in removed: player.parts.remove_at(i)
		player.refresh_positions()
		player.refresh_upgrades()

	player.end_support_tick()
	mark_phase("cleanup",measured)

func explosion(at: Vector2, radius: float, lifetime: float = 0.35, family: String = "impact", friendly: bool = true):
	# ParticlesSystem.cs selects a different recording for tiny / small / big blasts.
	var size=radius/48.0
	audio_events.append({"type":20 if size<=1.0 else (21 if size<=2.0 else 22),"position":at,"pitch":0.82 if family=="nuke" else 0.95,"feedback":family,"strength":clampf(radius/110.0,0.6,1.5)})
	effects.append(Feedback.decorate({"position":at,"radius":radius,"life":maxf(lifetime,1.15 if family=="nuke" else 0.65),"kind":"explosion"},family,friendly))

func impact_feedback(e: Dictionary, b: Dictionary, shielded: bool = false):
	var family = str(b.get("fx_family",Feedback.family(b.data)))
	e.last_fx=family; e.last_friendly=bool(b.get("friendly",true))
	# A shotgun volley and continuous damage still apply every hit, but their
	# embellishments are grouped per target so large builds remain readable.
	if float(e.get("fx_cooldown",0))>0: return
	e.fx_cooldown=0.12 if family=="flame" else 0.055
	var style=Feedback.profile(family)
	var axis=Vector2(b.get("velocity",Vector2.RIGHT)).normalized()
	if not shielded:
		e.feedback_left=0.095
		e.feedback_kick=axis*minf(8,style.weight*4)
	var kind="shield_hit" if shielded else "hit"
	var effect=Feedback.decorate({"position":e.position-axis*minf(16,float(e.get("radius",20))*0.45),"radius":20,"life":0.28 if family in ["emp","tesla","sonic"] else 0.22,"kind":kind,"particle_type":307 if shielded else 305+hit_count%2,"hit_pause":style.pause},family,bool(b.get("friendly",true)))
	effects.append(effect)
	audio_events.append({"type":-1,"position":e.position,"feedback":"emp" if shielded else family,"strength":0.6,"flesh":not shielded and SoftInsect.Brood.eligible(e),"flesh_strength":clampf(.6+style.weight*.25,.7,1.1)})

func hit_enemy(e: Dictionary, b: Dictionary):
	if e.has("patrol") and patrols.has(e.patrol):patrols[e.patrol].chase=float(patrols[e.patrol].data.get("ChaseDuration",3))
	for other in enemies:
		if other.hp<=0 or other.stun>0 or (other.role=="friendly")!=(e.role=="friendly"): continue
		for gun in other.guns:
			var shield = db.asset(gun.id)
			if shield.get("class")!="ShieldCore" or float(gun.get("shield",shield.maxShieldHealth))<=0: continue
			if other.position.distance_to(e.position)<float(shield.ShieldRange)*48:
				gun.shield = maxf(0,float(gun.get("shield",shield.maxShieldHealth))-float(b.shield_damage))
				gun.shield_delay = float(shield.shieldRechargeDelay)
				if gun.shield<=0:gun.shield_broken=true;gun.shield_delay=float(shield.maxShieldHealth)/2/float(shield.shieldRechargeRate)
				impact_feedback(e,b,true)
				SoftInsect.impact(e,Vector2(b.get("position",e.position)),Vector2(b.get("velocity",Vector2.RIGHT)),float(b.shield_damage)*.2,"shield")
				b.pierce=1
				return
	if b.data["class"]=="BlackHoleProjectile":
		special.add_black_hole(b)
		return
	impact_feedback(e,b)
	e.hp -= b.damage
	SoftInsect.impact(e,Vector2(b.get("position",e.position)),Vector2(b.get("velocity",Vector2.RIGHT)),float(b.damage),str(b.get("fx_family",Feedback.family(b.data))))
	if e.kind in ["Asteroid", "ContainerObject"]:
		var scraps = roundi((1.0-maxf(0,e.hp)/e.max_hp)*float(e.unit.get("totalScraps",0)))
		var difference = scraps-int(e.get("spawned_scraps",0))
		if difference > 0:spawn_scraps(e.position,difference)
		e.spawned_scraps = scraps
	hit_count += 1
	var typ: String = b.data["class"]
	if typ == "EMPBasicProjectile":
		e.stun = float(b.data.get("stunDuration", 1.5)) if e.unit.get("canBeStunned", true) else 0.0
		if e.stun>0:effects.append({"position":e.position,"radius":20,"life":0.1,"kind":"emp","particle_type":302,"duration":e.stun,"follow":e})
	if typ == "SonicBasicProjectile":
		projectile_grid_active=false;target_grid_active=false
		e.position += Vector2(b.velocity).normalized() * float(b.data.get("pushBackForce", 5)) * 48.0
	var area = float(b.data.get("projectileEffectArea", 0)) * 48.0 * (1+special.chip("MammothAreaPercentBoost",int(b.chips.get(5,0))))
	if b.chips.has(2):
		area = maxf(area, special.chip("ExplosionEffectArea",int(b.chips[2]))*48)
	if area > 0:
		for other in enemies:
			if other.uid != e.uid and other.damageable and (other.role != "friendly" if b.friendly else other.role == "friendly") and other.position.distance_to(e.position) < area:
				other.hp -= b.damage * (special.chip("ExplosionDamagePercent",int(b.chips[2])) if b.chips.has(2) and not b.data.has("projectileEffectArea") else 1.0)
				SoftInsect.impact(other,Vector2(e.position),(Vector2(other.position)-Vector2(e.position)).normalized(),float(b.damage),str(b.get("fx_family",Feedback.family(b.data))))
				impact_feedback(other,b)
		explosion(e.position,area,0.35,str(b.get("fx_family",Feedback.family(b.data))),bool(b.friendly))
	if typ == "BlackHoleProjectile":
		for other in enemies:
			if other.position.distance_to(e.position) < area * 2:
				other.position = Vector2(other.position).lerp(e.position, 0.5)
	if int(b.get("pierce",1))>1: return
	var jumps = int(b.get("chain_remaining",special.chip("chainTargetJumpCount",int(b.chips.get(4,0)))))+int(b.get("line_jumps",0))
	if jumps>0:
		var reach = special.chip("chainTargetRange",maxi(1,int(b.chips.get(4,0))))*48
		var candidates = enemies.filter(func(other): return other.hp>0 and other.damageable and other.uid!=e.uid and other.uid not in b.get("hit",[]) and (other.role!="friendly" if b.friendly else other.role=="friendly") and other.position.distance_to(e.position)<reach)
		candidates.sort_custom(func(left,right): return left.position.distance_squared_to(e.position)<right.position.distance_squared_to(e.position))
		if not candidates.is_empty():
			var other: Dictionary = candidates[0]
			var clone: Dictionary = b.duplicate(true)
			clone.hit = b.get("hit",[]).duplicate()
			clone.hit.append(e.uid)
			clone.chain_remaining = jumps-1
			clone.line_jumps = 0
			clone.pierce = 1
			clone.position = e.position
			clone.previous = e.position
			clone.velocity = (Vector2(other.position)-Vector2(e.position)).normalized()*maxf(480,Vector2(b.velocity).length())
			clone.direction = Vector2(clone.velocity).normalized()
			clone.age = 0.0
			clone.life = maxf(0.2,float(b.data.get("projectileLifeTime",1)))
			if int(b.data.get("projectilePrefab",0)) in [45,46]:
				effects.append(Feedback.decorate({"position":e.position,"end":other.position,"life":0.20,"radius":0,"kind":"chain"},str(b.get("fx_family",Feedback.family(b.data))),bool(b.friendly)))
				hit_enemy(other,clone)
			else: bullets.append(clone)
	if b.chips.has(1):
		var count = rng.randi_range(1,int(special.chip("shrapnelProjectileCount",int(b.chips[1]))))
		var shard: Dictionary = db.asset(db.stores.ChipsDataStore.shrapnelProjectile)
		for j in range(count):
			var clone: Dictionary = b.duplicate(true)
			clone.chips = {}
			clone.data = shard
			clone.fx_family = "flak"
			clone.origin = e.position
			clone.position = e.position
			clone.previous = e.position
			clone.velocity = Vector2.from_angle(TAU*j/count)*float(shard.projectileSpeed)*48
			clone.direction = Vector2(clone.velocity).normalized()
			clone.age = 0.0
			clone.damage *= special.chip("shrapnelDamagePercent",int(b.chips[1]))
			clone.shield_damage *= special.chip("shrapnelDamagePercent",int(b.chips[1]))
			clone.life = float(shard.projectileLifeTime)
			clone.hit = [e.uid]
			clone.pierce = 1
			clone.radius = 3.0
			bullets.append(clone)

func hit_player(index:int,b:Dictionary):
	var p:Dictionary=player.parts[index]
	if b.data["class"]=="BlackHoleProjectile":special.add_black_hole(b);return
	hurt_player(index,b.damage,b.shield_damage)
	if b.data["class"]=="EMPBasicProjectile":p.stun=maxf(p.stun,float(b.data.stunDuration))
	if b.data["class"]=="SonicBasicProjectile" and index==0:player.head+=Vector2(b.velocity).normalized()*float(b.data.pushBackForce)*48
	var radius=float(b.data.get("projectileEffectArea",0))*48
	if radius>0:
		for i in range(player.parts.size()):
			if i!=index and player.parts[i].position.distance_to(p.position)<radius:hurt_player(i,b.damage,b.shield_damage)
		explosion(p.position,radius,0.35,str(b.get("fx_family",Feedback.family(b.data))),bool(b.friendly))

func hurt_player(index: int, damage: float, shield_damage: float):
	var p: Dictionary = player.parts[index]
	if p.get("cloaked",false): return
	for i in player.parts.size():
		var shield:Dictionary=player.parts[i]
		var c: Dictionary = db.asset(shield.id)
		if c["class"] == "ShieldCore" and shield.hp>0 and shield.stun<=0 and shield.shield > 0 and shield.position.distance_to(p.position) < shield_range(i):
			shield.shield = maxf(0, shield.shield - shield_damage)
			if shield.shield<=0:
				shield.shield_broken=true
				audio_events.append({"type":52,"position":shield.position})
				shield.shield_delay=float(c.maxShieldHealth)*(1+player.upgrade_bonus(c.id,"ShieldHealthPercent"))/2.0/(float(c.shieldRechargeRate)*(1+player.upgrade_bonus(c.id,"ShieldRechargeRatePercent")))
			else:
				shield.shield_delay = float(c.shieldRechargeDelay)*(1+player.upgrade_bonus(c.id,"ShieldRechargeDelayPercent"))
				audio_events.append({"type":51,"position":shield.position})
			return
	p.hp -= damage
	p.impact_left=0.11
	effects.append({"position": p.position, "radius": 22, "life": 0.15, "kind": "hit","player_hit":true})

func shield_range(index:int)->float:
	var c:Dictionary=db.asset(player.parts[index].id)
	return float(c.ShieldRange)*48*(1+player.upgrade_bonus(c.id,"ShieldRangePercent"))*(1+special.chip("MammothAreaPercentBoost",int(player.chips(index).get(5,0))))

func ensure_drones(owner: int, core: Dictionary):
	var count = drones.filter(func(d): return d.owner == owner).size()
	for i in range(count, mini(int(core.get("maxDronesCount", 7)), int(core.DroneCount) + int(player.upgrade_bonus(core.id, "addDronesCount")))):
		add_drone(owner, db.asset(core.coreDrone))

func release_drone_target(d:Dictionary):
	var target:Dictionary=d.get("target",{})
	if not target.is_empty():
		if target.get("reserved_by",-1)==d.uid:target.erase("reserved_by");target.erase("carried")
		if target.get("repair_owner",-1)==d.uid:target.erase("repair_owner")
	d.target={};d.carrying=false;d.mode="return"

func step_drones(dt: float):
	for d in drones:
		if d.owner>=player.parts.size():release_drone_target(d);continue
		var home:Dictionary=player.parts[d.owner]
		if home.hp<=0 or home.stun>0:release_drone_target(d);continue
		var data:Dictionary=d.data
		var reach=db.range_units(data.get("droneRange",1))*48*(1+player.upgrade_bonus(data.id,"rangePercent"))
		var efficiency=1+player.upgrade_bonus(data.id,"efficiencyPercent")
		d.ping-=dt;d.cooldown-=dt
		if not d.target.is_empty():
			var valid=loot.has(d.target) if d.mode in ["pickup","carry"] else float(d.target.get("hp",0))>0
			if d.mode=="repair":valid=valid and d.target.hp<d.target.max_hp
			if d.mode=="attack":valid=valid and d.target.position.distance_to(home.position)<reach
			if not valid:release_drone_target(d)
		if d.target.is_empty() and d.ping<=0:
			d.ping=float(data.get("droneTargetPingDelay",2))
			var candidates:Array=[]
			if data["class"]=="EngineerDrone":
				candidates=player.parts.filter(func(p):return p.hp>0 and p.hp<p.max_hp and not p.has("repair_owner") and p.position.distance_to(home.position)<reach)
				candidates.sort_custom(func(a,b):return a.hp/a.max_hp<b.hp/b.max_hp)
				d.mode="repair"
			elif data["class"]=="ProjectileDrone":
				var target=nearest(home.position,reach)
				if not target.is_empty():candidates=[target]
				d.mode="attack"
			else:
				candidates=loot.filter(func(drop):return not drop.has("reserved_by") and float(drop.get("scatter_left",0))<=0 and drop.position.distance_to(d.position)<reach)
				candidates.sort_custom(func(a,b):return bool(a.pack) and not bool(b.pack))
				d.mode="pickup"
			if not candidates.is_empty():
				d.target=candidates[0];d.docked=false
				if d.mode=="repair":d.target.repair_owner=d.uid
				if d.mode=="pickup":d.target.reserved_by=d.uid
			else:d.mode="return"
		var target:Vector2=home.position if d.target.is_empty() or d.carrying else d.target.position
		var delta:Vector2=target-d.position
		var action_distance=float(data.droneCoreStopDistance if d.mode in ["return","carry"] else data.droneActionRange)*48
		if delta.length()<action_distance:
			match d.mode:
				"pickup":d.carrying=true;d.target.carried=true;d.mode="carry"
				"carry":
					d.target.delivered=true;d.target.erase("reserved_by");d.target.erase("carried");d.target={};d.carrying=false;d.mode="return"
					audio_events.append({"type":int(data.droneActionAudioType),"position":home.position})
				"repair":
					d.position=d.target.position;d.target.hp=minf(d.target.max_hp,d.target.hp+float(data.droneRepairAmountPerSec)*efficiency*dt)
					continue
				"attack":
					if d.cooldown<=0:
						fire({"coreProjectile":data.droneProjectile},d.position,delta.normalized(),true,player.chips(d.owner),efficiency-1+float(player.stats.get("15",0)))
						d.cooldown=1/maxf(0.1,float(data.droneRateOfFire)*(efficiency+float(player.stats.get("2",0))))
						audio_events.append({"type":int(data.droneActionAudioType),"position":d.position})
				"return":d.docked=true;d.position=home.position;d.speed=0;continue
		if d.docked:d.position=home.position;continue
		var speed_modifier=1+player.upgrade_bonus(data.id,"enginePowerPercent")
		var goal_speed=float(data.maxMovingSpeed)*48*speed_modifier
		if delta.length()<float(data.slowingDownDis)*48:goal_speed/=5
		d.speed=lerpf(d.speed,goal_speed,minf(1,float(data.acceleration)*speed_modifier*dt))
		d.rot_speed=lerpf(d.rot_speed,float(data.maxRotSpeed)*speed_modifier,minf(1,float(data.rotAcceleration)*dt))
		d.angle=rotate_toward(d.angle,delta.angle(),deg_to_rad(d.rot_speed)*dt)
		d.position+=Vector2.from_angle(d.angle)*d.speed*dt
		if d.carrying:d.target.position=d.position

func add_drone(owner: int, data: Dictionary):
	var uid=next_drone_uid;next_drone_uid+=1
	drones.append({"uid":uid,"owner":owner,"data":data,"position":player.parts[owner].position,"cooldown":0.0,"phase":rng.randf()*TAU,"target":{},"carrying":false,"docked":true,"mode":"return","ping":float(data.get("droneTargetPingDelay",2)),"speed":0.0,"angle":0.0,"rot_speed":0.0})

func ensure_enemy_drones(owner:Dictionary,gun:Dictionary,core:Dictionary):
	if not gun.has("drone_bay"):gun.drone_bay=next_drone_uid;next_drone_uid+=1
	var count=enemy_drones.filter(func(d):return d.bay==gun.drone_bay).size()
	for i in range(count,mini(int(core.DroneCount),int(core.maxDronesCount))):
		enemy_drones.append({"owner":owner.uid,"bay":gun.drone_bay,"data":db.asset(core.coreDrone),"position":owner.position,"angle":owner.angle,"speed":0.0,"rot_speed":0.0,"cooldown":0.0,"ping":0.0,"target":{},"docked":true,"friendly":owner.role=="friendly"})

func step_enemy_drones(dt:float):
	enemy_drones=enemy_drones.filter(func(d):return entity(d.owner).get("hp",0)>0 and not entity(d.owner).get("despawn",false))
	for d in enemy_drones:
		var owner:Dictionary=entity(d.owner);var data:Dictionary=d.data
		if owner.stun>0:continue
		var reach=db.range_units(data.droneRange)*48
		d.cooldown-=dt;d.ping-=dt
		if not d.target.is_empty() and (d.target.get("hp",0)<=0 or d.target.position.distance_to(owner.position)>reach or d.target.get("cloaked",false)):d.target={}
		if d.target.is_empty() and d.ping<=0:
			d.ping=float(data.droneTargetPingDelay)
			var candidates:Array=enemies.filter(func(e):return e.hp>0 and e.damageable and e.role!="friendly") if d.friendly else player.parts.filter(func(p):return p.hp>0 and not p.get("cloaked",false))
			if not d.friendly:candidates.append_array(enemies.filter(func(e):return e.hp>0 and e.role=="friendly" and e.damageable))
			candidates=candidates.filter(func(target):return target.position.distance_to(owner.position)<reach)
			candidates.sort_custom(func(a,b):return a.position.distance_squared_to(d.position)<b.position.distance_squared_to(d.position))
			if not candidates.is_empty():d.target=candidates[0];d.docked=false
		var target:Vector2=owner.position if d.target.is_empty() else d.target.position
		var delta=target-d.position
		if d.target.is_empty() and delta.length()<float(data.droneCoreStopDistance)*48:d.position=owner.position;d.docked=true;d.speed=0;continue
		if not d.target.is_empty() and delta.length()<float(data.droneActionRange)*48 and d.cooldown<=0:
			fire({"coreProjectile":data.droneProjectile},d.position,delta.normalized(),d.friendly,{},owner.damage_modifier-1)
			d.cooldown=1/maxf(0.1,float(data.droneRateOfFire));audio_events.append({"type":int(data.droneActionAudioType),"position":d.position})
		var goal_speed=float(data.maxMovingSpeed)*48
		if delta.length()<float(data.slowingDownDis)*48:goal_speed/=5
		d.speed=lerpf(d.speed,goal_speed,minf(1,float(data.acceleration)*dt))
		d.rot_speed=lerpf(d.rot_speed,float(data.maxRotSpeed),minf(1,float(data.rotAcceleration)*dt))
		d.angle=rotate_toward(d.angle,delta.angle(),deg_to_rad(d.rot_speed)*dt)
		d.position+=Vector2.from_angle(d.angle)*d.speed*dt

func step_patrols(dt:float):
	for key in patrols.keys():
		var group:Dictionary=patrols[key]
		var members: Array=group.members.filter(func(uid):return not entity(uid).is_empty())
		if members.is_empty():patrols.erase(key);continue
		if group.position.distance_to(player.head)>despawn_radius*48:
			for uid in members:entity(uid).despawn=true
			patrols.erase(key);continue
		var distance:float=group.position.distance_to(player.head)
		if distance<float(group.data.get("squadDetectionRange",10))*48:group.chase=float(group.data.get("ChaseDuration",3))
		else:group.chase=maxf(0,group.chase-dt)
		var target:Vector2=player.head if group.chase>0 else group.target
		if group.wait>0 and group.chase<=0:
			group.wait-=dt
			if group.wait<=0:group.target=player.head+Vector2.from_angle(rng.randf()*TAU)*sqrt(rng.randf())*patrol_radius*48
			continue
		var delta:Vector2=target-Vector2(group.position)
		if delta.length()<24 and group.chase<=0:group.wait=float(group.movement.get("waitingTime",3));continue
		group.speed=lerpf(group.speed,group.max_speed,minf(1,group.max_speed/48/10*dt))
		group.position+=delta.normalized()*group.speed*dt

func spawn_scraps(at:Vector2,count:int):
	if count<=0 or loot.filter(func(d):return not d.pack and not d.has('reserved_by')).size()>=250:return
	for i in count:
		var angle=loot_rng.randf_range(float(i)/count*TAU,float(i+1)/count*TAU)
		loot.append({'position':at,'value':1,'pack':false,'scatter_left':0.5,'scatter_from':at,'scatter_to':at+Vector2.from_angle(angle)*loot_rng.randf_range(0.5,2)*48})
func step_scraps(dt:float):
	for drop in loot:
		if float(drop.get('scatter_left',0))>0:
			drop.scatter_left=maxf(0,float(drop.scatter_left)-dt)
			drop.position=Vector2(drop.scatter_from).lerp(drop.scatter_to,1-float(drop.scatter_left)/0.5)
	scrap_removal_timer+=dt
	if scrap_removal_timer<0.25:return
	scrap_removal_timer=0
	var scraps=loot.filter(func(d):return not d.pack and not d.has('reserved_by') and float(d.get('scatter_left',0))<=0)
	if scraps.size()<=40:return
	var removed=0
	for drop in scraps:
		if drop.position.distance_to(player.head)>75*48:loot.erase(drop);removed+=1
		if removed>5:break
