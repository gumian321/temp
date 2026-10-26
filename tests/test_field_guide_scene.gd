extends "res://tests/test_ui_small_windows.gd"
## Focused visual/layout acceptance for the two field-guide screens.
func execute():
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate(); root.add_child(game); await settle()
	game.set_process(false); game.test_mode = true; game.save.fresh()
	game.save.state.meta = 1234567
	var state_before = game.save.state.duplicate(true)
	for extent in [Vector2i(1440, 900), Vector2i(1280, 720), Vector2i(800, 600)]:
		root.size = extent; await settle()
		game.show_menu(); await settle()
		await audit("field-home-%dx%d" % [extent.x, extent.y], game.panel)
		check(game.panel.get_node("HomeSpecimen").character_id == "centipede", "Home specimen follows selected centipede")
		game.show_missions(); await settle()
		for i in 6:
			game.mission_ui.select_mission(i); game.mission_ui.rows[i].grab_focus(); await settle()
			var asset = game.mission_ui.scene_art.NAMES[i]
			check(game.mission_ui.scene_art.texture.resource_path.ends_with("scene-" + asset + ".png"), "Generated painting follows selected mission %d" % i)
			check(game.mission_ui.scene_art.size == Vector2(676, 338), "Mission painting stays in the reserved art area")
			check(game.mission_ui.scene_icons[i].texture.resource_path.ends_with("icon-" + asset + ".png"), "Each mission has its own generated icon")
			check(game.mission_ui.scene_icons.filter(func(icon): return icon.selected).size() == 1, "Exactly one illustrated icon is selected")
			if extent == Vector2i(1440, 900):
				var icon = game.mission_ui.scene_icons[i].texture.get_image()
				check(icon.detect_alpha() != Image.ALPHA_NONE and icon.get_pixel(0, 0).a == 0, "Generated icon has transparent background")
			await audit("field-mission-%d-%dx%d" % [i, extent.x, extent.y], game.panel)
		var illustration = game.mission_ui.scene_art.texture
		game.mission_ui.select_difficulty(1); await settle()
		check(game.mission_ui.scene_art.texture == illustration, "Changing difficulty reuses the loaded painting")
	check(game.save.state == state_before, "Browsing specimens and operations preserves player progress")
	root.size = Vector2i(1440, 900)
	game.save.state.selected_character = "spider"
	game.show_menu(); await settle()
	check(game.panel.get_node("HomeSpecimen").character_id == "spider", "Home switches to the actual spider parts")
	await audit("field-spider-home", game.panel)
	game.show_missions(); await settle()
	check(game.save.state.selected_character == "spider" and game.mission_ui.scene_art.texture != null, "Mission painting loads with the spider selected without changing the character")
	await audit("field-spider-mission", game.panel)
	game.db.language = "English"; root.size = Vector2i(960, 600)
	game.show_menu(); await settle(); await audit("field-home-english", game.panel)
	game.show_missions(); await settle()
	for i in 6:
		game.mission_ui.select_mission(i); await settle()
		await audit("field-mission-english-%d" % i, game.panel)
	game.cursor_system.shutdown(); game.audio_system.shutdown(); game.particle_effects.clear()
	game.queue_free(); await settle()
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks, "issues": issues, "captures": captures}
	FileAccess.open("res://artifacts/field-guide-scene-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify({"passed": report.passed, "issues": issues}))
	quit(0 if report.passed else 1)
