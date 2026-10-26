extends "res://tests/test_centipede_scene.gd"
## Native deterministic before/after recording uses the actual game render path.
## SPIDER_TURN_RECORD=after (or before), optional SPIDER_RIG_BASELINE=absolute .gd.
func execute():
	root.size = Vector2i(1440,900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.test_mode = true
	game.save.state.roster_unlocked = ["centipede", "spider"]
	game.save.select_character("spider")
	game.begin_run()
	var deployment_deadline = Time.get_ticks_msec() + 30000
	while game.deployment_active and Time.get_ticks_msec() < deployment_deadline: await process_frame
	var deployment_ready = not game.deployment_active and game.screen == "game" and game.run != null
	check(deployment_ready, "Production spider deployment completes within 30 seconds")
	if not deployment_ready:
		quit(1)
		return
	game.set_process(false)
	game.zoom = 1.0
	game.camera_focus.clear()
	game.show_game()
	game.combat.enemies.clear()
	game.combat.bullets.clear()
	var gun = game.db.named("Core_Gun_Gatling").id
	while game.player.parts.size() < 33: game.player.append_segment(gun)
	var baseline = OS.get_environment("SPIDER_RIG_BASELINE")
	if not baseline.is_empty(): game.player.spider_rig = load(baseline).new()
	for frame in 180: game.player.step(1.0/60.0, Vector2.ZERO, false)
	var label = OS.get_environment("SPIDER_TURN_RECORD")
	var record = not label.is_empty() and DisplayServer.get_name() != "headless"
	var directory = "res://artifacts/spider-turn-" + label
	if record: DirAccess.make_dir_recursive_absolute(directory)
	var synchronized = true
	for frame in 180:
		var direction = Vector2.RIGHT if frame < 30 else (Vector2.LEFT if frame < 90 else Vector2.RIGHT)
		if frame >= 150: direction = Vector2.ZERO
		game.player.step(1.0/60.0, direction, true)
		for index in range(1,game.player.parts.size()):
			var part = game.player.parts[index]
			var pose = game.player.spider_rig.mount_pose(part.segment)
			synchronized = synchronized and part.position.distance_to(pose.point) < 0.001 and game.player.weapon_origin(index).distance_to(pose.point) < 0.001
		game.camera = game.player.head
		game._process(0.0)
		game.queue_redraw()
		if record:
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory + "/%04d.png" % frame)
	check(synchronized, "All 32 weapons and collisions share actual continuous leg sockets through boosted reversals")
	game.cursor_system.shutdown(); game.audio_system.shutdown(); game.particle_effects.clear(); game.queue_free()
	await process_frame
	print(JSON.stringify({"checks": checks, "recorded": record, "frames":180}))
	quit(0 if synchronized else 1)
