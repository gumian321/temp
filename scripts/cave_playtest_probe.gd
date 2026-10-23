extends "res://scripts/windows_review_probe.gd"
## The same end-to-end cave check runs against source and the shipped EXE.
var capture_directory = "user://cave-captures"

func capture(tag: String):
	game.insect_layer.sync(game, 0); game.sync_camera_layers(); game.battle_hud.refresh(); game.queue_redraw()
	await process_frame; await process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_directory))
	var path = capture_directory + "/cave-" + tag + ".png"
	check(root.get_texture().get_image().save_png(path) == OK, "Native cave capture: " + tag)
	captures.append(ProjectSettings.globalize_path(path))

func execute():
	root.size = Vector2i(1440, 900)
	await process_frame
	game.set_process(false); game.save.fresh(); game.test_mode = false
	game.selected_mission = game.db.named("Survival Mission"); game.begin_run()
	check(game.deployment_active and game.deployment_ui.is_visible_in_tree(), "Shipped deployment shows loading before preparing the map")
	var loading_captured=false
	var deadline=Time.get_ticks_msec()+60000
	while game.deployment_active and Time.get_ticks_msec()<deadline:
		if not loading_captured and game.deployment_ui.progress.value>=60 and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_directory))
			var path=capture_directory+"/cave-loading.png"
			check(root.get_texture().get_image().save_png(path)==OK,"Shipped loading progress renders inside the actual EXE")
			check(root.get_visible_rect().encloses(game.deployment_ui.progress.get_global_rect()),"Shipped loading bar stays inside the viewport")
			captures.append(ProjectSettings.globalize_path(path));loading_captured=true
		await process_frame
	check(not game.deployment_active and game.screen=="game","Completed preparation automatically opens the cave")
	check(game.deployment_report.progress[-1].progress==100 and game.run.elapsed==0,"Loading reaches real completion before simulation begins")
	game.set_process(false)
	var world = game.player.terrain
	check(world.enabled and world == game.combat.terrain and world == game.charcoal_terrain.world, "Main scene shares one enabled cave world across simulation and rendering")
	game.combat.enemies.clear(); game.combat.drones.clear(); game.combat.enemy_drones.clear(); game.combat.loot.clear(); game.combat.effects.clear()
	# Show the intact deposit without the player's jaws covering its surface.
	game.player.head = Vector2(200, 0); game.player.facing = Vector2.RIGHT
	game.player.motion.reset(); game.player.refresh_positions()
	game.camera = Vector2(350, 0); game.center = root.size * 0.5; game.zoom = 1.75
	await capture("00-mineral-grains")
	var fps = game.performance_overlay
	check(fps.display.is_visible_in_tree() and fps.reading.text.contains("FPS"), "Shipped cave displays the independent frame-rate counter")
	var fps_bounds = fps.plate.get_global_rect()
	check(root.get_visible_rect().encloses(fps_bounds) and fps_bounds.position.y > root.get_visible_rect().size.y - 85, "Frame-rate counter stays below the minimap in the bottom-right corner")
	game.zoom = 1.0
	await capture("00b-normal-mineral-grains")
	var entry = world.wall_hit(Vector2.ZERO, Vector2(1000, 0), game.player.collision_radius(0))
	game.player.head = Vector2(entry.position) + Vector2(entry.normal) * 0.35
	game.player.facing = Vector2.RIGHT
	for i in game.player.history.size(): game.player.history[i] = game.player.head - Vector2(i * 4, 0)
	for i in 6: game.player.append_segment(game.db.named("Core_Gun_Gatling").id)
	game.player.motion.reset(); game.player.refresh_positions()
	game.camera = Vector2(300, 0); game.center = root.size * 0.5; game.zoom = 1.0
	await capture("01-before")
	var initial = world.removed_count
	Input.action_press("move_right")
	for i in 25: game._process(1.0 / 60)
	Input.action_release("move_right")
	check(world.mining_active and world.bite_serial > 0 and game.mouth_activity > 0.9, "Actual movement input engages head chewing and jaw animation")
	game.camera = Vector2(300, 0)
	await capture("02-chewing")
	var clear = true
	for frame in 600:
		game.player.step(1.0 / 60, Vector2.RIGHT, false)
		game.player_legs.step(game.player, 1.0 / 60)
		game.combat.step(1.0 / 60, Vector2(900, 0), false, false)
		clear = clear and game.player.body_poses.all(func(pose): return not world.blocked(pose.point, 26))
		if game.player.head.x > 570: break
	if game.player.head.x <= 550: print("SHORTCUT_DIAGNOSTIC=", JSON.stringify({"head": game.player.head, "facing": game.player.facing, "hit": world.wall_hit(game.player.head, game.player.head + Vector2.RIGHT * 12, game.player.collision_radius(0)), "active": world.mining_active, "bites": world.bite_serial}))
	check(game.player.head.x > 550 and world.removed_count > initial, "Production chamber shortcut opens by pushing into its ore-bearing wall")
	check(clear, "All six actual body modules follow the new passage without penetrating rock")
	check(world.ore_total > 0, "Mining the production deposit creates existing energy-crystal pickups")
	check(world.ray_clear(Vector2(300, 0), Vector2(570, 0)), "Projectiles gain a clear line through the excavated shortcut")
	game.camera = Vector2(300, 0)
	await capture("03-tunnel")
	var revision_before = world.revision
	var bites_before = world.bite_serial
	game.show_pause()
	for i in 20: game._process(1.0 / 60)
	check(world.revision == revision_before and world.bite_serial == bites_before, "Pause freezes excavation and preserves the tunnel")
	game.show_game(); game.set_process(false)
	game.combat.enemies.clear(); game.combat.bullets.clear()
	var enemy = game.combat.spawn(game.db.pool["250"], Vector2(210, 0))
	enemy.guns = []; enemy.components = []; enemy.warp = 0; enemy.stop_distance = 0; enemy.movement = {"enginePower": 2.0, "rotEngineModifier": 120.0}
	game.player.parts[0].hp = 5000; game.player.parts[0].max_hp = 5000
	var route: Array = []
	var passed = false
	for frame in 420:
		game.combat.step(1.0 / 60, Vector2.ZERO, false, false)
		if frame % 12 == 0: route.append([enemy.position.x, enemy.position.y])
		if enemy.position.x > 490: passed = true; break
	check(passed and not world.blocked(enemy.position, enemy.radius), "Production monster chase AI walks through the freshly mined shortcut")
	game.camera = Vector2(300, 0)
	await capture("04-monster-follows")
	# Representative simulation timing, with rendering checked in these captures.
	game.combat.enemies.clear()
	for i in 100:
		var e = game.combat.spawn(game.db.pool["250"], Vector2(100 + (i % 10) * 18, (i / 10) * 18 - 90))
		e.guns = []; e.components = []; e.warp = 0; e.stop_distance = 0
	var timings: Array = []
	for frame in 45:
		var started = Time.get_ticks_usec()
		game.combat.step(1.0 / 60, Vector2.ZERO, false, false)
		if frame >= 5: timings.append(float(Time.get_ticks_usec() - started) / 1000.0)
	timings.sort()
	var performance = {"actors": 100, "simulation_median_ms": timings[timings.size() / 2], "simulation_p95_ms": timings[floori(timings.size() * 0.95)]}
	var mined_cells = world.removed_count; var ore_value = world.ore_total
	var bend = await curve_trial()
	var report = {"passed": checks.all(func(c): return c.passed), "exported": OS.has_feature("review_build"), "checks": checks, "captures": captures, "route": route, "performance": performance, "mined_cells": mined_cells, "ore_value": ore_value, "curve_trial": bend,"deployment":game.deployment_report}
	var report_path = capture_directory + "/cave-scene-report.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_directory))
	FileAccess.open(report_path, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	game.cursor_system.shutdown(); game.audio_system.shutdown(); game.particle_effects.clear(); game.queue_free()
	await process_frame; await process_frame
	quit(0 if report.passed else 1)

func curve_trial() -> Dictionary:
	# A fresh production run demonstrates the actual bite footprint at a bend,
	# with the same six modules and collision used in the shipped game.
	game.start_run(); game.set_process(false)
	var world = game.player.terrain
	game.combat.enemies.clear(); game.combat.drones.clear(); game.combat.enemy_drones.clear(); game.combat.loot.clear(); game.combat.effects.clear()
	var entry = world.wall_hit(Vector2.ZERO, Vector2(1000, 0), 30)
	game.player.head = Vector2(entry.position) + Vector2(entry.normal) * 0.35
	game.player.facing = Vector2.RIGHT
	for i in game.player.history.size(): game.player.history[i] = game.player.head - Vector2(i * 4, 0)
	for i in 6: game.player.append_segment(game.db.named("Core_Gun_Gatling").id)
	game.player.motion.reset(); game.player.refresh_positions()
	var clear = true; var path: Array = []
	var straight_removed = 0
	for direction in [Vector2.RIGHT, Vector2.UP]:
		for frame in 480:
			game.player.step(1.0 / 60, direction, false)
			game.leg_phase += game.player.velocity.length() / 60 * 0.075
			game.player_legs.step(game.player, 1.0 / 60)
			game.combat.step(1.0 / 60, Vector2.ZERO, false, false)
			clear = clear and game.player.body_poses.all(func(pose): return not world.blocked(pose.point, 26))
			if frame % 20 == 0: path.append([game.player.head.x, game.player.head.y])
			if direction == Vector2.RIGHT and game.player.head.x > 412: break
			if direction == Vector2.UP and game.player.head.y < -145: break
		if direction == Vector2.RIGHT and game.player.head.x <= 412: print("CURVE_ENTRY_DIAGNOSTIC=", JSON.stringify({"head": game.player.head, "hit": world.wall_hit(game.player.head, game.player.head + direction * 12, 30), "active": world.mining_active, "bites": world.bite_serial}))
		if direction == Vector2.RIGHT: straight_removed = world.removed_count
	check(game.player.head.x > 400 and game.player.head.y < -140 and world.removed_count > straight_removed, "Actual production excavation turns north inside rock and cuts a curved passage")
	check(clear, "All six body modules remain clear throughout the newly excavated bend")
	game.camera = Vector2(365, -55)
	await capture("05-rounded-bend")
	return {"path": path, "mined_cells": world.removed_count, "ore_value": world.ore_total}
