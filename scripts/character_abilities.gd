extends RefCounted
const Tether=preload("res://scripts/tether_motion.gd")
## Run-owned abilities. Only Combat.step advances timers; menus cannot tick skills.
var battle_ref: WeakRef
var combat:
	get: return battle_ref.get_ref()
var player
var cooldown = 0.0
var active = 0.0
var armor = 100.0
var armor_delay = 0.0
var threads: Array = []
var released_threads: Array = []
var emitter_pose:Dictionary={}
var rush_hit: Dictionary = {}
var aim = Vector2.ZERO
var rush_direction = Vector2.RIGHT
var charge = 0.0
var reset_serial = -1

func _init(battle):
	battle_ref = weakref(battle)
	player = battle.player
	reset()

func supported() -> bool:
	return player.has_method("configure_character")

func reset():
	cooldown = 0; active = 0; armor = 100; armor_delay = 0; charge = 0
	threads.clear(); released_threads.clear(); rush_hit.clear()
	emitter_pose.clear()
	if supported():
		player.coil_rig.reset()
		player.coil_active = false; player.rush_active = false
		reset_serial = player.character_reset_serial

func state() -> Dictionary:
	return {"cooldown": cooldown, "cooldown_max": float(player.character_config.get("skill_cooldown", 10)) if supported() else 10.0, "active": active, "armor": armor, "armor_max": 100.0, "threads": threads, "released_threads":released_threads, "charge": charge}

func request_skill(world_aim: Vector2) -> bool:
	if not supported(): return false
	if reset_serial != player.character_reset_serial: reset()
	if cooldown > 0 or active > 0 or player.parts[0].hp <= 0 or float(player.parts[0].get("stun", 0)) > 0: return false
	if player.character_id == "beetle" and armor < 35: return false
	aim = world_aim
	cooldown = float(player.character_config.get("skill_cooldown", 10))
	match player.character_id:
		"centipede":
			active = 2.4; player.begin_coil()
			player.refresh_positions()
		"spider":
			active = 2.0
			var candidates: Array = combat.enemies.filter(func(e): return e.hp > 0 and e.damageable and e.role != "friendly" and float(e.get("warp", 0)) <= 0 and not e.get("cloaked", false) and not e.get("despawn", false) and player.head.distance_to(e.position) <= 360)
			candidates.sort_custom(func(a,b): return Vector2(a.position).distance_squared_to(aim) < Vector2(b.position).distance_squared_to(aim))
			for e in candidates.slice(0, 4): threads.append({"uid": e.uid, "position": e.position,"tether":Tether.create(player.head,e.position,e.uid)})
		"beetle":
			armor -= 35; armor_delay = 4; active = 0.95; charge = 0.3
			rush_direction = player.head.direction_to(aim)
			if rush_direction.is_zero_approx(): rush_direction = player.facing
			player.facing = rush_direction; player.rush_active = true; rush_hit.clear()
	return true

func boss(e: Dictionary) -> bool:
	if str(e.get("kind", "")).contains("Boss"): return true
	var parent: Dictionary = combat.entity(int(e.get("parent", 0)))
	return not parent.is_empty() and str(parent.get("kind", "")).contains("Boss")

func update(dt: float):
	if not supported(): return
	if reset_serial != player.character_reset_serial: reset()
	dt = clampf(dt, 0, 0.1)
	Tether.advance_released(released_threads,dt)
	if dt>0:
		for thread in released_threads:thread.release_origin=player.head
		update_emitter_pose()
	if player.parts[0].hp <= 0:
		finish(); return
	cooldown = maxf(0, cooldown - dt)
	armor_delay = maxf(0, armor_delay - dt)
	if armor_delay <= 0 and active <= 0: armor = minf(100, armor + dt * 12)
	if active <= 0: return
	active = maxf(0, active - dt)
	match player.character_id:
		"spider":
			for thread in threads.duplicate():
				var e: Dictionary = combat.entity(int(thread.uid))
				if e.is_empty() or e.hp <= 0 or e.role == "friendly" or float(e.get("warp", 0)) > 0 or e.get("cloaked", false) or e.get("despawn", false) or player.head.distance_to(e.position) > 420:
					Tether.append_release(released_threads,thread.tether,"silk")
					threads.erase(thread); continue
				if not boss(e) and combat.insect_control_system.eligible(e, true):
					e.stun = maxf(float(e.get("stun", 0)), dt + 0.03)
					var distance = player.head.distance_to(e.position)
					# Silk remains taut at the hold distance: legs keep struggling against it.
					preload("res://scripts/soft_insect.gd").pull(e,player.head-Vector2(e.position),125.0 if distance>90 else 75.0,dt)
					if distance > 90: combat.move_actor(e,Vector2(e.position).move_toward(player.head,minf(125*dt,distance-90)))
				thread.position = e.position
				var struggle=preload("res://scripts/soft_insect.gd").struggle(e.get("soft_body",{}))
				Tether.step(thread.tether,player.head,e.position,.95,struggle,dt)
		"beetle":
			if charge > 0: charge = maxf(0, charge - dt)
			else: advance_rush(dt)
	if active <= 0: finish()
	if dt>0:update_emitter_pose()

func update_emitter_pose():
	var motions:Array=threads.map(func(thread):return thread.tether)+released_threads
	emitter_pose=Tether.combine_reactions(motions) if not motions.is_empty() else {}
	for motion in motions:motion.emitter_offset=emitter_pose.offset

func finish():
	for thread in threads:Tether.append_release(released_threads,thread.tether,"silk")
	active = 0; charge = 0; threads.clear()
	update_emitter_pose()
	if supported():
		player.end_coil()
		player.rush_active = false
		player.refresh_positions()

func advance_rush(dt: float):
	var start: Vector2 = player.head
	var end: Vector2 = start + rush_direction * 620 * dt
	end=player.ground_position(start,end,player.collision_radius(0))
	var candidates: Array = combat.enemies.filter(func(e): return e.hp > 0 and e.role != "friendly" and float(e.get("warp", 0)) <= 0 and not e.get("cloaked", false) and not e.get("despawn", false))
	candidates.sort_custom(func(a,b): return start.distance_squared_to(a.position) < start.distance_squared_to(b.position))
	for e in candidates:
		var contact = Geometry2D.get_closest_point_to_segment(e.position, start, end)
		if contact.distance_to(e.position) > float(e.radius) + 40: continue
		if not rush_hit.has(e.uid) and e.damageable:
			rush_hit[e.uid] = true
			combat.hit_enemy(e, {"data": {"class": "BasicProjectile"}, "damage": 85.0, "shield_damage": 85.0, "chips": {}, "friendly": true, "position": contact, "previous": start, "origin": start, "velocity": rush_direction * 620, "radius": 0.0, "fx_family": "impact", "pierce": 1})
			if not boss(e) and combat.insect_control_system.eligible(e, true):
				combat.push_enemy(e,rush_direction,2.0)
				e.stun = maxf(float(e.get("stun", 0)), 0.25)
		if boss(e):
			end = start
			active = 0
			break
	# Already swept above, before testing contacts along the permitted travel.
	player.head = end
	player.velocity = rush_direction * 620
	player.refresh_positions()

func focus_target(at: Vector2, reach: float, fallback: Dictionary) -> Dictionary:
	if not supported() or player.character_id != "centipede" or active <= 0: return fallback
	var best: Dictionary = {}
	var distance = INF
	for e in combat.enemies:
		if e.hp <= 0 or not e.damageable or e.role == "friendly" or float(e.get("warp", 0)) > 0 or e.get("cloaked", false) or e.get("despawn", false) or at.distance_to(e.position) > reach: continue
		var d = Vector2(e.position).distance_squared_to(aim)
		if d < distance: best = e; distance = d
	return fallback if best.is_empty() else best

func absorb_front(damage: float, shot: Dictionary) -> float:
	if not supported() or player.character_id != "beetle": return damage
	armor_delay = 4
	if armor <= 0: return damage
	var incoming: Vector2 = -Vector2(shot.get("velocity", Vector2.ZERO))
	if incoming.is_zero_approx() and shot.has("position"): incoming = Vector2(shot.position) - player.head
	if incoming.is_zero_approx() or incoming.normalized().dot(player.facing) < 0.45: return damage
	var blocked = minf(armor, damage * 0.6)
	armor -= blocked
	return damage - blocked
