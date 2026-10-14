extends "res://tests/test_centipede_scene.gd"
func settle():
	for i in range(4):await process_frame
func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
	game.set_process(false);game.test_mode=true;game.save.state.settings.skip_boss=true
	game.save.state.roster_unlocked=["centipede","spider","beetle"]
	game.save.select_character("spider");game.start_run();game.set_process(false)
	var id=game.db.named("Core_Gun_Gatling").id
	game.player.pending=[id,id,id,id,id]
	var live_rig_before=game.player.spider_rig.legs.duplicate(true)
	game.show_build_ui();await settle()
	check(game.player.spider_rig.legs==live_rig_before,"Opening assembly preview never mutates live planted feet")
	var ui=game.build_ui
	check(ui.insert_targets.size()==8 and ui.segment_buttons.is_empty(),"Empty spider exposes one growth target on each of eight legs")
	var data={"kind":"inventory","index":0,"id":id}
	check(not ui.can_drop({"kind":"mount","before":17},data),"Cannot skip a leg depth")
	ui.drop({"kind":"mount","before":17},data)
	check(game.player.pending.size()==5,"Invalid skipped depth preserves inventory")
	for depth in range(4):
		var mount=game.player.spider_mount(0,depth)
		await drag_at(ui.inventory[0].get_global_rect().get_center(),ui.insert_targets[mount].get_global_rect().get_center())
		await settle()
	check(game.build_ui.spider_preview.spider_rig!=game.player.spider_rig and game.build_ui.spider_preview.spider_leg_count(0)==4,"Preview owns an isolated rig with current assembly counts")
	check(game.player.spider_leg_count(0)==4 and game.player.pending.size()==1,"Native inventory drags grow one leg to four ordered modules")
	check(not ui.insert_targets.has(33) and ui.insert_targets.size()==7,"Full leg has no fifth growth target")
	ui.drop({"kind":"mount","before":1},data)
	check(game.player.pending.size()==1 and game.player.spider_leg_count(0)==4,"Inventory cannot destroy an occupied module")
	check(not ui.can_drop({"kind":"mount","before":33},data),"Mount past total capacity is rejected")
	var moving=game.player.parts[game.player.part_at(9)]
	await drag_at(ui.segment_buttons[9].get_global_rect().get_center(),ui.insert_targets[2].get_global_rect().get_center())
	await settle()
	check(game.player.spider_leg_count(0)==3 and game.player.spider_leg_count(1)==1 and moving.segment==2,"Native cross-leg drag shortens source and lengthens destination")
	var other=game.player.parts[game.player.part_at(1)]
	await drag_at(ui.segment_buttons[2].get_global_rect().get_center(),ui.segment_buttons[1].get_global_rect().get_center())
	await settle()
	check(moving.segment==1 and other.segment==2,"Occupied native drop swaps two modules without loss")
	await capture("spider-assembly-01-leg-layout")
	while game.player.parts.size()-1<32:game.player.append_segment(id)
	ui.rebuild();await settle()
	check(ui.segment_buttons.size()==32 and ui.insert_targets.is_empty(),"Full spider displays all 32 modules and no growth targets")
	ui.drop({"kind":"mount","before":32},data)
	check(game.player.pending.size()==1 and game.player.parts.size()==33,"Full spider invalid drop preserves pending and installed modules")
	await capture("spider-assembly-02-full-layout")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.process_mode=Node.PROCESS_MODE_DISABLED
	game.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"captures":captures,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/spider-assembly-ui-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
