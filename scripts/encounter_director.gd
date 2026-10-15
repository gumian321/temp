extends RefCounted
## Optional, bounded encounters; never join mission objective or boss wave groups.
const TYPES = ["charger", "broodmother", "treasure"]
const WARNING_TIME = 1.6
const TREASURE_LIFETIME = 14.0
const MAX_SPECIALS = 8
const ENEMY_BUDGET = 70
const WORLD_BUDGET = 256
const MOBILE_KINDS = ["AISwarmingUnit", "AIFollowingUnit", "AIPatrolUnit"]
var session: WeakRef
var rng = RandomNumberGenerator.new()
var bag: Array = []
var previous = ""
var next_in = 18.0
var phase = "quiet"
var event_type = ""
var warning_left = 0.0
var event_left = 0.0
var markers: Array[Vector2] = []
var births: Array = []
var notice = ""
var notice_left = 0.0
var completed = 0
var enabled = true

func _init(run):
	session = weakref(run)
	rng.seed = 20261015

func current(): return session.get_ref()

func live_specials() -> Array:
	return current().combat.enemies.filter(func(e): return e.get("group", "") == "surprise" and e.hp > 0 and not e.get("despawn", false))

func mobile_count() -> int:
	var count = 0
	for e in current().combat.enemies:
		if e.hp > 0 and not e.get("despawn", false) and e.role != "friendly" and e.kind in MOBILE_KINDS: count += 1
	return count

func has_room() -> bool:
	# Map rocks, containers and station parts are not additional chasing threats.
	return current().combat.enemies.size() < WORLD_BUDGET and mobile_count() < ENEMY_BUDGET and live_specials().size() < MAX_SPECIALS

func safe_to_start() -> bool:
	var run = current()
	if run.finished or run.player.parts[0].hp <= run.player.parts[0].max_hp * 0.35 or run.director.boss_pause > 0: return false
	var nearby = 0
	for e in run.combat.enemies:
		if e.hp <= 0 or e.get("despawn", false) or e.role == "friendly": continue
		var distance = Vector2(e.position).distance_to(run.player.head)
		if e.kind == "AIBossUnit" and (e.active or distance < 1500): return false
		if distance < 900 and e.kind in MOBILE_KINDS: nearby += 1
	return nearby < 24 and has_room() and live_specials().is_empty()

func draw_type() -> String:
	if bag.is_empty():
		bag = TYPES.duplicate()
		for i in range(bag.size() - 1, 0, -1):
			var j = rng.randi_range(0, i)
			var old = bag[i]; bag[i] = bag[j]; bag[j] = old
		if bag.back() == previous:
			var old = bag[0]; bag[0] = bag[-1]; bag[-1] = old
	previous = str(bag.pop_back())
	return previous

func title(kind: String) -> String:
	var db = current().db
	return {"charger": db.ui("LANCER AMBUSH", "冲锋虫夹击"), "broodmother": db.ui("BROOD ERUPTION", "裂殖母虫"), "treasure": db.ui("TREASURE HUNT", "藏宝虫出没")}.get(kind, "")

func hint(kind: String) -> String:
	var db = current().db
	return {"charger": db.ui("Dodge the marked charge, then strike", "侧移躲开冲锋 · 趁僵直反击"), "broodmother": db.ui("Burst the mother; chain the hatchlings", "击破母虫 · 收割分裂幼虫续连杀"), "treasure": db.ui("Catch it in 14s for a bonus supply pack", "14秒内击杀 · 额外补给箱与能量")}.get(kind, "")

func start_warning(kind: String = ""):
	event_type = draw_type() if kind.is_empty() else kind
	phase = "warning"
	warning_left = WARNING_TIME
	place_markers()

func place_markers():
	markers.clear()
	var angle = rng.randf() * TAU
	var head: Vector2 = current().player.head
	markers.append(head + Vector2.from_angle(angle) * 520)
	if event_type == "charger": markers.append(head + Vector2.from_angle(angle + PI * 0.85) * 560)

func step(dt: float):
	var run = current()
	if not enabled or run == null or run.finished: return
	notice_left = maxf(0, notice_left - dt)
	# Births are dispatched outside Combat's death iteration, never recursively.
	for birth in births:
		for i in range(4):
			if not has_room(): break
			spawn_special("hatchling", Vector2(birth) + Vector2.from_angle(i * TAU / 4) * 45)
	births.clear()
	if phase == "active":
		event_left = maxf(0, event_left - dt)
		for e in live_specials():
			if (e.encounter_type == "treasure" and e.age >= TREASURE_LIFETIME) or event_left <= 0 or Vector2(e.position).distance_to(run.player.head) > 1900:
				e.despawn = true
		if live_specials().is_empty():
			phase = "quiet"
			next_in = rng.randf_range(24, 34)
			completed += 1
		return
	if phase == "warning":
		if not safe_to_start():
			phase = "quiet"; markers.clear(); next_in = 5.0
			return
		warning_left = maxf(0, warning_left - dt)
		if warning_left > 0: return
		# Walking into a telegraph relocates it with a fresh warning; no contact spawn.
		for at in markers:
			for part in run.player.parts:
				if Vector2(part.position).distance_to(at) < 220:
					place_markers(); warning_left = WARNING_TIME
					return
		for at in markers: spawn_special(event_type, at)
		markers.clear()
		phase = "active"; event_left = 24.0
		return
	next_in = maxf(0, next_in - dt)
	if next_in <= 0:
		if safe_to_start(): start_warning()
		else: next_in = 4.0

func spawn_special(kind: String, at: Vector2) -> Dictionary:
	var run = current()
	if not has_room(): return {}
	var e: Dictionary = run.combat.spawn(run.db.pool["250"], at)
	if e.is_empty(): return e
	# The source template is a kamikaze. Instance copies deliberately remove its
	# suicide trigger, inherited weapons and global configuration dependencies.
	e.unit = e.unit.duplicate(true)
	e.unit.scrapsCount = 2 if kind == "hatchling" else 5
	e.components = []
	e.guns = []
	e.group = "surprise"
	e.encounter_type = kind
	e.brood_species = {"charger": "mantis", "broodmother": "sac", "treasure": "beetle", "hatchling": "grub"}[kind]
	e.hp = float({"charger": 110, "broodmother": 165, "treasure": 95, "hatchling": 18}[kind]) * run.combat.health_modifier * (1 + minf(run.heat, 1) * 0.6)
	e.max_hp = e.hp
	e.radius = float({"charger": 22, "broodmother": 32, "treasure": 24, "hatchling": 12}[kind])
	e.angle = at.direction_to(run.player.head).angle()
	e.encounter_phase = "approach"
	e.phase_left = 0.0
	e.charge_direction = Vector2.ZERO
	e.contact_left = 0.6
	e.shot_left = 2.0
	e.warp = 0.35
	e.charge_hit = false
	return e

func move_actor(e: Dictionary, dt: float) -> bool:
	if not e.has("encounter_type"): return false
	var run = current()
	var battle = run.combat
	var player = run.player
	var start: Vector2 = e.position
	var toward = start.direction_to(player.head)
	var distance = start.distance_to(player.head)
	var movement = battle.insect_control_system.movement_factor(e, dt)
	e.contact_left = maxf(0, float(e.contact_left) - dt)
	match str(e.encounter_type):
		"charger":
			match str(e.encounter_phase):
				"approach":
					e.angle = toward.angle()
					if distance <= 390:
						e.encounter_phase = "windup"; e.phase_left = 0.85
						e.charge_direction = toward; e.charge_hit = false
					else: e.position += toward * 115 * movement * dt
				"windup":
					e.phase_left -= dt
					if e.phase_left <= 0: e.encounter_phase = "dash"; e.phase_left = 0.55
				"dash":
					var travel = minf(dt, maxf(0, e.phase_left))
					e.position += Vector2(e.charge_direction) * 640 * movement * travel
					if not e.charge_hit:
						for i in range(player.parts.size()):
							var part: Dictionary = player.parts[i]
							if part.hp <= 0 or part.get("cloaked", false): continue
							var closest = Geometry2D.get_closest_point_to_segment(part.position, start, e.position)
							if closest.distance_to(part.position) < e.radius + player.collision_radius(i):
								battle.hurt_player(i, 22 * e.damage_modifier, 16 * e.damage_modifier)
								e.charge_hit = true
								break
					e.phase_left -= dt
					if e.phase_left <= 0: e.encounter_phase = "recover"; e.phase_left = 1.4
				"recover":
					e.phase_left -= dt
					if e.phase_left <= 0: e.encounter_phase = "approach"
		"treasure":
			var escape = -toward if distance < 720 else toward.orthogonal()
			if escape.is_zero_approx(): escape = Vector2.RIGHT
			var direction = escape.rotated(sin(e.age * 2.8) * 0.5)
			e.position += direction * 105 * movement * dt
			e.angle = direction.angle()
		"broodmother":
			e.angle = toward.angle()
			if distance > 230: e.position += toward * 65 * movement * dt
			e.shot_left -= dt
			if e.shot_left <= 0 and distance < 650:
				e.shot_left = 2.2
				var core: Dictionary = run.db.named("Core_Gun_Gatling")
				for spread in [-0.2, 0.0, 0.2]:
					battle.fire(core, e.position, toward.rotated(spread), false, {}, e.damage_modifier * 0.65 - 1, true, 0, 1.0, "enemy:" + str(e.uid))
		"hatchling":
			e.angle = toward.angle()
			e.position += toward * 150 * movement * dt
			if e.contact_left <= 0:
				for i in range(player.parts.size()):
					if player.parts[i].hp > 0 and not player.parts[i].get("cloaked", false) and Vector2(e.position).distance_to(player.parts[i].position) < e.radius + player.collision_radius(i):
						battle.hurt_player(i, 6 * e.damage_modifier, 4 * e.damage_modifier)
						e.contact_left = 1.0
						break
	battle.spatial_moved(e)
	return true

func on_death(e: Dictionary):
	if not e.has("encounter_type") or e.get("encounter_resolved", false) or e.get("despawn", false): return
	e.encounter_resolved = true
	var run = current()
	if run.finished or run.player.parts[0].hp <= 0: return
	if e.encounter_type == "broodmother": births.append(Vector2(e.position))
	if e.encounter_type == "treasure" and e.age < TREASURE_LIFETIME and e.get("last_friendly", false):
		run.combat.loot.append({"position": e.position, "value": 0, "pack": true, "rarity": 2})
		run.combat.spawn_scraps(e.position, 35)
		notice = run.db.ui("TREASURE CLAIMED · collect your bonus supply", "追猎成功 · 拾取额外补给与能量")
		notice_left = 3.5
		run.combat.audio_events.append({"type": 50, "position": e.position, "pitch": 1.35})
