extends Node
## Short fixed-input diagnostic replay. Never used by normal save loading or
## counted as the real-clock thirty-minute acceptance run.
const Snapshot=preload("res://scripts/battle_snapshot.gd")
var game
var folder=""
var snapshot:Dictionary={}
var restored=false
var frames=0
var warmup=60
var samples=180
var frame_us:Array=[]
var draw_call_samples:Array=[]
var last_start=0
var pending=false
var pending_elapsed=0.0
var sampled_game_seconds=0.0
var combat_sums:Dictionary={}
var main_sums:Dictionary={}
var direction=Vector2.RIGHT
var chooser
var last_ui=0
var source_fingerprint={}
var canonical_actors:Dictionary={}
var canonical_parts:Dictionary={}
var alias_checks={"controls":0,"drones":0,"effects":0}
var restore_checks:Dictionary={}
var terrain_kernels=false
var terrain_kernel_us:Dictionary={}
var terrain_kernel_calls:Dictionary={}
var render_timing=false
var render_timer_sums={"cpu":0.0,"gpu":0.0}
var render_timer_samples={"cpu":0,"gpu":0}
var render_auditing=false

func setup(owner_game):game=owner_game;call_deferred("start")
func start():
	folder=OS.get_environment("RBPEW_REPLAY_ROOT")
	var actual=OS.get_user_data_dir().replace("\\","/").to_lower()
	if folder.is_empty() or not actual.begins_with(folder.replace("\\","/").to_lower()+"/"):
		printerr("Replay refuses a non-isolated user profile");get_tree().quit(2);return
	var path=OS.get_environment("RBPEW_BATTLE_SNAPSHOT")
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null:printerr("Replay snapshot missing");get_tree().quit(2);return
	var value=file.get_var(false)
	if not value is Dictionary or value.get("format")!=2:printerr("Replay snapshot format invalid");get_tree().quit(2);return
	snapshot=value
	terrain_kernels=OS.get_environment("RBPEW_REPLAY_TERRAIN_KERNELS")=="1"
	render_timing=OS.get_environment("RBPEW_REPLAY_RENDER_TIMING")=="1" and RenderingServer.has_method("viewport_set_measure_render_time")
	if render_timing:RenderingServer.call("viewport_set_measure_render_time",game.get_viewport().get_viewport_rid(),true)
	warmup=maxi(1,int(OS.get_environment("RBPEW_REPLAY_WARMUP")))
	samples=maxi(1,int(OS.get_environment("RBPEW_REPLAY_SAMPLES")))
	get_tree().set_meta("performance_fixture",true)
	game.selected_mission=game.db.named("Endless Mission");game.difficulty=0
	chooser=preload("res://scripts/conservative_pilot.gd").new();chooser.game=game;chooser.folder=folder
	add_child(chooser)
	chooser.policy_rng.seed=20261026
	get_tree().process_frame.connect(tick)
	game.begin_run()

func apply_snapshot():
	game.runtime_log.finish_session("diagnostic_replay_restore")
	var experiment=str(OS.get_environment("RBPEW_REPLAY_WORLD_MODE"))
	var experimental_world=null
	if experiment in ["capacity","empty","segmented","native-sweep"]:
		# Explicit source-only research modes. Normal gameplay and exported
		# acceptance runs never request or load these excluded tool resources.
		var path={"capacity":"res://tools/deep_capacity_geometry_world.gd","empty":"res://tools/deep_empty_geometry_world.gd","segmented":"res://tools/deep_segmented_geometry_world.gd","native-sweep":"res://tools/native_sweep_world.gd"}[experiment]
		var script=load(path)
		if script==null:printerr("Replay world prototype unavailable");get_tree().quit(2);return
		experimental_world=script.new()
	elif terrain_kernels:experimental_world=preload("res://scripts/cave_kernel_profile.gd").new()
	if experimental_world!=null:
		game.charcoal_terrain.world=experimental_world
		game.player.terrain=game.charcoal_terrain.world;game.combat.terrain=game.charcoal_terrain.world
	var world=game.charcoal_terrain.world
	world.reset_cave(bool(snapshot.terrain.enabled),int(snapshot.terrain.seed_value))
	for key in snapshot.terrain:world.set(key,snapshot.terrain[key])
	if snapshot.has("navigation"):Snapshot.restore_navigation(world,snapshot.navigation)
	if snapshot.has("save_state"):game.save.state=snapshot.save_state.duplicate(true)
	var systems={"player":game.player,"combat":game.combat,"run":game.run,
		"map":game.run.map_director,"director":game.run.director,"rewards":game.run.rewards,
		"encounters":game.run.encounters,"abilities":game.combat.character_abilities,
		"special":game.combat.special,"mutations":game.combat.mutation_weapons,
		"controls":game.combat.insect_control_system,"momentum":game.combat.momentum,
		"achievements":game.run.achievements,"player_legs":game.player_legs}
	for key in ["spider_rig","coil_rig","flagella","fragment_recovery","motion"]:
		var child=game.player.get(key)
		if child!=null:systems["player_"+key]=child
	if game.run.rewards.get("pacing")!=null:systems["pacing"]=game.run.rewards.pacing
	for key in systems:
		if snapshot.states.get(key) is Dictionary:Snapshot.apply_state(systems[key],snapshot.states[key])
	for actor in game.combat.enemies:canonical_actors[int(actor.uid)]=actor
	for part in game.player.parts:
		if part.has("feedback_uid"):canonical_parts[int(part.feedback_uid)]=part
	for actor in game.combat.enemies:
		for key in actor:actor[key]=bind_value(actor[key])
	for key in systems:
		var data=snapshot.states.get(key)
		if not data is Dictionary:continue
		for field in data.get("values",{}):
			if field in ["enemies","parts","detached_fragments"]:continue
			var value=systems[key].get(field)
			if value is Array or value is Dictionary:systems[key].set(field,bind_value(value))
	for drone in game.combat.drones+game.combat.enemy_drones:
		if not drone.get("target") is Dictionary or drone.target.is_empty():continue
		if str(drone.get("mode","")) in ["pickup","carry"]:
			for loot in game.combat.loot:
				if int(loot.get("reserved_by",-1))==int(drone.uid):drone.target=loot;alias_checks.drones+=1;break
		else:
			drone.target=bind_value(drone.target);alias_checks.drones+=1
	for control in game.combat.insect_control_system.active:
		if control.get("target") is Dictionary and canonical_actors.has(int(control.target.get("uid",-1))):
			control.target=canonical_actors[int(control.target.uid)];alias_checks.controls+=1
	for effect in game.combat.effects:
		if effect.get("follow") is Dictionary and not effect.follow.is_empty():effect.follow=bind_value(effect.follow);alias_checks.effects+=1
	# Map jobs refer to the actual node dictionary, not a deserialized copy.
	for job in game.run.map_director.actor_jobs:
		if job.get("node") is Dictionary and game.run.map_director.nodes.has(job.node.key):job.node=game.run.map_director.nodes[job.node.key]
	game.combat.insect_controls=game.combat.insect_control_system.active
	game.combat.spatial_active=false;game.combat.refresh_spatial()
	restore_checks={"parts":game.player.parts.size()==snapshot.states.player["values"].parts.size(),
		"actors":game.combat.enemies.size()==snapshot.states.combat["values"].enemies.size(),
		"levels":game.player.levels==snapshot.states.player["values"].levels,
		"stats":game.player.stats==snapshot.states.player["values"].stats,
		"combat_rng":game.combat.rng.state==snapshot.states.combat["random"].rng.state,
		"run_rng":game.run.rng.state==snapshot.states.run["random"].rng.state}
	if not restore_checks.values().all(func(v):return v):printerr("Replay restore mismatch: ",restore_checks);get_tree().quit(2);return
	if snapshot.states.get("main") is Dictionary:Snapshot.apply_state(game,snapshot.states["main"])
	else:game.camera=game.player.head
	var view=JSON.parse_string(OS.get_environment("RBPEW_REPLAY_VIEW"))
	if view is Dictionary and view.has("zoom"):game.zoom=float(view.zoom)
	game.camera_focus.clear();game.last_visual_screen="";game.last_visual_camera=Vector2.INF
	game.insect_layer.battle_id=0
	game.run.finished=false;game.death_transition.active=false
	game.runtime_log.run_identity=0
	game.show_game()
	Input.warp_mouse(game.get_viewport_rect().size*.5)
	if game.passive_fx.get("living")!=null and game.passive_fx.living.has_method("invalidate_submission_cache"):game.passive_fx.living.invalidate_submission_cache()
	direction=Vector2(game.player.velocity).normalized()
	if direction.is_zero_approx():direction=Vector2.RIGHT
	chooser.held(direction)
	game.performance_samples.clear();game.combat.phase_times.clear()
	restored=true;source_fingerprint=game.runtime_log.fingerprint("res://scripts/cave_world.gd")
	print("BATTLE_REPLAY_RESTORED=",JSON.stringify({"elapsed":game.run.elapsed,"actors":game.combat.enemies.size(),"parts":game.player.parts.size()}))

func tick():
	if render_auditing:return
	if game==null or game.run==null or game.deployment_active:return
	if not restored:apply_snapshot();return
	var now=Time.get_ticks_usec()
	if pending and game.run.elapsed>pending_elapsed:
		frames+=1
		if frames>warmup:
			frame_us.append(float(now-last_start));sampled_game_seconds+=game.run.elapsed-pending_elapsed
			draw_call_samples.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			for key in game.combat.phase_times:combat_sums[key]=int(combat_sums.get(key,0))+int(game.combat.phase_times[key])
			for key in game.performance_samples:main_sums[key]=int(main_sums.get(key,0))+int(game.performance_samples[key].microseconds)
			if render_timing:
				for key in ["cpu","gpu"]:
					var value=float(RenderingServer.call("viewport_get_measured_render_time_"+key,game.get_viewport().get_viewport_rid()))
					if is_finite(value) and value>0:render_timer_sums[key]+=value;render_timer_samples[key]+=1
			if terrain_kernels:
				var world=game.charcoal_terrain.world
				for key in world.kernel_us:terrain_kernel_us[key]=int(terrain_kernel_us.get(key,0))+int(world.kernel_us[key])
				for key in world.kernel_calls:terrain_kernel_calls[key]=int(terrain_kernel_calls.get(key,0))+int(world.kernel_calls[key])
		if frames>=warmup+samples:
			if OS.get_environment("RBPEW_REPLAY_RENDER_AUDIT")=="1":
				render_auditing=true;chooser.held(Vector2.ZERO);pending=false
				var script=load("res://tools/render_batch_audit.gd")
				var audit=script.new();add_child(audit);audit.setup(game,folder)
				return
			finish("sample_complete");return
	if game.run.finished or game.player.parts[0].hp<=0:finish("normal_death");return
	if game.screen!="game":
		chooser.held(Vector2.ZERO);pending=false
		if now-last_ui>100000:last_ui=now;chooser.choose_or_build()
		return
	# The same frame-indexed movement input is replayed in every variant. No
	# health, actor, equipment, particle or damage overrides are applied.
	var intent=direction.rotated(sin(float(frames)/90)*.3)
	chooser.held(intent)
	game.performance_samples.clear();game.combat.phase_times.clear()
	if terrain_kernels:game.charcoal_terrain.world.kernel_us.clear();game.charcoal_terrain.world.kernel_calls.clear()
	last_start=now;pending=true;pending_elapsed=game.run.elapsed

func bind_value(value,depth:int=0):
	if depth>32:return value
	if value is Dictionary:
		if value.has("uid") and value.has("kind") and canonical_actors.has(int(value.uid)):return canonical_actors[int(value.uid)]
		if value.has("feedback_uid") and value.has("id") and canonical_parts.has(int(value.feedback_uid)):return canonical_parts[int(value.feedback_uid)]
		for key in value:value[key]=bind_value(value[key],depth+1)
	elif value is Array:
		for index in value.size():value[index]=bind_value(value[index],depth+1)
	return value

func statistics(values:Array)->Dictionary:
	if values.is_empty():return {}
	var sorted=values.duplicate();sorted.sort();var sum=0.0
	for value in sorted:sum+=value
	return {"mean_ms":sum/sorted.size()/1000,"p95_ms":sorted[mini(sorted.size()-1,int(sorted.size()*.95))]/1000,"p99_ms":sorted[mini(sorted.size()-1,int(sorted.size()*.99))]/1000,"max_ms":sorted[-1]/1000,"frames":sorted.size()}

func finish(reason:String):
	chooser.held(Vector2.ZERO)
	var report={"scope":"Diagnostic state replay: captured pure simulation state/RNG/terrain; derived indexes and render nodes rebuilt. Frame-indexed input, optional fixed simulation dt; not a real-clock 30-minute acceptance run.",
		"reason":reason,"passed":reason=="sample_complete","fixture":true,"exported":not OS.has_feature("editor"),"debug_build":OS.is_debug_build(),"alias_rebinds":alias_checks,"restore_checks":restore_checks,
		"snapshot_elapsed":snapshot.run_elapsed,"end_elapsed":game.run.elapsed,"warmup_frames":warmup,"sample_frames":samples,"frame":statistics(frame_us),
		"sampled_game_seconds":sampled_game_seconds,"counts":game.runtime_log.counts(game),"combat_phase_mean_ms":{},"main_phase_mean_ms":{},"source":source_fingerprint,"hp":game.player.parts[0].hp}
	for key in combat_sums:report.combat_phase_mean_ms[key]=float(combat_sums[key])/maxi(1,frame_us.size())/1000
	for key in main_sums:report.main_phase_mean_ms[key]=float(main_sums[key])/maxi(1,frame_us.size())/1000
	if not draw_call_samples.is_empty():
		var draw_sum=0.0
		for value in draw_call_samples:draw_sum+=value
		report.draw_calls={"mean":draw_sum/draw_call_samples.size(),"min":draw_call_samples.min(),"max":draw_call_samples.max(),"samples":draw_call_samples.size(),"scope":"Engine renderer counter sampled for every timed active fixture frame"}
	if game.charcoal_terrain.world.has_method("native_stats"):report.native_sweep=game.charcoal_terrain.world.native_stats()
	if render_timing:
		report.engine_render_timing={"scope":"Engine asynchronous viewport timers, separate from main logic; null means no positive supported samples. Timer readback is diagnostic.","positive_samples":render_timer_samples.duplicate(),"cpu_mean_ms":null,"gpu_mean_ms":null}
		for key in ["cpu","gpu"]:
			if render_timer_samples[key]>0:report.engine_render_timing[key+"_mean_ms"]=render_timer_sums[key]/render_timer_samples[key]
	if terrain_kernels:
		report.terrain_kernel_scope="Inclusive nested instrumented calls per sampled frame; profiling overhead changes timing; do not add nested rows or use instrumented FPS as acceptance."
		report.terrain_kernels={}
		for key in terrain_kernel_us:report.terrain_kernels[key]={"mean_ms":float(terrain_kernel_us[key])/maxi(1,frame_us.size())/1000,"calls_per_frame":float(terrain_kernel_calls.get(key,0))/maxi(1,frame_us.size())}
	game.runtime_log.finish_session("battle_replay_"+reason)
	FileAccess.open(folder.path_join("replay-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	if DisplayServer.get_name()!="headless":game.get_viewport().get_texture().get_image().save_png(folder.path_join("replay.png"))
	print("BATTLE_REPLAY_REPORT=",JSON.stringify(report))
	game.cursor_system.shutdown();game.audio_system.shutdown();get_tree().quit(0 if report.passed else 1)
