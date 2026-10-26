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
	var good_path = "user://ui-save-failures.json"
	game.save.path = good_path
	game.controls.bind("move_left", KEY_J)
	check(int(game.save.state.settings.bindings.move_left) == KEY_J, "Successful rebinding is stored")
	# An absent parent directory deterministically rejects the temporary save.
	game.save.path = "user://missing-ui-save-directory/profile.json"
	game.controls.bind("move_left", KEY_H)
	check(int(game.save.state.settings.bindings.move_left) == KEY_J, "Failed rebind preserves the previous saved key")
	var mapped = InputMap.action_get_events("move_left")
	check(mapped.size() == 1 and mapped[0].physical_keycode == KEY_J, "Failed rebind preserves the live input mapping")
	game.controls.bind("unknown_action", KEY_K)
	check(not game.save.state.settings.bindings.has("unknown_action"), "Unknown input actions cannot be saved")
	game.save.state.disabled.append(game.save.state.unlocked[0])
	var excluded: Array = game.save.state.disabled.duplicate()
	game.show_missions()
	for i in 3: await process_frame
	game.mission_ui.reset_pool()
	check(game.save.state.disabled == excluded, "Failed pool reset preserves the current reward exclusions")
	check(game.mission_ui.reset_button.visible, "Failed pool reset keeps the retry control available")
	check(game.mission_ui.status.text == game.db.ui("SAVE FAILED · FILTER UNCHANGED", "保存失败 · 筛选未更改"), "Failed pool reset reports the failure visibly")
	game.save.path = good_path
	game.mission_ui.reset_pool()
	check(game.save.state.disabled.is_empty(), "Retrying pool reset succeeds with a writable save path")
	var restored = load("res://scripts/save_store.gd").new(game.db, good_path)
	check(restored.state.disabled.is_empty() and int(restored.state.settings.bindings.move_left) == KEY_J, "Fresh save load matches successful UI edits only")
	game.cursor_system.shutdown()
	game.audio_system.shutdown()
	game.particle_effects.clear()
	game.queue_free()
	for i in 3: await process_frame
	var report = {"checks": checks, "passed": checks.all(func(c): return c.passed)}
	FileAccess.open("res://artifacts/ui-save-failures-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if report.passed else 1)
