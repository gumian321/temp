extends "res://tests/test_centipede_scene.gd"
const Art=preload("res://scripts/insect_projectiles.gd")
const FX=preload("res://scripts/weapon_fx.gd")
const FAMILIES=["gatling","shotgun","cannon","flak","rocket","nuke","emp","blackhole","sonic"]
class Board extends Node2D:
	var fx=FX.new()
	var font=load("res://assets/fonts/NotoSansSC-Light.otf")
	func world(point:Vector2)->Vector2:return point
	func _draw():
		draw_rect(Rect2(0,0,1440,900),Color("f5f2e7"))
		draw_string(font,Vector2(40,50),"敌弹辨识 · 深红轮廓 / 浅色隔离边 / 指向尾迹",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("173b70"))
		for row in 3:
			var zoom=[0.5,1.0,1.5][row]
			var y=150+row*245
			draw_string(font,Vector2(35,y-30),"缩放 %.1f · 上排我方 / 下排敌方"%zoom,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("173b70"))
			for col in FAMILIES.size():
				var x=105+col*155
				for friendly in [true,false]:
					var at=Vector2(x,y+(0 if friendly else 90))
					var b={"position":at,"origin":at-Vector2(100,0),"velocity":Vector2(600,0),"friendly":friendly,"fx_family":FAMILIES[col],"radius":4,"data":{}}
					# Exhaust decorative budget: hostile bodies/tails must still show.
					fx.draw_count=FX.MAX_PROJECTILES
					fx.paint_projectile(self,b,1,zoom)

func capture(label:String):
	game.queue_redraw();await process_frame;await process_frame
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var path="res://artifacts/"+label+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"Captured "+label)
	captures.append(path)

func execute():
	for family in FAMILIES:
		for zoom in [.4,.6,1.0,1.8]:
			for direction in [Vector2.RIGHT,Vector2.UP,Vector2(-1,1).normalized()]:
				var bullet={"position":Vector2(100,100),"origin":Vector2(100,100)-direction*50,"velocity":direction*650,"radius":4,"friendly":false,"fx_family":family,"data":{}}
				var before=bullet.duplicate(true)
				var cue=Art.hostile_geometry(bullet,zoom)
				check(cue.size.x>=22 and cue.size.y>=14 and cue.tail>0 and cue.tail<=34,"Visible hostile size and bounded trail: %s %.1f"%[family,zoom])
				check(Vector2(cue.axis).dot(direction)>.999 and bullet==before,"Cue follows velocity without modifying gameplay")
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
	game.save.state.settings.skip_boss=true;game.start_run();game.set_process(false)
	game.combat.enemies.clear();game.combat.bullets.clear();game.combat.effects.clear()
	for name in ["Core_Gun_SonicWave","Core_Gun_Cannon","Core_Gun_Tesla"]:game.player.append_segment(game.db.named(name).id)
	game.camera=Vector2(-70,0);game.zoom=1.0
	for i in 28:
		var at=Vector2(-430+(i%7)*112,-165+(i/7)*110)
		var direction=at.direction_to(game.player.head)
		var bullet={"position":at,"previous":at-direction*20,"origin":at-direction*70,"velocity":direction*600,"radius":4,"friendly":i%3==0,"fx_family":FAMILIES[i%FAMILIES.size()],"data":{}}
		game.combat.bullets.append(bullet)
		if i%2==0:game.combat.effects.append({"position":at,"kind":"explosion","radius":100,"life":.3,"fx_duration":.7,"friendly":true,"fx_family":"cannon"})
	var bullet=game.combat.bullets[1].duplicate(true)
	await capture("hostile-bullets-combat")
	check(game.combat.bullets[1]==bullet,"Rendering preserves hostile projectile state")
	var layer=CanvasLayer.new();layer.layer=100;root.add_child(layer);layer.add_child(Board.new())
	await capture("hostile-bullets-comparison")
	layer.queue_free();game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.process_mode=Node.PROCESS_MODE_DISABLED;game.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"captures":captures,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/hostile-readability-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
