extends SceneTree

const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/centipede.gd")
const Save = preload("res://scripts/save_store.gd")
const Battle = preload("res://scripts/combat.gd")
const Run = preload("res://scripts/run_state.gd")
var errors: Array = []
var checks = 0

func check(value: bool, description: String):
	checks += 1
	if not value:
		errors.append(description)
		printerr("FAIL: ", description)

func _initialize():
	var db = DB.new()
	check(db.kind("Mission").size() == 6, "all six source missions imported")
	check(db.kind("MissionAIConfiguration").size() == 18, "all 18 source AI configurations imported")
	check(db.kind("Chip").size() == 6, "all six chips imported")
	check(db.packed("010000000500000006000000") == [1, 5, 6], "packed enum arrays retain little endian IDs")
	var p = Body.new(db)
	var gun: String = db.named("Core_Gun_Gatling").id
	check(not p.add_piece(gun, Vector2i(0, 0)), "HQ cannot be overwritten")
	check(not p.add_piece(gun, Vector2i(5, 5)), "disconnected placement rejected")
	check(p.add_piece(gun, Vector2i(0, -1)), "adjacent placement accepted")
	check(p.add_piece(gun, Vector2i(0, -2)), "second segment accepted")
	check(not p.connected(1), "removing bridge disconnects downstream part")
	p.actions.move = 1
	check(not p.move_piece(1, Vector2i(-1, 0)), "disconnecting move rejected atomically")
	check(p.parts[1].cell == Vector2i(0, -1), "failed move preserves original layout")
	p.actions.duplicate = 1
	check(p.duplicate_piece(1, Vector2i(1, -1)), "duplicate uses available action")
	check(p.actions.duplicate == 0, "duplicate consumes action")
	p.actions.swap = 1
	check(p.swap_piece(1, 2), "swap keeps connectivity")
	check(p.connected(), "structure connected after swap")
	p.actions.wall = 1
	var hp: float = p.parts[1].hp
	check(p.reinforce(1), "wall reinforcement")
	check(p.parts[1].hp == hp + db.stores.CoresDataStore.walledCoreAddedHealth, "wall uses original bonus")
	for i in range(600):
		p.step(1.0 / 60, Vector2.from_angle(float(i) / 150), false)
	check(p.head.length() > 20, "head moves under input")
	check(p.parts[1].position.distance_to(p.head) > 35, "body section follows behind head")
	var pose: Dictionary = p.path_sample(58)
	check(pose.direction.length() > 0.99, "path tangent normalized")
	var old_position: Vector2 = p.parts[1].position
	for i in range(120): p.step(1.0 / 60, Vector2.ZERO, false)
	check(p.parts[1].position.distance_to(old_position) < 180, "deceleration does not teleport tail")
	p.step(0.5, Vector2.RIGHT, true)
	check(not p.boost and p.fuel==0, "boost unavailable without source fuel tank")
	var save = Save.new(db)
	save.path = "user://test-isolated-save.json"
	save.fresh()
	check(save.state.meta == 55, "source new-game currency")
	save.state.meta = 123
	check(save.save(), "atomic save write succeeds")
	save.state.meta = 0
	check(save.load_save() and save.state.meta == 123, "save round-trip restores currency")
	var combat = Battle.new(db, p)
	var kamikaze: Dictionary = combat.spawn(db.pool["250"], Vector2(400, 0))
	check(kamikaze.name == "AI_Kamikaze_1", "pool ID binds original enemy, no substitute")
	check(kamikaze.hp == 100, "original enemy health")
	combat.fire(db.named("Core_Gun_Gatling"), Vector2.ZERO, Vector2.RIGHT, true)
	check(combat.bullets.size() == 1, "gatling emits projectile")
	check(combat.bullets[0].damage == 6, "original Gatling damage")
	check(abs(combat.bullets[0].velocity.length() - 960.0) < 0.01, "original projectile speed scaled by world units")
	combat.bullets.clear()
	combat.fire(db.named("Core_Gun_Shotgun"), Vector2.ZERO, Vector2.RIGHT, true)
	check(combat.bullets.size() == 15, "original shotgun barrage count")
	for m in db.kind("Mission"):
		for d in range(3):
			var session = Run.new(db, save, p, combat, m, d)
			check(session.duration == float(m.MissionsObjectiveList[d].objectiveTime) * 60, m.name + " duration")
			check(not session.configuration.is_empty(), m.name + " AI binding")
	var report = {"checks": checks, "passed": checks - errors.size(), "failures": errors, "scope": "Source data, construction, path movement, basic weapons, save round-trip and task bindings. This is not full gameplay parity acceptance."}
	var f = FileAccess.open("res://artifacts/core-test-report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print(JSON.stringify(report))
	quit(1 if not errors.is_empty() else 0)
