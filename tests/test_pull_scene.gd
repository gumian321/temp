extends "res://tests/test_centipede_scene.gd"
func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.test_mode=false;game.save.state.settings.skip_boss=true
	game.start_run();game.set_process(false)
	game.run.timers={"swarm":999.0,"wave":999.0,"patrol":999.0}
	var metrics={}
	var initial_weapon=game.player.hq_weapon
	for mode in ["tendril","spider","vortex"]:
		game.combat.enemies.clear();game.combat.bullets.clear();game.combat.effects.clear()
		game.combat.special.black_holes.clear();game.combat.insect_controls.clear()
		game.combat.insect_control_system.released.clear()
		game.player.configure_character("spider" if mode=="spider" else "centipede")
		game.player.hq_weapon=game.db.named("Core_Gun_Tesla").id if mode=="tendril" else initial_weapon
		game.combat.character_abilities.reset()
		for part in game.player.parts:part.cooldown=999.0
		game.zoom=2.2;game.camera=game.player.head+Vector2(100,0)
		var enemy:Dictionary=game.combat.spawn(game.db.pool["250"],game.player.head+Vector2(250,0))
		enemy.kind="AISwarmingUnit";enemy.guns=[];enemy.components=[];enemy.unit={"canBeStunned":true}
		enemy.movement={};enemy.angle=PI;enemy.brood_species="grub";enemy.radius=32.0
		enemy.hp=10000.0;enemy.max_hp=10000.0;enemy.warp=0.0
		game.insect_layer.sync(game,1.0/60)
		await capture("pull-"+mode+"-before")
		if mode=="tendril":game.combat.fire(game.db.named("Core_Gun_Tesla"),game.player.head,Vector2.RIGHT,true,{},0,false,0,1,"player:0")
		elif mode=="spider":check(game.combat.request_skill(enemy.position),"Actual spider skill activates")
		else:game.combat.special.black_holes.append({"position":game.player.head,"radius":400.0,"life":0.8,"damage":0.0,"shield_damage":0.0,"friendly":true,"force":120.0})
		var shape_change=0.0;var appendage_change=0.0;var largest_step=0.0;var signs={}
		var release_seen=false
		var emitter_forward=0.0;var emitter_backward=0.0
		for frame in 300:
			var previous=Vector2(enemy.position)
			game.test_time+=1.0/60;game.player.motion.elapsed+=1.0/60
			game.combat.step(1.0/60,game.player.head+Vector2.RIGHT*600,false,false)
			game.insect_layer.sync(game,1.0/60)
			var emitter=game.combat.character_abilities.emitter_pose if mode=="spider" else game.combat.insect_control_system.emitter_pose("player:0",int(game.player.parts[0].get("insect_source_token",0)))
			var offset=Vector2(emitter.get("offset",Vector2.ZERO))
			emitter_forward=maxf(emitter_forward,offset.x);emitter_backward=minf(emitter_backward,offset.x)
			largest_step=maxf(largest_step,previous.distance_to(enemy.position))
			if enemy.soft_body.has("pull_strain") and game.insect_layer.rigs.has(enemy.uid):
				var rig=game.insect_layer.rigs[enemy.uid]
				var strain=float(enemy.soft_body.pull_strain);var bend=float(enemy.soft_body.pull_bend)
				var deformed=rig.bones[0].position.distance_to(rig.bones[14].position)
				var antenna=float(rig.feelers[0].node.rotation)
				signs[signf(bend)]=true
				enemy.soft_body.pull_strain=0.0;enemy.soft_body.pull_bend=0.0;rig.pose(0)
				shape_change=maxf(shape_change,absf(deformed-rig.bones[0].position.distance_to(rig.bones[14].position)))
				appendage_change=maxf(appendage_change,absf(antenna-rig.feelers[0].node.rotation))
				enemy.soft_body.pull_strain=strain;enemy.soft_body.pull_bend=bend;rig.pose(0)
			if frame in [12,28,65]:await capture("pull-"+mode+"-%02d"%frame)
			var released=game.combat.character_abilities.released_threads if mode=="spider" else game.combat.insect_control_system.released
			if not released.is_empty():
				release_seen=true
				if frame in [22,26,32,124,130,134]:await capture("pull-"+mode+"-recoil-%d"%frame)
		check(shape_change>.08,"Actual "+mode+" stretches the rendered body internally")
		check(appendage_change>.1 and signs.has(-1.0) and signs.has(1.0),"Actual "+mode+" visibly struggles and whips antennae in alternating directions")
		check(largest_step<5,"Actual "+mode+" moves continuously")
		check(not enemy.soft_body.has("pull_strain"),"Actual "+mode+" recovers after release")
		if mode!="vortex":
			check(emitter_forward>11 and emitter_backward<-5,"Actual "+mode+" source organ visibly stretches forward then recoils backward")
			check(release_seen,"Actual "+mode+" keeps a visible recoil curve after detachment")
			check(game.combat.character_abilities.released_threads.is_empty() and game.combat.insect_control_system.released.is_empty(),"Actual "+mode+" cleans up all released ropes")
		metrics[mode]={"shape_change":shape_change,"antenna_radians":appendage_change,"largest_step":largest_step,"emitter_forward":emitter_forward,"emitter_backward":emitter_backward}
		await capture("pull-"+mode+"-released")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.process_mode=Node.PROCESS_MODE_DISABLED
	game.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"captures":captures,"metrics":metrics,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/pull-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
