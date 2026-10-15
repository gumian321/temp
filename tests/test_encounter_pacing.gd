extends SceneTree
## Bounded soak of real mission/map/combat clocks. Durable HQ isolates cadence;
## this is not a claim about default-character difficulty or human completion.
func _initialize(): call_deferred("execute")

func execute():
	var db = load("res://scripts/source_db.gd").new()
	var save = load("res://scripts/save_store.gd").new(db); save.path = "user://encounter-pacing.json"
	var p = load("res://scripts/chain_centipede.gd").new(db)
	var b = load("res://scripts/combat.gd").new(db, p)
	var r = load("res://scripts/run_state.gd").new(db, save, p, b, db.named("Endless Mission"), 0)
	p.parts[0].max_hp = 50000; p.parts[0].hp = 50000
	var events: Array = []
	var max_specials = 0; var max_actors = 0; var before_phase = "quiet"
	var started = Time.get_ticks_usec()
	for frame in range(1800):
		var dt = .1
		var target = b.nearest(p.head, 1000)
		var aim: Vector2 = target.get("position", p.head + Vector2.RIGHT * 200)
		p.step(dt, Vector2.from_angle(r.elapsed * .08), false)
		b.step(dt, aim, false); r.step(dt)
		if r.encounters.phase == "active" and before_phase != "active": events.append({"kind": r.encounters.event_type, "time": r.elapsed, "actors": b.enemies.size()})
		before_phase = r.encounters.phase
		max_specials = maxi(max_specials, r.encounters.live_specials().size())
		max_actors = maxi(max_actors, b.enemies.size())
		b.audio_events.clear(); p.feedback_events.clear()
		if frame % 300 == 0: await process_frame
	var passed = events.size() >= 2 and max_specials <= r.encounters.MAX_SPECIALS and not r.finished
	var report = {"passed": passed, "events": events, "max_specials": max_specials, "max_total_actors": max_actors, "kills": b.kills, "best_chain": b.momentum.best, "bursts": b.momentum.bursts, "elapsed": r.elapsed, "simulation_ms": (Time.get_ticks_usec() - started) / 1000.0, "scope": "180-second real endless run, default loadout and durable HQ; no injected enemies, kills or encounter timers."}
	FileAccess.open("res://artifacts/encounter-pacing-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if passed else 1)
