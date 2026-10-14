extends "res://tests/test_centipede_scene.gd"
## Production main scene, persisted selected-character profile, normal zoom.
## Run tools/run_checks.py spider_visibility_scene --render in an isolated profile.
const SpiderArt = preload("res://scripts/spider_art.gd")
var pixel_results: Array = []

func frame_image() -> Image:
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func verify_visible_body(label: String):
	SpiderArt.prepare()
	check(not SpiderArt.pieces.is_empty(), label + ": generated atlas pieces are present")
	var valid = true
	for piece in SpiderArt.pieces.values():
		valid = valid and piece != null and piece.atlas != null
	check(valid, label + ": every body/leg piece has a real texture")
	if not valid or DisplayServer.get_name() == "headless": return
	var with_body = await frame_image()
	check(with_body.save_png("res://artifacts/" + label + ".png") == OK, "Captured " + label)
	captures.append("res://artifacts/" + label + ".png")
	# An actual render differential detects the user's floating-turret regression.
	# Keep the same main scene, towers, camera, profile, and transforms; replace
	# only the atlas with transparent pixels for one control frame.
	var saved: Dictionary = {}
	for key in SpiderArt.pieces:
		var piece = SpiderArt.pieces[key]
		saved[key] = piece.atlas
		var blank = Image.create(piece.atlas.get_width(), piece.atlas.get_height(), false, Image.FORMAT_RGBA8)
		blank.fill(Color.TRANSPARENT)
		piece.atlas = ImageTexture.create_from_image(blank)
	var without_body = await frame_image()
	for key in SpiderArt.pieces: SpiderArt.pieces[key].atlas = saved[key]
	var difference = 0
	# Central battlefield only: excludes HUD counters and menu decorations.
	for y in range(260, 640):
		for x in range(490, 950):
			var a = with_body.get_pixel(x, y)
			var b = without_body.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.08:
				difference += 1
	pixel_results.append({"capture": label, "zoom": game.zoom, "changed_body_pixels": difference})
	check(difference > (400 if game.zoom == 1.0 else 20), label + ": body and bare legs visibly change battlefield pixels")
	game.queue_redraw()

func execute():
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	# Persist through the production SaveStore, then load a new scene. This
	# covers launch selection instead of forcibly configuring the live player.
	game.save.state.roster_unlocked = ["centipede", "spider", "beetle"]
	game.save.state.settings.skip_boss = true
	check(game.save.select_character("spider"), "Persist spider selection to isolated player profile")
	game.cursor_system.shutdown(); game.audio_system.shutdown(); game.particle_effects.clear()
	game.queue_free()
	await process_frame
	await process_frame
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	check(game.save.state.selected_character == "spider", "Restart reads saved spider selection")
	game.begin_run()
	game.set_process(false)
	game.camera_focus.clear()
	game.combat.enemies.clear()
	game.camera = game.player.head
	game.show_game()
	check(game.player.character_id == "spider", "Production begin_run uses selected spider")
	check(game.zoom == 1.0, "Normal production zoom is 1.0, with no enlarged test override")
	check(game.player.parts.size() == 1 and game.player.spider_rig.legs.size() == 8, "Zero installed modules still creates eight bare legs")
	await verify_visible_body("spider-visible-default-bare")
	var gun = game.db.named("Core_Gun_Gatling").id
	game.player.install_module(gun, game.player.spider_mount(0, 0))
	game.player.install_module(gun, game.player.spider_mount(3, 0))
	for frame in 45: game.player.step(1.0 / 60.0, Vector2.RIGHT, false)
	game.camera = game.player.head
	await verify_visible_body("spider-visible-default-two-towers")
	game.zoom = 0.25
	await verify_visible_body("spider-visible-radar-two-towers")
	game.cursor_system.shutdown(); game.audio_system.shutdown(); game.particle_effects.clear()
	game.queue_free()
	await process_frame
	await process_frame
	var report = {"checks": checks, "captures": captures, "pixel_results": pixel_results, "passed": checks.all(func(c): return c.passed)}
	FileAccess.open("res://artifacts/spider-visibility-scene-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if report.passed else 1)
