extends RefCounted
## Opt-in playtest validation, shared by editor checks and the actual EXE.
const Roster = preload("res://scripts/character_roster.gd")
const Store = preload("res://scripts/save_store.gd")
var game
var tree: SceneTree
var root: Window
var process_frame: Signal:
	get: return tree.process_frame

func _init(owner_game):
	game = owner_game;tree = game.get_tree();root = tree.root

static func isolated_profile() -> bool:
	var expected = OS.get_environment("RBPEW_TEST_SANDBOX").replace("\\", "/").to_lower() + "/"
	var actual = OS.get_user_data_dir().replace("\\", "/").to_lower() + "/"
	return expected != "/" and actual.begins_with(expected)

func quit(code: int):
	tree.quit(code)

func create_timer(seconds: float):
	return tree.create_timer(seconds)
var checks: Array = []
var captures: Array = []

func check_exit():
	print("TEST_USER_DIR=", OS.get_user_data_dir())
	for i in 120:await process_frame
	check(game.screen == "home", "Normal shipped entry point reaches home")
	await click_at(Vector2(418,661))
	check(not game.audio_system.music.playing and game.audio_system.music.stream == null, "Actual exit button stops audio")
	check(game.cursor_system.textures.is_empty(), "Actual exit button releases cursor textures")
	print(JSON.stringify({"passed":checks.all(func(item):return item.passed),"startup_exit":true,"checks":checks}))

func check(value: bool, label: String):
	checks.append({"name": label, "passed": value})
	if not value:printerr("FAIL: ", label)

func start():
	var expected = OS.get_environment("RBPEW_TEST_SANDBOX").replace("\\", "/").to_lower() + "/"
	var actual = OS.get_user_data_dir().replace("\\", "/").to_lower() + "/"
	if expected == "/" or not actual.begins_with(expected):
		printerr("ERROR: Refusing review test outside isolated user directory")
		quit(2)
		return
	print("TEST_USER_DIR=", OS.get_user_data_dir())
	call_deferred("execute")

func settle():
	for i in 4:await process_frame

func click_at(point: Vector2):
	var motion = InputEventMouseMotion.new()
	motion.position = point;motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT;event.position = point;event.global_position = point;event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate();event.pressed = false
	Input.parse_input_event(event)
	await settle()

func capture(label: String):
	if DisplayServer.get_name() == "headless":return
	game.queue_redraw();await settle();await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	check(image != null and not image.is_empty(), "Renderer produced " + label)
	if image == null or image.is_empty():return
	var path = "user://" + label + ".png"
	check(image.save_png(path) == OK, "Saved " + label)
	captures.append(ProjectSettings.globalize_path(path))

func drag_at(from: Vector2, to: Vector2):
	var press=InputEventMouseButton.new();press.position=from;press.global_position=from;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
	Input.parse_input_event(press);await process_frame
	for i in range(1,9):
		var motion=InputEventMouseMotion.new();motion.position=from.lerp(to,i/8.0);motion.global_position=motion.position;motion.relative=(to-from)/8;motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion);await process_frame
	press=press.duplicate();press.position=to;press.global_position=to;press.pressed=false
	Input.parse_input_event(press);await settle()

func press_skill():
	var focus = root.gui_get_focus_owner()
	if focus != null:focus.release_focus()
	var motion = InputEventMouseMotion.new();motion.position = Vector2(900,450);motion.global_position = motion.position
	Input.parse_input_event(motion)
	await settle()
	var event = InputEventKey.new();event.physical_keycode = KEY_SPACE;event.keycode = KEY_SPACE;event.pressed = true
	Input.parse_input_event(event);await settle()
	event = event.duplicate();event.pressed = false;Input.parse_input_event(event);await settle()

func execute():
	root.content_scale_size = Vector2i.ZERO;root.size = Vector2i(1440,900)
	if OS.get_environment("RBPEW_TEST_EXPORTED") == "1":
		check(OS.has_feature("template") and not OS.has_feature("editor"), "Test runs in actual exported Windows executable")
	await settle()
	game.set_process(false);game.test_mode = true
	check(game.screen == "home", "Fresh executable opens directly at home")
	check(game.save.state.roster_unlocked == ["centipede"], "Fresh colleague profile starts with normal roster")
	await click_at(Vector2(268,464))
	check(game.screen == "characters", "Actual home Nest button opens character screen")
	var nest = game.panel.get_child(0)
	check(nest.cards.keys() == Roster.ids(), "Nest displays only Centipede and Spider")
	check(is_equal_approx(nest.cards.centipede.position.x, 1440.0 - nest.cards.spider.position.x - nest.cards.spider.size.x), "Two character cards are centered")
	check(nest.debug_unlock_button.is_visible_in_tree(), "Debug unlock button is visible")
	await capture("review-01-debug-button")
	var previous = game.save.state.duplicate(true)
	var normal_path: String = game.save.path
	game.save.path = "user://missing-debug-test-directory/save.json"
	await click_at(nest.debug_unlock_button.get_global_rect().get_center())
	check(game.save.state == previous and nest.status.text.contains("未能保存"), "Failed debug save keeps roster locked and displays error")
	game.save.path = normal_path
	await click_at(nest.debug_unlock_button.get_global_rect().get_center())
	check(game.save.state.roster_unlocked == Roster.ids(), "Real mouse click unlocks both playable characters")
	previous.roster_unlocked = Roster.ids()
	check(game.save.state == previous, "Button preserves all unrelated profile progress")
	var reloaded = Store.new(game.db, normal_path)
	check(reloaded.state.roster_unlocked == Roster.ids(), "Unlocked characters reload from saved file")
	await click_at(nest.debug_unlock_button.get_global_rect().get_center())
	check(game.save.state.roster_unlocked.size() == 2, "Repeated button clicks are safe")
	await capture("review-02-all-unlocked")
	for dimensions in [Vector2i(1280,720),Vector2i(1440,900)]:
		root.size = dimensions;await settle()
		check(root.get_visible_rect().encloses(nest.debug_unlock_button.get_global_rect()), "Debug button fits viewport " + str(dimensions))
		check(nest.cards.values().all(func(card):return not card.get_global_rect().intersects(nest.debug_unlock_button.get_global_rect())), "Debug button does not cover character cards " + str(dimensions))
	game.show_menu();await settle()
	check(game.debug_unlock_button.is_visible_in_tree() and game.debug_unlock_button.text.contains("一键全开"),"Shipped home exposes the new full-unlock Debug button")
	await capture("review-05-home-full-unlock")
	await click_at(game.debug_unlock_button.get_global_rect().get_center())
	check(game.db.research.all(func(node):return node.nodeRewardsList.all(func(id):return game.save.available(id))),"Actual EXE home button unlocks every evolution tier")
	check(game.db.catalog.values().filter(func(reward):return str(reward.get("class","")).ends_with("Reward")).all(func(reward):return game.save.available(reward.id)),"Actual EXE home button unlocks and enables every skill reward")
	check(Roster.ids().all(func(id):return game.save.character_unlocked(id)),"Full unlock includes every playable character")
	check(Store.new(game.db,normal_path).state.unlocked==game.save.state.unlocked,"Full unlock persists in an independently reloaded EXE profile")
	for id in Roster.ids():
		game.show_characters();await settle();nest = game.panel.get_child(0)
		await click_at(nest.cards[id].get_global_rect().get_center())
		check(game.save.state.selected_character == id, "Mouse selects " + id)
		check(Store.new(game.db, normal_path).state.selected_character == id, "Selection persists: " + id)
		await click_at(Vector2(1215,804))
		check(game.screen == "menu", "Deploy from Nest opens expeditions for " + id)
		await click_at(game.mission_ui.launch_button.get_global_rect().get_center())
		check(game.screen == "game" and game.player.character_id == id, "Actual launch button starts " + id)
		check(game.player.module_cap() == int(Roster.config(id).slot_cap), "Correct mount capacity for " + id)
		if id == "spider":
			game.combat.spawn(game.db.pool["250"],game.player.head + Vector2(170,30))
			var enemy = game.combat.enemies.back();enemy.warp = 0.0;enemy.damageable = true;enemy.active = true
		await press_skill()
		check(game.combat.character_abilities.state().cooldown > 0, "Space activates " + id + " skill")
		match id:
			"centipede":check(game.player.coil_active, "Centipede coils")
			"spider":check(not game.combat.character_abilities.state().threads.is_empty(), "Spider connects enemy with silk")
		await capture("review-03-" + id)
		game.run.rewards.enqueue(true)
		var reward_time=float(game.run.elapsed)
		game._process(1.0/60.0);await settle()
		check(game.screen=="rewards" and game.reward_ui.buttons.size()==3,"Actual EXE automatically opens earned three-choice reward: "+id)
		game._process(0.25)
		check(game.run.elapsed==reward_time,"Three-choice reward pauses combat in exported game: "+id)
		game.postpone_rewards();await settle()
		var element=game.db.named("Core_Gun_Gatling").id
		game.player.append_segment(element);game.player.append_segment(element)
		game.show_build_ui();await settle()
		var ui=game.build_ui
		var mounts=ui.segment_buttons.keys();mounts.sort()
		await drag_at(ui.segment_buttons[mounts[0]].get_global_rect().get_center(),ui.segment_buttons[mounts[1]].get_global_rect().get_center())
		check(game.player.parts.size()==2 and int(game.player.parts[1].fusion_level)==2,"Exported native drag fuses mounted elements: "+id)
		check(game.screen=="build" and is_equal_approx(game.player.fusion_multiplier(1),2.2),"Exported fusion increases attack and leaves assembly open: "+id)
		for frame in 45:await process_frame
		check(ui.body_canvas.flagella.poses(int(game.player.parts[1].feedback_uid)).size()==2,"Exported evolved segment renders two flagella: "+id)
		await capture("review-04-fusion-"+id)
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await create_timer(0.25).timeout
	game.queue_free();await settle()
	var report = {"passed": checks.all(func(item):return item.passed), "checks": checks, "captures": captures, "user_data": OS.get_user_data_dir(), "renderer": DisplayServer.get_name(), "exported": OS.has_feature("template")}
	FileAccess.open("user://windows-review-test-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
