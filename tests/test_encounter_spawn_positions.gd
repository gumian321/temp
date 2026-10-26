extends "res://tests/test_encounter_scene.gd"
## Follow published world markers through the real cave/spawn/collision pipeline.

func capture(label: String):
	await paint_scene()
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path = "res://artifacts/" + label + ".png"
	check(root.get_texture().get_image().save_png(path) == OK, "Native capture: " + label)
	captures.append(path)

func execute():
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate(); root.add_child(game); await settle()
	game.set_process(false); game.test_mode = true; game.save.fresh()
	game.selected_mission = game.db.named("Endless Mission"); game.start_run(); game.set_process(false)
	game.combat.enemies.clear(); game.combat.drones.clear(); game.combat.loot.clear()
	game.run.timers = {"swarm": 999, "wave": 999, "patrol": 999}
	game.performance_overlay.set_process(false); game.performance_overlay.display.hide()
	game.tutorials.reset_run(); game.tutorials.set_process(false); game.tutorials.hide()
	var director = game.run.encounters
	var world = game.player.terrain
	var cases = 0; var arrivals = 0; var largest_offset = 0.0
	for region in [Vector2.ZERO, Vector2(760, 0), Vector2(2050, -1056)]:
		game.player.head = world.safe_position(region, game.player.collision_radius(0)); game.player.refresh_positions()
		for kind in director.TYPES:
			for seed_index in range(10):
				game.combat.enemies.clear(); director.rng.seed = 20261023 + seed_index
				director.start_warning(kind)
				var promised = director.markers.duplicate()
				var expected = 2 if kind == "charger" else 1
				var label = "%s / %s / seed %d" % [kind, region, 20261023 + seed_index]
				check(director.phase == "warning" and promised.size() == expected, "A complete encounter has valid markers: " + label)
				check(promised.all(func(at): return Vector2(at).distance_to(game.player.head) >= 220 and not world.blocked(at, director.SPECIAL_RADII[kind])), "Published markers already satisfy distance and terrain clearance: " + label)
				director.step(.4)
				check(director.markers == promised and director.live_specials().is_empty(), "Markers stay fixed throughout the warning: " + label)
				director.step(1.21)
				var actors = director.live_specials()
				check(director.phase == "active" and actors.size() == expected, "Countdown produces every announced enemy: " + label)
				var exact = actors.size() == promised.size()
				for i in mini(actors.size(), promised.size()):
					var offset: float = actors[i].position.distance_to(promised[i])
					largest_offset = maxf(largest_offset, offset); exact = exact and offset < .01
				check(exact, "All enemies appear exactly at their published markers: " + label)
				game.combat.step(.1, game.player.head + Vector2.RIGHT, false, false)
				check(actors.all(func(e): return promised.any(func(at): return Vector2(e.position).distance_to(at) < .01)), "Initial collision/arrival update preserves the promised positions: " + label)
				arrivals += actors.size(); cases += 1
	# The old regression seed placed a marker only 156 px from a stationary player.
	game.player.head = Vector2.ZERO; game.player.refresh_positions(); game.combat.enemies.clear()
	game.camera = Vector2.ZERO; game.zoom = 1; game.center = Vector2(720, 450)
	director.rng.seed = 20261025; director.start_warning("charger")
	var promised = director.markers.duplicate()
	await capture("encounter-spawn-fixed-warning")
	game.player.head = promised[0]; game.player.refresh_positions(); director.step(1.7)
	await paint_scene()
	check(director.warning_waiting and director.markers == promised and director.live_specials().is_empty(), "Entering a marked location waits without moving either marker")
	check(game.battle_hud.encounter_label.text.contains("等待") and game.battle_hud.encounter_hint.text.contains("原位"), "The waiting state tells the player that the marked positions are retained")
	await capture("encounter-spawn-fixed-waiting")
	game.player.head = Vector2.ZERO; game.player.refresh_positions(); director.step(.01)
	await paint_scene()
	check(director.live_specials().size() == promised.size() and director.live_specials().all(func(e): return promised.has(e.position)), "Clearing the area releases the same promised enemies at the same locations")
	for e in director.live_specials():
		if game.insect_layer.rigs.has(e.uid):
			check(game.insect_layer.rigs[e.uid].position.distance_to(game.world(e.position)) < .01, "Native insect rig is centered on the actual marked spawn position")
	await capture("encounter-spawn-fixed-arrived")
	game.combat.enemies.clear(); director.start_warning("charger")
	game.run.director.boss_pause = 2; director.step(.01); await paint_scene()
	check(director.phase == "quiet" and director.markers.is_empty() and game.battle_hud.encounter_hint.text.contains("取消"), "Safety cancellation is shown instead of silently abandoning the warning")
	game.cursor_system.shutdown(); game.audio_system.shutdown(); game.particle_effects.clear(); game.queue_free(); await settle()
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks, "cases": cases, "arrivals": arrivals, "max_spawn_offset": largest_offset, "captures": captures}
	FileAccess.open("res://artifacts/encounter-spawn-positions-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
