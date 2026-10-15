extends "res://tests/test_centipede_scene.gd"
## Actual scene pixels at the normal gameplay zoom, for both playable bodies.
const Feedback=preload("res://scripts/segment_feedback.gd")

func frame(label:String):
	await capture(label)
	return root.get_texture().get_image() if DisplayServer.get_name()!="headless" else null

func red_gain(before:Image,after:Image,at:Vector2,radius:int=22) -> int:
	var count=0
	for y in range(roundi(at.y)-radius,roundi(at.y)+radius+1):
		for x in range(roundi(at.x)-radius,roundi(at.x)+radius+1):
			if x<0 or y<0 or x>=after.get_width() or y>=after.get_height():continue
			var a=after.get_pixel(x,y)
			var b=before.get_pixel(x,y)
			if a.r-a.g>b.r-b.g+0.12 and a.r>0.3:count+=1
	return count

func advance_hit(dt:float):
	game.test_time+=dt
	for part in game.player.parts:Feedback.step_hit(part,dt)

func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.test_mode=false
	game.save.state.settings.skip_boss=true
	game.start_run();game.set_process(false)
	game.combat.enemies.clear();game.combat.bullets.clear();game.combat.effects.clear()
	for name in ["Core_Gun_Gatling","Core_Gun_Cannon","Core_Gun_Shotgun","Core_Gun_Tesla"]:game.player.append_segment(game.db.named(name).id)
	game.player.refresh_positions();game.zoom=1.0;game.camera=game.player.head-Vector2(105,0)
	var index=game.player.part_at(2)
	var target=game.world(game.player.parts[index].position)
	var neighbor=game.world(game.player.parts[game.player.part_at(3)].position)
	var before=await frame("segment-injury-centipede-before")
	game.combat.hurt_player(index,18,0)
	var after=await frame("segment-injury-centipede-hit")
	if before!=null:
		check(red_gain(before,after,target)>150,"Normal zoom: damaged shell and mounted organ visibly turn red")
		# The expanding cue may cross an adjacent rim; its core stays unchanged.
		check(red_gain(before,after,neighbor,14)<12,"Normal zoom: neighboring shell retains its own color")
	advance_hit(0.16)
	var held=await frame("segment-injury-centipede-settle")
	if before!=null:check(red_gain(before,held,target)>70,"Local red cue remains visible after 160 ms")
	advance_hit(0.3)
	await frame("segment-injury-centipede-health-trail")
	check(game.player.parts[index].impact_left==0 and game.player.parts[index].damage_number_left>0,"Tint settles before the legible damage number and health trail expire")
	advance_hit(1.0)
	await frame("segment-injury-centipede-recovered")
	game.player.configure_character("spider");game.player.reset()
	for leg in [0,1,2,3]:game.player.install_module(game.db.named("Core_Gun_Gatling").id,game.player.spider_mount(leg,0))
	game.player.refresh_positions();game.camera=game.player.head
	index=game.player.part_at(game.player.spider_mount(0,0))
	target=game.world(game.player.parts[index].position)
	neighbor=game.world(game.player.parts[game.player.part_at(game.player.spider_mount(1,0))].position)
	before=await frame("segment-injury-spider-before")
	game.combat.hurt_player(index,15,0)
	after=await frame("segment-injury-spider-hit")
	if before!=null:
		check(red_gain(before,after,target)>90,"Spider: only the struck leg shell and its organ turn red")
		check(red_gain(before,after,neighbor,14)<12,"Spider: opposite leg does not inherit a hit tint")
	var count=game.segment_damage_layer.get_child_count()
	for i in 100:game.combat.hurt_player(index,0.01,0)
	check(game.segment_damage_layer.get_child_count()==count,"A hundred contacts create no per-hit UI nodes")
	game.combat.hurt_player(0,30,0)
	await frame("segment-injury-spider-body-hit")
	advance_hit(1.5)
	await frame("segment-injury-spider-recovered")
	game.screen="menu"
	await frame("segment-injury-menu-cleanup")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.process_mode=Node.PROCESS_MODE_DISABLED
	game.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"captures":captures,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/segment-injury-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
