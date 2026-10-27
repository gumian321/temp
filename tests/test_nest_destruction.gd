extends SceneTree

const DB = preload("res://scripts/source_db.gd")
const Save = preload("res://scripts/save_store.gd")
const Body = preload("res://scripts/chain_centipede.gd")
const Battle = preload("res://scripts/combat.gd")
const Run = preload("res://scripts/run_state.gd")
var checks: Array = []

func _initialize(): call_deferred("execute")
func check(ok: bool, label: String):
	checks.append({"name": label, "passed": ok})
	if not ok: printerr("FAIL: ", label)

func fixture(db, mission: Dictionary) -> Dictionary:
	var save = Save.new(db, "user://nest-destruction.json", false)
	var body = Body.new(db); var battle = Battle.new(db, body)
	var run = Run.new(db, save, body, battle, mission, 0)
	for e in battle.enemies: e.guns = []; e.components = []
	return {"run": run, "battle": battle, "body": body}

func finish_actor(battle, e: Dictionary):
	e.guns = []; e.components = []; e.warp = 0; e.hp = 1
	battle.hit_enemy(e, {"data": {"class": "BasicProjectile"}, "damage": 1000000.0, "shield_damage": 1000000.0, "friendly": true, "chips": {}, "velocity": Vector2.RIGHT, "position": e.position, "pierce": 1})
	battle.step(0, Vector2.RIGHT, false, false)

func execute():
	var db = DB.new()
	var f = fixture(db, db.named("Survival Mission"))
	var map = f.run.map_director
	f.battle.enemies.clear(); map.nodes.clear(); map.pending_nodes.clear(); map.actor_jobs.clear()
	var key = -Vector2.ONE * map.distance * .5
	map.spawn_node(key, 103)
	var node: Dictionary = map.nodes[key]
	check(node.has("center_sprite") and node.objectives.size() > 1, "Real map nest starts with a visible center and multiple destructible parts")
	var last: Dictionary = f.battle.entity(node.objectives[-1])
	for uid in node.objectives.slice(0, -1): finish_actor(f.battle, f.battle.entity(uid))
	map.step(0)
	check(node.has("center_sprite") and not map.destroyed_nodes.has(node.key), "Nest center survives while its last objective remains alive")
	var before_kills: int = f.battle.kills
	f.battle.effects.clear(); f.battle.death_splatters.clear(); f.battle.loot.clear()
	finish_actor(f.battle, last); map.step(0)
	check(map.destroyed_nodes.has(node.key) and not node.has("center_sprite"), "Destroying the final part removes the persistent map nest center")
	check(f.battle.effects.any(func(fx): return fx.kind == "explosion" and fx.position == node.position and fx.radius >= 90), "Cleared map nest bursts at the same position as its center")
	check(f.battle.kills == before_kills + 1 and f.battle.statistics.stat_StationsDestroyed == 1, "The visual center does not create an extra kill or station credit")
	var packs = f.battle.loot.filter(func(drop): return drop.pack).size()
	var effects: int = f.battle.effects.size()
	for i in 10: map.step(0)
	check(packs == 2 and f.battle.loot.filter(func(drop): return drop.pack).size() == packs and f.battle.effects.size() == effects, "Clearing gives exactly two station rewards and one center burst")
	f.battle.step(2, Vector2.RIGHT, false, false)
	check(not f.battle.effects.any(func(fx): return fx.kind == "explosion" and fx.position == node.position), "Nest burst fully expires without leaving a permanent replacement")
	f.body.head = Vector2(50000, 50000); map.update_grid(true)
	f.body.head = Vector2.ZERO; map.update_grid(true)
	check(not map.nodes.has(node.key) and not map.pending_nodes.has(node.key) and map.destroyed_nodes.has(node.key), "A destroyed center does not return after leaving and revisiting the map")

	for mission in db.kind("Mission"):
		f = fixture(db, mission)
		var mode: String = f.run.mode.get("class", "")
		if mode not in ["SDestroyModeManager", "SProtectModeManager"]: continue
		var director = f.run.director
		check(director.initial_objectives > 0, "Mission nest supplies actual objectives: " + mode)
		for e in director.living_objectives(): finish_actor(f.battle, e)
		f.battle.effects.clear(); director.step(0)
		check(f.run.finished and f.run.won == (mode == "SDestroyModeManager"), "Nest destruction retains the mission result: " + mode)
		check(director.get("station_destroyed") == true and f.battle.effects.any(func(fx): return fx.kind == "explosion" and fx.position == Vector2.ZERO), "Mission nest marks its center removed and bursts once: " + mode)
		var count: int = f.battle.effects.size(); director.step(0)
		check(f.battle.effects.size() == count, "Finished mission cannot repeat the nest burst: " + mode)
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks}
	FileAccess.open("res://artifacts/nest-destruction-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
