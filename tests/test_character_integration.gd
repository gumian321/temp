extends SceneTree
## Cross-system regression: fixed mounts, ownership, rewards, and character resets.
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/chain_centipede.gd")
const Battle = preload("res://scripts/combat.gd")
const Save = preload("res://scripts/save_store.gd")
const Run = preload("res://scripts/run_state.gd")
var checks: Array = []
func check(ok: bool, title: String):
	checks.append({"name": title, "passed": ok})
	if not ok: printerr("FAIL: ", title)
func _initialize(): call_deferred("execute")
func execute():
	var db = DB.new()
	var gun = db.named("Core_Gun_Gatling").id
	for id in ["spider", "beetle"]:
		var body = Body.new(db)
		body.configure_character(id)
		var cap = 8 if id == "spider" else 6
		check(body.parts.size() == 1 and body.segment_count() == cap, id + ": empty fixed body starts with only its head")
		check(body.body_poses.size() == cap + 1 and body.part_at(cap) == -1, id + ": empty mount poses exist without fake modules")
		body.install_module(gun, 1)
		body.install_module(gun, cap)
		var last: Dictionary = body.parts[2]
		check(body.move_to_mount(2, 2) and body.parts[2] == last and last.segment == 2, id + ": moving to an adjacent free mount preserves owner index")
		check(not body.move_to_mount(2, 1), id + ": moving cannot overwrite an occupied mount")
		check(body.swap_piece(1, 2) and last.segment == 1, id + ": swapping preserves module identity")
		body.swap_piece(1, 2)
		var battle = Battle.new(db, body)
		var drone = db.kind("MainCoreDroneReward")[0]
		battle.add_drone(2, db.asset(drone.drone))
		var drone_uid = battle.drones[-1].uid
		battle.hurt_player(1, 100000, 100000)
		battle.step(0.01, Vector2.RIGHT * 700, false)
		check(body.parts.size() == 2 and body.parts[1] == last and last.segment == 2 and body.part_at(1) == -1, id + ": destruction frees its mount without shifting survivors")
		var owned = battle.drones.filter(func(d): return d.uid == drone_uid)
		check(owned.size() == 1 and owned[0].owner == 1 and body.parts[owned[0].owner] == last, id + ": destruction remaps drone ownership to the surviving module")
		check(body.append_segment(gun) and body.parts[-1].segment == 1, id + ": replacement fills the vacant fixed mount")
		var geometry_ok = true
		for frame in 120:
			body.step(1.0 / 60, Vector2.UP if frame < 60 else Vector2.LEFT, false)
			for i in range(1, body.parts.size()):
				var expected = body.head + body.compact_mount_offset(body.parts[i].segment).rotated(body.facing.angle())
				geometry_ok = geometry_ok and body.parts[i].position.distance_to(expected) < 0.01
		check(geometry_ok, id + ": hardpoints stay attached during turns and movement")
		var save = Save.new(db); save.fresh()
		var run = Run.new(db, save, body, battle, db.named("Endless Mission"), 0)
		var reward: Dictionary = {}
		for r in db.kind("BlockReward"):
			if save.available(r.id): reward = r; break
		while body.parts.size() - 1 < cap - 1: body.append_segment(gun)
		check(run.can_reward(reward), id + ": final free hardpoint permits one reward")
		body.pending.append(reward.blockCore)
		check(not run.can_reward(reward), id + ": reserves consume the final hardpoint capacity")
		body.pending.clear(); body.append_segment(gun)
		check(not body.append_segment(gun) and run.can_reward(reward), id + ": full fixed body rejects growth but permits a replacement reward")
		body.pending.append(reward.blockCore)
		check(not run.can_reward(reward), id + ": full body allows only one pending replacement")
		for index in body.parts.size():
			for other in body.adjacent_part_indices(index):
				check(index in body.adjacent_part_indices(other), id + ": adjacency remains symmetric")
		body.configure_character("centipede")
		check(body.parts.size() == 1 and body.segment_count() == 0 and body.pending.is_empty() and not body.coil_active and not body.rush_active, id + ": character switch resets to a clean head-only centipede")
	var body = Body.new(db); body.configure_character("beetle")
	var battle = Battle.new(db, body)
	var enemy = battle.spawn(db.pool["250"], Vector2(50, 0))
	enemy.hp = 1000.0; enemy.max_hp = 1000.0; enemy.guns = []; enemy.components = []
	enemy.kind = "AISwarmingUnit"; enemy.unit = {"canBeStunned": true}; enemy.warp = 0
	var shield = db.kind("ShieldCore")[0]
	enemy.guns = [{"id": shield.id, "shield": float(shield.maxShieldHealth)}]
	battle.character_abilities.rush_direction = Vector2.RIGHT
	battle.character_abilities.advance_rush(0.1)
	check(enemy.hp == 1000.0 and enemy.guns[0].shield < float(shield.maxShieldHealth), "Beetle rush damages enemy shields before hull")
	for protection in ["friendly", "warp", "cloaked", "despawn"]:
		body.head = Vector2.ZERO; body.refresh_positions()
		enemy.position = Vector2(50, 0); enemy.hp = 1000.0; enemy.guns = []; enemy.role = ""; enemy.warp = 0.0; enemy.cloaked = false; enemy.despawn = false
		if protection == "friendly": enemy.role = "friendly"
		elif protection == "warp": enemy.warp = 1.0
		else: enemy[protection] = true
		battle.character_abilities.rush_hit.clear(); battle.character_abilities.advance_rush(0.1)
		check(enemy.hp == 1000.0, "Beetle rush excludes " + protection + " targets")
	enemy.role = ""; enemy.warp = 0.0; enemy.cloaked = false; enemy.despawn = false
	body.configure_character("spider"); battle.character_abilities.reset()
	enemy.guns = []; enemy.position = Vector2(150, 0); enemy.stun = 0.0; enemy.unit.canBeStunned = false
	battle.request_skill(enemy.position); battle.character_abilities.update(0.1)
	check(enemy.stun == 0.0 and enemy.position == Vector2(150, 0), "Spider active respects control-immune targets")
	body.configure_character("beetle")
	body.install_module(gun, 3)
	var original_uid = body.parts[1].feedback_uid
	var drone = db.kind("MainCoreDroneReward")[0]
	battle.add_drone(1, db.asset(drone.drone))
	battle.special.mines = [{"anchored": true, "owner": 1}, {"anchored": false, "owner": 1}]
	check(battle.replace_character_module(1, db.named("Core_Gun_Cannon").id) and body.parts[1].segment == 3 and body.parts[1].feedback_uid != original_uid, "Compact replacement preserves hardpoint and creates fresh module identity")
	check(battle.drones.all(func(d): return d.owner != 1) and battle.special.mines.size() == 1 and not battle.special.mines[0].anchored, "Compact replacement clears owned drones and anchored mines only")
	var report = {"checks": checks, "passed": checks.all(func(c): return c.passed)}
	FileAccess.open("res://artifacts/character-integration-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
