extends SceneTree
const Profile=preload("res://tests/test_startup_combat_profile.gd")
var rows:Array=[]
func _initialize():call_deferred("execute")
func stats(values:Array)->Dictionary:
	if values.is_empty():return {}
	values.sort();var total=0.0
	for value in values:total+=value
	return {"mean":total/values.size(),"median":values[values.size()/2],"p95":values[mini(values.size()-1,int(values.size()*.95))],"max":values[-1]}
func execute():
	root.size=Vector2i(1440,900);set_meta("performance_fixture",true)
	var game=Profile.ProfileGame.new();game.weapon_fx=Profile.ProfileFX.new();root.add_child(game);await process_frame
	game.set_process(false);game.test_mode=false;game.save.fresh()
	for mission in game.db.kind("Mission"):
		for component in game.db.prefabs[mission.MissionsObjectiveList[0].objectivePrefab].components:
			if component.get("class")=="GAModeManager":game.selected_mission=mission
	game.begin_run()
	while game.deployment_active:await process_frame
	game.set_process(false);game.combat.profile_enabled=true
	game.combat.rng.seed=20261022;game.run.rng.seed=20261022;game.run.encounters.rng.seed=20261022
	for name in ["Core_Gun_Tesla","Core_Gun_EMP","Core_Repair","Core_Shield"]:game.player.append_segment(game.db.named(name).id)
	game.player.motion.reset();game.player.refresh_positions()
	for part in game.player.parts:part.hp=100000;part.max_hp=100000
	for enemy in game.run.director.living_objectives():enemy.hp=100000;enemy.max_hp=100000
	game.reward_snoozed=true;game.reward_snooze_count=2147483647
	var world=game.player.terrain;var director=game.run.director
	if OS.get_environment("RBPEW_ESCORT_NEAR")=="1":
		var near_point=world.safe_position(Vector2(240,0),game.player.collision_radius(0))
		var offset=near_point-game.player.head
		game.player.head=near_point
		for i in game.player.history.size():game.player.history[i]+=offset
		game.player.motion.reset();game.player.refresh_positions();game.camera=game.player.head
		if director.cave_escort!=null:
			director.cave_escort.setup(world,game.player,director.living_objectives(),director.fleet_data,director.fleet_goal)
			director.fleet_position=director.living_objectives()[0].position
	var initial={"player":game.player.head,"fleet":director.fleet_position,"goal":director.fleet_goal,"radius":director.fleet_radius,"count":director.initial_objectives,"follow_range":director.fleet_data.disFromPlayerToMove*48,"geometry":world.geometry.size()}
	print("ESCORT_INITIAL ",JSON.stringify(initial))
	var began=Time.get_ticks_usec();var frame=0
	var drive=OS.get_environment("RBPEW_ESCORT_DRIVE")=="1"
	var held="";var travel=0.0;var previous_fleet:Vector2=director.fleet_position
	var states:Dictionary={}
	var duration=OS.get_environment("RBPEW_ESCORT_SECONDS").to_float()
	if duration<=0:duration=15
	while Time.get_ticks_usec()-began<duration*1000000:
		if drive:
			var phase=float(Time.get_ticks_usec()-began)/1000000
			var wanted="move_down" if phase>=12 and phase<20 else "move_right"
			var separation=game.player.head.distance_to(director.fleet_position)
			if separation>350 or (held.is_empty() and separation>180):wanted=""
			if wanted!=held:
				if not held.is_empty():Input.action_release(held)
				if not wanted.is_empty():Input.action_press(wanted)
				held=wanted
		game.performance_samples.clear();game.combat.phase_times.clear()
		game.reward_snoozed=true;game.reward_snooze_count=2147483647
		var before=Time.get_ticks_usec();game._process(game.get_process_delta_time())
		var cpu=float(Time.get_ticks_usec()-before)/1000
		await process_frame
		if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
		travel+=previous_fleet.distance_to(director.fleet_position);previous_fleet=director.fleet_position
		var escort_state=director.cave_escort.status if director.cave_escort!=null else "legacy"
		states[escort_state]=int(states.get(escort_state,0))+1
		rows.append({"frame":frame,"elapsed":game.run.elapsed,"frame_ms":float(Time.get_ticks_usec()-before)/1000,"cpu_ms":cpu,"draw_ms":float(game.draw_us)/1000,
			"phases":game.performance_samples.duplicate(true),"combat_phases":game.combat.phase_times.duplicate(),"actors":game.combat.enemies.size(),"bullets":game.combat.bullets.size(),
			"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"fleet":director.fleet_position,"player":game.player.head,"geometry":world.geometry.size(),"nav_us":world.nav_prepare_us})
		frame+=1
	if not held.is_empty():Input.action_release(held)
	var tag=OS.get_environment("RBPEW_ESCORT_TAG").validate_filename()
	if tag.is_empty():tag="latest"
	var captures=["res://artifacts/escort-profile-"+tag+".png"]
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(captures[0])
	var result={"scope":"Actual native main scene, Escort normal difficulty, screenshot-derived four modules, real engine delta. Isolated profile, durable inspection actors; not the user's exact upgrade/RNG history.","initial":initial,"rows":rows,"captures":captures,"passed":game.screen=="game" and rows.size()>10,"final_fleet":director.fleet_position,"final_geometry":world.geometry.size()}
	result.drive=drive;result.convoy_travel=travel;result.escort_states=states;result.mined_cells=world.removed_count
	if drive:result.passed=result.passed and travel>160 and director.living_objectives().all(func(e):return not world.blocked(e.position,e.radius))
	for key in ["frame_ms","cpu_ms","draw_ms","actors","bullets","draw_calls","nav_us"]:result[key]=stats(rows.map(func(row):return row[key]))
	var phases={}
	for row in rows:
		for key in row.phases:
			if not phases.has(key):phases[key]=[]
			phases[key].append(float(row.phases[key].microseconds)/1000)
	result.phases={}
	for key in phases:result.phases[key]=stats(phases[key])
	FileAccess.open("res://artifacts/escort-profile-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("ESCORT_RESULT ",JSON.stringify({"initial":initial,"frame_ms":result.frame_ms,"cpu_ms":result.cpu_ms,"draw_ms":result.draw_ms,"phases":result.phases,"final_fleet":result.final_fleet}))
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await process_frame;await process_frame
	quit(0 if result.passed else 1)
