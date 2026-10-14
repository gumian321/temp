extends "res://tests/test_centipede_scene.gd"
const Organs=preload("res://scripts/soft_organ_art.gd")
const Art=preload("res://scripts/insect_armaments.gd")
const Body=preload("res://scripts/chain_centipede.gd")
const Battle=preload("res://scripts/combat.gd")
class Board extends Node2D:
	var organs=Organs.new()
	var font=load("res://assets/fonts/NotoSansSC-Light.otf")
	var benchmark=false
	var timings:Array=[]
	var entries=["sonic","cannon","shotgun","sniper","flame","drone_bay"]
	func _draw():
		organs.begin_frame()
		if benchmark:
			var started=Time.get_ticks_usec()
			for i in 60:
				var variant=entries[i%entries.size()]
				organs.paint(self,"load:"+str(i),Art.texture(variant),Vector2(80+i%10*130,100+i/10*110),Vector2.ONE*56,0,variant,timings.size()/60.0,.18,Color.WHITE,float(i))
			timings.append(Time.get_ticks_usec()-started)
			return
		draw_rect(Rect2(0,0,1440,900),Color("f5f2e7"))
		draw_string(font,Vector2(40,45),"虫体元素 · 局部软体动画",HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("173b70"))
		for row in entries.size():
			var variant=entries[row]
			draw_string(font,Vector2(35,150+row*130),Art.entries()[variant].zh,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("173b70"))
			for col in 4:
				var at=Vector2(330+col*290,132+row*130)
				var clock=[0.0,0.72,0.72,0.83][col]
				var pulse=[0.0,0.0,0.18,0.07][col]
				organs.paint(self,"%d:%d"%[row,col],Art.texture(variant),at,Vector2(130,100),0,variant,clock,pulse)
				if row==0:draw_string(font,at+Vector2(-60,-65),["待机 A","待机 B","发射 / 振翅","回弹"][col],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("173b70"))

func execute():
	var db=preload("res://scripts/source_db.gd").new()
	var variants=Art.entries().keys()
	for variant in variants:
		var moving=false;var bounded=true;var no_fold=true
		for frame in 24:
			var clock=frame*0.071
			var pulse=0.18 if frame%3==0 else 0.0
			for row in range(8):
				for col in range(8):
					var uv=Vector2(col/8.0,row/8.0)
					var p=Organs.deform(uv,variant,clock,pulse)
					var right=Organs.deform(uv+Vector2(0.125,0),variant,clock,pulse)
					var down=Organs.deform(uv+Vector2(0,0.125),variant,clock,pulse)
					bounded=bounded and p.is_finite() and p.length()<1.1
					no_fold=no_fold and (right-p).cross(down-p)>0
			moving=moving or Organs.deform(Vector2(.9,.3),variant,clock,0).distance_to(Organs.deform(Vector2(.9,.3),variant,0,0))>0.005
		check(moving and bounded and no_fold,"Distinct bounded idle deformation with no inverted mesh cells: "+variant)
		check(Organs.deform(Vector2(.5,1),variant,0.2,0.18)==Vector2(0,.5),"Mounted root stays pinned: "+variant)
	check(Organs.deform(Vector2(.95,.3),"sonic",0,0).distance_to(Organs.deform(Vector2(.95,.3),"sonic",0.72,0))>0.08,"Butterfly wing tip visibly folds independently of its root")
	check(Organs.deform(Vector2(.8,.4),"cannon",0.3,0.18).distance_to(Organs.deform(Vector2(.8,.4),"cannon",0.3,0))>0.05,"Sac visibly compresses immediately on discharge")
	var p=Body.new(db);var b=Battle.new(db,p)
	var core=db.named("Core_Gun_Rocket");p.append_segment(core.id)
	b.fire(core,p.weapon_origin(1),Vector2.RIGHT,true,{},0,false,0,1,"player:1")
	check(p.parts[1].organ_pulse>0 and p.parts[1].recoil>0,"Actual projectile emission starts mounted recoil and organ animation")
	var shots=int(p.parts[1].organ_shots)
	for frame in 100:
		b.step(.01,Vector2.RIGHT*1000,false)
		if int(p.parts[1].organ_shots)>shots:break
	check(int(p.parts[1].organ_shots)>shots and p.parts[1].organ_pulse>0,"Later barrage rounds retrigger attack animation")
	p=Body.new(db);b=Battle.new(db,p);p.append_segment(db.named("Core_MinesField").id)
	b.special.step(.01)
	check(not b.special.mines.is_empty() and p.parts[1].organ_pulse>0,"Egg release triggers the egg organ contraction")
	p=Body.new(db);b=Battle.new(db,p);core=db.named("Core_Drones_Attack");p.append_segment(core.id)
	b.drones.clear();b.add_drone(1,db.asset(core.coreDrone));b.drones[0].ping=0
	var enemy=b.spawn(db.pool["250"],p.parts[1].position+Vector2(80,0));enemy.warp=0
	b.step_drones(.01)
	check(not b.drones[0].docked and p.parts[1].organ_pulse>0,"Nest contracts when a hunter launches")
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
	game.save.state.settings.skip_boss=true;game.start_run();game.set_process(false)
	game.combat.enemies.clear();game.combat.bullets.clear()
	for name in ["Core_Gun_SonicWave","Core_Gun_Cannon","Core_Gun_Shotgun","Core_Gun_Tesla"]:game.player.append_segment(db.named(name).id)
	game.show_build_ui();await process_frame;await process_frame
	game.build_ui.body_canvas.set_process(false)
	for clock in [0.0,0.4]:
		game.build_ui.body_canvas.clock=clock;game.build_ui.body_canvas.queue_redraw()
		await capture("soft-organ-assembly-"+str(clock))
	game.show_game();game.zoom=2.0;game.camera=Vector2(-110,0)
	game.test_time=0.4
	for part in game.player.parts:part.organ_pulse=.18
	await capture("soft-organ-combat")
	check(game.soft_organs.meshes.size()>=5,"Live HQ and every mounted organ use deformable meshes")
	var sheet=CanvasLayer.new();sheet.layer=100;root.add_child(sheet)
	var board=Board.new();sheet.add_child(board)
	await capture("soft-organ-motion-sheet")
	board.benchmark=true
	for frame in 12:
		board.queue_redraw();await process_frame
	var render_cost=0.0
	if not board.timings.is_empty():
		for cost in board.timings:render_cost+=cost/1000.0
		render_cost/=board.timings.size()
		check(board.organs.meshes.size()==60,"Renderer prunes unused meshes and keeps one per visible organ")
		check(render_cost<50,"Sixty deforming organs stay within bounded CPU drawing budget")
	sheet.queue_free();await process_frame
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.process_mode=Node.PROCESS_MODE_DISABLED;game.queue_free();await process_frame;await process_frame
	var report={"passed":checks.all(func(c):return c.passed),"variants":variants.size(),"sixty_organs_cpu_ms":render_cost,"checks":checks,"captures":captures}
	FileAccess.open("res://artifacts/soft-organ-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
