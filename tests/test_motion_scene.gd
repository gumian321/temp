extends "res://tests/test_centipede_scene.gd"
## Real keyboard input in the actual game. The preview deliberately omits enemies
## so starts, turns, reversals and idle motion can be inspected without combat noise.
var clip_frames = 0

func movement(keys: Array):
	for action in ["move_right", "move_up", "move_left", "move_down"]:
		if action in keys: Input.action_press(action)
		else: Input.action_release(action)

func record_frame():
	if DisplayServer.get_name() == "headless": return
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var picture = root.get_texture().get_image()
	picture.resize(1080, 675, Image.INTERPOLATE_LANCZOS)
	var path = "res://artifacts/motion-frames/frame-%04d.png" % clip_frames
	if picture.save_png(path) != OK: printerr("ERROR: Could not save motion frame ", clip_frames)
	clip_frames += 1

func execute():
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.save.state.settings.skip_boss = true
	game.start_run()
	game.run.rewards.enqueue(true)
	game._process(.016)
	await process_frame
	check(game.screen == "rewards" and game.run.offers.size() == 3, "Earned pack automatically opens three choices")
	await capture("centipede-choose-one-reward")
	var selected = false
	for i in range(game.run.offers.size()):
		var reward: Dictionary = game.run.offers[i]
		if reward.get("class") != "BlockReward" or not game.run.can_reward(reward): continue
		var button = game.reward_ui.buttons[i]
		await click_at(button.get_global_rect().get_center())
		selected = true
		break
	check(selected and game.screen == "build" and game.player.pending.size() > 0 and game.run.packs == 0, "Selecting a module consumes one pack and returns to assembly with the item")
	if not selected:
		game.queue_free(); quit(1); return
	var module_count = game.player.pending.size()
	for i in range(module_count):
		await click_at(game.build_ui.inventory[0].get_global_rect().get_center())
		await click_at(game.build_ui.slots[i].get_global_rect().get_center())
	check(game.player.pending.is_empty() and game.player.parts.size() == module_count + 1, "Claimed modules can actually be installed from the explained inventory")
	# Clear fixture equipment, then mount a readable mix of colored source towers.
	game.player.reset()
	var modules = ["Core_Gun_Gatling", "Core_Gun_Cannon", "Core_Gun_Tesla", "Core_Gun_Shotgun", "Core_Gun_EMP", "Core_Gun_Flame Thrower"]
	for i in range(modules.size()): game.player.install_module(game.db.named(modules[i]).id, i + 1, 4)
	game.combat.enemies.clear()
	game.combat.drones.clear()
	game.run.timers = {"swarm": 999.0, "wave": 999.0, "patrol": 999.0}
	game.run.encounters.enabled = false
	game.run.rewards.queue.clear(); game.run.packs = 0
	# Keep the in-game instructional overlay out of this isolated motion preview.
	game.tutorials.movement_shown = true
	game.tutorials.radar_shown = true
	game.tutorials.fuel_shown = true
	game.show_game()
	game.zoom = 1.1
	var input_label = game.label_at("", Vector2(460, 100), 23)
	var stages = [
		{"keys": ["move_right"], "label": "D · 起步 / 前进", "frames": 90},
		{"keys": ["move_up"], "label": "W · 向上转弯", "frames": 90},
		{"keys": ["move_left"], "label": "A · 向左转弯", "frames": 90},
		{"keys": ["move_down"], "label": "S · 向下转弯", "frames": 90},
		{"keys": ["move_right"], "label": "D · 连续转弯", "frames": 90},
		{"keys": ["move_left"], "label": "A · 反向掉头", "frames": 90},
		{"keys": [], "label": "松开按键 · 停住 / 尾部轻摆", "frames": 120},
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/motion-frames"))
	var total_frames = 0
	var max_head_step = 0.0
	for stage in stages:
		movement(stage.keys)
		input_label.text = stage.label
		var initial_head: Vector2 = game.player.head
		for frame in range(stage.frames):
			var previous_head: Vector2 = game.player.head
			game._process(1.0 / 60.0)
			game.combat.enemies.clear()
			max_head_step = maxf(max_head_step, previous_head.distance_to(game.player.head))
			if total_frames % 3 == 0: await record_frame()
			total_frames += 1
		check(game.screen == "game", "Main loop stays playable during " + stage.label)
		if not stage.keys.is_empty(): check(game.player.head.distance_to(initial_head) > 60.0, "Keyboard input moves the character during " + stage.label)
		if stage.label.begins_with("W") or stage.label.begins_with("A"): await capture("centipede-motion-%d" % total_frames)
	movement([])
	check(game.player.velocity.length() < 0.01, "Releasing real game input stops the head")
	check(max_head_step < 3.0, "Head movement in the main loop has no teleport frames")
	await capture("centipede-motion-idle")
	game.cursor_system.shutdown(); game.audio_system.shutdown(); game.particle_effects.clear()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await create_timer(0.25).timeout
	game.queue_free()
	await process_frame
	await process_frame
	var report = {"checks": checks, "captures": captures, "clip_frames": clip_frames, "clip_fps": 20, "passed": checks.all(func(c): return c.passed), "scope": "Real game input, deliberately staged equipment and no enemies for motion inspection."}
	FileAccess.open("res://artifacts/motion-scene-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if report.passed else 1)
