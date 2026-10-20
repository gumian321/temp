extends "res://tests/test_centipede_scene.gd"
var boss
func settle():
	for i in 4:await process_frame
func capture(label:String):
	game.sync_camera_layers();game.insect_layer.sync(game,0);game.queue_redraw();game.battle_hud.refresh()
	await settle()
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var path="res://artifacts/polish-"+label+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"Native capture "+label);captures.append(path)
func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
	game.set_process(false);game.test_mode=true;game.save.fresh();game.start_run();await settle()
	game.tutorials.visible=false;game.run.timers={"swarm":999,"wave":999,"patrol":999}
	game.combat.enemies.clear();game.combat.effects.clear();game.combat.loot.clear();game.combat.bullets.clear()
	game.camera=Vector2.ZERO;game.zoom=1;game.center=Vector2(720,450)
	game.player.append_segment(game.db.named("Core_Gun_Flame Thrower").id)
	game.player.parts[1].fusion_level=4;game.player.refresh_upgrades()
	for i in 45:game.player.step(1.0/60,Vector2.ZERO,false)
	check(game.player.flagella.poses(int(game.player.parts[1].feedback_uid)).size()==6,"Actual game tier-four segment carries six flagella")
	var index=0
	for key in game.db.pool:
		var prefab=game.db.prefabs.get(game.db.pool[key],{})
		if not str(prefab.get("name","")).begins_with("Object_Container_"):continue
		var e=game.combat.spawn(game.db.pool[key],Vector2(-350+index*125,-170));e.warp=0;index+=1
	game.combat.loot.append({"position":Vector2(-280,140),"value":0,"pack":true,"rarity":2})
	game.combat.loot.append({"position":Vector2(-160,140),"value":5,"pack":false})
	game.run.map_director.nodes[Vector2(999,999)]={"position":Vector2(360,-100),"center_sprite":"unused-test-placeholder","members":[],"objectives":[],"key":Vector2(999,999)}
	boss=game.combat.spawn(game.db.pool["250"],Vector2(6000,-1800));boss.kind="AIBossUnit";boss.warp=0;boss.guns=[]
	for i in 8:
		var at=Vector2(-420+i*115,-290)
		game.combat.bullets.append({"position":at,"previous":at-Vector2(12,0),"origin":at-Vector2(60,0),"velocity":Vector2(400,0),"friendly":false,"fx_family":["gatling","cannon","rocket","sonic"][i%4],"radius":4,"data":{},"age":.2,"life":3.0})
	var emitter=game.player.weapon_origin(1)
	var core=game.db.named("Core_Gun_Flame Thrower")
	for i in 45:game.combat.special.continuous(core,emitter,Vector2(.9,-.4).normalized(),true,{},0,1.0/60,"player:1")
	await capture("world-and-weapons")
	check(game.material==null,"Colored weapons keep their original palette")
	var latest=game.combat.effects.filter(func(e):return e.kind=="flame")
	check(latest.size()==1 and latest[0].curve.size()==25,"Each flame owner has one continuous curved ribbon, never a row of bullets")
	# Force the real fatal-hit path and confirm delayed UI with one recorded result.
	game.combat.enemies.clear();game.run.map_director.nodes.erase(Vector2(999,999));game.combat.bullets.clear();game.combat.effects.clear()
	game.combat.fire(game.db.named("Core_Gun_Gatling"),Vector2(-200,-150),Vector2.RIGHT,true)
	game.combat.hurt_player(0,100000,100000)
	game._process(.001)
	check(game.death_transition.active and game.screen=="game" and game.run.finished,"Fatal hit starts slow aftermath before entering result screen")
	var awarded=game.save.state.meta
	var bullet=game.combat.bullets[0] if not game.combat.bullets.is_empty() else {}
	var before=Vector2(bullet.get("position",Vector2.ZERO))
	game._process(.1)
	if not bullet.is_empty():check(Vector2(bullet.position).distance_to(before)<Vector2(bullet.velocity).length()*.04,"Projectiles continue moving slowly during fatal aftermath")
	await capture("fatal-slow-motion")
	for i in 12:game._process(.1)
	check(game.screen=="result" and not game.death_transition.active,"Result appears after the bounded slow-motion transition")
	check(game.save.state.meta==awarded,"Fatal aftermath awards the result exactly once")
	check(is_equal_approx(Engine.time_scale,1.0),"Slow motion never changes global engine time scale")
	game.start_run();game.set_process(false)
	check(not game.death_transition.active and is_equal_approx(game.zoom,1.0),"Restart returns to normal speed and camera scale")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"captures":captures}
	FileAccess.open("res://artifacts/playtest-polish-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
