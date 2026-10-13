extends SceneTree
## Real main-scene input, construction and combat checks; optional renderer captures.
var game
var checks: Array = []
var captures: Array = []

func check(value: bool, title: String):
	checks.append({"name": title, "passed": value})
	if not value: printerr("FAIL: ", title)

func _initialize():
	call_deferred("execute")

func click_at(point: Vector2):
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await process_frame

func drag_at(from: Vector2, to: Vector2, capture_drag: bool = false, via: Vector2 = Vector2(-1,-1)):
	var motion = InputEventMouseMotion.new()
	motion.position = from; motion.global_position = from
	Input.parse_input_event(motion)
	await process_frame
	var press = InputEventMouseButton.new()
	press.position=from;press.global_position=from;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
	Input.parse_input_event(press)
	await process_frame
	var previous=from
	for step in range(1,9):
		var point=from.lerp(to,step/8.0) if via.x<0 else (from.lerp(via,step/4.0) if step<=4 else via.lerp(to,(step-4)/4.0))
		motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;motion.relative=point-previous;motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
		previous=point
		await process_frame
	check(root.gui_is_dragging(), "Native drag preview is active before mouse release")
	if capture_drag: await capture("centipede-05-drag-preview")
	press=press.duplicate();press.position=to;press.global_position=to;press.pressed=false
	Input.parse_input_event(press)
	await process_frame
	await process_frame
func capture(label: String):
	game._process(0.0)
	game.queue_redraw()
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	check(image != null and not image.is_empty(), "Renderer produced " + label)
	if image == null or image.is_empty(): return
	var path = "res://artifacts/" + label + ".png"
	check(image.save_png(path) == OK, "Saved " + label)
	captures.append(path)

func visible_text(node: Node) -> String:
	var value = ""
	if (node is Label or node is Button or node is RichTextLabel) and node.is_visible_in_tree():
		value += node.text + "\n"
	for child in node.get_children(): value += visible_text(child)
	return value

func execute():
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	if not game.has_method("start_run"):
		printerr("ERROR: Main scene script could not be loaded")
		game.free()
		quit(1)
		return
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.test_mode = true
	check(game.save.state.settings.language == "Chinese (simplified)", "Fresh user defaults to Simplified Chinese")
	game.show_menu()
	await process_frame
	var menu_text = visible_text(game.panel)
	check("开始" in menu_text or "游戏" in menu_text, "Main menu contains Chinese navigation")
	await capture("centipede-01-chinese-menu")
	game.save.state.settings.skip_boss = true
	game.start_run()
	check(game.player.parts.size() == 1, "Fresh run has no installed tower fixture")
	check(game.player.segment_count() >= 6, "Fresh run shows at least six empty body segments")
	check(game.player.segment_pose(6).point.distance_to(game.player.head) > 300.0, "Bare centipede has a visible extended tail")
	await capture("centipede-02-fresh-run")
	var modules = ["Core_Gun_Gatling", "Core_Gun_Shotgun", "Core_Gun_Cannon", "Core_Shield", "Core_Repair", "Core_Gun_Tesla", "Core_Gun_EMP", "Core_Chip_Mammoth", "Core_FuelTank", "Core_Gun_Gatling"]
	for module in modules:
		var core = game.db.named(module)
		check(not core.is_empty(), "Source module exists: " + module)
		game.player.pending.append(core.id)
	game.show_build_ui()
	await process_frame
	check(game.screen == "build" and game.build_ui.slots.size()==9, "Pending modules open the nine-slot drag construction screen")
	await drag_at(game.build_ui.inventory[0].get_global_rect().get_center(),Vector2(850,780))
	check(game.player.parts.size()==1 and game.player.pending.size()==10, "Dropping outside all mounts cancels without consuming a pending module")
	for slot in range(9):
		if slot < 3:
			await drag_at(game.build_ui.inventory[0].get_global_rect().get_center(),game.build_ui.slots[slot].get_global_rect().get_center(),slot==0)
		else:
			await click_at(game.build_ui.inventory[0].get_global_rect().get_center())
			await click_at(game.build_ui.slots[slot].get_global_rect().get_center())
		check(game.player.part_at(1,slot)>0 and game.player.parts.size()==slot+2, "Mouse installs exactly one module in grid slot %d"%slot)
	check(game.player.segment_count()==6 and game.player.parts_on_segment(1).size()==9, "Filling all nine mounts keeps the same shell width and body length")
	await drag_at(game.build_ui.inventory[0].get_global_rect().get_center(),game.build_ui.slots[0].get_global_rect().get_center())
	check(game.player.pending.size()==1 and game.player.parts.size()==10, "Occupied target rejects an inventory drop without losing the item")
	await drag_at(game.build_ui.inventory[0].get_global_rect().get_center(),game.build_ui.tail_target.get_global_rect().get_center())
	check(game.player.segment_count()==7 and game.player.part_at(7,4)>0 and game.player.pending.is_empty(), "Dropping on the tail grows exactly one body segment and mounts the item")
	await click_at(game.build_ui.segment_buttons[1].get_global_rect().get_center())
	check("武装" in visible_text(game.panel), "Construction title is Chinese")
	check(visible_text(game.panel).length()<100,"Assembly communicates with icons and short labels, not paragraphs")
	await capture("centipede-03-segment-construction")
	game.show_game()
	for frame in range(110):
		game._process(1.0 / 60.0)
		if frame % 20 == 0: await process_frame
	check(game.player.head.length() > 70.0, "Real main loop moves the centipede")
	check(game.combat.bullets.size() > 0, "Installed towers fire in the real combat loop")
	check(game.player.parts_on_segment(1).size()==9 and game.player.module_size(1)==14, "All nine installed modules retain compact independent world mounts")
	game.zoom=1.6;game.camera=game.player.head-Vector2(140,0)
	await capture("centipede-04-armed-combat")
	game.player.actions = {"move": 2, "swap": 1, "duplicate": 1, "wall": 1}
	game.show_build_ui()
	await process_frame
	var source=game.player.part_at(1,0)
	await drag_at(game.build_ui.slots[0].get_global_rect().get_center(),game.build_ui.slots[1].get_global_rect().get_center())
	check(game.player.part_at(1,1)==source and game.player.actions.swap==0, "Native drag swaps occupied mounts and consumes one swap token")
	await drag_at(game.build_ui.slots[1].get_global_rect().get_center(),game.build_ui.tail_target.get_global_rect().get_center())
	check(game.player.part_at(8,4)==source and game.player.part_at(1,1)<0 and game.player.actions.move==1, "Native drag moves a module to a new tail segment and consumes one move token")
	await drag_at(game.build_ui.slots[4].get_global_rect().get_center(),game.build_ui.slots[4].get_global_rect().get_center(),false,game.build_ui.segment_buttons[2].get_global_rect().get_center())
	check(game.player.part_at(2,4)==source and game.player.part_at(8,4)<0 and game.player.actions.move==0,"Hovering another shell during native drag switches grids without losing the dragged module")
	await click_at(game.build_ui.segment_buttons[1].get_global_rect().get_center())
	await click_at(game.build_ui.slots[0].get_global_rect().get_center())
	await click_at(game.build_ui.copy_button.get_global_rect().get_center())
	await click_at(game.build_ui.slots[1].get_global_rect().get_center())
	check(game.player.parts.size()==12 and game.player.actions.duplicate==0, "Click fallback duplicates into the selected empty grid slot")
	await click_at(game.build_ui.slots[1].get_global_rect().get_center())
	await click_at(game.build_ui.armor_button.get_global_rect().get_center())
	check(game.player.parts[game.player.part_at(1,1)].wall and game.player.actions.wall==0, "Armor applies to the selected local mount")
	game.cursor_system.shutdown()
	game.audio_system.shutdown()
	game.particle_effects.clear()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	# The audio/render threads must drain after the final UI click before their
	# stream resources are freed, just as the application's safe_shutdown does.
	await create_timer(0.25).timeout
	game.queue_free()
	await process_frame
	await process_frame
	var report = {"checks": checks, "captures": captures, "passed": checks.all(func(item): return item.passed), "user_data": OS.get_user_data_dir(), "renderer": DisplayServer.get_name()}
	var report_name = "centipede-scene-test-report.json" if DisplayServer.get_name() == "headless" else "centipede-scene-render-report.json"
	FileAccess.open("res://artifacts/" + report_name, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if report.passed else 1)
