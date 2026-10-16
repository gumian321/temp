extends "res://tests/test_centipede_scene.gd"
func enemy(at:Vector2,hp:float=100.0)->Dictionary:
	var e:Dictionary=game.combat.spawn(game.db.pool["250"],at)
	e.kind="AISwarmingUnit";e.guns=[];e.components=[];e.unit={};e.warp=0.0;e.hp=hp;e.max_hp=100.0;e.radius=15.0;e.role="swarm"
	return e
func bar(uid:int)->Dictionary:
	for item in game.enemy_health_layer.bars:
		if item.uid==uid:return item
	return {}
func capture(label:String):
	game.insect_layer.sync(game,0)
	game.queue_redraw();game.enemy_health_layer.queue_redraw()
	await process_frame;await process_frame
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var path="res://artifacts/"+label+".png"
	var image=root.get_texture().get_image()
	check(image.save_png(path)==OK,"Captured "+label)
	if label=="enemy-health-01-fractions":
		for item in game.enemy_health_layer.bars:
			var rect:Rect2=item.rect
			var filled=rect.position+Vector2(1,1)
			var expected=game.enemy_health_layer.LOW if item.ratio<=.25 else game.enemy_health_layer.HEALTH
			check(image.get_pixelv(Vector2i(filled)).is_equal_approx(expected),"Native pixel contains health fill at the enemy's screen anchor")
			if item.ratio<1:
				check(image.get_pixelv(Vector2i(rect.position+Vector2(rect.size.x-2,1))).is_equal_approx(game.enemy_health_layer.EMPTY),"Native pixel shows empty HP at the unfilled end")
	captures.append(path)
func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.save.state.settings.skip_boss=true;game.start_run();game.set_process(false)
	game.combat.enemies.clear();game.combat.bullets.clear();game.combat.effects.clear()
	game.camera=Vector2.ZERO;game.zoom=1.0
	var layer=game.enemy_health_layer
	check(layer.z_index==100,"Health draws above combat particles")
	var targets:Array=[]
	for i in 3:targets.append(enemy(Vector2(-250+i*250,-100),[100.0,50.0,5.0][i]))
	layer.rebuild()
	for i in 3:
		check(is_equal_approx(float(bar(targets[i].uid).get("ratio",-1)),[1.0,.5,.05][i]),"Exact HP fraction %d%%"%[100,50,5][i])
	await capture("enemy-health-01-fractions")
	check(layer.get_global_transform_with_canvas().is_equal_approx(Transform2D.IDENTITY),"Health screen-space coordinates are not transformed a second time by world camera")
	var shield:Dictionary=game.db.named("Core_Shield")
	targets[1].guns=[{"id":shield.id,"shield":float(shield.maxShieldHealth)*.75,"angle":0.0,"cooldown":999.0,"offset":Vector2.ZERO}]
	layer.rebuild()
	check(is_equal_approx(bar(targets[1].uid).shield,.75) and is_equal_approx(bar(targets[1].uid).ratio,.5),"Shield and HP remain separate fractions")
	var nearby=enemy(targets[1].position+Vector2(70,40),30)
	nearby.role="patrol";layer.rebuild()
	check(bar(nearby.uid).shield>0,"Shield covers other hostile roles exactly as combat does")
	targets[1].stun=1.0;layer.rebuild()
	check(is_zero_approx(bar(nearby.uid).shield),"Stunned source provides no shield strip")
	targets[1].stun=0.0
	var boss=enemy(Vector2(0,140));boss.kind="AIBossUnit";boss.damageable=false;boss.radius=45
	var part=enemy(Vector2(-100,200),25);part.parent=boss.uid
	var part2=enemy(Vector2(100,200),75);part2.parent=boss.uid
	boss.parts=[part.uid,part2.uid];boss.max_hp=200.0
	game.combat.step(0.0,game.player.head,false,false)
	layer.rebuild()
	check(is_equal_approx(bar(boss.uid).ratio,.5),"Invulnerable boss controller aggregates child HP")
	await capture("enemy-health-02-shield-boss")
	part.hp=0.0
	game.combat.step(0.0,game.player.head,false,false);layer.rebuild()
	check(is_equal_approx(bar(boss.uid).ratio,.375) and boss.max_hp==200.0,"Destroyed boss part does not shrink original maximum or refill boss bar")
	for state in ["pause","result","rewards"]:
		game.screen=state;layer.rebuild();check(not layer.bars.is_empty(),"Bars persist in "+state)
	for state in ["home","build"]:
		game.screen=state;layer.rebuild();check(layer.bars.is_empty(),"Bars clear in "+state)
	game.screen="game";game.radar_mode=true;layer.rebuild();check(layer.bars.is_empty(),"Tactical radar clears world bars")
	game.radar_mode=false
	var far=enemy(Vector2(10000,10000));layer.rebuild();check(bar(far.uid).is_empty(),"Offscreen enemies culled")
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution;root.content_scale_size=resolution;await process_frame
		for zoom in [.5,1.0,1.8]:
			game.zoom=zoom;game.sync_camera_layers();layer.rebuild()
			check(layer.get_global_transform_with_canvas().is_equal_approx(Transform2D.IDENTITY),"Screen-space canvas remains identity at zoom %.1f"%zoom)
			check(not bar(targets[1].uid).is_empty() and bar(targets[1].uid).rect.size==Vector2(48,6),"Fixed readable size at %s zoom %.1f"%[resolution,zoom])
	root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900);game.zoom=1.0;await process_frame
	game.combat.enemies.clear()
	for i in 180:enemy(Vector2(-480+(i%18)*55,-200+(i/18)*45),float([100,50,5][i%3]))
	var begin=Time.get_ticks_usec()
	for i in 20:layer.rebuild()
	var rebuild_ms=(Time.get_ticks_usec()-begin)/20000.0
	check(layer.bars.size()>100,"Dense field retains visible bars")
	check(rebuild_ms<30,"Dense 180-enemy layout stays within a bounded CPU budget")
	await capture("enemy-health-03-dense")
	var timings={}
	for count in [64,128,384,768]:
		game.combat.enemies.clear()
		for i in count:enemy(Vector2(-500+(i%32)*32,-260+(i/32)*22))
		begin=Time.get_ticks_usec()
		for sample in 20:layer.rebuild()
		timings[str(count)]=(Time.get_ticks_usec()-begin)/20000.0
		check(timings[str(count)]<50,"Bounded rebuild CPU for %d enemies"%count)
	game.combat.enemies.clear()
	for i in 4:enemy(Vector2.ZERO,25.0*(i+1))
	layer.rebuild()
	var lifted=false
	for item in layer.bars:lifted=lifted or item.rect.position!=item.anchor
	check(lifted,"Overlapping enemies receive bounded bar lifts")
	await capture("enemy-health-04-overlap")
	game.combat.enemies.clear()
	for row in 3:
		for column in 6:
			var specimen=enemy(Vector2(-450+column*180,-180+row*180),float([100,50,5][row]))
			specimen.brood_species=["grub","beetle","moth","sac","mantis","queen"][column]
			specimen.radius=[15.0,24.0,20.0,28.0,30.0,45.0][column]
			if column==5:specimen.kind="AIBossUnit"
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution;root.content_scale_size=resolution;game.zoom=.8 if resolution.x==1280 else 1.0
		await process_frame
		await capture("enemy-health-species-%d"%resolution.x)
	var draw_calls={}
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		draw_calls.enabled=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		layer.hide();await process_frame;await process_frame;await RenderingServer.frame_post_draw
		draw_calls.disabled=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		layer.show()
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.process_mode=Node.PROCESS_MODE_DISABLED
	game.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"captures":captures,"dense_rebuild_ms":rebuild_ms,"rebuild_timings_ms":timings,"draw_calls":draw_calls,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/enemy-health-scene-"+("headless" if DisplayServer.get_name()=="headless" else "native")+"-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
