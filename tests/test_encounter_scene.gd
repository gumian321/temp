extends "res://tests/test_centipede_scene.gd"

func settle():
	for i in range(4): await process_frame

func paint_scene():
	game.sync_camera_layers()
	game.insect_layer.sync(game, 0)
	game.battle_hud.refresh()
	game.queue_redraw()
	await settle()

func execute():
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate(); root.add_child(game); await settle()
	game.set_process(false); game.save.fresh(); game.test_mode = true
	game.selected_mission = game.db.named("Endless Mission"); game.start_run(); await settle()
	game.combat.enemies.clear(); game.combat.drones.clear(); game.combat.loot.clear()
	game.run.timers = {"swarm": 999, "wave": 999, "patrol": 999}
	game.tutorials.movement_shown = true; game.tutorials.radar_shown = true; game.tutorials.fuel_shown = true
	var director = game.run.encounters
	director.start_warning("charger"); director.markers.assign([Vector2(-420, 0), Vector2(420, 0)])
	await paint_scene(); await capture("encounter-warning")
	check(game.battle_hud.encounter_label.text.contains("冲锋虫") and game.battle_hud.encounter_hint.text.contains("侧移"), "Warning names the enemy and explains its counterplay")
	game.combat.momentum.burst_left = 6; game.combat.momentum.chain = 18; game.combat.momentum.remaining = 4.5
	game.show_pause(); game._process(2); await settle()
	check(director.warning_left == director.WARNING_TIME and game.combat.momentum.burst_left == 6, "Pause freezes encounter warnings and overdrive")
	game.show_game(); await settle()
	game.run.rewards.enqueue(true); var elapsed: float = game.run.elapsed
	game._process(.05); await settle()
	check(game.screen == "rewards" and game.run.elapsed == elapsed and game.run.packs == 1 and game.reward_ui.buttons.size() == 3, "Earned pack automatically opens three choices during overdrive without advancing combat")
	var burst: float = game.combat.momentum.burst_left
	game._process(2)
	check(game.combat.momentum.burst_left == burst and director.warning_left == director.WARNING_TIME, "Automatic reward selection preserves burst and encounter warning time")
	game.postpone_rewards(); await settle()
	game.combat.enemies.clear(); director.markers.clear(); director.phase = "active"; director.event_left = 24
	var charger = director.spawn_special("charger", Vector2(-300, 20))
	charger.encounter_phase = "windup"; charger.phase_left = .6; charger.charge_direction = Vector2.RIGHT; charger.angle = 0
	var mother = director.spawn_special("broodmother", Vector2(260, 90))
	var treasure = director.spawn_special("treasure", Vector2(300, -160)); treasure.age = 4.2
	await paint_scene()
	for e in [charger, mother, treasure]:
		var rig = game.insect_layer.rigs[e.uid]
		check(rig.art.resource_path.begins_with("res://assets/special_encounters/"), "Real rig uses ImageGen texture: " + str(e.encounter_type))
		check(rig.legs.size()==6 and rig.mesh.texture==rig.art, "Generated body retains articulated legs and soft mesh: " + str(e.encounter_type))
	game.camera = game.player.head; game.zoom = 1
	for dimensions in [Vector2i(1440, 900), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions; await settle(); game.center = Vector2(dimensions) / 2
		await paint_scene()
		var h = game.battle_hud
		var bounds = root.get_visible_rect()
		var valid = true
		for label in [h.streak_label, h.streak_detail, h.encounter_label, h.encounter_hint, h.supplies]: valid = valid and bounds.encloses(label.get_global_rect())
		check(valid, "New status labels fit the viewport at " + str(dimensions))
		check(not h.streak_label.get_global_rect().intersects(h.encounter_label.get_global_rect()), "Streak and encounter status do not overlap at " + str(dimensions))
		await capture("encounter-showcase-%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1440, 900); await settle(); game.center = Vector2(720, 450)
	charger.encounter_phase = "recover"; charger.phase_left = 1.2; director.event_type = "broodmother"
	mother.hp = 0; mother.last_friendly = true
	game.combat.step(.01, Vector2.RIGHT, false, false); director.step(.01)
	await paint_scene(); await capture("encounter-split-and-recovery")
	check(director.live_specials().filter(func(e): return e.encounter_type == "hatchling").size() == 4, "Native scene contains the four real split offspring")
	game.cursor_system.shutdown(); game.audio_system.shutdown(); game.particle_effects.clear(); game.queue_free(); await settle()
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks, "captures": captures, "scope": "Staged real gameplay states and native renderer; not an unassisted human playthrough."}
	FileAccess.open("res://artifacts/encounter-scene-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
