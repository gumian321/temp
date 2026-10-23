extends SceneTree
## Real main scene with normal AI/fire/collisions. CPU attribution and real
## frame intervals are recorded separately; setup and stopped screens excluded.
const Trails=preload("res://scripts/projectile_trails.gd")
class ProfileFX extends "res://scripts/weapon_fx.gd":
	var projectile_us=0
	var effect_us=0
	func paint_projectile(canvas,bullet:Dictionary,time:float,zoom:float):
		var began=Time.get_ticks_usec();super.paint_projectile(canvas,bullet,time,zoom);projectile_us+=Time.get_ticks_usec()-began
	func paint(canvas,battle,time:float,zoom:float):
		var began=Time.get_ticks_usec();super.paint(canvas,battle,time,zoom);effect_us+=Time.get_ticks_usec()-began
class ProfileGame extends "res://scripts/main.gd":
	var draw_us=0
	func _draw():
		weapon_fx.projectile_us=0;weapon_fx.effect_us=0
		var began=Time.get_ticks_usec();super._draw();draw_us=Time.get_ticks_usec()-began
var game
var checks:Array=[]
var rows:Array=[]
var captures:Array=[]
var seen_hostile:Dictionary={}
var missing_trails=0
var curved_trails=0
var peak_hostile=0
var trace_checks=0
var tag=""
func _initialize():call_deferred("execute")
func check(ok:bool,label:String):
	checks.append({"name":label,"passed":ok})
	if not ok:printerr("FAIL: ",label)
func stats(values:Array)->Dictionary:
	if values.is_empty():return {}
	values.sort();var total=0.0
	for value in values:total+=value
	return {"mean":total/values.size(),"median":values[values.size()/2],"p95":values[mini(values.size()-1,int(values.size()*.95))],"max":values[-1]}
func audit_hostiles():
	var count=0
	for shot in game.combat.bullets:
		if shot.friendly:continue
		count+=1;seen_hostile[str(shot.fx_family)]=int(seen_hostile.get(str(shot.fx_family),0))+1
		if float(shot.age)<.04:continue
		var state:Dictionary=shot.get("projectile_trail",{})
		if state.is_empty():missing_trails+=1;continue
		var path=Trails.path(state,42.0/game.zoom)
		if path.points.size()>2:
			var first=Vector2(path.points[1])-Vector2(path.points[0]);var last=Vector2(path.points[-1])-Vector2(path.points[-2])
			if absf(first.angle_to(last))>.015:curved_trails+=1
	peak_hostile=maxi(peak_hostile,count)
func spawn_named(name:String,at:Vector2):
	for prefab in game.db.entities:
		for blueprint in game.db.entities[prefab]:
			if str(blueprint.name)==name and str(blueprint.parent_unit)=="0":
				var enemy=game.combat.spawn_actor(prefab,blueprint,at)
				enemy.hp=100000;enemy.max_hp=100000
				return enemy
	return {}
func run_case(label:String,seconds:float,action:String=""):
	if not action.is_empty():Input.action_press(action)
	var started=Time.get_ticks_usec();var initial=float(game.run.elapsed);var frame=0
	while Time.get_ticks_usec()-started<seconds*1000000:
		game.reward_snoozed=true;game.reward_snooze_count=2147483647
		game.performance_samples.clear();game.combat.phase_times.clear()
		var before=float(game.run.elapsed);var began=Time.get_ticks_usec()
		game._process(game.get_process_delta_time())
		var cpu=float(Time.get_ticks_usec()-began)/1000
		await process_frame;await RenderingServer.frame_post_draw
		if game.screen!="game" or float(game.run.elapsed)<=before:
			check(false,"Every measured frame advances live battle: "+label);break
		audit_hostiles()
		rows.append({"case":label,"frame_ms":float(Time.get_ticks_usec()-began)/1000,"cpu_ms":cpu,
			"draw_ms":float(game.draw_us)/1000,"projectile_draw_ms":float(game.weapon_fx.projectile_us)/1000,
			"effects_draw_ms":float(game.weapon_fx.effect_us)/1000,"actors":game.combat.enemies.size(),
			"bullets":game.combat.bullets.size(),"death_splatters":game.combat.death_splatters.size(),
			"attack_commands":game.attack_shader_layer.stats().commands,
			"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"phases":game.performance_samples.duplicate(true),"combat_phases":game.combat.phase_times.duplicate(),
			"elapsed":game.run.elapsed,"zoom":game.zoom})
		frame+=1
	if not action.is_empty():Input.action_release(action)
	check(float(game.run.elapsed)>initial,"Case includes real simulation: "+label)
	var path="res://artifacts/startup-profile-"+label+tag+".png"
	root.get_texture().get_image().save_png(path);captures.append(path)
	var selected=rows.filter(func(row):return row["case"]==label)
	var result={"case":label,"frames":selected.size(),"simulated_seconds":float(game.run.elapsed)-initial}
	for key in ["frame_ms","cpu_ms","draw_ms","projectile_draw_ms","effects_draw_ms","actors","bullets","draw_calls","attack_commands"]:
		result[key]=stats(selected.map(func(row):return row[key]))
	print("STARTUP_PROFILE ",JSON.stringify(result))
	return result
func execute():
	var requested=OS.get_environment("RBPEW_STARTUP_TAG")
	if not requested.is_empty():tag="-"+requested.validate_filename()
	check(DisplayServer.get_name()!="headless","Uses the actual native renderer")
	root.size=Vector2i(1440,900);set_meta("performance_fixture",true)
	game=ProfileGame.new();game.weapon_fx=ProfileFX.new();root.add_child(game);await process_frame
	game.set_process(false);game.test_mode=false;game.save.fresh();game.selected_mission=game.db.named("Survival Mission")
	game.begin_run()
	while game.deployment_active:await process_frame
	game.set_process(false);game.combat.profile_enabled=true
	game.combat.rng.seed=20261022;game.run.rng.seed=20261022;game.run.encounters.rng.seed=20261022
	game.tutorials.movement_shown=true;game.tutorials.radar_shown=true;game.tutorials.fuel_shown=true
	for part in game.player.parts:part.hp=100000;part.max_hp=100000
	game.reward_snoozed=true;game.reward_snooze_count=2147483647
	var results:Array=[]
	results.append(await run_case("fresh-idle",5.0))
	results.append(await run_case("fresh-mining",5.0,"move_right"))
	preload("res://scripts/performance_loadouts.gd").install(game.player,game.db)
	for part in game.player.parts:part.hp=100000;part.max_hp=100000
	game.player.motion.reset();game.player.refresh_positions()
	results.append(await run_case("mixed-combat",6.0,"move_up"))
	# Normal prefab weapons, AI aiming, source fire() and original rates. No
	# hand-created bullets or renderer-only hostile objects are added.
	var names=["AI_ProjectileShip_Gatling","AI_ProjectileShip_Cannon","AI_ProjectileShip_Rocket","AI_ProjectileShip_EMP","AI_ProjectileShip_Tesla","AI_ProjectileShip_GatlingSniperGatling","AI_Shotgun_1","AI_Following_Flak","AI_DronesCarrier_1"]
	var spawned=[]
	for i in names.size():
		var at=game.player.head+Vector2.from_angle(TAU*float(i)/names.size())*240
		var enemy=spawn_named(names[i],at);check(not enemy.is_empty(),"Production enemy prefab exists: "+names[i]);spawned.append(enemy)
	results.append(await run_case("hostile-crossfire",8.0,"move_left"))
	check(peak_hostile>0 and not seen_hostile.is_empty(),"Actual enemy AI fires red projectiles in main scene")
	check(missing_trails==0,"All observed surviving red projectiles own dynamic history")
	check(curved_trails>0,"Actual homing projectiles preserve curved history")
	var report={"scope":"Debug Godot source runtime, normal main scene/AI/weapons/collisions and real engine delta. Isolated save; HP raised only to retain inspection subjects; fixed test inputs and staged native enemy encounter. No editor debugger connected. Not the user's exact equipment/window.",
		"renderer":DisplayServer.get_name(),"resolution":root.size,"debug_build":OS.is_debug_build(),
		"results":results,"rows":rows,"captures":captures,"hostile_families":seen_hostile,"peak_hostile":peak_hostile,
		"missing_hostile_histories":missing_trails,"curved_hostile_histories":curved_trails,
		"checks":checks,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/startup-combat-profile"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await process_frame;await process_frame
	quit(0 if report.passed else 1)
