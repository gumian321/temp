extends "res://scripts/windows_review_probe.gd"
## Fixed-tick native pressure fixture with CPU attribution. Same production AI,
## hit detection, projectiles, artwork and effects as the normal game.
class ProfileFX extends "res://scripts/weapon_fx.gd":
	var costs:Dictionary={}
	func measure(key:String,began:int):costs[key]=int(costs.get(key,0))+Time.get_ticks_usec()-began
	func paint_projectile(canvas,shot:Dictionary,time:float,zoom:float):
		var began=Time.get_ticks_usec();super.paint_projectile(canvas,shot,time,zoom);measure("projectiles",began)
	func paint_effect(canvas,effect:Dictionary,zoom:float):
		var began=Time.get_ticks_usec();super.paint_effect(canvas,effect,zoom);measure("effect/"+str(effect.kind),began)
class ProfileGame extends "res://scripts/main.gd":
	var draw_us=0
	func _draw():
		var began=Time.get_ticks_usec();super._draw();draw_us=Time.get_ticks_usec()-began
const DT=1.0/60
var rows:Array=[]
func stats(values:Array)->Dictionary:
	values.sort();var sum=0.0
	for value in values:sum+=value
	return {"within_60fps_percent":float(values.filter(func(v):return v<=1000.0/60).size())*100.0/values.size(),"mean":sum/values.size(),"median":values[values.size()/2],"p95":values[int(values.size()*.95)],"p99":values[mini(values.size()-1,int(values.size()*.99))],"max":values[-1]}
func execute():
	if DisplayServer.get_name()=="headless":push_error("Dense pressure fixture requires --render --native-pacing");quit(1);return
	tree.set_meta("performance_fixture",true);root.size=Vector2i(1440,900)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0;seed(20261014)
	var tag=OS.get_environment("RBPEW_PRESSURE_TAG").validate_filename()
	if tag.is_empty():tag="latest"
	var count=int(OS.get_environment("RBPEW_PRESSURE_ENEMIES")) if not OS.get_environment("RBPEW_PRESSURE_ENEMIES").is_empty() else 64
	var floor_count=int(OS.get_environment("RBPEW_PRESSURE_BULLETS")) if not OS.get_environment("RBPEW_PRESSURE_BULLETS").is_empty() else 256
	var parts=int(OS.get_environment("RBPEW_PRESSURE_PARTS")) if not OS.get_environment("RBPEW_PRESSURE_PARTS").is_empty() else 31
	game.set_process(false);game.weapon_fx=ProfileFX.new()
	game.test_mode=true;game.save.fresh();game.save.state.settings.skip_boss=true
	game.selected_mission=game.db.named("Endless Mission");game.start_run();game.set_process(false)
	game.performance_profile_enabled=true;game.combat.profile_enabled=true
	game.combat.enemies.clear();game.combat.bullets.clear();game.combat.patrols.clear();game.combat.effects.clear()
	var gun=game.db.named("Core_Gun_Gatling")
	for i in parts-1:game.player.append_segment(gun.id)
	for part in game.player.parts:part.hp=10000000.0;part.max_hp=10000000.0
	for i in count:
		var e=game.combat.spawn(game.db.pool["256" if i%4==0 else "255"],Vector2.from_angle(TAU*i/count)*(220+float(i%7)*60))
		e.hp=10000000.0;e.max_hp=10000000.0
	game.camera=game.player.head;game.center=Vector2(720,450);game.tutorials.visible=false;game.audio_system.shutdown()
	var warmup=60 if OS.get_environment("RBPEW_PRESSURE_WARMUP").is_empty() else clampi(int(OS.get_environment("RBPEW_PRESSURE_WARMUP")),1,600)
	var samples=180 if OS.get_environment("RBPEW_PRESSURE_SAMPLES").is_empty() else clampi(int(OS.get_environment("RBPEW_PRESSURE_SAMPLES")),60,1800)
	for frame in warmup+samples:
		game.performance_samples.clear();game.combat.phase_times.clear();game.weapon_fx.costs.clear()
		var began=Time.get_ticks_usec()
		for i in maxi(0,floor_count-game.combat.bullets.size()):
			var angle=float(frame*17+i)*2.39996323;var friendly=i%2==0
			game.combat.fire(gun,game.player.head+Vector2.from_angle(angle)*(60 if friendly else 600),Vector2.from_angle(angle)*(1 if friendly else -1),friendly,{},0,true)
		var injected=Time.get_ticks_usec()
		game.player.step(DT,Vector2.from_angle(frame*.011),false)
		game.leg_phase+=game.player.velocity.length()*DT*.075;game.player_legs.step(game.player,DT)
		game.combat.step(DT,game.player.head+Vector2.RIGHT*600,true)
		var simulated=Time.get_ticks_usec()
		game.combat.audio_events.clear();game.player.feedback_events.clear()
		game.test_time+=DT;game.camera=game.player.head
		game.update_source_hud();game.sync_camera_layers();game.insect_layer.sync(game,DT);game.queue_redraw()
		var prepared=Time.get_ticks_usec()
		await process_frame;await RenderingServer.frame_post_draw
		if frame<warmup:continue
		var draw_cost=0.0
		if "draw_us" in game:draw_cost=float(game.draw_us)
		else:
			for phase in game.performance_samples.values():draw_cost+=float(phase.microseconds)
		var row={"frame_ms":(Time.get_ticks_usec()-began)/1000.0,"simulation_ms":(simulated-injected)/1000.0,"inject_ms":(injected-began)/1000.0,"visual_sync_ms":(prepared-simulated)/1000.0,"main_draw_ms":draw_cost/1000.0,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"bullets":game.combat.bullets.size(),"effects":game.combat.effects.size(),"actors":game.combat.enemies.size(),"main_phases":game.performance_samples.duplicate(true),"combat_phases":game.combat.phase_times.duplicate(),"fx_phases":game.weapon_fx.costs.duplicate()}
		rows.append(row)
	var summary:Dictionary={}
	for key in ["frame_ms","simulation_ms","inject_ms","visual_sync_ms","main_draw_ms","draw_calls","bullets","effects","actors"]:summary[key]=stats(rows.map(func(row):return row[key]))
	var phases:Dictionary={}
	for row in rows:
		for group in ["main_phases","combat_phases","fx_phases"]:
			for key in row[group]:
				var value=float(row[group][key].microseconds) if group=="main_phases" else float(row[group][key])
				var path=group+"/"+key;phases[path]=float(phases.get(path,0))+value/rows.size()/1000.0
	var hp=0.0
	for e in game.combat.enemies:hp+=e.hp
	var report={"fixture_version":2,"debug_build":OS.is_debug_build(),"exported":not OS.has_feature("editor"),"tag":tag,"renderer":RenderingServer.get_video_adapter_name(),"scope":"Fixed 1/60 simulation with native rendering; source projectile floor replenishment is separately timed. Not real-time dynamic-delta FPS. No editor debugger, isolated save.","config":{"actors":count,"parts":parts,"projectile_floor":floor_count,"warmup":warmup,"samples":samples},"summary":summary,"phases_mean_ms":phases,"flight_instances":game.attack_shader_layer.flight_batch.submitted,"flight_groups":game.attack_shader_layer.flight_batch.groups.size(),"signature":{"actors":game.combat.enemies.size(),"parts":game.player.parts.size(),"bullets":game.combat.bullets.size(),"hp_sum":hp,"rng":str(game.combat.rng.state),"head":[game.player.head.x,game.player.head.y]},"rows":rows}
	var path=OS.get_environment("RBPEW_PRESSURE_OUTPUT")
	if path.is_empty():path=("res://artifacts/" if OS.has_feature("editor") else "user://")+"dense-pressure-"+tag+".json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	root.get_texture().get_image().save_png(path.get_basename()+".png")
	print("DENSE_PRESSURE ",JSON.stringify(summary));print("PHASES ",JSON.stringify(phases))
	game.cursor_system.shutdown();game.particle_effects.clear();game.queue_free();await process_frame;await process_frame;quit(0)
