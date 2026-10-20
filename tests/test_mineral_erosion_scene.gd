extends "res://tests/test_centipede_scene.gd"
const Mineral=preload("res://scripts/mineral_erosion.gd")
var ores:Array=[]
func settle():
	for i in 4: await process_frame
func capture(label:String):
	game.sync_camera_layers();game.insect_layer.sync(game,0);game.battle_hud.refresh()
	game.queue_redraw();game.enemy_health_layer.queue_redraw();await settle()
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var path="res://artifacts/mineral-"+label+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"Native capture: "+label)
	captures.append(path)
func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
	game.set_process(false);game.test_mode=true;game.save.fresh();game.start_run();await settle()
	game.tutorials.visible=false
	game.combat.enemies.clear();game.combat.effects.clear();game.combat.bullets.clear();game.combat.loot.clear()
	game.camera=Vector2.ZERO;game.center=Vector2(720,450);game.zoom=1.3
	var terrain=game.combat.terrain;game.combat.terrain=null
	var labels=Control.new();game.add_child(labels)
	for row in 2:
		for col in 4:
			var e=game.combat.spawn(game.db.pool["132"],Vector2(-390+col*240,-180+row*220))
			e.uid=100+row+col*4;e.warp=0;e.hp=100;e.max_hp=100;e.guns=[]
			ores.append(e)
			for hit in col*2:
				var origin=e.position+(Vector2(-180,(hit%3-1)*12) if row==0 else Vector2((hit%3-1)*12,-180))
				var s={"position":origin,"previous":origin,"velocity":origin.direction_to(e.position),"damage":14.0,"shield_damage":14.0,"friendly":true,"chips":{},"pierce":1,"data":{"class":"BasicProjectile"}}
				game.combat.hit_enemy(e,s)
			e.feedback_left=0
			var label=Label.new();labels.add_child(label)
			label.text=["完整矿石","轻度开采","深度开采","剩余碎块"][col]
			label.position=game.world(e.position)+Vector2(-55,80)
			label.add_theme_font_size_override("font_size",20)
	game.combat.effects.clear();game.combat.loot.clear()
	game.combat.terrain=terrain
	var enemy=game.combat.spawn(game.db.pool["250"],Vector2(-80,265));enemy.warp=0;enemy.hp=enemy.max_hp*.6;enemy.guns=[]
	await capture("erosion-stages")
	game.enemy_health_layer.rebuild()
	check(game.enemy_health_layer.bars.all(func(b):return b.uid not in ores.map(func(e):return e.uid)),"Actual scene hides every mineral health bar")
	check(game.enemy_health_layer.bars.any(func(b):return b.uid==enemy.uid),"Monster health bar remains visible")
	check(game.material==null,"Weapon and projectile canvas retains original colors")
	var damaged=ores[1]
	var texture=damaged.mineral.texture
	var count=damaged.mineral.remaining
	var origin=damaged.position+Vector2(-150,20)
	game.combat.hit_enemy(damaged,{"position":origin,"previous":origin,"velocity":origin.direction_to(damaged.position),"damage":10.0,"shield_damage":10.0,"friendly":true,"chips":{},"pierce":1,"data":{"class":"BasicProjectile"},"fx_family":"gatling"})
	await capture("fracture-impact")
	check(damaged.mineral.texture==texture and damaged.mineral.remaining<count and not damaged.mineral.dirty,"Further hit updates existing native texture after first upload")
	var revisions=ores.map(func(e):return int(e.get("mineral",{}).get("revision",0)))
	game.screen="pause";game.camera+=Vector2(20,10);game.zoom=.9
	await capture("erosion-paused")
	check(ores.map(func(e):return int(e.get("mineral",{}).get("revision",0)))==revisions,"Pause, zoom and camera movement preserve every cut")
	check(ores.filter(func(e):return e.has("mineral")).all(func(e):return not e.mineral.dirty),"Native renderer uploads masks and clears dirty flag")
	labels.queue_free()
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"captures":captures,"scope":"Actual gameplay renderer with staged damage; HP labels are test-only."}
	FileAccess.open("res://artifacts/mineral-erosion-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
