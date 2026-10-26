extends SceneTree
## Alternating render-only A/B blocks on exactly the same live-game snapshot.
## Deliberately excludes simulation and never reports these timings as game FPS.
const Organs=preload("res://scripts/soft_organ_art.gd")
class ProfileGame extends "res://scripts/main.gd":
	var costs:Array=[]
	func _draw():
		var start=Time.get_ticks_usec();super._draw();costs.append(float(Time.get_ticks_usec()-start)/1000)
var checks:Array=[]
func check(value:bool,message:String):
	checks.append({"passed":value,"name":message})
	if not value:push_error(message)
func _initialize():call_deferred("execute")
func execute():
	if DisplayServer.get_name()=="headless":push_error("Render snapshot requires --render");quit(1);return
	set_meta("performance_fixture",true);root.size=Vector2i(1440,900)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var game=ProfileGame.new();root.add_child(game);await process_frame;game.set_process(false)
	game.save.fresh();game.save.state.settings.skip_boss=true;game.start_run();game.set_process(false)
	game.combat.enemies.clear();game.combat.bullets.clear();game.combat.patrols.clear()
	preload("res://scripts/performance_loadouts.gd").install(game.player,game.db)
	for part in game.player.parts:part.hp=100000;part.max_hp=100000
	for i in 24:
		var e=game.combat.spawn(game.db.pool["256" if i%4==0 else "255"],Vector2.from_angle(i*TAU/24)*(200+i%4*60))
		e.hp=100000;e.max_hp=100000
	for frame in 45:
		game.player.step(1.0/60,Vector2.UP,false);game.combat.step(1.0/60,Vector2.RIGHT*600,true)
	game.camera=game.player.head;game.test_time=1.25;game.camera_kick=Vector2.ZERO
	game.insect_layer.sync(game,0);game.sync_camera_layers();game.update_source_hud()
	game.tutorials.visible=false;game.tutorials.set_process(false)
	game.particle_effects.process_mode=Node.PROCESS_MODE_DISABLED
	game.performance_overlay.set_process(false);game.performance_overlay.display.hide();game.audio_system.shutdown()
	var costs={"cpu":[],"gpu":[]};var blocks=[];var pictures:Dictionary={}
	var count_before=[game.combat.enemies.size(),game.combat.bullets.size(),game.player.parts.size(),game.combat.rng.state]
	for mode in ["cpu","gpu","gpu","cpu"]:
		game.soft_organs=Organs.new();game.soft_organs.use_gpu=mode=="gpu"
		for frame in 12:game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		game.costs.clear()
		for frame in 48:game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		var sum=0.0
		for value in game.costs:sum+=value;costs[mode].append(value)
		blocks.append({"mode":mode,"mean_main_draw_ms":sum/game.costs.size()})
		pictures[mode]=root.get_texture().get_image()
	var summary:Dictionary={}
	for mode in costs:
		var values:Array=costs[mode];values.sort();var sum=0.0
		for value in values:sum+=value
		summary[mode]={"mean_main_draw_ms":sum/values.size(),"median_main_draw_ms":values[values.size()/2],"p95_main_draw_ms":values[int(values.size()*.95)]}
	var a=pictures.cpu.get_data();var b=pictures.gpu.get_data();var sum_error=0;var changed=0
	for i in a.size():
		var difference=absi(int(a[i])-int(b[i]));sum_error+=difference
		if difference>16:changed+=1
	var mean_error=float(sum_error)/a.size();var changed_fraction=float(changed)/a.size()
	check(changed_fraction<.002 and mean_error<.5,"Main-scene CPU/GPU paths preserve generated art and effect layering")
	check(summary.gpu.median_main_draw_ms<summary.cpu.median_main_draw_ms,"GPU path reduces main drawing cost in alternating identical-scene blocks")
	check(count_before==[game.combat.enemies.size(),game.combat.bullets.size(),game.player.parts.size(),game.combat.rng.state],"Render comparison leaves actors, bullets, loadout and RNG unchanged")
	for mode in pictures:pictures[mode].save_png("res://artifacts/render-snapshot-"+mode+"-20261025.png")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"renderer":RenderingServer.get_video_adapter_name(),"scope":"Frozen real main-scene snapshot, alternating CPU/GPU/GPU/CPU draw submission. No simulation, not gameplay FPS or a whole-change before/after comparison.","counts":count_before.slice(0,3),"blocks":blocks,"costs":summary,"mean_channel_error_255":mean_error,"changed_channel_fraction":changed_fraction}
	FileAccess.open("res://artifacts/render-snapshot-20261025.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	game.cursor_system.shutdown();game.particle_effects.clear();game.queue_free();await process_frame;await process_frame;quit(0 if report.passed else 1)
