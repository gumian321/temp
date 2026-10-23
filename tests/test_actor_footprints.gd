extends SceneTree
func _initialize():call_deferred("execute")
func execute():
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.test_mode=true;game.save.fresh();game.start_run();game.set_process(false)
	var actors=game.combat.enemies.map(func(e):return {"kind":e.kind,"radius":e.radius,"ground_radius":e.get("ground_radius",e.radius),"parent":e.get("parent",0),"orbit_speed":e.get("orbit_speed",0),"offset":e.get("orbit_offset",Vector2.ZERO),"position":e.position})
	FileAccess.open("res://artifacts/actor-footprints.json",FileAccess.WRITE).store_string(JSON.stringify(actors,"\t"))
	print(JSON.stringify(actors))
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await process_frame;await process_frame;quit()
