extends SceneTree
## Natural survival simulation followed by a central-chamber CPU/native sample.
## Fixed-step preparation is excluded from all native frame measurements.
class ProfileBattle extends "res://scripts/combat.gd":
	var samples:Dictionary={}
	var measuring=false
	var legacy_uid=OS.get_environment("RBPEW_CENTRAL_LEGACY")=="1"
	func record(key:String,began:int):
		if measuring:samples[key]=int(samples.get(key,0))+Time.get_ticks_usec()-began
	func ground_direction(e:Dictionary,target:Vector2)->Vector2:
		if not measuring:return super.ground_direction(e,target)
		var began=Time.get_ticks_usec();var result=super.ground_direction(e,target)
		record("navigation/"+str(e.kind),began);return result
	func constrain_actor(e:Dictionary):
		if not measuring:super.constrain_actor(e);return
		var began=Time.get_ticks_usec();super.constrain_actor(e)
		record("collision/"+str(e.kind),began)
	func source_component(components:Array,type:String)->Dictionary:
		if not measuring:return super.source_component(components,type)
		var began=Time.get_ticks_usec();var result=super.source_component(components,type)
		record("components",began);return result
	func entity(uid:int)->Dictionary:
		var began=Time.get_ticks_usec();var result:Dictionary={}
		if legacy_uid and not spatial_active:
			for e in enemies:
				if e.uid==uid:result=e;break
		else:result=super.entity(uid)
		record("entity_lookup",began);return result
class ProfileGame extends "res://scripts/main.gd":
	func prepare_run_player():
		super.prepare_run_player()
		combat=ProfileBattle.new(db,player)
class ProfileWorld extends "res://tests/mixed_cave_timing_world.gd":
	var recording=false
	var moves:Array=[]
	func move(start:Vector2,desired:Vector2,radius:float)->Vector2:
		var result=super.move(start,desired,radius)
		if recording:moves.append([start,desired,radius,result])
		return result
func _initialize():call_deferred("execute")
func execute():
	root.size=Vector2i(1440,900);set_meta("performance_fixture",true)
	var game=ProfileGame.new();root.add_child(game);await process_frame
	game.set_process(false);game.test_mode=false;game.save.fresh()
	game.charcoal_terrain.world=ProfileWorld.new()
	game.selected_mission=game.db.named("Survival Mission");game.begin_run()
	while game.deployment_active:await process_frame
	game.set_process(false)
	if OS.get_environment("RBPEW_CENTRAL_LEGACY")=="1":
		game.player.terrain.use_sweep_neighborhoods=false;game.combat.use_incremental_refresh=false
	game.combat.rng.seed=20261022;game.run.rng.seed=20261022;game.run.encounters.rng.seed=20261022
	# Same module count as the report, representative attack/support modules.
	for name in ["Core_Gun_Tesla","Core_Gun_EMP","Core_Shield","Core_Repair","Core_Gun_Flame Thrower","Core_Drones_Attack","Core_Drones_Scrapper","Core_Gun_Cannon","Core_Gun_Rocket"]:
		var core:Dictionary=game.db.named(name)
		if core.is_empty():printerr("Missing fixture core: ",name);quit(1);return
		game.player.append_segment(core.id)
	game.player.motion.reset();game.player.refresh_positions()
	for part in game.player.parts:part.hp=100000;part.max_hp=100000
	game.reward_snoozed=true;game.reward_snooze_count=2147483647
	var world=game.player.terrain
	# Hold the central chamber while native waves and map orbits develop.
	for tick in 7200:
		game.combat.step(1.0/60,game.player.head+Vector2.RIGHT*500,false)
		game.run.step(1.0/60)
		game.run.rewards.queue.clear();game.run.packs=0;game.combat.audio_events.clear();game.player.feedback_events.clear()
	game.performance_profile_enabled=true;game.combat.profile_enabled=true;game.combat.measuring=true
	game.tutorials.movement_shown=true;game.tutorials.radar_shown=true;game.tutorials.fuel_shown=true
	var native=DisplayServer.get_name()!="headless"
	if native:
		await process_frame;await RenderingServer.frame_post_draw
		for frame in 12:
			# Discard the wall-clock stall from the synchronous preparation loop.
			# These 12 fixed warmup frames are never native timing samples.
			game._process(1.0/60)
			await process_frame;await RenderingServer.frame_post_draw
	world.recording=OS.get_environment("RBPEW_RECORD_MOVES")=="1"
	var initial_elapsed=float(game.run.elapsed)
	var rows:Array=[]
	for frame in 600:
		game.performance_samples.clear();game.combat.phase_times.clear();game.combat.samples.clear();world.samples.clear()
		var began=Time.get_ticks_usec()
		game._process(game.get_process_delta_time() if native else 1.0/60)
		var cpu=Time.get_ticks_usec()-began
		if native:await process_frame;await RenderingServer.frame_post_draw
		rows.append({"cpu_ms":cpu/1000.0,"frame_ms":(Time.get_ticks_usec()-began)/1000.0,"phases":game.performance_samples.duplicate(true),"combat":game.combat.phase_times.duplicate(),"details":game.combat.samples.duplicate(),"world":world.samples.duplicate(true),"actors":game.combat.enemies.size(),"bullets":game.combat.bullets.size(),"drones":game.combat.drones.size()+game.combat.enemy_drones.size(),"elapsed":game.run.elapsed,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"living_modules":game.player.parts.filter(func(p):return p.hp>0).size(),"screen":game.screen,"sweep_neighborhoods":world.sweep_neighborhood_order.size()})
		game.run.rewards.queue.clear();game.run.packs=0
	var tag=OS.get_environment("RBPEW_CENTRAL_TAG").validate_filename()
	if tag.is_empty():tag="latest"
	var report={"scope":"120 simulated seconds of natural survival waves in the central chamber, then 600 active main-scene ticks. Representative nine modules, not the user's exact save. Raised player HP; isolated progress. CPU-only unless native_render is true. Native window is offscreen; no editor remote debugger attached.","native_render":native,"rows":rows,"initial_elapsed":initial_elapsed,"legacy":OS.get_environment("RBPEW_CENTRAL_LEGACY")=="1","passed":initial_elapsed>=119.99 and initial_elapsed<121 and rows.all(func(row):return row.screen=="game" and row.living_modules==10) and game.run.elapsed>initial_elapsed}
	FileAccess.open("res://artifacts/central-survival-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	if world.recording:FileAccess.open("res://artifacts/central-movement-queries.bin",FileAccess.WRITE).store_var(world.moves)
	if native:root.get_texture().get_image().save_png("res://artifacts/central-survival-"+tag+".png")
	print("CENTRAL_PROFILE ",tag," actors=",game.combat.enemies.size()," passed=",report.passed)
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await process_frame;await process_frame
	quit(0 if report.passed else 1)
