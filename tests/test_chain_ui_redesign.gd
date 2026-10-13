extends "res://tests/test_centipede_scene.gd"
## Native pointer regression checks for the stable equipment rail.
func settle():
	for i in range(4):await process_frame
func start_drag(from:Vector2,to:Vector2):
	var motion=InputEventMouseMotion.new();motion.position=from;motion.global_position=from
	Input.parse_input_event(motion);await process_frame
	var press=InputEventMouseButton.new();press.position=from;press.global_position=from;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
	Input.parse_input_event(press);await process_frame
	for i in range(1,9):
		motion=InputEventMouseMotion.new();motion.position=from.lerp(to,i/8.0);motion.global_position=motion.position;motion.relative=(to-from)/8;motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion);await process_frame
func release_at(at:Vector2):
	var release=InputEventMouseButton.new();release.position=at;release.global_position=at;release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false
	Input.parse_input_event(release);await settle()
func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
	game.set_process(false);game.test_mode=true;game.save.state.settings.skip_boss=true;game.start_run()
	for name in ["Core_Gun_Gatling","Core_Gun_Cannon","Core_Shield","Core_Repair"]:game.player.append_segment(game.db.named(name).id)
	game.player.pending.append(game.db.named("Core_Gun_Tesla").id)
	game.show_build_ui();await settle()
	var ui=game.build_ui
	check(ui.return_button.get_theme_stylebox("normal") is StyleBoxTexture and ui.return_button.get_theme_color("font_color")==load("res://scripts/game_ui.gd").TEXT,"Generated light action skin and navy text survive deferred global theme application")
	var rail=ui.chain_scroll
	var card=ui.segment_buttons[2]
	await click_at(card.get_global_rect().get_center())
	check(is_instance_valid(card) and ui.segment_buttons[2]==card and ui.chain_scroll==rail,"Selection retains native cards, rail, and keyboard focus")
	check(card.has_focus(),"Clicked card keeps keyboard focus without a rebuild")
	var first:Dictionary=game.player.parts[game.player.part_at(1)]
	var third:Dictionary=game.player.parts[game.player.part_at(3)]
	var swap_at=ui.segment_buttons[3].get_global_rect().get_center()
	await start_drag(ui.segment_buttons[1].get_global_rect().get_center(),swap_at)
	check(ui.hovered_target=={"kind":"swap","segment":3},"Pointer over the central card resolves the swap destination before release")
	await capture("chain-redesign-00-swap-preview")
	await release_at(swap_at)
	await settle()
	check(first.segment==3 and third.segment==1,"Central card drop swaps exactly two mounted segments")
	check(ui.landing_segment==3 and ui.landing_left>0,"Successful drop starts a landing confirmation pulse")
	await capture("chain-redesign-01-assembly")
	var count=game.player.pending.size()
	var destination=ui.insert_targets[2].get_global_rect().get_center()
	await start_drag(ui.inventory[0].get_global_rect().get_center(),destination)
	check(root.gui_is_dragging() and ui.can_drop(ui.hovered_target,ui.active_drag_data),"Inventory drag highlights an available insertion rail")
	await capture("chain-redesign-02-insert-preview")
	var cancel=InputEventKey.new();cancel.keycode=KEY_ESCAPE;cancel.physical_keycode=KEY_ESCAPE;cancel.pressed=true
	Input.parse_input_event(cancel);await process_frame
	await release_at(destination)
	check(game.screen=="build" and game.player.pending.size()==count and game.player.segment_count()==4,"Escape cancels a drag without closing assembly or consuming inventory")
	await drag_at(ui.inventory[0].get_global_rect().get_center(),Vector2(1020,725))
	check(game.player.pending.size()==count,"Invalid drop keeps the pending element")
	await drag_at(ui.segment_buttons[1].get_global_rect().get_center(),ui.segment_buttons[2].get_global_rect().get_center(),false)
	check(game.player.segment_count()==4,"Swapping preserves the body count")
	while game.player.segment_count()<60:game.player.append_segment(game.db.named("Core_Gun_Gatling").id)
	ui.rebuild();await settle()
	rail=ui.chain_scroll;rail.scroll_horizontal=1600;await settle()
	var saved_scroll=rail.scroll_horizontal
	await click_at(ui.inventory[0].get_global_rect().get_center())
	check(ui.chain_scroll==rail and rail.scroll_horizontal==saved_scroll,"Inventory selection preserves long-chain scroll position")
	check(ui.segment_buttons.size()==60 and ui.insert_targets.size()==61,"All 60 segments remain accessible on the horizontal rail")
	check(not ui.can_drop({"kind":"gap","before":61},ui.selected_data),"Full body refuses insertion without consuming the pending reward")
	ui.cancel_selection();check(ui.chain_scroll==rail and rail.scroll_horizontal==saved_scroll,"Cancelling selection preserves rail position")
	rail.scroll_horizontal=0;await settle()
	await start_drag(ui.segment_buttons[1].get_global_rect().get_center(),Vector2(1346,350))
	var initial=rail.scroll_horizontal
	for i in range(25):ui._process(1.0/60);await process_frame
	check(rail.scroll_horizontal>initial+100,"Dragging near the rail edge smoothly scrolls the long body")
	await release_at(Vector2(1020,725))
	await capture("chain-redesign-03-long-body")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.process_mode=Node.PROCESS_MODE_DISABLED
	for i in range(12):OS.delay_msec(10);await process_frame
	game.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"captures":captures,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/chain-ui-redesign-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
