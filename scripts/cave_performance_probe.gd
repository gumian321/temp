extends "res://scripts/windows_review_probe.gd"
## Opt-in isolated, native frame timing for the shipped runtime. One rendered
## frame per production tick; fixed simulation input never substitutes for FPS.
func stats(values:Array)->Dictionary:
	if values.is_empty():return {}
	values.sort()
	var total=0.0;var within=0
	for value in values:
		total+=value
		if value<=1000.0/60:within+=1
	return {"mean":total/values.size(),"median":values[values.size()/2],"p95":values[mini(values.size()-1,floori(values.size()*.95))],"p99":values[mini(values.size()-1,floori(values.size()*.99))],"max":values.back(),"within_60fps_percent":float(within)*100/values.size()}

func execute():
	root.size=Vector2i(1440,900)
	tree.set_meta("performance_fixture",true)
	game.set_process(false);game.test_mode=false;game.save.fresh()
	var actors=80 if OS.get_environment("RBPEW_MINING_ACTORS").is_empty() else clampi(OS.get_environment("RBPEW_MINING_ACTORS").to_int(),0,120)
	var count=240 if OS.get_environment("RBPEW_MINING_FRAMES").is_empty() else clampi(OS.get_environment("RBPEW_MINING_FRAMES").to_int(),240,18000)
	var mixed=OS.get_environment("RBPEW_MINING_LOADOUT")=="mixed"
	var native_actors=OS.get_environment("RBPEW_MINING_NATIVE_ACTORS")=="1"
	var native_pacing=OS.get_environment("RBPEW_MINING_NATIVE_PACING")=="1"
	var duration=clampf(OS.get_environment("RBPEW_MINING_SECONDS").to_float(),0,120)
	var mission_name=OS.get_environment("RBPEW_MINING_MISSION")
	if mission_name.is_empty():mission_name="Survival Mission"
	var route=OS.get_environment("RBPEW_MINING_ROUTE")
	game.selected_mission=game.db.named(mission_name);game.begin_run()
	while game.deployment_active:await process_frame
	game.set_process(false)
	var world=game.player.terrain
	var battle_seed=20261021 if OS.get_environment("RBPEW_MINING_SEED").is_empty() else OS.get_environment("RBPEW_MINING_SEED").to_int()
	game.combat.rng.seed=battle_seed;game.run.rng.seed=battle_seed;game.run.encounters.rng.seed=battle_seed
	var legacy_cpu=OS.get_environment("RBPEW_MINING_LEGACY_CPU")=="1"
	preload("res://scripts/soft_insect.gd").use_constraint_certificate=not legacy_cpu
	world.move_certificate_step=32.0 if legacy_cpu else 16.0
	# Loading already exercised the default certificate grid. A different
	# diagnostic cell size must never reinterpret those old cache keys.
	world.free_regions.clear();world.blocked_free_regions.clear();world.free_radii.clear()
	world.use_sweep_clipping=not legacy_cpu
	world.use_clearance_cache=not legacy_cpu
	game.run.map_director.use_remote_orbits=not legacy_cpu and OS.get_environment("RBPEW_MINING_FULL_ORBITS")!="1"
	if not native_actors:
		game.combat.enemies.clear();game.combat.drones.clear();game.combat.enemy_drones.clear();game.combat.loot.clear();game.combat.effects.clear()
		game.run.timers={"swarm":9999.0,"wave":9999.0,"patrol":9999.0};game.run.encounters.enabled=false
	var entry=world.wall_hit(Vector2.ZERO,Vector2(1000,0),30)
	game.player.head=Vector2(entry.position)+Vector2(entry.normal)*.35;game.player.facing=Vector2.RIGHT
	for i in game.player.history.size():game.player.history[i]=game.player.head-Vector2(i*4,0)
	if mixed:preload("res://scripts/performance_loadouts.gd").install(game.player,game.db)
	else:
		for i in 6:game.player.append_segment(game.db.named("Core_Gun_Gatling").id)
	game.player.motion.reset();game.player.refresh_positions()
	for part in game.player.parts:part.hp=100000;part.max_hp=100000
	for i in (0 if native_actors else actors):
		var e=game.combat.spawn(game.db.pool["250"],Vector2(630+(i%10)*15,(i/10)*17-60))
		e.guns=[];e.components=[];e.warp=0;e.stop_distance=0;e.hp=100000;e.max_hp=100000
	game.tutorials.movement_shown=true;game.tutorials.radar_shown=true;game.tutorials.fuel_shown=true
	game.show_game()
	# Use the normal reward-snooze state before each tick. Clearing a queue
	# afterward cannot undo a reward screen opened during that same tick.
	game.reward_snoozed=true;game.reward_snooze_count=2147483647
	var initial_actor_count=game.combat.enemies.size()
	game.combat.profile_enabled=true
	if OS.get_environment("RBPEW_MINING_LEGACY_EGGS")=="1":game.weapon_fx.use_mine_batches=false
	for i in 12:
		game._process(1.0/60);game.run.rewards.queue.clear();game.run.packs=0
		await process_frame;await RenderingServer.frame_post_draw
	var rows:Array=[];var frame_times:Array=[];var cpu_times:Array=[];var bites:Array=[];var drops:Array=[]
	Input.action_press("move_right")
	var turned=false;var held="move_right";var frame=0;var checkpoints:Array=[]
	var initial_elapsed=game.run.elapsed
	while frame<count and (duration<=0 or game.run.elapsed-initial_elapsed<duration):
		if game.screen=="pause":game.show_game()
		game.camera_focus.clear()
		var old_elapsed=game.run.elapsed
		if route=="excavate" and not turned and frame>=150 and game.player.head.x>412:
			Input.action_release("move_right");Input.action_press("move_up");turned=true
		if route=="roam":
			var next=["move_right","move_up","move_left","move_down"][floori((game.run.elapsed-initial_elapsed)/15.0)%4]
			if next!=held:Input.action_release(held);Input.action_press(next);held=next
		var old_bites=world.bite_serial;var old_ore=world.ore_total
		game.performance_samples.clear()
		game.combat.phase_times.clear()
		game.reward_snoozed=true;game.reward_snooze_count=2147483647
		var began=Time.get_ticks_usec()
		game._process(game.get_process_delta_time() if native_pacing else 1.0/60)
		var cpu=float(Time.get_ticks_usec()-began)/1000.0
		game.run.rewards.queue.clear();game.run.packs=0
		await process_frame;await RenderingServer.frame_post_draw
		var elapsed=float(Time.get_ticks_usec()-began)/1000.0
		var row={"frame":frame,"frame_ms":elapsed,"cpu_ms":cpu,"actors":game.combat.enemies.size(),"bite":world.bite_serial>old_bites,"ore":world.ore_total-old_ore,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"main_phases":game.performance_samples.duplicate(true)}
		row.head=[game.player.head.x,game.player.head.y]
		row.bullets=game.combat.bullets.size()
		row.living_modules=game.player.parts.filter(func(part):return part.hp>0).size()
		row.screen=game.screen;row.simulated=game.run.elapsed>old_elapsed;row.run_elapsed=game.run.elapsed
		row.mines=game.combat.special.mines.size();row.drones=game.combat.drones.size();row.loot=game.combat.loot.size();row.effects=game.combat.effects.size()
		row.combat_phases=game.combat.phase_times.duplicate()
		row.attack_commands=game.attack_shader_layer.stats().commands
		row.rig_builds=game.insect_layer.rig_builds;row.rig_reuses=game.insect_layer.rig_reuses
		row.flight_instances=game.attack_shader_layer.flight_batch.submitted
		row.orbit_moves=game.run.map_director.orbit_moves;row.remote_orbit_skips=game.run.map_director.remote_orbit_skips
		rows.append(row);frame_times.append(elapsed);cpu_times.append(cpu)
		if row.bite:bites.append(elapsed)
		if row.ore>0:drops.append(elapsed)
		if not row.simulated or row.screen!="game":
			check(false,"A timing sample left active combat; stop instead of measuring menu frames")
			break
		if native_pacing:
			for checkpoint in [10,40,80]:
				if game.run.elapsed-initial_elapsed>=checkpoint and checkpoint not in checkpoints:
					checkpoints.append(checkpoint)
					var path="user://mixed-%03d.png"%checkpoint
					root.get_texture().get_image().save_png(path);captures.append(ProjectSettings.globalize_path(path))
		frame+=1
	for action in ["move_right","move_up","move_left","move_down"]:Input.action_release(action)
	check(world.ore_total>0 and world.removed_count>0,"Measured production frames include actual excavation and mineral drops")
	if not native_actors:check(rows.all(func(row):return row.actors>=actors),"The live map and wave simulation retains at least the initial actor pressure")
	check(rows.all(func(row):return row.screen=="game" and row.simulated),"Every timed frame advances real combat; paused, reward and result screens never count as gameplay FPS")
	var expected_modules=12 if mixed else 7
	check(rows.all(func(row):return row.living_modules==expected_modules),"All configured modules remain alive and available throughout the measured battle")
	if route=="excavate":check(turned and world.removed_count>50,"Long excavation turns into natural rock and keeps mining beyond the starting deposit")
	var directory="user://cave-performance"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path=directory+"/fps.png";root.get_texture().get_image().save_png(path)
	var counter=game.performance_overlay
	var report={"passed":checks.all(func(c):return c.passed),"exported":OS.has_feature("template"),"checks":checks,"runtime":OS.get_executable_path(),"conditions":{"width":1440,"height":900,"initial_actors":actors,"measured_frames":count,"warmup_frames":12,"dt":1.0/60,"six_gatling_modules":true,"audio_and_effects":true,"invulnerable_fixture_actors":true,"native_map_spawns":true,"reward_interruptions_suppressed":true},"frame_ms":stats(frame_times),"cpu_ms":stats(cpu_times),"bite_frame_ms":stats(bites),"drop_frame_ms":stats(drops),"counter":{"fps":counter.current_fps,"average_ms":counter.average_ms,"peak_ms":counter.peak_ms,"text":counter.reading.text},"frames":rows,"mined_cells":world.removed_count,"ore_value":world.ore_total,"deployment":game.deployment_report,"captures":[ProjectSettings.globalize_path(path)]}
	var report_path=directory+"/report.json"
	report.conditions.measured_frames=rows.size();report.conditions.six_gatling_modules=not mixed
	report.conditions.loadout="screenshot-derived 11 mixed modules" if mixed else "six Gatlings"
	report.conditions.native_pacing=native_pacing;report.conditions.duration_seconds=game.run.elapsed-initial_elapsed
	if native_pacing:report.conditions.dt="actual engine process delta"
	report.conditions.initial_actors=initial_actor_count
	report.conditions.vsync_mode=DisplayServer.window_get_vsync_mode();report.conditions.refresh_rate=DisplayServer.screen_get_refresh_rate()
	report.conditions.native_actor_waves=native_actors;report.conditions.invulnerable_fixture_actors=not native_actors
	report.conditions.legacy_egg_rendering=not game.weapon_fx.use_mine_batches
	report.conditions.battle_seed=battle_seed;report.conditions.legacy_cpu=legacy_cpu
	report.conditions.remote_orbits=game.run.map_director.use_remote_orbits
	report.captures.append_array(captures)
	report.windows={}
	for range_seconds in [[0,10],[30,40],[70,80]]:
		var samples=rows.filter(func(row):return row.run_elapsed-initial_elapsed>=range_seconds[0] and row.run_elapsed-initial_elapsed<range_seconds[1])
		if samples.is_empty():continue
		report.windows[str(range_seconds[0])+"-"+str(range_seconds[1])]={"frames":samples.size(),"frame_ms":stats(samples.map(func(row):return row.frame_ms)),"cpu_ms":stats(samples.map(func(row):return row.cpu_ms)),"max_mines":samples.map(func(row):return row.mines).max(),"max_actors":samples.map(func(row):return row.actors).max(),"max_loot":samples.map(func(row):return row.loot).max()}
	report.conditions.mission=mission_name;report.conditions.route=route if not route.is_empty() else "straight"
	report.conditions.fixture_focus_pause_suppressed=true
	report.conditions.flight_batch=game.attack_shader_layer.use_flight_batch
	report.conditions.rig_pool=game.insect_layer.use_rig_pool
	report.conditions.spatial_query_cache=game.combat.spatial.use_query_cache
	report.conditions.upgrade_cache=game.player.use_upgrade_cache
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	if OS.has_feature("editor"):
		var tag=OS.get_environment("RBPEW_MINING_PERF_TAG")
		if tag.is_empty():tag="latest"
		FileAccess.open("res://artifacts/cave-native-performance-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify({"passed":report.passed,"exported":report.exported,"native_performance_report":ProjectSettings.globalize_path(report_path),"frame_ms":report.frame_ms,"cpu_ms":report.cpu_ms,"bite_frame_ms":report.bite_frame_ms,"drop_frame_ms":report.drop_frame_ms,"counter":report.counter,"captures":report.captures}))
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free()
	await process_frame;await process_frame
	quit(0 if report.passed else 1)
