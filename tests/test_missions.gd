extends SceneTree
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/centipede.gd")
const Save = preload("res://scripts/save_store.gd")
const Battle = preload("res://scripts/combat.gd")
const Run = preload("res://scripts/run_state.gd")
var db
var save
var checks = 0
var failures: Array = []

func check(condition: bool, description: String):
	checks += 1
	if not condition: failures.append(description); printerr(description)

func fixture(m: Dictionary, difficulty: int):
	var p = Body.new(db)
	var b = Battle.new(db,p)
	return Run.new(db,save,p,b,m,difficulty)

func clear_targets(r):
	for e in r.combat.enemies:
		if e.uid in r.director.objectives: e.hp = 0
	r.combat.step(0.01,Vector2.RIGHT,false)
	r.step(0.01)

func _initialize():
	db = DB.new()
	save = Save.new(db)
	save.path = "user://mission-tests-isolated.json"
	for m in db.kind("Mission"):
		for d in range(3):
			var r = fixture(m,d)
			var name = m.name + "/" + str(d)
			match r.mode["class"]:
				"BHModeManager":
					check(r.director.initial_objectives > 0,name+": source trader fleet materialized")
					clear_targets(r)
					check(r.finished and r.won,name+": destroying complete trader fleet wins")
				"GAModeManager":
					check(r.director.initial_objectives > 0,name+": escort fleet exists")
					r.director.fleet_position = r.director.fleet_goal
					r.step(0.01)
					check(r.finished and r.won,name+": reaching source goal wins")
					var lose = fixture(m,d)
					clear_targets(lose)
					check(lose.finished and not lose.won,name+": fleet destruction loses")
				"SDestroyModeManager":
					check(r.director.initial_objectives > 0,name+": source station rings materialized")
					clear_targets(r)
					check(r.finished and r.won,name+": every station part destroyed wins")
				"SProtectModeManager":
					check(r.director.initial_objectives > 0,name+": friendly station exists")
					r.elapsed = r.duration
					r.step(0.01)
					check(r.finished and r.won,name+": defending until timer wins")
					var lose = fixture(m,d)
					clear_targets(lose)
					check(lose.finished and not lose.won,name+": station destruction loses")
				"SurvivalModeManager":
					r.elapsed = 15
					r.step(0.01)
					check(r.director.end_spawned,name+": source final Boss appears after 15 seconds")
					var roots = r.combat.enemies.filter(func(e): return e.kind == "AIBossUnit" and e.group == "survival_final")
					check(not roots.is_empty(),name+": final boss root exists")
					for e in r.combat.enemies:
						if e.group == "survival_final" and e.damageable: e.hp = 0
					r.combat.step(0.01,Vector2.RIGHT,false)
					r.step(0.01)
					check(r.finished and r.won,name+": all final boss parts destroyed wins")
				"EndlessModeManager":
					r.elapsed = r.duration * 1.1
					r.step(0.01)
					check(not r.finished,name+": endless passes first round without finishing")
					check(r.director.endless_wave == r.mode.bossesSpawnPercent.size(),name+": first-round source Boss schedule dispatched")
					r.elapsed = r.duration * 2.1
					r.step(0.01)
					check(r.director.endless_wave == r.mode.bossesSpawnPercent.size()*2,name+": second-round Boss schedule dispatched")
	var p = Body.new(db)
	var b = Battle.new(db,p)
	var boss = b.spawn(db.pool["55"],Vector2(1000,0))
	check(boss.parts.size() > 1,"Boss retains individual source parts")
	var part = b.entity(boss.parts[0])
	var other = b.entity(boss.parts[1])
	var original = other.hp
	part.hp = 0
	b.step(0.01,Vector2.ZERO,false)
	check(b.entity(boss.uid).hp > 0,"one destroyed part does not kill entire Boss")
	check(other.hp == original,"neighbor Boss part keeps independent health")
	check(b.entity(part.uid).is_empty(),"destroyed part removed including its turrets")
	check(b.destroyed.any(func(e): return e.uid == part.uid),"part destruction generates callback evidence")
	var report = {"checks":checks,"passed":checks-failures.size(),"failures":failures,"scope":"All 18 mission setups, specific victory/failure callbacks, endless schedules and independent source Boss parts. Isolated outcome tests; not full manual playthrough."}
	var file = FileAccess.open("res://artifacts/mission-test-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify(report))
	quit(1 if not failures.is_empty() else 0)
