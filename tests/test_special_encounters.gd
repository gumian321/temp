extends SceneTree
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/chain_centipede.gd")
const Battle = preload("res://scripts/combat.gd")
const Run = preload("res://scripts/run_state.gd")
const Save = preload("res://scripts/save_store.gd")
var db
var save
var checks: Array = []

func check(value: bool, title: String):
	checks.append({"name": title, "passed": value})
	if not value: printerr("FAIL: ", title)

func fixture():
	var p = Body.new(db)
	var b = Battle.new(db, p)
	var r = Run.new(db, save, p, b, db.named("Endless Mission"), 0)
	b.enemies.clear(); b.drones.clear(); b.loot.clear(); b.destroyed.clear()
	return r

func tick(r, dt: float): r.combat.step(dt, Vector2.RIGHT, false, false)

func kill(r, e: Dictionary):
	r.combat.hit_enemy(e, {"data": {"class": "BasicProjectile"}, "damage": 10000.0, "shield_damage": 10000.0, "friendly": true, "chips": {}, "velocity": Vector2.RIGHT, "position": e.position, "pierce": 1})
	tick(r, 0)

func _initialize():
	db = DB.new(); save = Save.new(db); save.path = "user://encounter-tests.json"
	var r = fixture(); var director = r.encounters
	var bag: Array = []
	for i in range(12): bag.append(director.draw_type())
	var unique = true
	for i in range(1, bag.size()): unique = unique and bag[i] != bag[i - 1]
	for i in range(0, 12, 3): unique = unique and bag.slice(i, i + 3).has("charger") and bag.slice(i, i + 3).has("broodmother") and bag.slice(i, i + 3).has("treasure")
	check(unique, "Shuffle bag includes all three encounters without adjacent repeats across bag boundaries")
	director.step(17.9)
	check(director.phase == "quiet" and r.combat.enemies.is_empty(), "Opening grace period spawns no special enemies")
	director.step(.2)
	check(director.phase == "warning" and r.combat.enemies.is_empty(), "Encounter begins with a visible warning before actors exist")
	var marked = director.markers.duplicate()
	r.player.head = director.markers[0]; r.player.refresh_positions()
	director.step(2)
	check(r.combat.enemies.is_empty() and director.warning_waiting and director.markers == marked, "Approaching a spawn marker waits at the promised positions without contact spawning")
	director.step(2)
	check(director.markers == marked and director.warning_waiting, "Remaining near a marker does not move either warning")
	r.player.head = Vector2.ZERO; r.player.refresh_positions(); director.step(.01)
	check(director.phase == "active" and not director.live_specials().is_empty(), "Safe warning completion spawns the announced event")
	check(director.live_specials().size() == marked.size() and director.live_specials().all(func(e): return marked.has(e.position)), "Leaving the warning spawns every announced enemy exactly at its marker")
	r = fixture(); director = r.encounters; director.next_in = 0
	r.player.parts[0].hp = r.player.parts[0].max_hp * .3
	director.step(1)
	check(director.phase == "quiet" and r.combat.enemies.is_empty(), "Low health defers new encounters")
	r.player.parts[0].hp = r.player.parts[0].max_hp
	var boss = r.combat.spawn(db.pool["55"], Vector2(700, 0))
	director.next_in = 0; director.step(1)
	check(director.phase == "quiet", "Nearby bosses suppress additional special pressure")
	r.combat.enemies.clear(); director.start_warning("charger")
	r.director.boss_pause = 3; director.step(1)
	check(director.phase == "quiet" and director.markers.is_empty() and director.notice_left > 0 and director.notice.contains("取消"), "Boss recovery cancels a pending warning with an explicit visible reason")
	r = fixture(); director = r.encounters
	var template: Dictionary = db.entities[db.pool["250"]][0]
	var source = template.duplicate(true)
	var charger = director.spawn_special("charger", Vector2(250, 0)); charger.warp = 0
	var hp: float = r.player.parts[0].hp
	tick(r, .01)
	check(charger.encounter_phase == "windup" and r.player.parts[0].hp == hp, "Charger stops and winds up without hidden contact damage")
	var locked: Vector2 = charger.charge_direction
	r.player.head = Vector2(0, 200); r.player.refresh_positions()
	for i in range(60): tick(r, 1.0 / 60)
	check(charger.charge_direction == locked and absf(charger.position.y) < .01, "Charge direction stays locked after the player sidesteps")
	for i in range(40): tick(r, 1.0 / 60)
	check(charger.encounter_phase == "recover" and r.player.parts[0].hp == hp, "A dodged charge exposes a real recovery window")
	r.player.head = Vector2.ZERO; r.player.refresh_positions(); charger.position = Vector2(100, 0)
	charger.encounter_phase = "dash"; charger.phase_left = .55; charger.charge_direction = Vector2.LEFT; charger.charge_hit = false
	tick(r, .3)
	var after: float = r.player.parts[0].hp
	tick(r, .1)
	check(after < hp and r.player.parts[0].hp == after, "Swept dash collision hits once, including low frame rates")
	check(template == source, "Special configuration never mutates shared prefab or source components")
	var position: Vector2 = charger.position; var remaining: float = charger.phase_left
	charger.stun = 2; tick(r, .1)
	check(charger.position == position and charger.phase_left == remaining, "Existing stun control suspends special movement and its phase")
	r = fixture(); director = r.encounters
	var mother = director.spawn_special("broodmother", Vector2(500, 0))
	kill(r, mother)
	check(director.births.size() == 1 and director.live_specials().is_empty(), "Mother queues births outside the death iteration")
	director.on_death(mother); director.step(.01)
	check(director.live_specials().size() == 4 and director.births.is_empty(), "Mother produces exactly four hatchlings, once")
	for child in director.live_specials(): kill(r, child)
	director.step(.01)
	check(director.live_specials().is_empty() and director.births.is_empty(), "Hatchlings cannot recursively split")
	r = fixture(); director = r.encounters
	var treasure = director.spawn_special("treasure", Vector2(300, 0)); treasure.warp = 0
	var distance: float = treasure.position.distance_to(r.player.head); tick(r, .1)
	check(treasure.position.distance_to(r.player.head) > distance, "Treasure insect flees, creating a pursuit target")
	kill(r, treasure); director.on_death(treasure)
	check(r.combat.loot.filter(func(d): return d.pack).size() == 1, "Timely treasure kill grants exactly one extra pack")
	var energy = 0
	for drop in r.combat.loot: energy += int(drop.value)
	check(energy == 40, "Treasure grants 35 bonus energy plus normal five-energy death loot")
	for drop in r.combat.loot: drop.delivered = true
	r.timers = {"swarm": 999, "wave": 999, "patrol": 999}; r.step(0)
	check(r.packs > 0 and not r.roll_rewards().is_empty(), "Special loot enters the real reward queue and produces eligible offers")
	r = fixture(); director = r.encounters
	treasure = director.spawn_special("treasure", Vector2(300, 0)); treasure.age = 14
	director.phase = "active"; director.event_left = 20; director.step(.01); tick(r, 0)
	check(r.combat.enemies.is_empty() and r.combat.loot.is_empty() and r.combat.momentum.chain == 0, "Expired treasure escapes without loot or kill credit")
	for i in range(20): director.spawn_special("hatchling", Vector2(500 + i, 0))
	check(director.live_specials().size() == director.MAX_SPECIALS, "Hard special-actor cap bounds splitting and spawn load")
	r.combat.enemies.clear()
	director.start_warning("charger")
	for i in range(director.ENEMY_BUDGET - 1): r.combat.spawn(db.pool["250"], Vector2(2500 + i, 0))
	director.step(director.WARNING_TIME)
	check(director.phase == "quiet" and director.notice_left > 0 and director.live_specials().is_empty(), "A filled budget cancels visibly instead of spawning only half a promised pair")
	r.combat.spawn(db.pool["250"], Vector2(2600, 0))
	check(director.spawn_special("charger", Vector2(500, 0)).is_empty() and not director.safe_to_start(), "Global pressure cap prevents surplus encounter actors")
	for e in r.combat.enemies: e.kind = "Asteroid"
	check(director.safe_to_start(), "Static map props do not permanently suppress surprise encounters")
	r.combat.enemies.clear(); r.finished = true; director.next_in = 0; director.phase = "quiet"; director.births.append(Vector2(300, 0)); director.step(30)
	check(r.combat.enemies.is_empty(), "Finished runs dispatch neither encounters nor pending births")
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks}
	FileAccess.open("res://artifacts/special-encounters-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
