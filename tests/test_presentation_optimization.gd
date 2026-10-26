extends "res://tests/test_centipede_scene.gd"
class CountedGame extends "res://scripts/main.gd":
	var draw_count=0
	func _draw():
		draw_count+=1;super._draw()
class WorldCover extends Node2D:
	func _draw():draw_rect(Rect2(0,0,3000,2000),Color.MAGENTA)

func settle():
	for i in 3:await process_frame
func execute():
	if DisplayServer.get_name()=="headless":push_error("Presentation optimization checks require --render");quit(1);return
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1440,900)
	game=CountedGame.new();root.add_child(game);await settle();game.set_process(false)
	game.save.fresh();game.save.state.settings.skip_boss=true
	var idle:Array=[]
	for name in ["home","missions","options","research"]:
		match name:
			"home":game.show_menu()
			"missions":game.show_missions()
			"options":game.show_options()
			"research":game.show_lab()
		game._process(0);await settle()
		var before=game.draw_count
		for frame in 30:game._process(1.0/60);await process_frame
		idle.append({"screen":name,"world_redraws_in_30_ticks":game.draw_count-before})
		check(game.draw_count==before,"Static "+name+" does not rebuild hidden world drawing")
		check(not game.menu_background.visible and not game.background_renderer.visible,"Static "+name+" hides covered legacy ships and fullscreen terrain shader")
		if name=="home":check(game.panel.get_node("HomeSpecimen").clock>0,"Homepage specimen animation keeps its independent clock")
	game.start_run();game.set_process(false);game.run.packs=0;game.player.pending.clear();game.show_game()
	game._process(.016);await settle()
	game.show_pause();game._process(0);await settle()
	var before=game.draw_count;var clock_before=game.test_time
	for frame in 20:game._process(1.0/60);await process_frame
	check(game.draw_count==before and game.test_time==clock_before,"Paused combat retains its image without advancing organ or world clocks")
	game.show_game();game._process(.016);await settle()
	check(game.draw_count>before and game.test_time>clock_before,"Resuming immediately restores animated world rendering")
	for size in [Vector2i(800,600),Vector2i(1440,900),Vector2i(2560,1080)]:
		root.size=size;await settle();game.queue_redraw();await settle()
		check(game.center==Vector2(size)*.5,"Resize centres the actual battlefield at "+str(size))
		var rect=game.tactical_radar.bounds(Vector2(size))
		check(root.get_visible_rect().encloses(rect),"Radar stays inside "+str(size))
		check(rect.size==Vector2(144,120) if size.x==800 else rect.size==Vector2(180,150),"Radar uses the intended compact/full size at "+str(size))
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var reference=root.get_texture().get_image()
			var cover=WorldCover.new();cover.z_index=4095;game.add_child(cover);await settle();await RenderingServer.frame_post_draw
			var actual=root.get_texture().get_image();var stable=true
			if size.x==800:actual.save_png("res://artifacts/radar-cover-diagnostic.png")
			for y in range(int(rect.position.y)+18,int(rect.end.y)-18,4):
				for x in range(int(rect.position.x)+18,int(rect.end.x)-18,4):
					stable=stable and reference.get_pixel(x,y)==actual.get_pixel(x,y)
			check(stable,"Radar remains readable above world effects at "+str(size))
			cover.queue_free();await settle()
			await capture("optimized-battle-"+str(size.x)+"x"+str(size.y))
	game.show_menu();game._process(0);await settle()
	check(game.soft_organs.gpu.items.is_empty(),"Returning home releases all mounted GPU canvas items")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"idle":idle,"captures":captures}
	FileAccess.open("res://artifacts/presentation-optimization-20261025.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle();quit(0 if report.passed else 1)
