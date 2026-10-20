extends "res://tests/test_centipede_scene.gd"
## Render the corrected reference treatment through the actual gameplay scene.
const Art = preload("res://scripts/charcoal_art.gd")

func settle():
	for i in 4: await process_frame

func shot(tag: String):
	game.sync_camera_layers();game.insect_layer.sync(game,0);game.battle_hud.refresh();game.queue_redraw()
	await settle()
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path = "res://artifacts/charcoal-" + tag + ".png"
	check(root.get_texture().get_image().save_png(path) == OK, "Native capture " + tag)
	captures.append(path)

func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
	game.set_process(false);game.test_mode=true;game.save.fresh()
	game.selected_mission=game.db.named("Survival Mission");game.start_run();await settle()
	game.tutorials.movement_shown=true;game.tutorials.radar_shown=true;game.tutorials.fuel_shown=true;game.tutorials.visible=false
	await shot("fresh-run")
	check(game.material == null,"Weapon and projectile canvas preserves original colors")
	for key in ["rocks","chasm","panel","centipede_parts","centipede_leg_links","centipede_tail_reference","spider_segmented_parts"]:
		var pixels=Art.texture(key).get_image()
		check(pixels.detect_alpha()!=Image.ALPHA_NONE and pixels.get_pixel(0,0).a<.01,"True transparent source: "+key)
	game.combat.enemies.clear();game.combat.loot.clear();game.combat.effects.clear()
	game.run.timers={"swarm":999,"wave":999,"patrol":999}
	game.run.elapsed=19;game.run.heat=.02
	for name in ["Core_Gun_Cannon","Core_Gun_Gatling","Core_Gun_Shotgun","Core_Gun_Tesla","Core_Gun_Cannon","Core_Gun_Gatling"]:
		var core=game.db.named(name)
		if not core.is_empty():game.player.append_segment(core.id)
	game.player.coil_active=true;game.player.coil_rig.begin(game.player,true)
	for i in 90: game.player.step(1.0/60.0,Vector2.ZERO,false)
	game.camera=game.player.head;game.center=Vector2(720,450)
	var rocks=[Vector2(-420,-280),Vector2(-310,-210),Vector2(-180,-145),Vector2(-82,-210),Vector2(-270,-65),Vector2(-385,5),Vector2(-265,115),Vector2(-260,-365)]
	var radii=[]
	for i in rocks.size():
		var actor=game.combat.spawn(game.db.pool[str(130+i%3)],game.player.head+rocks[i])
		actor.warp=0.0;actor.damageable=true;actor.active=true
		radii.append(actor.radius)
	for i in 3:
		var enemy=game.combat.spawn(game.db.pool["250"],game.player.head+Vector2(250+i*130,100-i*110))
		enemy.warp=0.0;enemy.damageable=true;enemy.active=true
	game.run.encounters.start_warning("charger")
	game.run.encounters.markers.assign([game.player.head+Vector2(-460,260)])
	game.run.packs=1;game.reward_snoozed=true
	game.combat.loot.append({"position":game.player.head+Vector2(160,160),"value":5,"pack":false})
	await shot("reference-scene")
	check(game.combat.enemies.slice(0,rocks.size()).map(func(e):return e.radius)==radii,"Restyling preserves obstacle collision radii")
	var fixed_positions=game.charcoal_terrain.visible_chasms.duplicate(true)
	game.queue_redraw();await settle()
	check(game.charcoal_terrain.visible_chasms==fixed_positions,"Decorations remain stable between stationary frames")
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=dimensions;game.center=Vector2(dimensions)*.5;await settle();await shot("layout-%dx%d"%[dimensions.x,dimensions.y])
		var h=game.battle_hud
		check(root.get_visible_rect().encloses(h.skill_label.get_global_rect()),"Skill label fits "+str(dimensions))
		check(not h.skill_label.get_global_rect().intersects(h.keys.get_global_rect()),"Bottom controls do not overlap "+str(dimensions))
	root.size=Vector2i(1440,900);game.center=Vector2(720,450);await settle()
	game.run.packs=0;game.run.rewards.queue.clear();game.reward_snoozed=true
	game.show_build();await settle()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var path="res://artifacts/charcoal-assembly.png"
		check(root.get_texture().get_image().save_png(path)==OK,"Assembly capture");captures.append(path)
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"captures":captures,"scope":"Native main scene; staged showcase plus fresh run. Corrected second reference only."}
	FileAccess.open("res://artifacts/charcoal-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
