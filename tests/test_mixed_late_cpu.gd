extends SceneTree
## Deterministic 90 simulated seconds, natural waves and the screenshot loadout.
## CPU diagnostic only: no rendering, no native FPS claim.
func _initialize():call_deferred("execute")
func execute():
	set_meta("performance_fixture",true)
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.test_mode=false;game.save.fresh()
	game.charcoal_terrain.world=preload("res://tests/mixed_cave_timing_world.gd").new()
	game.selected_mission=game.db.named("Survival Mission");game.begin_run()
	while game.deployment_active:await process_frame
	game.set_process(false)
	var world=game.player.terrain
	game.combat.rng.seed=20261021;game.run.rng.seed=20261021;game.run.encounters.rng.seed=20261021
	var entry=world.wall_hit(Vector2.ZERO,Vector2(1000,0),30)
	game.player.head=Vector2(entry.position)+Vector2(entry.normal)*.35;game.player.facing=Vector2.RIGHT
	for i in game.player.history.size():game.player.history[i]=game.player.head-Vector2(i*4,0)
	preload("res://scripts/performance_loadouts.gd").install(game.player,game.db)
	for part in game.player.parts:part.hp=100000;part.max_hp=100000
	game.player.motion.reset();game.player.refresh_positions()
	game.combat.profile_enabled=true
	var rows=[]
	for tick in 5400:
		world.samples.clear();game.combat.phase_times.clear()
		var began=Time.get_ticks_usec()
		var movement=[Vector2.RIGHT,Vector2.UP,Vector2.LEFT,Vector2.DOWN][(tick/900)%4]
		game.player.step(1.0/60,movement,false)
		var body=float(Time.get_ticks_usec()-began)/1000.0
		game.combat.step(1.0/60,game.player.head+Vector2.RIGHT*500,false)
		var combat=float(Time.get_ticks_usec()-began)/1000.0-body
		var before_mission=world.samples.duplicate(true)
		world.samples.clear();game.run.step(1.0/60)
		var total=float(Time.get_ticks_usec()-began)/1000.0
		rows.append({"frame":tick,"body_ms":body,"combat_ms":combat,"mission_ms":total-body-combat,"cpu_ms":total,"combat_phases":game.combat.phase_times.duplicate(),"world_before_mission":before_mission,"world_mission":world.samples.duplicate(true),"actors":game.combat.enemies.size(),"jobs":game.run.map_director.actor_jobs.size(),"local_jobs":game.run.local_spawn_jobs.size()})
		game.run.rewards.queue.clear();game.run.packs=0;game.combat.audio_events.clear();game.player.feedback_events.clear()
	var tag=OS.get_environment("RBPEW_LATE_TAG")
	if tag.is_empty():tag="latest"
	var result={"scope":"CPU only; inclusive timing overlaps, no FPS claim. 5400 fixed 1/60 simulated ticks, natural actors, full mining, screenshot mixed loadout.","rows":rows,"final_actors":game.combat.enemies.map(func(e):return {"kind":e.kind,"radius":e.radius,"ground_radius":e.get("ground_radius",e.radius),"orbit_speed":e.get("orbit_speed",0),"position":e.position,"offset":e.get("orbit_offset",Vector2.ZERO)})}
	FileAccess.open("res://artifacts/mixed-late-cpu-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("MIXED_LATE_CPU completed ",rows.size()," active ticks; final actors ",game.combat.enemies.size())
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free()
	await process_frame;await process_frame;quit()
