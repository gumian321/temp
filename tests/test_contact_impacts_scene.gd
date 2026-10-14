extends "res://tests/test_centipede_scene.gd"
const Feedback=preload("res://scripts/weapon_feedback.gd")
## Same real projectile, two powers and opposite off-center strike heights.
func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.test_mode=false;game.save.state.settings.skip_boss=true
	game.start_run();await process_frame
	game.run.timers={"swarm":999.0,"wave":999.0,"patrol":999.0}
	game.combat.enemies.clear();game.combat.drones.clear()
	game.tutorials.movement_shown=true;game.tutorials.radar_shown=true;game.tutorials.fuel_shown=true
	game.zoom=2.3;game.camera=game.player.head+Vector2(155,0)
	var targets:Array=[]
	for i in range(2):
		var target=game.combat.spawn(game.db.pool["250"],game.player.head+Vector2(160,-75+150*i))
		target.guns=[];target.mission_controlled=true;target.hp=10000;target.max_hp=10000
		targets.append(target)
		game.combat.fire(game.db.named("Core_Gun_Gatling"),target.position+Vector2(-110,9 if i==0 else -9),Vector2.RIGHT,true)
		var bullet=game.combat.bullets.back()
		bullet.position=target.position+Vector2(-110,9 if i==0 else -9)
		bullet.previous=bullet.position;bullet.origin=bullet.position;bullet.velocity=Vector2(8000,0)
		bullet.damage=2.0 if i==0 else 100.0;bullet.shield_damage=bullet.damage
	game.combat.effects.clear()
	game.combat.step(0.025,game.player.head+Vector2.RIGHT*500,false)
	var hits=game.combat.effects.filter(func(e):return e.kind=="hit")
	check(hits.size()==2,"Real fast projectile step generates both weak and heavy contacts")
	if hits.size()==2:
		check(hits[1].radius>hits[0].radius*2,"Production weak/heavy impact sizes differ by more than two times")
		for i in range(2):
			check(absf(hits[i].position.distance_to(targets[i].position)-targets[i].radius)<0.01,"Contact %d hugs the actual target rim"%i)
			check((hits[i].position.y-targets[i].position.y)*(1 if i==0 else -1)>0,"Contact %d preserves off-center aim height"%i)
			hits[i].life=hits[i].fx_duration*0.83
	game.label_at("轻弹 · 2 伤害",Vector2(660,203),22)
	game.label_at("重弹 · 100 伤害",Vector2(660,645),22)
	await capture("contact-impacts-weak-heavy")
	for hit in hits:hit.life=hit.fx_duration*0.5
	await capture("contact-impacts-shards")
	game.combat.step(0.3,game.player.head+Vector2.RIGHT*500,false)
	check(game.combat.effects.all(func(e):return e.kind not in ["hit","shield_hit"]),"All contact feedback expires promptly")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.process_mode=Node.PROCESS_MODE_DISABLED
	for i in range(12):OS.delay_msec(10);await process_frame
	game.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"captures":captures,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/contact-impacts-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
