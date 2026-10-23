extends SceneTree
## Frozen scene differential: render attribution, not playable-game FPS.
const Fixture=preload("res://tests/mixed_loadout_fixture.gd")
class ProfilePassive extends "res://scripts/passive_feedback.gd":
	var suppressed=false
	func paint(canvas,player,combat,zoom:float):
		if not suppressed:super.paint(canvas,player,combat,zoom)
class ProfileGame extends "res://scripts/main.gd":
	var diagnostic_mode="full"
	var last_draw_ms=0.0
	var organ_ms=0.0
	var organ_families={}
	func _draw():
		var began=Time.get_ticks_usec();organ_ms=0.0;organ_families.clear()
		weapon_fx.use_mine_batches=diagnostic_mode!="legacy_egg"
		var mines=combat.special.mines if combat!=null else []
		var strands=player.flagella.strands if player!=null else {}
		if diagnostic_mode=="no_egg_visuals":combat.special.mines=[]
		if diagnostic_mode=="no_flagella":player.flagella.strands={}
		super._draw()
		if diagnostic_mode=="no_egg_visuals":combat.special.mines=mines
		if diagnostic_mode=="no_flagella":player.flagella.strands=strands
		last_draw_ms=float(Time.get_ticks_usec()-began)/1000.0
	func organ_art(texture:Texture2D,at:Vector2,bounds:Vector2,rotation:float,tint:Color,family:String,pulse:float,key:String="",seed_value:float=0.0,activity:float=0.0,frozen:bool=false,tension:Dictionary={}):
		if diagnostic_mode=="no_soft_organs":return
		var began=Time.get_ticks_usec()
		super.organ_art(texture,at,bounds,rotation,tint,family,pulse,key,seed_value,activity,frozen,tension)
		var ms=float(Time.get_ticks_usec()-began)/1000.0
		organ_ms+=ms;organ_families[family]=float(organ_families.get(family,0))+ms
func _initialize():call_deferred("execute")
func stats(values:Array)->Dictionary:
	values.sort();var total=0.0
	for value in values:total+=value
	return {"mean":total/values.size(),"median":values[values.size()/2],"p95":values[mini(values.size()-1,int(values.size()*.95))],"max":values[-1]}
func execute():
	root.size=Vector2i(1440,900);set_meta("performance_fixture",true)
	var game=ProfileGame.new();game.passive_fx=ProfilePassive.new();root.add_child(game);await process_frame
	game.set_process(false);game.test_mode=false;game.save.fresh();game.selected_mission=game.db.named("Survival Mission");game.begin_run()
	while game.deployment_active:await process_frame
	game.set_process(false);game.combat.enemies.clear();game.combat.effects.clear();game.combat.drones.clear()
	Fixture.install(game.player,game.db)
	for i in 12:
		game._process(1.0/60);game.run.rewards.queue.clear();game.run.packs=0
		await process_frame;await RenderingServer.frame_post_draw
	game.combat.enemies.clear();game.combat.effects.clear();game.insect_layer.sync(game,0)
	for i in 30:
		game.player.parts[7].cooldown=0;game.combat.special.step(0)
	game.combat.effects.clear();game.show_game()
	var results=[]
	for mode in ["full","legacy_egg","no_egg_visuals","no_soft_organs","no_passives","no_flagella","full_repeat"]:
		game.diagnostic_mode=mode;game.passive_fx.suppressed=mode=="no_passives"
		var frames=[];var draws=[];var organs=[];var calls=[];var primitives=[]
		for frame in 132:
			var began=Time.get_ticks_usec();game.queue_redraw()
			await process_frame;await RenderingServer.frame_post_draw
			if frame<12:continue
			frames.append(float(Time.get_ticks_usec()-began)/1000.0);draws.append(game.last_draw_ms);organs.append(game.organ_ms)
			calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		var row={"case":mode,"render_frame_ms":stats(frames),"main_draw_ms":stats(draws),"organ_draw_ms":stats(organs),"draw_calls":stats(calls),"primitives":stats(primitives),"last_organ_families_ms":game.organ_families.duplicate()}
		results.append(row);print("MIXED_RENDER ",JSON.stringify(row))
		if mode in ["full","legacy_egg"]:root.get_texture().get_image().save_png("res://artifacts/mixed-render-"+mode+".png")
	FileAccess.open("res://artifacts/mixed-render-attribution.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"Identical frozen screenshot-derived loadout with 30 egg mines. Changes hide drawing only, not saved equipment or production logic. Render times are not playable-game FPS; another user playtest may still be rendering.","results":results},"\t"))
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await process_frame;await process_frame;quit()
