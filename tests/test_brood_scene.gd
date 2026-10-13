extends SceneTree
const Brood=preload("res://scripts/brood_theme.gd")
const Soft=preload("res://scripts/soft_insect.gd")
const Rig=preload("res://scripts/soft_insect_rig.gd")
var checks:Array=[]
var actors:Array=[]
var rigs:Array=[]
class Board extends Node2D:
	var font:Font=load("res://assets/fonts/NotoSansSC-Light.otf")
	var impact=false
	var motion=false
	var stage=""
	func _draw():
		draw_rect(Rect2(0,0,1440,900),Color("f6f2e7"))
		if motion:
			draw_string(font,Vector2(48,49),"虫群 · 软腹、关节足与独立翅片",HORIZONTAL_ALIGNMENT_LEFT,-1,29,Color("173b70"))
			draw_string(font,Vector2(48,83),stage,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("6984a4"))
			var labels=["褶腹幼虫","钳角甲虫","绒翅飞蛾","泡囊虫","镰臂虫","母巢虫后"]
			var details=["抬足收膝 · 腹节传递","甲足大步 · 受击后仰","大幅扇翅 · 翅根反冲","囊腹压扁 · 拍击回弹","镰臂大摆 · 三节关节","六足支撑 · 厚腹甩动"]
			for i in range(6):
				var p=Vector2(80+(i%3)*465,465+(i/3)*378)
				draw_string(font,p,labels[i],HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("173b70"))
				draw_string(font,p+Vector2(0,25),details[i],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("6984a4"))
			return
		draw_string(font,Vector2(48,49),"蜈蚣 · 生体武装与软体虫群",HORIZONTAL_ALIGNMENT_LEFT,-1,29,Color("173b70"))
		draw_string(font,Vector2(48,80),"米白甲壳 / 蓝墨虫怪 / 局部受击 → 传递 → 回弹",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("6984a4"))
		var names=["骨壳炮","刺管连射","双腔霰弹","针刺狙击","种荚火箭","散刺炮","焰囊喷口","电角","脉冲腺","鸣螺","涡眼","裂变种","孢雷巢"]
		var ids=["cannon","gatling","shotgun","sniper","rocket","flak","flame","tesla","emp","sonic","blackhole","nuke","mine"]
		for i in ids.size():
			var x=55+i*104
			var texture=Brood.weapon_texture(ids[i])
			var size=texture.get_size()*minf(72.0/texture.get_width(),125.0/texture.get_height())
			draw_texture_rect(texture,Rect2(Vector2(x+38,167)-size/2,size),false)
			draw_string(font,Vector2(x,256),names[i],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("173b70"))
		draw_line(Vector2(48,280),Vector2(1392,280),Color("bacadb"),1)
		var labels=["褶腹幼虫 · 软弹","钳角甲虫 · 紧实","绒翅飞蛾 · 翅腹滞后","泡囊虫 · 柔软","镰臂虫 · 轻快","母巢虫后 · 厚重"]
		for i in labels.size():
			var p=Vector2(95+(i%3)*465,540+(i/3)*302)
			draw_string(font,p,labels[i],HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("173b70"))
		draw_string(font,Vector2(50,883),"受击演示：左侧命中，身体局部压缩后回弹" if impact else "待机呼吸与触须摆动 · 实际 Godot 网格渲染",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("6984a4"))
func _initialize():call_deferred("execute")
func check(value:bool,title:String):
	checks.append({"name":title,"passed":value})
	if not value:printerr("FAIL: ",title)
func shot(path:String):
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(path)==OK,"Capture "+path)
func execute():
	root.size=Vector2i(1440,900)
	if DisplayServer.get_name()=="headless":printerr("Render test requires --render");quit(1);return
	var board=Board.new();root.add_child(board)
	for i in Brood.SPECIES.size():
		var e={"uid":i+1,"kind":"AISwarmingUnit","position":Vector2.ZERO,"angle":-PI/2,"hp":100.0,"max_hp":100.0,"radius":50.0,"brood_species":Brood.SPECIES[i]}
		var rig=Rig.new();board.add_child(rig);rig.setup(e)
		rig.position=Vector2(250+(i%3)*465,414+(i/3)*302)
		rig.scale=Vector2.ONE*105
		rig.pose(0);actors.append(e);rigs.append(rig)
	await shot("res://artifacts/brood-lineup.png")
	board.motion=true
	for i in rigs.size():
		rigs[i].position=Vector2(250+(i%3)*465,283+(i/3)*378)
		rigs[i].scale=Vector2.ONE*145
	DirAccess.make_dir_recursive_absolute("res://artifacts/brood-frames")
	for frame in range(300):
		var walking=frame<90 or (frame>=150 and frame<240)
		board.stage="行走：抬脚、收膝、大幅扇翅，腹节跟随步态摆动" if walking else "停步：腹部呼吸，触须轻摆，飞蛾持续扇翅"
		if frame in [108,204]:
			for e in actors:Soft.impact(e,e.position+Vector2(-28,12),Vector2.RIGHT,20,"cannon")
		if (frame>=108 and frame<145) or (frame>=204 and frame<240):board.stage="命中：立即压扁 → 短暂停住 → 后仰、飞溅 → 抖动回弹"
		board.queue_redraw()
		for i in actors.size():
			if walking:actors[i].position+=Vector2(0,-.65)
			Soft.step(actors[i],1.0/60);rigs[i].pose(1.0/60)
		await process_frame
		if frame%2==0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg("res://artifacts/brood-frames/frame-%03d.jpg"%frame,0.91)
		if frame==108:await shot("res://artifacts/brood-impact.png")
		if frame==120:await shot("res://artifacts/brood-rebound.png")
	board.queue_free();await process_frame
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.test_mode=false
	game.save.state.settings.skip_boss=true
	game.start_run();game.show_game();game.camera_focus.clear()
	game.combat.enemies.clear();game.combat.drones.clear();game.combat.bullets.clear()
	game.tutorials.visible=false
	for name in ["Core_Gun_Cannon","Core_Gun_Tesla","Core_Gun_Shotgun","Core_Gun_Flame Thrower"]:game.player.append_segment(game.db.named(name).id)
	for frame in range(140):game.player.step(1.0/60,Vector2.from_angle(-0.5+frame*0.005),false)
	game.camera=game.player.head+Vector2(70,0);game.zoom=1.25
	for i in range(6):
		var e=game.combat.spawn(game.db.pool["250"],game.player.head+Vector2(160+(i%3)*120,-140+(i/3)*220))
		e.brood_species=Brood.SPECIES[i];e.radius=26 if i!=5 else 48;e.angle=(game.player.head-e.position).angle()
		Soft.impact(e,e.position-Vector2(10,0),Vector2.RIGHT,15);Soft.step(e,0.06)
	game.insect_layer.sync(game,0)
	game.queue_redraw()
	await shot("res://artifacts/brood-in-game.png")
	check(game.insect_layer.rigs.size()==6,"All six new insects render through the real game layer")
	game.radar_mode=true;game.insect_layer.sync(game,0)
	check(not game.insect_layer.visible,"World insect meshes hide while the full radar is open")
	game.radar_mode=false;game.insect_layer.sync(game,0)
	var dying=game.combat.enemies[0]
	dying.hp=0;game.combat.enemies.erase(dying)
	game.insect_layer.sync(game,0.1)
	check(game.insect_layer.rigs.has(dying.uid),"Killed insect retains a brief soft collapse")
	game.insect_layer.sync(game,0.3)
	check(not game.insect_layer.rigs.has(dying.uid),"Death rig is freed after collapse")
	game.screen="build";game.insect_layer.sync(game,0)
	check(not game.insect_layer.visible,"No enemy meshes leak into build screen")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear()
	game.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/brood-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
