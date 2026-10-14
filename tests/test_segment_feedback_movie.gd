extends "res://tests/test_centipede_scene.gd"
## Optional 4-second, 30 FPS production animation capture; not a regression default.
func execute():
	if DisplayServer.get_name()=="headless":
		printerr("ERROR: Animation capture requires --render")
		quit(1);return
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.test_mode=false;game.save.state.settings.skip_boss=true
	game.start_run();await process_frame
	game.set_process(false)
	game.run.timers={"swarm":999.0,"wave":999.0,"patrol":999.0}
	game.combat.enemies.clear()
	for name in ["Core_Gun_Gatling","Core_Gun_Cannon","Core_Gun_Shotgun","Core_Gun_Tesla"]:game.player.append_segment(game.db.named(name).id)
	game.player.refresh_positions();game.zoom=1.7
	var focus:Vector2=game.player.head-Vector2(105,0)
	var directory="res://artifacts/segment-feedback-movie"
	DirAccess.make_dir_recursive_absolute(directory)
	for frame in range(120):
		if frame==36:game.combat.hurt_player(game.player.part_at(2),5,5)
		if frame==54:game.combat.hurt_player(game.player.part_at(2),100000,100000)
		# Advance the real production loop: VFX lifetimes, motion, HUD and audio.
		game._process(1.0/30.0)
		game.camera=focus;game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var image=root.get_texture().get_image()
		if image==null or image.is_empty() or image.save_png(directory+"/frame-%04d.png"%frame)!=OK:
			printerr("ERROR: Could not capture animation frame ",frame);quit(1);return
	check(game.player.segment_count()==3,"The animation ends with three surviving body segments")
	check(game.combat.effects.all(func(e):return e.kind!="segment_break"),"The real-time animation naturally expires its debris")
	var report={"frames":120,"fps":30,"seconds":4,"hit_frame":36,"destruction_frame":54,"checks":checks,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/segment-feedback-movie-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.process_mode=Node.PROCESS_MODE_DISABLED
	for i in range(12):OS.delay_msec(10);await process_frame
	game.queue_free();await process_frame;await process_frame
	print(JSON.stringify(report));quit(0 if report.passed else 1)
