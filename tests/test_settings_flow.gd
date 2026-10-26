extends SceneTree
var checks:Array=[]
var game
func _initialize():call_deferred("execute")
func check(ok:bool,title:String):
	checks.append({"name":title,"passed":ok})
	if not ok:push_error(title)
func settle():
	await process_frame
	await process_frame
func execute():
	game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
	game.set_process(false);game.save.path="user://settings-flow.json";game.save.fresh();game.controls.apply()
	for route in ["keyboard","controller","button"]:
		game.show_menu();game.show_options();await settle()
		var staged_language="Russian" if game.save.state.settings.language=="English" else "English"
		game.options_draft.language=staged_language
		game.show_controls();await settle()
		var code=KEY_J if route=="keyboard" else (KEY_K if route=="controller" else KEY_L)
		game.controls.bind("move_left",code)
		game.save.state.settings.invert_x=not game.save.state.settings.invert_x
		var inverted=game.save.state.settings.invert_x
		game.save.save()
		if route=="keyboard":
			var event=InputEventKey.new();event.physical_keycode=KEY_ESCAPE;event.pressed=true
			game._unhandled_input(event)
		elif route=="controller":
			var event=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_B;event.pressed=true
			game._input(event)
		else:
			var buttons=[];game.collect_focus_buttons(game.panel,buttons);buttons[0].pressed.emit()
		await settle()
		check(game.screen=="options",route+" returns to settings")
		check(game.options_draft.language==staged_language,route+" preserves unapplied display/language choices")
		# Keep the check window small and windowed, including native-render runs.
		game.options_draft.screen_mode=2;game.options_draft.resolution=0
		game.apply_options();await settle()
		var reloaded=load("res://scripts/save_store.gd").new(game.db,game.save.path)
		check(int(reloaded.state.settings.bindings.get("move_left",0))==code,route+" Apply preserves rebound key after reload")
		check(reloaded.state.settings.invert_x==inverted,route+" Apply preserves controller options after reload")
	game.show_menu();game.show_options();game.options_draft.language="Russian";game.show_menu()
	game.save.state.settings.volume=0.31;game.save.save();game.show_options();await settle()
	check(game.options_draft.language==game.save.state.settings.language,"Leaving settings discards unapplied language changes")
	check(is_equal_approx(float(game.options_draft.volume),0.31),"Reopening settings refreshes live audio preferences")
	game.save.path="user://missing-settings-directory/settings.json"
	var before=game.save.state.duplicate(true)
	var language_before=game.db.language
	game.options_draft.language="Russian" if language_before!="Russian" else "English"
	game.apply_options();await settle()
	check(game.save.state==before and game.db.language==language_before,"Failed Apply preserves the saved and active settings")
	check(game.screen=="options" and not game.options_error.is_empty(),"Failed Apply provides a visible retry message")
	game.source_ui_action("ApplyResettButton","",{});await settle()
	check(game.save.state==before and game.screen=="options" and not game.options_error.is_empty(),"Failed reset retains progress and reports failure in settings")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
	FileAccess.open("res://artifacts/settings-flow-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	game.cursor_system.shutdown();game.audio_system.shutdown();game.queue_free();await settle()
	quit(0 if report.passed else 1)
