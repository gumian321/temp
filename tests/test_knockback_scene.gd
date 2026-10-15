extends "res://tests/test_centipede_scene.gd"
## Fire the actual sonic projectile through collision, simulation and native rig.
func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.test_mode=false;game.save.state.settings.skip_boss=true
	game.start_run();game.set_process(false)
	game.run.timers={"swarm":999.0,"wave":999.0,"patrol":999.0}
	game.combat.enemies.clear();game.combat.bullets.clear();game.combat.effects.clear()
	var core:Dictionary=game.db.named("Core_Gun_SonicWave")
	game.player.hq_weapon=core.id
	game.player.append_segment(core.id)
	for part in game.player.parts:part.cooldown=999.0
	game.zoom=1.6;game.camera=game.player.head+Vector2(90,0)
	var enemy:Dictionary=game.combat.spawn(game.db.pool["250"],game.player.head+Vector2(190,0))
	enemy.kind="AISwarmingUnit";enemy.guns=[];enemy.components=[];enemy.unit={}
	enemy.movement={"enginePower":1.5,"rotEngineModifier":12.0};enemy.angle=PI
	enemy.hp=10000.0;enemy.max_hp=10000.0;enemy.warp=0.0;enemy.stop_distance=0
	await capture("knockback-00-before")
	game.combat.fire(core,game.player.head,Vector2.RIGHT,true)
	game.player.parts[0].organ_pulse=0.18
	var first_hit=-1
	var samples:Array=[]
	var largest_step=0.0
	var largest_visual_step=0.0
	var before_hit=Vector2(enemy.position)
	var furthest=before_hit.x
	var previous_visual=game.world(enemy.position)
	var rig_matches=true
	var shape_change=0.0
	for frame in 120:
		var previous=Vector2(enemy.position)
		game.test_time+=1.0/60
		game.player.motion.elapsed+=1.0/60
		game.combat.step(1.0/60,game.player.head+Vector2.RIGHT*600,false,false)
		game.insect_layer.sync(game,1.0/60)
		game.queue_redraw();await process_frame
		largest_step=maxf(largest_step,previous.distance_to(enemy.position))
		if first_hit<0 and enemy.hp<10000:
			first_hit=frame;before_hit=previous;furthest=enemy.position.x
			check(previous.distance_to(enemy.position)<2,"First real projectile contact causes no coordinate jump")
		if first_hit>=0:
			furthest=maxf(furthest,enemy.position.x)
			if frame-first_hit in [0,8,20,40,70]:
				await capture("knockback-after-%02d"%(frame-first_hit))
		if game.insect_layer.rigs.has(enemy.uid):
			var rig=game.insect_layer.rigs[enemy.uid]
			if enemy.soft_body.has("push_strain"):
				# Compare the actual bone spacing with/without push at the same pose
				# and clock. Translation/rotation alone cannot pass this check.
				var strain=float(enemy.soft_body.push_strain);var bend=float(enemy.soft_body.push_bend)
				var deformed=rig.bones[0].position.distance_to(rig.bones[14].position)
				enemy.soft_body.push_strain=0.0;enemy.soft_body.push_bend=0.0;rig.pose(0)
				shape_change=maxf(shape_change,absf(deformed-rig.bones[0].position.distance_to(rig.bones[14].position)))
				enemy.soft_body.push_strain=strain;enemy.soft_body.push_bend=bend;rig.pose(0)
			rig_matches=rig_matches and rig.position.distance_to(game.world(enemy.position))<0.01
			largest_visual_step=maxf(largest_visual_step,rig.position.distance_to(previous_visual))
			previous_visual=rig.position
		samples.append({"frame":frame,"x":enemy.position.x,"hp":enemy.hp})
	check(first_hit>=0,"The production sonic projectile actually collides with the target")
	check(largest_step<10 and largest_visual_step<16,"Both collision position and rendered rig travel continuously")
	check(rig_matches,"Rendering follows actual pushed positions with no hidden collision/visual mismatch")
	check(shape_change>.06,"Real projectile knockback changes internal body shape instead of only moving or rotating the rig")
	check(furthest>before_hit.x+40,"A moving pursuer is visibly driven backward")
	check(not enemy.has("knockback_velocity") and enemy.position.x<furthest-25,"The enemy slows, settles and resumes its own pursuit")
	check(game.camera_kick==Vector2.ZERO,"Sonic knockback does not introduce camera shake")
	await capture("knockback-99-pursuit-resumed")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.process_mode=Node.PROCESS_MODE_DISABLED
	game.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"captures":captures,"samples":samples,"largest_step":largest_step,"largest_visual_step":largest_visual_step,"first_hit_frame":first_hit,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/knockback-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
