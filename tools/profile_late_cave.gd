extends SceneTree
const World=preload("res://scripts/cave_world.gd")
const Prototype=preload("res://tools/cave_sweep_prototype.gd")
const Profiled=preload("res://tools/profiled_cave_world.gd")
const ResultCache=preload("res://tools/cave_result_cache_prototype.gd")
const DB=preload("res://scripts/source_db.gd")
var rows=[]
func _initialize():call_deferred("execute")
func vector(value)->Vector2:
	if value is Array:return Vector2(float(value[0]),float(value[1]))
	var fields=str(value).trim_prefix("(").trim_suffix(")").split(",")
	return Vector2(float(fields[0]),float(fields[1]))
func percentile(values:Array,fraction:float)->float:
	values.sort();return values[mini(values.size()-1,int(values.size()*fraction))] if not values.is_empty() else 0
func execute():
	var path=OS.get_environment("RBPEW_ROSTER_REPLAY")
	if path.is_empty():printerr("Missing captured late-game roster");quit(2);return
	var snapshot=JSON.parse_string(FileAccess.get_file_as_string(path));var db=DB.new()
	var target=vector(snapshot.player_parts[0].position)
	var actors=[]
	for actor in snapshot.actors:
		if actor.parent!=0 or actor.kind not in ["AIBossUnit","AISwarmingUnit"]:continue
		var definitions=db.entities.get(actor.prefab,[]);var speed=96.0;var rotate_speed=24.0
		for blueprint in definitions:
			if blueprint.unit.get("class")!=actor.kind:continue
			for component in blueprint.components:
				if str(component.get("class","")).ends_with("Movement"):
					speed=float(component.get("enginePower",2))*48;rotate_speed=float(component.get("enginePower",2))*float(component.get("rotEngineModifier",12));break
			break
		# Only survival_final actors enable heat_speed. These captures are from
		# Endless Mission, whose bosses retain base speed; old captures omitted
		# the flag, so do not invent a heat multiplier for them.
		if actor.kind=="AIBossUnit" and actor.get("heat_speed",false):
			var factor=maxf(1,snapshot.heat) if actor.active else snapshot.heat
			speed*=factor*(2.0 if factor>1 else 1.0)
		actors.append({"position":vector(actor.position),"radius":float(actor.ground_radius),"kind":actor.kind,"speed":speed,"rotate_speed":rotate_speed})
	var tests=[]
	# This is a collision/navigation micro-reproducer from the captured roster,
	# not a restored full save or a rendered FPS comparison. Excavated cells are
	# not restored; both paths use the same original procedural cave.
	var profile_only=OS.get_environment("RBPEW_CAVE_PROFILE_ONLY")=="1"
	var result_cache=OS.get_environment("RBPEW_CAVE_RESULT_CACHE")=="1"
	var production_cache=OS.get_environment("RBPEW_CAVE_PRODUCTION_CACHE")=="1"
	var recovery_cache=OS.get_environment("RBPEW_CAVE_RECOVERY_CACHE")=="1"
	var extended_sweeps=OS.get_environment("RBPEW_CAVE_EXTENDED_SWEEPS")=="1"
	var variable_steps=[1.0/60,.018,.026,1.0/30,.041,.017]
	var prototype_name="production" if production_cache else ("result_cache" if result_cache else "prototype")
	if recovery_cache:prototype_name="recovery"
	for variant in (["profiled"] if profile_only else ["legacy",prototype_name,prototype_name,"legacy"]):
		var use_prototype=variant=="prototype"
		var world=Profiled.new() if variant=="profiled" else (ResultCache.new() if variant=="result_cache" else (Prototype.new() if use_prototype else World.new()));world.reset_cave(true)
		world.use_sweep_result_cache=variant=="production" or recovery_cache
		world.use_recovery_cache=variant=="recovery"
		world.use_extended_sweeps=variant=="recovery" and extended_sweeps
		world.use_collision_blocks=variant=="recovery"
		var states=actors.duplicate(true);var frames=[];var nav=[];var movement=[];var by_kind={}
		for frame in 160:
			if frame==40 and variant=="profiled":world.kernel_us.clear();world.kernel_calls.clear()
			var dt:float=variable_steps[frame%variable_steps.size()] if recovery_cache else 1.0/30
			world.begin_navigation_frame(dt)
			var began=Time.get_ticks_usec();var nav_us=0;var move_us=0
			for actor in states:
				var stage=Time.get_ticks_usec()
				var direction=world.direction(actor.position,target,actor.radius,actor)
				nav_us+=Time.get_ticks_usec()-stage;stage=Time.get_ticks_usec()
				var desired=actor.position+direction*actor.speed*dt
				actor.position=world.move(actor.position,desired,actor.radius)
				var cost=Time.get_ticks_usec()-stage;move_us+=cost
				if frame>=40:by_kind[actor.kind]=int(by_kind.get(actor.kind,0))+cost
			if frame>=40:frames.append(float(Time.get_ticks_usec()-began)/1000);nav.append(float(nav_us)/1000);movement.append(float(move_us)/1000)
		var total=0.0;var nav_total=0.0;var move_total=0.0
		for value in frames:total+=value
		for value in nav:nav_total+=value
		for value in movement:move_total+=value
		tests.append({"prototype":use_prototype,"mean_ms":total/frames.size(),"p95_ms":percentile(frames,.95),"max_ms":frames[-1],"navigation_mean_ms":nav_total/nav.size(),"movement_mean_ms":move_total/movement.size(),"movement_us_by_kind":by_kind,"extended_queries":world.extended_queries if use_prototype else 0})
		tests[-1].variant=variant
		tests[-1].p99_ms=percentile(frames,.99)
		if variant=="result_cache":tests[-1].cache_hits=world.cache_hits;tests[-1].cache_misses=world.cache_misses
		if variant=="production":tests[-1].cache_hits=world.sweep_result_hits;tests[-1].cache_misses=world.sweep_result_misses
		if recovery_cache:
			tests[-1].recovery_hits=world.recovery_hits;tests[-1].recovery_misses=world.recovery_misses
			tests[-1].cache_hits=world.sweep_result_hits;tests[-1].cache_misses=world.sweep_result_misses
			tests[-1].extended_sweeps=world.extended_sweeps;tests[-1].neighborhood_grows=world.sweep_neighborhood_grows
		if variant=="profiled":tests[-1].kernel_inclusive_us=world.kernel_us;tests[-1].kernel_calls=world.kernel_calls
		await process_frame
	var legacy=World.new();legacy.reset_cave(true);legacy.use_sweep_result_cache=false
	var candidate=World.new() if production_cache else (ResultCache.new() if result_cache else Prototype.new());candidate.reset_cave(true)
	candidate.use_sweep_result_cache=production_cache
	var probes=0;var mismatch=0;var max_error=0.0
	for actor in ([] if profile_only or recovery_cache else actors):
		for angle_index in 12:
			for length in [8.01,12.0,16.0,24.0,32.0]:
				var start:Vector2=actor.position;var finish=start+Vector2.from_angle(angle_index*TAU/12)*length
				var a=legacy.wall_hit(start,finish,actor.radius)
				var b=candidate.movement_wall_hit(start,finish,actor.radius) if production_cache else candidate.wall_hit(start,finish,actor.radius)
				probes+=1
				if a.is_empty()!=b.is_empty():mismatch+=1
				elif not a.is_empty():
					var error=absf(float(a.time)-float(b.time));max_error=maxf(max_error,error)
					if error>.000001 or Vector2(a.normal).distance_to(Vector2(b.normal))>.0001:mismatch+=1
	var report={"snapshot_elapsed":snapshot.run_elapsed,"actors":actors.size(),"heat":snapshot.heat,"dt":1.0/30,"scope":"ABBA headless navigation/collision micro-reproducer from recorded root actors. Same procedural seed, mining edits not restored, no rendered FPS claim.","tests":tests,"collision_probes":probes,"mismatch":mismatch,"max_time_error":max_error}
	report.model_version=2;report.speed_model="Base prefab movement speed for Endless Mission; heat only when explicitly captured heat_speed=true. Missing headings use navigation intent, boosts are not restored."
	var output="res://artifacts/late-cave-kernels-20261026.json" if profile_only else "res://artifacts/late-cave-profile-20261026.json"
	if result_cache:output="res://artifacts/late-cave-result-cache-20261026.json"
	if production_cache:output="res://artifacts/late-cave-production-cache-20261026.json"
	if recovery_cache:
		output="res://artifacts/late-cave-recovery-cache-20261026.json"
		report.dt=variable_steps;report.scope+=" Recovery comparison keeps the existing sweep result cache enabled in both paths."
		report.correctness_report="artifacts/cave-recovery-cache-20261026.json"
		report.extended_sweeps=extended_sweeps
		for key in ["collision_probes","mismatch","max_time_error"]:report.erase(key)
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	quit(0 if mismatch==0 else 1)
