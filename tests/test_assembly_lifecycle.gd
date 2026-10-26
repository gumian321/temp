extends SceneTree

var checks: Array = []

func check(value: bool, name: String):
	checks.append({"name": name, "passed": value})
	if not value: push_error(name)

func _initialize(): call_deferred("execute")

func execute():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 3: await process_frame
	game.set_process(false)
	game.test_mode = true
	game.save.fresh()
	game.start_run()
	game.show_build_ui()
	for i in 3: await process_frame
	# Queue redraws on the outgoing canvas, then replace the character and its
	# assembly screen in one turn, just as quick screen/run changes can do.
	for character in ["spider", "centipede", "spider", "centipede"]:
		var retired_panel = game.panel
		var retired_canvas = game.build_ui.body_canvas
		retired_canvas.queue_redraw()
		game.player.configure_character(character)
		game.show_build_ui()
		check(not retired_panel.is_inside_tree(), "Outgoing assembly leaves the live UI immediately: " + character)
		check(game.ui.get_child_count() == 1, "Only one live screen receives input: " + character)
		var canvas = game.build_ui.body_canvas
		check(canvas.is_inside_tree(), "Replacement assembly is live: " + character)
		check(is_instance_valid(game.build_ui.spider_preview) if character == "spider" else not canvas.points.is_empty(), "Replacement assembly owns geometry for its character: " + character)
		var retired_scale = retired_panel.scale
		root.size = Vector2i(1280, 720) if character == "spider" else Vector2i(1440, 900)
		root.size_changed.emit()
		check(retired_panel.scale == retired_scale, "Retired assembly ignores viewport resizing: " + character)
		for i in 3: await process_frame
		check(not is_instance_valid(retired_panel), "Outgoing assembly is freed after the frame: " + character)
	for screen in ["lab", "reward_pool"]:
		if screen == "lab": game.show_lab()
		else: game.show_reward_pool()
		for i in 3: await process_frame
		var retired_view = game.panel.get_child(0)
		var retired_scale = retired_view.scale
		game.show_menu()
		root.size = Vector2i(960, 600) if screen == "lab" else Vector2i(1440, 900)
		root.size_changed.emit()
		check(retired_view.scale == retired_scale, "Retired view ignores viewport resizing: " + screen)
		for i in 3: await process_frame
	game.show_build_ui()
	var retired_builder = game.build_ui
	retired_builder.rebuild.call_deferred()
	game.show_game()
	for i in 3: await process_frame
	check(game.screen == "game" and not is_instance_valid(retired_builder), "Same-frame assembly close cancels its deferred focus and rebuild work")
	game.show_lab()
	var retired_lab = game.panel.get_child(0)
	retired_lab.show_detail(game.db.research[0], 0)
	game.show_menu()
	for i in 3: await process_frame
	check(game.screen == "home" and not is_instance_valid(retired_lab), "Same-frame research close cancels its deferred detail focus")
	game.cursor_system.shutdown()
	game.audio_system.shutdown()
	game.particle_effects.clear()
	game.queue_free()
	for i in 3: await process_frame
	var report = {"checks": checks, "passed": checks.all(func(c): return c.passed)}
	FileAccess.open("res://artifacts/assembly-lifecycle-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if report.passed else 1)
