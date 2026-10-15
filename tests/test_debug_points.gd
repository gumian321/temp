extends "res://tests/test_centipede_scene.gd"

func settle():
	for i in range(4):await process_frame

func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
	game.set_process(false);game.save.path="user://debug-points.json";game.save.fresh()
	game.show_menu();await settle()
	var before=game.save.state.duplicate(true)
	check(game.debug_points_button.is_visible_in_tree() and game.debug_points_button.text.contains("1000"),"Home exposes a clearly labeled debug grant button")
	await click_at(game.debug_points_button.get_global_rect().get_center());await settle()
	check(game.save.state.meta==int(before.meta)+1000 and game.home_points_label.text==str(game.save.state.meta),"Click grants exactly 1000 points and refreshes the visible balance immediately")
	var expected=before.duplicate(true);expected.meta+=1000
	check(game.save.state==expected,"Grant preserves every other profile field and unlock")
	var loaded=load("res://scripts/save_store.gd").new(game.db,game.save.path)
	check(loaded.state.meta==game.save.state.meta,"Granted currency persists through a fresh save-store load")
	await click_at(game.debug_points_button.get_global_rect().get_center());await settle()
	check(game.save.state.meta==int(before.meta)+2000,"Repeated clicks add points without a hidden limit")
	game.show_lab();await settle()
	var balance=int(game.save.state.meta);game.debug_add_evolution_points()
	check(game.save.state.meta==balance,"A stale callback outside the home screen cannot grant currency")
	game.show_menu();await settle()
	check(game.home_points_label.text==str(balance),"Returning home retains the updated balance")
	# A failed write restores the prior in-memory amount instead of claiming a grant.
	var valid_path=game.save.path;game.save.path="user://missing-directory/points.json"
	game.debug_add_evolution_points()
	check(game.save.state.meta==balance and game.home_points_label.text==str(balance),"Failed save cannot leave an unsaved currency grant")
	game.save.path=valid_path
	game.show_menu();await settle()
	for resolution in [Vector2i(1440,900),Vector2i(1280,720)]:
		root.size=resolution;await settle()
		var button=game.debug_points_button
		var physical_rect=root.get_final_transform()*button.get_global_rect()
		check(Rect2(Vector2.ZERO,Vector2(resolution)).encloses(physical_rect),"Grant button stays visible at "+str(resolution))
		await capture("debug-points-home-"+str(resolution.x))
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"captures":captures}
	FileAccess.open("res://artifacts/debug-points-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
