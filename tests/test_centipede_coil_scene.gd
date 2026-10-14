extends SceneTree
## Native main-scene sequence, at normal gameplay zoom. No debug segment labels.
## Set COIL_CAPTURE_FRAMES=1 to additionally save 60 entry animation frames.
var game
var checks: Array = []
var captures: Array = []
func _initialize(): call_deferred("execute")
func check(ok: bool, label: String):
	checks.append({"name": label, "passed": ok})
	if not ok: printerr("FAIL: ", label)
func advance(dt: float):
	game.player.step(dt, Vector2.ZERO, false)
	game.player_legs.step(game.player, dt)
	game.combat.character_abilities.update(dt)
	game.insect_layer.sync(game, dt)
func capture(label: String):
	game.sync_camera_layers()
	game.insect_layer.sync(game, 0)
	game.queue_redraw()
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var path = "res://artifacts/round9-coil-" + label + ".png"
	check(image != null and not image.is_empty(), "Main renderer produced " + label)
	if image == null or image.is_empty(): return
	check(image.save_png(path) == OK, "Saved " + label)
	captures.append(path)
func execute():
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game); await process_frame
	game.set_process(false)
	game.save.path = "user://round9-coil-scene-isolated.json"
	game.save.fresh(); game.save.state.settings.skip_boss = true
	game.save.select_character("centipede")
	game.start_run(); game.set_process(false)
	var modules = ["Core_Gun_Gatling", "Core_Gun_Shotgun", "Core_Gun_Cannon", "Core_Shield", "Core_Repair", "Core_Gun_Tesla"]
	for i in 12: game.player.append_segment(str(game.db.named(modules[i % modules.size()]).id))
	for i in 45: game.player.step(1.0 / 60, Vector2(1, 0.1), false)
	game.zoom = 1.0
	game.camera = game.player.head - Vector2(200, 0)
	game.center = Vector2(720, 450)
	game.show_game()
	var before = game.player.parts.map(func(p): return p.position)
	check(game.combat.request_skill(game.player.head + Vector2(350, 0)), "Live main-scene skill request starts coiling")
	check(before == game.player.parts.map(func(p): return p.position), "Native scene has no activation jump")
	await capture("entry-000")
	for frame in 60:
		advance(game.player.coil_rig.ENTER_DURATION / 60)
		if frame == 14: await capture("entry-025")
		if frame == 29: await capture("entry-050")
		if OS.get_environment("COIL_CAPTURE_FRAMES") == "1": await capture("animation-%03d" % frame)
	await capture("entry-100")
	check(game.player.coil_rig.phase == "hold", "Native scene reaches full coiled pose")
	var frozen = game.player.parts.map(func(p): return p.position)
	var coil_time = game.player.coil_rig.elapsed
	var skill_time = game.combat.character_abilities.active
	game.show_pause()
	for frame in 30: game._process(1.0 / 60)
	check(frozen == game.player.parts.map(func(p): return p.position) and coil_time == game.player.coil_rig.elapsed and skill_time == game.combat.character_abilities.active, "Actual pause menu freezes physical coil and skill timer")
	game.show_game()
	# Finish naturally at the existing 2.4-second skill boundary.
	while game.combat.character_abilities.active > 0: advance(minf(1.0 / 60, game.combat.character_abilities.active))
	await capture("exit-000")
	for frame in 60:
		advance(game.player.coil_rig.EXIT_DURATION / 60)
		if frame == 14: await capture("exit-025")
		if frame == 29: await capture("exit-050")
	await capture("exit-100")
	check(not game.player.coil_rig.engaged(), "Native release finishes back in ordinary follower motion")
	check(is_equal_approx(game.zoom, 1), "All native captures use normal gameplay zoom")
	game.player.begin_coil(); advance(0.1)
	game.player.reset(); game.combat.character_abilities.update(0)
	check(not game.player.coil_rig.engaged() and game.combat.character_abilities.active == 0, "Native run reset clears transition and ability serial")
	game.cursor_system.shutdown(); game.audio_system.shutdown(); game.particle_effects.clear()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.queue_free(); await process_frame; await process_frame
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks, "captures": captures, "renderer": DisplayServer.get_name()}
	FileAccess.open("res://artifacts/centipede-round9-coil-scene-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
