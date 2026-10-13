extends SceneTree
## Production renderer + real collision events. GUI captures are explicitly skipped headlessly.
var game
var checks:Array=[]
var captures:Array=[]
func _initialize():call_deferred("execute")
func check(ok:bool,title:String):
	checks.append({"name":title,"passed":ok})
	if not ok:printerr("FAIL: ",title)
func picture(name:String):
	game.insect_layer.sync(game,0.016)
	game.queue_redraw();await process_frame
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var path="res://artifacts/insect-attack-"+name+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"Saved "+name)
	captures.append(path)
func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame;game.set_process(false)
	game.save.state.settings.skip_boss=true
	for entry in [["silk","Core_Gun_EMP"],["tendril","Core_Gun_Tesla"]]:
		game.start_run();game.set_process(false)
		game.run.timers={"swarm":999.0,"wave":999.0,"patrol":999.0}
		game.run.rewards.queue.clear();game.run.packs=0
		game.combat.enemies.clear();game.combat.drones.clear()
		game.tutorials.movement_shown=true;game.tutorials.radar_shown=true;game.tutorials.fuel_shown=true
		game.player.hq_weapon=game.db.named(entry[1]).id
		game.player.install_module(game.db.named("Core_Gun_Cannon").id,1,4)
		var enemy=game.combat.spawn(game.db.pool["250"],game.player.head+Vector2(215,-30))
		enemy.guns=[];enemy.warp=0;enemy.mission_controlled=false;enemy.hp=2000;enemy.max_hp=2000
		game.camera=game.player.head+Vector2(70,-5);game.zoom=1.65
		game.label_at("缄鸣 · 活丝缠绕" if entry[0]=="silk" else "雷须 · 蓄电触须牵引",Vector2(480,225),28)
		game.label_at("丝束锚点与虫身束缚 / 末段自然淡出" if entry[0]=="silk" else "弯曲带电纤维 / 拉近目标 / 腹囊回弹",Vector2(478,270),17)
		game.combat.fire(game.db.named(entry[1]),game.player.head,game.player.head.direction_to(enemy.position),true)
		var found=false
		for frame in range(120):
			if game.combat.insect_controls.any(func(e):return e.kind==entry[0]):found=true;break
			game.combat.step(1.0/120.0,enemy.position,false)
		check(found,entry[0]+" control emitted by real combat hit")
		if found:
			game.combat.step(0.045,enemy.position,false)
			game.test_time=1.2;game.player.parts[0].organ_pulse=0.14;game.player.parts[1].organ_pulse=0.14
			await picture(entry[0]+"-active")
			for control in game.combat.insect_controls:control.life=0.07
			game.player.parts[0].organ_pulse=0.04;game.player.parts[1].organ_pulse=0.04
			await picture(entry[0]+"-release")
		game.combat.insect_controls.clear()
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear()
	game.process_mode=Node.PROCESS_MODE_DISABLED
	for i in range(8):await process_frame
	game.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"captures":captures,"headless":DisplayServer.get_name()=="headless","passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/insect-attack-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
