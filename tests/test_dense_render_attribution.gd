extends SceneTree
## Identical frozen dense battle: isolate presentation cost, never claim FPS.
class ProfileFX extends "res://scripts/weapon_fx.gd":
	var suppressed=false
	func paint(canvas,battle,time:float,zoom:float):
		if not suppressed:super.paint(canvas,battle,time,zoom)
	func paint_projectile(canvas,bullet:Dictionary,time:float,zoom:float):
		if not suppressed:super.paint_projectile(canvas,bullet,time,zoom)
class ProfileGame extends "res://scripts/main.gd":
	var mode="full"
	var last_draw_us=0
	var organ_us=0
	func _draw():
		var began=Time.get_ticks_usec();organ_us=0
		super._draw()
		if mode=="no_terrain":cave_terrain.visible=false
		last_draw_us=Time.get_ticks_usec()-began
	func organ_art(texture:Texture2D,at:Vector2,bounds:Vector2,rotation:float,tint:Color,family:String,pulse:float,key:String="",seed_value:float=0.0,activity:float=0.0,frozen:bool=false,tension:Dictionary={}):
		if mode=="no_organs":return
		var began=Time.get_ticks_usec()
		super.organ_art(texture,at,bounds,rotation,tint,family,pulse,key,seed_value,activity,frozen,tension)
		organ_us+=Time.get_ticks_usec()-began
func _initialize():call_deferred("execute")
func stats(values:Array)->Dictionary:
	values.sort();var total=0.0
	for value in values:total+=value
	return {"mean":total/values.size(),"median":values[values.size()/2],"p95":values[mini(values.size()-1,int(values.size()*.95))],"max":values[-1]}
func execute():
	root.size=Vector2i(1440,900);set_meta("performance_fixture",true)
	var game=ProfileGame.new();game.weapon_fx=ProfileFX.new();root.add_child(game);await process_frame
	game.set_process(false);game.test_mode=false;game.save.fresh();game.selected_mission=game.db.named("Survival Mission");game.begin_run()
	while game.deployment_active:await process_frame
	game.set_process(false)
	game.combat.rng.seed=20261021;game.run.rng.seed=20261021;game.run.encounters.rng.seed=20261021
	preload("res://scripts/performance_loadouts.gd").install(game.player,game.db)
	for part in game.player.parts:part.hp=100000;part.max_hp=100000
	game.player.motion.reset();game.player.refresh_positions()
	for i in 16:
		var angle=float(i)*TAU/16
		var enemy=game.combat.spawn(game.db.pool["250"],Vector2.from_angle(angle)*200+Vector2(-60,0))
		enemy.hp=100000;enemy.max_hp=100000;enemy.warp=0
	game.combat.profile_enabled=true
	game.reward_snoozed=true;game.reward_snooze_count=2147483647
	var simulation=[]
	for frame in 900:
		game.performance_samples.clear();game.combat.phase_times.clear()
		game.camera_focus.clear();game.reward_snoozed=true
		var began=Time.get_ticks_usec();game._process(1.0/60)
		var cpu=float(Time.get_ticks_usec()-began)/1000
		game.run.rewards.queue.clear();game.run.packs=0
		await process_frame;await RenderingServer.frame_post_draw
		simulation.append({"frame":frame,"cpu_ms":cpu,"frame_ms":float(Time.get_ticks_usec()-began)/1000,"phases":game.performance_samples.duplicate(true),"combat_phases":game.combat.phase_times.duplicate(),"effects":game.combat.effects.size(),"actors":game.combat.enemies.size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
		if frame>=300 and game.combat.effects.size()>=24:break
	var results=[]
	for mode in ["full","no_attacks","hidden_attack_layers","no_organs","no_insects","no_terrain","full_repeat"]:
		game.mode=mode;game.weapon_fx.suppressed=mode=="no_attacks"
		game.attack_shader_layer.visible=mode!="hidden_attack_layers"
		game.insect_layer.visible=mode!="no_insects"
		game.cave_terrain.visible=mode!="no_terrain"
		var frames=[];var draws=[];var organs=[];var calls=[];var phases=[]
		for frame in 100:
			game.performance_samples.clear()
			var began=Time.get_ticks_usec();game.queue_redraw()
			await process_frame;await RenderingServer.frame_post_draw
			# cave_terrain.sync() owns visibility, so suppress after its callback
			# only in this frozen diagnostic and allow the next draw to settle.
			if mode=="no_terrain":game.cave_terrain.visible=false
			if frame<12:continue
			frames.append(float(Time.get_ticks_usec()-began)/1000);draws.append(float(game.last_draw_us)/1000);organs.append(float(game.organ_us)/1000)
			calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));phases.append(game.performance_samples.duplicate(true))
		results.append({"case":mode,"render_frame_ms":stats(frames),"main_draw_ms":stats(draws),"organ_ms":stats(organs),"draw_calls":stats(calls),"phases":phases})
		if mode=="full":root.get_texture().get_image().save_png("res://artifacts/dense-render-full.png")
	var report={"scope":"Frozen identical dense battle drawing only, not gameplay FPS. 16 durable fixture targets plus natural actors; actual weapons and effects simulated before freezing.","simulation":simulation,"results":results,"effects":game.combat.effects.size(),"insect_rigs":game.insect_layer.rigs.size()}
	FileAccess.open("res://artifacts/dense-render-attribution.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	for result in results:print("DENSE_RENDER ",JSON.stringify({"case":result.case,"frame_ms":result.render_frame_ms,"draw_ms":result.main_draw_ms,"organ_ms":result.organ_ms,"calls":result.draw_calls}))
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await process_frame;await process_frame;quit()
