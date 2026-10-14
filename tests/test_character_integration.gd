extends SceneTree
## Cross-system regression for the two active characters and legacy input safety.
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/chain_centipede.gd")
const Battle = preload("res://scripts/combat.gd")
const Save = preload("res://scripts/save_store.gd")
var checks: Array = []
func check(ok: bool, title: String):
	checks.append({"name": title, "passed": ok})
	if not ok: printerr("FAIL: ", title)
func _initialize(): call_deferred("execute")
func execute():
	var db = DB.new()
	var gun = db.named("Core_Gun_Gatling").id
	var body = Body.new(db)
	for retired in ["beetle", "unknown"]:
		body.configure_character(retired)
		check(body.character_id == "centipede" and body.module_cap() == 60 and not body.compact_body(), "Retired or invalid body configuration falls back safely: " + retired)
		var battle = Battle.new(db, body)
		check(battle.request_skill(Vector2.RIGHT * 200) and body.coil_active and not body.rush_active, "Fallback activates centipede skill only: " + retired)
	body.configure_character("spider")
	check(body.parts.size() == 1 and body.module_cap() == 32, "Spider starts with a clean head and 32-module cap")
	body.install_module(gun, 8)
	var original_uid = body.parts[1].feedback_uid
	var battle = Battle.new(db, body)
	var drone = db.kind("MainCoreDroneReward")[0]
	battle.add_drone(1, db.asset(drone.drone))
	battle.special.mines = [{"anchored": true, "owner": 1}, {"anchored": false, "owner": 1}]
	check(battle.replace_character_module(1, db.named("Core_Gun_Cannon").id) and body.parts[1].segment == 8 and body.parts[1].feedback_uid != original_uid, "Compact replacement preserves leg mount and creates fresh module identity")
	check(battle.drones.all(func(d): return d.owner != 1) and battle.special.mines.size() == 1 and not battle.special.mines[0].anchored, "Compact replacement clears owned drones and anchored mines only")
	var enemy = battle.spawn(db.pool["250"], Vector2(150, 0))
	enemy.hp = 1000.0; enemy.max_hp = 1000.0; enemy.guns = []; enemy.components = []
	enemy.kind = "AISwarmingUnit"; enemy.unit = {"canBeStunned": false}; enemy.warp = 0
	enemy.stun = 0.0
	battle.request_skill(enemy.position); battle.character_abilities.update(0.1)
	check(enemy.stun == 0.0 and enemy.position == Vector2(150, 0), "Spider active respects control-immune targets")
	for index in body.parts.size():
		for other in body.adjacent_part_indices(index):
			check(index in body.adjacent_part_indices(other), "Spider mount adjacency remains symmetric")
	body.pending.append(gun)
	body.configure_character("centipede")
	check(body.parts.size() == 1 and body.segment_count() == 0 and body.pending.is_empty() and not body.coil_active and not body.rush_active, "Character switch resets to clean head-only centipede")
	var save = Save.new(db, "user://character-integration-isolated.json", false)
	save.state.roster_unlocked = ["centipede", "spider", "beetle"]
	check(not save.character_unlocked("beetle") and not save.select_character("beetle"), "Injected stale unlock cannot expose retired character")
	var report = {"checks": checks, "passed": checks.all(func(c): return c.passed)}
	FileAccess.open("res://artifacts/character-integration-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
