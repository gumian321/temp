extends "res://tests/test_centipede_scene.gd"
func settle():
	for i in range(4):await process_frame
func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
	game.set_process(false);game.test_mode=true;game.save.state.settings.skip_boss=true;game.save.select_character("centipede");game.start_run();game.set_process(false)
	var id=game.db.named("Core_Gun_Gatling").id
	for i in range(8):game.player.append_segment(id)
	game.player.pending=[id,id]
	game.show_build_ui();await settle()
	var ui=game.build_ui
	check(ui.body_canvas.hotspots.size()==17,"Mounted parts and growth points exist directly on character canvas")
	check(ui.inventory[0].get_theme_stylebox("normal") is StyleBoxEmpty,"Inventory is bare icons without a card frame")
	var canvas=ui.body_canvas
	var anchor=Vector2(370,220)
	var world=canvas.view_to_world(anchor)
	canvas.zoom_at(1.5,anchor)
	check(canvas.world_to_view(world).distance_to(anchor)<0.01,"Cursor-anchored zoom preserves exact body screen position")
	canvas.pan+=Vector2(43,-17);canvas.layout_hotspots()
	var first=ui.segment_buttons[1]
	check((first.position+first.size/2).distance_to(canvas.world_to_view(first.world))<0.01,"Panned native drag hotspot aligns with actual mounted segment")
	canvas.fit();await settle()
	await drag_at(ui.inventory[0].get_global_rect().get_center(),ui.insert_targets[3].get_global_rect().get_center())
	await settle()
	check(game.player.segment_count()==9 and game.player.pending.size()==1,"Native icon drops into an actual inter-body socket and grows a segment")
	await drag_at(ui.inventory[0].get_global_rect().get_center(),Vector2(20,200))
	check(game.player.pending.size()==1,"Dropping outside the character preserves the inventory")
	await capture("direct-body-centipede")
	while game.player.segment_count()<60:game.player.append_segment(id)
	ui.rebuild();await settle();ui.body_canvas.fit();await settle()
	check(ui.segment_buttons.size()==60,"Sixty mounted body modules remain directly selectable")
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution;await settle()
		var all_visible=true
		for control in ui.body_canvas.hotspots:
			if not Rect2(Vector2.ZERO,ui.body_canvas.size).encloses(control.get_rect()):all_visible=false
		check(all_visible,"Fit keeps every actual body socket inside canvas at "+str(resolution))
		check(not ui.body_canvas.get_rect().intersects(ui.inventory_scroll.get_rect()),"Character canvas and bottom icon tray never overlap at "+str(resolution))
		var moving=game.player.parts[game.player.part_at(1)]
		var before_pending=game.player.pending.size()
		await drag_at(root.get_final_transform()*ui.segment_buttons[1].get_global_rect().get_center(),root.get_final_transform()*ui.segment_buttons[3].get_global_rect().get_center());await settle()
		check(moving.segment==3,"Native body-space swap maps correctly at "+str(resolution))
		await drag_at(root.get_final_transform()*ui.inventory[0].get_global_rect().get_center(),root.get_final_transform()*ui.insert_targets[61].get_global_rect().get_center());await settle()
		check(game.player.pending.size()==before_pending and game.player.segment_count()==60,"Native full-body drop cancels without inventory loss at "+str(resolution))
		await capture("direct-body-full-"+str(resolution.x))
	var pending=game.player.pending.size()
	ui.drop({"kind":"gap","before":61},{"kind":"inventory","index":0,"id":id})
	check(game.player.pending.size()==pending and game.player.segment_count()==60,"Full sixty-body invalid insertion loses nothing")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.process_mode=Node.PROCESS_MODE_DISABLED;game.queue_free();await settle()
	var report={"checks":checks,"captures":captures,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/direct-body-assembly-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
