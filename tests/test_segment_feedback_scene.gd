extends "res://tests/test_centipede_scene.gd"
## Production renderer fixture: impact, fragmentation, fading and complete cleanup.
func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.test_mode=false;game.save.state.settings.skip_boss=true
	game.start_run();await process_frame
	game.run.timers={"swarm":999.0,"wave":999.0,"patrol":999.0}
	game.combat.enemies.clear()
	for name in ["Core_Gun_Gatling","Core_Gun_Cannon","Core_Gun_Shotgun","Core_Gun_Tesla"]:game.player.append_segment(game.db.named(name).id)
	game.player.refresh_positions();game.zoom=1.7;game.camera=game.player.head-Vector2(105,0)
	await capture("segment-feedback-00-intact")
	game.combat.hurt_player(game.player.part_at(2),5,5)
	await capture("segment-feedback-01-hit")
	var index=game.player.part_at(2)
	game.combat.hurt_player(index,100000,100000)
	game.combat.step(0.01,game.player.head+Vector2.RIGHT*500,false)
	check(game.player.segment_count()==3,"The production scene removes one destroyed body segment")
	await capture("segment-feedback-02-break")
	for remaining in [0.72,0.45,0.16]:
		for effect in game.combat.effects:
			if effect.kind=="segment_break":effect.life=remaining
		await capture("segment-feedback-life-%02d"%roundi(remaining*100))
	game.combat.step(1.1,game.player.head+Vector2.RIGHT*500,false)
	check(game.combat.effects.all(func(e):return e.kind!="segment_break"),"The production scene removes expired debris")
	await capture("segment-feedback-03-recovered")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.process_mode=Node.PROCESS_MODE_DISABLED
	for i in range(12):OS.delay_msec(10);await process_frame
	game.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"captures":captures,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/segment-feedback-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
